---
title: Meet Icey
part: 2
blurb: The real board, what's on it, getting the tools installed, and putting your first design on an actual chip.
---

Everything up to now ran inside this page. The circuits were real, in the sense that they were the exact gates Yosys would have built, but the electricity was imaginary. Time to change that.

![The Icey board](img/icey-photo.webp)

## A tour

Going round the board from the chip outwards:

**The FPGA** in the middle-left is the iCE40UP5K, in a 48-pin package 7 mm across. It has 5,280 logic cells, 30 blocks of 4-kilobit RAM, 4 large blocks of 256-kilobit RAM (128 KB in total), 8 multiplier blocks, and a PLL for making clocks. You'll use every one of those before the end of the course.

**The programmer** is the big square chip bottom-right, an FTDI FT2232H. It's a USB-to-everything converter with two independent channels. Channel A talks SPI to the FPGA and the flash chip, and that's how bitstreams get loaded. Channel B is a plain serial port wired to two FPGA pins, so once your design is running it can talk to your computer. That's lesson 15.

**The flash** (the 8-pin chip labelled QSPI FLASH) holds 16 MB. An FPGA's configuration lives in SRAM, which forgets everything when the power goes, so normally a board stores its bitstream in a flash chip and the FPGA reads it back at power-up.

**The USB host chip** next to the PERIPHERAL USB-C port is a MAX3421E. It lets the FPGA be a USB host, so you can plug a keyboard straight into Icey. **The microSD slot** and the USB host chip share one SPI bus. There's a **VGA connector** along the bottom edge, driven by a little resistor network that turns 8 FPGA pins into 256 colours.

**The human interface** is modest: LED1 (pin `LED`, active high), an RGB LED, the button SW2 (pin `BTN`, active low, as you know), and a RESET button. A second LED, LED2, lights up when the FPGA *isn't* configured, which is a handy "is my design loaded?" check. Down the left side is a header with nine spare FPGA pins (`P1` to `P9`) plus ground, 3.3 V and 5 V.

The full pin list is in `firmware/icey.pcf` in the Icey repository. Every name you use for a top-level port must match a name in that file, which is why the browser board has been using `LED` and `BTN` all along.

## Two quirks of this board

Every board has quirks, and these two are worth knowing on day one.

**There is no clock crystal.** Most FPGA boards have a crystal oscillator wired to a clock pin. Icey uses the oscillator built into the iCE40 itself, a block called `SB_HFOSC`. It runs at 48 MHz and has a divider, so you can get 48, 24, 12 or 6 MHz. It's not very precise, within about 10% according to the datasheet, but in practice the one on the bring-up board was close enough for a 3-megabaud serial link. The examples all use 12 MHz, and so does this course.

**This revision can't boot from its flash.** On rev 1 of the board, two data lines between the FPGA and the flash are swapped relative to what the iCE40 expects when it boots. Loading a design over USB works perfectly, and the flash itself works fine from your own logic (lesson 21 reads it), but the FPGA can't load itself from flash at power-up. So after you unplug Icey, the design is gone and you need to load it again. It takes about a second. Rev 2 fixes the wiring.

## Installing the tools

Up to now you've needed nothing but a browser. For the real board you need a way to send bitstreams over USB, and a few lessons from now you'll want the full toolchain on your own machine. The Icey repository has a script that sets everything up on Linux:

```sh
git clone --recurse-submodules https://github.com/darshg321/Icey
cd Icey
firmware/tools/setup.sh
```

It makes a Python virtual environment in `~/.local/share/icey/venv` with Yosys, nextpnr and icepack (the same WebAssembly builds this site uses, packaged for the command line) and `pyftdi`, then installs a udev rule so your user account can open the board's USB chip. That last step asks for your password. **Unplug Icey and plug it back in afterwards**, because the new permissions only apply to newly connected devices.

Use the USB-C port labelled PROGRAMMER. The other one is the USB host port, for keyboards.

## Getting a design onto the chip

There are three routes, and you'll end up using all of them.

**From this site.** Every exercise has a **build for Icey** button. It runs Yosys and nextpnr right here in the page, then gives you a bitstream. In Chrome or Edge you can press **Upload to Icey** and the page loads it over USB using WebUSB. In other browsers, download the `.bin` file and load it with `iceyprog`:

```sh
~/.local/share/icey/venv/bin/python firmware/tools/iceyprog.py sram design.bin
```

`iceyprog` is Icey's programmer. Stock tools like `iceprog` expect a different pin layout on the FTDI chip and can't load this board; the README in `firmware/` explains why if you're curious. When the load works it prints `CDONE = 1`, LED2 goes out, and your design starts running.

**From Icestudio.** A graphical tool where you wire blocks together, and you can put Verilog inside blocks. The next lesson but one is all about it.

**From the command line.** `make prog` in any example folder. Part 3 starts there.

## Your first real circuit

Go back to lesson 1's design, the one where the LED lights while you hold the button. It's already in the workbench. Press **build for Icey**. You'll see the chip view: a map of the iCE40 with the few cells your design uses lit up. Then upload it, by button or by `iceyprog`, and press SW2 on the real board.

@exercise first-light

It's a small thing, an LED and a button, but take a second with it. Your text went through the same synthesis tool, the same placer and router, the same bitstream packer that people use for satellite and particle-detector designs, and now there's a physical path through the chip from pin 6 to pin 9 that didn't exist a minute ago.

## The clock, for real

Now the blink from lesson 6. The browser gave you `clk` for free. On Icey you make it yourself, by placing an `SB_HFOSC`:

```verilog
wire clk;
SB_HFOSC #(.CLKHF_DIV("0b10")) osc (
  .CLKHFEN(1'b1),    // enable the output
  .CLKHFPU(1'b1),    // power the oscillator up
  .CLKHF(clk)        // 48 MHz divided by 4: 12 MHz
);
```

This is an instantiation, just like the full adders in lesson 4, except the module isn't one you wrote. `SB_HFOSC` is a *primitive*: a block of hardware that physically exists on the iCE40, which Yosys knows about. The `#(...)` sets a parameter, the divider. `"0b10"` divides by 4; `"0b00"`, `"0b01"` and `"0b11"` give 48, 24 and 6 MHz.

The browser simulator can't run primitives like this one (it only knows gates and flip-flops), so this exercise goes straight to the build. Notice that you never had to write this in Part 1: when a design has a `clk` input, the workbench's **build for Icey** quietly wraps it in this same oscillator. Now you know what that wrapper does.

@exercise hfosc

If your LED blinks a little faster or slower than once a second, that's the internal oscillator's tolerance. Time it against a stopwatch over a minute if you're curious how far off your particular chip is.
