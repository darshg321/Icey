---
title: Gates, and a burglar alarm
part: 1
blurb: AND, OR, XOR and NOT, the four operators every digital circuit is built from, and the reasons you'd reach for each one.
---

Every digital chip ever made, from the FPGA on Icey to the processor in your phone, is built out of a handful of logic functions. You've already met one of them. NOT takes one bit and flips it. The other three you'll use constantly take two bits and produce one.

@widget gate-play

Click the two inputs and switch between the gates. It helps to have a sentence for each, because that's how you'll recognise them in a problem:

- **AND** (`&`) is 1 only when *both* inputs are 1. "Only if this and that."
- **OR** (`|`) is 1 when *either* input is 1, or both. "Any of these."
- **XOR** (`^`, exclusive or) is 1 when the inputs *differ*. "One or the other, but not both."
- **NAND, NOR, XNOR** are those three followed by a NOT. They matter more on a silicon wafer than they do to you; on an FPGA they cost exactly the same as the plain versions.

That's the whole vocabulary. Everything from here to the CPU in Part 4 is these, arranged cleverly.

## A burglar alarm

The browser board in this lesson has three switches. One says whether the alarm is armed, one is a sensor on the door, one is a sensor on the window. A sensor reads 1 when its door or window is open. The siren should sound when the alarm is armed and either the door or the window is open.

Notice how close that sentence is to the answer. "Armed *and* (door *or* window)":

```verilog
assign siren = armed & (door | window);
```

The brackets matter. Verilog's `&` binds tighter than `|`, the same way × binds tighter than + in arithmetic, so `armed & door | window` means `(armed & door) | window`, and that alarm goes off whenever the window is open, armed or not. If you're ever unsure about precedence, add brackets. Nobody has ever been confused by too many brackets in a logic expression.

@exercise alarm

After you get it working, add a second output: a green `ready` light that's on when the alarm is armed and everything's closed. You'll need NOT for that, and there's more than one correct way to write it. Look at the Gates tab afterwards. Yosys doesn't necessarily build the gates you wrote. It builds *some* circuit with the same truth table, often a smaller one.

## Two switches, one light

Here's a problem from real house wiring. A staircase has a light switch at the bottom and another at the top, and flipping *either* switch should toggle the light. Walk upstairs, flip the top switch, light goes off. Come back down, flip the bottom one, light comes on.

Write out the truth table and see which gate it is. Both switches down: off. Flip one: on. Flip the other one too: off again. The light is on exactly when the two switches disagree. That's XOR.

It's worth remembering XOR as "toggle". `x ^ 1` flips `x`, and `x ^ 0` leaves it alone. So XOR with a control bit is a controllable inverter, and you'll use that trick again for parity checks, for checksums, for the random number generator in lesson 16, and in the Game of Life.

@exercise stairs

## Three judges

Last one. Three judges each press a button for yes or no, and the light comes on if at least two of them say yes. This is a *majority* function, and it isn't just a game show thing. Spacecraft electronics often build three copies of the same circuit and take a majority vote of their outputs, so a cosmic ray flipping a bit in one copy gets outvoted by the other two. That technique is called triple modular redundancy.

Think about when the answer is yes: judges A and B agree yes, *or* A and C do, *or* B and C do. Each pair is an AND, and you OR the three pairs together.

You can write it all in one `assign`, but long expressions are easier to read if you name the pieces. A `wire` declares an internal signal that isn't a port:

```verilog
wire ab = a & b;
wire ac = a & c;
wire bc = b & c;
assign yes = ab | ac | bc;
```

`wire ab = a & b;` is a shorthand for declaring `ab` and then writing `assign ab = a & b;`. Internal wires cost nothing in hardware. They're names for things that already exist in the circuit.

@exercise majority

## What to take from this

You can now describe any combinational circuit. That's the technical term for a circuit with no memory, where the outputs depend only on what the inputs are right now. In principle, any function of any number of inputs can be written with just AND, OR and NOT. In practice you'd go mad doing that for a 32-bit adder, which is why the next two lessons are about writing bigger things more compactly: buses of many bits, and arithmetic.
