const clock = { port: 'clk', hz: 25.175e6 };
const PORTS = `  input        clk,       // 25 MHz pixel clock
  output       HSYNC,
  output       VSYNC,
  output [2:0] VGA_R,
  output [2:0] VGA_G,
  output [1:0] VGA_B`;
const monitor = [{ type: 'vga', hsync: 'HSYNC', vsync: 'VSYNC', r: 'VGA_R', g: 'VGA_G', b: 'VGA_B' }];

const TIMING = `  // 640x480 @ 60 Hz: 800 clocks per line, 525 lines per frame
  reg [9:0] h = 0, v = 0;
  always @(posedge clk) begin
    if (h == 799) begin
      h <= 0;
      v <= (v == 524) ? 10'd0 : v + 1;
    end else
      h <= h + 1;
  end
  wire visible = (h < 640) && (v < 480);`;

// Watch the sync outputs for a while and check them against the VGA spec.
function checkTiming(t) {
  const sim = t.sim;
  const lo = n => sim.get(n) === 0;
  // find an hsync falling edge
  let guard = 0;
  while (lo('HSYNC') && guard++ < 2000) sim.tick('clk');
  while (!lo('HSYNC') && guard++ < 4000) sim.tick('clk');
  if (guard >= 4000) t.fail('HSYNC never went low. It should pulse low for 96 clocks in every 800-clock line.');
  let width = 0;
  while (lo('HSYNC') && width < 2000) { sim.tick('clk'); width++; }
  t.ok(width === 96, `The HSYNC pulse is ${width} clocks long; it should be 96.`);
  let period = width;
  while (!lo('HSYNC') && period < 5000) { sim.tick('clk'); period++; }
  t.ok(period === 800, `HSYNC pulses are ${period} clocks apart; a line should be 800 clocks.`);
  // vsync
  guard = 0;
  while (lo('VSYNC') && guard++ < 500000) sim.tick('clk');
  while (!lo('VSYNC') && guard++ < 900000) sim.tick('clk');
  if (guard >= 900000) t.fail('VSYNC never went low. It should pulse low for 2 lines in every 525-line frame.');
  let vw = 0;
  while (lo('VSYNC') && vw < 10000) { sim.tick('clk'); vw++; }
  t.ok(vw === 1600, `The VSYNC pulse is ${vw} clocks (${(vw / 800).toFixed(2)} lines); it should be exactly 2 lines (1600 clocks).`);
  let vp = vw;
  while (!lo('VSYNC') && vp < 900000) { sim.tick('clk'); vp++; }
  t.ok(vp === 420000, `VSYNC pulses are ${vp} clocks apart; a frame is 800 × 525 = 420,000 clocks.`);
}

// Capture one frame the way a monitor does: returns {pixel(x,y), blankingLit}
function captureFrame(t) {
  const sim = t.sim;
  const W = 640, H = 480;
  const px = new Uint8Array(W * H);
  let guard = 0;
  while (sim.get('VSYNC') === 0 && guard++ < 500000) sim.tick('clk');
  while (sim.get('VSYNC') === 1 && guard++ < 900000) sim.tick('clk');
  let x = 0, y = -(2 + 33), lastH = sim.get('HSYNC'), blankLit = 0;
  for (let i = 0; i < 420000; i++) {
    sim.tick('clk');
    const H_ = sim.get('HSYNC');
    if (lastH === 1 && H_ === 0) { x = -(96 + 48); y++; }
    lastH = H_;
    const c = (sim.get('VGA_R') << 5) | (sim.get('VGA_G') << 2) | sim.get('VGA_B');
    if (x >= 0 && x < W && y >= 0 && y < H) px[y * W + x] = c; else if (c) blankLit++;
    x++;
  }
  return { px, blankLit, at: (xx, yy) => px[yy * W + xx] };
}

