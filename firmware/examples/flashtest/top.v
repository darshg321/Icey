// Icey flash test: raw SPI / quad-SPI transactions on the W25Q128 from the PC.
//
// UART 3 Mbaud (FT2232H channel B). One command:
//   'T' ntx tx[0..ntx-1] dummy nrx_lo nrx_hi mode
//      CS low, send ntx bytes on IO0, clock `dummy` dummy cycles, read nrx bytes
//      (mode 0: 1-bit on IO1, mode 1: 4-bit on IO3..IO0), CS high.
//      Replies the nrx bytes, then a 4-byte count of 24 MHz clocks CS was low.
// SPI clock = 12 MHz. IO0 is released (tristated) from the dummy phase in quad mode.
`default_nettype none
module top (
  input  wire RX, output wire TX, output wire LED,
  output wire FLASH_SCK, output wire FLASH_CS,
  inout  wire FLASH_MOSI,                 // IO0 (flash DI)
  input  wire FLASH_MISO,                 // IO1 (flash DO)
  input  wire FLASH_WP,                   // IO2 (10k pull-up)
  input  wire FLASH_HOLD                  // IO3 (10k pull-up)
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

  // ---------------- flash pins ----------------
  reg sck = 0, cs = 1, mosi = 0, oe = 1;
  wire io0_in;
  SB_IO #(.PIN_TYPE(6'b1010_01), .PULLUP(1'b0)) io0 (
    .PACKAGE_PIN(FLASH_MOSI), .OUTPUT_ENABLE(oe), .D_OUT_0(mosi), .D_IN_0(io0_in));
  assign FLASH_SCK = sck;
  assign FLASH_CS = cs;

  // ---------------- read buffer (4 KB block RAM) ----------------
  reg [7:0] mem [0:4095];
  reg [11:0] wa = 0, ra = 0; reg [7:0] wd = 0, rd = 0; reg we = 0;
  always @(posedge clk) begin
    if (we) mem[wa] <= wd;
    rd <= mem[ra];
  end

  // ---------------- command + transaction engine ----------------
  localparam IDLE = 0, NTX = 1, TXB = 2, DUM = 3, NRL = 4, NRH = 5, MODE = 6,
             RUN = 7, SEND_RD = 8, SEND = 9, CNT = 10;
  localparam S_TX = 0, S_DUMMY = 1, S_RX = 2, S_DONE = 3;
  reg [3:0] st = IDLE;
  reg [7:0] txm [0:15];
  reg [4:0] ntx = 0, ti = 0;
  reg [7:0] dummy = 0, sh = 0;
  reg [12:0] nrx = 0, ri = 0;
  reg quad = 0, ph = 0;
  reg [1:0] stage = S_TX;
  reg [2:0] bitn = 0;
  reg [7:0] rbyte = 0;
  reg [31:0] cyc = 0;
  reg [1:0] w = 0; reg [12:0] si = 0; reg [2:0] cb = 0;
  wire [1:0] after_tx = (dummy != 0) ? S_DUMMY : (nrx != 0) ? S_RX : S_DONE;

  always @(posedge clk) begin
    tgo <= 0; we <= 0;
    case (st)
      IDLE: if (rv && rsh == "T") st <= NTX;
      NTX:  if (rv) begin ntx <= rsh[4:0]; ti <= 0; st <= (rsh == 0) ? DUM : TXB; end
      TXB:  if (rv) begin txm[ti[3:0]] <= rsh; ti <= ti + 1; if (ti + 1 == ntx) st <= DUM; end
      DUM:  if (rv) begin dummy <= rsh; st <= NRL; end
      NRL:  if (rv) begin nrx[7:0] <= rsh; st <= NRH; end
      NRH:  if (rv) begin nrx[12:8] <= rsh[4:0]; st <= MODE; end
      MODE: if (rv) begin
        quad <= rsh[0]; cs <= 0; cyc <= 0; ph <= 0; ti <= 0; bitn <= 0; ri <= 0;
        sh <= txm[0]; oe <= 1;
        stage <= (ntx != 0) ? S_TX : (dummy != 0) ? S_DUMMY : (nrx != 0) ? S_RX : S_DONE;
        st <= RUN;
      end
      RUN: begin
        cyc <= cyc + 1;
        ph <= ~ph;
        if (!ph) begin                                  // falling half: drive IO0
          sck <= 0;
          if (stage == S_TX) begin mosi <= sh[7]; oe <= 1; end
          else oe <= ~quad;                             // quad: let the flash drive IO0
          if (stage == S_DONE) begin cs <= 1; si <= 0; w <= 0; st <= SEND_RD; end
        end else begin                                  // rising half: flash samples / we sample
          sck <= 1;
          case (stage)
            S_TX: begin
              sh <= {sh[6:0], 1'b0}; bitn <= bitn + 1;
              if (bitn == 7) begin
                ti <= ti + 1; sh <= txm[(ti + 1) & 15];
                if (ti + 1 == ntx) stage <= after_tx;
              end
            end
            S_DUMMY: begin
              dummy <= dummy - 1;
              if (dummy == 1) stage <= (nrx != 0) ? S_RX : S_DONE;
            end
            S_RX: begin
              if (quad) begin
                rbyte <= {rbyte[3:0], FLASH_HOLD, FLASH_WP, FLASH_MISO, io0_in};
                bitn <= bitn + 1;
                if (bitn[0]) begin
                  we <= 1; wa <= ri[11:0]; wd <= {rbyte[3:0], FLASH_HOLD, FLASH_WP, FLASH_MISO, io0_in};
                  ri <= ri + 1; bitn <= 0;
                  if (ri + 1 == nrx) stage <= S_DONE;
                end
              end else begin
                rbyte <= {rbyte[6:0], FLASH_MISO};
                bitn <= bitn + 1;
                if (bitn == 7) begin
                  we <= 1; wa <= ri[11:0]; wd <= {rbyte[6:0], FLASH_MISO};
                  ri <= ri + 1;
                  if (ri + 1 == nrx) stage <= S_DONE;
                end
              end
            end
            default: ;
          endcase
        end
      end
      SEND_RD: begin
        oe <= 1; sck <= 0;
        if (si == nrx) begin st <= CNT; cb <= 0; end
        else begin ra <= si[11:0]; w <= w + 1; if (w == 2) begin w <= 0; st <= SEND; end end
      end
      SEND: if (!tbusy) begin tdat <= rd; tgo <= 1; si <= si + 1; st <= SEND_RD; end
      CNT:  if (!tbusy) begin
        tdat <= cyc[7:0]; cyc <= cyc >> 8; tgo <= 1; cb <= cb + 1;
        if (cb == 3) st <= IDLE;
      end
    endcase
  end

  // heartbeat
  reg [23:0] hb = 0;
  always @(posedge clk) hb <= hb + 1;
  assign LED = hb[23];
endmodule
