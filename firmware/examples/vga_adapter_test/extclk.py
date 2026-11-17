#!/usr/bin/env python3
"""Load a bitstream, then leave the FT2232H free-running a clock (30 MHz requested, 15 MHz measured) on the
flash SCK line (FPGA pin 15) so the design has a crystal-derived clock.

Uses MPSSE command 0x95 (clock continuously until GPIOL1 goes low). GPIOL1 is
CDONE, which stays high while the FPGA is configured, so the clock runs until
the FTDI is next reset (any iceyprog command, or a replug). The script exits
without resetting the FTDI on purpose.
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools'))
from iceyprog import Icey  # noqa: E402

data = open(sys.argv[1], 'rb').read()
b = Icey()
ok = b.load_sram(data)
print('CDONE =', int(ok))
if not ok:
    sys.exit(1)
ftdi = b.ctrl.ftdi
f = ftdi.set_frequency(30e6)
ftdi.write_data(bytes([0x95]))
time.sleep(0.2)
print(f"SCK free-running (requested {f / 1e6:.0f} MHz, measured 15 MHz on the board)")
sys.stdout.flush()
os._exit(0)   # skip pyftdi cleanup: it would put the FTDI back in UART mode and stop the clock
