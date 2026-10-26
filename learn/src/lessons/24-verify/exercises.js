import { equivalent, proveAsserts } from '../../engine/formal.js';
import { SIM_SCRIPT, prelude } from '../../engine/yosys.js';
import { Sim } from '../../engine/sim.js';

const REF = `// The reference: obviously correct, and slow.
module popcount_ref(input [7:0] x, output reg [3:0] n);
  integer i;
  always @(*) begin
    n = 0;
    for (i = 0; i < 8; i = i + 1) n = n + x[i];
  end
endmodule`;

const FAST_BUGGY = `// Adds bits in pairs, then pairs of pairs, then the two halves.
module popcount_fast(input [7:0] x, output [3:0] n);
  wire [7:0] pairs = (x & 8'h55) + ((x >> 1) & 8'h55);        // four 2-bit counts
  wire [7:0] quads = (pairs & 8'h33) + ((pairs >> 2) & 8'h33); // two 4-bit counts
  wire [2:0] total = quads[3:0] + quads[7:4];
  assign n = total;
endmodule`;

const FAST = FAST_BUGGY.replace('wire [2:0] total', 'wire [3:0] total');

const FIFO_BUGGY = `// A 4-entry FIFO. Push adds a byte at the back, pop removes the front.
module fifo(
  input        clk,
  input        push,
  input        pop,
  input  [7:0] din,
  output [7:0] dout,
  output       full,
  output       empty
);
  reg [7:0] mem [0:3];
  reg [1:0] wp = 0, rp = 0;     // write and read pointers
  reg [2:0] count = 0;          // how many bytes are stored, 0..4

  assign full  = (count == 4);
  assign empty = (count == 0);
  assign dout  = mem[rp];

  always @(posedge clk) begin
    if (push && !full) begin
      mem[wp] <= din;
      wp <= wp + 1;
    end
    if (pop && !empty)
      rp <= rp + 1;
    case ({push, pop && !empty})
      2'b10: count <= count + 1;
      2'b01: count <= count - 1;
      default: ;
    endcase
  end

  // Your assertions go here, for example:
  // always @(*) assert(count <= 4);
endmodule`;

const FIFO = FIFO_BUGGY
  .replace('case ({push, pop && !empty})', 'case ({push && !full, pop && !empty})')
  .replace(`  // Your assertions go here, for example:
  // always @(*) assert(count <= 4);`, `  always @(*) begin
    assert(count <= 4);
    assert(wp - rp == count[1:0]);    // pointers agree with the count
  end`);

async function simulate(run, src, top) {
  const r = await run(SIM_SCRIPT(top), { 'design.v': prelude(src) });
  if (!r.ok) throw new Error('It didn\'t compile; see the Log tab.');
  const json = typeof r.files['out.json'] === 'string' ? JSON.parse(r.files['out.json']) : JSON.parse(new TextDecoder().decode(r.files['out.json']));
  return new Sim(json, top);
}

export default [
  {
    id: 'equiv',
    title: 'Prove it matches',
    prompt: '`popcount_fast` counts the 1 bits in a byte with a clever trick. A quick random test says it works. The equivalence check says otherwise. Find and fix the bug.',
    starter: `${FAST_BUGGY}\n\n${REF}\n`,
    solution: `${FAST}\n\n${REF}\n`,
    top: 'popcount_fast',
    icey: false,
    gates: false,
    async formal(src, run) {
      const out = [];
      // what a hurried testbench does: a few dozen random inputs
      const sim = await simulate(run, src, 'popcount_fast');
      let seed = 7, bad = null;
      for (let i = 0; i < 40; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        const x = (seed >> 8) % 255;     // the hurried tester's generator never makes 255
        sim.set('x', x); sim.settle();
        let pop = 0; for (let b = 0; b < 8; b++) pop += (x >> b) & 1;
        if (sim.get('n') !== pop) { bad = `x = ${x}: got ${sim.get('n')}, expected ${pop}`; break; }
      }
      out.push({ name: '40 random test inputs', pass: !bad, message: bad ? `Failed for ${bad}.` : 'Passed. Looks done, doesn\'t it?' });
      const eq = await equivalent(run, src, 'popcount_ref', 'popcount_fast');
      if (eq.cex && 'x' in eq.cex) {
        sim.set('x', eq.cex.x); sim.settle();
        let pop = 0; for (let b = 0; b < 8; b++) pop += (eq.cex.x >> b) & 1;
        eq.message += ` popcount_fast says ${sim.get('n')}, the reference says ${pop}. (1 input in 256: a random test of 40 inputs misses it most of the time.)`;
      }
      out.push({ name: 'formally equivalent to popcount_ref for all 256 inputs', ...eq });
      return out;
    },
  },
  {
    id: 'fifo',
    project: true,
    title: 'A FIFO that can\'t go wrong',
    prompt: 'Write at least two assertions about how `count`, `wp` and `rp` relate. Let the prover find the bug, fix it, and make the proof go through.',
    starter: FIFO_BUGGY + '\n',
    solution: FIFO + '\n',
    top: 'fifo',
    icey: false,
    gates: false,
    async formal(src, run) {
      const code = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
      const n = (code.match(/\bassert\s*\(/g) || []).length;
      const out = [{ name: 'has at least two assertions', pass: n >= 2, message: n >= 2 ? '' : `Found ${n}. Write down what must always be true about count, wp and rp.` }];
      const p = await proveAsserts(run, src, 'fifo');
      out.push({ name: 'the assertions are proven', ...p });
      // and an independent check against a model, so the assertions can't be trivially weak
      const sim = await simulate(run, src, 'fifo');
      const q = [];
      let seed = 99, msg = '';
      for (let i = 0; i < 3000 && !msg; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        const push = (seed >> 9) & 1, pop = (seed >> 13) & 1 & ((seed >> 17) & 1 | (seed >> 3) & 1), din = (seed >> 20) & 255;
        sim.set('push', push); sim.set('pop', pop); sim.set('din', din); sim.settle();
        if (sim.get('full') !== +(q.length === 4)) msg = `after ${i} steps with ${q.length} bytes stored, full = ${sim.get('full')}`;
        else if (sim.get('empty') !== +(q.length === 0)) msg = `after ${i} steps with ${q.length} bytes stored, empty = ${sim.get('empty')}`;
        else if (q.length && sim.get('dout') !== q[0]) msg = `after ${i} steps dout = ${sim.get('dout')}, but the oldest byte is ${q[0]}`;
        const doPop = pop && q.length > 0, doPush = push && q.length < 4;
        if (doPop) q.shift();
        if (doPush) q.push(din);
        sim.tick('clk');
      }
      out.push({ name: '3,000 random pushes and pops against a model', pass: !msg, message: msg ? `Doesn't behave like a FIFO: ${msg}.` : '' });
      return out;
    },
  },
];
