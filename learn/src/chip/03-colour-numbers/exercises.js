export default [
  {
    id: 'c3-colour',
    title: 'Colour preview',
    prompt: '`colour = {P6, P5, P4, P3, P2, P1}` as `rrggbb`. Each RGB channel on if any of its bits is set; LED1 on for white.',
    starter: `module top(
  input  P1, P2, P3, P4, P5, P6,
  output LED,    // LED1: 1 = on
  output RGB0,   // red:   0 = on
  output RGB1,   // blue:  0 = on
  output RGB2    // green: 0 = on
);
  // your chip's 6-bit colour: {r[1:0], g[1:0], b[1:0]}

  assign LED  = 0;
  assign RGB0 = 1;
  assign RGB1 = 1;
  assign RGB2 = 1;
endmodule
`,
    solution: `module top(
  input  P1, P2, P3, P4, P5, P6,
  output LED,
  output RGB0,
  output RGB1,
  output RGB2
);
  wire [5:0] colour = {P6, P5, P4, P3, P2, P1};
  wire [1:0] r = colour[5:4];
  wire [1:0] g = colour[3:2];
  wire [1:0] b = colour[1:0];

  assign RGB0 = ~|r;
  assign RGB2 = ~|g;
  assign RGB1 = ~|b;
  assign LED  = &colour;
endmodule
`,
    board: [{ type: 'icey' }],
    tests: [
      { name: 'uses a 6-bit vector and no ==', run(t) {
        t.ok(/\[\s*5\s*:\s*0\s*\]/.test(t.code), 'Build the colour as a 6-bit vector: wire [5:0] colour = {P6, ...};');
        t.ok(!/==/.test(t.code), 'Use reduction operators (| and &) instead of comparing with ==.');
      } },
      { name: 'all 64 colours', run(t) {
        t.table(['P6', 'P5', 'P4', 'P3', 'P2', 'P1'], ['RGB0', 'RGB2', 'RGB1', 'LED'], e => {
          const c = (e.P6 << 5) | (e.P5 << 4) | (e.P4 << 3) | (e.P3 << 2) | (e.P2 << 1) | e.P1;
          return { RGB0: c & 0b110000 ? 0 : 1, RGB2: c & 0b001100 ? 0 : 1, RGB1: c & 0b000011 ? 0 : 1, LED: c === 63 ? 1 : 0 };
        }, { describe: e => `colour = 6'b${[e.P6, e.P5, e.P4, e.P3, e.P2, e.P1].join('')}` });
      } },
    ],
  },
];
