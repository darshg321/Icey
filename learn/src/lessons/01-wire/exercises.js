const board = [
  { type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ' },
  { type: 'led', port: 'LED', label: 'LED1' },
];

export default [
  {
    id: 'wire',
    title: 'Connect the button to the LED',
    prompt: 'Fill in the module so `LED` is connected straight to `BTN`. Then hold the button on the virtual board (or hold the space bar).',
    starter: `module top(
  input  BTN,   // button SW2
  output LED    // LED1
);
  // one line goes here

endmodule
`,
    solution: `module top(
  input  BTN,
  output LED
);
  assign LED = BTN;
endmodule
`,
    board,
    tests: [
      { name: 'LED follows BTN', run(t) { t.set('BTN', 1); t.eq('LED', 1, 'when BTN is 1'); t.set('BTN', 0); t.eq('LED', 0, 'when BTN is 0'); } },
    ],
  },
  {
    id: 'not-gate',
    title: 'Make the LED light when you press',
    prompt: 'SW2 reads 0 when pressed. Change the design so the LED is **on** while the button is held down.',
    starter: `module top(
  input  BTN,   // 0 when pressed (active low)
  output LED
);
  assign LED = BTN;
endmodule
`,
    solution: `module top(
  input  BTN,
  output LED
);
  assign LED = ~BTN;
endmodule
`,
    board,
    tests: [
      { name: 'LED is off when the button is up', run(t) { t.set('BTN', 1); t.eq('LED', 0, 'with the button up (BTN = 1)'); } },
      { name: 'LED is on while the button is pressed', run(t) { t.set('BTN', 0); t.eq('LED', 1, 'with the button pressed (BTN = 0)'); } },
    ],
  },
];
