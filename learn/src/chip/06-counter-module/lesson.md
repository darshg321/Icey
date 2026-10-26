---
title: Two counters, one module
part: 2
blurb: Modules, parameters and enables. The beam’s x and y counters, built from one module you write once.
---

The beam needs two counters: **x** goes across a line (800 steps), and **y** goes down the screen, one step each time x wraps (525 lines). They're the same counter with different sizes, so you'll write it once as a module and use it twice. This session's design starts from last session's.

```recall
Q: A counter compares with `N - 1` to wrap. How many clocks does one full cycle take?
A: N: it counts 0 to N − 1.
From: Session 5

Q: Why does your chip set starting values in the reset instead of writing `reg x = 0`?
A: A real chip powers up with random values in its flip-flops and ignores `= 0`. Only the reset puts them in a known state.
From: Session 5

Q: `<=` or `=` inside `always @(posedge clk)`?
A: `<=`.
From: Session 5

Q: What's `|v` for a vector `v`?
A: 1 if any bit of `v` is 1.
From: Session 3
```

## Learn

```resource
title: Modules
url: https://hdlbits.01xz.net/wiki/module
source: HDLBits
time: 5 min
do: Read the whole explanation: instances, and connecting them.
```

```resource
title: Connecting ports by name
url: https://hdlbits.01xz.net/wiki/module_name
source: HDLBits
time: 3 min
do: Always connect by name, `.port(signal)`. It's much harder to get wrong.
```

```resource
title: Three modules
url: https://hdlbits.01xz.net/wiki/module_shift
source: HDLBits
time: 5 min
do: Several instances of one module, chained together, the way your two counters will be.
```

HDLBits doesn't cover parameters. A module can declare them with defaults, and each instance can override them:

```verilog
module counter #(parameter MAX = 800, parameter W = 10) ( ... );

counter #(.MAX(525)) ycount ( .clk(clk), ... );
```

## Predict

```predict
Q: x counts 0 … 3 (MAX 4) and y counts 0 … 2 (MAX 3), and y only steps when x wraps. Starting from both at 0, how many clocks until both are back at 0?
A: 4 × 3 = **12**. That's why a VGA frame is 800 × 525 = 420,000 clocks.
```

## Build

1. A module `counter` with parameters `MAX` and `W` (the width of the count), and ports `clk`, `rst_n`, `en` (count only when 1), `value` (`[W-1:0]`) and `wrap`. `wrap` is 1 during the clock where `en` is 1 and `value` is `MAX − 1`, so it's exactly the moment the counter wraps. Reset sets `value` to 0.
2. In `top`, two instances: `x` counts every clock (`en` tied to 1) up to `H_TOTAL`; `y` counts when `x` wraps, up to `V_TOTAL`.
3. LED1 toggles every time **y** wraps, so once per "frame".

With the defaults (6000 × 1000) LED1 changes twice a second. The tests make the counters tiny.

@exercise c6-counters

```reflect
Your `counter` module doesn't know whether it's counting pixels or lines. What decides that?
```

```sidequest
title: Generate loops: a 100-bit adder
link: https://hdlbits.01xz.net/wiki/adder100i
time: 15 min
why: Making 100 instances of a module with a `for` loop, which is how big regular hardware gets built.

title: Modules and vectors
link: https://hdlbits.01xz.net/wiki/module_shift8
time: 10 min
why: Instances with vector ports, plus a multiplexer to pick an output.
```
