---
title: Listening, and a reaction timer
part: 3
blurb: A serial receiver, random numbers from a shift register, turning binary into decimal, and a game that measures your reflexes in milliseconds.
---

The transmitter from the last lesson lets Icey talk. This one lets it listen, and then puts everything from Part 1 and Part 3 so far into one project: a reaction timer that waits a random time, lights the LED, and reports how many milliseconds you took to hit the button.

## Receiving

The receiver has a harder job than the transmitter. The transmitter decides when bits happen. The receiver has to work it out from the line alone, with no clock wire to help.

It starts by waiting for the line to drop from 1 to 0, the start bit. But a 0 on the line might also be a glitch, so it waits half a bit-time and checks again. If the line is still 0, this is a real start bit, and the receiver is now lined up with the *middle* of it. From there, it waits one whole bit-time at a time, sampling each data bit right in the middle, as far as possible from the edges where the line changes. After the eighth data bit it waits once more and checks the stop bit is 1. If it is, the byte is good: it raises a `valid` pulse for one clock, with the byte on `data`.

```
line:   ‾‾‾‾\___start___/‾‾bit0‾‾\__bit1__/‾ ...
                 ^ check     ^ sample  ^ sample
             (half a bit)  (then one bit at a time)
```

The `rx` pin comes from another chip running on its own clock, so it goes through a two-flip-flop synchroniser first, just like the button in lesson 8. Every external signal gets one.

@exercise uart-rx

The board in that exercise wires your receiver to the transmitter from last lesson, so whatever you type comes straight back. That's called an echo, and it's the first thing anyone does with a new serial port.

## Random numbers from a shift register

A reaction timer needs to wait a *random* time, or you'd learn the rhythm. Where does randomness come from in a circuit that's completely deterministic?

Mostly, it doesn't. The usual trick is a *linear feedback shift register*, an LFSR. Take a shift register, and instead of shifting in a fixed bit, shift in the XOR of a few of its own bits:

```verilog
reg [15:0] lfsr = 16'hACE1;     // any start value except zero
always @(posedge clk)
  lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
```

With the right choice of which bits to XOR (the *taps*), the register walks through every one of its 65,535 non-zero values before repeating, in an order that looks thoroughly scrambled. It isn't really random. Start it from the same value and you get the same sequence every time. But it's cheap, one XOR gate per tap, and for a game it's plenty, especially with one more trick: let the LFSR run on every clock, and read it when the player presses the button. Nobody's thumb is accurate to 83 nanoseconds, so the value you read is effectively random.

LFSRs turn up all over hardware: in test pattern generators, in the scramblers that keep serial links like USB and SATA from sending long runs of identical bits, and in the CRC checksums that protect Ethernet frames, which are LFSRs too.

@exercise lfsr

## Binary to decimal

The reaction time is a binary number, like `14'b00000101011011`. People want to read `347`. On a computer you'd divide by 10 repeatedly; division is very expensive in hardware. There's a lovely algorithm called *double dabble* that does it with shifts and small additions.

You shift the binary number, one bit at a time, into a set of 4-bit decimal digits. Shifting left doubles everything. The trouble is that a decimal digit that's 5 or more will become 10 or more when doubled, which doesn't fit in one digit. So before each shift, look at each digit, and if it's 5 or more, add 3. Then, when it's doubled, it overflows into the next digit at exactly the right point. (5 + 3 = 8, and 8 doubled is 16, which is `1_0000` in binary: a carry of one into the next digit and a 0 left behind, which is what 5 × 2 = 10 should give.)

In Verilog, the natural way to write that is a loop:

```verilog
integer i;
always @(*) begin
  dec = 0;
  for (i = 13; i >= 0; i = i - 1) begin
    if (dec[3:0]   >= 5) dec[3:0]   = dec[3:0]   + 3;
    if (dec[7:4]   >= 5) dec[7:4]   = dec[7:4]   + 3;
    if (dec[11:8]  >= 5) dec[11:8]  = dec[11:8]  + 3;
    if (dec[15:12] >= 5) dec[15:12] = dec[15:12] + 3;
    dec = {dec[14:0], bin[i]};
  end
end
```

Now think about what a `for` loop means in hardware. There's no processor to run it, so Yosys *unrolls* it: it makes 14 copies of the loop body, chained one after another, each copy a little circuit of comparators and adders. It all happens in one clock, as one big combinational circuit. Loops in synthesisable Verilog don't repeat anything in time; they repeat hardware in space. Run it and look at the gate count, which is a good reminder that the convenient display format is the expensive one, and why your stopwatch counted in decimal digits from the start.

@exercise bcd

## Project: the reaction timer

Here's how the game goes:

1. Press SW2 to start. The LED is off.
2. After a random delay between 1 and about 3 seconds, the LED comes on.
3. Press SW2 as fast as you can. Icey sends your time over serial, like `247 ms`, followed by `\r\n`.
4. If you press before the LED comes on, it sends `too soon!\r\n` instead.

You have all the parts: the debouncer, a millisecond tick, the LFSR (take `1000 + lfsr[10:0]` milliseconds for the delay), `bcd`, `uart_tx`, and a feeder like the one from the hello project. What's new is putting them together around a state machine: idle, waiting, go, reporting, and too-soon. Draw it first.

The message has no leading zeros: `47 ms`, not `0047 ms`. Your feeder can skip a character when it's a leading zero, by moving its index on without raising `send`.

The tests use `MS = 20` (clocks per millisecond, instead of 12,000) and `DB_BITS = 4`, so give your design parameters with those names.

@exercise reaction

When it works on the board, open the terminal and see how fast you are. Most people land between 200 and 300 ms. Then think about where the time goes: the debouncer adds 5 ms, the synchroniser 2 clocks, and your nervous system the rest.
