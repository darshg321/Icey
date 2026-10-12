#!/usr/bin/env python3
"""Icey hardware tests. Load the bridge first:  make prog   (in this folder)

    hwtest.py bus        SPI bus + MAX3421E revision register (no equipment)
    hwtest.py button     press SW2: LED1 lights in hardware, script reports it
    hwtest.py rgb        light RGB0/1/2 one at a time to record the colours
    hwtest.py led3       blink LED3 through the FTDI (channel B GPIO)
    hwtest.py sd         microSD: init, card ID, capacity, sector 0 (read-only)
    hwtest.py usb        USB host: detect + enumerate a keyboard, then echo keys
    hwtest.py sdwrite    write test on ONE unused sector (backed up + restored)
    hwtest.py sw3        press the reset button (do this last: wipes the design)
"""
import sys
import time

from pyftdi.serialext import serial_for_url

URL = 'ftdi://ftdi:2232h/2'

SD_CS, USB_CS, USB_RST, LED1 = 1, 2, 4, 8
RGB = [16, 32, 64]


def open_port():
    p = serial_for_url(URL, baudrate=3_000_000, timeout=1)
    p.udev.set_latency_timer(1)       # default 16 ms makes every round trip slow
    p.reset_input_buffer()
    return p


class Bridge:
    def __init__(self, port=None):
        self.p = port or open_port()
        self.outs = SD_CS | USB_CS | USB_RST
        self.set(self.outs)

    def close(self):
        self.p.close()

    def _read(self, n):
        b = bytearray()
        while len(b) < n:
            c = self.p.read(n - len(b))
            if not c:
                sys.exit(f'hwtest: bridge not answering ({len(b)}/{n} bytes). Did you `make prog`?')
            b += c
        return bytes(b)

    def set(self, v):
        self.outs = v
        self.p.write(bytes([ord('C'), v]))
        assert self._read(1) == b'k'

    def speed(self, hz):
        d = max(0, min(255, round(24e6 / (2 * hz)) - 1))
        self.p.write(bytes([ord('D'), d]))
        assert self._read(1) == b'k'
        return 24e6 / (2 * (d + 1))

    def inputs(self):
        self.p.write(b'I')
        return self._read(1)[0]

    def xfer(self, data):
        out = bytearray()
        data = bytes(data)
        for i in range(0, len(data), 256):
            chunk = data[i:i + 256]
            self.p.write(bytes([ord('X'), len(chunk) & 0xFF]) + chunk)
            out += self._read(len(chunk))
        return bytes(out)

    def xfer_cs(self, mask, data):
        """SPI exchange with chip selects (bit0 SD, bit1 USB) held low: 1 round trip."""
        data = bytes(data)
        assert 0 < len(data) <= 256
        self.p.write(bytes([ord('Y'), mask, len(data) & 0xFF]) + data)
        return self._read(len(data))

    def cs(self, which, active):
        v = self.outs | which if not active else self.outs & ~which
        self.set(v)


def ok(msg):
    print(f'  \x1b[32m✔\x1b[0m {msg}')


def bad(msg):
    print(f'  \x1b[31m✘\x1b[0m {msg}')


def info(msg):
    print(f'    {msg}')


# ------------------------------------------------------------ MAX3421E -----
class Max3421:
    RCVFIFO, SNDFIFO, SUDFIFO, RCVBC, SNDBC = 1, 2, 4, 6, 7
    USBIRQ, USBCTL, PINCTL, REVISION = 13, 15, 17, 18
    HIRQ, MODE, PERADDR, HCTL, HXFR, HRSL = 25, 27, 28, 29, 30, 31

    def __init__(self, br):
        self.b = br

    def wr(self, reg, *vals):
        self.b.xfer_cs(2, [(reg << 3) | 2, *vals])

    def rd(self, reg, n=1):
        r = self.b.xfer_cs(2, [reg << 3] + [0] * n)
        return r[1:] if n > 1 else r[1]

    def reset(self):
        self.b.set(self.b.outs & ~USB_RST)          # pulse RES#
        time.sleep(0.01)
        self.b.set(self.b.outs | USB_RST)
        time.sleep(0.01)
        self.wr(self.PINCTL, 0x18)                  # full-duplex SPI, INT active low
        self.wr(self.USBCTL, 0x20)                  # CHIPRES
        self.wr(self.USBCTL, 0x00)
        t = time.time()
        while not self.rd(self.USBIRQ) & 1:         # OSCOKIRQ: 12 MHz crystal running
            if time.time() - t > 1:
                return False
        return True


