// Icey-8: the CPU designed in this lesson. Every instruction is two bytes:
// an opcode, then an operand (a number or an address).
export const OPS = { LDI: 0, LDA: 1, STA: 2, ADD: 3, SUB: 4, AND: 5, OR: 6, XOR: 7, JMP: 8, JZ: 9, JC: 10, OUT: 11, IN: 12, HLT: 15 };

const ALU = `module alu(
  input      [2:0] op,     // 0 add, 1 sub, 2 and, 3 or, 4 xor
  input      [7:0] a,
  input      [7:0] b,
  output reg [7:0] y,
  output reg       carry   // add: carry out. sub: borrow (a < b)
);
  always @(*) begin
    carry = 0;
    case (op)
      3'd0: {carry, y} = a + b;
      3'd1: {carry, y} = {1'b0, a} - {1'b0, b};
      3'd2: y = a & b;
      3'd3: y = a | b;
      3'd4: y = a ^ b;
      default: y = b;
    endcase
  end
endmodule`;

const FIB = `  // Fibonacci: outputs 1 1 2 3 5 8 13 ... 233, then halts
  initial begin
    mem[8'h00] = 8'h00; mem[8'h01] = 8'h00;   //       LDI 0
    mem[8'h02] = 8'h02; mem[8'h03] = 8'h80;   //       STA x
    mem[8'h04] = 8'h00; mem[8'h05] = 8'h01;   //       LDI 1
    mem[8'h06] = 8'h02; mem[8'h07] = 8'h81;   //       STA y
    mem[8'h08] = 8'h01; mem[8'h09] = 8'h81;   // loop: LDA y
    mem[8'h0a] = 8'h0b; mem[8'h0b] = 8'h00;   //       OUT
    mem[8'h0c] = 8'h03; mem[8'h0d] = 8'h80;   //       ADD x
    mem[8'h0e] = 8'h0a; mem[8'h0f] = 8'h1c;   //       JC done
    mem[8'h10] = 8'h02; mem[8'h11] = 8'h82;   //       STA t
    mem[8'h12] = 8'h01; mem[8'h13] = 8'h81;   //       LDA y
    mem[8'h14] = 8'h02; mem[8'h15] = 8'h80;   //       STA x
    mem[8'h16] = 8'h01; mem[8'h17] = 8'h82;   //       LDA t
    mem[8'h18] = 8'h02; mem[8'h19] = 8'h81;   //       STA y
    mem[8'h1a] = 8'h08; mem[8'h1b] = 8'h08;   //       JMP loop
    mem[8'h1c] = 8'h0f; mem[8'h1d] = 8'h00;   // done: HLT
  end`;

const CPU_SOL = `module cpu(
  input            clk,
  input      [7:0] in_port,
  output reg [7:0] out_port = 0,
  output reg       out_strobe = 0,   // high for one clock on every OUT
  output           halted,
  output     [7:0] pc_out,
  output     [7:0] a_out
);
  reg [7:0] mem [0:255];
${FIB}

  localparam FETCH = 3'd0, OP = 3'd1, ARG = 3'd2, EXEC = 3'd3, HALT = 3'd4;
  reg [2:0] state = FETCH;
  reg [7:0] pc = 0, a = 0, op = 0, arg = 0;
  reg z = 0, c = 0;

  // memory: the address comes from the state machine, reads are registered
  reg [7:0] rdata = 0;
  reg [7:0] maddr;
  wire we = (state == EXEC) && (op == 8'd2);   // STA
  always @(*) begin
    case (state)
      FETCH:   maddr = pc;
      OP:      maddr = pc + 1;
      ARG:     maddr = rdata;      // the operand, used as an address
      default: maddr = arg;
    endcase
  end
  always @(posedge clk) begin
    if (we) mem[maddr] <= a;
    rdata <= mem[maddr];
  end

  wire [7:0] y;
  wire carry;
  alu alu(.op(op[2:0] - 3'd3), .a(a), .b(rdata), .y(y), .carry(carry));

  always @(posedge clk) begin
    out_strobe <= 0;
    case (state)
      FETCH: state <= OP;
      OP:    begin op <= rdata; state <= ARG; end
      ARG:   begin arg <= rdata; pc <= pc + 2; state <= EXEC; end
      EXEC: begin
        state <= FETCH;
        case (op)
          8'd0:  begin a <= arg;   z <= (arg == 0); end                  // LDI
          8'd1:  begin a <= rdata; z <= (rdata == 0); end                // LDA
          8'd3, 8'd4: begin a <= y; c <= carry; z <= (y == 0); end       // ADD SUB
          8'd5, 8'd6, 8'd7: begin a <= y; z <= (y == 0); end             // AND OR XOR
          8'd8:  pc <= arg;                                              // JMP
          8'd9:  if (z) pc <= arg;                                       // JZ
          8'd10: if (c) pc <= arg;                                       // JC
          8'd11: begin out_port <= a; out_strobe <= 1; end               // OUT
          8'd12: begin a <= in_port; z <= (in_port == 0); end            // IN
          8'd15: state <= HALT;                                          // HLT
          default: ;                                                     // STA, and unknown opcodes
        endcase
      end
      default: state <= HALT;
    endcase
  end

  assign halted = (state == HALT);
  assign pc_out = pc;
  assign a_out = a;
endmodule`;

