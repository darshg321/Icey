---
title: A button, an LED, and a wire
part: 1
blurb: What an FPGA actually is, your first module, and why the LED comes on backwards.
---

A normal processor runs a list of instructions, one after another, very fast. An FPGA doesn't run anything. It's a chip full of small logic blocks and a huge grid of switchable wiring, and none of it is connected when the chip powers up. You describe a circuit, a toolchain works out how to build that circuit out of the blocks, and a few hundred kilobytes of configuration data close the right switches. After that the chip *is* your circuit, until you unplug it.

The chip on Icey is a Lattice iCE40UP5K. It has 5,280 logic cells, a bit over a megabit of memory, eight multipliers, and 39 pins you can use. That's small by FPGA standards and it's plenty for everything in this course, including a full Apple I.

You describe circuits in a hardware description language. We'll use Verilog, which is what most open-source FPGA tools speak natively and what a lot of the chip industry still uses day to day. It looks a bit like C. That resemblance will mislead you at least once, and that's fine; there's a whole lesson on it later.

## The smallest useful circuit

Icey has a button labelled SW2 and an LED labelled LED1. In the board's pin file those two pins are called `BTN` and `LED`. Here's a circuit that connects them:

```verilog
module top(
  input  BTN,
  output LED
);
  assign LED = BTN;
endmodule
```

A `module` is a box with pins. The list in brackets says what the pins are called and which way signals flow through them. `top` is just the name of the outermost box, the one whose pins get connected to the real chip's pins. Inside, `assign` makes a permanent connection. It isn't a line of code that runs once. Read it as "LED is always the same as BTN", the way you'd read a wire on a schematic.

That's the whole program. No main loop, no setup, nothing to call. The connection exists for as long as the chip is powered.

@exercise wire

Try the exercise now. The workbench on the right has an editor, and when you press **Run** (or Ctrl+Enter) three things happen. Yosys, the open-source synthesis tool, reads your Verilog and turns it into a netlist of logic gates. A simulator built into this page then runs those gates, and the little board under the editor shows the result. Press and hold the button on the virtual board and watch the LED.

## Why it's backwards

If you wired `LED` straight to `BTN`, the LED is on when you're *not* pressing the button and goes off when you press. Your code isn't wrong. The button is.

Look at how SW2 is wired on Icey: one side of the switch goes to ground, and the FPGA pin also has a 10 kΩ resistor to 3.3 V. With the button up, the resistor pulls the pin high and the FPGA reads a 1. Pressing the button connects the pin straight to ground, so it reads 0. Engineers call this *active low*. It's everywhere, because a switch to ground plus a pull-up resistor is the cheapest, most noise-tolerant way to wire a button.

The virtual board copies this exactly, so the same code behaves the same way on the real thing.

To fix it you need an inverter. In Verilog that's `~`, which flips every bit of whatever follows it:

```verilog
assign LED = ~BTN;
```

@exercise not-gate

Once that passes, click the **Gates** tab. That diagram is not a drawing of your code; it's the netlist Yosys produced, the same one the simulator is running. You should see one NOT gate between `BTN` and `LED`. Press the button on the board while the Gates tab is open and the wires turn green when they carry a 1.

## What just happened (and what didn't)

There's a habit worth breaking right away. When you wrote `assign LED = ~BTN;` you might picture a tiny program that checks the button and sets the LED, over and over. Nothing like that exists. There's a gate, and electricity moves through it in a fraction of a nanosecond. If you put a thousand `assign` statements in a module, you get a thousand pieces of circuitry all working at the same time. Order doesn't matter; you could write them in any sequence and get the same chip.

That idea, that everything happens at once, is the whole reason FPGAs exist, and Part 4 of this course is about exploiting it. For now just keep the picture in your head: you're drawing a circuit, with text.

> **On the real board.** The two lines you wrote will work on Icey as they are, because the port names match the board's pin file. You'll do that in lesson 10. Until then everything happens in the browser, and you don't need to install anything.
