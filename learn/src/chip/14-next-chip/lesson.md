---
title: Your next chip
part: 4
blurb: How to design a chip that isn’t this one: the rules that carry over, a way to plan, and where to learn the rest.
---

You've done the whole loop once: idea, Verilog, simulation, an FPGA, verification, layout, tapeout. Everything except the idea carries over to your next chip. This session is about turning a new idea into a plan you can build the same way.

```recall
Q: Name two things a chip design must get right that an FPGA design can get away without.
A: Every register set by the reset (a chip ignores `= 0` starting values), and fitting the area: about a thousand cells on the shared chip.
From: Sessions 5–13

Q: What's the difference between the timing check Tiny Tapeout runs and your chip's real clock?
A: The flow checks at 50 MHz (20 ns); your chip runs at 25.175 MHz, so it has about 19.7 ns of extra margin.
From: Session 13

Q: How did you check that every `uo_out` bit was the right signal?
A: By running `vga_core` on its own next to the packaged chip and comparing them clock by clock.
From: Session 11
```

## The rules that carry over

These came up along the way; they're true of every digital chip, not just this one.

1. **Reset everything.** Registers power up random. Every one gets its value from `rst_n`.
2. **One clock, rising edges, `<=` in clocked blocks, `=` in `always @(*)`.** Mixing clocks is an advanced topic; avoid it until you need it.
3. **Every output assigned on every path**, or you get latches.
4. **Memory is expensive.** In GF180 a flip-flop takes as much area as six NAND gates (64 µm²). A tile has room for a few hundred flip-flops in total, so a few dozen bytes of memory at most once you add the logic around them. Compute instead of storing when you can, like your VGA chip does.
5. **Registered outputs.** Glitch-free, and easy to reason about.
6. **Test from the pins, test the netlist, and check your tests can fail.**

## Plan the next one

Use this before you write any Verilog:

- **What does it do**, in one sentence? What do the pins mean: which inputs, which outputs, at what clock?
- **What does it remember?** List every register and its width, and add them up. Your VGA chip has 36 flip-flops and used under a fifth of its tile. If your total is over a couple of hundred, think again.
- **Draw the blocks**: counters, state machines, shift registers, multiplexers. Each one is something you've now built or read about.
- **How will you test it?** Write the first cocotb test before the design.
- **How will you see it on Icey?** LEDs, the VGA port, the serial port, or the logic analyser.

## Ideas that fit one tile

- a **sound** chip: square waves and a tiny melody sequencer on one output pin (PWM, from the course),
- a **UART** device: a calculator or a secret-message box you type to from a PC,
- a **game**: Pong on VGA, with the paddles on the input pins,
- a **4-bit CPU** with a handful of instructions in a tiny ROM,
- a **random number generator** from an LFSR, shown as noise on VGA or as dice on LEDs.

## Where to learn the rest

```sidequest
title: The rest of the course
link: #/course
time: weeks
why: State machines, UART, SPI, memory, timing, a CPU of your own and an Apple I, all on Icey. Lessons 9, 15, 17, 19 and 22 are the ones a chip designer leans on most.

title: HDLBits, all of it
link: https://hdlbits.01xz.net/wiki/Problem_sets
time: weeks
why: Over 150 short problems with instant feedback. The state machine and "Building larger circuits" sets are the best practice there is.

title: Tiny Tapeout's digital design lessons
link: https://tinytapeout.com/digital_design/
time: as needed
why: Short articles from the people who run the shuttles, aimed at exactly this kind of design.

title: Zero to ASIC
link: https://www.zerotoasiccourse.com/
time: a course
why: Matt Venn's paid course: the deeper version of everything after your Verilog (layout, the open-source flow, analog), if you get hooked.
```

```reflect
What's your next chip? One sentence, and list its pins.
```
