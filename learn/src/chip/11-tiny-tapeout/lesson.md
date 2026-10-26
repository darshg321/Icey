---
title: The Tiny Tapeout package
part: 4
blurb: Your design inside the module the shared chip expects, with the standard VGA pinout, and a wrapper so the same file runs on Icey.
---

The shared chip gives every design the same pins: 8 inputs (`ui_in`), 8 outputs (`uo_out`), 8 bidirectional pins (`uio_*`), `clk`, `rst_n` and `ena`. Your top module has to have exactly those ports and be called `tt_um_` something. Today you package your design to fit, without changing what's inside.

```recall
Q: What are your chip's inputs, and which one is active low?
A: `clk`, `rst_n` (active low), `pause` and `effect`.
From: Sessions 7–10

Q: Connecting a module instance: by position or by name, and why?
A: By name, `.port(signal)`: order mistakes can't happen.
From: Session 6

Q: Why does your chip work even though flip-flops power up random?
A: Every register is set by the reset; one test even checks it from random states.
From: Session 5
```

## Learn

```resource
title: The template's project.v
url: https://github.com/TinyTapeout/ttgf-verilog-template/blob/main/src/project.v
source: Tiny Tapeout
time: 3 min
do: The port list you'll copy, and the rules in the comments: every output assigned, unused inputs listed in `_unused`.
```

```resource
title: Pinouts: TinyVGA
url: https://tinytapeout.com/specs/pinouts/
source: Tiny Tapeout
time: 3 min
do: Find the **TinyVGA** table: which `uo_out` bit is which colour bit and which sync. Use it exactly, so your chip works with the standard VGA adapter.
```

## Predict

```predict
Q: Your core has outputs `hsync`, `vsync`, `r[1:0]`, `g[1:0]`, `b[1:0]`: 8 signals. The TinyVGA table says `uo_out[0]` is R1, `[4]` is R0, `[7]` is HSync. In `assign uo_out = { ... };`, which signal comes first in the braces?
A: `hsync`: the first thing in `{ }` is the top bit, `uo_out[7]`. So it starts `{hsync, b[0], g[0], r[0], vsync, ...}`. Check the rest against the table yourself.
```

## Build

Three modules in one file (plus your `counter`):

1. **`vga_core`**: your session 10 module, renamed. Nothing inside changes.
2. **`tt_um_vga_demo`**: the Tiny Tapeout module. One `vga_core` inside, connected: `ui_in[0]` → `pause`, `ui_in[1]` → `effect`, `rst_n` → `rst_n`, `uo_out` ← the TinyVGA order, `uio_out` and `uio_oe` = 0 (you don't use those pins; `uio_oe = 0` makes them inputs).
3. **`top`**: Icey pretending to be the Tiny Tapeout board. One `tt_um_vga_demo` inside, with SW2 (`BTN`) as `rst_n`, header `P1`/`P2` as `ui_in[0]`/`ui_in[1]`, and `uo_out` driving Icey's VGA pins.

The tests check `tt_um_vga_demo` through its pins, the way the real chip will be used, and also run your `vga_core` alone to check every `uo_out` bit carries the right signal. (Keep the name `tt_um_vga_demo` for now; when you ship, it gets your GitHub username.)

@exercise c11-tiny-tapeout

```reflect
Your `top` for Icey and `tt_um_vga_demo` both contain your design. Which one goes on the real chip, and what is the other one for?
```

```sidequest
title: Lesson 17 of the course: memory
link: #/l/memory
time: 40 min
why: Block RAM and ROM on the FPGA. On a chip, memory is the scarce thing: knowing what it costs shapes every design.
```
