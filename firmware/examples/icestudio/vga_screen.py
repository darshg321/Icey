"""The VGA monitor side of the Icey showcase (showcase_vga.ice).

The FPGA draws the picture by itself: the live Life grid, the effects, and
an 80x30 text layer on top. This module fills the text layer. It keeps a
copy of the screen and sends only the cells that changed (bridge command
'T'), so screens can be redrawn every frame. VgaShow has one method per
screen of the show (board check, Life acts, benchmark, proof, typing test,
results, finale, visuals).

Used by life_show.py and typing_test.py when started with --vga.
"""
import numpy as np

COLS, ROWS = 80, 30

# palette of the "Text layer" block; 0 = see-through
CLEAR, BLACK, NAVY, MUTED, WHITE, ACCENT, GOOD, WARM, BAD, YELLOW, DARK, GREY, CREAM, ROSE, \
    MAROON, SLATE = range(16)

# font codes 1-31 (same table as tools/vga_font.py); 32-126 are ASCII
GLYPHS = ' █▀▁▂▃▄▅▆▇▏▎▍▌▋▊▉─│╭╮╰╯✔✘○×…·→•░'
CODE = {ch: i for i, ch in enumerate(GLYPHS) if i}
CODE.update({chr(c): c for c in range(32, 127)})
CODE.update({'—': ord('-'), '–': ord('-'), '’': ord("'"), '✓': CODE['✔']})

# 'G' scene byte (Scene director block)
AUTO, HIDE, MIDDLE = 0x80, 0x40, 0x20
SCENES = ['Life, rainbow cells', 'plasma', 'Life over the plasma', 'XOR fractal',
          'Life over the interference', 'interference', 'all 256 colours',
          'Life over the XOR fractal']
SHORT = ['rainbow Life', 'plasma', 'Life + plasma', 'XOR fractal', 'Life + interference',
         'interference', '256 colours', 'Life + XOR']
TEXT_ONLY = 8
EFFECTS = [  # (scene, name, how) for the racing-the-beam act
    (1, 'Sine plasma', '4 sine waves per pixel, then 3 more for the colour: 7 table lookups'),
    (3, 'XOR fractal', 'x XOR y makes nested squares; scrolled and recoloured every frame'),
    (5, 'Interference', 'two moving sources, 4 multiplies per pixel in the DSP blocks'),
    (6, 'All 256 colours', 'everything the 3-3-2 bit resistor DAC on the board can show'),
]

BIG = {  # 3x5 digits, drawn with half blocks (3 text rows)
    '0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
    '2': ['###', '..#', '###', '#..', '###'], '3': ['###', '..#', '###', '..#', '###'],
    '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '###', '..#', '###'],
    '6': ['###', '#..', '###', '#.#', '###'], '7': ['###', '..#', '..#', '..#', '..#'],
    '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '###'],
    ',': ['.', '.', '.', '#', '#'], '.': ['.', '.', '.', '.', '#'],
    '%': ['#.#', '..#', '.#.', '#..', '#.#'], ' ': ['.', '.', '.', '.', '.'],
}


def big(s):
    """Text -> 3 rows of half-block characters (5 pixel rows, 1 column gap)."""
    px = ['', '', '', '', '', '']
    for i, ch in enumerate(s):
        g = BIG.get(ch, BIG[' '])
        for r in range(5):
            px[r] += ('.' if i else '') + g[r]
    px[5] = '.' * len(px[0])
    halves = {('#', '#'): '█', ('#', '.'): '▀', ('.', '#'): '▄', ('.', '.'): ' '}
    return [''.join(halves[a, b] for a, b in zip(px[2 * r], px[2 * r + 1])) for r in range(3)]


def bar(frac, width):
    """Progress bar of full and partial blocks, exactly `width` cells."""
    n = max(0.0, min(1.0, frac)) * width
    full = int(n)
    part = ' ▏▎▍▌▋▊▉'[int((n - full) * 8)] if full < width else ''
    return ('█' * full + part).ljust(width)


def wrap(text, width):
    lines, line = [], ''
    for w in text.split():
        if line and len(line) + 1 + len(w) > width:
            lines.append(line)
            line = w
        else:
            line = f'{line} {w}' if line else w
    return lines + ([line] if line else [])


