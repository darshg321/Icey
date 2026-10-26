export default [
  {
    id: 'c1-reset-light',
    title: 'The reset light',
    prompt: 'LED1 (`LED`) on while SW2 (`BTN`) is held down, off otherwise.',
    starter: `module top(
  input  BTN,   // SW2: 0 while pressed
  output LED    // LED1: 1 = on
);
  assign LED = 0;   // change this
endmodule
`,
    solution: `module top(
  input  BTN,
  output LED
);
  assign LED = ~BTN;
endmodule
`,
    board: [{ type: 'icey' }],
    tests: [
      { name: 'LED1 is off when SW2 is up', run(t) { t.set('BTN', 1); t.eq('LED', 0, 'with SW2 not pressed (BTN = 1)'); } },
      { name: 'LED1 is on while SW2 is held', run(t) { t.set('BTN', 0); t.eq('LED', 1, 'while SW2 is pressed (BTN = 0)'); } },
    ],
  },
];
