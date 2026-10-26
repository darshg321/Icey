---
title: Test it like a chip
part: 4
blurb: Your own repository, and a testbench in Python with cocotb, run the way Tiny Tapeout runs it.
---

Chips can't be patched after they're made, so chip designers spend more time testing than designing. Today your design moves into its real home, a GitHub repository made from the Tiny Tapeout template, and you write its testbench: a Python program that drives the clock and reset, watches the pins, and fails if anything is off. The same test later runs on the post-layout netlist, which is how you know the manufactured chip will behave like your Verilog.

This session runs on your computer, not in the browser. Linux, macOS or Windows with WSL all work.

```recall
Q: How many clocks between hsync pulses, and how many between vsync pulses?
A: 800 and 420,000 (800 × 525).
From: Session 7

Q: Which `uo_out` bit is hsync, and which is vsync?
A: `uo_out[7]` is hsync, `uo_out[3]` is vsync.
From: Session 11

Q: What should `uio_oe` be in your chip, and why?
A: 0: your chip doesn't drive the bidirectional pins, and 0 makes them inputs.
From: Session 11
```

## Set up (10 minutes)

1. Open the [ttgf-verilog-template](https://github.com/TinyTapeout/ttgf-verilog-template), press **Use this template** → **Create a new repository**, make it public, and clone it.
2. Pick your module name: `tt_um_` + your GitHub username + a short name, e.g. `tt_um_yourname_vga`. It has to be unique on the chip.
3. Put your session 11 code in `src/project.v`, **without** Icey's `top`, and rename `tt_um_vga_demo` to your name. In `info.yaml`, set `top_module` to it.
4. Install the simulator and cocotb:
   - Linux / WSL: `sudo apt install iverilog`; macOS: `brew install icarus-verilog`
   - then, in the repository: `python3 -m venv venv && . venv/bin/activate && pip install -r test/requirements.txt`
5. In `test/tb.v`, change `tt_um_example` to your module name.

## Learn

```resource
title: cocotb: First steps
url: https://docs.cocotb.org/en/stable/first_steps.html
source: cocotb
time: 8 min
do: How a cocotb test drives a clock, sets inputs, waits with `await`, and checks outputs with `assert`.
```

```resource
title: The template's test README
url: https://github.com/TinyTapeout/ttgf-verilog-template/blob/main/test/README.md
source: Tiny Tapeout
time: 3 min
do: How to run the test (`make -B`), and later the gate-level version.
```

## Build

Replace `test/test.py` with this. It's a working test of the hsync timing:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly


async def reset(dut, ui=0):
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())   # about 25 MHz
    dut.ena.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


async def falling_edges(dut, bit, count, limit):
    """Clock numbers where uo_out[bit] goes from 1 to 0."""
    edges, last = [], 1
    for n in range(limit):
        await RisingEdge(dut.clk)
        await ReadOnly()
        v = (int(dut.uo_out.value) >> bit) & 1
        if last == 1 and v == 0:
            edges.append(n)
            if len(edges) == count:
                break
        last = v
    return edges


@cocotb.test()
async def test_hsync(dut):
    await reset(dut)
    edges = await falling_edges(dut, 7, 3, 5000)
    assert len(edges) == 3, "hsync never pulsed"
    assert edges[1] - edges[0] == 800, f"hsync period is {edges[1] - edges[0]}"
```

Run it from `test/` with `make -B`: it should pass. Then **add two tests yourself**:

1. `test_vsync`: vsync (bit 3) pulses every 420,000 clocks.
2. `test_bidirectional`: after reset, `uio_oe` is 0.

Check your tests can fail: change a number in `project.v`, run them, watch them catch it, and change it back. A test that can't fail proves nothing.

Commit and push. On GitHub, the **test** action runs the same thing.

```reflect
Your browser tests and your cocotb tests check the same chip. What can cocotb do that the browser can't? (Hint: think about what happens to your Verilog after synthesis and layout.)
```

```sidequest
title: Lesson 24 of the course: verify like a chip company
link: #/l/verify
time: 40 min
why: Formal verification: instead of testing some inputs, prove a property holds for all of them.

title: Lesson 14 of the course: testbenches
link: #/l/testbench
time: 30 min
why: Testbenches written in Verilog itself, the other common style.
```