class VgaText:
    """The FPGA's 80x30 text layer, with a copy here to send only changes."""

    def __init__(self, io):
        self.io = io                                    # hwtest.Bridge
        self.cells = np.zeros((ROWS, COLS), np.uint16)  # {colour, char}
        self.sent = np.full((ROWS, COLS), -1, np.int32)
        self.sent_scene = None
        self.want = None            # scene the current screen asked for
        self.hidden = False         # visuals mode: effects only, whatever was asked

    def scene(self, byte=None):
        if byte is not None:
            self.want = byte
        b = HIDE | MIDDLE | AUTO if self.hidden else self.want
        if b is not None and b != self.sent_scene:
            self.io.p.write(bytes([ord('G'), b]))
            if self.io._read(1) != b'k':
                raise IOError('VGA scene: bad reply from the board')
            self.sent_scene = b

    def clear(self, bg=CLEAR):
        self.cells[:] = bg << 12

    def fill(self, row, col, w, h, bg):
        self.cells[max(0, row):row + h, max(0, col):col + w] = bg << 12

    def text(self, row, col, s, fg=WHITE, bg=CLEAR):
        """Write s at (row, col), clipped to the screen. Returns the next column."""
        if 0 <= row < ROWS:
            attr = (bg << 4 | fg) << 8
            for i, ch in enumerate(s):
                if 0 <= col + i < COLS:
                    self.cells[row, col + i] = attr | CODE.get(ch, ord('?'))
        return col + len(s)

    def segs(self, row, col, parts, bg=CLEAR):
        """parts: [(text, fg), ...] written one after another."""
        for s, fg in parts:
            col = self.text(row, col, s, fg, bg)
        return col

    def box(self, row, col, w, h, fg=SLATE, bg=NAVY, title=None, tfg=ACCENT):
        self.fill(row, col, w, h, bg)
        self.text(row, col, '╭' + '─' * (w - 2) + '╮', fg, bg)
        for r in range(row + 1, row + h - 1):
            self.text(r, col, '│', fg, bg)
            self.text(r, col + w - 1, '│', fg, bg)
        self.text(row + h - 1, col, '╰' + '─' * (w - 2) + '╯', fg, bg)
        if title:
            self.text(row, col + 2, f' {title} ', tfg, bg)

    def flush(self):
        """Send the changed cells: one 'T' command per run, all acks read at once."""
        diff = self.cells.astype(np.int32) != self.sent
        out, n = bytearray(), 0
        for r in np.nonzero(diff.any(axis=1))[0]:
            cols = np.nonzero(diff[r])[0]
            runs, start, end = [], cols[0], cols[0]
            for c in cols[1:]:
                if c - end > 3:                  # a new command costs 4 bytes = 2 cells
                    runs.append((start, end))
                    start = c
                end = c
            runs.append((start, end))
            for a, b in runs:
                addr = r * 128 + a
                cells = self.cells[r, a:b + 1]
                out += bytes([ord('T'), addr >> 8, addr & 0xFF, len(cells)])
                out += np.stack([cells & 0xFF, cells >> 8], axis=1).astype(np.uint8).tobytes()
                n += 1
            self.sent[r] = self.cells[r]
        if n:
            self.io.p.write(bytes(out))
            if self.io._read(n) != b'k' * n:
                raise IOError('VGA text layer: bad reply from the board')


