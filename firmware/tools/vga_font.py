#!/usr/bin/env python3
"""vga_font - the 8x16 font ROM for the VGA text layer in showcase_vga.ice.

Takes ASCII 0x20-0x7E from a Linux console font (Terminus Bold 16 by
default, SIL Open Font License) and fills codes 0x00-0x1F with the
block, bar and box glyphs the show draws with (see GLYPHS; the show's
vga_text.py uses the same table). Prints the Verilog initial block.

    vga_font.py [font.psf.gz] > font.vh
"""
import gzip
import struct
import sys

PSF = '/usr/share/consolefonts/Uni2-TerminusBold16.psf.gz'

# code -> character, codes 0x00-0x1F (0x00 stays blank)
GLYPHS = ' █▀▁▂▃▄▅▆▇▏▎▍▌▋▊▉─│╭╮╰╯✔✘○×…·→•░'


def load_psf1(path):
    d = gzip.open(path).read()
    assert d[:2] == b'\x36\x04', 'PSF1 fonts only'
    mode, h = d[2], d[3]
    n = 512 if mode & 1 else 256
    assert h == 16
    glyphs = [d[4 + i * h:4 + (i + 1) * h] for i in range(n)]
    uni, p, i = {}, 4 + n * h, 0
    while mode & 2 and i < n and p + 2 <= len(d):
        u, = struct.unpack('<H', d[p:p + 2])
        p += 2
        if u == 0xFFFF:
            i += 1
        elif u != 0xFFFE:
            uni.setdefault(chr(u), i)
    return glyphs, uni


def drawn(ch):
    """Glyphs drawn here (blocks and bars must tile exactly, cell to cell)."""
    rows = [0] * 16
    if ch == '█':
        rows = [0xFF] * 16
    elif ch == '▀':
        rows = [0xFF] * 8 + [0] * 8
    elif '▁' <= ch <= '▇':                       # lower 1/8 .. 7/8
        k = (ord(ch) - ord('▁') + 1) * 2
        rows = [0] * (16 - k) + [0xFF] * k
    elif '▉' <= ch <= '▏':                       # left 7/8 .. 1/8
        k = ord('▏') - ord(ch) + 1
        rows = [(0xFF << (8 - k)) & 0xFF] * 16
    elif ch == '✔':
        pix = ['........', '........', '........', '......##', '.....###',
               '.....##.', '....###.', '#..###..', '##.##...', '#####...',
               '.###....', '..#.....', '........', '........', '........', '........']
        rows = [int(r.replace('.', '0').replace('#', '1'), 2) for r in pix]
    elif ch == '○':
        pix = ['........', '........', '........', '..####..', '.##..##.',
               '##....##', '#......#', '#......#', '#......#', '##....##',
               '.##..##.', '..####..', '........', '........', '........', '........']
        rows = [int(r.replace('.', '0').replace('#', '1'), 2) for r in pix]
    else:
        return None
    return bytes(rows)


def rom(path=PSF):
    glyphs, uni = load_psf1(path)
    out = [bytes(16)] * 128
    for c in range(0x20, 0x7F):
        out[c] = glyphs[uni.get(chr(c), c)]
    for c, ch in enumerate(GLYPHS):
        if c == 0:
            continue
        g = drawn(ch)
        if g is None:
            if ch not in uni:
                sys.exit(f'vga_font: {ch!r} is not in {path}')
            g = glyphs[uni[ch]]
        out[c] = g
    return out


def verilog(out):
    lines = ['// 8x16 font: ASCII from Terminus Bold 16 (SIL Open Font License),',
             '// codes 0-31 = ' + GLYPHS[1:] + '  (tools/vga_font.py)',
             'initial begin']
    for c, g in enumerate(out):
        lines.append('  ' + ' '.join(f'font[{c * 16 + r}]=8\'h{b:02x};' for r, b in enumerate(g)))
    lines.append('end')
    return '\n'.join(lines)


if __name__ == '__main__':
    print(verilog(rom(sys.argv[1] if len(sys.argv) > 1 else PSF)))