def test_bus(br):
    print('SPI bus / MAX3421E')
    idle = br.xfer([0xFF] * 4)
    (ok if idle == b'\xff' * 4 else bad)(f'idle bus reads {idle.hex(" ")} (pull-up on MISO)')
    m = Max3421(br)
    osc = m.reset()
    (ok if osc else bad)('MAX3421E oscillator OK (12 MHz crystal X1)' if osc else 'MAX3421E oscillator never started')
    rev = m.rd(m.REVISION)
    (ok if rev in (0x12, 0x13) else bad)(f'MAX3421E REVISION = 0x{rev:02x} (expect 0x12 or 0x13)')
    m.wr(m.MODE, 0xC1)                              # host mode (PERADDR is a host register)
    m.wr(m.PERADDR, 0x5A)
    back = m.rd(m.PERADDR)
    (ok if back == 0x5A else bad)(f'register write/read-back: wrote 0x5a, read 0x{back:02x}')
    m.wr(m.PERADDR, 0)


# --------------------------------------------------------- simple tests ----
def test_button(br):
    print('SW2: press and release it a few times (10 s). LED1 lights while held.')
    t, last, presses = time.time(), None, 0
    while time.time() - t < 10:
        pressed = not (br.inputs() & 1)
        if pressed != last:
            print(f'    {"PRESSED " if pressed else "released"}  ({time.time() - t:4.1f} s)')
            presses += pressed
            last = pressed
        time.sleep(0.01)
    (ok if presses else bad)(f'{presses} press(es) seen')


def test_rgb(br):
    print('RGB LED: note the colour of each step (5 s each)')
    for i, bit in enumerate(RGB):
        br.set((br.outs & ~sum(RGB)) | bit)
        print(f'    now lit: RGB{i} (FPGA pin {39 + i})', flush=True)
        time.sleep(5)
    br.set(br.outs & ~sum(RGB))


def test_led3(br):
    br.close()
    from pyftdi.gpio import GpioMpsseController
    g = GpioMpsseController()
    g.configure(URL, direction=1 << 11, frequency=1e6)   # BCBUS3 = wide-port bit 11
    print('LED3 (FTDI BCBUS3, active low): blinking for 5 s')
    for k in range(10):
        g.write(0 if k % 2 == 0 else 1 << 11)
        time.sleep(0.5)
    g.write(1 << 11)
    g.close()
    print('    done (LED3 off)')


def test_sw3(br):
    br.close()
    sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/tools')
    from iceyprog import Icey
    b = Icey()
    print(f'CDONE now = {int(b.cdone())} (1 = configured)')
    b.close()
    print('Press SW3 (reset) now (waiting up to 30 s)...', flush=True)
    b = Icey()
    t = time.time()
    while b.cdone() and time.time() - t < 30:
        time.sleep(0.05)
    d = b.cdone()
    b.close()
    (ok if not d else bad)(f'CDONE = {int(d)}: ' + ('FPGA reset (and stays blank: rev-1 flash boot bug). '
                                                   'LED2 should be lit.' if not d else 'FPGA did not reset'))


# ------------------------------------------------------------- microSD -----
class SD:
    def __init__(self, br):
        self.b = br

    def cmd(self, idx, arg=0, crc=0x01, extra=0):
        self.b.cs(SD_CS, True)
        f = bytes([0x40 | idx, arg >> 24 & 255, arg >> 16 & 255, arg >> 8 & 255, arg & 255, crc])
        r = self.b.xfer(f + b'\xff' * (8 + extra))[6:]
        for k, v in enumerate(r):
            if v != 0xFF:
                return v, r[k + 1:k + 1 + extra]
        return None, b''

    def end(self):
        self.b.cs(SD_CS, False)
        self.b.xfer(b'\xff')                       # let the card release MISO

    def data(self, idx, arg, n):
        """Command with a data block (CID/CSD/read sector): returns n bytes."""
        self.b.cs(SD_CS, True)
        f = bytes([0x40 | idx, arg >> 24 & 255, arg >> 16 & 255, arg >> 8 & 255, arg & 255, 0x01])
        r = self.b.xfer(f + b'\xff' * 16)[6:]
        r1 = next((v for v in r if v != 0xFF), None)
        if r1 != 0:
            self.end()
            return None
        buf = r[r.index(0) + 1:]
        t = time.time()
        while 0xFE not in buf:                     # wait for the data token
            if time.time() - t > 0.5:
                self.end()
                return None
            buf = self.b.xfer(b'\xff' * 16)
        buf = buf[buf.index(0xFE) + 1:]
        if len(buf) < n + 2:
            buf += self.b.xfer(b'\xff' * (n + 2 - len(buf)))
        self.end()
        return buf[:n]


