---
title: Making choices, and a hex display
part: 1
blurb: Multiplexers, if and case, the always block, and the latch that appears when you forget an else.
---

Everything so far has been a fixed formula. Lots of circuits need to *choose*: show this number or that one, depending on a switch. The hardware that does this is called a multiplexer, or mux, and it's probably the most common block on any chip.

A two-way mux has two data inputs, a select input, and one output. When select is 0 the output copies the first input; when it's 1 it copies the second. Verilog borrowed the C ternary operator for it:

```verilog
assign out = sel ? b : a;   // sel = 1 picks b, sel = 0 picks a
```

On a 4-bit bus that's four muxes sharing one select line. It's a physical switch made of gates: both `a` and `b` exist all the time, the mux only decides which one gets through.

@exercise pick

## Longer decisions: the always block

Chains of `? :` get unreadable fast. For anything with more than two choices, Verilog has a block form that reads like ordinary code:

```verilog
reg [6:0] seg;

always @(*) begin
  case (digit)
    4'h0: seg = 7'b0111111;
    4'h1: seg = 7'b0000110;
    // ...
    default: seg = 7'b0000000;
  endcase
end
```

`always @(*)` means "whenever any input to this block changes, work out the outputs again". In hardware terms it still describes a combinational circuit, just like `assign`. Yosys reads the `case` and builds a pile of muxes and gates that produce the same answers.

There's an unfortunate word in there. Any signal you assign inside an `always` block has to be declared `reg`, not `wire`. That's a historical accident in the language and it does **not** mean there's a register (a memory element) involved. Here `seg` is plain combinational logic. Lots of people get confused by this for years. Now you won't.

## The 7-segment display

The practice board in this lesson has 7-segment displays, the kind on alarm clocks. Each digit is seven LED bars, named a to g:

```
  aaa
 f   b
 f   b
  ggg
 e   c
 e   c
  ddd
```

On this board `seg[0]` drives bar a, `seg[1]` drives b, and so on up to `seg[6]` for g, and a 1 lights the bar. To show a 1 you light b and c, so `seg = 7'b0000110`. To show an 8 you light everything. Your job is a decoder that takes a 4-bit number (0 to 15) and lights the right bars to draw it in hex, 0 to 9 then A, b, C, d, E, F. Lowercase b and d are the convention because uppercase B and D would look like 8 and 0.

Draw the digits on paper first. It's faster than guessing.

@exercise hex7

## The latch trap

Here's the thing that bites everyone once. Suppose a circuit should output the number of the highest active request line out of three, and you write:

```verilog
always @(*) begin
  if (req[2])      y = 2'd2;
  else if (req[1]) y = 2'd1;
  else if (req[0]) y = 2'd0;
end
```

What's `y` when no request is active? You didn't say. In software the variable would just keep whatever it had last time. Hardware can do that too, but only by building memory: Yosys has to put a *latch* on `y` so it can hold its old value whenever none of the branches run. You asked for a combinational circuit and accidentally got a storage element.

Latches are bad news on an FPGA. The timing tools can't analyse them properly, the iCE40 doesn't have native latches so they get built awkwardly out of logic, and the behaviour usually isn't what you meant anyway. Yosys prints a warning when it infers one. The workbench shows it in yellow.

The rule that prevents it: in an `always @(*)` block, every output gets a value on every path through the block. The easy way to guarantee that is to give everything a default at the very top, and then override it:

```verilog
always @(*) begin
  y = 2'd0;          // default first
  if (req[2])      y = 2'd2;
  else if (req[1]) y = 2'd1;
end
```

For a `case`, always write a `default:` branch, even when you think you've covered every value.

@exercise latch

## Project: a hex calculator

Time to put three lessons together. Two 4-bit numbers on the switches, their sum on two 7-segment digits. The sum can go up to 30, which is `1E` in hex, so the left digit shows the top bit of the total and the right one shows the bottom four.

You'll want your decoder as its own module, instantiated once per digit, plus an adder. It's fine to paste your code from the previous exercise. Copying a module you've already tested is how most hardware gets built.

@exercise calc
