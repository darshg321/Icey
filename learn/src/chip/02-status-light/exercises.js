export default [
  {
    id: 'c2-status',
    title: 'Status light',
    prompt: 'Red while reset (`BTN` = 0), else blue if paused (`P1`), else green. LED1 shows `P2`. RGB pins are active low.',
    starter: `module top(
  input  BTN,    // reset: 0 while held
  input  P1,     // pause
  input  P2,     // effect
  output LED,    // LED1: 1 = on
  output RGB0,   // red:   0 = on
  output RGB1,   // blue:  0 = on
  output RGB2    // green: 0 = on
);
  assign LED  = 0;
  assign RGB0 = 1;
  assign RGB1 = 1;
  assign RGB2 = 1;
endmodule
`,
    solution: `module top(
  input  BTN,
  input  P1,
  input  P2,
  output LED,
  output RGB0,
  output RGB1,
  output RGB2
);
  wire resetting = ~BTN;
  wire paused    = BTN & P1;
  wire running   = BTN & ~P1;

  assign RGB0 = ~resetting;
  assign RGB1 = ~paused;
  assign RGB2 = ~running;
  assign LED  = P2;
endmodule
`,
    board: [{ type: 'icey' }],
    tests: [
      { name: 'every combination of reset, pause and effect', run(t) {
        t.table(['BTN', 'P1', 'P2'], ['RGB0', 'RGB1', 'RGB2', 'LED'], ({ BTN, P1, P2 }) => ({
          RGB0: BTN ? 1 : 0,
          RGB1: BTN && P1 ? 0 : 1,
          RGB2: BTN && !P1 ? 0 : 1,
          LED: P2,
        }), { describe: e => `reset ${e.BTN ? 'up' : 'held'}, pause = ${e.P1}, effect = ${e.P2}` });
      } },
    ],
  },
];
