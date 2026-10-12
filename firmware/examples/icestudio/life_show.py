#!/usr/bin/env python3
"""Full-screen terminal show for the Icey Game of Life demo (life.ice).

Normally started by firmware/life-demo.sh, which builds and loads the design.
Acts: random soup -> glider gun -> flat-out benchmark -> cell-for-cell proof.

    life_show.py           play once, then wait for Enter
    life_show.py --loop    kiosk mode: repeat forever (Ctrl-C to quit)
"""
import argparse
import os
import shutil
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from life import CLOCK, N, Life, make_grid, step  # noqa: E402

# ------------------------------------------------------------- styling -----
ESC = '\x1b['
BOLD = ESC + '1m'
DIM = ESC + '2m'


def fg(r, g, b):
    return f'{ESC}38;2;{r};{g};{b}m'


def bg(r, g, b):
    return f'{ESC}48;2;{r};{g};{b}m'


ACCENT = (90, 200, 255)
GOOD = (120, 230, 140)
WARM = (255, 170, 60)
MUTED = (120, 130, 150)
BG = (10, 12, 22)
RESET = ESC + '0m' + bg(*BG)        # back to plain text on the show's background

# cell colour by age (generations seen alive): white-hot -> orange -> red ->
# magenta -> deep blue
_STOPS = [(0, (255, 255, 255)), (1, (255, 236, 140)), (3, (255, 170, 50)),
          (8, (240, 70, 70)), (20, (200, 60, 200)), (60, (90, 80, 230)),
          (200, (50, 70, 160))]
PALETTE = np.stack([np.interp(np.arange(256), [a for a, _ in _STOPS], [c[k] for _, c in _STOPS])
                    for k in range(3)], axis=1).round().astype(np.int32)

BIG = {  # 3x5 block font for the headline number
    '0': ['███', '█ █', '█ █', '█ █', '███'], '1': [' █ ', '██ ', ' █ ', ' █ ', '███'],
    '2': ['███', '  █', '███', '█  ', '███'], '3': ['███', '  █', '███', '  █', '███'],
    '4': ['█ █', '█ █', '███', '  █', '  █'], '5': ['███', '█  ', '███', '  █', '███'],
    '6': ['███', '█  ', '███', '█ █', '███'], '7': ['███', '  █', '  █', '  █', '  █'],
    '8': ['███', '█ █', '███', '█ █', '███'], '9': ['███', '█ █', '███', '  █', '███'],
    ',': ['   ', '   ', '   ', ' █ ', '█  '], '.': ['   ', '   ', '   ', '   ', ' █ '],
    ' ': ['   '] * 5,
}


def big_text(s):
    return [' '.join(BIG[ch][row] for ch in s) for row in range(5)]


