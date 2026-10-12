"""Monkeytype-style typing test for the Icey showcase.

Every keystroke comes from the keyboard plugged into the *board*: keyboard ->
MAX3421E USB host -> FPGA (SPI bridge) -> USB -> this PC. While you type, the
FPGA runs the Game of Life flat out in the background.

Used by life_show.py (press `t`, or start it with --typing).
"""
import random
import sys
import time

import numpy as np

# "serika dark", Monkeytype's default theme
BG = (50, 52, 55)
SUB = (100, 102, 105)
TEXT = (209, 208, 197)
MAIN = (226, 183, 20)
ERR = (202, 71, 84)
ERR_EXTRA = (126, 42, 51)

WORDS = """the be to of and a in that have it for not on with he as you do at this but his
by from they we say her she or an will my one all would there their what so up out if
about who get which go me when make can like time no just him know take people into
year your good some could them see other than then now look only come its over think
also back after use two how our work first well way even new want because any these
give day most us great between need large often hand high place hold turn without
point world still learn plant cover food sun four state keep eye never last let thought
city tree cross farm hard start might story saw far sea draw left late run while press
close night real life few north open seem together next white children begin got walk
example ease paper group always music those both mark book letter until mile river car
feet care second enough plain girl usual young ready above ever red list though feel
talk bird soon body dog family direct pose leave song measure door product black short
numeral class wind question happen complete ship area half rock order fire south
problem piece told knew pass since top whole king space heard best hour better true
during hundred five remember step early hold west ground interest reach fast verb sing
listen six table travel less morning ten simple several vowel toward war lay against
pattern slow center love person money serve appear road map rain rule govern pull cold
notice voice unit power town fine certain fly fall lead cry dark machine note wait plan
figure star box noun field rest correct able pound done beauty drive stood contain
front teach week final gave green oh quick develop ocean warm free minute strong
special mind behind clear tail produce fact street inch multiply nothing course stay
wheel full force blue object decide surface deep moon island foot system busy test
record boat common gold possible plane stead dry wonder laugh thousand ago ran check
game shape equate hot miss brought heat snow tire bring yes distant fill east paint
language among grand ball yet wave drop heart present heavy dance engine position arm
wide sail material size vary settle speak weight general ice matter circle pair include
divide syllable felt perhaps pick sudden count square reason length represent art
subject region energy hunt probable bed brother egg ride cell believe fraction forest
sit race window store summer train sleep prove lone leg exercise wall catch mount wish
sky board joy winter sat written wild instrument kept glass grass cow job edge sign
visit past soft fun bright gas weather month million bear finish happy hope flower
clothe strange gone jump baby eight village meet root buy raise solve metal whether
push seven paragraph third shall held hair describe cook floor either result burn hill
safe cat century consider type law bit coast copy phrase silent tall sand soil roll
temperature finger industry value fight lie beat excite natural view sense ear else
quite broke case middle kill son lake moment scale loud spring observe child straight
consonant nation dictionary milk speed method organ pay age section dress cloud
surprise quiet stone tiny climb cool design poor lot experiment bottom key iron single
stick flat twenty skin smile crease hole trade melody trip office receive row mouth
exact symbol die least trouble shout except wrote seed tone join suggest clean break
lady yard rise bad blow oil blood touch grew cent mix team wire cost lost brown wear
garden equal sent choose fell fit flow fair bank collect save control decimal gentle
woman captain practice separate difficult doctor please protect noon whose locate ring
character insect caught period indicate radio spoke atom human history effect electric
expect crop modern element hit student corner party supply bone rail imagine provide
agree thus capital chair danger fruit rich thick soldier process operate guess
necessary sharp wing create neighbor wash bat rather crowd corn compare poem string
bell depend meat rub tube famous dollar stream fear sight thin triangle planet hurry
chief colony clock mine tie enter major fresh search send yellow gun allow print dead
spot desert suit current lift rose continue block chart hat sell success company
subtract event particular deal swim term opposite wife shoe shoulder spread arrange
camp invent cotton born determine quart nine truck noise level chance gather shop
stretch throw shine property column molecule select wrong gray repeat require broad
prepare salt nose plural anger claim continent oxygen sugar death pretty skill women
season solution magnet silver thank branch match suffix especially fig afraid huge
sister steel discuss forward similar guide experience score apple bought led pitch coat
mass card band rope slip win dream evening condition feed tool total basic smell valley
nor double seat arrive master track parent shore division sheet substance favor connect
post spend chord fat glad original share station dad bread charge proper bar offer
segment slave duck instant market degree populate chick dear enemy reply drink occur
support speech nature range steam motion path liquid log meant quotient teeth shell
neck""".split()

