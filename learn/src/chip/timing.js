// Verilog snippets shared by the VGA days' starters and solutions.
export const TABLE = `  // 640x480 at 60 Hz, 25.175 MHz pixel clock
  //              visible  front porch  sync  back porch  total
  // horizontal     640        16        96       48       800
  // vertical       480        10         2       33       525
  // Both sync pulses are active low (0 during the pulse).`;

// Days 10-11: a working timing generator to build on.
export const COUNTERS = `  reg [9:0] x = 0, y = 0;
  always @(posedge clk) begin
    if (x == 799) begin
      x <= 0;
      y <= (y == 524) ? 10'd0 : y + 1;
    end else
      x <= x + 1;
  end
  wire visible = (x < 640) && (y < 480);`;

// Registered outputs: everything is delayed by one clock together.
export const OUTPUTS = `  reg hs = 1, vs = 1;
  reg [5:0] rgb = 0;
  always @(posedge clk) begin
    hs  <= ~(x >= 656 && x < 752);
    vs  <= ~(y >= 490 && y < 492);
    rgb <= visible ? colour : 6'd0;
  end
  assign hsync = hs;
  assign vsync = vs;
  assign {r, g, b} = rgb;`;

export const PORTS = `  input        clk,     // 25.175 MHz pixel clock
  output       hsync,
  output       vsync,
  output [1:0] r,       // 2 bits per colour, like Tiny Tapeout's VGA board
  output [1:0] g,
  output [1:0] b`;
