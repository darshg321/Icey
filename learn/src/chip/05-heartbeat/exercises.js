import { runs, noInitialValues, powerUp } from '../checks.js';

export const HEARTBEAT = `module top #(
  parameter H_TOTAL = 6_000_000
)(
  input  clk,
  input  BTN,                     // SW2 = your chip's reset: 0 while held
  output LED
);
  wire rst_n = BTN;

  reg [22:0] count;
  reg led;
  always @(posedge clk) begin
    if (!rst_n) begin
      count <= 0;
      led <= 0;
    end else if (count == H_TOTAL - 1) begin
      count <= 0;
      led <= ~led;
    end else
      count <= count + 1;
  end
  assign LED = led;
endmodule
`;

export default [
  {
    id: 'c5-heartbeat',
    title: 'Heartbeat',
    prompt: '`count` wraps at `H_TOTAL`; LED1 toggles on each wrap. Reset (`BTN` = 0) clears both. No starting values.',
    starter: `module top #(
  parameter H_TOTAL = 6_000_000
)(
  input  clk,          // 12 MHz
  input  BTN,          // SW2 = your chip's reset: 0 while held
  output LED
);
  wire rst_n = BTN;

  assign LED = 0;      // replace with your counter
endmodule
`,
    solution: HEARTBEAT,
    board: [{ type: 'icey' }],
    clock: { port: 'clk', hz: 12e6 },
    testParams: { H_TOTAL: 5 },
    tests: [
      { name: 'no starting values, only the reset', run(t) { noInitialValues(t); } },
      { name: 'from any power-up state, reset gives LED1 off, then a change every 5 clocks', run(t) {
        for (let trial = 0; trial < 3; trial++) {
          powerUp(t, 'BTN');
          t.eq('LED', 0, 'right after reset');
          const r = runs(t, 'LED', 40);
          t.ok(r.length >= 5, `LED1 changed ${r.length} times in 40 clocks after reset; with H_TOTAL = 5 it should change 8 times.`);
          t.ok(r[0].v === 0 && r[0].len === 5, `After reset, LED1 should stay off for exactly 5 clocks, but it was ${r[0].v ? 'on' : 'off'} for ${r[0].len}. ${r[0].len === 6 ? 'Compare with H_TOTAL - 1.' : 'Is every register reset?'}`);
          for (const x of r.slice(1)) t.ok(x.len === 5, `LED1 was ${x.v ? 'on' : 'off'} for ${x.len} clocks; with H_TOTAL = 5 it should be 5 every time.`);
        }
      } },
      { name: 'holding reset keeps LED1 off', run(t) {
        powerUp(t, 'BTN');
        t.tick(7);
        t.set('BTN', 0);
        t.tick(20);
        t.eq('LED', 0, 'while reset is held');
      } },
    ],
  },
];
