// Icey blink: LED1 blinks, RGB LED cycles R/G/B/off. Clock: internal 12 MHz HFOSC.
module top(output LED, output RGB0, output RGB1, output RGB2);
  wire clk;
  SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));

  reg [25:0] c = 0;
  always @(posedge clk) c <= c + 1;
  assign LED = c[23];

  SB_RGBA_DRV #(.CURRENT_MODE("0b1"), .RGB0_CURRENT("0b000001"),
                .RGB1_CURRENT("0b000001"), .RGB2_CURRENT("0b000001")) rgb (
    .CURREN(1'b1), .RGBLEDEN(1'b1),
    .RGB0PWM(c[25:24] == 2'd1), .RGB1PWM(c[25:24] == 2'd2), .RGB2PWM(c[25:24] == 2'd3),
    .RGB0(RGB0), .RGB1(RGB1), .RGB2(RGB2));
endmodule
