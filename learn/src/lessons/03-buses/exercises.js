const board = [
  { type: 'switches', port: 'sw', width: 8, label: 'sw[7:0]' },
  { type: 'leds', port: 'led', label: 'led[7:0]' },
];

const rev8 = x => { let r = 0; for (let i = 0; i < 8; i++) r |= ((x >> i) & 1) << (7 - i); return r; };
const pop = x => { let n = 0; while (x) { n += x & 1; x >>= 1; } return n; };

export default [
  {
    id: 'mirror',
    title: 'Mirror image',
    prompt: 'Make the LEDs show the switches back to front: `led[7]` follows `sw[0]`, `led[6]` follows `sw[1]`, and so on.',
    starter: `module top(
  input  [7:0] sw,
  output [7:0] led
);
  assign led = sw;
endmodule
`,
    solution: `module top(
  input  [7:0] sw,
  output [7:0] led
);
  assign led = {sw[0], sw[1], sw[2], sw[3], sw[4], sw[5], sw[6], sw[7]};
endmodule
`,
    board,
    tests: [{ name: 'led is sw reversed', run(t) { t.table(['sw'], ['led'], e => rev8(e.sw)); } }],
  },
  {
    id: 'reduce',
    title: 'All, any, odd',
    prompt: 'Light `all` when every switch is up, `any` when at least one is, and `odd` when an odd number are.',
    starter: `module top(
  input  [7:0] sw,
  output all,
  output any,
  output odd
);
  assign all = 0;
  assign any = 0;
  assign odd = 0;
endmodule
`,
    solution: `module top(
  input  [7:0] sw,
  output all,
  output any,
  output odd
);
  assign all = &sw;
  assign any = |sw;
  assign odd = ^sw;
endmodule
`,
    board: [
      { type: 'switches', port: 'sw', width: 8, label: 'sw[7:0]' },
      { type: 'led', port: 'all', label: 'all' }, { type: 'led', port: 'any', label: 'any' },
      { type: 'led', port: 'odd', label: 'odd', color: '#ffd84a' },
    ],
    tests: [
      { name: 'all = every bit set', run(t) { t.table(['sw'], ['all'], e => (e.sw === 255 ? 1 : 0)); } },
      { name: 'any = at least one bit set', run(t) { t.table(['sw'], ['any'], e => (e.sw ? 1 : 0)); } },
      { name: 'odd = parity', run(t) { t.table(['sw'], ['odd'], e => pop(e.sw) & 1); } },
    ],
  },
];
