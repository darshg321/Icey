import { clock, monitor, reset, checkTiming, captureFrame, blankingIsBlack, sameAfterAnyPowerUp, plain, iceyWrap } from '../vga.js';
import { noInitialValues } from '../checks.js';
import { COUNTER } from '../06-counter-module/exercises.js';

export const VGA_PORTS = `  input        clk,     // 25.175 MHz pixel clock
  input        rst_n,   // 0 = reset
  output       hsync,
  output       vsync,
  output [1:0] r,       // 2 bits per colour
  output [1:0] g,
  output [1:0] b`;

// The beam: x and y from two counters (session 6's module).
export const BEAM = `  wire [9:0] x, y;
  wire x_wrap, y_wrap;
  counter #(.MAX(800)) xcount (.clk(clk), .rst_n(rst_n), .en(1'b1), .value(x), .wrap(x_wrap));
  counter #(.MAX(525)) ycount (.clk(clk), .rst_n(rst_n), .en(x_wrap), .value(y), .wrap(y_wrap));
  wire visible = (x < 640) && (y < 480);`;

// Registered outputs from a 6-bit `colour`.
export const OUTPUTS = `  reg hs, vs;
  reg [5:0] rgb;
  always @(posedge clk) begin
    if (!rst_n) begin
      hs <= 1;
      vs <= 1;
      rgb <= 0;
    end else begin
      hs  <= ~(x >= 656 && x < 752);
      vs  <= ~(y >= 490 && y < 492);
      rgb <= visible ? colour : 6'd0;
    end
  end
  assign hsync = hs;
  assign vsync = vs;
  assign {r, g, b} = rgb;`;

export const resetButton = { type: 'button', port: 'rst_n', label: 'rst_n (reset)', activeLow: true };

export const vgaChecks = (restart = reset) => [
  { name: 'no starting values, only the reset', run(t) { noInitialValues(t); } },
  { name: 'the reset sets every register (random power-up state)', run(t) { sameAfterAnyPowerUp(t, plain, () => restart(t)); } },
  { name: 'sync timing matches the VGA standard', run(t) { restart(t); checkTiming(t); } },
];

export default [
  {
    id: 'c7-sync',
    title: 'Half red, half blue',
    prompt: '640×480 VGA timing from your counters. Left half full red, right half full blue, black outside the visible area.',
    carry: 'c6-counters',
    starter: `${COUNTER.replace(/\n  assign wrap[\s\S]*?\nendmodule/, '\n  // your counter from session 6\nendmodule')}

module top(
${VGA_PORTS}
);
  // x: 0..799, y: 0..524, then hsync, vsync and the colours
  assign hsync = 1;
  assign vsync = 1;
  assign r = 0;
  assign g = 0;
  assign b = 0;
endmodule
`,
    solution: `${COUNTER}

module top(
${VGA_PORTS}
);
${BEAM}

  wire [5:0] colour = (x < 320) ? 6'b110000 : 6'b000011;

${OUTPUTS}
endmodule
`,
    board: [monitor, resetButton],
    clock,
    iceyWrap,
    gates: false,
    tests: [
      ...vgaChecks(),
      { name: 'red on the left, blue on the right, black blanking', run(t) {
        reset(t);
        const f = captureFrame(t);
        blankingIsBlack(t, f);
        t.ok(f.at(0, 0) === 0b110000 && f.at(319, 240) === 0b110000, 'The left half (x = 0 to 319) should be full red: r = 3, g = 0, b = 0. If it\'s shifted, check the picture starts 144 clocks after hsync falls (96 sync + 48 back porch).');
        t.ok(f.at(320, 240) === 0b000011 && f.at(639, 479) === 0b000011, 'The right half (x = 320 to 639) should be full blue: r = 0, g = 0, b = 3.');
      } },
    ],
  },
];
