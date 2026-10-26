---
title: Clocks, flip-flops, and a blinking light
part: 1
blurb: Circuits that remember. The clock, the flip-flop, counters, and how to get one second out of twelve million ticks.
---

Every circuit you've built so far forgets everything the instant its inputs change. Take your finger off the button and the LED goes out. To do anything interesting, like counting, waiting, or blinking, a circuit has to remember things, and the part that remembers is the flip-flop.

## The flip-flop

A D flip-flop has a data input `D`, an output `Q`, and a clock input. Most of the time it ignores `D` completely and holds `Q` steady. At the exact moment the clock goes from 0 to 1, called the rising edge, it copies `D` to `Q`, and then goes back to ignoring `D` until the next rising edge.

@widget dff

That one behaviour is the foundation of every processor, memory controller and video chip in existence. Here's how you write it:

```verilog
reg q;
always @(posedge clk)
  q <= d;
```

`always @(posedge clk)` means "on every rising edge of clk". The arrow `<=` is the *nonblocking assignment*, and it's the one you use in clocked blocks. The next lesson explains why; for now, the rule is `<=` inside `always @(posedge clk)` and `=` inside `always @(*)`.

This time `reg` really does mean a register. A `reg` assigned in a clocked block becomes flip-flops, one per bit.

## The clock

Something has to provide that rising edge. On almost every FPGA board that's a clock signal: a square wave from a crystal oscillator, ticking millions of times a second, wired to every flip-flop in the design. Icey doesn't have a crystal; it uses an oscillator built into the iCE40 itself, set to 12 MHz. The virtual board in this lesson gives you the same thing on an input called `clk`: twelve million rising edges a second.

Design with a single clock and all your flip-flops update at the same instant, in lockstep. Between edges, the combinational logic has about 83 nanoseconds to work out what every flip-flop should load next. That rhythm (settle, tick, settle, tick) is called *synchronous design*. It's how nearly all digital hardware is built, because it makes a design with a million flip-flops as easy to reason about as one with three.

## Counting

Put an adder's output back into its own input through a register, and you have a counter:

```verilog
reg [7:0] count = 0;
always @(posedge clk)
  count <= count + 1;
```

On every edge, `count` loads the value one bigger than itself. After 255 it wraps around to 0, because 256 doesn't fit in 8 bits.

The `= 0` sets the value the register has at power-up. On an FPGA that works, because the configuration data includes the initial state of every flip-flop. Remember that this is a luxury, though. A custom chip (an ASIC) powers up with its flip-flops in random states, which is why ASIC designs always have an explicit reset. Lesson 24 comes back to this.

@exercise counter

If you showed `count[7:0]` on the LEDs you'd see them all glowing at half brightness. They're flickering millions of times a second, and your eye averages that out. The virtual board does the same averaging. To see the counting you need to look at much higher bits, which change much more slowly. Bit *n* of a counter flips every 2ⁿ cycles. Bit 23 flips every 8,388,608 cycles, which at 12 MHz is about 0.7 seconds.

## Exactly one second

Picking a counter bit gives you periods that are powers of two, like 0.7 seconds or 1.4 seconds. To get exactly one blink per second you need the LED to change every half second, which is 6,000,000 cycles. So count from 0 up to 5,999,999, then start again from 0 and flip the LED:

```verilog
reg [22:0] count = 0;
reg led = 0;
always @(posedge clk) begin
  if (count == 23'd5_999_999) begin
    count <= 0;
    led <= ~led;
  end else begin
    count <= count + 1;
  end
end
```

Two questions to ask yourself every time you write something like this. How many bits does the counter need? 5,999,999 is less than 2²³ (8,388,608), so 23 bits. And is it counting to N or N−1? From 0 to 5,999,999 inclusive is 6,000,000 values, so it's right. Off-by-one errors in counters are the single most common bug in hardware, and they're extra sneaky because the result looks almost right.

@exercise blink

## Project: a stopwatch

The board has two 7-segment digits. Make them show seconds and tenths of a second, from 0.0 up to 9.9 and then wrapping round to 0.0. Holding the button (`BTN`, still active low) resets it to 0.0.

Don't try to do it all with one big counter. Split it into stages:

1. A counter that produces a one-clock *pulse* every tenth of a second (every 1,200,000 cycles). This is a "tick" or "enable" signal, not a new clock: everything still runs on `clk`, and the tenths counter only moves on cycles where the tick is high.
2. A tenths digit, 0 to 9. On a tick it adds 1, or goes back to 0 if it was at 9.
3. A seconds digit that moves only on cycles where the tenths digit is wrapping from 9 back to 0.

Counting in separate decimal digits like this is called BCD, binary-coded decimal. It saves you converting binary to decimal for the display, which is surprisingly expensive in hardware. Lesson 16 shows how expensive.

Why a tick and not a slow clock? Because making a new clock out of logic (say, `always @(posedge count[20])`) gives you a second clock domain that's slightly out of step with the first, and signals moving between the two can get corrupted. Lesson 8 shows what that corruption looks like. One clock everywhere, with enables for the slow parts, avoids the whole problem.

@exercise stopwatch
