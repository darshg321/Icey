// Icey UART + flash test (115200 8N1 on /dev/ttyUSB1, FTDI channel B).
//   any byte -> echoed back
//   'i'      -> 3-byte JEDEC ID read from the SPI flash by the FPGA (ef 40 18)
//   'b'      -> '1' if SW2 released, '0' if pressed
module top(input RX, output TX, output LED, input BTN,
           output FLASH_SCK, output FLASH_CS, output FLASH_MOSI, input FLASH_MISO);
  wire clk;
  SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk)); // 12 MHz
  localparam DIV = 104;  // 12 MHz / 115200

  // ---- UART RX ----
  reg [1:0] rs = 2'b11;
  always @(posedge clk) rs <= {rs[0], RX};
  reg [6:0] rc = 0; reg [3:0] rb = 0; reg [7:0] rsh = 0; reg rbusy = 0, rv = 0;
  always @(posedge clk) begin
    rv <= 0;
    if (!rbusy) begin
      if (!rs[1]) begin rbusy <= 1; rc <= DIV/2; rb <= 0; end
    end else if (rc == DIV-1) begin
      rc <= 0; rb <= rb + 1;
      if (rb >= 1 && rb <= 8) rsh <= {rs[1], rsh[7:1]};
      if (rb == 9) begin rbusy <= 0; rv <= 1; end
    end else rc <= rc + 1;
  end

  // ---- UART TX ----
  reg [9:0] tsh = 10'h3ff; reg [3:0] tb = 0; reg [6:0] tc = 0; reg tbusy = 0;
  reg tgo = 0; reg [7:0] tdat = 0;
  assign TX = tsh[0];
  always @(posedge clk) begin
    if (!tbusy) begin
      if (tgo) begin tsh <= {1'b1, tdat, 1'b0}; tbusy <= 1; tb <= 0; tc <= 0; end
    end else if (tc == DIV-1) begin
      tc <= 0; tsh <= {1'b1, tsh[9:1]}; tb <= tb + 1;
      if (tb == 9) tbusy <= 0;
    end else tc <= tc + 1;
  end

  // ---- SPI flash master (clk/32): sends 0x9F, reads 24 bits ----
  reg [31:0] fsh = 0; reg [5:0] fn = 0; reg fact = 0; reg [3:0] fd = 0; reg sck = 0;
  reg [23:0] id = 0; reg fstart = 0, fdone = 0;
  assign FLASH_SCK = sck; assign FLASH_CS = !fact; assign FLASH_MOSI = fsh[31];
  always @(posedge clk) begin
    fdone <= 0;
    if (!fact) begin
      if (fstart) begin fact <= 1; fsh <= 32'h9F000000; fn <= 0; fd <= 0; sck <= 0; end
    end else begin
      fd <= fd + 1;
      if (fd == 15) begin
        sck <= !sck;
        if (!sck) id <= {id[22:0], FLASH_MISO};  // sample on rising edge
        else begin
          fsh <= {fsh[30:0], 1'b0}; fn <= fn + 1;
          if (fn == 31) begin fact <= 0; fdone <= 1; end
        end
      end
    end
  end

  // ---- control ----
  reg pend = 0; reg [7:0] pbyte = 0;  // one-byte RX buffer
  reg [2:0] st = 0;
  always @(posedge clk) begin
    tgo <= 0; fstart <= 0;
    if (rv) begin pend <= 1; pbyte <= rsh; end
    case (st)
      0: if (pend) begin
           pend <= rv;  // keep a byte that arrives this very cycle
           if (rv) pbyte <= rsh;
           if (pbyte == "i") begin fstart <= 1; st <= 1; end
           else begin tdat <= (pbyte == "b") ? (BTN ? "1" : "0") : pbyte; tgo <= 1; st <= 5; end
         end
      1: if (fdone) st <= 2;
      2: if (!tbusy && !tgo) begin tdat <= id[23:16]; tgo <= 1; st <= 3; end
      3: if (!tbusy && !tgo) begin tdat <= id[15:8];  tgo <= 1; st <= 4; end
      4: if (!tbusy && !tgo) begin tdat <= id[7:0];   tgo <= 1; st <= 5; end
      5: if (!tbusy && !tgo) st <= 0;
    endcase
  end

  reg [22:0] bl = 0;
  always @(posedge clk) bl <= bl + 1;
  assign LED = bl[22];
endmodule
