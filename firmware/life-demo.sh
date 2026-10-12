#!/usr/bin/env bash
# One command to run the Icey Game of Life demo:
#   sets up tools (first run only) -> builds life.ice -> loads it -> runs the show
#
#   ./firmware/life-demo.sh            play once
#   ./firmware/life-demo.sh --loop     kiosk mode (repeat until Ctrl-C)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VENV="${ICEY_VENV:-$HOME/.local/share/icey/venv}"
PY="$VENV/bin/python"
ICE="$HERE/examples/icestudio/life.ice"
BUILD="$HERE/build/life"

c() { printf '\033[1;38;2;90;200;255m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

# 1. tools
if ! "$PY" -c 'import pyftdi, numpy, yowasp_yosys, yowasp_nextpnr_ice40' 2>/dev/null; then
    c "First run: installing tools (one time)"
    "$HERE/tools/setup.sh"
fi

# 2. board
if command -v lsusb >/dev/null && ! lsusb -d 0403:6010 >/dev/null; then
    die "Icey not found. Plug in the programming USB-C (USB2) and try again."
fi

# 3. build (cached until life.ice changes)
if [ ! -f "$BUILD/life.bin" ] || [ "$ICE" -nt "$BUILD/life.bin" ]; then
    c "Building life.ice for the FPGA (first time takes ~30 s)"
    "$PY" "$HERE/tools/ice2v.py" "$ICE" "$BUILD"
    (cd "$BUILD" &&
        "$VENV/bin/yowasp-yosys" -q -p 'synth_ice40 -top main -json life.json' main.v &&
        "$VENV/bin/yowasp-nextpnr-ice40" -q --up5k --package sg48 \
            --json life.json --pcf main.pcf --asc life.asc &&
        "$VENV/bin/yowasp-icepack" life.asc life.bin) || die "Build failed"
fi

# 4. load
c "Loading the design onto the board"
"$PY" "$HERE/tools/iceyprog.py" sram "$BUILD/life.bin" >/dev/null ||
    die "Couldn't load the FPGA (run: $PY $HERE/tools/iceyprog.py sram $BUILD/life.bin)"

# 5. show
exec "$PY" "$HERE/examples/icestudio/life_show.py" "$@"
