const nib = (port, label) => ({ type: 'switches', port, width: 4, label });

export default [
  {
    id: 'full-adder',
    title: 'A full adder',
    prompt: 'Add `a + b + cin`. `sum` is the low bit of the total and `cout` is the high bit.',
    starter: `module top(
  input  a, b, cin,
  output sum,
  output cout
);
  assign sum  = 0;
  assign cout = 0;
endmodule
`,
    solution: `module top(
  input  a, b, cin,
  output sum,
  output cout
);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule
`,
    board: [{ type: 'switches', port: 'a', width: 1, label: 'a' }, { type: 'switches', port: 'b', width: 1, label: 'b' }, { type: 'switches', port: 'cin', width: 1, label: 'cin' },
      { type: 'led', port: 'cout', label: 'cout' }, { type: 'led', port: 'sum', label: 'sum' }],
    tests: [
      { name: 'sum is the low bit of a + b + cin', run(t) { t.table(['a', 'b', 'cin'], ['sum'], e => (e.a + e.b + e.cin) & 1); } },
      { name: 'cout is the high bit', run(t) { t.table(['a', 'b', 'cin'], ['cout'], e => (e.a + e.b + e.cin) >> 1); } },
    ],
  },
  {
    id: 'ripple',
    title: 'Four of them in a row',
    prompt: 'Finish the ripple-carry adder: four `full_adder` instances, each one\'s carry out feeding the next one\'s carry in. Don\'t use `+`.',
    starter: `module full_adder(input a, b, cin, output sum, cout);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module top(
  input  [3:0] a,
  input  [3:0] b,
  output [4:0] total
);
  wire c1, c2, c3;
  full_adder fa0(.a(a[0]), .b(b[0]), .cin(1'b0), .sum(total[0]), .cout(c1));

  // fa1, fa2 and fa3 go here. fa3's carry out is total[4].

endmodule
`,
    solution: `module full_adder(input a, b, cin, output sum, cout);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module top(
  input  [3:0] a,
  input  [3:0] b,
  output [4:0] total
);
  wire c1, c2, c3;
  full_adder fa0(.a(a[0]), .b(b[0]), .cin(1'b0), .sum(total[0]), .cout(c1));
  full_adder fa1(.a(a[1]), .b(b[1]), .cin(c1),   .sum(total[1]), .cout(c2));
  full_adder fa2(.a(a[2]), .b(b[2]), .cin(c2),   .sum(total[2]), .cout(c3));
  full_adder fa3(.a(a[3]), .b(b[3]), .cin(c3),   .sum(total[3]), .cout(total[4]));
endmodule
`,
    board: [nib('a', 'a'), nib('b', 'b'), { type: 'leds', port: 'total', label: 'total[4:0]' }, { type: 'value', port: 'total', label: 'decimal' }],
    tests: [
      { name: 'total = a + b for every a and b', run(t) { t.table(['a', 'b'], ['total'], e => e.a + e.b); } },
      { name: 'built from full adders, without +', run(t) {
        if (/\+/.test(t.code)) t.fail('No + in this one: chain the full_adder instances together instead. (You get to use + in the next exercise.)');
        if ((t.code.match(/full_adder\s+\w+\s*\(/g) || []).length < 4) t.fail('There should be four full_adder instances.');
      } },
    ],
  },
  {
    id: 'plus',
    title: 'The easy way',
    prompt: 'Same adder, written with `+`. Make sure 15 + 15 comes out as 30.',
    starter: `module top(
  input  [3:0] a,
  input  [3:0] b,
  output [4:0] total
);
  assign total = 0;
endmodule
`,
    solution: `module top(
  input  [3:0] a,
  input  [3:0] b,
  output [4:0] total
);
  assign total = a + b;
endmodule
`,
    board: [nib('a', 'a'), nib('b', 'b'), { type: 'leds', port: 'total', label: 'total[4:0]' }, { type: 'value', port: 'total', label: 'decimal' }],
    tests: [{ name: 'total = a + b, including the carry', run(t) { t.table(['a', 'b'], ['total'], e => e.a + e.b); } }],
  },
];
