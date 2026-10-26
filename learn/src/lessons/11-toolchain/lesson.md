---
title: What the tools actually did
part: 2
blurb: Synthesis, lookup tables, placement, routing, timing and bitstreams. What happens between pressing build and the LED lighting up.
---

You've pressed "build for Icey" a few times now and gotten a working chip out of it. This lesson opens that box, because sooner or later a build will fail, or come out too slow, or too big, and the only way to fix it is to know what the tools were trying to do.

There are four stages. **Synthesis** turns your Verilog into a netlist of the parts the chip actually has. **Placement** decides where on the chip each part goes. **Routing** connects them through the chip's wiring. **Bitstream generation** writes all those decisions into a file the chip can load. Yosys does the first. nextpnr does the second and third and checks the timing. icepack does the fourth.

You can watch all of it happen on one small design. Edit it if you like, press the button, then click through the stages:

@widget toolflow

## Synthesis: from code to cells

Yosys works in passes. First it parses your code and turns each `always` block and operator into generic cells: an adder, a register, a multiplexer. Then it optimises (removing logic that can't affect any output, merging duplicates, simplifying constants), and breaks everything down into single-bit gates. Up to that point nothing depends on which chip you're targeting. Stage 2 in the widget is the very netlist the browser simulator has been running all along.

Then comes *technology mapping*: rewriting the netlist using only the building blocks this particular FPGA has. For the iCE40 the main one is a little bit surprising.

## The lookup table

There are no AND gates on an FPGA. There are no OR gates either, or XORs. There are *lookup tables*.

A 4-input lookup table, LUT4 for short, is 16 bits of memory and a multiplexer. Its four inputs form a 4-bit address, 0 to 15, and the output is whichever of the 16 stored bits that address selects. Set the 16 bits right and the LUT behaves like any function of four inputs you can think of. AND, XOR, "is this number prime", anything.

@widget lut

That's why it's called *field-programmable*: the logic is decided by memory contents, which you load in the field. It also changes how you think about cost. On an FPGA, `a & b` and `(a ^ b) | (c & ~d)` cost exactly the same, one LUT, because any function of up to four inputs fits in one. A function of five inputs needs at least two LUTs, chained together. So the question that matters isn't "how many gates?" but "how many inputs does each output depend on?"

@exercise prime

The utilisation bar in the chip view will probably say 2 cells, not 1. Click around the floorplan and you'll find the second one is called `$PACKER_VCC`: nextpnr uses a spare LUT as a source of constant 1s for things like the chip's I/O settings. It's overhead, not your logic.

Each iCE40 *logic cell* is one LUT4, followed by an optional flip-flop, plus a piece of dedicated carry logic. A flip-flop that's fed straight from a LUT lives in the same cell for free. Eight logic cells make a *tile*, and the UP5K has 660 of them in a grid.

## Carry chains

Counters and adders are so common that the iCE40 has special hardware for them. Each logic cell has a carry input from the cell below it, and a small fixed circuit that computes the carry out. Those circuits are chained vertically through the tile, and from tile to tile, so a 16-bit adder becomes 16 logic cells in a column, each using its LUT for the sum bit and the hardwired chain for the carry. The hardwired chain is far faster than building carries out of LUTs and general routing.

This is what Yosys was doing with your `+` in lesson 4, and why the hand-built ripple adder came out bigger: Yosys spots `+`, but it can't spot an adder you built out of gates yourself.

@exercise carry

## Placement and routing

After synthesis you have a list of cells and the wires between them, but no locations. nextpnr's placer assigns each cell to a specific place on the chip, trying to keep connected cells close together, since a short wire is a fast wire. The router then has to find an actual path for every connection through the chip's grid of switchable wires, without two signals ever needing the same wire. On a nearly full chip, routing can take much longer than everything else put together.

Then nextpnr adds up the delays. Every LUT takes some time to produce its output, about half a nanosecond, and every wire adds more depending on how far it goes. The longest chain of LUTs and wires between one flip-flop and the next is the *critical path*, and it sets the fastest clock your design can run at. In the chip view that's the red line, and it's reported as **Max frequency**. As long as that number is above the clock you're actually using, the design will work. If it isn't, it'll work most of the time on most chips at most temperatures, which is a lot worse than it sounds. Lesson 19 is about fixing a design that's too slow.

## The bitstream

The last step writes every LUT's 16 bits, every flip-flop setting, and the state of every routing switch into one file. For the UP5K it's 104,090 bytes, and its size doesn't depend on your design at all: a single NOT gate and a design that fills the chip produce files of the same size, because every switch on the chip gets a setting either way. That's why a 1-gate design's bitstream is mostly zeros.

Loading it is a dance with three pins. The programmer pulls the FPGA's reset pin (`CRESET_B`) low, holds the SPI chip-select low, then lets reset go. Seeing chip-select low as it comes out of reset tells the iCE40 to wait for a bitstream over SPI rather than fetching one from flash. Then the programmer clocks the whole file in, adds a few dozen extra clock pulses, and the FPGA raises `CDONE` to say "configured". That's every line of `iceyprog`, and of the WebUSB upload on this site, which does the same thing from JavaScript.

None of this is magic, and all of it is open source. If you ever want to know why Yosys made some decision, the log tells you; it's in the Log tab after every build, and it's long, and it's all there.
