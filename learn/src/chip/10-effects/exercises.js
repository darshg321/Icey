import { clock, monitor, captureFrame, blankingIsBlack, sameFrame, iceyWrap } from '../vga.js';
import { COUNTER } from '../06-counter-module/exercises.js';
import { VGA_PORTS, BEAM, OUTPUTS, resetButton, vgaChecks } from '../07-sync/exercises.js';
import { FRAME, restartWith } from '../09-motion/exercises.js';

export const CORE_PORTS = `${VGA_PORTS},
  input        pause,   // 1 = freeze
  input        effect   // picks the picture`;

// The finished core of the chip (the body of session 10's module).
export const CORE_BODY = `${BEAM}

${FRAME}

  wire [9:0] sx = x + {frame, 1'b0};
  wire [9:0] sy = y + frame;
  wire [5:0] xor_pattern = sx[8:3] ^ y[8:3];
  wire [5:0] diagonals = sx[8:3] + sy[8:3];
  wire [5:0] colour = effect ? diagonals : xor_pattern;

${OUTPUTS}`;

export default [
  {
    id: 'c10-effects',
    title: 'Two effects',
    prompt: 'An `effect` input that switches to a second, different moving pattern.',
    carry: 'c9-motion',
    starter: `${COUNTER}

module top(
${CORE_PORTS}
);
${BEAM}

${FRAME}

  // a second pattern, chosen by effect
  wire [9:0] sx = x + {frame, 1'b0};
  wire [5:0] colour = sx[8:3] ^ y[8:3];

${OUTPUTS}
endmodule
`,
    solution: `${COUNTER}

module top(
${CORE_PORTS}
);
${CORE_BODY}
endmodule
`,
    board: [monitor, resetButton, { type: 'switches', port: 'pause', label: 'pause' }, { type: 'switches', port: 'effect', label: 'effect' }],
    clock,
    iceyWrap,
    gates: false,
    tests: [
      ...vgaChecks(restartWith({ pause: 0, effect: 0 })),
      { name: 'both effects move, and pause freezes them', run(t) {
        for (const effect of [0, 1]) {
          restartWith({ pause: 0, effect })(t);
          const a = captureFrame(t), b = captureFrame(t);
          blankingIsBlack(t, b);
          t.ok(b.colours >= 8, `Effect ${effect} has ${b.colours} colours; keep at least 8.`);
          t.ok(!sameFrame(a, b), `Effect ${effect} doesn't move.`);
          t.sim.set('pause', 1);
          captureFrame(t);
          t.ok(sameFrame(captureFrame(t), captureFrame(t)), `Effect ${effect} still moves while paused.`);
        }
      } },
      { name: 'effect switches to a different picture', run(t) {
        restartWith({ pause: 1, effect: 0 })(t);
        captureFrame(t);
        const a = captureFrame(t);
        t.sim.set('effect', 1);
        const b = captureFrame(t);
        t.ok(!sameFrame(a, b), 'effect = 1 shows the same picture as effect = 0.');
      } },
    ],
  },
];
