import { compile } from './compile-node.mjs';
import { Sim } from '../src/engine/sim.js';
import assert from 'node:assert/strict';

async function sim(src) { const r = await compile(src); if (!r.ok) { console.log(r.diags); throw new Error('compile failed'); } return new Sim(r.json, 'top'); }

// adder
let s = await sim(`module top(input [3:0] a, b, output [4:0] y); assign y = a + b; endmodule`);
for (let a = 0; a < 16; a++) for (let b = 0; b < 16; b++) { s.set('a', a); s.set('b', b); s.settle(); assert.equal(s.get('y'), a + b); }
console.log('adder ok, gates', s.gateCount);

// counter with reset + nonblocking swap
s = await sim(`module top(input clk, input rst, output reg [7:0] c, output reg x = 1, output reg y = 0);
always @(posedge clk) begin if (rst) c <= 0; else c <= c + 1; x <= y; y <= x; end endmodule`);
s.set('rst', 1); s.tick(); assert.equal(s.get('c'), 0);
s.set('rst', 0); s.tick('clk', 300); assert.equal(s.get('c'), 300 % 256);
assert.equal(s.get('x'), 0); assert.equal(s.get('y'), 1); // 301 swaps: odd
s.tick(); assert.equal(s.get('x'), 1);
console.log('counter ok');

// memory: sync write, async read, and a sync-read RAM
s = await sim(`module top(input clk, input we, input [3:0] wa, ra, input [7:0] d, output [7:0] q, output reg [7:0] q2);
reg [7:0] m [0:15]; reg [7:0] m2 [0:15];
always @(posedge clk) begin if (we) begin m[wa] <= d; m2[wa] <= d; end q2 <= m2[ra]; end
assign q = m[ra]; endmodule`);
s.set('we', 1); for (let i = 0; i < 16; i++) { s.set('wa', i); s.set('d', i * 7 + 3); s.tick(); }
s.set('we', 0);
for (let i = 0; i < 16; i++) { s.set('ra', i); s.settle(); assert.equal(s.get('q'), i * 7 + 3); s.tick(); assert.equal(s.get('q2'), i * 7 + 3); }
console.log('memory ok', s.mems.length, 'mems');

// ROM with initial
s = await sim(`module top(input clk, input [2:0] a, output reg [7:0] q);
reg [7:0] rom [0:7]; integer i; initial for (i=0;i<8;i=i+1) rom[i] = i*i;
always @(posedge clk) q <= rom[a]; endmodule`);
for (let i = 0; i < 8; i++) { s.set('a', i); s.tick(); assert.equal(s.get('q'), i * i); }
console.log('rom ok');

// divided clock
s = await sim(`module top(input clk, output reg slow = 0, output reg [3:0] n = 0);
always @(posedge clk) slow <= ~slow; always @(posedge slow) n <= n + 1; endmodule`);
s.tick('clk', 20); assert.equal(s.get('n'), 10);
console.log('divider ok');

// case / 7seg style
s = await sim(`module top(input [1:0] s, output reg [3:0] y); always @(*) case (s) 0: y = 1; 1: y = 2; 2: y = 4; default: y = 8; endcase endmodule`);
for (let i = 0; i < 4; i++) { s.set('s', i); s.settle(); assert.equal(s.get('y'), 1 << i); }
console.log('case ok');

// comb loop
const r = await compile(`module top(input a, output y); wire t; assign t = ~t & a; assign y = t; endmodule`);
try { new Sim(r.json, 'top'); assert.fail('no loop error'); } catch (e) { console.log('loop ->', e.message.slice(0, 60)); }

// perf
s = await sim(`module top(input clk, output led); reg [23:0] c = 0; always @(posedge clk) c <= c + 1; assign led = c[23]; endmodule`);
let t = performance.now(); s.tick('clk', 1e6); console.log('24-bit counter: ', (1e6 / ((performance.now() - t) / 1000) / 1e6).toFixed(2), 'M cycles/s, gates', s.gateCount);
assert.equal(s.get('c'), 1e6);

// errors
for (const src of [`module top(input a, output y); assign y = a endmodule`, `module top(input a, output y); assign y = b; endmodule`, `module top(input a, en, output reg y); always @(*) if (en) y = a; endmodule`])
  console.log((await compile(src)).diags);
console.log('all ok');
