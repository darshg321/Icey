#!/usr/bin/env python3
"""Full-screen terminal show for the Icey showcase (showcase.ice).

Normally started by firmware/life-demo.sh, which builds and loads the design.
Board check (USB host, keyboard, microSD, RGB) -> random soup -> glider gun ->
patterns from the microSD -> flat-out benchmark -> cell-for-cell proof.
A keyboard plugged into the board's USB host port steers the show.

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
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'hwtest'))
from life import CLOCK, N, Life, make_grid, step  # noqa: E402
from hwtest import (SD_CS, USB_CS, USB_RST, Bridge, Fat32, Keyboard,  # noqa: E402
                    sd_init)

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
               ' iCE40UP5K FPGA  ·  Game of Life + USB host + microSD  ·  128 cells computed every clock')
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
RED, BLUE, GREEN = 0x10, 0x20, 0x40          # RGB LED bits in the bridge's 'C' command
BASE = SD_CS | USB_CS | USB_RST              # chip selects idle high, MAX3421E running


class Quit(Exception):
    pass


class NextAct(Exception):
    pass


def stat(label, value, color=(230, 235, 245)):
    return fg(*MUTED) + f'{label:<14}' + BOLD + fg(*color) + value + RESET


def bar(frac, width, color):
    n = max(0.0, min(1.0, frac)) * width
    full = int(n)
    part = ' ▏▎▍▌▋▊▉'[int((n - full) * 8)] if full < width else ''
    return fg(*color) + '█' * full + part + RESET + bg(*BG) + ' ' * (width - full - len(part))


def parse_rle(text):
    """Life pattern in RLE format -> 128x128 grid (centred, cropped)."""
    body, w, h = [], 0, 0
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('x'):
            for part in line.split(','):
                k, _, v = part.partition('=')
                if k.strip() == 'x':
                    w = int(v)
                elif k.strip() == 'y':
                    h = int(v)
            continue
        body.append(line)
    cells, x, y, num = [], 0, 0, ''
    for ch in ''.join(body):
        if ch.isdigit():
            num += ch
            continue
        n = int(num or 1)
        num = ''
        if ch == 'o':
            cells += [(x + i, y) for i in range(n)]
            x += n
        elif ch == 'b':
            x += n
        elif ch == '$':
            y += n
            x = 0
        elif ch == '!':
            break
    g = np.zeros((N, N), np.uint8)
    w = max(w, max((c[0] for c in cells), default=0) + 1)
    h = max(h, max((c[1] for c in cells), default=0) + 1)
    ox, oy = max(0, (N - w) // 2), max(0, (N - h) // 2)
    for cx, cy in cells:
        if 0 <= ox + cx < N and 0 <= oy + cy < N:
            g[oy + cy, ox + cx] = 1
    return g


def stdin_enter():
    import select
    if select.select([sys.stdin], [], [], 0)[0]:
        sys.stdin.readline()
        return True
    return False


class Show:
    def __init__(self, life, scr):
        self.b, self.s = life, scr
        self.io = Bridge(port=life.p)
        self.age = np.zeros((N, N), np.uint8)
        self.pc_rate = None
        self.kbd = None
        self.fs = None
        self.sd_info = None
        self.sd_files = []
        self.sd_patterns = []                    # (name, grid)
        self.sd_idx = 0
        self.btn_prev = True
        self.last_input = None
        self.keys_seen = 0

    # ------------------------------------------------------------ helpers --
    def rgb(self, bits):
        self.io.set(BASE | bits)

    def inputs(self):
        """New keyboard keys + SW2 presses since the last call."""
        ev = []
        if self.kbd and self.kbd.name:
            for k in self.kbd.poll():
                ev.append(k)
                self.last_input = f"keyboard '{k}'"
                self.keys_seen += 1
        released = bool(self.io.inputs() & 1)
        if self.btn_prev and not released:
            ev.append('button')
            self.last_input = 'button SW2'
        self.btn_prev = released
        if 'esc' in ev or 'q' in ev:
            raise Quit
        if 'n' in ev or 'right' in ev:
            raise NextAct
        return ev

    def update_age(self, grid):
        self.age = np.where(grid == 1, np.minimum(self.age.astype(np.int32) + 1, 255), 0).astype(np.uint8)

    def controls(self):
        if not (self.kbd and self.kbd.name):
            return [fg(*MUTED) + 'SW2 on the board: new random soup']
        k = lambda key, what: BOLD + fg(*ACCENT) + f'{key:>5}' + RESET + fg(*MUTED) + f' {what}'
        lines = [fg(*MUTED) + "keyboard on the board's USB port:",
                 k('space', 'pause') + '   ' + k('r', 'new soup'),
                 k('g', 'glider gun') + ' ' + k('a', 'acorn'),
                 k('+/-', 'speed') + '      ' + k('n', 'next act'),
                 k('esc', 'quit') + '       ' + fg(*MUTED) + 'SW2 = new soup']
        if self.sd_patterns:
            lines.insert(4, k('s', f'next pattern from the microSD ({len(self.sd_patterns)})'))
        return lines

    # -------------------------------------------------------- board check --
    def board_check(self):
        s = self.s
        s.clear(); s.header()
        rows = []
        top = 3
        left = max(0, (s.cols - 84) // 2)

        def show(extra=None):
            for i, (mark, label, text) in enumerate(rows + ([extra] if extra else [])):
                c = {'ok': fg(*GOOD) + '✔', 'no': fg(*MUTED) + '○', 'run': fg(*WARM) + '…'}[mark]
                room = max(20, s.cols - left - 15)
                text = text if len(text) <= room else text[:room - 3] + '...'
                sys.stdout.write(s.at(top + 2 + i, left) + bg(*BG) + '\x1b[K' + c + RESET + '  ' +
                                 BOLD + f'{label:<10}' + RESET + fg(220, 225, 235) + text + RESET)
            s.flush()

        sys.stdout.write(s.at(top, left) + BOLD + fg(*ACCENT) + 'BOARD CHECK' + RESET +
                         fg(*MUTED) + '   everything below is reached through the FPGA')
        rows.append(('ok', 'FPGA', 'Life engine + I/O bridge loaded, sharing one 3 Mbaud USB link'))
        show()

        self.rgb(RED | BLUE)
        show(('run', 'USB host', 'looking for a keyboard on the board\'s USB-C port...'))
        self.io.speed(6e6)
        self.kbd = Keyboard(self.io, wait=2.0)
        rev = self.kbd.h.rd(self.kbd.h.REVISION)
        rows.append(('ok', 'USB host', f'MAX3421E controller, revision 0x{rev:02x}'))
        if self.kbd.name:
            vid, pid = self.kbd.vidpid
            rows.append(('ok', 'keyboard', f'{self.kbd.name}  ({vid:04x}:{pid:04x}) — it steers the show'))
        else:
            rows.append(('no', 'keyboard', 'none (optional: plug one into the board to steer the show)'))
        show(('run', 'microSD', 'reading the card...'))

        try:
            sd, info = sd_init(self.io)
        except Exception as e:                    # noqa: BLE001
            sd, info = None, str(e)
        if sd:
            self.sd_info = info
            gb = info.get('bytes', 0) / 1e9
            rows.append(('ok', 'microSD', f"{gb:.1f} GB {info['type']}, \"{info.get('name', '?')}\", "
                                          f"made {info.get('date', '?')}"))
            try:
                self.fs = Fat32(sd)
                self.sd_files = self.fs.listdir()
                names = [f['name'] + ('/' if f['dir'] else '') for f in self.sd_files]
                shown = ', '.join(names)
                rows.append(('ok', '', f'FAT32 "{self.fs.label}": {len(names)} entries: {shown}'))
                for f in self.sd_files:
                    if not f['dir'] and f['name'].lower().endswith('.rle') and f['size'] < 64 * 1024:
                        try:
                            g = parse_rle(self.fs.read(f).decode('ascii', 'replace'))
                            if g.any():
                                self.sd_patterns.append((f['name'], g))
                        except Exception:  # noqa: BLE001
                            pass
                rows.append(('ok' if self.sd_patterns else 'no', '',
                             f'{len(self.sd_patterns)} Life pattern(s) (.rle) found on the card' if self.sd_patterns
                             else 'no .rle Life patterns on the card (copy some to its root to play them)'))
            except (ValueError, IOError) as e:
                rows.append(('no', '', f'filesystem: {e} (file listing needs FAT32)'))
            self.io.speed(6e6)
        else:
            rows.append(('no', 'microSD', f'no card ({info})'))
        show(('run', 'RGB LED', 'red... blue... green...'))
        for c in (RED, BLUE, GREEN):
            self.rgb(c)
            time.sleep(0.4)
        rows.append(('ok', 'RGB LED', 'red / blue / green on pins 39 / 40 / 41'))
        rows.append(('ok', 'SW2', 'press it during the show for a new soup (LED1 lights while held)'))
        show()
        self.rgb(0)
        t = time.time()
        sys.stdout.write(s.at(top + 3 + len(rows), left) + fg(*MUTED) +
                         'starting in a moment...  (n = skip, esc = quit)' + RESET)
        s.flush()
        while time.time() - t < 4:
            try:
                self.inputs()
            except NextAct:
                break
            time.sleep(0.05)

    # -------------------------------------------------------------- watch --
    def watch(self, title, grid, rate, seconds, notes, rgb=BLUE):
        b, s = self.b, self.s
        self.rgb(rgb)

        def load(g):
            b.speed(255)
            b.load(g)
            self.age[:] = 0

        def set_rate(r):
            b.speed(max(1, min(254, round(CLOCK / r / 65536))))

        load(grid)
        set_rate(rate)
        s.clear(); s.header(); s.frame_box(title)
        g0, t0, paused = None, time.time(), False
        last = (None, None); r = 0.0
        while time.time() - t0 < seconds or paused:
            ev = self.inputs()
            if ev:
                t0 = time.time()                     # interacting keeps the act going
            for e in ev:
                if e == 'space':
                    paused = not paused
                    b.speed(255) if paused else set_rate(rate)
                elif e in ('r', 'button'):
                    load(make_grid('random', np.random.default_rng())); set_rate(rate)
                elif e in ('g', 'a', 'p'):
                    load(make_grid({'g': 'gun', 'a': 'acorn', 'p': 'rpent'}[e], None)); set_rate(rate)
                elif e == 's' and self.sd_patterns:
                    name, g = self.sd_patterns[self.sd_idx % len(self.sd_patterns)]
                    self.sd_idx += 1
                    self.last_input = f"microSD pattern '{name}'"
                    load(g); set_rate(rate)
                elif e in ('+', '='):
                    rate = min(rate * 1.5, 360); set_rate(rate)
                elif e == '-':
                    rate = max(rate / 1.5, 2); set_rate(rate)
                if paused and e != 'space':
                    b.speed(255)
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
                     stat('speed', 'paused' if paused else f'{r:,.0f} gen/s'),
                     '', *notes, '', *self.controls(),
                     '', stat('last input', self.last_input or '—', ACCENT),
                     '', fg(*MUTED) + 'colour = cell age:  ' +
                     ''.join(fg(*PALETTE[a]) + '█' for a in (0, 1, 3, 6, 12, 25, 60, 150)) +
                     fg(*MUTED) + '  new → old'])
            s.flush()
            time.sleep(1 / 40)

    def sd_act(self):
        for name, g in self.sd_patterns[:6]:
            self.watch(f'FROM YOUR microSD · {name[:30]}', g, 30, 8,
                       [fg(*MUTED) + f'{name}, read from the card in the board\'s',
                        fg(*MUTED) + 'microSD slot through the FPGA\'s SPI bus.'], rgb=GREEN | BLUE)

    # ------------------------------------------------------------ unleash --
    def measure_pc(self):
        g = make_grid('random', np.random.default_rng(1))
        k, t = 0, time.time()
        while time.time() - t < 1.0:
            g = step(g)
            k += 1
        return k / (time.time() - t)

    def unleash(self, seconds):
        b, s = self.b, self.s
        self.rgb(RED)
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
        pc = self.measure_pc()
        time.sleep(max(0.0, 2.0 - (time.time() - t0)))
        g1, _ = b.snapshot()
        fpga = (g1 - g0) / (time.time() - t0)
        self.pc_rate = pc
        self.age[:] = 0
        t0 = time.time()
        headline = big_text(f'{fpga:,.0f}')
        try:
            while time.time() - t0 < seconds:
                for e in self.inputs():
                    if e in ('r', 'button'):
                        b.speed(255); b.load(make_grid('random', np.random.default_rng())); b.speed(0)
                        self.age[:] = 0
                gen, g = b.snapshot()
                self.update_age(g)
                s.grid(self.age)
                w = 20
                s.panel([fg(*WARM) + BOLD + l + RESET for l in headline] + [
                    BOLD + fg(*WARM) + 'generations per second' + RESET, '',
                    stat('cell updates', f'{fpga * N * N / 1e9:.2f} billion / s', WARM),
                    stat('per clock', '128 cells (a whole row)'),
                    stat('generation', f'{gen - g1:,}'), '',
                    fg(*MUTED) + 'FPGA      ' + bar(1.0, w, WARM) + f' {fpga:,.0f}',
                    fg(*MUTED) + 'This PC   ' + bar(pc / fpga, w, ACCENT) + f' {pc:,.0f}', '',
                    BOLD + fg(*GOOD) + f'{fpga / pc:,.0f}x faster' + RESET + fg(*MUTED) +
                    ' than NumPy on this computer,',
                    fg(*MUTED) + 'on a small FPGA clocked at just 24 MHz.', '',
                    fg(*MUTED) + 'The LED is red: flat out. The keyboard and',
                    fg(*MUTED) + 'SW2 still work, the I/O runs in parallel.'])
                s.flush()
                time.sleep(1 / 15)
        except NextAct:
            pass
        return fpga

    # -------------------------------------------------------------- proof --
    def proof(self):
        b, s = self.b, self.s
        self.rgb(RED | BLUE)
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
        head = [BOLD + 'The FPGA ran ' + fg(*WARM) + f'{n:,}' + RESET + BOLD + ' generations in 0.1 s.' + RESET]
        for i in range(n):
            ref = step(ref)
            if i % 250 == 0 or i == n - 1:
                done = (i + 1) / n
                s.panel(head + [fg(*MUTED) + 'Now this PC computes the same thing',
                                fg(*MUTED) + 'to check every single cell:', '',
                                bar(done, 30, ACCENT) + f' {done * 100:5.1f}%',
                                fg(*MUTED) + f'{time.time() - t0:5.1f} s on the PC']); s.flush()
        diff = int((ref != fpga_grid).sum())
        ok = diff == 0
        self.rgb(GREEN if ok else RED)
        verdict = (fg(*GOOD) + BOLD + f'✔ all {N * N:,} cells match' if ok
                   else fg(240, 80, 80) + BOLD + f'✘ {diff} cells differ')
        s.panel(head + [fg(*MUTED) + f'This PC needed {time.time() - t0:.1f} s for the same work.',
                        '', bar(1, 30, ACCENT) + ' 100.0%', '', verdict + RESET,
                        fg(*MUTED) + 'Bit-exact with the software reference.' if ok else '',
                        fg(*MUTED) + 'The LED is green: proof passed.' if ok else ''])
        s.flush()
        t = time.time()
        while time.time() - t < 4:
            try:
                self.inputs()
            except NextAct:
                break
            time.sleep(0.05)
        return ok, n

    # ------------------------------------------------------------- finale --
    def finale(self, fpga, n, ok, loop):
        s = self.s
        s.clear(); s.header()
        kb = self.kbd.name if self.kbd and self.kbd.name else None
        lines = [
            BOLD + fg(*ACCENT) + 'What just happened' + RESET, '',
            '• The grid lives in the FPGA\'s block RAM. 128 copies of the Life rule',
            '  are wired side by side in the chip: a whole row of 128 cells per clock.',
            '• Flat out: ' + fg(*WARM) + BOLD + f'{fpga:,.0f} generations/s' + RESET +
            f'  ({fpga * N * N / 1e9:.2f} billion cell updates/s), ' + fg(*GOOD) + BOLD +
            f'{fpga / self.pc_rate:,.0f}x' + RESET + ' NumPy on this PC.',
            f'• Proof: {n:,} generations, every cell ' +
            (fg(*GOOD) + 'identical' if ok else fg(240, 80, 80) + 'NOT identical') + RESET + ' to the PC.',
            '• At the same time, an I/O bridge in the same chip ran the board\'s',
            '  peripherals for the PC over the same USB cable:',
            f'    – USB host: {kb} enumerated by the board, {self.keys_seen} keys read' if kb
            else '    – USB host: MAX3421E controller (no keyboard plugged in)',
            (f"    – microSD: {self.sd_info.get('bytes', 0) / 1e9:.1f} GB card, "
             f'{len(self.sd_files)} files listed from its FAT32 filesystem') if self.sd_info
            else '    – microSD: no card inserted',
            '    – SW2 button, RGB LED and LED1 driven by the FPGA',
            '', fg(*MUTED) + 'Design: firmware/examples/icestudio/showcase.ice (open it in Icestudio)',
            '', fg(*MUTED) + ('Replaying in 8 s...  (esc to quit)' if loop
                              else 'Press Enter here, or Enter/Esc on the board\'s keyboard, to exit.'),
        ]
        top = max(2, (s.lines - len(lines)) // 2)
        left = max(0, (s.cols - 80) // 2)
        for i, ln in enumerate(lines):
            sys.stdout.write(s.at(top + i, left) + bg(*BG) + ln + RESET)
        s.flush()


def run(loop):
    life = Life()
    try:
        with Screen() as scr:
            show = Show(life, scr)
            try:
                show.board_check()
                while True:
                    fpga, n, ok = None, 0, False
                    for act in ('soup', 'gun', 'sd', 'leash', 'proof'):
                        try:
                            if act == 'soup':
                                show.watch('ACT 1 · PRIMORDIAL SOUP',
                                           make_grid('random', np.random.default_rng()), 20, 12,
                                           [fg(*MUTED) + 'A random grid, slowed to 20 gen/s so you can',
                                            fg(*MUTED) + 'watch. Order emerges from noise.'])
                            elif act == 'gun':
                                show.watch('ACT 2 · GOSPER GLIDER GUN', make_grid('gun', None), 40, 12,
                                           [fg(*MUTED) + 'Fires a glider every 30 generations, forever',
                                            fg(*MUTED) + '(the grid wraps, so they come back around).'])
                            elif act == 'sd' and show.sd_patterns:
                                show.sd_act()
                            elif act == 'leash':
                                fpga = show.unleash(10)
                            elif act == 'proof':
                                ok, n = show.proof()
                        except NextAct:
                            continue
                    show.finale(fpga or 0, n, ok, loop)
                    t = time.time()
                    while True:
                        if not loop and stdin_enter():
                            raise Quit
                        try:
                            ev = show.inputs()
                        except NextAct:
                            ev = ['enter']
                        if not loop and 'enter' in ev:
                            raise Quit
                        if loop and time.time() - t > 8:
                            break
                        time.sleep(0.05)
            except Quit:
                pass
    except KeyboardInterrupt:
        pass
    finally:
        try:
            life.speed(255)
            Bridge(port=life.p).set(BASE)
        except Exception:  # noqa: BLE001
            pass
        life.close()


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--loop', action='store_true', help='repeat forever (kiosk mode)')
    run(ap.parse_args().loop)
