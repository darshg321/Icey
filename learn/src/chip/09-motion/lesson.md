---
title: Motion
part: 3
blurb: A frame counter turns a still pattern into an animation. And a pause input to stop it.
---

A counter that goes up once per frame, mixed into your colour maths, makes everything scroll, pulse or spin, for the cost of a few flip-flops. Today your chip starts moving, and gets its **pause** input.

```recall
Q: Your chip has no memory for a picture. How does it decide a pixel's colour?
A: It computes it from x and y (and anything else it keeps track of) at the moment the beam reaches that pixel.
From: Session 8

Q: What must the colour be outside the visible 640 × 480?
A: Black (all zeros): monitors measure the black level during blanking.
From: Session 7

Q: In your `counter` module, when is `wrap` 1?
A: For the one clock where `en` is 1 and `value` is MAX − 1.
From: Session 6

Q: Where do your registers get their starting values?
A: From the reset (`if (!rst_n) ...`), never from `= 0`.
From: Session 5
```

## Learn

```resource
title: Racing the Beam: Colour Cycle and Bounce
url: https://projectf.io/posts/racing-the-beam/
source: Project F
time: 6 min
do: Read **Colour Cycle** and **Bounce**. Notice *when* in the frame they change things: during blanking, so the picture never changes halfway down.
```

```resource
title: VGA Playground: checkers, again
url: https://vga-playground.com/?preset=checkers
source: Tiny Tapeout
time: 4 min
do: This time read `counter` and the `layer_..._x` lines: the same checkerboard, shifted by the frame counter at different speeds, which is why it looks 3D.
```

## Predict

```predict
Q: You add `wire [9:0] sx = x + frame;` and draw with `sx` instead of `x`. Each frame, `frame` goes up by 1. Which way does the picture move, and how fast at 60 frames a second?
A: Left, by one pixel per frame: 60 pixels a second. The pixel that used to be at x + 1 is now drawn at x. (`x - frame` moves it right; `frame * 2` doubles the speed.)
```

## Build

1. A frame counter, `frame`, that goes up by 1 **once per frame**, just after the visible area (the clock where `x == 0` and `y == 480` is a good moment). It resets to 0, like everything else.
2. Use it in your colour maths so the picture moves.
3. A new input, `pause`: while it's 1, the frame counter stops, and the picture holds still.

@exercise c9-motion

```reflect
Why update the frame counter at y = 480 rather than, say, y = 100?
```

```sidequest
title: Random numbers: a 5-bit LFSR
link: https://hdlbits.01xz.net/wiki/lfsr5
time: 15 min
why: A shift register with XOR feedback makes pseudo-random numbers in a handful of gates. Starfields, noise and sparkle effects all use one.
```
