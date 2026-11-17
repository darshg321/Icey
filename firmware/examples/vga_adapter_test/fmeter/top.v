// frequency meter: counts FLASH_SCK edges per ~1 s of HFOSC/4 (12 MHz), prints hex over UART 115200
module top(input FLASH_SCK, output TX, output LED);
  wire clk;
  SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));
  reg [31:0] cnt = 0;
  always @(posedge FLASH_SCK) cnt <= cnt + 1;
  wire [31:0] g = cnt ^ (cnt >> 1);
  reg [31:0] gq = 0; always @(posedge FLASH_SCK) gq <= g;
  reg [31:0] s1 = 0, s2 = 0;
  always @(posedge clk) begin s1 <= gq; s2 <= s1; end
  reg [31:0] bin; integer i;
  always @* begin bin[31] = s2[31]; for (i = 30; i >= 0; i = i - 1) bin[i] = bin[i+1] ^ s2[i]; end
  reg [23:0] t = 0; reg [31:0] last = 0, delta = 0; reg go = 0;
  always @(posedge clk) begin
    go <= 0;
    if (t == 24'd11999999) begin t <= 0; delta <= bin - last; last <= bin; go <= 1; end
    else t <= t + 1;
  end
  assign LED = t[23];
  // uart tx: 9 chars (8 hex + \n)
  reg [6:0] bd = 0; reg [3:0] bit = 0; reg [3:0] ch = 9; reg [9:0] sh = 10'h3ff; reg [31:0] d = 0;
  wire [3:0] nib = d[31:28];
  wire [7:0] hex = nib < 10 ? "0" + nib : "a" + nib - 10;
  always @(posedge clk) begin
    if (go) begin d <= delta; ch <= 0; bit <= 0; bd <= 0; end
    else if (ch < 9 || bit != 0) begin
      if (bd == 103) begin
        bd <= 0;
        if (bit == 0) begin
          if (ch < 9) begin sh <= {1'b1, (ch == 8 ? 8'h0a : hex), 1'b0}; bit <= 10; ch <= ch + 1; if (ch < 8) d <= d << 4; end
        end else begin sh <= {1'b1, sh[9:1]}; bit <= bit - 1; end
      end else bd <= bd + 1;
    end
  end
  assign TX = sh[0];
endmodule
