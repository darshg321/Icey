---
title: Testbenches
part: 3
blurb: Testing hardware with more hardware description. Icarus Verilog, waveforms in GTKWave, and testbenches that check themselves.
---

Every exercise so far came with tests, and you've seen how much faster it is to find a bug from "led should be 4 after 3 presses, but it was 7" than from staring at a board. From here on, the projects are bigger and you'll write your own. That's normal practice. In chip companies the people verifying a design often outnumber the people writing it, and lesson 24 explains why.

The tests in this site were written in JavaScript, driving the gate-level simulator. On your own machine, the usual way is a *testbench*: a Verilog module that has no ports, instantiates the design under test, wiggles its inputs and checks its outputs. It runs in a Verilog simulator, not on the chip.

## Installing a simulator

Icarus Verilog is small, free, and the standard choice for this:

```sh
sudo apt install iverilog gtkwave        # Debian, Ubuntu
brew install icarus-verilog              # macOS (GTKWave: brew install --cask gtkwave)
```

The OSS CAD Suite includes both as well. GTKWave is a waveform viewer, the desktop version of the Waves tab you've been using.

## A first testbench

Take the PWM dimmer from lesson 12, as its own module in `pwm.v`:

```verilog
module pwm(input clk, input [7:0] duty, output out);
  reg [7:0] count = 0;
  always @(posedge clk) count <= count + 1;
  assign out = (count < duty);
endmodule
```

And here's a testbench for it, in `pwm_tb.v`:

```verilog
`timescale 1ns / 1ps

module pwm_tb;
  reg clk = 0;
  always #5 clk = ~clk;              // a 100 MHz clock: flips every 5 ns

  reg  [7:0] duty;
  wire       out;
  pwm dut(.clk(clk), .duty(duty), .out(out));

  integer i, on;
  initial begin
    $dumpfile("pwm.vcd");
    $dumpvars(0, pwm_tb);

    duty = 64;
    on = 0;
    for (i = 0; i < 256; i = i + 1) begin
      @(posedge clk);
      if (out) on = on + 1;
    end
    if (on != 64) $display("FAIL: duty 64 gave %0d clocks on", on);
    else          $display("ok: duty 64");

    $finish;
  end
endmodule
```

A lot of new language is in there, and none of it can be synthesised, so you'll never put any of it on a chip.

`` `timescale 1ns / 1ps`` says that delays are in nanoseconds. `#5` means "wait 5 ns", so `always #5 clk = ~clk;` is a free-running clock. Delays only exist in simulation; there's no way to build "wait 5 ns" out of LUTs.

`initial begin ... end` runs once, from time zero, like a normal program. Inside it you can use loops, `integer` variables, and `@(posedge clk)`, which means "wait here until the next rising edge of clk". This is the one place in Verilog where it really does behave like software, because it *is* software: a script for the simulator.

`$display` prints, with C-style formatting. `$dumpfile` and `$dumpvars` record every signal into a VCD file for GTKWave. `$finish` ends the simulation, which is important because the clock would otherwise run forever.

Build and run it:

```sh
iverilog -g2012 -o pwm_sim pwm_tb.v pwm.v
vvp pwm_sim
gtkwave pwm.vcd
```

`iverilog` compiles the Verilog into a simulation, and `vvp` runs it. In GTKWave, expand `pwm_tb` on the left, select the signals, and press Insert to show them.

## Make it check itself

The testbench above prints "ok" or "FAIL". That's already better than reading waveforms, but it only checks one duty value. The real power comes from loops and a reference: compute what the answer should be, compare against what the design did, and complain loudly when they disagree.

```verilog
integer d, errors = 0;
initial begin
  for (d = 0; d < 256; d = d + 1) begin
    duty = d;
    repeat (256) @(posedge clk);       // let it settle into the new duty
    on = 0;
    repeat (256) begin
      @(posedge clk);
      if (out) on = on + 1;
    end
    if (on != d) begin
      $display("FAIL: duty %0d gave %0d", d, on);
      errors = errors + 1;
    end
  end
  $display("%0d errors", errors);
  $finish;
end
```

That's every possible input, checked in well under a second. A *self-checking* testbench like this can run every time you change the design, and a test that can run automatically is a test that does get run. Put a `test` target in your Makefile that does it.

## Project: find the bug

Here's a debouncer with a bug in it. It works fine if you press the button gently. Write a testbench that finds the problem, then fix it.

```verilog
module debounce(input clk, input btn, output reg stable = 1);
  reg [15:0] timer = 0;
  reg [1:0] sync = 2'b11;
  always @(posedge clk) begin
    sync <= {sync[0], btn};
    if (sync[1] != stable) timer <= timer + 1;
    if (&timer) begin
      stable <= sync[1];
      timer <= 0;
    end
  end
endmodule
```

Things your testbench should try: a clean press held for 10 ms; a press that bounces for 3 ms; a series of short glitches, each 1 ms long with 1 ms gaps, going on for 20 ms. Generate the bounce with a loop and `$random`. Write each case as its own block, check `stable` at the end of each, and print what you expected and what you got.

If you get stuck, compare it line by line with the debouncer from lesson 8. The difference is one missing line, and it's the kind of bug that would pass a demo and fail in the field.

Notice that the tests in lesson 8 would have passed this design. They tried one glitch, and one glitch isn't enough to trip it. A test suite only proves the things it tries, which is the problem lesson 24 spends its whole length on.
