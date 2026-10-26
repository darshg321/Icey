import { fmax, used } from '../../engine/flow.js';

const clock = { port: 'clk', hz: 25.175e6 };
const PORTS = `  input        clk,
  output       HSYNC,
  output       VSYNC,
  output [2:0] VGA_R,
  output [2:0] VGA_G,
  output [1:0] VGA_B`;
const COMMON = `  reg [9:0] h = 0, v = 0;
  always @(posedge clk) begin
    if (h == 799) begin h <= 0; v <= (v == 524) ? 10'd0 : v + 1; end
    else h <= h + 1;
  end
  wire visible = (h < 640) && (v < 480);

  // t moves the two circles a little every frame
  reg [9:0] t = 0;
  always @(posedge clk) if (h == 0 && v == 480) t <= t + 1;`;

const SLOW = `module top(
${PORTS}
);
${COMMON}

  // distance (squared) from two moving centres
  wire signed [10:0] dx1 = h - 200 - t, dy1 = v - 240;
  wire signed [10:0] dx2 = h - 440 + t, dy2 = v - 200 - t[8:1];
  wire [21:0] d1 = dx1*dx1 + dy1*dy1;
  wire [21:0] d2 = dx2*dx2 + dy2*dy2;
  wire [7:0] c = d1[14:7] + d2[14:7];

  reg hs = 1, vs = 1;
  reg [7:0] rgb = 0;
  always @(posedge clk) begin
    hs  <= ~(h >= 656 && h < 752);
    vs  <= ~(v >= 490 && v < 492);
    rgb <= visible ? c : 8'd0;
  end
  assign HSYNC = hs;
  assign VSYNC = vs;
  assign VGA_R = rgb[7:5];
  assign VGA_G = rgb[4:2];
  assign VGA_B = rgb[1:0];
endmodule
`;

const FAST = `module top(
${PORTS}
);
${COMMON}

  // stage 1: differences
  reg signed [10:0] dx1 = 0, dy1 = 0, dx2 = 0, dy2 = 0;
  // stage 2: squares
  reg [21:0] sx1 = 0, sy1 = 0, sx2 = 0, sy2 = 0;
  // stage 3: sums
  reg [21:0] d1 = 0, d2 = 0;
  // stage 4: colour
  reg [7:0] c = 0;
  // the sync and visible signals travel through the same number of stages
  reg [3:0] vis_d = 0, hs_d = 4'hf, vs_d = 4'hf;

  always @(posedge clk) begin
    dx1 <= h - 200 - t;  dy1 <= v - 240;
    dx2 <= h - 440 + t;  dy2 <= v - 200 - t[8:1];
    sx1 <= dx1*dx1;  sy1 <= dy1*dy1;  sx2 <= dx2*dx2;  sy2 <= dy2*dy2;
    d1  <= sx1 + sy1;  d2 <= sx2 + sy2;
    c   <= d1[14:7] + d2[14:7];
    vis_d <= {vis_d[2:0], visible};
    hs_d  <= {hs_d[2:0], ~(h >= 656 && h < 752)};
    vs_d  <= {vs_d[2:0], ~(v >= 490 && v < 492)};
  end

  reg hs = 1, vs = 1;
  reg [7:0] rgb = 0;
  always @(posedge clk) begin
    hs  <= hs_d[3];
    vs  <= vs_d[3];
    rgb <= vis_d[3] ? c : 8'd0;
  end
  assign HSYNC = hs;
  assign VSYNC = vs;
  assign VGA_R = rgb[7:5];
  assign VGA_G = rgb[4:2];
  assign VGA_B = rgb[1:0];
endmodule
`;

// The picture the design should draw for frame counter tt.
function refPixel(x, y, tt) {
  const s11 = n => { n &= 0x7ff; return n >= 1024 ? n - 2048 : n; };
  const dx1 = s11(x - 200 - tt), dy1 = s11(y - 240), dx2 = s11(x - 440 + tt), dy2 = s11(y - 200 - (tt >> 1));
  const d1 = (dx1 * dx1 + dy1 * dy1) & 0x3fffff, d2 = (dx2 * dx2 + dy2 * dy2) & 0x3fffff;
  return (((d1 >> 7) & 255) + ((d2 >> 7) & 255)) & 255;
}

