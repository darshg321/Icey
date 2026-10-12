#!/usr/bin/env python3
"""Host side of the uart_flash example. Uses pyftdi on FTDI channel B, so it
works without being in the dialout group (it temporarily detaches ttyUSB1)."""
from pyftdi.serialext import serial_for_url

p = serial_for_url('ftdi://ftdi:2232h/2', baudrate=115200, timeout=0.5)
p.reset_input_buffer()
p.write(b'hello world'); print('echo     :', p.read(11))
p.write(b'i');          print('flash id :', p.read(3).hex(' '), '(expect ef 40 18)')
p.write(b'b');          print('button   :', p.read(1), "('1' = released)")
p.close()