HELP = 'tab restart   esc back to the demo   SW2 restart'


def fg(c):
    return f'\x1b[38;2;{c[0]};{c[1]};{c[2]}m'


def bgc(c):
    return f'\x1b[48;2;{c[0]};{c[1]};{c[2]}m'


R = '\x1b[0m' + bgc(BG)
BOLD = '\x1b[1m'

BIG = {  # 3x5 digits for the countdown / results
    '0': ['███', '█ █', '█ █', '█ █', '███'], '1': [' █ ', '██ ', ' █ ', ' █ ', '███'],
    '2': ['███', '  █', '███', '█  ', '███'], '3': ['███', '  █', '███', '  █', '███'],
    '4': ['█ █', '█ █', '███', '  █', '  █'], '5': ['███', '█  ', '███', '  █', '███'],
    '6': ['███', '█  ', '███', '█ █', '███'], '7': ['███', '  █', '  █', '  █', '  █'],
    '8': ['███', '█ █', '███', '█ █', '███'], '9': ['███', '█ █', '███', '  █', '███'],
    '%': ['█ █', '  █', ' █ ', '█  ', '█ █'], ' ': ['   '] * 5,
}


def big(s):
    return [' '.join(BIG.get(c, BIG[' '])[r] for c in s) for r in range(5)]


