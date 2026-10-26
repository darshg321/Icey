---
title: Your own design
part: 4
blurb: How to pick a project, plan it, build it in pieces, and bring it up on a real board when it doesn't work the first time.
---

Every project so far came with a plan: here are the modules, here are the tests, here's what the board should do. This lesson is the plan for when there isn't one. Much of it comes from what went wrong while Icey was being brought up.

## Pick something that needs hardware

You can build anything on an FPGA that you can build in software, but the projects that are fun to finish are the ones where hardware is the right answer. They tend to have one of three properties: they're **fast** (more than a few million things per second), they're **precise** (timing to the clock cycle), or they're **parallel** (lots of independent work happening at once). Some ideas that fit Icey, roughly from smaller to bigger:

- **A logic analyser.** Sample the nine header pins at 12 MHz into block RAM when a trigger condition hits, then send the capture over serial and draw it on your PC. It's genuinely useful for debugging your next project.
- **A frequency counter** on a header pin, shown in the terminal. Count edges for exactly one second; to make it accurate, feed a crystal oscillator into pin P4.
- **Breakout or Pong on VGA**, with a USB keyboard. The keyboard is the hard part: the `hwtest` example does USB enumeration from Python through the FPGA, and moving that into hardware is a project by itself. A button version first is fine.
- **A synthesiser.** A pin toggling at audio rates through a resistor and capacitor makes sound. Several oscillators, an envelope, a sigma-delta output, notes from the serial port.
- **A Mandelbrot or Julia set explorer on VGA**, using the eight DSP blocks as a pipeline of complex multipliers.
- **Your own RISC-V core.** The RV32I instruction set is small and very well documented, there are compilers for it, and with a UART you can run C programs on a processor you wrote.
- **The rest of the Apple I**: Integer BASIC, and Woz's 40×24 terminal on the VGA port.

Pick one where you can describe the finished thing in a sentence, and where you can get *something* visibly working in an evening. A project with a working first step gets finished. A project with a perfect plan and nothing running for three weeks usually doesn't.

## Write it down first

Before any Verilog, write half a page: what it does, what the inputs and outputs are (pins, by name from `icey.pcf`), what the clock is, and a block diagram. The diagram doesn't need to be neat. Boxes are modules, arrows are buses, and every arrow is labelled with its width and what it means.

The most important decisions are the interfaces between your boxes. Most of the bugs in a big design live at the joins, where two modules disagree about what a signal means or when it's valid. One convention makes most of those disagreements impossible, and it's worth using everywhere: **valid/ready**.

```verilog
// producer side          consumer side
output [7:0] data,        input  [7:0] data,
output       valid,       input        valid,
input        ready        output       ready
```

The producer raises `valid` when `data` holds something. The consumer raises `ready` when it can take something. A transfer happens on every clock where both are high, and only then. The producer has to hold `data` steady while `valid` is high and `ready` isn't. That's the whole rule, and it handles every case: a fast producer and a slow consumer, the reverse, either side pausing at any time. Your UART transmitter's `send` and `busy` were a simple version of it. The FIFO from lesson 24 slots naturally between two valid/ready interfaces to absorb bursts. Industrial bus standards like AXI-Stream are this same handshake with extra signals.

## Build it in pieces, test each piece

Build bottom-up. Each module gets a testbench before it gets connected to anything (lesson 14), and the testbench lives next to the module in the same folder, with a `make test` that runs them all. When a module works, leave it alone and build the next one.

When it's time to put modules together, add them one at a time. Connect two, test the pair. Add a third. If you connect seven untested modules and it doesn't work, there are seven places to look and dozens of joins between them. If you add one at a time, the bug is almost always in the last thing you added.

Build for the board often, not just at the end. Check the utilisation and the timing each time. It's much easier to fix a design that grew 5% too big this afternoon than one that's 40% too big after a month.

## When it doesn't work on the board

It will happen. The simulation is perfect, the board does nothing. Work through this list, in order, before you change any logic. It's the list of things that actually went wrong during Icey's bring-up and during the writing of this course.

1. **Is the design loaded?** LED2 goes out when the FPGA is configured. On a rev-1 board, unplugging it loses the design.
2. **Is the clock running?** Put a counter's top bit on LED1 as a heartbeat in every design. If it isn't blinking, nothing else will work either. Remember there's no clock pin; you need `SB_HFOSC`.
3. **Are the pin names right?** nextpnr's "unconstrained IO" warning means a port didn't match `icey.pcf` and landed on a random pin. Read the warnings.
4. **Active low?** The button, the RGB LED, the sync pulses, chip selects. Half of all "it does nothing" bugs are a missing `~`.
5. **Widths?** Verilog's silent truncation (lesson 3). Read every assignment and count the bits on both sides.
6. **Latches?** Search the Yosys log for "Latch inferred".
7. **Timing?** If Fmax is below your clock, the design may work in a way that makes no sense, or work on Tuesday and fail on Wednesday.
8. **Is anything crossing clock domains, or coming from outside?** Every asynchronous input needs a synchroniser (lesson 8).
9. **Did it really pass in simulation?** With the same parameters? The tests in this course shrank timing constants; make sure the real ones are back.

If you're still stuck, make the hardware tell you what it's doing. Send internal signals out over the UART, or onto LEDs, or onto header pins for a logic analyser. That's why the logic analyser is at the top of the project list.

## Where to go next

You've written combinational logic and state machines, used block RAM, DSPs, a PLL and the RGB driver, talked to a flash chip, driven a monitor, built a CPU and run a 1976 computer on a chip that costs a few dollars, and proven a design correct. That's a real foundation, and the parts you haven't seen yet build on it rather than replacing it.

A few directions, depending on what grabbed you. **SystemVerilog** adds types, interfaces and much better testbench features; Yosys reads a good subset of it, and the industry uses it for nearly all new work. **Bigger FPGAs**, like the ECP5 family (also fully supported by Yosys and nextpnr), have hundreds of thousands of LUTs, fast serial transceivers and DDR memory controllers, and run Linux on soft processors. **Chip design** through Tiny Tapeout, if lesson 24 caught your interest. And **reading other people's designs** teaches fast: the Icey firmware folder, the showcase design, Arlet's 6502 core, and the many open-source FPGA projects out there are all things you can now read.

Go and build something.