const TOP = `module top(
  input        clk,
  input  [7:0] sw,
  output [7:0] led,
  output [7:0] pc,
  output [7:0] acc,
  output       halted
);
  cpu cpu(.clk(clk), .in_port(sw), .out_port(led), .out_strobe(), .halted(halted), .pc_out(pc), .a_out(acc));
endmodule`;

// Assemble "LDI 5" style lines into bytes (labels allowed). Shared with the widget.
export function assemble(text) {
  const lines = text.split('\n');
  const labels = {}, out = [], refs = [];
  let pc = 0;
  const num = s => { s = s.trim(); if (/^\$[0-9a-f]+$/i.test(s)) return parseInt(s.slice(1), 16); if (/^0x[0-9a-f]+$/i.test(s)) return parseInt(s, 16); if (/^-?\d+$/.test(s)) return (+s) & 255; return null; };
  lines.forEach((raw, i) => {
    let line = raw.replace(/;.*$/, '').trim();
    const lm = line.match(/^([A-Za-z_]\w*):\s*(.*)$/);
    if (lm) { labels[lm[1]] = pc; line = lm[2]; }
    if (!line) return;
    const [mn, ...rest] = line.split(/\s+/);
    const m = mn.toUpperCase();
    const operand = rest.join(' ');
    if (m === '.ORG') { pc = num(operand); return; }
    if (m === '.BYTE') { for (const v of operand.split(',')) { out.push([pc++, num(v) ?? 0, i]); } return; }
    if (!(m in OPS)) throw new Error(`line ${i + 1}: unknown instruction "${mn}"`);
    out.push([pc++, OPS[m], i]);
    const v = operand ? num(operand) : 0;
    if (v === null) refs.push([out.length, operand.trim(), i]);
    out.push([pc++, v ?? 0, i]);
  });
  for (const [idx, name, i] of refs) {
    if (!(name in labels)) throw new Error(`line ${i + 1}: unknown label "${name}"`);
    out[idx][1] = labels[name];
  }
  return out.map(([addr, val]) => [addr & 255, val & 255]);
}

export function toInitial(bytes) {
  const lines = [];
  for (let i = 0; i < bytes.length; i += 2) {
    const h = ([a, v]) => `mem[8'h${a.toString(16).padStart(2, '0')}] = 8'h${v.toString(16).padStart(2, '0')};`;
    lines.push('    ' + h(bytes[i]) + (bytes[i + 1] ? ' ' + h(bytes[i + 1]) : ''));
  }
  return `  initial begin\n${lines.join('\n')}\n  end`;
}

// Put a program into the CPU's memory and collect what it OUTputs.
function runProgram(t, src, { maxCycles = 20000, input = 0 } = {}) {
  const mem = t.sim.peekMem('mem');
  if (!mem) t.fail('The tests need the CPU\'s memory to be called "mem": reg [7:0] mem [0:255];');
  mem.data.fill(0);
  for (const [a, v] of assemble(src)) for (let b = 0; b < 8; b++) mem.data[a * 8 + b] = (v >> b) & 1;
  if (t.has('in_port')) t.sim.set('in_port', input);
  const outs = [];
  for (let i = 0; i < maxCycles; i++) {
    t.sim.tick('clk');
    if (t.sim.get('out_strobe')) outs.push(t.sim.get('out_port'));
    if (t.sim.get('halted')) return outs;
  }
  t.fail(`The program didn't reach HLT within ${maxCycles} clocks. Outputs so far: ${outs.join(', ') || 'none'}.`);
}

function expectOuts(t, src, want, what, opts) {
  const got = runProgram(t, src, opts);
  t.ok(JSON.stringify(got) === JSON.stringify(want), `${what}: expected OUT values ${want.join(', ')}, got ${got.join(', ') || 'nothing'}.\n\n${src.trim()}`);
}

