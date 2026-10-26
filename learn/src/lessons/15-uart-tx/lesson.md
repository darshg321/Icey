---
title: Icey says hello
part: 3
blurb: A serial transmitter from scratch, so your designs can finally talk back. Baud rates, framing, and a message ROM.
---

LEDs are a terrible way to find out what a design is doing. Eight of them give you one byte, at whatever speed your eyes can read. This lesson gives Icey a voice: a serial port, sending text to your computer through the same USB cable you program it with. Every project after this one uses it, for output, for debugging, or both.

## How serial works

The FT2232H on Icey has a second channel that's a plain serial port, called a UART (universal asynchronous receiver-transmitter). Two FPGA pins connect to it: `TX`, which carries bits from the FPGA to the computer, and `RX`, which carries them back. On Linux it shows up as `/dev/ttyUSB1`.

The protocol is older than personal computers and very simple. The line sits at 1 when idle. To send a byte:

1. Drive the line to 0 for one bit-time. This is the *start bit*; the falling edge tells the receiver a byte is coming.
2. Send the eight data bits, **least significant bit first**, one bit-time each.
3. Drive the line to 1 for one bit-time, the *stop bit*. Then it's idle again, or the next start bit can follow straight away.

@widget uartframe

There's no clock wire. The two ends agree on the speed in advance, and the receiver times every bit from the start bit's falling edge. The speed is the *baud rate*, in bits per second. 115,200 is the usual choice and it's what we'll use.

At 12 MHz, one bit lasts 12,000,000 / 115,200 = 104.17 clocks. Round it to 104 and you're 0.16% fast, which is fine: a UART receiver tolerates a few percent of error before it starts misreading bits, because it only has to stay in step for ten bits before the next start bit resynchronises it.

That tolerance matters on Icey, because the 12 MHz comes from the iCE40's internal oscillator, which the datasheet only promises to within 10%. A 10% error would be too much. In practice the chips are much closer than that: on the bring-up board, 115,200 baud ran without a single error, and so did 3,000,000 baud. If you ever see garbage characters, the oscillator is the first suspect, and the fix is a crystal on header pin P4.

## The transmitter

The transmitter is a state machine with a counter for timing and a shift register for the data. It sits idle with `tx` high until someone raises `send` for one clock. Then it grabs the byte, and sends the ten bits, holding each one for `CLKS_PER_BIT` clocks. While it's doing that, `busy` is high, so whoever's feeding it bytes knows to wait.

One tidy way to do it is to put the whole frame into a 10-bit shift register: `{1'b1, data, 1'b0}`, the stop bit, the data, and the start bit at the bottom. Then you send bit 0, shift right, and repeat ten times. Shift 1s in at the top as you go, so whatever's left in the register after the last bit is the idle level anyway.

Make `tx` a register, not a combinational output. A glitch on a combinational output is invisible to an LED but can look like a start bit to a UART receiver.

@exercise uart-tx

The board in this exercise has a terminal connected to `TX`. Press SW2 and it sends the next letter of the alphabet.

## A message

To send a whole string, you need two more things: somewhere to keep the characters, and something that feeds them to the transmitter one at a time.

For the storage, a `case` statement works fine as a small read-only memory:

```verilog
reg [7:0] char;
always @(*) begin
  case (index)
    0: char = "H";
    1: char = "e";
    // ...
    default: char = 8'h0a;  // newline
  endcase
end
```

Verilog lets you write a single character in double quotes and gives you its 8-bit ASCII code. (A longer string in quotes becomes one long number, 8 bits per character, which is handy but awkward to index. The `case` is easier to read.)

The feeder is another small state machine: if the transmitter isn't busy and there are characters left, raise `send` for one clock and move `index` on. When the string's finished, wait a second and start again.

There's a subtle bug waiting in that description. If you raise `send` on the same clock that you see `busy` low, then on the next clock `busy` might *still* be low, because the transmitter only noticed `send` on that edge. Then the feeder sends the next character at once, and the transmitter misses it. Think about how many clocks it takes from `send` going high to `busy` going high, and make sure your feeder waits at least that long.

@exercise hello

## Seeing it on your computer

Build it for Icey and load it. Then open the serial port:

```sh
~/.local/share/icey/venv/bin/pyserial-miniterm /dev/ttyUSB1 115200
```

(Press Ctrl+] to quit.) On Linux you may need to add yourself to the `dialout` group to open the port: `sudo usermod -aG dialout $USER`, then log out and in again. Or use the terminal on this page: in Chrome or Edge, **connect a real Icey** in the board panel opens the same port. The board's FTDI chip shows up as two serial ports, and the UART is the second.

If you see your message once a second, the FPGA is talking. Keep this transmitter; you'll use it in nearly every project from here on.
