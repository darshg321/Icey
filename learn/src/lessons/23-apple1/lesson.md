---
title: An Apple I, gate for gate
part: 4
blurb: Recreate the computer that started Apple, from its memory map to its quirks, and run the original 1976 monitor program on it.
---

In 1976 Steve Wozniak designed a computer that was mostly a 6502 processor, a few kilobytes of RAM, a keyboard interface, a video terminal and a 256-byte program to tie it together. About two hundred were made. Steve Jobs sold them for $666.66. It was the Apple I, and the company named after it is doing fine.

You're going to rebuild it, faithfully, on Icey. Not an emulator running on a processor, but the same architecture in hardware: a 6502 executing real 6502 machine code at 1 MHz, the same memory map, the same peripheral registers, and the same monitor program that Woz wrote, byte for byte. Every part of it is something you've already built a smaller version of.

## The architecture

The whole Apple I fits in one table:

| address | what | ours |
|---|---|---|
| `$0000`–`$0FFF` | RAM, 4 KB as shipped | 8 KB of block RAM, `$0000`–`$1FFF` |
| `$D010`–`$D013` | a Motorola 6821 PIA: keyboard in, display out | a PIA module, wired to the serial port |
| `$FF00`–`$FFFF` | 256 bytes of ROM: the Woz Monitor | 256 bytes of block RAM, loaded at build time |

The CPU sees nothing but this map. When it puts an address on its bus, the *address decoder* decides which chip answers. Woz did that with a few logic chips; you'll do it with three comparisons.

@exercise decode

## The CPU

Designing a 6502 from scratch is a big project in its own right; it has 56 instructions, 13 addressing modes and a lot of quirks that real programs depend on. Instead we'll use a core that already exists and has been tested for years: Arlet Ottens' `verilog-6502`, which runs real 6502 software in a lot of FPGA projects. Its licence lets you use it in anything, as long as the copyright notice stays with the code, and it's included in this exercise automatically. Taking a proven core instead of writing your own is what engineers do with any part that isn't the point of the project, and the point here is the computer around the processor. (You did build a processor of your own in the last lesson, so you know what's inside this one.)

Its interface is small:

```verilog
cpu cpu(.clk(clk), .reset(reset), .AB(ab), .DI(din), .DO(dout), .WE(we),
        .IRQ(1'b0), .NMI(1'b0), .RDY(en));
```

`AB` is the 16-bit address bus. `DO` and `WE` carry writes out. `DI` is the data coming back, and the core expects it one clock *after* the address, which is how block RAM behaves, so the RAM and ROM can be wired straight to it. That also means the multiplexer choosing which chip's data goes to `DI` has to look at where the address was *one clock ago*. Get that wrong and the CPU reads the right data from the wrong chip, which is a very confusing bug.

`RDY` pauses the CPU when it's low. We use it as a clock enable: run the system at 12 MHz, raise `RDY` on one clock in twelve, and the 6502 runs at 1 MHz, the speed of the original. Faithful timing matters for some old software, which counts instructions to make delays.

## The PIA, and Woz's terminal

The original Apple I had a separate circuit that turned characters into video on a TV: 40 columns, 24 lines, upper case only, and so slow it could only draw about 60 characters a second. The keyboard was a separate ASCII keyboard. Both connected to the 6502 through a Motorola 6821 Peripheral Interface Adapter, which appears as four registers:

| address | name | reading | writing |
|---|---|---|---|
| `$D010` | KBD | the key, with bit 7 set | |
| `$D011` | KBDCR | bit 7: a key is waiting | control |
| `$D012` | DSP | bit 7: display still busy | a character to show |
| `$D013` | DSPCR | | control |

The monitor's input loop is short: wait until `KBDCR` bit 7 is set, read `KBD` (which also clears the flag). Its output routine is shorter: wait until `DSP` bit 7 is clear, write the character to `DSP`.

There's one faithful detail worth copying. A real 6821 has a *direction register* behind each data register, and bit 2 of the control register chooses which one you reach at the data address. After reset that bit is 0, and the very first thing the Woz Monitor does is write `$7F` to `DSP`, which on real hardware sets the direction of seven pins and draws nothing. If your PIA treats that as a character, every reset prints a garbage byte. So model the control registers, and send `DSP` writes to the display only once `DSPCR` bit 2 has been set.

@exercise pia

Our terminal is the serial port, so the "display" is your computer's terminal window, or the one in this page. The starter code includes `display` and `keyboard` modules that make it behave like the original: carriage returns become a new line, letters are forced to upper case, and backspace becomes `_`, which is what the Woz Monitor uses for rubout.

## Project: the Apple I

Wire it all together: reset (at power-up, and whenever SW2 is held, like the RESET key on the original), the clock enable, the CPU, the decoder, RAM, ROM, keyboard, PIA, display, and the delayed read mux. The tests don't need Apple's code. They load their own little 6502 programs into your ROM: one prints "HI", one echoes the keyboard, and one uses RAM at both ends of the map, plus the stack.

In the browser, the board runs the 6502 at full simulation speed rather than at 1 MHz (the simulator can't quite keep up with real time on a design this size), and you'll see a placeholder program in the ROM that tells you to load the monitor.

@exercise apple1

## Loading the Woz Monitor

The monitor is 256 bytes of 6502 code. It was printed in hex in the back of the Apple-1 Operation Manual in 1976, and that listing has been copied into countless places since; search for "wozmon hex" and you'll find it. The first line should read `FF00: D8 58 A0 7F 8C 12 D0 A9`. Paste the listing here, or choose a `wozmon.bin` file, to get the `initial` block for your ROM:

@widget romtool {"name":"rom","size":256}

Replace the placeholder block in your `rom` with it and press Run. The terminal shows a backslash, `\`, the monitor's prompt. Now you're using a 1976 computer. Its commands look like this:

```
FF00.FF0F          show memory from FF00 to FF0F
0: A9 0 AA 20 EF FF E8 8A 4C 2 0
                   store those bytes from address 0
0R                 run the program at address 0
```

That second line is the first program in the Apple-1 manual: it prints every character the terminal can show, over and over, forever. Type it in, press Enter, type `0R`, and watch. Press SW2 (RESET) to get back to the prompt, same as on the original.

The monitor has no assembler; programs were entered as hex, just as you did with Icey-8 before you had a better tool. Hand-assembling a few lines of 6502 into it is a rite of passage. A nice first one: read a key, print it twice, loop.

## On the real board

Build for Icey and upload. The 6502 now really runs at 1 MHz. The whole computer takes about a fifth of the logic cells and 17 of the 30 block RAMs (16 of them are the 8 KB of RAM), and nextpnr reports it could run at about 18 MHz, comfortably above the 12 it needs. Connect to the second serial port at 115200 baud and you'll get the backslash.

## Taking it further

The real Apple I could run BASIC: Woz's Integer BASIC lived in a 4 KB ROM at `$E000`, and the UP5K has room for it. You'd add a fourth region to your decoder, a 4 KB ROM, and load it the same way. Type `E000R` at the monitor and you get a `>` prompt.

The other big extension is the original display. It drew 40 columns by 24 lines of upper-case characters on a TV. Icey has a VGA port, and you know how to drive it (lesson 18) and how to keep characters in RAM (lesson 17). A text display is a 960-byte character RAM, a font ROM with the 64 characters the Apple I could show, and two counters to work out which character and which row of its pixels the beam is on. Add a cursor and scrolling and you've rebuilt Woz's terminal too, all on one chip, where in 1976 it took a whole board.
