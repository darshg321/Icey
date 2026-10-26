---
title: Ship it
part: 4
blurb: GitHub builds the chip layout, you read the reports, try it in the VGA Playground and on Icey, and submit.
---

Today GitHub turns your Verilog into a manufacturable layout: standard cells from the GF180 process placed and wired inside your tile, checked against the foundry's rules. Then you look at it from every side, and send it off.

```recall
Q: Why should you deliberately break your design once and rerun the tests?
A: To check the tests can fail. A test that passes no matter what proves nothing.
From: Session 12

Q: What does `uio_oe = 0` mean?
A: All the bidirectional pins are inputs: your chip never drives them.
From: Session 11

Q: In which part of the frame does your frame counter change, and why?
A: Just after the visible area, so the picture never changes partway down the screen.
From: Session 9
```

## 1. Fill in the details (5 minutes)

In `info.yaml`: `clock_hz: 25175000`, leave `tiles` at `"1x1"`, fill in the title, author and description, and the pinout (`ui[0]`: pause, `ui[1]`: effect, `uo[0]` … `uo[7]`: the TinyVGA names). In `docs/info.md`, two or three sentences on what it draws and how to use the switches.

## 2. Build the layout

Commit and push. Open the **Actions** tab on GitHub and watch the **gds** job; the first run takes a while.

```resource
title: Tiny Tapeout FAQ
url: https://tinytapeout.com/faq/
source: Tiny Tapeout
time: as needed
do: If an action fails, the common causes are here, including the "pages" step, which needs GitHub Pages enabled.
```

When it's green, read its summary:

- **Utilisation**: how much of your tile you used. A design like yours lands around 15%.
- **Cell usage**: the gates your Verilog became. Find the flip-flops (`dffq`): how many did you expect from your registers?
- **Timing**: you may see *setup violations* at the `ss_125C` (slow, hot) corners. Tiny Tapeout checks every design at 50 MHz (20 ns), but yours runs at 25.175 MHz (39.7 ns), so it has 19.7 ns more than the check assumes. Setup slack better than about −19 ns is fine for you. **Hold** violations are not fine.

The **gl_test** job reruns your cocotb tests on the netlist from the layout: the same gates that will be manufactured.

## 3. See it

- **VGA Playground**: open `https://vga-playground.com/?repo=` followed by your repository's URL. It runs your actual design from GitHub. If the picture is right there, your pinout is right.
- **On Icey**: go back to session 11, press **build for Icey**, load it (**Upload to Icey (USB)**, or **Download .bin** then `iceyprog.py sram top.bin`), and plug in a VGA monitor. SW2 resets; wire header P1 and P2 to the header's 3V3 or GND pins for pause and effect (don't leave them floating).

## 4. Submit

Post your repository in **#asic** on the Hack Club Slack and follow the current steps there: Hack Club sends an Icepi Zero FPGA board and a logic analyser after you ship, and you submit the same design for the shared chip once it's tested on that board.

```reflect
What would you change about your chip if you did it again?
```
