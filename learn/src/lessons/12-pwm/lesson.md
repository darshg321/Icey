---
title: A breathing light, in Icestudio
part: 2
blurb: Dimming an LED that can only be on or off, the RGB LED on Icey, and building a project out of blocks in Icestudio.
---

An FPGA pin is either high or low. There's no "half". Yet the mood lamp at the end of this lesson fades smoothly between colours, using nothing but on and off.

The trick is to switch faster than eyes can follow. Turn an LED on for 25% of the time and off for 75%, thousands of times a second, and it looks a quarter as bright. You saw this by accident in lesson 6, when the low bits of a counter made the LEDs glow at half brightness. Doing it on purpose is called *pulse-width modulation*, or PWM, and it dims LEDs, sets motor speeds, and (with a filter) even makes audio.

## PWM in one comparison

Take a free-running 8-bit counter, 0 to 255 and round again. Compare it to an 8-bit brightness value. While the counter is below the brightness, the output is on:

```verilog
reg [7:0] pwm_count = 0;
always @(posedge clk) pwm_count <= pwm_count + 1;
assign led = (pwm_count < duty);
```

With `duty` at 64 the LED is on for 64 counts out of every 256, a quarter of the time. At 12 MHz the whole 256-count cycle repeats 46,875 times a second, far too fast to see any flicker. The fraction of time spent on is called the *duty cycle*.

@exercise pwm

The virtual board averages each LED's brightness over every screen refresh, the same way your eye does. Slide the switches and watch it dim.

## Breathing

To make the LED breathe, the duty cycle itself has to change slowly, up from 0 to 255 then back down, over a second or two. That's a counter too, a slow one, ticking up and down like the scanner in lesson 7.

If you try it with a straight ramp, the light will look wrong: it seems to spend ages almost fully bright and then dive to black. Eyes don't perceive brightness linearly. Going from 1% to 2% looks like a big jump; going from 90% to 91% looks like nothing. The fix is to bend the curve, so the brightness changes slowly near the bottom and faster near the top. Squaring does a decent job and costs one multiplier:

```verilog
wire [15:0] sq = level * level;   // 0..65025
wire [7:0]  duty = sq[15:8];      // keep the top 8 bits
```

This is called *gamma correction*. Every screen you've ever looked at does a version of it.

## The RGB LED on Icey

Icey has an RGB LED: three LEDs, red, green and blue, in one package. It's wired in a way you need to know about. The three LEDs share a positive connection to 5 V, and each one's negative end goes to an FPGA pin, `RGB0`, `RGB1` and `RGB2`. To light one, the FPGA pulls its pin *low*. So they're active low, like the button. And note the order, because it isn't the obvious one: **RGB0 is red, RGB1 is blue, RGB2 is green**.

Those three pins are special on the iCE40UP5K. They're designed to sink current for LEDs directly, and the proper way to drive them is through a hardware block called `SB_RGBA_DRV`, which limits the current. Driving them as plain outputs also works (that's what the browser exercises do), and it's what the bring-up tests found. When you build for real you can use either.

@exercise breathe

## Project: a mood lamp

The lamp has four modes, and SW2 steps through them: red breathing, green breathing, blue breathing, then a slow rainbow that drifts through all the colours. You'll need:

- your debouncer and edge detector from lesson 8 on `BTN`,
- a 2-bit mode counter,
- one breathing level generator,
- three PWM outputs, with a mux deciding which colours get the breathing level in each mode.

The rainbow is the interesting part. One way: run the three colours from three breathing generators that are a third of a cycle apart. Another: keep a 0–767 "hue" counter, and work out red, green and blue from which third of the range it's in. Either is fine.

The tests run your design with a much shorter breath (`STEP = 1`) and debouncer (`DB_BITS = 4`), so use parameters with those names for the breath timing and the debounce counter width.

@exercise mood

## Now in Icestudio

Icestudio is a graphical front end for the same tools. You draw a block diagram: pins on the edges, blocks of logic in the middle, wires between them. Each block can be a library part or a *code block* containing Verilog. Under the hood it writes all the blocks out as one Verilog file and runs Yosys and nextpnr, exactly as you've been doing.

Run Icestudio from the Icey repository (it needs Node.js 24 or newer; the first `npm install` downloads a few hundred megabytes):

```sh
cd firmware/icestudio
npm install
npm start
```

Then **Select → Board → UP5K → Icey**. Open `firmware/examples/icestudio/blink.ice` first and press **Upload**, to check everything works. It builds and loads in a few seconds, and you've done it from a GUI this time.

Now build the mood lamp there, but split into blocks, the way Icestudio wants:

1. A **clock** code block. Copy the one from `blink.ice`; it holds the `SB_HFOSC` and has one output, `clk_out`.
2. A **debounce** code block with inputs `clk` and `btn` and an output `press`. Paste in your synchroniser, debouncer and edge detector.
3. A **lamp** code block with inputs `clk` and `press`, and outputs `r`, `g`, `b`. Paste in the rest.
4. From the Basic menu, an **Input** block set to `BTN`, and three **Output** blocks set to `RGB0`, `RGB2` and `RGB1` for red, green and blue (that order again).
5. Wire them up and press **Upload**.

Each code block is a module, and Icestudio writes out the module header for you from the ports you list on the block. You type the body: the registers, the `always` blocks, the `assign`s. Compared to text, the drawing is nicer for seeing how big pieces connect, and worse for everything else. Many people prototype in Icestudio and move to plain files as projects grow. That's where Part 3 begins.