# ------------------------------------------------------------ screen -------
class Screen:
    def __init__(self):
        self.cols, self.lines = shutil.get_terminal_size((100, 40))
        # half-blocks give 1 char per cell column (128 wide, 64 tall);
        # braille packs 2x4 cells per char (64 wide, 32 tall)
        self.half = self.cols >= 128 + 44 and self.lines >= 64 + 6
        self.gw, self.gh = (128, 64) if self.half else (64, 32)
        self.side = self.cols >= self.gw + 44
        self.ox = max(0, (self.cols - (self.gw + 2 + (42 if self.side else 0))) // 2)

    def __enter__(self):
        sys.stdout.write('\x1b[?1049h\x1b[?25l' + bg(*BG) + '\x1b[2J')
        sys.stdout.flush()
        return self

    def __exit__(self, *exc):
        sys.stdout.write(ESC + '0m\x1b[?25h\x1b[?1049l')
        sys.stdout.flush()

    def at(self, row, col):
        return f'{ESC}{row + 1};{col + 1}H'

    def clear(self):
        sys.stdout.write(bg(*BG) + '\x1b[2J')

    # --------------------------------------------------------------- grid --
    def grid(self, age):
        """age: 128x128 uint8, 0 = dead, n = alive for n snapshots."""
        alive = age > 0
        col = PALETTE[np.minimum(age, 255) - 1]  # (128,128,3)
        out = []
        top = 3
        if self.half:
            for r in range(64):
                a, b2 = alive[2 * r], alive[2 * r + 1]
                ca, cb = col[2 * r], col[2 * r + 1]
                line = [self.at(top + r, self.ox + 1)]
                prev = None
                for x in range(128):
                    f = tuple(ca[x]) if a[x] else BG
                    k = tuple(cb[x]) if b2[x] else BG
                    if (f, k) != prev:
                        line.append(fg(*f) + bg(*k))
                        prev = (f, k)
                    line.append('▀')
                out.append(''.join(line))
        else:
            bits = np.zeros((32, 64), np.int32)
            for dx, dy, bit in ((0, 0, 1), (0, 1, 2), (0, 2, 4), (1, 0, 8),
                                (1, 1, 16), (1, 2, 32), (0, 3, 64), (1, 3, 128)):
                bits |= alive[dy::4, dx::2].astype(np.int32) * bit
            # colour each character by its youngest live cell
            a = np.where(alive, age, 255).reshape(32, 4, 64, 2).min(axis=(1, 3))
            for r in range(32):
                line = [self.at(top + r, self.ox + 1), bg(*BG)]
                prev = None
                for x in range(64):
                    c = tuple(PALETTE[a[r, x] - 1]) if bits[r, x] else MUTED
                    if c != prev:
                        line.append(fg(*c))
                        prev = c
                    line.append(chr(0x2800 + bits[r, x]))
                out.append(''.join(line))
        sys.stdout.write(''.join(out))

    def frame_box(self, title):
        """Border around the grid plus the act title."""
        w, h, x0, top = self.gw, self.gh, self.ox, 2
        c = fg(*MUTED) + bg(*BG)
        s = [self.at(top, x0) + c + '╭' + '─' * w + '╮']
        for r in range(h):
            s.append(self.at(top + 1 + r, x0) + c + '│' + self.at(top + 1 + r, x0 + w + 1) + '│')
        s.append(self.at(top + h + 1, x0) + c + '╰' + '─' * w + '╯')
        t = f' {title} '
        s.append(self.at(top, x0 + 2) + BOLD + fg(*ACCENT) + t + RESET + bg(*BG))
        sys.stdout.write(''.join(s))

    def header(self):
        txt = (BOLD + fg(*ACCENT) + ' ICEY ' + RESET + bg(*BG) + fg(*MUTED) +
               ' iCE40UP5K FPGA  ·  Conway\'s Game of Life  ·  128 cells computed every clock')
        sys.stdout.write(self.at(0, self.ox) + bg(*BG) + txt + '\x1b[K')

    def panel(self, lines):
        """Stats panel: right of the grid, or under it on narrow terminals."""
        if self.side:
            r0, c0 = 3, self.ox + self.gw + 4
        else:
            r0, c0 = self.gh + 4, self.ox
        for i, ln in enumerate(lines):
            sys.stdout.write(self.at(r0 + i, c0) + bg(*BG) + RESET + bg(*BG) + ln + RESET + bg(*BG) + '\x1b[K')

    def flush(self):
        sys.stdout.flush()


# ------------------------------------------------------------- the show ----
def stat(label, value, color=(230, 235, 245)):
    return fg(*MUTED) + f'{label:<14}' + BOLD + fg(*color) + value + RESET


def bar(frac, width, color):
    n = max(0.0, min(1.0, frac)) * width
    full = int(n)
    part = ' ▏▎▍▌▋▊▉'[int((n - full) * 8)] if full < width else ''
    return fg(*color) + '█' * full + part + RESET + bg(*BG) + ' ' * (width - full - len(part))


class Show:
    def __init__(self, board, scr):
        self.b, self.s = board, scr
        self.age = np.zeros((N, N), np.uint8)
        self.pc_rate = None

    def update_age(self, grid):
        self.age = np.where(grid == 1, np.minimum(self.age.astype(np.int32) + 1, 255), 0).astype(np.uint8)

    def watch(self, title, grid, rate, seconds, notes):
        b, s = self.b, self.s
        b.speed(255)
        b.load(grid)
        b.speed(max(1, min(254, round(CLOCK / rate / 65536))))
        self.age[:] = 0
        s.clear(); s.header(); s.frame_box(title)
        g0, t0 = None, time.time()
        last = (None, None); r = 0.0
        while time.time() - t0 < seconds:
            gen, g = b.snapshot()
            now = time.time()
            if g0 is None:
                g0 = gen
            if last[0] is not None and now > last[1]:
                r = 0.7 * r + 0.3 * (gen - last[0]) / (now - last[1])
            last = (gen, now)
            self.update_age(g)
            s.grid(self.age)
            s.panel([stat('generation', f'{gen - g0:,}'),
                     stat('live cells', f'{int(g.sum()):,}'),
                     stat('speed', f'{r:,.0f} gen/s'),
                     '', *notes,
                     '', fg(*MUTED) + 'colour = cell age:  ' +
                     ''.join(fg(*PALETTE[a]) + '█' for a in (0, 1, 3, 6, 12, 25, 60, 150)) +
                     fg(*MUTED) + '  new → old'])
            s.flush()
            time.sleep(1 / 30)

    def measure_pc(self):
        g = make_grid('random', np.random.default_rng(1))
        k, t = 0, time.time()
        while time.time() - t < 1.0:
            g = step(g)
            k += 1
        return k / (time.time() - t)

    def unleash(self, seconds):
        b, s = self.b, self.s
        s.clear(); s.header(); s.frame_box('ACT 3 · OFF THE LEASH')
        s.panel([fg(*WARM) + BOLD + 'Benchmarking...' + RESET,
                 fg(*MUTED) + 'FPGA running flat out, untouched for 2 s',
                 fg(*MUTED) + 'meanwhile: same simulation on this PC (NumPy)'])
        s.flush()
        b.speed(255)
        b.load(make_grid('random', np.random.default_rng()))
        b.speed(0)
        g0, _ = b.snapshot()
        t0 = time.time()
        pc = self.measure_pc()                       # ~1 s while the FPGA runs
        time.sleep(max(0.0, 2.0 - (time.time() - t0)))
        g1, _ = b.snapshot()
        fpga = (g1 - g0) / (time.time() - t0)
        self.pc_rate = pc
        # live view, still flat out (each snapshot pauses it ~7 ms)
        self.age[:] = 0
        t0 = time.time()
        gstart = g1
        headline = big_text(f'{fpga:,.0f}')
        while time.time() - t0 < seconds:
            gen, g = b.snapshot()
            self.update_age(g)
            s.grid(self.age)
            w = 20
            s.panel([fg(*WARM) + BOLD + l + RESET for l in headline] + [
                BOLD + fg(*WARM) + 'generations per second' + RESET,
                '',
                stat('cell updates', f'{fpga * N * N / 1e9:.2f} billion / s', WARM),
                stat('per clock', f'128 cells (a whole row)'),
                stat('generation', f'{gen - gstart:,}'),
                '',
                fg(*MUTED) + 'FPGA      ' + bar(1.0, w, WARM) + f' {fpga:,.0f}',
                fg(*MUTED) + 'This PC   ' + bar(pc / fpga, w, ACCENT) + f' {pc:,.0f}',
                '',
                BOLD + fg(*GOOD) + f'{fpga / pc:,.0f}x faster' + RESET + fg(*MUTED) +
                ' than NumPy on this computer,',
                fg(*MUTED) + 'on a small FPGA clocked at just 24 MHz.'])
            s.flush()
            time.sleep(1 / 15)
        return fpga

    def proof(self):
        b, s = self.b, self.s
        s.clear(); s.header(); s.frame_box('ACT 4 · PROOF')
        g = make_grid('random', np.random.default_rng())
        b.speed(255)
        b.load(g)
        gen0, _ = b.snapshot()
        b.speed(0)
        time.sleep(0.1)
        b.speed(255)
        gen1, fpga_grid = b.snapshot()
        n = gen1 - gen0
        self.age[:] = 0
        self.update_age(fpga_grid)
        s.grid(self.age)
        ref = g
        t0 = time.time()
        for i in range(n):
            ref = step(ref)
            if i % 250 == 0 or i == n - 1:
                done = (i + 1) / n
                s.panel([BOLD + 'The FPGA ran ' + fg(*WARM) + f'{n:,}' + RESET + BOLD +
                         ' generations in 0.1 s.' + RESET,
                         fg(*MUTED) + 'Now this PC computes the same thing',
                         fg(*MUTED) + 'to check every single cell:',
                         '',
                         bar(done, 30, ACCENT) + f' {done * 100:5.1f}%',
                         fg(*MUTED) + f'{time.time() - t0:5.1f} s on the PC']); s.flush()
        diff = int((ref != fpga_grid).sum())
        ok = diff == 0
        verdict = (fg(*GOOD) + BOLD + f'✔ all {N * N:,} cells match' if ok
                   else fg(240, 80, 80) + BOLD + f'✘ {diff} cells differ')
        s.panel([BOLD + 'The FPGA ran ' + fg(*WARM) + f'{n:,}' + RESET + BOLD +
                 ' generations in 0.1 s.' + RESET,
                 fg(*MUTED) + f'This PC needed {time.time() - t0:.1f} s for the same work.',
                 '', bar(1, 30, ACCENT) + ' 100.0%', '', verdict + RESET,
                 fg(*MUTED) + 'Bit-exact with the software reference.' if ok else ''])
        s.flush()
        time.sleep(4)
        return ok, n

    def finale(self, fpga, n, ok, loop):
        s = self.s
        s.clear(); s.header()
        lines = [
            BOLD + fg(*ACCENT) + 'What just happened' + RESET, '',
            f'• The grid lives in the FPGA\'s block RAM. 128 copies of the Life rule',
            f'  are wired side by side in the chip, so every clock tick a whole row',
            f'  of 128 cells is computed at once.',
            f'• Flat out: ' + fg(*WARM) + BOLD + f'{fpga:,.0f} generations/s' + RESET + bg(*BG) +
            f'  ({fpga * N * N / 1e9:.2f} billion cell updates/s)',
            f'• That is ' + fg(*GOOD) + BOLD + f'{fpga / self.pc_rate:,.0f}x faster' + RESET + bg(*BG) +
            ' than this computer running optimised NumPy.',
            f'• Proof: {n:,} generations, every cell ' + (fg(*GOOD) + 'identical' if ok else fg(240, 80, 80) + 'NOT identical') +
            RESET + bg(*BG) + ' to the PC.',
            f'• The PC only watches: all the work happens on the board, and the',
            f'  results come back over the same USB cable used to program it.',
            '', fg(*MUTED) + 'Design: firmware/examples/icestudio/life.ice (open it in Icestudio)',
            '', fg(*MUTED) + ('Replaying in 8 s...  (Ctrl-C to quit)' if loop else 'Press Enter to exit.'),
        ]
        top = max(2, (s.lines - len(lines)) // 2)
        left = max(0, (s.cols - 76) // 2)
        for i, ln in enumerate(lines):
            sys.stdout.write(s.at(top + i, left) + bg(*BG) + ln + RESET + bg(*BG))
        s.flush()


def run(loop):
    board = Life()
    try:
        with Screen() as scr:
            show = Show(board, scr)
            while True:
                show.watch('ACT 1 · PRIMORDIAL SOUP', make_grid('random', np.random.default_rng()),
                           20, 10, [fg(*MUTED) + 'A random grid, slowed to 20 gen/s so you can',
                                    fg(*MUTED) + 'watch. Order emerges from noise.'])
                show.watch('ACT 2 · GOSPER GLIDER GUN', make_grid('gun', None), 40, 10,
                           [fg(*MUTED) + 'A pattern that fires a glider every',
                            fg(*MUTED) + '30 generations, forever (the grid wraps,',
                            fg(*MUTED) + 'so eventually they come back around).'])
                fpga = show.unleash(10)
                ok, n = show.proof()
                show.finale(fpga, n, ok, loop)
                if not loop:
                    input()
                    break
                time.sleep(8)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            board.speed(255)
        except Exception:
            pass
        board.close()


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--loop', action='store_true', help='repeat forever (kiosk mode)')
    run(ap.parse_args().loop)
