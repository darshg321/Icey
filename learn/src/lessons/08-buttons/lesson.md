---
title: Buttons lie
part: 1
blurb: Count button presses, and find out why that's harder than it sounds. Edges, bounce, debouncing and metastability.
---

This lesson's project sounds like the easiest one yet: count how many times the button has been pressed, and show the count on the display. You'll write it in a few minutes, it'll pass a simple test, and then the virtual board will show you that it doesn't work. Real buttons are messier than the clean 0s and 1s you've been testing with.

## Counting presses, not clocks

The obvious first attempt:

```verilog
always @(posedge clk)
  if (!BTN) count <= count + 1;
```

Hold the button for a quarter of a second and that adds three million. The counter runs on every clock while the button is down. You want it to count *presses*: the moment the button goes from up to down, once.

That moment is an *edge*, and you detect it by remembering what the button was doing one clock ago:

```verilog
reg btn_prev = 1;
always @(posedge clk) btn_prev <= BTN;
wire pressed = btn_prev & ~BTN;   // was up last clock, is down now
```

`pressed` is high for exactly one clock cycle per press. Single-cycle pulses like that are how one part of a design tells another part "something just happened", and you'll write this two-flip-flop pattern hundreds of times.

@exercise edge

Once your edge detector passes, go to the Board tab and press the button a few times. Watch the count.

## Bounce

It probably went up by more than one per press. Sometimes by two or three, sometimes by ten.

When the metal contacts inside a push button come together, they don't just touch and stay touched. They hit, spring apart, hit again, and rattle for a few milliseconds before settling down. To you that's one press. To a circuit sampling the pin twelve million times a second, it's a burst of presses and releases.

@widget bounce

The virtual board's button bounces like a real one (for about four milliseconds, with random timing), so your edge detector is faithfully counting every rattle.

The fix is called debouncing, and the idea is to refuse to believe the button until it's held still for a while. Keep a "stable" version of the button. Whenever the raw input disagrees with the stable version, count how long it's been disagreeing. If it disagrees continuously for, say, 5 milliseconds, accept the new value. If it flips back before then, reset the count.

```verilog
reg        stable = 1;
reg [15:0] timer = 0;          // 2^16 clocks = 5.5 ms at 12 MHz
always @(posedge clk) begin
  if (btn_sync == stable)
    timer <= 0;                // agrees: nothing to do
  else if (&timer)             // disagreed for 65,535 clocks in a row
    stable <= btn_sync;
  else
    timer <= timer + 1;
end
```

Then do your edge detection on `stable` instead of the raw pin. The `&timer` there is the reduction AND from lesson 3: it's 1 when every bit of the timer is 1, which saves writing out the number 65,535.

## Metastability, the scary one

There's one more problem, and it's subtler. Your flip-flops sample on the clock edge. The button can change *whenever it likes*, with no regard for your clock. Every so often it'll change at almost exactly the moment a flip-flop is sampling it.

A flip-flop needs its input to be stable for a tiny window around the clock edge, a fraction of a nanosecond. If the input moves inside that window, the flip-flop can end up stuck between 0 and 1 for a while before falling one way or the other. That's *metastability*. It's rare and it's random, and worse, while it lasts, different gates reading that flip-flop can see different values. A state machine can end up in a state that shouldn't be possible.

The standard cure is cheap. Pass every asynchronous input through two flip-flops in a row before using it:

```verilog
reg [1:0] sync = 2'b11;
always @(posedge clk) sync <= {sync[0], BTN};
wire btn_sync = sync[1];
```

If the first flip-flop goes metastable, it almost certainly settles within one clock period, before the second one samples it. The chance of a failure doesn't drop to zero, but for a 12 MHz design it drops to roughly once in the lifetime of the universe. Everything that comes into your design from the outside world and isn't already synchronised to your clock (buttons, serial data, signals from other chips with their own clocks) gets a synchroniser. No exceptions.

The simulator can't show you metastability (it's an analog effect, and a gate-level simulator only knows 0 and 1), so this is one you have to take on trust. It's real, though, and a missing synchroniser is one of the classic "it fails once a week and we don't know why" bugs.

## Project: a press counter that tells the truth

Put the three pieces in a row: synchroniser, debouncer, edge detector. Count presses on the two hex digits. The tests press the button with realistic bounce and check the count goes up by exactly one each time, and that a 1 ms glitch on the line doesn't count at all.

@exercise debounce

From here on, every design in this course that reads a button uses this chain. Lesson 12 turns it into a module you can drop into Icestudio.
