const PALETTE = [0b000000, 0b110000, 0b111100, 0b111111];

export default [
  {
    id: 'c4-palette',
    title: 'Palette',
    prompt: '`{P2, P1}` picks black, red, yellow or white. Blue while reset is held. Preview on the RGB LED; LED1 for white.',
    starter: `module top(
  input  BTN,          // reset: 0 while held
  input  P1, P2,       // mode
  output LED,
  output RGB0,         // red:   0 = on
  output RGB1,         // blue:  0 = on
  output RGB2          // green: 0 = on
);
  reg [5:0] colour;    // rrggbb

  // choose colour here

  assign LED  = 0;
  assign RGB0 = 1;
  assign RGB1 = 1;
  assign RGB2 = 1;
endmodule
`,
    solution: `module top(
  input  BTN,
  input  P1, P2,
  output LED,
  output RGB0,
  output RGB1,
  output RGB2
);
  reg [5:0] colour;
  always @(*) begin
    if (!BTN)
      colour = 6'b000011;
    else
      case ({P2, P1})
        2'd0: colour = 6'b000000;
        2'd1: colour = 6'b110000;
        2'd2: colour = 6'b111100;
        default: colour = 6'b111111;
      endcase
  end

  assign RGB0 = ~|colour[5:4];
  assign RGB2 = ~|colour[3:2];
  assign RGB1 = ~|colour[1:0];
  assign LED  = &colour;
endmodule
`,
    board: [{ type: 'icey' }],
    tests: [
      { name: 'every mode, with reset up and held', run(t) {
        t.table(['BTN', 'P2', 'P1'], ['RGB0', 'RGB2', 'RGB1', 'LED'], ({ BTN, P1, P2 }) => {
          const c = BTN ? PALETTE[P2 * 2 + P1] : 0b000011;
          return { RGB0: c & 0b110000 ? 0 : 1, RGB2: c & 0b001100 ? 0 : 1, RGB1: c & 0b000011 ? 0 : 1, LED: c === 63 ? 1 : 0 };
        }, { describe: e => `mode = ${e.P2 * 2 + e.P1}, reset ${e.BTN ? 'up' : 'held'}` });
      } },
    ],
  },
];
