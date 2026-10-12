#!/usr/bin/env python3
"""iceyprog - programmer for the Icey iCE40UP5K board.

Talks to the on-board FT2232H (channel A, MPSSE) with pyftdi. Stock iceprog /
openFPGALoader can't be used because the board's FTDI pinout differs from the
iCEstick/iCEBreaker convention they hard-code:

    ADBUS0 SCK   ADBUS1 MOSI   ADBUS2 MISO
    ADBUS3 CS    ADBUS4 CRESET_B   ADBUS5 CDONE

Commands:
    iceyprog.py sram  design.bin   load into FPGA SRAM (lost on power-off)
    iceyprog.py flash design.bin   write SPI flash + verify (see README:
                                   rev-1 boards cannot boot from flash)
    iceyprog.py id                 read flash JEDEC ID (FPGA held in reset)
    iceyprog.py status             print CDONE
    iceyprog.py reset              pulse CRESET_B (FPGA tries to boot from flash)
"""
import argparse
import sys
import time

try:
    from pyftdi.spi import SpiController
    from pyftdi.ftdi import FtdiError
except ImportError:
    sys.exit('iceyprog: pyftdi is not installed. Run firmware/tools/setup.sh '
             '(or: pip install pyftdi)')

URL = 'ftdi://ftdi:2232h/1'
CRESET = 1 << 4
CDONE = 1 << 5


class Icey:
    def __init__(self, url=URL, freq=6e6):
        self.ctrl = SpiController(cs_count=1)
        self.ctrl.configure(url, frequency=freq)
        self.spi = self.ctrl.get_port(0, freq=freq, mode=0)
        self.gpio = self.ctrl.get_gpio()
        # CRESET out, CDONE in. CRESET isn't actually driven until the first
        # creset() call, so 'status' leaves a running design alone.
        self.gpio.set_direction(CRESET | CDONE, CRESET)

    def close(self):
        # Returns the FTDI to its default (UART) mode, which leaves the FPGA
        # running and CRESET_B pulled high by R20.
        self.ctrl.terminate()

    def creset(self, high):
        self.gpio.write(CRESET if high else 0)

    def cdone(self):
        return bool(self.gpio.read() & CDONE)

    def cs(self, low):
        self.spi.force_select(level=not low)

    # ---- FPGA SRAM (SPI slave configuration) ----
    def load_sram(self, data):
        # CS low on the rising edge of CRESET_B selects SPI slave mode.
        # Hold the FPGA in reset BEFORE pulling CS low: an unconfigured FPGA
        # keeps retrying a (failing) flash boot and drives SCK/CS itself, and
        # asserting CS against it first makes the load fail (reproduced on
        # hardware).
        self.creset(False)
        self.cs(True)
        time.sleep(0.001)
        self.creset(True)
        # Reading CDONE forces a USB round-trip so the delay below really
        # happens between CRESET_B rising and the data (UP5K needs >1.2 ms);
        # without it the commands get batched and configuration fails.
        if self.cdone():
            raise RuntimeError('CDONE stuck high while FPGA is in reset')
        time.sleep(0.002)
        self.cs(False)
        self.spi.write(b'\x00')  # 8 dummy clocks with CS high
        self.cs(True)
        for i in range(0, len(data), 4096):
            self.spi.write(data[i:i + 4096], start=False, stop=False)
        self.cs(False)
        self.spi.write(b'\x00' * 13)  # >= 49 clocks to enter user mode
        return self.cdone()

    # ---- SPI flash (FPGA held in reset so it releases the bus) ----
    def _cmd(self, out, readlen=0):
        return self.spi.exchange(bytes(out), readlen)

    def _wait(self):
        while self._cmd([0x05], 1)[0] & 1:
            time.sleep(0.001)

    def flash_id(self):
        self._cmd([0xAB])  # release power-down
        time.sleep(0.001)
        return self._cmd([0x9F], 3)

    def flash_write(self, data, offset=0):
        end = offset + len(data)
        for a in range(offset & ~0xFFFF, end, 0x10000):
            self._cmd([0x06])
            self._cmd([0xD8, a >> 16 & 0xFF, a >> 8 & 0xFF, a & 0xFF])
            self._wait()
        for i in range(0, len(data), 256):
            a = offset + i
            self._cmd([0x06])
            self._cmd(bytes([0x02, a >> 16 & 0xFF, a >> 8 & 0xFF, a & 0xFF])
                      + data[i:i + 256])
            self._wait()

    def flash_read(self, n, offset=0):
        out = bytearray()
        for i in range(0, n, 4096):
            a = offset + i
            out += self._cmd([0x03, a >> 16 & 0xFF, a >> 8 & 0xFF, a & 0xFF],
                             min(4096, n - i))
        return bytes(out)


def open_board(args):
    try:
        return Icey(args.url, args.freq)
    except (ValueError, FtdiError, OSError) as e:
        msg = str(e)
        if 'langid' in msg or 'Access denied' in msg or 'ermission' in msg:
            sys.exit('iceyprog: no permission to open the FT2232H. Install the '
                     'udev rule (firmware/tools/setup.sh) and replug the board.')
        if 'No USB device' in msg or 'not found' in msg.lower():
            sys.exit('iceyprog: Icey board not found (FT2232H 0403:6010). '
                     'Is the programming USB-C (USB2) plugged in?')
        raise


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd', choices=['sram', 'flash', 'id', 'status', 'reset'])
    ap.add_argument('bitstream', nargs='?')
    ap.add_argument('--freq', type=float, default=6e6, help='SPI clock (Hz)')
    ap.add_argument('--url', default=URL, help='pyftdi device URL')
    args = ap.parse_args()
    if args.cmd in ('sram', 'flash'):
        if not args.bitstream:
            ap.error(f'{args.cmd} needs a bitstream file')
        data = open(args.bitstream, 'rb').read()

    b = open_board(args)
    ok = True
    try:
        if args.cmd == 'status':
            print('CDONE =', int(b.cdone()))
        elif args.cmd == 'reset':
            b.creset(False)
            time.sleep(0.01)
            b.creset(True)
            time.sleep(0.5)
            ok = b.cdone()
            print('CDONE after reset =', int(ok))
        elif args.cmd == 'id':
            b.creset(False)
            time.sleep(0.01)
            jid = b.flash_id()
            print('flash JEDEC ID:', jid.hex(' '), '(W25Q128JV = ef 40 18)')
            ok = jid == b'\xef\x40\x18'
            b.creset(True)
        elif args.cmd == 'sram':
            print(f'loading {len(data)} bytes into FPGA SRAM...')
            ok = b.load_sram(data)
            print('CDONE =', int(ok), '-> configured' if ok else '-> FAILED')
        elif args.cmd == 'flash':
            b.creset(False)
            time.sleep(0.01)
            print('flash JEDEC ID:', b.flash_id().hex(' '))
            print(f'writing {len(data)} bytes...')
            b.flash_write(data)
            ok = b.flash_read(len(data)) == data
            print('verify:', 'OK' if ok else 'MISMATCH')
            b.creset(True)
            time.sleep(0.5)
            print('CDONE after reset =', int(b.cdone()),
                  '(expected 0 on rev-1 boards: flash boot is broken, see README)')
    finally:
        b.close()
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
