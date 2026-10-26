import { clock, monitor, reset, captureFrame, blankingIsBlack, iceyWrap } from '../vga.js';
import { COUNTER } from '../06-counter-module/exercises.js';
import { VGA_PORTS, BEAM, OUTPUTS, resetButton, vgaChecks } from '../07-sync/exercises.js';

export default [
  {
    id: 'c8-pixels',
    title: 'A pattern of your own',
    prompt: 'Compute `colour` from `x` and `y`: any pattern with at least 8 different colours.',
    carry: 'c7-sync',
    starter: `${COUNTER}

module top(
${VGA_PORTS}
);
${BEAM}

  // your pattern: {r[1:0], g[1:0], b[1:0]} from x and y
  wire [5:0] colour = (x < 320) ? 6'b110000 : 6'b000011;

${OUTPUTS}
endmodule
`,
    solution: `${COUNTER}

module top(
${VGA_PORTS}
);
${BEAM}

  wire [5:0] colour = x[8:3] ^ y[8:3];

${OUTPUTS}
endmodule
`,
    board: [monitor, resetButton],
    clock,
    iceyWrap,
    gates: false,
    tests: [
      ...vgaChecks(),
      { name: 'at least 8 colours, black blanking', run(t) {
        reset(t);
        const f = captureFrame(t);
        blankingIsBlack(t, f);
        t.ok(f.colours >= 8, `The frame has ${f.colours} different colour${f.colours === 1 ? '' : 's'}; make a pattern with at least 8.`);
      } },
    ],
  },
];
