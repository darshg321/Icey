const sw = (port, label) => ({ type: 'switches', port, label, width: 1 });

export default [
  {
    id: 'alarm',
    title: 'Burglar alarm',
    prompt: 'Make `siren` come on when `armed` is 1 and either `door` or `window` is 1. Then add the `ready` light: armed, and both closed.',
    starter: `module top(
  input  armed,
  input  door,     // 1 = open
  input  window,   // 1 = open
  output siren,
  output ready
);
  assign siren = 0;  // fix me
  assign ready = 0;  // and me
endmodule
`,
    solution: `module top(
  input  armed,
  input  door,
  input  window,
  output siren,
  output ready
);
  assign siren = armed & (door | window);
  assign ready = armed & ~door & ~window;
endmodule
`,
    board: [sw('armed', 'armed'), sw('door', 'door'), sw('window', 'window'),
      { type: 'led', port: 'siren', label: 'SIREN', color: '#ff3b2f' }, { type: 'led', port: 'ready', label: 'ready', color: '#3dff6e' }],
    tests: [
      { name: 'siren: armed and (door or window)', run(t) { t.table(['armed', 'door', 'window'], ['siren'], e => e.armed & (e.door | e.window)); } },
      { name: 'ready: armed and everything closed', run(t) { t.table(['armed', 'door', 'window'], ['ready'], e => e.armed & !e.door & !e.window ? 1 : 0); } },
    ],
  },
  {
    id: 'stairs',
    title: 'Two-way light switch',
    prompt: 'Flipping either switch should toggle the light.',
    starter: `module top(
  input  downstairs,
  input  upstairs,
  output light
);
  assign light = downstairs;
endmodule
`,
    solution: `module top(
  input  downstairs,
  input  upstairs,
  output light
);
  assign light = downstairs ^ upstairs;
endmodule
`,
    board: [sw('downstairs', 'downstairs'), sw('upstairs', 'upstairs'), { type: 'led', port: 'light', label: 'light', color: '#ffd84a' }],
    tests: [
      { name: 'flipping either switch toggles the light', run(t) {
        t.set('downstairs', 0); t.set('upstairs', 0);
        const start = t.get('light');
        t.set('downstairs', 1); t.eq('light', start ^ 1, 'after flipping the downstairs switch');
        t.set('upstairs', 1); t.eq('light', start, 'after then flipping the upstairs switch');
        t.set('downstairs', 0); t.eq('light', start ^ 1, 'after flipping the downstairs switch back');
      } },
      { name: 'light is off with both switches down', run(t) { t.set('downstairs', 0); t.set('upstairs', 0); t.eq('light', 0, 'with both switches at 0'); } },
    ],
  },
  {
    id: 'majority',
    title: 'Three judges',
    prompt: '`yes` is 1 when at least two of `a`, `b`, `c` are 1.',
    starter: `module top(
  input  a, b, c,
  output yes
);
  // name the pieces with wires if it helps

  assign yes = 0;
endmodule
`,
    solution: `module top(
  input  a, b, c,
  output yes
);
  wire ab = a & b;
  wire ac = a & c;
  wire bc = b & c;
  assign yes = ab | ac | bc;
endmodule
`,
    board: [sw('a', 'judge A'), sw('b', 'judge B'), sw('c', 'judge C'), { type: 'led', port: 'yes', label: 'YES', color: '#3dff6e' }],
    tests: [
      { name: 'yes when two or more agree', run(t) { t.table(['a', 'b', 'c'], ['yes'], e => (e.a + e.b + e.c >= 2 ? 1 : 0)); } },
    ],
  },
];
