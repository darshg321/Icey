---
title: Sync
part: 2
blurb: The timing a monitor expects, from your two counters. The first real picture.
---

Your x and y counters already have the right shape: one fast, one stepping each time the fast one wraps. Make them 800 and 525, add two sync pulses, and a monitor will lock on. Today your chip draws its first picture.

```recall
Q: y steps only when x wraps. What does that connect: which output of the x counter goes to which input of the y counter?
A: x's `wrap` goes to y's `en`.
From: Session 6

Q: Two counters of 800 and 525: how many clocks until both are back at 0?
A: 800 × 525 = 420,000.
From: Session 6

Q: A `case` in `always @(*)` without a `default` (and not every value listed): what do you get?
A: A latch, because some values leave the output unassigned.
From: Session 4
```

## Learn

Project F's guide is the best explanation of VGA timing there is. Read only these sections; the rest is about their boards.

```resource
title: Beginning FPGA Graphics
url: https://projectf.io/posts/fpga-graphics/
source: Project F
time: 12 min
do: Read **Space and Time**, **Display Timings**, skim **Driving a Display** and **Pixel Clock**, then read **Display Signals** and **Drawing Graphics** (up to "12-bit Colour"). Their `sx`/`sy` are your x and y.
```

```resource
title: VGA Playground
url: https://vga-playground.com/?preset=stripes
source: Tiny Tapeout
time: 2 min
do: Just look: a design like yours, running live. You'll use this again when you ship.
```

The numbers, for reference:

| | visible | front porch | sync | back porch | total |
|---|---|---|---|---|---|
| horizontal (clocks) | 640 | 16 | 96 | 48 | 800 |
| vertical (lines) | 480 | 10 | 2 | 33 | 525 |

Both sync pulses are **active low**. Pixel clock: 25.175 MHz.

## Predict

```predict
Q: hsync is low while x is in the sync part of the line. From the table, what's the first x where hsync goes low, and the last?
A: 640 + 16 = **656** to 656 + 96 − 1 = **751**. So `hsync = ~(x >= 656 && x < 752)`. Likewise vsync is low for y = 490 and 491.
```

## Build

From today your design has the ports your chip will have: `clk`, `rst_n`, `hsync`, `vsync`, and 2 bits each of `r`, `g`, `b`. (The Tiny Tapeout VGA adapter has 2 bits per colour. Icey's has a little more, and the **build for Icey** wrapper spreads your 2 bits over it.)

Keep your `counter` module, and replace `top`:

- x counts 0 … 799, y counts 0 … 524 (your two counters).
- `hsync` and `vsync` from the table.
- The **left half** of the visible area full red (`r = 3`), the **right half** full blue (`b = 3`).
- Everything outside the visible 640 × 480 must be black.
- Register the outputs (set them in an `always @(posedge clk)`, with a reset): they come out glitch-free, all one clock late together.

@exercise c7-sync

The monitor needs a whole frame (420,000 clocks) to show anything, and the simulator is slower than the real chip, so give it a few seconds.

```reflect
Why must the colour be black during the porches and sync pulses?
```

```sidequest
title: Lesson 9 of the course: state machines
link: #/l/fsm
time: 30 min
why: The most important pattern in digital design after counters: a traffic light and a combination lock. Your next chip will almost certainly have one.

title: A simple state machine
link: https://hdlbits.01xz.net/wiki/fsm1s
time: 10 min
why: The textbook two-state machine, with a synchronous reset like yours.
```
