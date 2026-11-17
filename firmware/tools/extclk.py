#!/usr/bin/env python3
"""Run a VGA design from the FT2232H's crystal instead of the FPGA's RC oscillator.

VGA-to-HDMI adapters can't lock onto the pixel clock made from the iCE40's
internal HFOSC (it wanders too much), but they do lock when the PLL is fed
from the FTDI chip, which runs off a 12 MHz crystal (tested 2026-11-16 with
firmware/examples/vga_adapter_test top_ext). Only works while the board is on
USB: the FTDI's channel A free-runs a clock on the flash SCK line (pin 15).

  extclk.py patch BUILD_DIR   rewrite BUILD_DIR/main.v + main.pcf (from ice2v.py) so the
                              design's SB_PLL40_CORE takes FLASH_SCK as its reference
                              (and lines are 804 clocks, to keep the sync rates on spec)
  extclk.py load FILE.bin     load into SRAM, then leave SCK clocking (15 MHz measured)

While the clock runs, /dev/ttyUSB0 (channel A) is gone; channel B (UART) still works.
Any iceyprog.py command or a replug resets the FTDI, stops the clock and freezes the design.
"""
import os
import re
import sys
import time

# 15 MHz * (53+1) / 2^5 = 25.3125 MHz (VGA wants 25.175; +0.55%), VCO 810 MHz.
# With 15 MHz in, the PLL can't get closer (PFD >= 10 MHz forces DIVR 0, VCO <= 1066 MHz).
PLL = {'DIVR': "4'b0000", 'DIVF': "7'b0110101", 'DIVQ': "3'b101", 'FILTER_RANGE': "3'b001"}


def add_port(src, module, decl):
    """Insert `decl,` as the first port of `module`."""
    pat = re.compile(r'(module\s+%s\s*\()' % re.escape(module))
    src, n = pat.subn(lambda m: m.group(1) + '\n  ' + decl + ',', src, count=1)
    if n != 1:
        sys.exit(f'extclk: could not find module {module}')
    return src


def patch(build):
    vpath, ppath = os.path.join(build, 'main.v'), os.path.join(build, 'main.pcf')
    src = open(vpath).read()
    if 'REFERENCECLK(FLASH_SCK)' in src:
        return
    # module that holds the PLL
    pll_at = src.find('SB_PLL40_CORE')
    if pll_at < 0:
        sys.exit('extclk: no SB_PLL40_CORE in the design')
    mod = re.findall(r'^module\s+(\w+)', src[:pll_at], re.M)[-1]
    end = src.index('endmodule', pll_at)
    body = src[pll_at:end]
    for k, v in PLL.items():
        body = re.sub(r'\.%s\([^)]*\)' % k, f'.{k}({v})', body)
    body = re.sub(r'\.REFERENCECLK\([^)]*\)', '.REFERENCECLK(FLASH_SCK)', body)
    src = src[:pll_at] + body + src[end:]
    src = add_port(src, mod, 'input FLASH_SCK')
    if mod != 'main':
        src = add_port(src, 'main', 'input FLASH_SCK')
        src, n = re.subn(r'(^%s\s+\w+\s*\()' % re.escape(mod), r'\1.FLASH_SCK(FLASH_SCK), ', src,
                         count=1, flags=re.M)
        if n != 1:
            sys.exit(f'extclk: could not find the {mod} instance in main')
    # 25.3125 MHz / 800 clocks = 31.64 kHz lines, 60.3 Hz frames: just outside VESA's 0.5%.
    # 804 clocks per line puts them on spec (31.48 kHz, 59.97 Hz); the extra 4 go in the back porch.
    src, n = re.subn(r'\bhc == 799\b', 'hc == 803', src)
    if n == 0:
        sys.exit('extclk: no 800-clock line counter (hc == 799) found')
    open(vpath, 'w').write(src)
    with open(ppath, 'a') as f:
        f.write('set_io FLASH_SCK 15\n')


def load(path):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from iceyprog import Icey
    b = Icey()
    if not b.load_sram(open(path, 'rb').read()):
        print('extclk: CDONE stayed low, load failed', file=sys.stderr)
        sys.exit(1)
    ftdi = b.ctrl.ftdi
    ftdi.set_frequency(30e6)          # gives 15 MHz on the pin (measured)
    ftdi.write_data(bytes([0x95]))    # MPSSE: clock continuously until GPIOL1 (CDONE) goes low
    time.sleep(0.2)
    sys.stdout.flush()
    os._exit(0)   # skip pyftdi cleanup: it would reset channel A and stop the clock


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('patch', 'load'):
        sys.exit(__doc__)
    (patch if sys.argv[1] == 'patch' else load)(sys.argv[2])
