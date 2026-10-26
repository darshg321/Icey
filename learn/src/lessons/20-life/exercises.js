const RULE = `module life_rule(
  input       self,         // is this cell alive now?
  input [7:0] neighbours,   // the eight cells around it
  output      next          // alive in the next generation?
);
  wire [3:0] n = neighbours[0] + neighbours[1] + neighbours[2] + neighbours[3]
               + neighbours[4] + neighbours[5] + neighbours[6] + neighbours[7];
  assign next = (n == 3) || (self && n == 2);
endmodule`;

// glider at rows 0-2, columns 0-2 of an 8x8 board; bit (r*8 + c)
const GLIDER = [[0, 1], [1, 2], [2, 0], [2, 1], [2, 2]];
const toBits = cells => cells.reduce((a, [r, c]) => a | (1n << BigInt(((r + 8) % 8) * 8 + ((c + 8) % 8))), 0n);
const lifeStep = bits => {
  let out = 0n;
  for (let r = 0; r < 8; r++) for (let c = 0; c < 8; c++) {
    let n = 0;
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
      if (!dr && !dc) continue;
      n += Number((bits >> BigInt(((r + dr + 8) % 8) * 8 + ((c + dc + 8) % 8))) & 1n);
    }
    const self = (bits >> BigInt(r * 8 + c)) & 1n;
    if (n === 3 || (self && n === 2)) out |= 1n << BigInt(r * 8 + c);
  }
  return out;
};
const show = b => Array.from({ length: 8 }, (_, r) => Array.from({ length: 8 }, (_, c) => ((b >> BigInt(r * 8 + c)) & 1n ? '#' : '.')).join('')).join('\n');

export default [
  {
    id: 'rule',
    title: 'The rule',
    prompt: 'A live cell with 2 or 3 live neighbours stays alive. A dead cell with exactly 3 comes alive. Everything else dies or stays dead.',
    starter: `module life_rule(
  input       self,
  input [7:0] neighbours,
  output      next
);
  assign next = self;
endmodule
`,
    solution: RULE,
    top: 'life_rule',
    tests: [{ name: 'every combination of a cell and its neighbours', run(t) {
      t.table(['self', 'neighbours'], ['next'], e => {
        let n = 0; for (let i = 0; i < 8; i++) n += (e.neighbours >> i) & 1;
        return (n === 3 || (e.self && n === 2)) ? 1 : 0;
      }, { describe: e => `self = ${e.self} with ${[...Array(8)].reduce((a, _, i) => a + ((e.neighbours >> i) & 1), 0)} live neighbours (neighbours = 8'b${e.neighbours.toString(2).padStart(8, '0')})` });
    } }],
  },
  {
    id: 'board8',
    project: true,
    title: '64 cells at once',
    prompt: 'An 8×8 Life board that wraps around at the edges, on the LED matrix. Every `STEP` clocks, all 64 cells move to the next generation together. SW2 puts the glider back.',
    starter: `${RULE}

module top(
  input         clk,
  input         BTN,
  output [63:0] cells_out     // bit r*8 + c = row r, column c
);
  parameter STEP = 3_000_000;   // a generation every quarter second
  localparam [63:0] GLIDER = 64'h0000_0000_0007_0402;

  reg [63:0] cells = GLIDER;
  wire [63:0] next;

  // generate: one life_rule per cell, wired to its eight neighbours

  assign cells_out = cells;
endmodule
`,
    solution: `${RULE}

module top(
  input         clk,
  input         BTN,
  output [63:0] cells_out
);
  parameter STEP = 3_000_000;
  localparam [63:0] GLIDER = 64'h0000_0000_0007_0402;

  reg [63:0] cells = GLIDER;
  wire [63:0] next;

  genvar r, c;
  generate
    for (r = 0; r < 8; r = r + 1) begin : row
      for (c = 0; c < 8; c = c + 1) begin : col
        localparam U = (r + 7) % 8, D = (r + 1) % 8, L = (c + 7) % 8, R = (c + 1) % 8;
        life_rule rule(
          .self(cells[r*8 + c]),
          .neighbours({cells[U*8 + L], cells[U*8 + c], cells[U*8 + R],
                       cells[r*8 + L],                 cells[r*8 + R],
                       cells[D*8 + L], cells[D*8 + c], cells[D*8 + R]}),
          .next(next[r*8 + c]));
      end
    end
  endgenerate

  reg [22:0] pre = 0;
  wire step = (pre == STEP - 1);
  always @(posedge clk) begin
    pre <= step ? 0 : pre + 1;
    if (!BTN) cells <= GLIDER;
    else if (step) cells <= next;
  end

  assign cells_out = cells;
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2: reset', activeLow: true, key: ' ' }, { type: 'matrix', port: 'cells_out', rows: 8, cols: 8, label: '8×8 Life' }],
    clock: { port: 'clk', hz: 12e6 },
    testParams: { STEP: 3 },
    tests: [
      { name: 'starts with the glider', run(t) {
        t.set('BTN', 1);
        const got = t.get('cells_out');
        t.ok(got === toBits(GLIDER), `At power-up the board should hold the glider:\n${show(toBits(GLIDER))}\nbut it was:\n${show(got)}`);
      } },
      { name: 'follows the rules for 40 generations, wrapping at the edges', run(t) {
        t.set('BTN', 1);
        let want = toBits(GLIDER);
        for (let g = 1; g <= 40; g++) {
          t.tick(3);
          want = lifeStep(want);
          const got = t.get('cells_out');
          if (got !== want) t.fail(`Generation ${g} should be:\n${show(want)}\nbut it was:\n${show(got)}`);
        }
      } },
    ],
  },
];
