#!/usr/bin/env python3
"""Single vs quad SPI reads of the on-board W25Q128 flash, done by the FPGA.
Load the design first: make prog (in this folder). Read-only, except for the
VOLATILE quad-enable bit, which is restored at the end (and resets at power-off)."""
import sys
import time

from pyftdi.serialext import serial_for_url

p = serial_for_url('ftdi://ftdi:2232h/2', baudrate=3_000_000, timeout=2)
p.udev.set_latency_timer(1)
p.reset_input_buffer()


def txn(tx, dummy=0, nrx=0, quad=False):
    p.write(bytes([ord('T'), len(tx), *tx, dummy, nrx & 255, nrx >> 8, int(quad)]))
    r = bytearray()
    while len(r) < nrx + 4:
        c = p.read(nrx + 4 - len(r))
        if not c:
            sys.exit('flashtest: no reply. Did you `make prog`?')
        r += c
    return bytes(r[:nrx]), int.from_bytes(r[nrx:], 'little')


def ok(m): print(f'  \x1b[32m✔\x1b[0m {m}')
def bad(m): print(f'  \x1b[31m✘\x1b[0m {m}')


jid, _ = txn([0x9F], nrx=3)
(ok if jid == b'\xef\x40\x18' else bad)(f'JEDEC ID {jid.hex(" ")} (W25Q128JV = ef 40 18)')
sr1 = txn([0x05], nrx=1)[0][0]
sr2 = txn([0x35], nrx=1)[0][0]
print(f'    status: SR1=0x{sr1:02x} SR2=0x{sr2:02x}  (QE = SR2 bit 1 = {sr2 >> 1 & 1})')
if not sr2 & 2:
    txn([0x50])                                   # volatile status register write enable
    txn([0x31, sr2 | 2])                          # SR2 with QE set (volatile)
    sr2q = txn([0x35], nrx=1)[0][0]
    (ok if sr2q & 2 else bad)(f'quad enable set in the volatile register (SR2=0x{sr2q:02x})')

all_ok = True
for addr in (0x000000, 0x004000, 0x010000, 0x018000):
    a = [addr >> 16 & 255, addr >> 8 & 255, addr & 255]
    single, cs = txn([0x0B, *a], dummy=8, nrx=4096)
    quad, cq = txn([0x6B, *a], dummy=8, nrx=4096, quad=True)
    same = single == quad
    all_ok &= same
    blank = all(b == 0xFF for b in single)
    note = 'erased (all FF)' if blank else f'{single[:8].hex(" ")} ...'
    (ok if same else bad)(f'0x{addr:06x}: 4 KB single vs quad {"identical" if same else "DIFFER"}  [{note}]')
    if not same:
        diff = sum(1 for x, y in zip(single, quad) if x != y)
        print(f'      {diff} bytes differ; first: single {single[:8].hex()} quad {quad[:8].hex()}')
    if addr == 0:
        pre = single[:8] == bytes.fromhex('ff0000ff7eaa997e')
        print(f'      iCE40 bitstream preamble at 0x0: {"present" if pre else "not found"}'
              ' (flash holds the image written during bring-up)')
        ts, tq = cs / 24e6, cq / 24e6
        print(f'      single: {cs:,} clocks = {4096 / ts / 1e6:.2f} MB/s   '
              f'quad: {cq:,} clocks = {4096 / tq / 1e6:.2f} MB/s  ({cs / cq:.1f}x faster)')

if not sr2 & 2:
    txn([0x50])
    txn([0x31, sr2])                              # put QE back as it was
    print(f'    restored SR2=0x{txn([0x35], nrx=1)[0][0]:02x}')
print('PASS: quad reads match single reads' if all_ok else 'FAIL')
p.close()
