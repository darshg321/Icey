---
title: The heartbeat
part: 2
blurb: Clocks, flip-flops and counters, with a proper reset. The counter that will sweep your chip’s beam across the screen.
---

So far everything has reacted instantly. A VGA picture needs **time**: the beam sweeps across each line, 800 steps, again and again. That sweep is a counter, and today you build it. Slowed right down, it blinks LED1.

Today is also where your chip differs from an FPGA design. An FPGA loads every register with a starting value. **A real chip doesn't: at power-up its flip-flops hold random values.** So from today, every register gets its starting value from the reset, never from `= 0`.

```recall
Q: In an `always @(*)` block, what happens if some path doesn't give the output a value?
A: You get a latch: the output has to remember its old value. Give every output a value on every path (a `default`, or a value before the `if`).
From: Session 4

Q: How do you write "1 if all bits of `v` are 1"?
A: `&v`
From: Session 3

Q: What does the `_n` in `rst_n` tell you?
A: It's active low: 0 means reset.
From: Session 1
```

## Learn

```resource
title: Always blocks (clocked)
url: https://hdlbits.01xz.net/wiki/alwaysblock2
source: HDLBits
time: 4 min
do: `always @(posedge clk)` and `<=`. Rule: `<=` in clocked blocks, `=` in `always @(*)`.
```

```resource
title: D flip-flop
url: https://hdlbits.01xz.net/wiki/dff
source: HDLBits
time: 2 min
do: Solve it. A flip-flop copies its input on each clock edge and holds it in between.
```

```resource
title: DFF with reset
url: https://hdlbits.01xz.net/wiki/dff8r
source: HDLBits
time: 3 min
do: A synchronous reset: checked on the clock edge. This is the reset your chip uses everywhere.
```

```resource
title: Decade counter
url: https://hdlbits.01xz.net/wiki/count10
source: HDLBits
time: 5 min
do: A counter that wraps at a number you choose. Exactly what your beam counter does at 799.
```

## Predict

```predict
Q: ~~~verilog
always @(posedge clk)
  if (!rst_n) count <= 0;
  else if (count == 4) count <= 0;
  else count <= count + 1;
~~~
After reset is released, what values does `count` go through, and how many clocks before it repeats?
A: 0, 1, 2, 3, 4, 0, 1, … It repeats every **5** clocks, not 4: it counts 0 to 4 inclusive. To repeat every N clocks, compare with N − 1.
```

## Build

Icey runs this session's design at **12 MHz**. The module has a parameter `H_TOTAL`.

- `count` goes 0, 1, …, `H_TOTAL − 1`, then back to 0.
- LED1 changes state each time `count` wraps.
- While reset (SW2, `BTN`) is held, `count` is 0 and LED1 is off.
- **No starting values** (`reg x = 0`): set them in the reset.

With `H_TOTAL = 6_000_000` LED1 blinks once a second. The tests use `H_TOTAL = 5`, so use the parameter, not the number.

@exercise c5-heartbeat

One test fills every register with random values, then resets, like a real chip powering up. If you forget to reset something, that's the test that tells you.

```reflect
Why does an FPGA design get away with `reg led = 0;` when a chip can't?
```

```sidequest
title: Lesson 8 of the course: a button you can trust
link: #/l/buttons
time: 30 min
why: Debouncing and edge detection: every real input to a chip needs it. Your VGA chip uses switches, so it gets away without.

title: Slow decade counter
link: https://hdlbits.01xz.net/wiki/countslow
time: 5 min
why: A counter with an enable input, which is tomorrow's idea.
```
