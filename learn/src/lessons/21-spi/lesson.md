---
title: Talking to other chips
part: 4
blurb: SPI, the bus that connects Icey's FPGA to its flash, its SD card and its USB host chip. Read the flash's ID from your own logic.
---

An FPGA on its own is a brain with no senses. Most of what makes Icey useful is in the chips around the FPGA: 16 megabytes of flash, a microSD card, a USB host controller. All three are wired to the FPGA by the same kind of connection, the Serial Peripheral Interface, SPI. Learning it opens all of them up.

## SPI

SPI is like the UART's more organised cousin. There's a *controller* (the FPGA, here) and one or more *peripherals*, connected by four wires:

- **SCK**, a clock the controller generates.
- **MOSI**, data from controller to peripheral.
- **MISO**, data from peripheral to controller.
- **CS**, chip select, one per peripheral, active low.

The controller pulls a chip's CS low to start talking to it. Then, for every bit, it toggles SCK. On each rising edge of SCK, *both* sides sample the data line coming towards them, and on each falling edge, both sides put out their next bit. So every SCK cycle moves one bit each way at the same time. Bytes go most significant bit first. When the conversation is over, CS goes back high.

That's "mode 0", which is what nearly everything uses. (There are four modes, which differ in whether SCK idles high or low and which edge samples. When a datasheet says "mode 0 and 3 supported", this is what it means.)

Unlike the UART, there's a clock wire, so there's no baud rate to agree on and no need to sample in the middle of bits. The controller can run SCK at whatever speed the peripheral can handle, and even stop halfway through a byte if it wants. This is why SPI goes much faster than a UART: Icey's flash accepts SCK up to 133 MHz for its fast-read commands.

Look at what both ends are: an 8-bit shift register. The controller's register shifts out of MOSI and in from MISO; the peripheral's does the opposite. After eight clocks, they've swapped contents. Lesson 7 promised shift registers would come back.

@exercise spi-byte

## The flash chip

Icey's flash is a Winbond W25Q128JV. Like most SPI flash chips, it understands a set of one-byte commands. A few useful ones:

| command | name | then |
|---|---|---|
| `9F` | read JEDEC ID | read 3 bytes: manufacturer, memory type, capacity |
| `03` | read data | send a 3-byte address, then read as many bytes as you like |
| `05` | read status | read 1 byte; bit 0 is "busy writing" |
| `06` | write enable | required before every write or erase |

The JEDEC ID is the "who are you?" command. Winbond's manufacturer code is `EF`, and `40 18` means a 128-megabit chip of this family. Reading it back is the standard first test for any SPI connection, because if you get `ef 40 18`, every wire and every bit of timing is working.

## The flash on Icey

The flash's pins in `icey.pcf` are `FLASH_SCK`, `FLASH_CS`, `FLASH_MOSI` and `FLASH_MISO`. These are the same wires the programmer uses to load bitstreams, which works because the FTDI chip lets go of them once the FPGA is configured.

You might remember from lesson 10 that this board revision can't boot from flash because two data lines are crossed. That only matters when the FPGA's built-in boot logic is in charge, because it insists on particular pins for input and output. From your own logic you can use any pin for anything, and the pin file already has the names the right way round for user designs. The bring-up tests read the ID this way, and got `ef 40 18`.

## Project: who's there?

Press SW2, and Icey reads the flash's JEDEC ID and prints it over serial as `ef 40 18`. In the browser, the board has a virtual W25Q128 that answers like the real one; it shows the last command it received.

Your design wraps `spi_byte` in a state machine: CS low, exchange `9F`, exchange three dummy bytes (`00`, though the flash ignores what you send while it's answering) while collecting what comes back, CS high, then print. For the printing, you'll need to turn each 4-bit nibble into a hex character: `"0" + n` for 0 to 9, `"a" + n - 10` above that. A Verilog `function` is a tidy way to write that once and use it six times:

```verilog
function [7:0] hexch(input [3:0] n);
  hexch = (n < 10) ? "0" + n : "a" + n - 10;
endfunction
```

A function is just a named piece of combinational logic. Each place you call it gets its own copy of the circuit.

@exercise jedec

## Further: speed, and the SD card

The flash supports a *quad* mode, using its WP and HOLD pins as two extra data lines, to move four bits per SCK clock instead of one. The `firmware/examples/flashtest` design on Icey does quad reads and measured 5.97 MB/s against 1.50 MB/s for single-bit reads at the same clock, four times faster, matching every byte of the stored bitstream.

The microSD card and the MAX3421E USB host chip share a second SPI bus (`SD_SCK`, `SD_MOSI`, `SD_MISO`) with separate chip selects (`SD_CS`, `USB_CS`). An SD card speaks SPI too, but it needs a little ritual to start: at least 74 clocks with CS high, a reset command, a voltage check, and then a loop waiting for the card to finish initialising, before it'll hand over 512-byte sectors. The `firmware/examples/hwtest` design does the SPI from the FPGA and the ritual from Python, which is a good way to explore it before you put it all in hardware.
