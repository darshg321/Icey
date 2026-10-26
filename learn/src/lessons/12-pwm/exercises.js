const clock = { port: 'clk', hz: 12e6 };

// Fraction of `n` clocks that an active-low pin spends low (= LED on).
function onFraction(t, pin, n) {
  let on = 0;
  for (let i = 0; i < n; i++) { t.tick(1); if (t.get(pin) === 0) on++; }
  return on / n;
}

const DEBOUNCE = `module debounce #(parameter DB_BITS = 16) (input clk, input btn, output press);
  reg [1:0] sync = 2'b11;
  reg stable = 1, prev = 1;
  reg [DB_BITS-1:0] timer = 0;
  always @(posedge clk) begin
    sync <= {sync[0], btn};
    if (sync[1] == stable) timer <= 0;
    else if (&timer)       stable <= sync[1];
    else                   timer <= timer + 1;
    prev <= stable;
  end
  assign press = prev & ~stable;   // falling edge: BTN is active low
endmodule`;

export default [
  {
    id: 'pwm',
    title: 'A dimmer',
    prompt: 'The switches set the brightness, 0 to 255. Make `LED` be on for `duty` out of every 256 clocks.',
    starter: `module top(
  input        clk,
  input  [7:0] duty,
  output       LED
);
  reg [7:0] pwm_count = 0;
  // count, and compare

  assign LED = 1;
endmodule
`,
    solution: `module top(
  input        clk,
  input  [7:0] duty,
  output       LED
);
  reg [7:0] pwm_count = 0;
  always @(posedge clk) pwm_count <= pwm_count + 1;
  assign LED = (pwm_count < duty);
endmodule
`,
    board: [{ type: 'switches', port: 'duty', width: 8, label: 'duty', initial: 32 }, { type: 'value', port: 'duty', label: 'duty' }, { type: 'led', port: 'LED', label: 'LED1' }],
    clock,
    tests: [
      { name: 'on for exactly duty/256 of the time', run(t) {
        for (const d of [0, 1, 64, 128, 200, 255]) {
          t.set('duty', d);
          t.tick(256);
          let on = 0;
          for (let i = 0; i < 256; i++) { t.tick(1); on += t.get('LED'); }
          t.ok(on === d, `With duty = ${d}, LED was on for ${on} of 256 clocks.`);
        }
      } },
    ],
  },
  {
    id: 'breathe',
    title: 'Breathing red',
    prompt: 'Make the red LED (`RGB0`, active low) breathe: dark at power-up, fully bright after about 1 s, dark again at 2 s, and so on. Use a brightness `level` that steps up or down every `STEP` clocks, squared for gamma.',
    starter: `module top(
  input  clk,
  output RGB0     // red, active low: 0 = on
);
  parameter STEP = 46_875;   // 256 steps up + 256 down = 2 s at 12 MHz

  reg [7:0] pwm_count = 0;
  always @(posedge clk) pwm_count <= pwm_count + 1;

  reg [7:0] level = 0;     // 0..255..0, one step every STEP clocks
  reg       up = 1;

  wire [15:0] sq = level * level;
  wire [7:0]  duty = sq[15:8];

  assign RGB0 = 1;   // off
endmodule
`,
    solution: `module top(
  input  clk,
  output RGB0
);
  parameter STEP = 46_875;

  reg [7:0] pwm_count = 0;
  always @(posedge clk) pwm_count <= pwm_count + 1;

  reg [15:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  reg [7:0] level = 0;
  reg       up = 1;
  always @(posedge clk) begin
    if (step) begin
      if (up) begin
        if (level == 255) up <= 0; else level <= level + 1;
      end else begin
        if (level == 0) up <= 1; else level <= level - 1;
      end
    end
  end

  wire [15:0] sq = level * level;
  wire [7:0]  duty = sq[15:8];
  assign RGB0 = ~(pwm_count < duty);
endmodule
`,
    board: [{ type: 'rgb', ports: { r: 'RGB0', g: 'RGB2', b: 'RGB1' }, activeLow: true, label: 'LED4 (RGB)' }],
    clock,
    testParams: { STEP: 4 },
    tests: [
      { name: 'dark, bright, dark (with STEP = 4)', run(t) {
        const f0 = onFraction(t, 'RGB0', 256);
        t.ok(f0 < 0.05, `At power-up the LED should be (nearly) off, but it was on ${(f0 * 100).toFixed(0)}% of the time.`);
        t.tick(4 * 160);
        const f1 = onFraction(t, 'RGB0', 256);
        t.ok(f1 > 0.75, `Near the top of the breath it should be almost fully on, but it was on ${(f1 * 100).toFixed(0)}% of the time.`);
        t.tick(4 * 200);
        const f2 = onFraction(t, 'RGB0', 256);
        t.ok(f2 < 0.1, `At the bottom of the breath it should be nearly off again, but it was on ${(f2 * 100).toFixed(0)}% of the time.`);
      } },
      { name: 'the curve is bent (gamma)', run(t) {
        t.tick(4 * 64);
        const f = onFraction(t, 'RGB0', 256);
        t.ok(f < 0.15, `A quarter of the way up, a squared curve should give about 6% brightness. Yours gave ${(f * 100).toFixed(0)}%. Did you use duty = (level*level) >> 8?`);
      } },
    ],
  },
  {
    id: 'mood',
    project: true,
    title: 'Mood lamp',
    prompt: 'Four modes: red, green, blue breathing, then a rainbow. SW2 steps through them. Use parameters `STEP` (breath timing) and `DB_BITS` (debounce width).',
    starter: `${DEBOUNCE}

module top(
  input  clk,
  input  BTN,
  output RGB0,   // red   (active low)
  output RGB1,   // blue  (active low)
  output RGB2    // green (active low)
);
  parameter STEP = 46_875;
  parameter DB_BITS = 16;

  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  reg [1:0] mode = 0;   // 0 red, 1 green, 2 blue, 3 rainbow

  assign RGB0 = 1;
  assign RGB1 = 1;
  assign RGB2 = 1;
endmodule
`,
    solution: `${DEBOUNCE}

module top(
  input  clk,
  input  BTN,
  output RGB0,
  output RGB1,
  output RGB2
);
  parameter STEP = 46_875;
  parameter DB_BITS = 16;

  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  reg [1:0] mode = 0;
  always @(posedge clk) if (press) mode <= mode + 1;

  reg [7:0] pwm_count = 0;
  always @(posedge clk) pwm_count <= pwm_count + 1;

  reg [15:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) pre <= step ? 0 : pre + 1;

  // breathing level, 0..255..0
  reg [7:0] level = 0;
  reg up = 1;
  always @(posedge clk) if (step) begin
    if (up) begin if (level == 255) up <= 0; else level <= level + 1; end
    else    begin if (level == 0)   up <= 1; else level <= level - 1; end
  end
  wire [15:0] sq = level * level;
  wire [7:0] breath = sq[15:8];

  // rainbow: hue 0..767, each third fades one colour into the next
  reg [9:0] hue = 0;
  always @(posedge clk) if (step) hue <= (hue == 767) ? 0 : hue + 1;
  wire [7:0] h = hue[7:0];
  reg [7:0] rr, gg, bb;
  always @(*) begin
    case (hue[9:8])
      2'd0:    begin rr = ~h; gg = h;  bb = 0;  end
      2'd1:    begin rr = 0;  gg = ~h; bb = h;  end
      default: begin rr = h;  gg = 0;  bb = ~h; end
    endcase
  end

  reg [7:0] r, g, b;
  always @(*) begin
    r = 0; g = 0; b = 0;
    case (mode)
      2'd0: r = breath;
      2'd1: g = breath;
      2'd2: b = breath;
      2'd3: begin r = rr; g = gg; b = bb; end
    endcase
  end

  assign RGB0 = ~(pwm_count < r);
  assign RGB2 = ~(pwm_count < g);
  assign RGB1 = ~(pwm_count < b);
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ', bounce: true }, { type: 'rgb', ports: { r: 'RGB0', g: 'RGB2', b: 'RGB1' }, activeLow: true, label: 'LED4 (RGB)' }],
    clock,
    testParams: { STEP: 1, DB_BITS: 4 },
    tests: [
      { name: 'mode 0 breathes red only', run(t) {
        t.set('BTN', 1);
        const seen = { RGB0: 0, RGB1: 0, RGB2: 0 };
        for (let i = 0; i < 1024; i++) { t.tick(1); for (const p of Object.keys(seen)) seen[p] += t.get(p) === 0; }
        t.ok(seen.RGB0 > 50, 'In the first mode the red LED (RGB0) should be breathing, but it was hardly ever on.');
        t.ok(seen.RGB1 === 0 && seen.RGB2 === 0, 'In the first mode only red should light. Remember RGB0 = red, RGB1 = blue, RGB2 = green.');
      } },
      { name: 'SW2 steps red → green → blue → rainbow → red', run(t) {
        t.set('BTN', 1); t.tick(50);
        const pressIt = () => { t.set('BTN', 0); t.tick(60); t.set('BTN', 1); t.tick(60); };
        const lit = () => { const s = { RGB0: 0, RGB1: 0, RGB2: 0 }; for (let i = 0; i < 1024; i++) { t.tick(1); for (const p of Object.keys(s)) s[p] += t.get(p) === 0; } return s; };
        pressIt(); let s = lit();
        t.ok(s.RGB2 > 50 && s.RGB0 === 0 && s.RGB1 === 0, 'After one press only green (RGB2) should be breathing.');
        pressIt(); s = lit();
        t.ok(s.RGB1 > 50 && s.RGB0 === 0 && s.RGB2 === 0, 'After two presses only blue (RGB1) should be breathing.');
        pressIt(); s = lit();
        t.ok(s.RGB0 > 50 && s.RGB1 > 50 && s.RGB2 > 50, 'After three presses (rainbow) all three colours should get used.');
        pressIt(); s = lit();
        t.ok(s.RGB0 > 50 && s.RGB1 === 0 && s.RGB2 === 0, 'After four presses it should be back to red.');
      } },
    ],
  },
];