class VgaShow:
    """Every screen of the show, laid out for the 80x30 text layer."""
    PANEL = 51                      # panel column, right of the Life grid (x 16..399)

    def __init__(self, io):
        self.t = VgaText(io)
        self.life_scene = 0         # scene for the Life acts ('v' mode changes it)

    # ------------------------------------------------------------ common --
    def header(self):
        t = self.t
        t.fill(0, 0, COLS, 1, NAVY)
        c = t.text(0, 1, ' ICEY ', BLACK, ACCENT)
        t.text(0, c + 2, 'iCE40UP5K FPGA · Game of Life · USB host · microSD · VGA', MUTED, NAVY)

    def life_screen(self, title, scene=0):
        """Grid at the left, panel at the right: for the Life acts."""
        t = self.t
        self.life_scene = scene
        t.clear()
        self.header()
        t.text(1, 2, f' {title} ', ACCENT, NAVY)
        t.box(2, self.PANEL, COLS - self.PANEL, 26)
        t.text(28, 2, ' this grid is drawn by the FPGA itself, from its own copy ', MUTED, NAVY)
        t.scene(self.life_scene)

    def panel(self, rows):
        """rows: list of [(text, fg), ...] or str, inside the panel box."""
        t, c0, w = self.t, self.PANEL + 2, COLS - self.PANEL - 4
        t.fill(3, self.PANEL + 1, COLS - self.PANEL - 2, 24, NAVY)
        for i, parts in enumerate(rows[:24]):
            if isinstance(parts, str):
                parts = [(parts, MUTED)]
            used, clipped = 0, []
            for s, fg in parts:
                s = s[:max(0, w - used)]
                clipped.append((s, fg))
                used += len(s)
            t.segs(3 + i, c0, clipped, NAVY)

    def stat(self, label, value, fg=WHITE, width=25):
        return [(f'{label:<{width - len(value)}}', MUTED), (value, fg)]

    def para(self, text, fg=MUTED):
        return [[(ln, fg)] for ln in wrap(text, 25)]

    # ------------------------------------------------------- board check --
    def board_check(self, rows, extra=None, footer=None):
        """rows: (mark, label, text) like the terminal's board check."""
        t = self.t
        t.clear()
        self.header()
        t.box(2, 2, COLS - 4, 26, title='BOARD CHECK')
        t.text(3, 4, 'everything below is reached through the FPGA', MUTED, NAVY)
        r = 5
        marks = {'ok': ('✔', GOOD), 'no': ('○', MUTED), 'run': ('…', WARM)}
        for mark, label, text in rows + ([extra] if extra else []):
            ch, fg = marks[mark]
            t.text(r, 4, ch, fg, NAVY)
            t.text(r, 7, label, WHITE, NAVY)
            lines = wrap(text, COLS - 22) or ['']
            for k, ln in enumerate(lines[:3]):
                t.text(r + k, 18, ln, CREAM, NAVY)
            r += min(3, len(lines))
            if r > 25:
                break
        if footer:
            t.text(26, 4, footer, MUTED, NAVY)
        t.scene(1)                  # plasma around the panel
        t.flush()

    # ---------------------------------------------------------- Life acts --
    def watch(self, gen, cells, speed, notes, controls, last_input):
        scene = 'visuals mode' if self.visuals else SHORT[self.life_scene]
        self.panel([self.stat('generation', f'{gen:,}'),
                    self.stat('live cells', f'{cells:,}'),
                    self.stat('speed', speed),
                    '', *self.para(notes, CREAM), '',
                    *controls, '',
                    self.stat('last input', last_input[:13], ACCENT),
                    self.stat('VGA', scene, ACCENT)])
        self.t.flush()

    def controls(self, kbd, sd_patterns):
        if not kbd:
            return [[('SW2 on the board:', MUTED)], [('new random soup', CREAM)]]

        def k(key, what, key2=None, what2=None):
            row = [(f'{key:>5} ', ACCENT), (f'{what:<10}', CREAM)]
            return row + ([(f'{key2:>3} ', ACCENT), (what2, CREAM)] if key2 else [])
        rows = [[('keyboard on the board:', MUTED)],
                k('space', 'pause', 'r', 'soup'),
                k('g', 'gun', 'a', 'acorn'),
                k('+/-', 'speed', 'n', 'next'),
                k('t', 'typing test'),
                k('v', 'visuals mode'),
                k('esc', 'quit', 'SW2', 'soup')]
        if sd_patterns:
            rows.insert(4, k('s', f'microSD pattern ({sd_patterns})'))
        return rows

    def unleash(self, fpga, pc, gen):
        n = f'{fpga:,.0f}'
        rows = [[(ln, WARM)] for ln in big(n)]
        self.panel([*rows, [('generations per second', WARM)], '',
                    self.stat('cells/s', f'{fpga * 128 * 128 / 1e9:.2f} billion', WARM),
                    self.stat('per clock', '128 cells'),
                    self.stat('generation', f'{gen:,}'), '',
                    [('FPGA ', MUTED), (bar(1.0, 19), WARM)],
                    [('PC   ', MUTED), (bar(pc / fpga, 19), ACCENT)],
                    [(f'     {fpga:,.0f} vs {pc:,.0f}', MUTED)], '',
                    [(f'{fpga / pc:,.0f}x faster', GOOD), (' than NumPy', MUTED)],
                    *self.para('on this computer, from a small FPGA at just 24 MHz.'), '',
                    *self.para('The LED is red: flat out. The keyboard and SW2 still work, the '
                               'I/O runs in parallel.')])
        self.t.flush()

    def benchmarking(self):
        self.panel([[('Benchmarking...', WARM)], '',
                    *self.para('FPGA running flat out, untouched for 2 s.'), '',
                    *self.para('Meanwhile: the same simulation on this PC (NumPy).')])
        self.t.flush()

    def proof(self, n, done, secs, verdict=None):
        rows = [[('The FPGA ran ', CREAM), (f'{n:,}', WARM)],
                [('generations in 0.1 s.', CREAM)], '',
                *self.para('Now this PC computes the same thing, to check every single cell:'), '',
                [(bar(done, 17), ACCENT), (f' {done * 100:5.1f}%', WHITE)],
                [(f'{secs:5.1f} s on the PC', MUTED)]]
        if verdict is not None:
            ok, diff = verdict
            rows += ['', [('✔ all 16,384 cells match', GOOD)] if ok else
                     [(f'✘ {diff} cells differ', BAD)]]
            if ok:
                rows += ['', *self.para('Bit-exact with the software reference.'), '',
                         *self.para('The LED is green: proof passed.')]
        self.panel(rows)
        self.t.flush()

    # ------------------------------------------------------------ visuals --
    def visual(self, k, scene, name, how):
        """One effect full screen, with a caption at the bottom."""
        t = self.t
        t.clear()
        t.fill(26, 0, COLS, 3, NAVY)
        c = t.text(26, 2, 'RACING THE BEAM', ACCENT, NAVY)
        t.text(26, c + 2, f'{k}/{len(EFFECTS)}  {name}', WHITE, NAVY)
        t.text(27, 2, how, CREAM, NAVY)
        t.text(28, 2, 'every pixel is computed as the monitor draws it: 25 million a second',
               MUTED, NAVY)
        t.scene(scene | MIDDLE)
        t.flush()

    @property
    def visuals(self):
        return self.t.hidden

    def set_visuals(self, on):
        """Visuals mode: only the effects on the monitor, the FPGA cycling through
        its scenes on its own. The text keeps updating underneath, hidden."""
        self.t.hidden = on
        self.t.scene()

    # ------------------------------------------------------------- finale --
    def finale(self, lines, footer):
        """lines: [(text, fg), ...] paragraphs, wrapped into a box over the plasma."""
        t = self.t
        t.clear()
        self.header()
        t.box(3, 4, COLS - 8, 23, title='WHAT JUST HAPPENED')
        r = 5
        for text, fg in lines:
            if not text:
                r += 1
                continue
            # "• text" and "  - text": continuation lines line up with the text
            body = text.lstrip()
            col = 7 + len(text) - len(body)
            lead = 2 if body[:2] in ('• ', '- ') else 0
            for k, ln in enumerate(wrap(body[lead:], COLS - 15 - col + 7)):
                if k == 0 and lead:
                    t.text(r, col, body[:lead], fg, NAVY)
                t.text(r, col + lead, ln, fg, NAVY)
                r += 1
        t.text(24, 7, footer, MUTED, NAVY)
        t.scene(1)
        t.flush()

    def message(self, lines):
        t = self.t
        t.clear(DARK)
        for i, ln in enumerate(lines):
            t.text(13 + i, (COLS - len(ln)) // 2, ln, CREAM, DARK)
        t.scene(TEXT_ONLY)
        t.flush()

    def off(self):
        """Back to what the FPGA does on its own: scenes cycling, no text."""
        self.t.hidden = False
        self.t.scene(0xFF)

    # -------------------------------------------------------- typing test --
    def typing_logo(self):
        t = self.t
        t.clear(DARK)
        c = t.text(2, 8, 'icey', YELLOW, DARK)
        c = t.text(2, c, 'type', CREAM, DARK)
        t.text(2, c + 3, "keys arrive through the FPGA's USB host", GREY, DARK)

    def typing(self, duration, started, remaining, wpm, lines):
        """lines: up to 3 lists of (char, fg, caret) for the visible words."""
        t = self.t
        self.typing_logo()
        if not started:
            c = t.text(10, 8, 'time  ', GREY, DARK)
            for d in (15, 30, 60):
                c = t.text(10, c, str(d), YELLOW if d == duration else GREY, DARK) + 2
            t.text(10, c + 2, '(1 / 2 / 3)   start typing to begin', GREY, DARK)
        else:
            c = t.text(10, 8, f'{int(remaining + 0.999)}', YELLOW, DARK)
            t.text(10, c + 3, f'{wpm:.0f} wpm', GREY, DARK)
        for k, line in enumerate(lines[:3]):
            for i, (ch, fg, caret) in enumerate(line):
                t.text(12 + 2 * k, 8 + i, ch, DARK if caret else fg, YELLOW if caret else DARK)
        t.text(19, 8, 'tab restart   esc back to the demo   SW2 restart', GREY, DARK)
        t.text(21, 8, 'keyboard → MAX3421E USB host → FPGA → USB → PC → FPGA → this', GREY, DARK)
        t.text(22, 8, 'screen. The FPGA runs the Game of Life flat out meanwhile.', GREY, DARK)
        t.scene(TEXT_ONLY)
        t.flush()

    def results(self, st, duration, per_sec, gens):
        t = self.t
        self.typing_logo()
        t.text(4, 8, 'wpm', GREY, DARK)
        t.text(4, 30, 'acc', GREY, DARK)
        for r, (a, b) in enumerate(zip(big(f"{st['wpm']:.0f}"), big(f"{st['acc']:.0f}%"))):
            t.text(5 + r, 8, a, YELLOW, DARK)
            t.text(5 + r, 30, b, YELLOW, DARK)
        for r, (label, value) in enumerate([
                ('test type', f'time {duration} english'), ('raw', f"{st['raw']:.0f}"),
                ('characters', f"{st['correct']}/{st['incorrect']}/{st['extra']}/{st['missed']}")]):
            t.text(4 + 2 * r, 52, label, GREY, DARK)
            t.text(5 + 2 * r, 52, value, YELLOW, DARK)
        series = [p[1] for p in per_sec] or [0]
        peak = max(max(series), 1)
        bw = 2 if len(series) <= 30 else 1
        h = 7
        for r in range(h):
            row = ''
            for v in series:
                level = v / peak * h - (h - 1 - r)
                row += (' ▁▂▃▄▅▆▇█'[max(0, min(8, int(level * 8)))] if level < 1 else '█') * bw
            t.text(11 + r, 8, '│', GREY, DARK)
            t.text(11 + r, 9, row, YELLOW, DARK)
        t.text(18, 8, '╰' + '─' * (len(series) * bw), GREY, DARK)
        t.text(19, 9, ''.join(('×' if p[2] else ' ').ljust(bw) for p in per_sec), ROSE, DARK)
        t.text(20, 8, f'raw wpm each second (peak {peak:.0f}), × = errors', GREY, DARK)
        c = t.text(22, 8, 'meanwhile the FPGA ran ', GREY, DARK)
        c = t.text(22, c, f'{gens:,}', YELLOW, DARK)
        t.text(22, c, ' Game of Life generations', GREY, DARK)
        t.text(23, 8, f'({gens * 128 * 128 / 1e9:.1f} billion cell updates) while reading your '
                      'keyboard', GREY, DARK)
        t.text(25, 8, 'tab / SW2 next test    esc back to the demo', GREY, DARK)
        t.scene(TEXT_ONLY)
        t.flush()
