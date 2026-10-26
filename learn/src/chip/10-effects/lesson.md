---
title: A second effect
part: 3
blurb: The effect input picks between two pictures. Your chip’s design is complete.
---

The last input: **effect**, which switches between two pictures. After today, the inside of your chip is finished: everything left is packaging it for manufacture, checking it, and shipping it.

```recall
Q: Why does the frame counter change just after the visible area?
A: So the picture never changes partway down the screen (no tearing).
From: Session 9

Q: How do you make the picture move right instead of left?
A: Subtract the frame counter (`x - frame`) instead of adding it.
From: Session 9

Q: `sel ? a : b`: which one do you get when `sel` is 1?
A: `a`.
From: Session 4

Q: What makes your chip's power-up state safe, even though flip-flops start random?
A: Every register is set by the reset.
From: Session 5
```

## Learn

No new reading today: you have everything you need. Spend the time on the picture. If you want ideas, flick through the [VGA Playground](https://vga-playground.com/?preset=rings) presets (`rings`, `drop`, `checkers`, `conway`) and Project F's [Racing the Beam](https://projectf.io/posts/racing-the-beam/) once more.

## Build

Add an input `effect`. When it's 0, show your existing pattern; when it's 1, a **different** one (different maths, not just different colours). Both should move with the frame counter and stop with `pause`.

Choose between the two with `? :`.

@exercise c10-effects

This module, with these ports, is the core of your chip. Next session it goes inside the Tiny Tapeout package unchanged.

```reflect
Describe your two effects in one sentence each, in terms of x, y and the frame counter.
```

```sidequest
title: Lesson 15 of the course: sending bytes to a PC
link: #/l/uart-tx
time: 40 min
why: A UART transmitter: a state machine, a baud-rate counter and a shift register together. The most useful interface a chip can have for debugging.
```
