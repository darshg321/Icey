---
title: Your chip’s first signal
part: 1
blurb: What a module is. Your chip’s reset line, shown on an LED.
---

By the end of this project you'll have designed a chip that draws animated graphics on a VGA monitor, and sent it off to be manufactured. Every session adds one piece. Today's piece is the smallest one there is: a wire.

Your chip will have a **reset** input. While reset is held, the chip starts over. On Icey, the button SW2 plays that part, so today you'll make LED1 show when reset is being held.

## Learn

A chip, and a piece of Verilog, is a **module**: a box with named pins (ports) going in and out, and something inside connecting them. These HDLBits problems each take a couple of minutes. Read the explanation, write the answer, press Submit.

```resource
title: Getting Started
url: https://hdlbits.01xz.net/wiki/step_one
source: HDLBits
time: 3 min
do: What a `module` and its ports look like. Solve it.
```

```resource
title: Simple wire
url: https://hdlbits.01xz.net/wiki/wire
source: HDLBits
time: 5 min
do: Read all of it. The key idea: `assign` is a permanent connection, not a step that runs once.
```

```resource
title: Inverter
url: https://hdlbits.01xz.net/wiki/notgate
source: HDLBits
time: 2 min
do: `~` flips a signal. You need it today.
```

## Try it in your head first

```parsons
Put these lines in order to make a module that connects `in` to `out`.
---
module wire_it(
  input  in,
  output out
);
  assign out = in;
endmodule
```

```predict
Q: SW2 reads **0 while you press it** and 1 otherwise (a resistor pulls it up). With `assign LED = BTN;`, what does LED1 do?
A: It's on when the button is *not* pressed, and goes off while you press it: LED1 follows the pin level, and the pin is 1 at rest. Signals that mean "yes" when they're 0 are called **active low**. Your chip's reset, `rst_n`, is active low too; the `_n` is the usual way to say so.
```

## Build

LED1 (`LED`) should be on **while SW2 is held**, and off otherwise. Click SW2 on the photo, or hold the space bar.

@exercise c1-reset-light

The other small LED next to the buttons is LED2. On the real board it's lit while the FPGA is empty, so it goes out once a design is running.

```reflect
Why does LED1 need a `~` here? Use the words "active low".
```

```sidequest
title: The 7458 chip
link: https://hdlbits.01xz.net/wiki/7458
time: 15 min
why: A real 1970s logic chip described in Verilog: several gates, internal wires, four outputs. Good practice at wiring things up.
```

### On the real board (whenever you like)

Press **build for Icey**, then **Upload to Icey (USB)** in the Chip tab, or **Download .bin** and load it with `iceyprog.py sram top.bin`.
