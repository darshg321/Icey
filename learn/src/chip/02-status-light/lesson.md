---
title: The status light
part: 1
blurb: AND, OR, NOT and XOR. An RGB light that shows what your chip is doing.
---

Your chip will have three controls: **reset** (hold to start over), **pause** (freeze the animation) and **effect** (switch pictures). Today you'll build a status light that shows which one is active, out of nothing but logic gates.

```recall
Q: What does `assign out = in;` describe: something that happens once, or something that's always true?
A: Always true. It's a wire: `out` follows `in` at every moment, forever.
From: Session 1

Q: SW2 reads 0 while pressed. What's the name for that, and how do you get a signal that's 1 while pressed?
A: Active low. `~BTN` is 1 while the button is pressed.
From: Session 1
```

## Learn

```resource
title: AND gate
url: https://hdlbits.01xz.net/wiki/andgate
source: HDLBits
time: 2 min
do: Solve it.
```

```resource
title: XNOR gate
url: https://hdlbits.01xz.net/wiki/xnorgate
source: HDLBits
time: 4 min
do: The explanation lists every bitwise operator: `&` AND, `|` OR, `^` XOR, `~` NOT. Keep it open while you build.
```

```resource
title: Declaring wires
url: https://hdlbits.01xz.net/wiki/wire_decl
source: HDLBits
time: 5 min
do: How to name an in-between signal with `wire`. It makes logic much easier to read.
```

## Predict

```predict
Q: Icey's RGB LED is wired from 5 V to the FPGA pins, so the FPGA lights a colour by pulling its pin **low**. What colour do you see with `RGB0 = 0` (red), `RGB2 = 0` (green), `RGB1 = 1` (blue)?
A: Yellow: red and green are on, blue is off. The RGB pins are active low, like the button.
```

## Build

| Port | Part | Meaning in your chip |
|---|---|---|
| `BTN` | SW2 | reset, 0 while held |
| `P1` | header pin 1 (click its ring) | pause |
| `P2` | header pin 2 | effect |
| `RGB0`, `RGB2`, `RGB1` | RGB LED red, green, blue | 0 = on |

The status light:

- **red** while reset is held,
- otherwise **blue** if paused,
- otherwise **green** (running).
- LED1 shows the effect switch (on when `P2` is 1).

Only one colour is ever on. Write the rule for each colour being *on* as a `wire`, then invert it for its pin.

@exercise c2-status

```reflect
"Otherwise blue if paused": which part of your blue rule is the "otherwise"?
```

```sidequest
title: Lesson 4 of the course: an adder from gates
link: #/l/adder
time: 25 min
why: The same gates, put together to add numbers: a half adder, a full adder, then four of them in a row. Every counter you build later has one inside.

title: Find the bug
link: https://hdlbits.01xz.net/wiki/bugs_mux2
time: 5 min
why: Reading someone else's broken Verilog is a skill of its own.
```
