const clock = { port: 'clk', hz: 12e6 };

export default [
  {
    id: 'swap',
    title: 'Make them swap',
    prompt: '`x` and `y` should trade values on every clock edge, so the two LEDs alternate. This version doesn\'t work. Fix it, and slow it down so you can see it: swap only when `step` is high.',
    starter: `module top(
  input  clk,
  output led_x,
  output led_y
);
  localparam STEP = 6_000_000;   // half a second
  reg [22:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg x = 1, y = 0;
  always @(posedge clk) begin
    if (step) begin
      x = y;
      y = x;
    end
  end

  assign led_x = x;
  assign led_y = y;
endmodule
`,
    solution: `module top(
  input  clk,
  output led_x,
  output led_y
);
  localparam STEP = 6_000_000;
  reg [22:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg x = 1, y = 0;
  always @(posedge clk) begin
    if (step) begin
      x <= y;
      y <= x;
    end
  end

  assign led_x = x;
  assign led_y = y;
endmodule
`,
    board: [{ type: 'led', port: 'led_x', label: 'x' }, { type: 'led', port: 'led_y', label: 'y', color: '#ffd84a' }],
    clock,
    tests: [
      { name: 'x and y swap every half second', run(t) {
        t.eq('led_x', 1, 'at power-up'); t.eq('led_y', 0, 'at power-up');
        for (let k = 1; k <= 3; k++) {
          t.tick(6_000_000);
          t.eq('led_x', k & 1 ? 0 : 1, `after ${k / 2} s`);
          t.eq('led_y', k & 1 ? 1 : 0, `after ${k / 2} s`);
        }
      } },
    ],
  },
  {
    id: 'shift',
    title: 'A shift register',
    prompt: 'Ten times a second, shift the LEDs up one place and bring in a 1 at `led[0]` if the button is held, 0 if not. Tap the button and watch the bit march along.',
    starter: `module top(
  input        clk,
  input        BTN,     // 0 while pressed
  output [7:0] led
);
  localparam STEP = 1_200_000;
  reg [20:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg [7:0] sr = 0;
  // on each step, shift in ~BTN

  assign led = sr;
endmodule
`,
    solution: `module top(
  input        clk,
  input        BTN,
  output [7:0] led
);
  localparam STEP = 1_200_000;
  reg [20:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg [7:0] sr = 0;
  always @(posedge clk)
    if (step) sr <= {sr[6:0], ~BTN};

  assign led = sr;
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ' }, { type: 'leds', port: 'led', label: 'led[7:0]' }],
    clock,
    tests: [
      { name: 'a press walks along the LEDs', run(t) {
        t.set('BTN', 1);
        t.tick(1_200_000 + 5);
        t.eq('led', 0, 'with the button never pressed');
        t.set('BTN', 0); t.tick(1_200_000); t.set('BTN', 1);
        t.eq('led', 1, 'one step after pressing');
        let want = 1;
        for (let i = 0; i < 8; i++) { t.tick(1_200_000); want = (want << 1) & 255; t.eq('led', want, `${i + 2} steps after the press`); }
      } },
    ],
  },
  {
    id: 'scanner',
    project: true,
    title: 'The scanner',
    prompt: 'One LED lit, starting at `led[0]`, moving one place every 750,000 clocks, bouncing between `led[0]` and `led[7]`.',
    starter: `module top(
  input        clk,
  output [7:0] led
);
  localparam STEP = 750_000;   // 1/16 s

  assign led = 8'b00000001;
endmodule
`,
    solution: `module top(
  input        clk,
  output [7:0] led
);
  localparam STEP = 750_000;
  reg [19:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg [7:0] pattern = 8'b00000001;
  reg left = 1;
  always @(posedge clk) begin
    if (step) begin
      if (left) begin
        pattern <= pattern << 1;
        if (pattern[6]) left <= 0;
      end else begin
        pattern <= pattern >> 1;
        if (pattern[1]) left <= 1;
      end
    end
  end

  assign led = pattern;
endmodule
`,
    board: [{ type: 'leds', port: 'led', label: 'led[7:0]', color: '#ff3b2f' }],
    clock,
    tests: [
      { name: 'sweeps 0 → 7 → 0 → 7', run(t) {
        const seq = [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3];
        t.eq('led', 1, 'at power-up (light on led[0])');
        t.tick(10);
        for (let i = 1; i < seq.length; i++) {
          t.tick(750_000);
          t.eq('led', 1 << seq[i], `after ${i} steps`);
        }
      } },
    ],
  },
];