function bbox(f, pred) {
  let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
  for (let y = 0; y < 480; y++) for (let x = 0; x < 640; x++) if (pred(f.at(x, y))) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  return x1 < 0 ? null : { x0, y0, x1, y1, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}

export default [
  {
    id: 'vga-timing',
    title: 'Colour bars',
    prompt: 'Generate 640×480 VGA timing and draw vertical colour bars, 64 pixels wide, starting with white on the left: colour = `~h[8:6]`. Black outside the visible area.',
    starter: `module top(
${PORTS}
);
${TIMING}

  wire [2:0] bar = ~h[8:6];

  assign HSYNC = 1;
  assign VSYNC = 1;
  assign VGA_R = 0;
  assign VGA_G = 0;
  assign VGA_B = 0;
endmodule
`,
    solution: `module top(
${PORTS}
);
${TIMING}

  wire [2:0] bar = ~h[8:6];

  reg hs = 1, vs = 1;
  reg [2:0] r = 0, g = 0;
  reg [1:0] b = 0;
  always @(posedge clk) begin
    hs <= ~(h >= 656 && h < 752);
    vs <= ~(v >= 490 && v < 492);
    r  <= visible ? {3{bar[2]}} : 3'd0;
    g  <= visible ? {3{bar[1]}} : 3'd0;
    b  <= visible ? {2{bar[0]}} : 2'd0;
  end

  assign HSYNC = hs;
  assign VSYNC = vs;
  assign VGA_R = r;
  assign VGA_G = g;
  assign VGA_B = b;
endmodule
`,
    board: monitor,
    clock,
    iceyClock: 'vga',
    gates: false,
    tests: [
      { name: 'sync timing matches the VGA standard', run(t) { checkTiming(t); } },
      { name: 'the picture lines up and blanking is black', run(t) {
        const f = captureFrame(t);
        t.ok(f.blankLit === 0, `${f.blankLit} pixels were lit outside the visible 640×480 area. During blanking the colour outputs must be 0, or the monitor gets confused about what black is.`);
        t.ok(f.at(0, 0) === 255 && f.at(63, 240) === 255, 'The first 64 pixels of each line should be white. If the bars are shifted, check that the picture starts 144 clocks after HSYNC falls (96 sync + 48 back porch).');
        t.ok(f.at(64, 100) !== 255 && f.at(639, 479) !== undefined, 'The second bar should start at x = 64.');
        t.ok(f.at(64 * 7, 300) === 0, 'The eighth bar (x = 448) should be black.');
      } },
    ],
  },
  {
    id: 'bounce',
    project: true,
    title: 'The bouncing square',
    prompt: 'A 32×32 square moving 2 pixels per frame in x and y, bouncing off the edges of the screen, on a black background. Change its colour every time it hits a wall.',
    starter: `module top(
${PORTS}
);
${TIMING}

  // position of the square's top-left corner
  reg [9:0] sx = 100, sy = 60;
  reg dx = 1, dy = 1;            // 1 = moving right / down
  reg [7:0] colour = 8'b111_000_00;

  // move once per frame, while the beam is in the blanking area
  wire frame_tick = (h == 0) && (v == 480);

  assign HSYNC = 1;
  assign VSYNC = 1;
  assign VGA_R = 0;
  assign VGA_G = 0;
  assign VGA_B = 0;
endmodule
`,
    solution: `module top(
${PORTS}
);
${TIMING}

  reg [9:0] sx = 100, sy = 60;
  reg dx = 1, dy = 1;
  reg [7:0] colour = 8'b111_000_00;
  wire frame_tick = (h == 0) && (v == 480);

  always @(posedge clk) begin
    if (frame_tick) begin
      if (dx) begin
        if (sx >= 640 - 32 - 2) begin dx <= 0; colour <= colour + 8'b001_011_01; end
        else sx <= sx + 2;
      end else begin
        if (sx <= 2) begin dx <= 1; colour <= colour + 8'b001_011_01; end
        else sx <= sx - 2;
      end
      if (dy) begin
        if (sy >= 480 - 32 - 2) begin dy <= 0; colour <= colour + 8'b011_001_10; end
        else sy <= sy + 2;
      end else begin
        if (sy <= 2) begin dy <= 1; colour <= colour + 8'b011_001_10; end
        else sy <= sy - 2;
      end
    end
  end

  wire in_square = (h >= sx) && (h < sx + 32) && (v >= sy) && (v < sy + 32);

  reg hs = 1, vs = 1;
  reg [7:0] rgb = 0;
  always @(posedge clk) begin
    hs  <= ~(h >= 656 && h < 752);
    vs  <= ~(v >= 490 && v < 492);
    rgb <= (visible && in_square) ? (colour | 8'b001_001_01) : 8'd0;
  end

  assign HSYNC = hs;
  assign VSYNC = vs;
  assign VGA_R = rgb[7:5];
  assign VGA_G = rgb[4:2];
  assign VGA_B = rgb[1:0];
endmodule
`,
    board: monitor,
    clock,
    iceyClock: 'vga',
    gates: false,
    tests: [
      { name: 'sync timing matches the VGA standard', run(t) { checkTiming(t); } },
      { name: 'a 32×32 square that moves', run(t) {
        const a = bbox(captureFrame(t), c => c !== 0);
        t.ok(a, 'Nothing was drawn: every visible pixel was black.');
        t.ok(a.w === 32 && a.h === 32, `The lit area is ${a.w}×${a.h} pixels; the square should be 32×32.`);
        const b = bbox(captureFrame(t), c => c !== 0);
        t.ok(b && (b.x0 !== a.x0 || b.y0 !== a.y0), 'The square didn\'t move between two frames.');
        t.ok(b && Math.abs(b.x0 - a.x0) <= 4 && Math.abs(b.y0 - a.y0) <= 4, `The square jumped from (${a.x0}, ${a.y0}) to (${b?.x0}, ${b?.y0}) in one frame; it should move 2 pixels.`);
      } },
    ],
  },
];
