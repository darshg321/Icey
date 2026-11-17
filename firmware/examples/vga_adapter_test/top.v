// VGA adapter test: static colour bars with a white border, for checking
// whether a VGA-to-HDMI converter can lock onto Icey's signal.
// LED1 blinks about once a second while the design is running.
//
//   make prog                  top_pll:   HFOSC 48 MHz -> PLL -> ~25.1 MHz, 800x525 (same as the demos)
//   make TOP=top_nopll prog    top_nopll: HFOSC/2 = 24 MHz, no PLL, 762x525.
//                              Line and frame rates land on spec (31.5 kHz / 60 Hz);
//                              the picture is 610 pixels wide over the standard 25.4 us.
//   make TOP=top_svga prog     top_svga:  800x600@60 (1056x628, positive syncs), PLL -> ~39.75 MHz,
//                              for converters that don't take 640x480.
//   make TOP=top_ext && ./extclk.py top_ext.bin
//                              top_ext:   640x480 from a crystal-derived clock instead of the
//                              HFOSC: extclk.py makes the FT2232H free-run a clock (15 MHz measured) on the
//                              flash SCK line (pin 15) -> PLL -> 25.3125 MHz.

module bars #(
    parameter HACT = 640, HFP = 16, HSW = 96, HTOT = 800,
    parameter VACT = 480, VFP = 10, VSW = 2, VTOT = 525,
    parameter POS = 0      // 1 = positive sync pulses
) (
    input clk,
    output reg hsync, vsync,
    output reg [2:0] r, g,
    output reg [1:0] b,
    output led
);
    initial begin hsync = 1; vsync = 1; r = 0; g = 0; b = 0; end
    reg [10:0] hc = 0, vc = 0;
    reg [5:0] frame = 0;
    always @(posedge clk) begin
        if (hc == HTOT - 1) begin
            hc <= 0;
            if (vc == VTOT - 1) begin vc <= 0; frame <= frame + 1; end
            else vc <= vc + 1;
        end else hc <= hc + 1;
    end
    wire de     = (hc < HACT) && (vc < VACT);
    wire border = (hc < 2) || (hc >= HACT - 2) || (vc < 2) || (vc >= VACT - 2);
    // 8 bars: white yellow cyan green magenta red blue black
    localparam BARW = HACT / 8;
    reg [6:0] sub = 0;
    reg [2:0] bar = 7;
    always @(posedge clk) begin
        if (hc == HTOT - 1) begin sub <= 0; bar <= 7; end
        else if (sub == BARW - 1) begin sub <= 0; bar <= bar - 1; end
        else sub <= sub + 1;
    end
    always @(posedge clk) begin
        hsync <= (hc >= HACT + HFP && hc < HACT + HFP + HSW) ^ !POS;
        vsync <= (vc >= VACT + VFP && vc < VACT + VFP + VSW) ^ !POS;
        r <= !de ? 3'd0 : border ? 3'd7 : {3{bar[1]}};
        g <= !de ? 3'd0 : border ? 3'd7 : {3{bar[2]}};
        b <= !de ? 2'd0 : border ? 2'd3 : {2{bar[0]}};
    end
    assign led = frame[5];
endmodule

module top_pll (
    output HSYNC, VSYNC, output [2:0] VGA_R, VGA_G, output [1:0] VGA_B, output LED
);
    wire hf, clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(hf));
    SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"), .DIVR(4'b0011),
        .DIVF(7'b1000010), .DIVQ(3'b101), .FILTER_RANGE(3'b001)) pll (
        .REFERENCECLK(hf), .PLLOUTGLOBAL(clk), .RESETB(1'b1), .BYPASS(1'b0));
    bars u (.clk(clk), .hsync(HSYNC), .vsync(VSYNC),
            .r(VGA_R), .g(VGA_G), .b(VGA_B), .led(LED));
endmodule

module top_nopll (
    output HSYNC, VSYNC, output [2:0] VGA_R, VGA_G, output [1:0] VGA_B, output LED
);
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b01")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));
    bars #(.HACT(610), .HFP(15), .HSW(92), .HTOT(762)) u (
            .clk(clk), .hsync(HSYNC), .vsync(VSYNC),
            .r(VGA_R), .g(VGA_G), .b(VGA_B), .led(LED));
endmodule

module top_svga (
    output HSYNC, VSYNC, output [2:0] VGA_R, VGA_G, output [1:0] VGA_B, output LED
);
    wire hf, clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(hf));
    // 48 MHz / 4 * 53 / 16 = 39.75 MHz (spec 40)
    SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"), .DIVR(4'b0011),
        .DIVF(7'b0110100), .DIVQ(3'b100), .FILTER_RANGE(3'b001)) pll (
        .REFERENCECLK(hf), .PLLOUTGLOBAL(clk), .RESETB(1'b1), .BYPASS(1'b0));
    bars #(.HACT(800), .HFP(40), .HSW(128), .HTOT(1056),
           .VACT(600), .VFP(1), .VSW(4), .VTOT(628), .POS(1)) u (
            .clk(clk), .hsync(HSYNC), .vsync(VSYNC),
            .r(VGA_R), .g(VGA_G), .b(VGA_B), .led(LED));
endmodule

module top_ext (
    input FLASH_SCK,
    output HSYNC, VSYNC, output [2:0] VGA_R, VGA_G, output [1:0] VGA_B, output LED
);
    wire clk;
    // SCK measured at 15 MHz on the board (not the 30 MHz requested).
    // 15 MHz * 54 / 32 = 25.3125 MHz (spec 25.175, +0.55%), VCO 810 MHz
    SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"), .DIVR(4'b0000),
        .DIVF(7'b0110101), .DIVQ(3'b101), .FILTER_RANGE(3'b001)) pll (
        .REFERENCECLK(FLASH_SCK), .PLLOUTGLOBAL(clk), .RESETB(1'b1), .BYPASS(1'b0));
    bars u (.clk(clk), .hsync(HSYNC), .vsync(VSYNC),
            .r(VGA_R), .g(VGA_G), .b(VGA_B), .led(LED));
endmodule