def sd_init(br):
    """Initialise the card. Returns (SD, info dict) or (None, reason)."""
    s = SD(br)
    br.speed(400e3)
    br.cs(SD_CS, False)
    br.xfer(b'\xff' * 10)
    r1, _ = s.cmd(0, 0, 0x95); s.end()
    if r1 != 0x01:
        return None, 'no card'
    r1, r7 = s.cmd(8, 0x1AA, 0x87, 4); s.end()
    v2 = r1 == 0x01 and r7[-2:] == b'\x01\xaa'
    t = time.time()
    while True:
        s.cmd(55); s.end()
        r1, _ = s.cmd(41, 0x40000000 if v2 else 0); s.end()
        if r1 == 0:
            break
        if time.time() - t > 2:
            return None, 'init timed out'
    r1, ocr = s.cmd(58, extra=4); s.end()
    s.hc = bool(ocr and ocr[0] & 0x40)
    br.speed(6e6)
    info = {'type': 'SDHC/SDXC' if s.hc else 'SDSC'}
    cid = s.data(10, 0, 16)
    if cid:
        info['name'] = cid[3:8].decode('ascii', 'replace').strip()
        info['date'] = f'{2000 + ((cid[13] & 0x0F) << 4 | cid[14] >> 4)}-{cid[14] & 0x0F:02d}'
    csd = s.data(9, 0, 16)
    if csd and csd[0] >> 6 == 1:
        info['bytes'] = (((csd[7] & 0x3F) << 16 | csd[8] << 8 | csd[9]) + 1) * 512 * 1024
    return s, info


