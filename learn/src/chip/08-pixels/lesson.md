---
title: Racing the beam
part: 3
blurb: No memory for a picture, so compute every pixel from its position. Your chip’s look.
---

Your chip has room for a few hundred logic gates and no memory for a picture. It doesn't need one: it works out each pixel's colour from `x` and `y` at the moment the beam gets there, 25 million times a second. This session is the creative one. Make something you like; it's what people will see.

```recall
Q: What's the first x where hsync goes low, and how long is the pulse?
A: 656 (640 visible + 16 front porch), for 96 clocks.
From: Session 7

Q: Why register the outputs?
A: Comparisons glitch briefly while counters change; a glitch on sync can look like a pulse. Registering removes glitches and delays every output by the same one clock.
From: Session 7

Q: `x[8:3]`: how many bits, and how often does it change as x counts up?
A: 6 bits; it goes up by one every 8 pixels.
From: Session 3
```

## Learn

```resource
title: Racing the Beam
url: https://projectf.io/posts/racing-the-beam/
source: Project F
time: 8 min
do: Read the intro, **Raster Bars** and **Hitomezashi**. Skip "Hello" (it needs memory). Stop before "Colour Cycle"; that's next session.
```

```resource
title: VGA Playground: checkers
url: https://vga-playground.com/?preset=checkers
source: Tiny Tapeout
time: 4 min
do: Find where the colour is computed from `pix_x` and `pix_y` (their x and y). Then try `?preset=rings` and `?preset=drop`.
```

## Predict

```predict
Q: `wire [5:0] colour = x[8:3] ^ y[8:3];` What does the screen look like, roughly?
A: Blocks of 8 × 8 pixels in a self-similar grid of nested squares, using all 64 colours. XOR of the coordinates is the classic one-line demo effect.
```

## Build

Your design from last session, with the left/right colour replaced by a **pattern of your own**, computed from `x` and `y`, with **at least 8 different colours** on screen. Ideas to start from, then change:

- `x ^ y`: XOR some bits of each.
- stripes: `x + y` or `x - y`, take some bits.
- a checkerboard: one bit of `x` XOR one bit of `y`, choosing between two colour expressions.

Change which bits you use and run again; that's the fastest way to understand it.

@exercise c8-pixels

```reflect
Which bits of x did you use, and what happened when you used lower ones?
```

```sidequest
title: Lesson 12 of the course: PWM
link: #/l/pwm
time: 30 min
why: Brightness from fast on/off switching, and a breathing LED. The same counter-and-compare idea, used for audio and motors.

title: Shift registers
link: https://hdlbits.01xz.net/wiki/shift4
time: 10 min
why: The other basic building block, alongside counters.
```
