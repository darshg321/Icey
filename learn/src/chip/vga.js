// Shared pieces for the chip path's VGA days: the checks a monitor would make,
// the virtual board, and the Icey wrapper that turns 2-bit-per-colour designs
// (the Tiny Tapeout VGA format) into Icey's 3/3/2 resistor DAC.
import { CLOCKS } from '../ui/wrap.js';

export const clock = { port: 'clk', hz: 25.175e6 };

// How to read the video signals off a design. `plain` is the module shape of
// days 9-12; `tt` reads them from uo_out in the TinyVGA order.
export const plain = {
  hs: sim => sim.get('hsync'),
  vs: sim => sim.get('vsync'),
  rgb: sim => (sim.get('r') << 4) | (sim.get('g') << 2) | sim.get('b'),
};
export const tt = {
  hs: sim => (sim.get('uo_out') >> 7) & 1,
  vs: sim => (sim.get('uo_out') >> 3) & 1,
  rgb: sim => {
    const u = sim.get('uo_out'), bit = n => (u >> n) & 1;
    return (bit(0) << 5) | (bit(4) << 4) | (bit(1) << 3) | (bit(5) << 2) | (bit(2) << 1) | bit(6);
  },
};

export const monitor = { type: 'vga', hsync: 'hsync', vsync: 'vsync', r: 'r', g: 'g', b: 'b' };
export const iceyMonitor = { type: 'vga', hsync: 'HSYNC', vsync: 'VSYNC', r: 'VGA_R', g: 'VGA_G', b: 'VGA_B' };

// Holds rst_n low for a few clocks if the design has one.
export function reset(t) {
  if (!t.has('rst_n')) return;
  t.sim.set('rst_n', 0);
  for (let i = 0; i < 4; i++) t.sim.tick('clk');
  t.sim.set('rst_n', 1);
}

// A real chip powers up with random register contents. Power up twice with
// different random states, reset, and the first frames must be identical.
// `restart` sets the inputs and does the reset.
export function sameAfterAnyPowerUp(t, io, restart) {
  const frames = [];
  for (let i = 0; i < 2; i++) {
    t.sim.scramble();
    restart();
    frames.push(captureFrame(t, io));
  }
  t.ok(sameFrame(frames[0], frames[1]), 'After a reset, the picture still depends on what the registers held at power-up, so some register isn\'t set by the reset. On a real chip registers start with random values; reset every one of them (the frame counter is the usual one to miss).');
}

export function checkTiming(t, io = plain) {
  const sim = t.sim;
  const tick = () => sim.tick('clk');
  const lo = f => f(sim) === 0;
  let guard = 0;
  while (lo(io.hs) && guard++ < 2000) tick();
  while (!lo(io.hs) && guard++ < 4000) tick();
  if (guard >= 4000) t.fail('hsync never went low. It should pulse low for 96 clocks in every 800-clock line.');
  let width = 0;
  while (lo(io.hs) && width < 2000) { tick(); width++; }
  t.ok(width === 96, `The hsync pulse is ${width} clocks long; it should be 96.`);
  let period = width;
  while (!lo(io.hs) && period < 5000) { tick(); period++; }
  t.ok(period === 800, `hsync pulses are ${period} clocks apart; a line should be 800 clocks.`);
  guard = 0;
  while (lo(io.vs) && guard++ < 500000) tick();
  while (!lo(io.vs) && guard++ < 900000) tick();
  if (guard >= 900000) t.fail('vsync never went low. It should pulse low for 2 lines in every 525-line frame.');
  let vw = 0;
  while (lo(io.vs) && vw < 10000) { tick(); vw++; }
  t.ok(vw === 1600, `The vsync pulse is ${vw} clocks (${(vw / 800).toFixed(2)} lines); it should be exactly 2 lines (1600 clocks).`);
  let vp = vw;
  while (!lo(io.vs) && vp < 900000) { tick(); vp++; }
  t.ok(vp === 420000, `vsync pulses are ${vp} clocks apart; a frame is 800 × 525 = 420,000 clocks.`);
}

// Capture the next frame the way a monitor does. Colours are 6-bit rrggbb.
export function captureFrame(t, io = plain) {
  const sim = t.sim;
  const W = 640, H = 480;
  const px = new Uint8Array(W * H);
  const tick = () => sim.tick('clk');
  let guard = 0;
  while (io.vs(sim) === 0 && guard++ < 500000) tick();
  while (io.vs(sim) === 1 && guard++ < 900000) tick();
  if (guard >= 900000) t.fail('No vsync pulse, so the monitor never starts a frame. Check the timing first.');
  let x = 0, y = -(2 + 33), lastH = io.hs(sim), blankLit = 0;
  for (let i = 0; i < 420000; i++) {
    tick();
    const h = io.hs(sim);
    if (lastH === 1 && h === 0) { x = -(96 + 48); y++; }
    lastH = h;
    const c = io.rgb(sim);
    if (x >= 0 && x < W && y >= 0 && y < H) px[y * W + x] = c; else if (c) blankLit++;
    x++;
  }
  const colours = new Set(px).size;
  return { px, blankLit, colours, at: (xx, yy) => px[yy * W + xx] };
}

export function blankingIsBlack(t, f) {
  t.ok(f.blankLit === 0, `${f.blankLit} pixels were lit outside the visible 640×480 area. During blanking all colour outputs must be 0, or the monitor gets confused about what black is.`);
}

export const sameFrame = (a, b) => a.px.every((v, i) => v === b.px[i]);

// Icey wrapper for the plain shape: 25.125 MHz from the PLL, 2-bit colours
// spread over the 3/3/2 DAC, and SW2 / header pins for the optional inputs.
export function iceyWrap(src) {
  const has = p => new RegExp(`\\b${p}\\b`).test(src.slice(src.search(/\bmodule\s+top\b/)));
  const extra = [has('rst_n') && '.rst_n(BTN)', has('pause') && '.pause(P1)', has('effect') && '.effect(P2)'].filter(Boolean);
  return `${src.replace(/\bmodule\s+top\b/, 'module user_top')}

module top(
  input        BTN, P1, P2,
  output       HSYNC, VSYNC,
  output [2:0] VGA_R, VGA_G,
  output [1:0] VGA_B
);
  wire clk;
  ${CLOCKS.vga.code}
  wire [1:0] r, g, b;
  user_top u (.clk(clk), .hsync(HSYNC), .vsync(VSYNC), .r(r), .g(g), .b(b)${extra.map(e => ', ' + e).join('')});
  assign VGA_R = {r, r[1]};
  assign VGA_G = {g, g[1]};
  assign VGA_B = b;
endmodule
`;
}
