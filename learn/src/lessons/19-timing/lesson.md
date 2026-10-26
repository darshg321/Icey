---
title: Too slow? Pipeline it
part: 3
blurb: What sets a design's top speed, how to read the critical path, and the trade that fixes it. Plus the hardware multipliers.
---

Sooner or later nextpnr will print something like this:

```
Info: Max frequency for clock 'clk': 21.10 MHz (FAIL at 25.13 MHz)
```

The design builds and loads. It might even look fine on your desk, today. But it's out of spec, and a chip running out of spec fails in the worst possible way: occasionally, more often when it's warm, differently on every board. This lesson is about why that number exists and how to raise it.

## Where the limit comes from

Picture two flip-flops with some logic between them. On a clock edge the first one changes its output. That change ripples through the logic, LUT after LUT, wire after wire, and arrives at the second flip-flop's input some nanoseconds later. The second flip-flop samples its input on the *next* clock edge. If the ripple hasn't finished by then, it samples a value that's half-updated, and your design has just computed garbage.

So the clock period must be longer than the slowest flip-flop-to-flip-flop path in the whole design, plus a little setup time the flip-flop needs. That slowest path is the *critical path*. At 25 MHz you have 40 ns per clock. A LUT takes about half a nanosecond, and wires between them typically take one or two, so you can afford perhaps 15 to 20 levels of logic between registers before you're in trouble.

Multipliers built from LUTs blow through that budget quickly. An 11-bit by 11-bit multiply is a grid of AND gates feeding a tree of adders, and it's deep. That's what's going on in this lesson's exercise.

## The exercise design

Here's an effect from the Icey VGA demo: two circular ripple patterns that drift around and interfere with each other. For every pixel, it works out the squared distance to two moving centres, and turns them into a colour:

```verilog
wire signed [10:0] dx1 = h - 200 - t, dy1 = v - 240;
wire [21:0] d1 = dx1*dx1 + dy1*dy1;
// ... the same for the second centre
wire [7:0] c = d1[14:7] + d2[14:7];
```

All of that happens between one register (`h`, `v`) and the next (`rgb`). Subtract, multiply, add, add, all in one clock. Built the way Icestudio builds it, with the multiplications made of logic cells, it tops out around 21 MHz. The pixel clock is 25.125 MHz.

## Pipelining

The fix is to stop doing everything in one clock. Put registers in the middle of the long path, and let each piece of the computation take its own clock cycle:

```verilog
always @(posedge clk) begin
  dx1 <= h - 200 - t;      // stage 1
  sx1 <= dx1 * dx1;        // stage 2
  d1  <= sx1 + sy1;        // stage 3
  c   <= d1[14:7] + ...;   // stage 4
end
```

Now the longest path is one multiplication, not a multiplication plus three additions. It's like an assembly line. Each pixel still takes four clocks to get through, but a new pixel enters on every clock, so the line still finishes 25 million pixels a second. You've traded *latency* (how long one answer takes) for *frequency* (how often you can start a new one), and in video, as in most hardware, frequency is what counts.

There's a catch, and it's the whole difficulty of pipelining: everything that travels alongside the data has to be delayed by the same amount. Your colour now comes out four clocks after the `h` and `v` that produced it. If `HSYNC` and `VSYNC` aren't delayed by four clocks too, the picture shifts four pixels relative to the sync, and the `visible` flag is wrong at the edges, so you get colour in the blanking. A shift register is the natural way to delay a signal by a fixed number of clocks:

```verilog
reg [3:0] hs_d;
always @(posedge clk) hs_d <= {hs_d[2:0], hsync_now};
// hs_d[3] is hsync_now from four clocks ago
```

The tests compare your picture against the right answer pixel by pixel, and if it's correct but shifted, they'll tell you by how many clocks.

@exercise pipeline

Build it for Icey after the tests pass. This exercise builds the way Icestudio does, without hardware multipliers, so it really is close to the limit. Look at the red line in the chip view: before pipelining it snakes through the multiplier's adder tree, and after, it's much shorter.

## The hardware multipliers

The iCE40UP5K has eight DSP blocks, called `SB_MAC16`. Each is a 16×16 multiplier with an accumulator, built directly in silicon, and much faster than one made from LUTs. Yosys will use them for `*` if you pass `-dsp` to `synth_ice40`. The Makefile in lesson 13 does. The builds on this site normally do. Icestudio, at the time of writing, doesn't.

That last fact caused real trouble while Icey's showcase demo was being built. The showcase runs the Game of Life, a USB host bridge and this exact interference effect together, and with the four multiplications built from logic the design needed 106% of the chip. The fix was to instantiate `SB_MAC16` blocks by hand in the Verilog, which Icestudio passes straight through. That brought it down to 95%. Knowing what the tools do and don't do is sometimes the difference between a design that fits and one that doesn't.

@exercise dsp

## A few rules of thumb

When the timing fails, read the critical path in nextpnr's log, or follow the red line in the chip view, and ask what's on it. Usually it's one of a few things.

A wide adder or comparator is usually fine, because carry chains are fast. A multiplier made of logic is slow; use the DSPs, or pipeline it. A long `if`/`else if` chain becomes a priority mux, one level per branch, and a `case` on a single value is usually shallower. Logic that goes through many levels to compute something you only need occasionally can often be computed one clock early and registered.

And a different kind of fix: does it need to run at this speed at all? The Life engine in the next lesson runs at 24 MHz rather than 48, because 48 didn't leave enough margin for the internal oscillator's tolerance. Running a design slower is a perfectly respectable answer, when the job allows it.
