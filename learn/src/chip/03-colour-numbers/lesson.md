---
title: Colours are numbers
part: 1
blurb: Vectors, slices, concatenation and reduction. Your chip’s 6-bit colour, previewed on the RGB LED.
---

Your chip will send the monitor a colour for every pixel: 2 bits of red, 2 of green and 2 of blue, so 64 colours. That colour is a 6-bit **vector**, one number made of six wires. Today you'll build it from six header pins and preview it on the RGB LED.

```recall
Q: Which operator is XOR, and when is `a ^ b` equal to 1?
A: `^`. When `a` and `b` are different.
From: Session 2

Q: Why do Icey's RGB pins need inverting?
A: The LED is wired from 5 V to the pin, so a pin at 0 turns its colour on: they're active low.
From: Session 2

Q: Is `assign` evaluated once, when the chip starts?
A: No. It's a connection that holds all the time.
From: Session 1
```

## Learn

```resource
title: Vectors
url: https://hdlbits.01xz.net/wiki/vector0
source: HDLBits
time: 4 min
do: Solve it.
```

```resource
title: Vector part select
url: https://hdlbits.01xz.net/wiki/vector2
source: HDLBits
time: 5 min
do: Taking a slice like `v[5:4]`. Solve it.
```

```resource
title: Vector concatenation
url: https://hdlbits.01xz.net/wiki/vector3
source: HDLBits
time: 4 min
do: Read the explanation of `{a, b}`. The first thing inside the braces becomes the top bits. Solving it is optional.
```

```resource
title: Reduction operators
url: https://hdlbits.01xz.net/wiki/reduction
source: HDLBits
time: 3 min
do: Read the first paragraph and examples: `|v` is 1 if *any* bit of `v` is 1; `&v` only if *all* are.
```

## Predict

```predict
Q: `wire [5:0] colour = 6'b110100;` Your chip's colour is laid out as `{r[1:0], g[1:0], b[1:0]}`. What are `colour[5:4]`, `colour[3:2]` and `colour[1:0]`, and what colour is it roughly?
A: `colour[5:4] = 2'b11` (red full), `colour[3:2] = 2'b01` (green a third), `colour[1:0] = 2'b00` (no blue): orange.
```

## Build

Header pins `P6` … `P1` form your chip's colour, `P6` as the top bit: `colour = {P6, P5, P4, P3, P2, P1}`, read as `rrggbb`.

The RGB LED can only switch each colour on or off, so preview it like this:

- red on if **any** red bit is set, the same for green and blue,
- LED1 on if the colour is **white** (every bit set).

Use slices and reduction operators; no comparing with `==`.

@exercise c3-colour

Click P1 to P6 on the photo and watch the colours mix.

```reflect
What does `|colour[5:4]` mean, in words?
```

```sidequest
title: Vector reversal
link: https://hdlbits.01xz.net/wiki/vectorr
time: 5 min
why: Flipping the bit order of a vector: harder than it sounds the first time.

title: More replication
link: https://hdlbits.01xz.net/wiki/vector5
time: 10 min
why: The `{n{x}}` repeat operator, which you'll want for spreading 2-bit colours onto wider outputs.

title: Lesson 3 of the course: buses and numbers
link: #/l/buses
time: 20 min
why: Binary, hex and widths, with a 7-segment display.
```
