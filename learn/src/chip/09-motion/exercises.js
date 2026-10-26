import { clock, monitor, reset, captureFrame, blankingIsBlack, sameFrame, iceyWrap } from '../vga.js';
import { COUNTER } from '../06-counter-module/exercises.js';
import { VGA_PORTS, BEAM, OUTPUTS, resetButton, vgaChecks } from '../07-sync/exercises.js';

export const FRAME = `  reg [7:0] frame;
  always @(posedge clk)
    if (!rst_n) frame <= 0;
    else if (x == 0 && y == 480 && !pause) frame <= frame + 1;`;

const PORTS = `${VGA_PORTS},
  input        pause    // 1 = freeze`;

export const restartWith = inputs => t => { for (const [k, v] of Object.entries(inputs)) t.sim.set(k, v); reset(t); };

export default [
  {
    id: 'c9-motion',
    title: 'Moving pattern, with pause',
    prompt: 'A frame counter (reset to 0, +1 once per frame) used in your pattern, and a `pause` input that stops it.',
    carry: 'c8-pixels',
    starter: `${COUNTER}

module top(
${PORTS}
);
${BEAM}

  // add a frame counter, and use it below
  wire [5:0] colour = x[8:3] ^ y[8:3];

${OUTPUTS}
endmodule
`,
    solution: `${COUNTER}

module top(
${PORTS}
);
${BEAM}

${FRAME}

  wire [9:0] sx = x + {frame, 1'b0};
  wire [5:0] colour = sx[8:3] ^ y[8:3];

${OUTPUTS}
endmodule
`,
    board: [monitor, resetButton, { type: 'switches', port: 'pause', label: 'pause' }],
    clock,
    iceyWrap,
    gates: false,
    tests: [
      ...vgaChecks(restartWith({ pause: 0 })),
      { name: 'it moves, and pause freezes it', run(t) {
        restartWith({ pause: 0 })(t);
        const a = captureFrame(t), b = captureFrame(t);
        blankingIsBlack(t, b);
        t.ok(b.colours >= 8, `The frame has ${b.colours} colours; keep at least 8.`);
        t.ok(!sameFrame(a, b), 'With pause = 0, two frames in a row are identical: use the frame counter in your colour.');
        t.sim.set('pause', 1);
        captureFrame(t);
        const c = captureFrame(t), d = captureFrame(t);
        t.ok(sameFrame(c, d), 'With pause = 1 the picture still changes: stop the frame counter while paused.');
      } },
    ],
  },
];
