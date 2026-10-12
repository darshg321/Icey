#!/usr/bin/env python3
"""PC side of the Icey Game of Life demo (examples/icestudio/life.ice).

The FPGA keeps a 128x128 grid and computes a whole row of 128 cells every
clock. This script talks to it over the FT2232H's second channel (the same
USB cable used for programming) at 3 Mbaud and draws the grid in the terminal.

    python life.py                  watch a random soup evolve
    python life.py --pattern gun    Gosper glider gun (also: acorn, rpent)
    python life.py --rate 60        generations per second to show (watch mode)
    python life.py --bench          measure the FPGA flat out
    python life.py --verify         check the FPGA cell-for-cell against NumPy

Needs pyftdi + numpy: run firmware/tools/setup.sh, then use
~/.local/share/icey/venv/bin/python life.py
"""
import argparse
import sys
import time

import numpy as np
from pyftdi.serialext import serial_for_url

N = 128
URL = 'ftdi://ftdi:2232h/2'
CLOCK = 24e6

PATTERNS = {
    'gun': [(24, 0), (22, 1), (24, 1), (12, 2), (13, 2), (20, 2), (21, 2), (34, 2), (35, 2),
            (11, 3), (15, 3), (20, 3), (21, 3), (34, 3), (35, 3), (0, 4), (1, 4), (10, 4),
            (16, 4), (20, 4), (21, 4), (0, 5), (1, 5), (10, 5), (14, 5), (16, 5), (17, 5),
            (22, 5), (24, 5), (10, 6), (16, 6), (24, 6), (11, 7), (15, 7), (12, 8), (13, 8)],
    'acorn': [(1, 0), (3, 1), (0, 2), (1, 2), (4, 2), (5, 2), (6, 2)],
    'rpent': [(1, 0), (2, 0), (0, 1), (1, 1), (1, 2)],
}


