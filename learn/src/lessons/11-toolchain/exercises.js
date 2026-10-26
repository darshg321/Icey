import { used, logicCells } from '../../engine/flow.js';

export default [
  {
    id: 'prime',
    title: 'A prime detector in one cell',
    prompt: 'Light `LED` when the 4-bit number on the switches is prime (2, 3, 5, 7, 11, 13). Write it however you like. Then build for Icey: it should fit in **one** logic cell.',
    starter: `module top(
  input  [3:0] sw,
  output LED
);
  assign LED = 0;
endmodule
`,
    solution: `module top(
  input  [3:0] sw,
  output LED
);
  assign LED = (sw == 2) | (sw == 3) | (sw == 5) | (sw == 7) | (sw == 11) | (sw == 13);
endmodule
`,
    board: [{ type: 'switches', port: 'sw', width: 4, label: 'sw' }, { type: 'value', port: 'sw', label: 'number' }, { type: 'led', port: 'LED', label: 'prime?' }],
    tests: [{ name: 'LED = sw is prime', run(t) { t.table(['sw'], ['LED'], e => +[2, 3, 5, 7, 11, 13].includes(e.sw)); } }],
    chipTests: [{ name: 'fits in one logic cell', check: r => logicCells(r) <= 1 ? null : `It used ${logicCells(r)} logic cells. Any function of four inputs fits in one LUT.` }],
  },
  {
    id: 'carry',
    title: 'Watch a carry chain',
    prompt: 'A 16-bit counter on `clk`, with its top bit on `LED`. Build it for Icey and find the column of carry cells in the chip view.',
    starter: `module top(
  input  clk,
  output LED
);
  // a 16-bit counter
  assign LED = 0;
endmodule
`,
    solution: `module top(
  input  clk,
  output LED
);
  reg [15:0] count = 0;
  always @(posedge clk) count <= count + 1;
  assign LED = count[15];
endmodule
`,
    board: [{ type: 'led', port: 'LED', label: 'LED1' }],
    clock: { port: 'clk', hz: 12e6 },
    tests: [{ name: 'counts', run(t) { t.tick(32768); t.eq('LED', 1, 'after 32,768 clocks'); t.tick(32768); t.eq('LED', 0, 'after 65,536 clocks'); } }],
    chipTests: [
      { name: 'uses the carry chain', check: r => r.cells.some(c => c.params.CARRY_ENABLE === '1') ? null : 'No logic cell has its carry logic enabled. Did you write the counter with +?' },
      { name: 'about one cell per bit', check: r => logicCells(r) <= 20 ? null : `${logicCells(r)} logic cells for a 16-bit counter. With the carry chain it should be around 16.` },
    ],
  },
];