export default [
  {
    id: 'alu',
    title: 'The ALU',
    prompt: 'The arithmetic and logic unit: add, subtract, AND, OR, XOR on two bytes. `carry` is the carry out of an add, or the borrow of a subtract (1 when `b > a`).',
    starter: `module alu(
  input      [2:0] op,     // 0 add, 1 sub, 2 and, 3 or, 4 xor
  input      [7:0] a,
  input      [7:0] b,
  output reg [7:0] y,
  output reg       carry
);
  always @(*) begin
    carry = 0;
    y = 0;
  end
endmodule
`,
    solution: ALU,
    top: 'alu',
    tests: [
      { name: 'add', run(t) { t.set('op', 0); t.table(['a', 'b'], ['y', 'carry'], e => ({ y: (e.a + e.b) & 255, carry: (e.a + e.b) >> 8 }), { max: 3000 }); } },
      { name: 'subtract', run(t) { t.set('op', 1); t.table(['a', 'b'], ['y', 'carry'], e => ({ y: (e.a - e.b) & 255, carry: e.b > e.a ? 1 : 0 }), { max: 3000 }); } },
      { name: 'and, or, xor', run(t) {
        for (const [op, f] of [[2, (x, y) => x & y], [3, (x, y) => x | y], [4, (x, y) => x ^ y]]) {
          t.set('op', op); t.table(['a', 'b'], ['y'], e => f(e.a, e.b), { max: 1000 });
        }
      } },
    ],
  },
  {
    id: 'cpu',
    project: true,
    title: 'Icey-8',
    prompt: 'Build the CPU described above. The memory must be called `mem`; the tests load their own programs into it. The board runs the Fibonacci program at 40 Hz so you can watch.',
    starter: `${ALU}

module cpu(
  input            clk,
  input      [7:0] in_port,
  output reg [7:0] out_port = 0,
  output reg       out_strobe = 0,
  output           halted,
  output     [7:0] pc_out,
  output     [7:0] a_out
);
  reg [7:0] mem [0:255];
${FIB}

  localparam FETCH = 3'd0, OP = 3'd1, ARG = 3'd2, EXEC = 3'd3, HALT = 3'd4;
  reg [2:0] state = FETCH;
  reg [7:0] pc = 0, a = 0, op = 0, arg = 0;
  reg z = 0, c = 0;

  // memory port, ALU, and the fetch/execute state machine

  assign halted = (state == HALT);
  assign pc_out = pc;
  assign a_out = a;
endmodule

${TOP}
`,
    solution: `${ALU}

${CPU_SOL}

${TOP}
`,
    testTop: 'cpu',
    board: [{ type: 'switches', port: 'sw', width: 8, label: 'in_port' }, { type: 'leds', port: 'led', label: 'out_port' }, { type: 'value', port: 'pc', label: 'PC', format: 'hex' }, { type: 'value', port: 'acc', label: 'A' }, { type: 'led', port: 'halted', label: 'halted', color: '#ff3b2f' }],
    clock: { port: 'clk', hz: 40 },
    gates: false,
    tests: [
      { name: 'LDI and OUT', run(t) { expectOuts(t, 'LDI 5\nOUT\nLDI 200\nOUT\nHLT', [5, 200], 'Two loads and outputs'); } },
      { name: 'STA and LDA', run(t) { expectOuts(t, 'LDI 42\nSTA $90\nLDI 0\nLDA $90\nOUT\nHLT', [42], 'Store, clear, load back'); } },
      { name: 'arithmetic and logic', run(t) {
        expectOuts(t, 'LDI 30\nSTA $90\nLDI 12\nADD $90\nOUT\nSUB $90\nOUT\nLDI $f0\nAND v\nOUT\nOR v\nOUT\nXOR v\nOUT\nHLT\nv: .byte $3c', [42, 12, 0x30, 0x3c, 0x00], 'ADD, SUB, AND, OR, XOR');
      } },
      { name: 'loops with JZ and JMP', run(t) { expectOuts(t, 'LDI 5\nloop: OUT\nSUB one\nJZ done\nJMP loop\ndone: HLT\none: .byte 1', [5, 4, 3, 2, 1], 'A countdown'); } },
      { name: 'JC after an add that overflows', run(t) { expectOuts(t, 'LDI 250\nADD ten\nJC yes\nLDI 0\nOUT\nHLT\nyes: OUT\nHLT\nten: .byte 10', [4], '250 + 10 should carry, and leave 4 in A'); } },
      { name: 'IN reads the switches', run(t) { expectOuts(t, 'IN\nOUT\nHLT', [0x5a], 'IN with the switches at 0x5a', { input: 0x5a }); } },
      { name: 'runs the Fibonacci program', run(t) {
        const src = `LDI 0\nSTA x\nLDI 1\nSTA y\nloop: LDA y\nOUT\nADD x\nJC done\nSTA t\nLDA y\nSTA x\nLDA t\nSTA y\nJMP loop\ndone: HLT\n.org $80\nx: .byte 0\ny: .byte 0\nt: .byte 0`;
        expectOuts(t, src, [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233], 'Fibonacci');
      } },
    ],
  },
];
