// Icey hardware-test bridge: PC <-UART 3 Mbaud-> FPGA <-SPI-> SD card / MAX3421E
//
// Commands (one at a time; the PC waits for each reply):
//   'X' n b0..b(n-1)  SPI exchange of n bytes (n=0 means 256); replies n bytes
//   'Y' cs n b0..     same, with chip selects in mask cs (bit0 SD, bit1 USB)
//                     pulled low around the transfer
//   'C' v             outputs: bit0 SD_CS, bit1 USB_CS, bit2 USB_RST (levels),
//                     bit3 LED1, bit4..6 RGB0..2 on              -> 'k'
//   'D' d             SPI clock = 24 MHz / (2*(d+1))             -> 'k'
//   'I'               inputs: bit0 BTN (1 = released), bit1 USB_INT, bit2 SD_MISO
// LED1 also lights in hardware while SW2 is held, independent of the PC.
`default_nettype none
module top (
  input  wire RX, output wire TX,
  output wire LED, input wire BTN,
  output wire RGB0, output wire RGB1, output wire RGB2,
  output wire SD_SCK, output wire SD_MOSI, input wire SD_MISO, output wire SD_CS,
  output wire USB_CS, output wire USB_RST, input wire USB_INT
);
  wire clk;
  SB_HFOSC #(.CLKHF_DIV("0b01")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk)); // 24 MHz

  // ---------------- UART, 8 clocks per bit ----------------
  reg [1:0] rs = 2'b11; reg [2:0] rc = 0; reg [3:0] rb = 0; reg [7:0] rsh = 0;
  reg rbusy = 0, rv = 0;
  always @(posedge clk) begin
    rs <= {rs[0], RX}; rv <= 0;
    if (!rbusy) begin
      if (!rs[1]) begin rbusy <= 1; rc <= 3; rb <= 0; end
    end else if (rc == 7) begin
      rc <= 0; rb <= rb + 1;
      if (rb == 0 && rs[1]) rbusy <= 0;
      if (rb >= 1 && rb <= 8) rsh <= {rs[1], rsh[7:1]};
      if (rb == 9) begin rbusy <= 0; rv <= 1; end
    end else rc <= rc + 1;
  end
  reg [9:0] tsh = 10'h3ff; reg [2:0] tc = 0; reg [3:0] tleft = 0;
  reg tgo = 0; reg [7:0] tdat = 0;
  wire tbusy = (tleft != 0) || tgo;
  always @(posedge clk) begin
    if (tleft == 0) begin
      if (tgo) begin tsh <= {1'b1, tdat, 1'b0}; tleft <= 10; tc <= 0; end
    end else if (tc == 7) begin tc <= 0; tsh <= {1'b1, tsh[9:1]}; tleft <= tleft - 1; end
    else tc <= tc + 1;
  end
  assign TX = tsh[0];

  // ---------------- SPI master, mode 0 ----------------
  reg [7:0] div = 29;                       // 400 kHz until the PC speeds it up
  reg [7:0] scnt = 0; reg [2:0] sbit = 0;
  reg [7:0] stx = 0, srx = 0;
  reg sck = 0, sbusy = 0, sgo = 0, sdone = 0;
  reg [7:0] sin = 0;
  always @(posedge clk) begin
    sdone <= 0;
    if (!sbusy) begin
      if (sgo) begin sbusy <= 1; stx <= sin; sbit <= 0; scnt <= div; sck <= 0; end
    end else if (scnt != 0) scnt <= scnt - 1;
    else begin
      scnt <= div;
      if (!sck) begin sck <= 1; srx <= {srx[6:0], SD_MISO}; end    // sample on rising
      else begin
        sck <= 0;
        if (sbit == 7) begin sbusy <= 0; sdone <= 1; end
        else begin sbit <= sbit + 1; stx <= {stx[6:0], 1'b0}; end  // shift on falling
      end
    end
  end
  assign SD_SCK = sck;
  assign SD_MOSI = stx[7];

  // ---------------- command handler ----------------
  reg [7:0] outs = 8'b0000_0111;           // CS high, USB_RST released, LEDs off
  reg [1:0] csm = 0;                        // chip selects held low during 'Y'
  reg [7:0] buffer [0:255];
  reg [7:0] bwa = 0, bra = 0, bwd = 0, brd = 0; reg bwe = 0;
  always @(posedge clk) begin
    if (bwe) buffer[bwa] <= bwd;
    brd <= buffer[bra];
  end
  localparam IDLE = 0, LEN = 1, FILL = 2, XRD = 3, XGO = 4, XWAIT = 5, SEND_RD = 6,
             SEND = 7, ARG = 8, ACK = 9, INP = 10, CSB = 11;
  reg [3:0] st = IDLE; reg [7:0] cmd = 0; reg [8:0] n = 0, i = 0; reg [1:0] w = 0;
  always @(posedge clk) begin
    tgo <= 0; sgo <= 0; bwe <= 0;
    case (st)
      IDLE: if (rv) begin
        cmd <= rsh;
        if (rsh == "X") st <= LEN;
        else if (rsh == "Y") st <= CSB;
        else if (rsh == "C" || rsh == "D") st <= ARG;
        else if (rsh == "I") st <= INP;
      end
      CSB:  if (rv) begin csm <= rsh[1:0]; st <= LEN; end
      LEN:  if (rv) begin n <= (rsh == 0) ? 9'd256 : {1'b0, rsh}; i <= 0; st <= FILL; end
      FILL: if (rv) begin
        bwe <= 1; bwa <= i[7:0]; bwd <= rsh; i <= i + 1;
        if (i + 1 == n) begin i <= 0; st <= XRD; w <= 0; end
      end
      XRD:  begin bra <= i[7:0]; w <= w + 1; if (w == 2) st <= XGO; end
      XGO:  begin sin <= brd; sgo <= 1; st <= XWAIT; end
      XWAIT: if (sdone) begin
        bwe <= 1; bwa <= i[7:0]; bwd <= srx; i <= i + 1; w <= 0;
        if (i + 1 == n) begin i <= 0; csm <= 0; st <= SEND_RD; end
        else st <= XRD;
      end
      SEND_RD: begin bra <= i[7:0]; w <= w + 1; if (w == 2) begin w <= 0; st <= SEND; end end
      SEND: if (!tbusy) begin
        tdat <= brd; tgo <= 1; i <= i + 1;
        st <= (i + 1 == n) ? IDLE : SEND_RD;
      end
      ARG:  if (rv) begin
        if (cmd == "C") outs <= rsh; else div <= rsh;
        st <= ACK;
      end
      ACK:  if (!tbusy) begin tdat <= "k"; tgo <= 1; st <= IDLE; end
      INP:  if (!tbusy) begin tdat <= {5'b0, SD_MISO, USB_INT, BTN}; tgo <= 1; st <= IDLE; end
    endcase
  end

  assign SD_CS   = outs[0] & ~csm[0];
  assign USB_CS  = outs[1] & ~csm[1];
  assign USB_RST = outs[2];
  assign LED     = outs[3] | ~BTN;          // lights while SW2 is held
  SB_RGBA_DRV #(.CURRENT_MODE("0b1"), .RGB0_CURRENT("0b000011"),
                .RGB1_CURRENT("0b000011"), .RGB2_CURRENT("0b000011")) rgb (
    .CURREN(1'b1), .RGBLEDEN(1'b1),
    .RGB0PWM(outs[4]), .RGB1PWM(outs[5]), .RGB2PWM(outs[6]),
    .RGB0(RGB0), .RGB1(RGB1), .RGB2(RGB2));
endmodule