class Fat32:
    """Read-only FAT32 reader on top of SD sector reads."""
    def __init__(self, sd):
        self.sd = sd
        mbr = self.sector(0)
        if mbr[82:90] == b'FAT32   ':
            self.part = 0
        else:
            self.part = int.from_bytes(mbr[454:458], 'little')
        bs = self.sector(self.part)
        if bs[82:90] != b'FAT32   ':
            raise ValueError('exFAT' if bs[3:11] == b'EXFAT   ' else 'not FAT32')
        self.spc = bs[13]
        reserved = int.from_bytes(bs[14:16], 'little')
        fatsz = int.from_bytes(bs[36:40], 'little')
        self.fat = self.part + reserved
        self.data = self.fat + bs[16] * fatsz
        self.root = int.from_bytes(bs[44:48], 'little')
        self.label = bs[71:82].decode('ascii', 'replace').strip()

    def sector(self, lba):
        d = self.sd.data(17, lba if self.sd.hc else lba * 512, 512)
        if d is None:
            raise IOError(f'read of sector {lba} failed')
        return d

    def chain(self, c):
        while 2 <= c < 0x0FFFFFF8:
            yield c
            e = self.sector(self.fat + c * 4 // 512)
            c = int.from_bytes(e[c * 4 % 512:c * 4 % 512 + 4], 'little') & 0x0FFFFFFF

    def listdir(self, cluster=None, limit=200):
        out, lfn = [], {}
        for c in self.chain(cluster or self.root):
            for k in range(self.spc):
                sec = self.sector(self.data + (c - 2) * self.spc + k)
                for o in range(0, 512, 32):
                    e = sec[o:o + 32]
                    if e[0] == 0:
                        return out
                    if e[0] == 0xE5:
                        lfn = {}
                        continue
                    if e[11] == 0x0F:
                        part = (e[1:11] + e[14:26] + e[28:32]).decode('utf-16-le', 'ignore')
                        lfn[e[0] & 0x1F] = part.split('\x00')[0]
                        continue
                    if e[11] & 0x08:
                        lfn = {}
                        continue
                    short = e[0:8].decode('ascii', 'replace').strip()
                    ext = e[8:11].decode('ascii', 'replace').strip()
                    name = ''.join(lfn[i] for i in sorted(lfn)) if lfn else short + ('.' + ext if ext else '')
                    lfn = {}
                    if name in ('.', '..'):
                        continue
                    out.append({'name': name, 'dir': bool(e[11] & 0x10),
                                'cluster': int.from_bytes(e[20:22], 'little') << 16 | int.from_bytes(e[26:28], 'little'),
                                'size': int.from_bytes(e[28:32], 'little')})
                    if len(out) >= limit:
                        return out
        return out

    def read(self, entry, maxbytes=64 * 1024):
        data = bytearray()
        for c in self.chain(entry['cluster']):
            for k in range(self.spc):
                data += self.sector(self.data + (c - 2) * self.spc + k)
                if len(data) >= min(entry['size'], maxbytes):
                    return bytes(data[:min(entry['size'], maxbytes)])
        return bytes(data[:entry['size']])


def sd_write_block(s, lba, data):
    """CMD24 single-block write. Returns None on success, else an error string."""
    br = s.b
    a = lba if s.hc else lba * 512
    br.cs(SD_CS, True)
    f = bytes([0x40 | 24, a >> 24 & 255, a >> 16 & 255, a >> 8 & 255, a & 255, 0x01])
    r = br.xfer(f + b'\xff' * 8)[6:]
    r1 = next((v for v in r if v != 0xFF), None)
    if r1 != 0:
        s.end()
        return f'CMD24 rejected (R1={r1!r})'
    resp = br.xfer(b'\xff\xfe' + bytes(data) + b'\xff\xff' + b'\xff' * 4)[-4:]
    tok = next((v for v in resp if v != 0xFF), None)
    if tok is None or tok & 0x1F != 0x05:
        s.end()
        return f'data not accepted (token {tok!r})'
    t = time.time()
    while br.xfer(b'\xff' * 16)[-1] != 0xFF:      # card holds MISO low while busy
        if time.time() - t > 1:
            s.end()
            return 'card stayed busy'
    s.end()
    return None


def test_sdwrite(br):
    import os
    import random
    print('microSD write test (one unused sector, backed up and restored)')
    s, card = sd_init(br)
    if not s:
        bad(f'card init failed: {card}')
        return
    mbr = s.data(17, 0, 512)
    starts = [int.from_bytes(mbr[454 + 16 * k:458 + 16 * k], 'little')
              for k in range(4) if mbr[450 + 16 * k]]
    first = min(starts) if starts else 0
    if mbr[510:512] != b'\x55\xaa' or first < 8:
        bad(f'no safe gap before the first partition (starts at {first}); not writing')
        return
    lba = first // 2                              # middle of the gap, outside any partition
    orig = s.data(17, lba if s.hc else lba * 512, 512)
    if orig is None:
        bad('could not read the sector to back it up')
        return
    backup = os.path.expanduser(f'~/icey-sd-backup-sector{lba}.bin')
    open(backup, 'wb').write(orig)
    ok(f'sector {lba} (gap before partition at {first}) backed up to {backup}')
    info(f'original content: {"all zeros" if not any(orig) else "has data"}')
    pattern = bytes(random.getrandbits(8) for _ in range(512))
    t = time.time()
    err = sd_write_block(s, lba, pattern)
    dt = time.time() - t
    if err:
        bad(f'write failed: {err}')
        return
    back = s.data(17, lba if s.hc else lba * 512, 512)
    (ok if back == pattern else bad)(f'wrote 512 random bytes in {dt * 1e3:.0f} ms, read back: '
                                     + ('identical' if back == pattern else 'MISMATCH'))
    err = sd_write_block(s, lba, orig)
    back = s.data(17, lba if s.hc else lba * 512, 512)
    restored = err is None and back == orig
    (ok if restored else bad)('original sector restored and verified' if restored else
                              f'RESTORE FAILED ({err}); the original is saved in {backup}')
    if restored:
        os.remove(backup)
    br.speed(400e3)


def test_sd(br):
    print('microSD (read-only)')
    s = SD(br)
    br.speed(400e3)
    br.cs(SD_CS, False)
    br.xfer(b'\xff' * 10)                          # >= 74 clocks with CS high
    r1, _ = s.cmd(0, 0, 0x95); s.end()
    if r1 != 0x01:
        bad(f'CMD0 (go idle): got {r1!r}, expected 0x01. Is a card inserted?')
        return
    ok('CMD0: card responds over SPI')
    r1, r7 = s.cmd(8, 0x1AA, 0x87, 4); s.end()
    v2 = r1 == 0x01 and r7[-2:] == b'\x01\xaa'
    info(f'CMD8: {"SD v2+" if v2 else "SD v1 / MMC"} card')
    t = time.time()
    while True:
        s.cmd(55); s.end()
        r1, _ = s.cmd(41, 0x40000000 if v2 else 0); s.end()
        if r1 == 0:
            break
        if time.time() - t > 2:
            bad(f'ACMD41 init timed out (last R1 0x{r1:02x})')
            return
    ok(f'initialised in {time.time() - t:.2f} s')
    r1, ocr = s.cmd(58, extra=4); s.end()
    hc = bool(ocr and ocr[0] & 0x40)
    info(f'OCR {ocr.hex()}: {"SDHC/SDXC (block addressed)" if hc else "SDSC (byte addressed)"}')
    hz = br.speed(6e6)
    info(f'SPI clock raised to {hz / 1e6:.0f} MHz')

    cid = s.data(10, 0, 16)
    if cid:
        mfr = {0x01: 'Panasonic', 0x02: 'Toshiba/Kioxia', 0x03: 'SanDisk', 0x1B: 'Samsung',
               0x1D: 'AData', 0x27: 'Phison', 0x28: 'Lexar', 0x31: 'Silicon Power',
               0x41: 'Kingston', 0x74: 'Transcend', 0x76: 'Patriot', 0x82: 'Sony',
               0x9C: 'Angelbird/Hoodman'}.get(cid[0], f'0x{cid[0]:02x}')
        name = cid[3:8].decode('ascii', 'replace')
        year, month = 2000 + ((cid[13] & 0x0F) << 4 | cid[14] >> 4), cid[14] & 0x0F
        ok(f'card ID: manufacturer {mfr}, product "{name}", rev {cid[8] >> 4}.{cid[8] & 15}, '
           f'serial {int.from_bytes(cid[9:13], "big"):08x}, made {year}-{month:02d}')
    else:
        bad('CMD10 (read CID) failed')
    csd = s.data(9, 0, 16)
    if csd:
        if csd[0] >> 6 == 1:
            c_size = (csd[7] & 0x3F) << 16 | csd[8] << 8 | csd[9]
            cap = (c_size + 1) * 512 * 1024
        else:
            c_size = (csd[6] & 3) << 10 | csd[7] << 2 | csd[8] >> 6
            mult = 1 << (((csd[9] & 3) << 1 | csd[10] >> 7) + 2)
            cap = (c_size + 1) * mult * (1 << (csd[5] & 15))
        ok(f'capacity {cap / 1e9:.2f} GB')
    sec = s.data(17, 0, 512)
    if not sec:
        bad('CMD17 (read sector 0) failed')
        return
    sig = sec[510:512] == b'\x55\xaa'
    (ok if sig else bad)(f'sector 0 read, boot signature {"55 AA present" if sig else "missing"}')
    types = {0x01: 'FAT12', 0x04: 'FAT16', 0x06: 'FAT16', 0x07: 'exFAT/NTFS', 0x0B: 'FAT32',
             0x0C: 'FAT32 (LBA)', 0x0E: 'FAT16 (LBA)', 0x83: 'Linux', 0xEE: 'GPT protective'}
    if sec[3:11] in (b'EXFAT   ', b'MSDOS5.0', b'mkfs.fat'):
        info(f'no partition table: filesystem starts at sector 0 ({sec[3:11].decode().strip()})')
    for k in range(4):
        e = sec[446 + 16 * k:462 + 16 * k]
        if e[4]:
            start, size = int.from_bytes(e[8:12], 'little'), int.from_bytes(e[12:16], 'little')
            info(f'partition {k + 1}: {types.get(e[4], hex(e[4]))}, start sector {start}, '
                 f'{size * 512 / 1e9:.2f} GB')
    s.hc = hc
    try:
        fs = Fat32(s)
        files = fs.listdir()
        ok(f'FAT32 volume "{fs.label}": {len(files)} entries in the root directory')
        for f in files[:12]:
            info(f"  {'[dir] ' if f['dir'] else ''}{f['name']}" + ('' if f['dir'] else f"  ({f['size']:,} bytes)"))
    except (ValueError, IOError) as e:
        info(f'filesystem: {e} (file listing needs FAT32)')
    br.speed(400e3)


# ---------------------------------------------------------- USB host -------
RESULT = ['success', 'busy', 'bad request', 'undef', 'NAK', 'STALL', 'toggle error',
          'wrong PID', 'bad byte count', 'PID error', 'packet error', 'CRC error',
          'K error', 'J error', 'timeout', 'babble']
KEYS = {**{4 + i: c for i, c in enumerate('abcdefghijklmnopqrstuvwxyz')},
        **{30 + i: c for i, c in enumerate('1234567890')},
        40: '\n', 42: '\b', 43: '\t', 44: ' ', 45: '-', 46: '=', 47: '[', 48: ']', 49: '\\',
        51: ';', 52: "'", 53: '`', 54: ',', 55: '.', 56: '/'}
SHIFT = dict(zip('abcdefghijklmnopqrstuvwxyz1234567890-=[]\\;\'`,./',
                 'ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+{}|:"~<>?'))


class UsbHost(Max3421):
    def xfer_wait(self, token, ep=0, tries=200):
        for _ in range(tries):
            self.wr(self.HIRQ, 0x80)
            self.wr(self.HXFR, token | ep)
            t = time.time()
            while not self.rd(self.HIRQ) & 0x80:
                if time.time() - t > 0.5:
                    return 14
            r = self.rd(self.HRSL) & 0x0F
            if r != 4:                                # retry on NAK
                return r
        return 4

    def control_in(self, setup, maxpkt=8):
        self.wr(self.SUDFIFO, *setup)
        r = self.xfer_wait(0x10)                      # SETUP
        if r:
            raise IOError(f'SETUP: {RESULT[r]}')
        want = setup[6] | setup[7] << 8
        data = bytearray()
        self.wr(self.HCTL, 0x20)                      # data stage starts with DATA1
        while len(data) < want:
            r = self.xfer_wait(0x00)                  # IN
            if r:
                raise IOError(f'IN: {RESULT[r]}')
            n = self.rd(self.RCVBC)
            if n:
                data += self.rd(self.RCVFIFO, n) if n > 1 else bytes([self.rd(self.RCVFIFO)])
            self.wr(self.HIRQ, 0x04)                  # RCVDAVIRQ: free the FIFO
            if n < maxpkt:
                break
        r = self.xfer_wait(0xA0)                      # OUT handshake (status stage)
        if r:
            raise IOError(f'status: {RESULT[r]}')
        return bytes(data)

    def control_out(self, setup):
        self.wr(self.SUDFIFO, *setup)
        r = self.xfer_wait(0x10)
        if r:
            raise IOError(f'SETUP: {RESULT[r]}')
        r = self.xfer_wait(0x80)                      # IN handshake (status stage)
        if r:
            raise IOError(f'status: {RESULT[r]}')

    def string(self, idx, maxpkt):
        if not idx:
            return ''
        d = self.control_in([0x80, 6, idx, 3, 0x09, 0x04, 255, 0], maxpkt)
        return d[2:d[0]].decode('utf-16-le', 'replace')


class Keyboard:
    """Enumerates a boot keyboard on the USB host port; poll() returns new keys."""
    def __init__(self, br, wait=3.0):
        self.h = h = UsbHost(br)
        self.name = None
        if not h.reset():
            return
        h.wr(h.MODE, 0xC1)
        t, state = time.time(), 0
        while time.time() - t < wait:
            h.wr(h.HCTL, 0x04)
            state = h.rd(h.HRSL) >> 6 & 3
            if state:
                break
            time.sleep(0.1)
        if not state:
            return
        low = state == 1
        h.wr(h.MODE, 0xC1 | 0x08 | (0x02 if low else 0))
        h.wr(h.HCTL, 0x01)
        while h.rd(h.HCTL) & 0x01:
            pass
        time.sleep(0.2)
        h.wr(h.PERADDR, 0)
        try:
            mp = h.control_in([0x80, 6, 0, 1, 0, 0, 8, 0])[7]
            h.control_out([0x00, 5, 1, 0, 0, 0, 0, 0])
            time.sleep(0.02)
            h.wr(h.PERADDR, 1)
            dev = h.control_in([0x80, 6, 0, 1, 0, 0, 18, 0], mp)
            self.vidpid = (int.from_bytes(dev[8:10], 'little'), int.from_bytes(dev[10:12], 'little'))
            try:
                self.maker, self.product = h.string(dev[14], mp), h.string(dev[15], mp)
            except IOError:
                self.maker, self.product = '', ''
            cfg = h.control_in([0x80, 6, 0, 2, 0, 0, 9, 0], mp)
            total = int.from_bytes(cfg[2:4], 'little')
            cfg = h.control_in([0x80, 6, 0, 2, 0, 0, total & 255, total >> 8], mp)
            k, kbd, self.ep, kif = 0, False, None, 0
            while k < len(cfg):
                if cfg[k + 1] == 4:
                    kbd = cfg[k + 5:k + 8] == b'\x03\x01\x01'
                    iface = cfg[k + 2]
                if cfg[k + 1] == 5 and kbd and self.ep is None and cfg[k + 2] & 0x80:
                    self.ep, kif = cfg[k + 2] & 0x0F, iface
                k += max(cfg[k], 1)
            if self.ep is None:
                return
            h.control_out([0x00, 9, cfg[5], 0, 0, 0, 0, 0])
            h.control_out([0x21, 0x0B, 0, 0, kif, 0, 0, 0])
        except IOError:
            return
        name = self.product if self.product.startswith(self.maker) else f'{self.maker} {self.product}'
        self.name = name.strip() or f'{self.vidpid[0]:04x}:{self.vidpid[1]:04x}'
        self.toggle, self.prev = 0, set()

    def poll(self):
        """One interrupt-IN attempt (~5 ms). Returns a list of new key names."""
        if not self.name:
            return []
        h = self.h
        h.wr(h.HCTL, 0x20 if self.toggle else 0x10)
        h.wr(h.HIRQ, 0x80)
        h.wr(h.HXFR, self.ep)
        for _ in range(5):
            if h.rd(h.HIRQ) & 0x80:
                break
        else:
            return []
        if h.rd(h.HRSL) & 0x0F:
            return []                                  # NAK: nothing new
        n = h.rd(h.RCVBC)
        rep = h.rd(h.RCVFIFO, n) if n > 1 else b''
        h.wr(h.HIRQ, 0x04)
        self.toggle ^= 1
        if len(rep) < 3:
            return []
        keys = set(rep[2:8]) - {0}
        new = sorted(keys - self.prev)
        self.prev = keys
        names = {41: 'esc', 44: 'space', 40: 'enter', 87: '+', 86: '-', 46: '+', 45: '-',
                 79: 'right', 80: 'left'}
        return [names.get(k) or KEYS.get(k, '?') for k in new]


def test_usb(br):
    print('USB host (MAX3421E) — plug a keyboard into the board\'s other USB-C port')
    h = UsbHost(br)
    br.speed(6e6)
    if not h.reset():
        bad('MAX3421E oscillator did not start')
        return
    h.wr(h.MODE, 0xC1)                                # host, D+/D- pull-downs
    t = time.time()
    state = 0
    while time.time() - t < 15:
        h.wr(h.HCTL, 0x04)                            # SAMPLEBUS
        hrsl = h.rd(h.HRSL)
        state = hrsl >> 6 & 3                         # K (bit6), J (bit7)
        if state:
            break
        if time.time() - t < 0.2:
            print('    waiting for a device (15 s)...')
        time.sleep(0.2)
    if not state:
        bad('no device detected on the USB host port')
        return
    low = state == 1                                  # K state = low-speed device
    ok(f'device detected: {"low-speed (1.5 Mbit/s)" if low else "full-speed (12 Mbit/s)"}')
    h.wr(h.MODE, 0xC1 | 0x08 | (0x02 if low else 0))  # + SOF/keep-alive (+ low speed)
    h.wr(h.HCTL, 0x01)                                # bus reset
    while h.rd(h.HCTL) & 0x01:
        pass
    time.sleep(0.2)
    h.wr(h.PERADDR, 0)
    try:
        dev = h.control_in([0x80, 6, 0, 1, 0, 0, 8, 0])
        mp = dev[7]
        ok(f'device descriptor read at address 0 (max packet {mp})')
        h.control_out([0x00, 5, 1, 0, 0, 0, 0, 0])   # SET_ADDRESS 1
        time.sleep(0.02)
        h.wr(h.PERADDR, 1)
        dev = h.control_in([0x80, 6, 0, 1, 0, 0, 18, 0], mp)
        vid, pid = int.from_bytes(dev[8:10], 'little'), int.from_bytes(dev[10:12], 'little')
        ok(f'enumerated: VID {vid:04x}  PID {pid:04x}, USB {dev[3]}.{dev[2] >> 4}')
        try:
            info(f'manufacturer: {h.string(dev[14], mp)!r}')
            info(f'product:      {h.string(dev[15], mp)!r}')
        except IOError as e:
            info(f'(no string descriptors: {e})')
        cfg = h.control_in([0x80, 6, 0, 2, 0, 0, 9, 0], mp)
        total = int.from_bytes(cfg[2:4], 'little')
        cfg = h.control_in([0x80, 6, 0, 2, 0, 0, total & 255, total >> 8], mp)
        # find a boot keyboard interface and its interrupt-IN endpoint
        k, iface, ep, eplen, kbd = 0, None, None, 8, False
        while k < len(cfg):
            ln, typ = cfg[k], cfg[k + 1]
            if typ == 4:
                iface = cfg[k + 2]
                kbd = cfg[k + 5:k + 8] == b'\x03\x01\x01'
            if typ == 5 and kbd and ep is None and cfg[k + 2] & 0x80:
                ep, eplen = cfg[k + 2] & 0x0F, cfg[k + 4]
                kif = iface
            k += max(ln, 1)
        if ep is None:
            bad('device has no boot-keyboard interface (is it a keyboard?)')
            return
        h.control_out([0x00, 9, cfg[5], 0, 0, 0, 0, 0])         # SET_CONFIGURATION
        h.control_out([0x21, 0x0B, 0, 0, kif, 0, 0, 0])         # SET_PROTOCOL boot
        ok(f'configured: boot keyboard on interface {kif}, endpoint 0x8{ep}')
    except IOError as e:
        bad(f'enumeration failed: {e}')
        return
    print('\n  Type on the keyboard. Keys travel keyboard -> MAX3421E -> FPGA -> USB -> here.')
    print('  Press Esc on the keyboard (or Ctrl-C here) to finish.\n  > ', end='', flush=True)
    toggle, prev, typed = 0, set(), 0
    try:
        while True:
            h.wr(h.HCTL, 0x20 if toggle else 0x10)
            r = h.xfer_wait(0x00, ep, tries=1)
            if r == 0:
                n = h.rd(h.RCVBC)
                rep = h.rd(h.RCVFIFO, n) if n > 1 else b''
                h.wr(h.HIRQ, 0x04)
                toggle ^= 1
                if len(rep) >= 3:
                    keys = set(rep[2:8]) - {0}
                    shift = rep[0] & 0x22
                    for kc in sorted(keys - prev):
                        if kc == 41:                         # Esc
                            print()
                            ok(f'{typed} key presses received through the USB host port')
                            return
                        ch = KEYS.get(kc)
                        if ch:
                            ch = SHIFT.get(ch, ch) if shift else ch
                            print('\b \b' if ch == '\b' else (ch + ('  > ' if ch == '\n' else '')),
                                  end='', flush=True)
                            typed += 1
                    prev = keys
            elif r not in (4,):
                time.sleep(0.005)
            time.sleep(0.008)
    except KeyboardInterrupt:
        print()
        ok(f'{typed} key presses received through the USB host port')


def main():
    tests = {'bus': test_bus, 'button': test_button, 'rgb': test_rgb, 'led3': test_led3,
             'sd': test_sd, 'sdwrite': test_sdwrite, 'usb': test_usb, 'sw3': test_sw3}
    if len(sys.argv) != 2 or sys.argv[1] not in tests:
        sys.exit(__doc__)
    br = Bridge()
    try:
        tests[sys.argv[1]](br)
    finally:
        try:
            br.close()
        except Exception:
            pass


if __name__ == '__main__':
    main()
