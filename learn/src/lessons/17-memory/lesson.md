---
title: Memory
part: 3
blurb: Block RAM, what makes the tools use it, filling it at power-up, and a little line editor that reverses what you type.
---

So far all your storage has been flip-flops: a few per counter, eight per shift register. The iCE40UP5K has 5,280 of them, which sounds like a lot until you want to store a screen of text, a recording, or a program. For that, the chip has dedicated memory blocks: 30 blocks of 4 kilobits each, called *block RAM* (BRAM), plus four big 256-kilobit blocks of *single-port RAM* (SPRAM). That's 15 KB and 128 KB respectively. The Apple I in lesson 23 had 4 KB of RAM in its standard configuration, and the SPRAM alone could hold 32 of those.

## Describing a memory

In Verilog, a memory is an array of registers:

```verilog
reg [7:0] mem [0:255];      // 256 words of 8 bits
```

That declares 256 entries, each 8 bits wide. You write to it in a clocked block, and read from it with an index:

```verilog
always @(posedge clk) begin
  if (we) mem[waddr] <= wdata;
  rdata <= mem[raddr];
end
```

Yosys recognises this pattern and maps it onto a block RAM. But only if you write it in a way the block RAM can actually do, and that's the important part of this lesson.

## Why the read has to be clocked

Look at `rdata <= mem[raddr];`. The read happens on a clock edge, so `rdata` shows the contents of `raddr` one clock *after* you set the address. That's called a *synchronous read*, and it's how the iCE40's block RAM physically works: it latches the address on the clock edge and produces the data afterwards.

Now suppose you write the read as a plain `assign rdata = mem[raddr];`. That asks for the data in the same clock as the address, an *asynchronous read*. The block RAM can't do that. Yosys does what it can: it builds your memory out of flip-flops and a gigantic multiplexer instead. For 256 bytes that's 2,048 flip-flops (40% of the chip) and a mux tree to match, and for anything larger it simply doesn't fit.

So the rule for FPGA memories: **register the read**. Your logic has to cope with the data arriving one clock later. It's the first time a design here has had *latency*, and it won't be the last; lesson 19 is largely about it.

@exercise ram

When it passes, press **build for Icey** and check the chip view. The memory should show up as one purple block RAM. The few dozen logic cells around it are mostly just carrying the 33 input and output signals between the pins and the RAM. Then, for comparison, change the read to an `assign` and build again.

## Filling it at power-up

A memory can start with contents in it, which makes it a ROM if you never write to it. For a few values, an `initial` block works:

```verilog
initial begin
  mem[0] = "H";
  mem[1] = "i";
end
```

For anything bigger, keep the data in a separate file and load it with `$readmemh`:

```verilog
initial $readmemh("font.hex", mem);
```

The file is plain text with one hex value per line. Yosys reads it at synthesis time and puts the contents straight into the bitstream, so the memory is full the instant the FPGA starts. It's how you'll load the Apple I's monitor program and its character font. (The browser has only one file, so the exercises here use `initial`. On your own machine, use `$readmemh`.)

## Project: a backwards line editor

Type a line in the terminal. Icey stores each character in block RAM as it arrives. When you press Enter, it sends the line back to you reversed, followed by `\r\n`. Type `hello` and you get `olleh`.

You'll need your `uart_rx` and `uart_tx`, a RAM, a write pointer that counts up as characters arrive, and a state machine that, on Enter (byte 13), walks the pointer back down and sends each character. Watch out for the RAM's one-clock read latency: set the address, then use the data on the *next* clock.

Ignore anything past 255 characters. The tests send a few lines of different lengths, including an empty one, which should come back as just `\r\n`.

@exercise reverse
