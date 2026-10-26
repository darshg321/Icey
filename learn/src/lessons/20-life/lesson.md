---
title: 128 cells per clock
part: 4
blurb: Conway's Game of Life, built as hardware instead of software. Generate loops, massive parallelism, and why an FPGA beats a PC with a clock more than a hundred times faster.
---

Part 4 is about the things FPGAs are actually *for*, the things where a $10 chip outruns a desktop computer. The first one is the purest example there is.

## The Game of Life

John Conway's Game of Life is a grid of cells, each alive or dead. Every generation, every cell looks at its eight neighbours and decides its next state by two rules. A live cell with two or three live neighbours survives; otherwise it dies. A dead cell with exactly three live neighbours comes alive. That's the whole game. From those two rules come gliders that walk across the grid, oscillators, guns that fire gliders forever, and (people have proved this) a working computer, if you make the grid big enough.

On a CPU, you'd loop over every cell, count its neighbours, apply the rule, and write the result into a second grid. For a 128×128 grid that's 16,384 cells, each needing eight memory reads and some arithmetic, every generation. A fast PC with well-written NumPy manages about ten thousand generations a second on a grid that size.

Now think about it as a circuit. The rule for one cell is a small combinational function of nine bits. There's no reason to compute the cells one at a time. You could build one rule circuit *per cell* and compute them all at once.

@exercise rule

## Copies, by the dozen: generate

You need 64 copies of `life_rule` for an 8×8 board, each wired to a different set of neighbours. Writing 64 instantiations by hand is silly. Verilog's `generate` loop stamps out copies for you:

```verilog
genvar r, c;
generate
  for (r = 0; r < 8; r = r + 1) begin : row
    for (c = 0; c < 8; c = c + 1) begin : col
      localparam L = (c + 7) % 8, R = (c + 1) % 8;   // wrap around
      // ... U and D the same way for the rows
      life_rule rule(.self(cells[r*8 + c]), .neighbours({...}), .next(next[r*8 + c]));
    end
  end
endgenerate
```

Like the `for` loop in the double-dabble converter, this doesn't run. It's a recipe that Yosys follows at build time, producing 64 separate circuits, each with its own wiring. `genvar` declares a loop variable that only exists during that expansion. The names after `begin :` label each copy, so the copies end up called `row[3].col[5].rule` and so on, which you'll see in the log.

The `% 8` makes the board wrap around: the left neighbour of column 0 is column 7. Topologically that's a doughnut, and it means gliders that walk off one edge come back on the other.

Every one of those 64 rule circuits calculates at the same time, on every clock. A whole generation takes one clock cycle. At 12 MHz this design could run twelve million generations a second, if it had any reason to.

@exercise board8

Run it on the board and watch the glider crawl diagonally, leave through the bottom right, and come back in at the top left.

## The real thing: 128×128 on Icey

64 cells is a toy. The `life.ice` project in the Icey repository runs a 128×128 grid, and it's worth understanding how, because it shows the trade-off at the heart of FPGA design.

A full 128×128 grid of rule circuits would be 16,384 copies, and each one needs a few LUTs. The UP5K has 5,280 LUTs, so that doesn't fit, not even close. So `life.ice` builds **one row** of rules: 128 copies side by side. The grid itself lives in block RAM, 128 bits per row. Every clock, the engine reads one row from the RAM into a sliding window of three rows (above, current, below), and the 128 rule circuits compute the whole new row at once. The new row goes into a second copy of the grid in RAM, so it doesn't overwrite rows that are still needed. When the generation is done, the two copies swap roles. That's *double buffering*, the same trick graphics cards use to avoid showing half-drawn frames.

So a generation takes 128 clocks, plus a few to fill the window: 134 in total. At 24 MHz that's

24,000,000 / 134 ≈ 179,000 generations per second

and measured on the board it's **178,540 generations per second**, which is **2.93 billion cell updates per second**. That's about 17 times faster than NumPy on the PC that's sending the commands, a machine whose clock runs more than a hundred times faster. The FPGA wins because it does 128 cells of work on every tick of its clock, and the PC, even with clever vector instructions, can't.

The design is also *checked*. The `life.py` script uploads a random grid, lets the FPGA run flat out, reads the grid back, and compares every cell against NumPy running the same number of generations. On the bring-up board it ran about 20,000 generations and matched cell for cell. When you're claiming a design is fast, being able to prove it's also right is what makes the number mean anything. Lesson 24 makes a habit of that.

To run it yourself, open `firmware/examples/icestudio/life.ice` in Icestudio and upload it, or just run the whole show:

```sh
./firmware/life-demo.sh
```

That script builds and loads the showcase design, then plays the grid in your terminal, runs a benchmark, and finishes with the cell-for-cell proof. If you have a USB keyboard, plug it into Icey's PERIPHERAL port and you can steer the show from the board.

Look at what else you now recognise in that design: a UART at 3 megabaud (8 clocks per bit at 24 MHz), block RAM with a registered read, a state machine scheduling the engine, a generate loop. Everything in it is something you've built.
