---
title: State machines and a combination lock
part: 1
blurb: The pattern behind every controller you'll ever write. A traffic light first, then a lock with a secret code.
---

Your stopwatch and your scanner both had a small amount of "what am I doing right now" information: which digit to show, which way the light was moving. As designs grow, that information becomes the heart of the design, and there's a standard way to organise it. It's called a finite state machine, FSM for short, and once you know the pattern you'll see it everywhere: in the serial port, the VGA timing, the SD card driver, the CPU.

An FSM has three parts:

1. A **state register**: a few flip-flops holding a number that says which state you're in.
2. **Next-state logic**: given the current state and the inputs, which state comes next?
3. **Output logic**: given the state, what should the outputs be?

That's it. The state register is the only memory. Everything else is combinational, so you already know how to write all of it.

## A traffic light

Start with something that has no inputs at all, apart from time. A traffic light shows green for 5 seconds, yellow for 1, red for 4, and repeats. Draw it before you write it, because hardware people really do draw these:

@widget fsm {"states":["GREEN","YELLOW","RED"],"edges":[["GREEN","YELLOW","5 s"],["YELLOW","RED","1 s"],["RED","GREEN","4 s"]]}

Give the states names with `localparam`, so the code says `GREEN` instead of `2'd0`:

```verilog
localparam GREEN = 2'd0, YELLOW = 2'd1, RED = 2'd2;
reg [1:0] state = GREEN;
reg [25:0] timer = 0;       // counts clocks spent in this state
```

Then one clocked block that runs the timer and moves between states:

```verilog
always @(posedge clk) begin
  timer <= timer + 1;
  case (state)
    GREEN:  if (timer == 5*SEC - 1) begin state <= YELLOW; timer <= 0; end
    YELLOW: if (timer == 1*SEC - 1) begin state <= RED;    timer <= 0; end
    RED:    if (timer == 4*SEC - 1) begin state <= GREEN;  timer <= 0; end
    default: state <= GREEN;
  endcase
end
```

Notice `timer <= timer + 1` at the top and `timer <= 0` further down. With nonblocking assignment, when two assignments to the same register happen in one clock, the last one wins. That's a common and perfectly legitimate way to say "normally do this, but in this case do that instead".

The outputs depend only on the state, which makes this a *Moore* machine:

```verilog
assign green  = (state == GREEN);
```

The `default:` branch catches state 3, which should never happen. "Should never" is doing a lot of work in that sentence: a power glitch, or a missing synchroniser upstream, can put a state register into a value you didn't plan for. A `default` that steers back to a known state costs nothing and means the machine can always recover.

There's one more thing in this exercise. The module has `parameter SEC = 12_000_000`, the number of clocks in a second. The board uses that value. The tests change it to 10 so they don't have to simulate ten real seconds, 120 million clock cycles, every time you press Run. That's a good habit for your own designs too: put your timing constants in parameters, and test with small values.

@exercise traffic

## Project: a combination lock

Now something with inputs. The practice board has four buttons, 0 to 3. The lock opens when you press **2, 0, 3, 1** in that order. When it opens, the green light comes on for three seconds and then it locks itself again. Any wrong press sends you back to the start and lights the red LED for half a second, so you know.

The buttons bounce (they're realistic, like in lesson 8), so the starter code gives you a `buttons` module with four copies of your synchroniser, debouncer and edge detector. It outputs `press[3:0]`, one clean single-cycle pulse per press. (It stamps out the four copies with a `generate` loop, which lesson 20 covers properly.) Your job is the `lock` module.

Sketch it before coding. You need a state for each step of progress through the code, plus an "open" state. In each progress state, a press of the right button moves you forward, a press of anything else sends you back to the start and fires the red light. In the open state, a timer counts down three seconds; any button press relocks it immediately.

You also need to decide how to tell which button was pressed. `press` is a 4-bit vector with at most one bit high at a time, so `press == 4'b0100` means button 2, and `|press` means "some button".

@exercise lock

A real lock would worry about a few more things: someone hammering buttons quickly, or pressing two at once. Think about what your machine does in those cases. The tests don't check them, but someone trying to get into your shed will.
