---
title: Eight wires at once
part: 1
blurb: Buses, binary numbers, slicing and gluing bits together, and the one-character operators that summarise a whole bus.
---

So far every signal has been one wire carrying one bit. Real designs move numbers around, and a number is just several wires next to each other. Verilog calls that a *vector*; most hardware people call it a bus.

```verilog
input  [7:0] sw,    // eight switches: sw[7] down to sw[0]
output [7:0] led
```

`[7:0]` means eight bits, numbered 7 down to 0. Bit 0 is the least significant one, the "ones" column. You can number them `[0:7]` if you want to start an argument with every hardware engineer you'll ever work with, but please don't. `[N-1:0]` is the convention and the rest of this course uses it.

Operators you already know work on every bit at once. If `a` and `b` are both 8 bits, `a & b` is eight AND gates side by side, bit 0 with bit 0, bit 1 with bit 1, and so on. `~sw` is eight inverters.

## Numbers

Since buses carry numbers, you need a way to write numbers. Verilog's format is width, an apostrophe, a base letter, then the digits:

```verilog
8'b1010_0101   // binary. The underscore is ignored, it's only there for you
8'hA5          // the same value in hex
8'd165         // and in decimal
165            // a bare number: decimal, and 32 bits wide
```

Always give the width when you can. A bare `165` is a 32-bit value, and Verilog quietly widens or chops things to make sizes match. That silent resizing is one of the most common sources of bugs in hardware, and Yosys won't warn you about it.

@widget binary

Hex is popular in hardware because each hex digit is exactly four bits. `8'hA5` is `1010` then `0101`. Once you've done this for a few weeks you'll read hex as bit patterns without thinking.

## Pulling bits out and putting them together

You can pick out one bit with `sw[3]`, or a range with `sw[3:0]` (the low four bits, called the low *nibble*, because hardware people are like this). Curly braces glue things together, with the first item becoming the most significant bits:

```verilog
assign led = {sw[3:0], sw[7:4]};   // swap the two halves
assign wide = {4'b0000, sw};       // a 12-bit version of sw, padded with zeros
assign all  = {8{1'b1}};           // eight copies of a 1: 8'b11111111
```

That last one is *replication*: `{n{x}}` is n copies of x, glued together.

None of these operations cost anything on the chip. Picking out bits and rearranging them is just choosing which wires go where. On a CPU, reversing the bits of a byte is a loop or a lookup table; here it's free, and runs in zero time. That's your first taste of a theme: things that are awkward in software are sometimes trivial in hardware, and vice versa.

@exercise mirror

## Summarising a bus

Put `&`, `|` or `^` in front of a bus with nothing on its left and it becomes a *reduction*: the operator gets applied across all the bits of that one bus, producing a single bit.

```verilog
wire all_on = &sw;   // sw[7] & sw[6] & ... & sw[0]
wire any_on = |sw;   // is anything set at all?
wire odd    = ^sw;   // is an odd number of bits set?
```

That last one deserves a moment. XOR of a bunch of bits is 1 when an odd number of them are 1. It's called *parity*, and it's the simplest error check there is. A serial link can send an extra bit with each byte so that the total number of 1s is always even; if the receiver ever counts an odd number, a bit got flipped on the way. Some kinds of memory store a parity bit alongside every byte for the same reason. A single XOR tree catches any one-bit error.

@exercise reduce

## A catch

Vectors give Verilog's quiet resizing lots of room to bite. Try this in the workbench after you've done the exercises:

```verilog
wire [3:0] small = sw;      // keeps sw[3:0], silently drops the top four bits
assign led = small;         // widens back to 8 bits, padding with zeros
```

It compiles without a single warning, and half your switches stop doing anything. When something "just doesn't respond", count the bits on both sides of every `=`.