// Capture a frame as a monitor would and compare it to the reference,
// trying small horizontal shifts to explain a misaligned pipeline.
function checkPicture(t) {
  const sim = t.sim;
  let guard = 0;
  while (sim.get('VSYNC') === 0 && guard++ < 500000) sim.tick('clk');
  while (sim.get('VSYNC') === 1 && guard++ < 900000) sim.tick('clk');
  if (guard >= 900000) t.fail('No VSYNC pulses, so a monitor would show nothing.');
  const tt = sim.get('t');
  const img = new Int16Array(640 * 480).fill(-1);
  let x = 0, y = -(2 + 33), lastH = sim.get('HSYNC'), blank = 0;
  for (let i = 0; i < 420000; i++) {
    sim.tick('clk');
    const H = sim.get('HSYNC');
    if (lastH === 1 && H === 0) { x = -(96 + 48); y++; }
    lastH = H;
    const c = (sim.get('VGA_R') << 5) | (sim.get('VGA_G') << 2) | sim.get('VGA_B');
    if (x >= 0 && x < 640 && y >= 0 && y < 480) img[y * 640 + x] = c; else if (c) blank++;
    x++;
  }
  const errs = shift => {
    let e = 0;
    for (let yy = 0; yy < 480; yy += 7) for (let xx = 20; xx < 620; xx += 3) if (img[yy * 640 + xx] !== refPixel(xx + shift, yy, tt)) e++;
    return e;
  };
  if (errs(0) === 0) { t.ok(blank === 0, `${blank} pixels were lit during blanking. The visible flag has to go through the pipeline too.`); return; }
  let best = 0, bestE = Infinity;
  for (let s = -8; s <= 8; s++) { const e = errs(s); if (e < bestE) { bestE = e; best = s; } }
  if (bestE === 0) t.fail(`The picture is right but shifted ${Math.abs(best)} pixel${Math.abs(best) > 1 ? 's' : ''} to the ${best > 0 ? 'left' : 'right'}. The colour comes out ${Math.abs(best)} clock${Math.abs(best) > 1 ? 's' : ''} ${best > 0 ? 'earlier' : 'later'} than the sync signals: delay ${best > 0 ? 'the colour' : 'HSYNC, VSYNC and visible'} by that many stages.`);
  t.fail('The picture doesn\'t match the reference. Check each pipeline stage computes the same thing as the original expressions.');
}

export default [
  {
    id: 'pipeline',
    title: 'Pipeline it',
    prompt: 'This design draws the right picture but only reaches about 21 MHz on the chip without hardware multipliers. Split the calculation into pipeline stages, keep the picture lined up, and get Fmax above 25.2 MHz.',
    starter: SLOW,
    solution: FAST,
    starterPasses: true,
    board: [{ type: 'vga', hsync: 'HSYNC', vsync: 'VSYNC', r: 'VGA_R', g: 'VGA_G', b: 'VGA_B' }],
    clock,
    iceyClock: 'vga',
    iceyDsp: false,
    gates: false,
    tests: [{ name: 'draws the same picture, lined up with the sync', run(t) { checkPicture(t); } }],
    chipTests: [
      { name: 'fast enough for a 25.175 MHz pixel clock', check: r => fmax(r) >= 25.2 ? null : `Max frequency is ${fmax(r).toFixed(1)} MHz; it needs to be at least 25.2. Look at the red line in the chip view: that's the path to break up.` },
    ],
  },
  {
    id: 'dsp',
    title: 'Use the hardware multipliers',
    prompt: 'Same design, built with `-dsp` this time, so the four multiplications go into the iCE40\'s DSP blocks. Paste in your pipelined version and build.',
    starter: SLOW,
    solution: FAST,
    starterPasses: true,
    board: [{ type: 'vga', hsync: 'HSYNC', vsync: 'VSYNC', r: 'VGA_R', g: 'VGA_G', b: 'VGA_B' }],
    clock,
    iceyClock: 'vga',
    gates: false,
    tests: [{ name: 'draws the same picture, lined up with the sync', run(t) { checkPicture(t); } }],
    chipTests: [
      { name: 'uses the DSP blocks', check: r => used(r, 'ICESTORM_DSP') >= 4 ? null : `Only ${used(r, 'ICESTORM_DSP')} DSP blocks used; there are four multiplications.` },
      { name: 'comfortably fast', check: r => fmax(r) >= 40 ? null : `Max frequency ${fmax(r).toFixed(1)} MHz.` },
    ],
  },
];
