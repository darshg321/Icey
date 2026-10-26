import { runs, noInitialValues, powerUp } from '../checks.js';

export const COUNTER = `module counter #(
  parameter MAX = 800,
  parameter W = 10
)(
  input              clk,
  input              rst_n,
  input              en,
  output reg [W-1:0] value,
  output             wrap
);
  assign wrap = en && (value == MAX - 1);
  always @(posedge clk) begin
    if (!rst_n)
      value <= 0;
    else if (wrap)
      value <= 0;
    else if (en)
      value <= value + 1;
  end
endmodule`;

export default [
  {
    id: 'c6-counters',
    title: 'x and y',
    prompt: 'A `counter #(MAX, W)` module with `en` and `wrap`, used twice in `top` (y steps when x wraps). LED1 toggles when y wraps.',
    carry: 'c5-heartbeat',
    starter: `module counter #(
  parameter MAX = 800,
  parameter W = 10
)(
  input              clk,
  input              rst_n,
  input              en,
  output reg [W-1:0] value,
  output             wrap
);
  // count 0 .. MAX-1 while en is 1; wrap = 1 on the clock it wraps
endmodule

module top #(
  parameter H_TOTAL = 6000,
  parameter V_TOTAL = 1000
)(
  input  clk,          // 12 MHz
  input  BTN,          // reset: 0 while held
  output LED
);
  wire rst_n = BTN;

  assign LED = 0;      // two counters, and a register that toggles when y wraps
endmodule
`,
    solution: `${COUNTER}

module top #(
  parameter H_TOTAL = 6000,
  parameter V_TOTAL = 1000
)(
  input  clk,
  input  BTN,
  output LED
);
  wire rst_n = BTN;
  wire [12:0] x;
  wire [9:0] y;
  wire x_wrap, y_wrap;
  counter #(.MAX(H_TOTAL), .W(13)) xcount (.clk(clk), .rst_n(rst_n), .en(1'b1), .value(x), .wrap(x_wrap));
  counter #(.MAX(V_TOTAL), .W(10)) ycount (.clk(clk), .rst_n(rst_n), .en(x_wrap), .value(y), .wrap(y_wrap));

  reg led;
  always @(posedge clk)
    if (!rst_n) led <= 0;
    else if (y_wrap) led <= ~led;
  assign LED = led;
endmodule
`,
    board: [{ type: 'icey' }],
    clock: { port: 'clk', hz: 12e6 },
    testParams: { H_TOTAL: 4, V_TOTAL: 3 },
    extraTops: ['counter'],
    tests: [
      { name: 'no starting values, only the reset', run(t) { noInitialValues(t); } },
      { name: 'top uses counter twice', run(t) {
        const uses = (t.code.match(/\bcounter\b/g) || []).length - 1;
        t.ok(/\bmodule\s+counter\b/.test(t.code), 'Write a module called counter.');
        t.ok(uses >= 2, `top should contain two counters; counter is used ${Math.max(uses, 0)} time${uses === 1 ? '' : 's'}.`);
      } },
      { name: 'counter on its own: counts while en, wraps at MAX - 1 (MAX = 800)', run(t) {
        const c = t.extra.counter;
        c.scramble(); c.set('en', 0); c.set('rst_n', 0); c.tick('clk'); c.tick('clk'); c.set('rst_n', 1);
        t.ok(c.get('value') === 0, `After reset, value should be 0, but it's ${c.get('value')}.`);
        c.tick('clk'); c.tick('clk');
        t.ok(c.get('value') === 0, 'With en = 0 the counter should hold still.');
        c.set('en', 1);
        for (let i = 1; i < 800; i++) {
          c.tick('clk');
          if (c.get('value') !== i) t.fail(`With en = 1, after ${i} clocks value should be ${i}, but it's ${c.get('value')}.`);
        }
        t.ok(c.get('wrap') === 1, 'At value = 799 with en = 1, wrap should be 1.');
        c.tick('clk');
        t.ok(c.get('value') === 0, `After 799 the counter should go back to 0, but it's ${c.get('value')}.`);
        t.ok(c.get('wrap') === 0, 'wrap should only be 1 for the one clock where value is MAX - 1.');
        c.set('en', 0);
        for (let i = 0; i < 5; i++) c.tick('clk');
        t.ok(c.get('value') === 0 && c.get('wrap') === 0, 'With en = 0, nothing should change, and wrap should be 0.');
      } },
      { name: 'LED1 toggles once per frame (4 × 3 = 12 clocks), from any power-up state', run(t) {
        for (let trial = 0; trial < 3; trial++) {
          powerUp(t, 'BTN');
          t.eq('LED', 0, 'right after reset');
          const r = runs(t, 'LED', 80);
          t.ok(r.length >= 4 && r.every(x => x.len === 12), `LED1 stretches were ${r.map(x => x.len).join(', ') || 'none'} clocks; with x counting to 4 and y to 3 they should all be 12.`);
        }
      } },
    ],
  },
];
