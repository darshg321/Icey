#!/usr/bin/env bash
# One command to run an Icey demo:
#   sets up tools (first run only) -> builds the design -> loads it -> runs the show
#
#   ./firmware/life-demo.sh             the showcase in this terminal, no monitor needed:
#                                       Game of Life, USB keyboard, microSD, typing test
#   ./firmware/life-demo.sh --vga       the whole showcase on a monitor plugged into
#                                       the board too (showcase_vga.ice); v = visuals mode
#   ./firmware/life-demo.sh --visuals   same design, starting in visuals mode (effects only)
#   ./firmware/life-demo.sh --patterns  just patterns on the monitor (vga_demo.ice)
#
#   The VGA demos default to working through a VGA-to-HDMI adapter: the pixel clock
#   comes from the USB chip's crystal (tools/extclk.py), so the board must stay
#   plugged into this PC while they run.
#   --purevga                           (with --vga, --visuals or --patterns) a plain VGA
#                                       cable to a VGA monitor: internal oscillator, and the
#                                       board runs on its own after loading
#   --loop                              kiosk mode (repeat until Ctrl-C)
#   --typing                            straight to the typing test
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VENV="${ICEY_VENV:-$HOME/.local/share/icey/venv}"
PY="$VENV/bin/python"
ICE="$HERE/examples/icestudio/showcase.ice"
BUILD="$HERE/build/showcase"
SHOW=()
PATTERNS=0
PUREVGA=0
HDMI=1
for a in "$@"; do
    case "$a" in
        --vga) ICE="$HERE/examples/icestudio/showcase_vga.ice"; BUILD="$HERE/build/showcase_vga"
               SHOW+=(--vga) ;;
        --visuals) ICE="$HERE/examples/icestudio/showcase_vga.ice"; BUILD="$HERE/build/showcase_vga"
                   SHOW+=(--vga --visuals) ;;
        --patterns) ICE="$HERE/examples/icestudio/vga_demo.ice"; BUILD="$HERE/build/vga_demo"
                    PATTERNS=1 ;;
        --purevga) HDMI=0; PUREVGA=1 ;;
        --loop|--typing) SHOW+=("$a") ;;
        *) sed -n '2,/^set/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 1 ;;
    esac
done

c() { printf '\033[1;38;2;90;200;255m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$ICE" == *showcase.ice ]]; then   # terminal showcase: no VGA, no clock needed
    if [ "$PUREVGA" = 1 ]; then die "--purevga needs --vga, --visuals or --patterns"; fi
    HDMI=0
elif [ "$HDMI" = 1 ]; then
    BUILD="${BUILD}_hdmi"
fi

# 1. tools
if ! "$PY" -c 'import pyftdi, numpy, yowasp_yosys, yowasp_nextpnr_ice40' 2>/dev/null; then
    c "First run: installing tools (one time)"
    "$HERE/tools/setup.sh"
fi

# 2. board
if command -v lsusb >/dev/null && ! lsusb -d 0403:6010 >/dev/null; then
    die "Icey not found. Plug in the programming USB-C (USB2) and try again."
fi

# 3. build (cached until the .ice changes)
if [ ! -f "$BUILD/life.bin" ] || [ "$ICE" -nt "$BUILD/life.bin" ] ||
   { [ "$HDMI" = 1 ] && [ "$HERE/tools/extclk.py" -nt "$BUILD/life.bin" ]; }; then
    c "Building $(basename "$ICE") for the FPGA (first time takes ~30 s)"
    "$PY" "$HERE/tools/ice2v.py" "$ICE" "$BUILD"
    if [ "$HDMI" = 1 ]; then "$PY" "$HERE/tools/extclk.py" patch "$BUILD"; fi
    (cd "$BUILD" &&
        "$VENV/bin/yowasp-yosys" -q -p 'synth_ice40 -top main -json life.json' main.v &&
        "$VENV/bin/yowasp-nextpnr-ice40" -q --up5k --package sg48 \
            --json life.json --pcf main.pcf --asc life.asc &&
        "$VENV/bin/yowasp-icepack" life.asc life.bin) || die "Build failed"
fi

# 4. load
c "Loading the design onto the board"
if [ "$HDMI" = 1 ]; then
    "$PY" "$HERE/tools/extclk.py" load "$BUILD/life.bin" ||
        die "Couldn't load the FPGA (run: $PY $HERE/tools/extclk.py load $BUILD/life.bin)"
    c "The USB chip now clocks the picture (for HDMI adapters). Keep the board on this PC."
    c "Plain VGA cable and monitor? --purevga lets the board run on its own."
else
    "$PY" "$HERE/tools/iceyprog.py" sram "$BUILD/life.bin" >/dev/null ||
        die "Couldn't load the FPGA (run: $PY $HERE/tools/iceyprog.py sram $BUILD/life.bin)"
fi

# 5. show
if [ "$PATTERNS" = 1 ]; then
    c "Look at the monitor: the patterns change on their own, SW2 skips to the next one."
    if [ "$HDMI" = 1 ]; then
        c "Leave the board on this PC's USB (it supplies the clock)."
    else
        c "The board runs them by itself now; nothing else is needed from this PC."
    fi
    exit 0
fi
exec "$PY" "$HERE/examples/icestudio/life_show.py" "${SHOW[@]}"
