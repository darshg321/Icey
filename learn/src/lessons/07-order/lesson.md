---
title: "= or <=: the light chaser"
part: 1
blurb: Why clocked blocks use <=, shift registers, parameters, and a scanning light like the car in Knight Rider.
---

The first lesson promised that Verilog's resemblance to C would trip you up at least once. This is where.

Here's a circuit with two flip-flops, `x` and `y`, that are supposed to swap values on every clock edge. If `x` starts at 1 and `y` at 0, the two LEDs should blink alternately.

```verilog
always @(posedge clk) begin
  x = y;
  y = x;
end
```

Read it like software and it's a classic bug: the first line overwrites `x`, so the second line copies the *new* `x` back into `y`, and they both end up as 0. And that's what happens here too. `=` inside an `always` block is a *blocking* assignment. It takes effect immediately, and lines below it see the new value.

Now the version with `<=`:

```verilog
always @(posedge clk) begin
  x <= y;
  y <= x;
end
```

This one swaps. A *nonblocking* assignment doesn't change anything straight away. Every right-hand side in the block is evaluated using the values from before the clock edge, and then all the registers update together. That's precisely how real flip-flops behave: at the edge, every flip-flop samples its input at the same moment, so nobody sees anybody else's new value until the next edge. Two flip-flops cross-wired to each other really do swap on every clock.

So the rule from lesson 6 has a reason behind it. Inside `always @(posedge clk)`, use `<=`, and the code will mean what the hardware does. Inside `always @(*)`, use `=`, because there you *want* each line to see the result of the one above, like steps in a calculation. Mixing the two in one block makes code whose meaning depends on line order in ways that are easy to get wrong, so don't.

@exercise swap

## The shift register

Chain flip-flops so each one loads from its neighbour, and a bit pushed in at one end walks along the chain, one position per clock:

```verilog
reg [7:0] sr = 0;
always @(posedge clk)
  sr <= {sr[6:0], in};   // everything moves up a place, `in` enters at bit 0
```

With nonblocking assignment this is one line, and all eight flip-flops shift in the same instant. Shift registers are everywhere. A serial port (lesson 15) is a shift register that pushes bits out of one pin. The SPI bus that talks to the flash chip and the SD card (lesson 21) is two shift registers, one at each end of the wire. Delay lines in video pipelines (lesson 19) are shift registers. Even the random number generator in lesson 16 is a shift register with some XOR gates on it.

On the virtual board, the shift register only moves ten times a second so you can watch it. That needs a slow enable pulse like the one in your stopwatch, and now's a good moment to tidy it up with a *named constant*:

```verilog
localparam STEP = 1_200_000;   // 12 MHz / 10
reg [20:0] pre = 0;
wire step = (pre == STEP - 1);
```

`localparam` gives a number a name inside a module. A `parameter` is the same thing, except the module that instantiates this one can override it, `ledbar #(.STEP(600_000)) bar(...)`, which is how you make reusable modules with settings. Use names for numbers that mean something. `1_199_999` on its own is a riddle; `STEP - 1` explains itself.

@exercise shift

## Project: the scanner

KITT, the talking car in Knight Rider, had a strip of red lights on its bonnet with a single light sweeping left and right, endlessly. Build it: one lit LED, moving one position every sixteenth of a second, bouncing off each end.

There are a few ways to do it. You could keep the position as a 3-bit number plus a direction bit and decode it to the LEDs. Or keep the LED pattern itself in a register and shift it left or right, flipping direction at the ends. Pick one, and if you've got time, try the other one and compare them in the Gates tab.

The tests expect the light to start on `led[0]`, move up to `led[7]`, come back down to `led[0]`, and repeat, with each position held for 750,000 clocks (1/16 s).

@exercise scanner
