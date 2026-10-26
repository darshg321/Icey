const HEX = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71];
const SEG_TABLE = `  case (digit)
    4'h0: seg = 7'b0111111;
    4'h1: seg = 7'b0000110;
    4'h2: seg = 7'b1011011;
    4'h3: seg = 7'b1001111;
    4'h4: seg = 7'b1100110;
    4'h5: seg = 7'b1101101;
    4'h6: seg = 7'b1111101;
    4'h7: seg = 7'b0000111;
    4'h8: seg = 7'b1111111;
    4'h9: seg = 7'b1101111;
    4'ha: seg = 7'b1110111;
    4'hb: seg = 7'b1111100;
    4'hc: seg = 7'b0111001;
    4'hd: seg = 7'b1011110;
    4'he: seg = 7'b1111001;
    4'hf: seg = 7'b1110001;
    default: seg = 7'b0000000;
  endcase`;
const showDigit = d => `digit = ${d} (${d.toString(16).toUpperCase()})`;

export default [
  {
    id: 'pick',
    title: 'Pick one',
    prompt: 'When `sel` is 0, show `a` on the LEDs. When it\'s 1, show `b`.',
    starter: `module top(
  input  [3:0] a,
  input  [3:0] b,
  input        sel,
  output [3:0] led
);
  assign led = a;
endmodule
`,
    solution: `module top(
  input  [3:0] a,
  input  [3:0] b,
  input        sel,
  output [3:0] led
);
  assign led = sel ? b : a;
endmodule
`,
    board: [{ type: 'switches', port: 'a', width: 4, label: 'a' }, { type: 'switches', port: 'b', width: 4, label: 'b' }, { type: 'switches', port: 'sel', width: 1, label: 'sel' }, { type: 'leds', port: 'led', label: 'led' }],
    tests: [{ name: 'led = sel ? b : a', run(t) { t.table(['a', 'b', 'sel'], ['led'], e => (e.sel ? e.b : e.a)); } }],
  },
  {
    id: 'hex7',
    title: 'Hex digit decoder',
    prompt: 'Light the right segments to draw `digit` in hex: 0 to 9, then A b C d E F. `seg[0]` is bar a, `seg[6]` is bar g.',
    starter: `module top(
  input      [3:0] digit,
  output reg [6:0] seg     // {g, f, e, d, c, b, a}
);
  always @(*) begin
    case (digit)
      4'h0: seg = 7'b0111111;
      4'h1: seg = 7'b0000110;
      // ...the other fourteen
      default: seg = 7'b0000000;
    endcase
  end
endmodule
`,
    solution: `module top(
  input      [3:0] digit,
  output reg [6:0] seg
);
  always @(*) begin
${SEG_TABLE.replace(/^/gm, '  ')}
  end
endmodule
`,
    board: [{ type: 'switches', port: 'digit', width: 4, label: 'digit' }, { type: 'seg7', port: 'seg', label: 'seg' }],
    tests: [{ name: 'every digit from 0 to F', run(t) { t.table(['digit'], ['seg'], e => HEX[e.digit], { describe: e => showDigit(e.digit) }); } }],
  },
  {
    id: 'latch',
    title: 'Find the latch',
    prompt: '`y` should be the number of the highest active request, and `valid` should say whether there\'s any request at all. With no requests, `y` must be 0. Run it as is first and read the warning, then fix it.',
    starter: `module top(
  input  [2:0] req,
  output reg [1:0] y,
  output valid
);
  assign valid = |req;

  always @(*) begin
    if (req[2])      y = 2'd2;
    else if (req[1]) y = 2'd1;
    else if (req[0]) y = 2'd0;
  end
endmodule
`,
    solution: `module top(
  input  [2:0] req,
  output reg [1:0] y,
  output valid
);
  assign valid = |req;

  always @(*) begin
    y = 2'd0;
    if (req[2])      y = 2'd2;
    else if (req[1]) y = 2'd1;
  end
endmodule
`,
    board: [{ type: 'switches', port: 'req', width: 3, label: 'req' }, { type: 'leds', port: 'y', label: 'y' }, { type: 'led', port: 'valid', label: 'valid' }],
    tests: [
      { name: 'y is the highest active request', run(t) { t.table(['req'], ['y'], e => (e.req & 4 ? 2 : e.req & 2 ? 1 : 0)); } },
      { name: 'y goes back to 0 when the requests stop', run(t) { t.set('req', 4); t.eq('y', 2, 'with req = 3\'b100'); t.set('req', 0); t.eq('y', 0, 'after req goes back to 0 (a latch would still be holding 2)'); } },
    ],
  },
  {
    id: 'calc',
    project: true,
    title: 'Hex calculator',
    prompt: 'Show `a + b` in hex on two digits: `hex1` on the left, `hex0` on the right.',
    starter: `module hex7(
  input      [3:0] digit,
  output reg [6:0] seg
);
  // paste your decoder here
endmodule

module top(
  input  [3:0] a,
  input  [3:0] b,
  output [6:0] hex1,   // left digit
  output [6:0] hex0    // right digit
);
  // an adder, and two hex7 instances

endmodule
`,
    solution: `module hex7(
  input      [3:0] digit,
  output reg [6:0] seg
);
  always @(*) begin
${SEG_TABLE.replace(/^/gm, '  ')}
  end
endmodule

module top(
  input  [3:0] a,
  input  [3:0] b,
  output [6:0] hex1,
  output [6:0] hex0
);
  wire [4:0] total = a + b;
  hex7 left (.digit({3'b000, total[4]}), .seg(hex1));
  hex7 right(.digit(total[3:0]),          .seg(hex0));
endmodule
`,
    board: [{ type: 'switches', port: 'a', width: 4, label: 'a' }, { type: 'switches', port: 'b', width: 4, label: 'b' }, { type: 'seg7', ports: ['hex1', 'hex0'], label: 'a + b' }],
    tests: [{ name: 'shows a + b in hex', run(t) {
      t.table(['a', 'b'], ['hex1', 'hex0'], e => ({ hex1: HEX[(e.a + e.b) >> 4], hex0: HEX[(e.a + e.b) & 15] }), { describe: e => `a = ${e.a}, b = ${e.b} (sum ${(e.a + e.b).toString(16).toUpperCase()})` });
    } }],
  },
];