# ---------------------------------------------------------------- board ----
class Life:
    def __init__(self):
        self.p = serial_for_url(URL, baudrate=3_000_000, timeout=1)
        self.p.udev.set_latency_timer(1)     # default 16 ms slows every round trip
        self.p.reset_input_buffer()

    def close(self):
        self.p.close()

    def _read(self, n):
        buf = bytearray()
        while len(buf) < n:
            chunk = self.p.read(n - len(buf))
            if not chunk:
                sys.exit(f'life: no reply from the board ({len(buf)}/{n} bytes). '
                         'Is life.ice uploaded?')
            buf += chunk
        return bytes(buf)

    def _ack(self):
        if self._read(1) != b'k':
            sys.exit('life: unexpected reply from the board')

    def speed(self, n):
        """0 = flat out, 255 = stopped, else n * 65536 clocks per generation."""
        self.p.write(bytes([ord('V'), n]))
        self._ack()

    def step(self):
        self.p.write(b'N')
        self._ack()

    def load(self, grid):
        self.p.write(b'L' + np.packbits(grid, axis=1, bitorder='little').tobytes())
        self._ack()

    def snapshot(self):
        self.p.write(b'S')
        raw = self._read(4 + N * N // 8)
        gen = int.from_bytes(raw[:4], 'little')
        grid = np.unpackbits(np.frombuffer(raw[4:], np.uint8).reshape(N, N // 8),
                             axis=1, bitorder='little')
        return gen, grid


# ------------------------------------------------------------ reference ----
def step(g):
    n = sum(np.roll(np.roll(g, dy, 0), dx, 1)
            for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0))
    return ((n == 3) | ((g == 1) & (n == 2))).astype(np.uint8)


def make_grid(name, rng):
    g = np.zeros((N, N), np.uint8)
    if name == 'random':
        g[:] = rng.random((N, N)) < 0.35
    else:
        cells = PATTERNS[name]
        w = max(x for x, _ in cells) + 1
        h = max(y for _, y in cells) + 1
        ox, oy = (N - w) // 2, (N - h) // 2
        if name == 'gun':
            ox, oy = 4, 4
        for x, y in cells:
            g[oy + y, ox + x] = 1
    return g


# --------------------------------------------------------------- render ----
DOTS = [(0, 0, 0x01), (0, 1, 0x02), (0, 2, 0x04), (1, 0, 0x08),
        (1, 1, 0x10), (1, 2, 0x20), (0, 3, 0x40), (1, 3, 0x80)]


def braille(g):
    """128x128 grid -> 32 lines of 64 braille characters (2x4 cells each)."""
    code = np.zeros((N // 4, N // 2), np.int32)
    for dx, dy, bit in DOTS:
        code |= g[dy::4, dx::2].astype(np.int32) * bit
    return '\n'.join(''.join(chr(0x2800 + c) for c in line) for line in code)


# ---------------------------------------------------------------- modes ----
def watch(b, args, rng):
    b.speed(255)
    b.load(make_grid(args.pattern, rng))
    # n * 65536 clocks per generation (plus ~135 to compute it)
    n = max(1, min(254, round(CLOCK / args.rate / 65536)))
    b.speed(n)
    sys.stdout.write('\x1b[2J\x1b[?25l')
    last_gen, last_t = None, time.time()
    start_gen = None               # the board's counter keeps running across sessions
    rate = 0.0
    try:
        while True:
            gen, g = b.snapshot()
            if start_gen is None:
                start_gen = gen
            now = time.time()
            if last_gen is not None and now > last_t:
                rate = 0.8 * rate + 0.2 * (gen - last_gen) / (now - last_t)
            last_gen, last_t = gen, now
            sys.stdout.write('\x1b[H' + braille(g) + '\n')
            sys.stdout.write(f'gen {gen - start_gen:>8}   live {int(g.sum()):>5}   '
                             f'{rate:6.1f} gen/s   (Ctrl-C to quit, --bench for full speed)\x1b[K\n')
            sys.stdout.flush()
            time.sleep(1 / 30)
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write('\x1b[?25h\n')


def bench(b, rng):
    b.speed(255)
    b.load(make_grid('random', rng))
    b.speed(0)
    g0, _ = b.snapshot()
    t0 = time.time()
    time.sleep(3)
    g1, _ = b.snapshot()
    t1 = time.time()
    b.speed(255)
    gps = (g1 - g0) / (t1 - t0)
    print(f'FPGA:  {gps:,.0f} generations/s  =  {gps * N * N / 1e9:.2f} billion cell updates/s')
    print(f'       (128 cells per clock, {CLOCK / gps:.0f} clocks per generation at 24 MHz)')
    g = make_grid('random', rng)
    k, t = 0, time.time()
    while time.time() - t < 1:
        g = step(g)
        k += 1
    pc = k / (time.time() - t)
    print(f'PC:    {pc:,.0f} generations/s with NumPy on this computer  '
          f'(the FPGA is {gps / pc:,.0f}x faster)')


def verify(b, rng):
    g = make_grid('random', rng)
    b.speed(255)
    b.load(g)
    gen0, got = b.snapshot()
    ok = np.array_equal(got, g)
    print(f'upload           : {"OK" if ok else "MISMATCH"}')
    ref = g
    for i in range(5):
        b.step()
        gen, got = b.snapshot()
        ref = step(ref)
        diff = int((got != ref).sum())
        ok &= diff == 0
        print(f'step {i + 1} (gen {gen - gen0:>2})  : {diff} cells differ')
    # now let it run flat out for a moment, stop it, and check the result
    b.speed(0)
    time.sleep(0.1)
    b.speed(255)
    gen, got = b.snapshot()
    n = gen - gen0 - 5
    print(f'flat out: {n:,} generations; computing the same on the PC...')
    for _ in range(n):
        ref = step(ref)
    diff = int((got != ref).sum())
    ok &= diff == 0
    print(f'flat out (gen {gen - gen0:,}) : {diff} cells differ')
    print('PASS: the FPGA matches the reference exactly' if ok else 'FAIL')
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--pattern', choices=['random', *PATTERNS], default='random')
    ap.add_argument('--rate', type=float, default=20, help='generations/s in watch mode')
    ap.add_argument('--bench', action='store_true')
    ap.add_argument('--verify', action='store_true')
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    rng = np.random.default_rng(args.seed)
    b = Life()
    try:
        if args.bench:
            bench(b, rng)
        elif args.verify:
            sys.exit(0 if verify(b, rng) else 1)
        else:
            watch(b, args, rng)
    finally:
        b.close()


if __name__ == '__main__':
    main()