class TypingTest:
    def __init__(self, show):
        self.show = show
        self.s = show.s
        self.duration = 30
        self.rgb_state = None

    # -------------------------------------------------------------- output --
    def at(self, row, col):
        return f'\x1b[{row + 1};{col + 1}H'

    def clear(self):
        sys.stdout.write(bgc(BG) + '\x1b[2J')

    def rgb(self, bits):
        if bits != self.rgb_state:
            self.rgb_state = bits
            self.show.rgb(bits)

    # -------------------------------------------------------------- layout --
    def layout(self, width):
        lines, line, used = [], [], 0
        for i, w in enumerate(self.words):
            n = max(len(w), len(self.typed[i]) if i < len(self.typed) else 0) + 1
            if used + n > width and line:
                lines.append(line)
                line, used = [], 0
            line.append(i)
            used += n
        if line:
            lines.append(line)
        return lines

    def draw(self, started, remaining, wpm_live):
        cols, rows = self.s.cols, self.s.lines
        width = min(cols - 8, 90)
        left = (cols - width) // 2
        top = max(2, rows // 2 - 6)
        out = [bgc(BG)]
        # header: mode selector, or live timer + wpm
        out.append(self.at(top - 1, left) + '\x1b[K')
        if not started:
            sel = '  '.join((fg(MAIN) if d == self.duration else fg(SUB)) + str(d)
                            for d in (15, 30, 60))
            out.append(self.at(top - 1, left) + fg(SUB) + 'time  ' + sel + fg(SUB) +
                       '    (1 / 2 / 3)   start typing to begin')
        else:
            out.append(self.at(top - 1, left) + BOLD + fg(MAIN) + f'{int(remaining + 0.999)}' + R +
                       fg(SUB) + f'   {wpm_live:.0f} wpm')
        # words: 3 visible lines, current word on line 1 or 2
        lines = self.layout(width)
        cur_line = next(k for k, ln in enumerate(lines) if self.cur in ln)
        first = max(0, cur_line - 1)
        for k in range(3):
            row = top + 1 + k * 2
            out.append(self.at(row, 0) + '\x1b[K' + self.at(row, left))
            if first + k >= len(lines):
                continue
            for i in lines[first + k]:
                w = self.words[i]
                t = self.typed[i] if i < len(self.typed) else ''
                for j in range(max(len(w), len(t))):
                    caret = i == self.cur and j == len(t)
                    if j < len(t):
                        c = (TEXT if j < len(w) and t[j] == w[j] else ERR if j < len(w) else ERR_EXTRA)
                        ch = w[j] if j < len(w) else t[j]
                    else:
                        c, ch = SUB, w[j]
                    if i < self.cur and j >= len(t):
                        c = ERR                          # skipped letters
                    out.append((bgc(MAIN) + fg(BG) if caret else fg(c)) + ch + R)
                caret_space = i == self.cur and len(t) >= len(w)
                out.append((bgc(MAIN) + ' ' + R) if caret_space else ' ')
        out.append(self.at(top + 8, left) + fg(SUB) + HELP + '\x1b[K')
        out.append(self.at(top + 10, left) + fg(SUB) +
                   'keys travel: keyboard → MAX3421E USB host → FPGA → USB → this PC' + '\x1b[K')
        sys.stdout.write(''.join(out))
        sys.stdout.flush()

    # --------------------------------------------------------------- stats --
    def stats(self, elapsed):
        correct_chars = incorrect = extra = missed = 0
        for i, w in enumerate(self.words[:self.cur + 1]):
            t = self.typed[i] if i < len(self.typed) else ''
            done = i < self.cur
            for j, ch in enumerate(w):
                if j < len(t):
                    if t[j] == ch:
                        correct_chars += 1
                    else:
                        incorrect += 1
                elif done:
                    missed += 1
            extra += max(0, len(t) - len(w))
        # Monkeytype-style wpm: characters of fully correct words (+ their spaces)
        good = sum(len(w) + 1 for i, w in enumerate(self.words[:self.cur])
                   if self.typed[i] == w)
        if self.cur < len(self.typed) and self.typed[self.cur] == self.words[self.cur]:
            good += len(self.words[self.cur])
        minutes = max(elapsed, 1e-6) / 60
        wpm = good / 5 / minutes
        raw = (self.keystrokes - self.backspaces) / 5 / minutes
        acc = 100 * self.correct_keys / max(1, self.correct_keys + self.wrong_keys)
        return dict(wpm=wpm, raw=raw, acc=acc, correct=correct_chars, incorrect=incorrect,
                    extra=extra, missed=missed)

    # ---------------------------------------------------------------- test --
    def new_test(self):
        rng = random.Random()
        self.words = [rng.choice(WORDS) for _ in range(400)]
        self.typed = ['']
        self.cur = 0
        self.keystrokes = self.backspaces = self.correct_keys = self.wrong_keys = 0
        self.per_sec = []              # (wpm so far, raw that second, errors that second)

    def key(self, k):
        """Apply one key. Returns True if it was a typing key."""
        w = self.words[self.cur]
        t = self.typed[self.cur]
        if k == '\b':
            if t:
                self.typed[self.cur] = t[:-1]
                self.backspaces += 1
            elif self.cur > 0 and self.typed[self.cur - 1] != self.words[self.cur - 1]:
                self.typed.pop()           # back into a wrong word, like Monkeytype
                self.cur -= 1
            self.rgb(0x40 if self.ok_so_far() else 0x10)
            return True
        if k == 'space':
            if not t:
                return True                # Monkeytype ignores space at a word start
            self.keystrokes += 1
            if t == w:
                self.correct_keys += 1
            else:
                self.wrong_keys += 1
            self.cur += 1
            self.typed.append('')
            self.rgb(0x40 if t == w else 0x10)
            return True
        if len(k) == 1 and k.isalpha():
            self.keystrokes += 1
            good = len(t) < len(w) and w[len(t)] == k
            self.correct_keys += good
            self.wrong_keys += not good
            self.sec_errors += not good
            self.typed[self.cur] = t + k
            self.rgb(0x40 if self.ok_so_far() else 0x10)
            return True
        return False

    def ok_so_far(self):
        t, w = self.typed[self.cur], self.words[self.cur]
        return w.startswith(t)

    def run(self):
        """Runs tests until esc. Returns normally (back to the show)."""
        kbd = self.show.kbd
        if not (kbd and kbd.name):
            self.clear()
            sys.stdout.write(self.at(self.s.lines // 2, 4) + fg(TEXT) +
                             'Plug a keyboard into the board\'s USB-C port for the typing test.')
            sys.stdout.flush()
            time.sleep(3)
            return
        life = self.show.b
        while True:
            self.new_test()
            self.clear()
            started, t0 = False, None
            self.sec_errors = 0
            last_draw = 0
            last_sec_keys = 0
            btn_prev = True
            self.rgb(0)
            self.draw(False, self.duration, 0)
            restart = False
            while True:
                keys = kbd.poll()
                released = bool(self.show.io.inputs() & 1)
                if btn_prev and not released:
                    keys = keys + ['tab']
                btn_prev = released
                dirty = False
                for k in keys:
                    if k == 'esc':
                        self.rgb(0)
                        return
                    if k in ('tab', '\t'):
                        restart = True
                        break
                    if not started and k in ('1', '2', '3'):
                        self.duration = {'1': 15, '2': 30, '3': 60}[k]
                        dirty = True
                        continue
                    if self.key(k):
                        dirty = True
                        if not started:
                            started, t0 = True, time.time()
                            gen0 = life.snapshot()[0]
                            life.speed(0)          # Life runs flat out while you type
                            last_sec = t0
                if restart:
                    break
                now = time.time()
                if started:
                    elapsed = now - t0
                    while now - last_sec >= 1 and len(self.per_sec) < self.duration:
                        st = self.stats(len(self.per_sec) + 1)
                        raw_sec = (self.keystrokes - last_sec_keys) * 60 / 5
                        last_sec_keys = self.keystrokes
                        self.per_sec.append((st['wpm'], raw_sec, self.sec_errors))
                        self.sec_errors = 0
                        last_sec += 1
                    if elapsed >= self.duration:
                        life.speed(255)
                        gens = life.snapshot()[0] - gen0
                        if not self.results(self.stats(self.duration), gens):
                            self.rgb(0)
                            return
                        break
                if dirty or (started and now - last_draw > 0.2):
                    remaining = self.duration - (now - t0) if started else self.duration
                    self.draw(started, remaining, self.stats(now - t0)['wpm'] if started else 0)
                    last_draw = now
            if restart:
                life.speed(255)
                continue

    # ------------------------------------------------------------- results --
    def results(self, st, gens):
        """Shows the results. Returns True to run another test, False for esc."""
        self.clear()
        cols, rows = self.s.cols, self.s.lines
        left = max(2, (cols - 76) // 2)
        top = max(1, rows // 2 - 11)
        o = [bgc(BG)]
        o.append(self.at(top, left) + fg(SUB) + 'wpm' + self.at(top, left + 22) + 'acc')
        for r, (a, b) in enumerate(zip(big(f"{st['wpm']:.0f}"), big(f"{st['acc']:.0f}%"))):
            o.append(self.at(top + 1 + r, left) + fg(MAIN) + a + self.at(top + 1 + r, left + 22) + b)
        o.append(self.at(top + 1, left + 44) + fg(SUB) + 'test type')
        o.append(self.at(top + 2, left + 44) + fg(MAIN) + f'time {self.duration}' + fg(SUB) + '  english')
        o.append(self.at(top + 3, left + 44) + fg(SUB) + 'raw')
        o.append(self.at(top + 4, left + 44) + fg(MAIN) + f"{st['raw']:.0f}")
        o.append(self.at(top + 5, left + 44) + fg(SUB) + 'characters')
        o.append(self.at(top + 6, left + 44) + fg(MAIN) +
                 f"{st['correct']}/{st['incorrect']}/{st['extra']}/{st['missed']}")
        # per-second wpm bars with error marks
        chart_top = top + 9
        h = 6
        series = [p[1] for p in self.per_sec] or [0]       # raw wpm in each second
        peak = max(max(series), 1)
        bw = 2 if len(series) <= 36 else 1
        blocks = ' ▁▂▃▄▅▆▇█'
        for r in range(h):
            line = []
            for v in series:
                level = v / peak * h - (h - 1 - r)
                ch = blocks[max(0, min(8, int(level * 8)))] if level < 1 else '█'
                line.append(ch * bw)
            o.append(self.at(chart_top + r, left) + fg(SUB) + '│' + fg(MAIN) + ''.join(line))
        errs = ''.join(('×' if p[2] else ' ').ljust(bw) for p in self.per_sec)
        o.append(self.at(chart_top + h, left) + fg(SUB) + '└' + '─' * (len(series) * bw))
        o.append(self.at(chart_top + h + 1, left + 1) + fg(ERR) + errs)
        o.append(self.at(chart_top + h + 1, left + len(series) * bw + 3) + fg(SUB) +
                 f'raw wpm each second (peak {peak:.0f}), × = errors')
        o.append(self.at(chart_top + h + 3, left) + fg(SUB) + 'meanwhile the FPGA ran ' + fg(MAIN) +
                 f'{gens:,}' + fg(SUB) + ' Game of Life generations in the background')
        o.append(self.at(chart_top + h + 4, left) + fg(SUB) +
                 f'({gens * 128 * 128 / 1e9:.1f} billion cell updates) while reading your keyboard')
        o.append(self.at(chart_top + h + 6, left) + fg(SUB) + 'tab / SW2 next test    esc back to the demo')
        sys.stdout.write(''.join(o))
        sys.stdout.flush()
        self.rgb(0x40 if st['acc'] >= 95 else 0x20)
        btn_prev = True
        while True:
            keys = self.show.kbd.poll()
            released = bool(self.show.io.inputs() & 1)
            if btn_prev and not released:
                return True
            btn_prev = released
            if 'esc' in keys:
                return False
            if 'tab' in keys or '\t' in keys or 'enter' in keys:
                return True
