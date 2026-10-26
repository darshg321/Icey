---
title: Racing the beam
part: 3
blurb: Driving a VGA monitor directly from logic, pixel by pixel, with no framebuffer and no processor. Sync timing, a PLL, and a bouncing square.
---

This is where FPGAs start doing things that ordinary microcontrollers can't. A VGA monitor wants a new pixel every 40 nanoseconds, 25 million of them a second, with sync pulses timed to the clock cycle. A microcontroller would struggle to keep up even if it did nothing else. A few counters and comparators on the FPGA do it without breaking a sweat, and can compute every pixel's colour on the fly as the monitor asks for it.

## How VGA works

VGA is a leftover from cathode ray tubes, and it makes most sense if you picture one. An electron beam sweeps across the screen from left to right, drawing one line of pixels, then flies back to the left and drops down to draw the next line. When it reaches the bottom it flies back to the top and starts the next frame. The video signal is three analog voltages, red, green and blue, giving the brightness at whatever point the beam is at right now, plus two digital sync signals that tell the monitor when to fly back: `HSYNC` for the end of a line, `VSYNC` for the end of a frame.

The flying back takes time, so every line and frame has extra time that isn't visible. For the standard 640×480 mode at 60 frames a second:

@widget vgatiming

Each line is 800 pixel-clocks: 640 visible, then a 16-clock *front porch*, a 96-clock sync pulse, and a 48-clock *back porch*. Each frame is 525 lines: 480 visible, 10 lines of front porch, 2 of sync, 33 of back porch. Both sync pulses are *active low*: the line sits at 1 and drops to 0 for the pulse. The pixel clock is officially 25.175 MHz. Do the multiplication and you get 800 × 525 × 60 = 25.2 million, which is where that number comes from.

None of the extra time is wasted on modern LCDs, which don't have a beam to fly back, but they still expect the timing. Get it wrong and the monitor shows "out of range" or nothing at all. (The browser monitor in this lesson does the same: it measures your line length and refuses to show a picture if it's wrong.)

During the porches and sync pulses, the colour outputs **must be black**. Monitors measure the black level during blanking, and if you're sending colour then, the whole picture comes out washed out or with a coloured cast.

## The timing generator

Two counters, one for the column, one for the line:

```verilog
reg [9:0] h = 0, v = 0;
always @(posedge clk) begin
  if (h == 799) begin
    h <= 0;
    v <= (v == 524) ? 10'd0 : v + 1;
  end else
    h <= h + 1;
end
wire visible = (h < 640) && (v < 480);
```

`h` is the beam's x position and `v` its y position, with the visible area at the top left. The sync outputs are comparisons: `HSYNC` is low while `h` is from 656 to 751 (640 + 16 front porch, for 96 clocks), and `VSYNC` is low while `v` is 490 or 491.

Then you decide each pixel's colour from `h` and `v` as the beam passes. There's no memory holding the picture. There doesn't need to be: whatever you can compute from the coordinates in one clock, you can draw. That's what "racing the beam" means, and it's how the Atari 2600 drew its games with 128 bytes of RAM.

Register the outputs. If the sync and colour signals come straight out of comparators, they glitch briefly as the counters change, and a glitch on a sync line can look like a pulse to the monitor. Registering everything adds one clock of delay to all of them equally, so they stay lined up.

## The colours on Icey

Icey's VGA connector is driven through a resistor network that turns digital outputs into the analog voltages VGA wants. Red and green get 3 bits each (`VGA_R[2:0]`, `VGA_G[2:0]`), blue gets 2 (`VGA_B[1:0]`), for 256 colours in total. The resistor values are binary-weighted, so `VGA_R = 3'b111` is full red and `3'b100` is about half.

@exercise vga-timing

## The pixel clock on Icey

Icey has no crystal, so where does 25 MHz come from? The iCE40 has a PLL, a phase-locked loop, which can multiply and divide a clock. The VGA examples in the Icey repository take the 48 MHz internal oscillator, divide it by 4 to get 12 MHz, multiply by 67 to get 804 MHz inside the PLL, then divide by 32: 25.125 MHz. That's 0.2% off the official 25.175, and monitors don't mind that. On the bring-up board the measured pixel clock was 25.055 MHz, which gives 31.32 kHz lines and 59.65 Hz frames, against 31.47 kHz and 59.94 Hz in the standard.

The settings come from a tool called `icepll`, which is installed with the others: `yowasp-icepll -i 48 -o 25.175` (or plain `icepll` with the native tools) prints the closest settings it can find, which are these exact ones. The **build for Icey** button in this lesson wraps your design in that PLL setup. To see the code, it's in `firmware/examples/icestudio/vga_demo.ice`, in the clock block.

One honest note: the VGA output on Icey has been checked in simulation and by measuring the timing on the board, but as of the time of writing, nobody had reported plugging a real monitor into one. If you're the first, it's worth knowing that the sync timing is right but the colour levels are the least tested part.

## Project: the bouncing square

Remember screensavers? A square, bouncing around the screen and changing colour each time it hits an edge.

The square's position is two registers, `sx` and `sy`. Each pixel is inside the square if `h` is between `sx` and `sx + 31` and `v` is between `sy` and `sy + 31`. That's four comparisons, all running at the same time on every pixel.

The position should only change once per frame, and only while the beam isn't drawing, otherwise the top half of the square would be drawn at the old position and the bottom half at the new one. That's called *tearing*, and avoiding it is why games care about vertical sync. The starter gives you a `frame_tick` that's high for one clock per frame, when the beam has just finished the visible area.

@exercise bounce

The square is the simplest sprite there is. A game is lots of these, plus some rules. If you want to keep going, Pong is two paddles, a ball, and the button from lesson 8. You have everything you need.
