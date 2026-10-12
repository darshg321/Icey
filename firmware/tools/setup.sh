#!/usr/bin/env bash
# One-time host setup for the Icey board (Linux).
#  - Python venv with pyftdi (programmer), numpy (examples) and YoWASP
#    yosys/nextpnr/icepack (build)
#  - udev rule so the FT2232H can be opened without root
# The venv lives at $ICEY_VENV (default ~/.local/share/icey/venv); the
# Icestudio board definition looks for it there too.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VENV="${ICEY_VENV:-$HOME/.local/share/icey/venv}"
PKGS=(pyftdi numpy yowasp-yosys yowasp-nextpnr-ice40)

echo "==> Creating Python venv at $VENV"
mkdir -p "$(dirname "$VENV")"
if command -v uv >/dev/null; then
    uv venv -q --allow-existing "$VENV"
    VIRTUAL_ENV="$VENV" uv pip install -q "${PKGS[@]}"
elif python3 -m venv "$VENV" 2>/dev/null; then
    "$VENV/bin/pip" install -q "${PKGS[@]}"
else
    echo "!! Could not create a venv. Install uv (https://docs.astral.sh/uv/) or python3-venv." >&2
    exit 1
fi

RULE=/etc/udev/rules.d/53-icey-ftdi.rules
if ! cmp -s "$HERE/53-icey-ftdi.rules" "$RULE" 2>/dev/null; then
    echo "==> Installing udev rule (needs sudo)"
    sudo cp "$HERE/53-icey-ftdi.rules" "$RULE"
    sudo udevadm control --reload
    echo "    Unplug and replug the board's programming USB-C for it to take effect."
fi

if ! id -nG | grep -qw dialout; then
    echo "==> Optional: to use the FPGA UART as /dev/ttyUSB1, run"
    echo "      sudo usermod -aG dialout \$USER   (then log out/in)"
fi

echo "==> Done. Try:  $VENV/bin/python $HERE/iceyprog.py id"
