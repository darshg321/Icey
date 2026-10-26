import { clock, tt, iceyMonitor, checkTiming, captureFrame, blankingIsBlack, sameFrame, sameAfterAnyPowerUp } from '../vga.js';
import { noInitialValues } from '../checks.js';
import { COUNTER } from '../06-counter-module/exercises.js';
import { CORE_PORTS, CORE_BODY } from '../10-effects/exercises.js';

const TT_PORTS = `    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset`;

const ICEY_PORTS = `  input        clk,            // 25 MHz, from the PLL when built for Icey
  input        BTN,            // SW2: 0 while pressed -> rst_n
  input        P1, P2,         // header pins -> ui_in[0], ui_in[1]
  output       HSYNC, VSYNC,
  output [2:0] VGA_R, VGA_G,
  output [1:0] VGA_B`;

export const TT_WRAPPER = `module tt_um_vga_demo (
${TT_PORTS}
);
  wire hsync, vsync;
  wire [1:0] r, g, b;
  vga_core core (
    .clk(clk), .rst_n(rst_n), .pause(ui_in[0]), .effect(ui_in[1]),
    .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b)
  );

  // TinyVGA pinout
  assign uo_out  = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};
endmodule`;

// Resets the chip with ui_in = `ui`.
function start(t, ui) {
  t.sim.set('ena', 1); t.sim.set('uio_in', 0); t.sim.set('ui_in', ui);
  t.sim.set('rst_n', 0);
  for (let i = 0; i < 4; i++) t.sim.tick('clk');
  t.sim.set('rst_n', 1);
}

export default [
  {
    id: 'c11-tiny-tapeout',
    title: 'tt_um_vga_demo',
    prompt: 'Your session 10 module as `vga_core`, inside `tt_um_vga_demo` (TinyVGA pinout on `uo_out`), inside Icey\'s `top`.',
    carry: 'c10-effects',
    starter: `\`default_nettype none

${COUNTER}

module vga_core(
${CORE_PORTS}
);
  // your session 10 design, unchanged
endmodule

module tt_um_vga_demo (
${TT_PORTS}
);
  // one vga_core, connected to the Tiny Tapeout pins

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = 0;
  assign uio_out = 0;
  assign uio_oe  = 0;
endmodule

// Icey pretending to be the Tiny Tapeout board: it holds the "chip".
module top(
${ICEY_PORTS}
);
  // one tt_um_vga_demo, connected to Icey's pins
endmodule
`,
    solution: `\`default_nettype none

${COUNTER}

module vga_core(
${CORE_PORTS}
);
${CORE_BODY}
endmodule

${TT_WRAPPER}

// Icey pretending to be the Tiny Tapeout board: it holds the "chip".
module top(
${ICEY_PORTS}
);
  wire [7:0] uo, uio_out, uio_oe;
  tt_um_vga_demo chip (
    .ui_in({6'b0, P2, P1}), .uo_out(uo),
    .uio_in(8'b0), .uio_out(uio_out), .uio_oe(uio_oe),
    .ena(1'b1), .clk(clk), .rst_n(BTN)
  );

  assign HSYNC = uo[7];
  assign VSYNC = uo[3];
  assign VGA_R = {uo[0], uo[4], uo[0]};
  assign VGA_G = {uo[1], uo[5], uo[1]};
  assign VGA_B = {uo[2], uo[6]};
endmodule
`,
    board: [iceyMonitor, { type: 'icey' }],
    clock,
    iceyClock: 'vga',
    testTop: 'tt_um_vga_demo',
    extraTops: ['vga_core'],
    gates: false,
    tests: [
      { name: 'no starting values, only the reset', run(t) { noInitialValues(t); } },
      { name: 'the reset sets every register (random power-up state)', run(t) {
        sameAfterAnyPowerUp(t, tt, () => start(t, 0));
      } },
      { name: 'uo_out carries vga_core\'s outputs in the TinyVGA order', run(t) {
        const core = t.extra.vga_core;
        for (const [sim, inputs] of [[t.sim, { ena: 1, uio_in: 0, ui_in: 0 }], [core, { pause: 0, effect: 0 }]]) {
          for (const [k, v] of Object.entries(inputs)) sim.set(k, v);
          sim.set('rst_n', 0);
          for (let i = 0; i < 4; i++) sim.tick('clk');
          sim.set('rst_n', 1);
        }
        const names = ['R1', 'G1', 'B1', 'VSync', 'R0', 'G0', 'B0', 'HSync'];
        for (let i = 0; i < 2 * 420000; i++) {
          t.sim.tick('clk'); core.tick('clk');
          const r = core.get('r'), g = core.get('g'), b = core.get('b');
          const want = (core.get('hsync') << 7) | ((b & 1) << 6) | ((g & 1) << 5) | ((r & 1) << 4) |
                       (core.get('vsync') << 3) | ((b >> 1) << 2) | ((g >> 1) << 1) | (r >> 1);
          const got = t.sim.get('uo_out');
          if (got !== want) {
            const bit = [0, 1, 2, 3, 4, 5, 6, 7].find(n => ((got ^ want) >> n) & 1);
            t.fail(`uo_out[${bit}] should be ${names[bit]} (TinyVGA pinout), but it doesn't match vga_core's output. Check the order in assign uo_out = {...}: bit 7 comes first.`);
          }
        }
      } },
      { name: 'the bidirectional pins are unused inputs', run(t) {
        start(t, 0);
        for (let i = 0; i < 2000; i++) t.sim.tick('clk');
        t.ok(t.get('uio_oe') === 0, 'uio_oe should be 0: all the bidirectional pins are inputs.');
        t.ok(t.get('uio_out') === 0, 'uio_out should be 0.');
      } },
      { name: 'VGA timing on uo_out (TinyVGA pinout)', run(t) {
        start(t, 0);
        checkTiming(t, tt);
      } },
      { name: 'picture, pause (ui_in[0]) and effect (ui_in[1])', run(t) {
        start(t, 0);
        const a = captureFrame(t, tt), b = captureFrame(t, tt);
        blankingIsBlack(t, b);
        t.ok(b.colours >= 8, `The frame has ${b.colours} colours, read through the TinyVGA pinout.`);
        t.ok(!sameFrame(a, b), 'With ui_in = 0 the picture should move.');
        t.sim.set('ui_in', 1);
        captureFrame(t, tt);
        const c = captureFrame(t, tt), d = captureFrame(t, tt);
        t.ok(sameFrame(c, d), 'With ui_in[0] = 1 (pause) the picture should hold still.');
        t.sim.set('ui_in', 3);
        const e = captureFrame(t, tt);
        t.ok(!sameFrame(d, e), 'ui_in[1] (effect) should switch to the other picture.');
      } },
    ],
  },
];
