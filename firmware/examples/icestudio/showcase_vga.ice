{
  "version": "1.2",
  "package": {
    "name": "Icey showcase + VGA",
    "version": "1.0",
    "description": "The showcase (Game of Life, SD, USB host) plus the live grid and effects on VGA",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "Icey",
    "graph": {
      "blocks": [
        {
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [],
              "out": [
                {
                  "name": "clk"
                },
                {
                  "name": "pclk"
                }
              ]
            },
            "params": [],
            "code": "// Clocks: 24 MHz system + 25 MHz pixel\n// Icey has no crystal for the FPGA: internal 48 MHz oscillator / 2 = 24 MHz\n// runs the Life engine, UART and I/O bridge. The PLL turns it into the\n// 25.125 MHz VGA pixel clock (640x480@60 wants 25.175; 0.2% off is fine).\nSB_HFOSC #(.CLKHF_DIV(\"0b01\")) osc (\n  .CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));\nSB_PLL40_CORE #(.FEEDBACK_PATH(\"SIMPLE\"), .DIVR(4'b0001),\n  .DIVF(7'b1000010), .DIVQ(3'b101), .FILTER_RANGE(3'b001)) pll (\n  .REFERENCECLK(clk), .PLLOUTGLOBAL(pclk), .RESETB(1'b1), .BYPASS(1'b0));\n"
          },
          "id": "39e9458f-85f8-44b3-a336-c742f136e704",
          "position": {
            "x": 40,
            "y": 360
          },
          "size": {
            "width": 480,
            "height": 260
          }
        },
        {
          "id": "23ece895-14a0-4d3f-9624-af197c278a3d",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rx"
                }
              ],
              "out": [
                {
                  "name": "data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "valid"
                }
              ]
            },
            "params": [],
            "code": "// UART receive (3 Mbaud)\n// 24 MHz / 3 Mbaud = 8 clocks per bit\nreg [1:0] s = 2'b11;\nreg [3:0] cnt = 0;\nreg [3:0] bitn = 0;\nreg [7:0] sh = 0;\nreg busy = 0, v = 0;\nalways @(posedge clk) begin\n  s <= {s[0], rx};\n  v <= 0;\n  if (!busy) begin\n    if (!s[1]) begin busy <= 1; cnt <= 3; bitn <= 0; end   // start bit\n  end else if (cnt == 7) begin\n    cnt <= 0;\n    bitn <= bitn + 1;\n    if (bitn == 0 && s[1]) busy <= 0;                       // false start\n    if (bitn >= 1 && bitn <= 8) sh <= {s[1], sh[7:1]};\n    if (bitn == 9) begin busy <= 0; v <= 1; end\n  end else cnt <= cnt + 1;\nend\nassign data = sh;\nassign valid = v;\n"
          },
          "position": {
            "x": 600,
            "y": 120
          },
          "size": {
            "width": 420,
            "height": 340
          }
        },
        {
          "id": "e287aef8-e066-4261-bcbd-61bc661993b9",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "send"
                }
              ],
              "out": [
                {
                  "name": "tx"
                },
                {
                  "name": "busy"
                }
              ]
            },
            "params": [],
            "code": "// UART transmit (3 Mbaud)\nreg [9:0] sh = 10'h3ff;\nreg [3:0] cnt = 0;\nreg [3:0] left = 0;\nalways @(posedge clk) begin\n  if (left == 0) begin\n    if (send) begin sh <= {1'b1, data, 1'b0}; left <= 10; cnt <= 0; end\n  end else if (cnt == 7) begin\n    cnt <= 0; sh <= {1'b1, sh[9:1]}; left <= left - 1;\n  end else cnt <= cnt + 1;\nend\nassign tx = sh[0];\nassign busy = (left != 0) || send;\n"
          },
          "position": {
            "x": 2200,
            "y": 560
          },
          "size": {
            "width": 420,
            "height": 280
          }
        },
        {
          "id": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "rx_valid"
                },
                {
                  "name": "tx_busy"
                },
                {
                  "name": "new_row",
                  "range": "[127:0]",
                  "size": 128
                }
              ],
              "out": [
                {
                  "name": "above",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "row",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "below",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "tx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "tx_send"
                },
                {
                  "name": "led"
                },
                {
                  "name": "cmd_idle"
                },
                {
                  "name": "disp_we"
                },
                {
                  "name": "disp_row",
                  "range": "[6:0]",
                  "size": 7
                },
                {
                  "name": "disp_data",
                  "range": "[127:0]",
                  "size": 128
                }
              ]
            },
            "params": [],
            "code": "// Grid memory + scheduler + PC link\n// The 128x128 grid lives in block RAM, two copies (\"banks\"): the engine\n// reads generation N from one bank and writes generation N+1 to the other.\n// Every clock it reads one row, slides a 3-row window (above/row/below) and\n// the 128 rule copies produce a whole new row at once.\n//\n// PC commands (bytes on the UART):\n//   'S'         -> 4-byte generation counter + 2048-byte grid snapshot\n//   'L' + 2048  -> load a grid                         (replies 'k')\n//   'V' + n     -> speed: 0 = flat out, 255 = stop,\n//                  else wait n*65536 clocks (n*2.7 ms) per generation\n//   'N'         -> single step while stopped           (replies 'k')\n// Grid format: row 0..127, 16 bytes per row, bit x of the row = column x.\n// Every row written to the grid is also sent out on disp_* so the VGA\n// layer can keep its own copy (block RAM has only one read port).\n\nreg [127:0] mem [0:255];      // {bank, row}\nreg [7:0]   raddr = 0;\nreg [127:0] rdata = 0;\nreg         we = 0;\nreg [7:0]   waddr = 0;\nreg [127:0] wdata = 0;\nalways @(posedge clk) begin\n  rdata <= mem[raddr];\n  if (we) mem[waddr] <= wdata;\nend\n\n// ---------------- generation engine ----------------\nreg         bank = 0;              // bank holding the current generation\nreg [31:0]  gen = 0;\nreg [7:0]   speed = 255;           // start stopped until the PC says go\nreg [23:0]  wait_cnt = 0;\nreg         running = 0;           // a generation is in progress\nreg [7:0]   i = 0;                 // read index 0..129\nreg         rd_v0 = 0, rd_v = 0;   // address issued / rdata valid this cycle\nreg [1:0]   filled = 0;            // rows in the window (saturates at 3)\nreg         win = 0;               // window full: compute a row this cycle\nreg [6:0]   wrow = 0;\nreg [127:0] a = 0, r = 0, b = 0;\nreg         pause_req = 0;         // PC link wants the engine parked\nreg         step_req = 0;          // engine-owned latch for single steps\nreg         step_pulse = 0, speed_pulse = 0;   // one-clock requests from PC link\nreg         gen_tick = 0;          // one clock when a generation completes\nassign above = a; assign row = r; assign below = b;\nwire idle = !running;\n\n// engine-side memory signals (muxed with the PC link below)\nreg [7:0]   e_raddr;\nreg         e_we;\nreg [7:0]   e_waddr;\nreg [127:0] e_wdata;\n\nalways @(posedge clk) begin\n  e_we <= 0;\n  gen_tick <= 0;\n  if (step_pulse) step_req <= 1;\n  if (!running) begin\n    rd_v0 <= 0; rd_v <= 0; win <= 0;\n    if (speed_pulse) wait_cnt <= 0;               // new speed takes effect now\n    else if (wait_cnt != 0) wait_cnt <= wait_cnt - 1;\n    else if (!pause_req && (speed != 255 || step_req)) begin\n      running <= 1; i <= 0; filled <= 0; wrow <= 0; step_req <= 0;\n    end\n  end else begin\n    // 1) issue reads for rows 127, 0, 1, ..., 127, 0 (wrap-around)\n    if (i <= 129) begin\n      e_raddr <= {bank, i[6:0] - 7'd1};\n      i <= i + 1;\n    end\n    rd_v0 <= (i <= 129);\n    rd_v  <= rd_v0;                 // block RAM answers one clock later\n    // 2) slide the 3-row window\n    if (rd_v) begin\n      a <= r; r <= b; b <= rdata;\n      if (filled != 3) filled <= filled + 1;\n    end\n    win <= rd_v && filled >= 2;\n    // 3) register the new row from the 128 rule copies, write next cycle\n    if (win) begin\n      e_we <= 1; e_waddr <= {~bank, wrow}; e_wdata <= new_row;\n      wrow <= wrow + 1;\n      if (wrow == 127) begin\n        running <= 0; bank <= ~bank; gen <= gen + 1; gen_tick <= 1;\n        wait_cnt <= (speed == 255) ? 24'd0 : {speed, 16'h0};\n      end\n    end\n  end\nend\n\n// ---------------- PC link ----------------\nlocalparam H_IDLE = 0, H_SPEED = 1, H_WAIT = 2, H_DUMPGEN = 3, H_DUMPRD = 4,\n           H_DUMPROW = 5, H_LOAD = 6, H_ACK = 7, H_STEP = 8;\nreg [3:0]   hs = H_IDLE;\nreg [7:0]   cmd = 0;\nreg [127:0] acc = 0;               // load accumulator / dump shift register\nreg [3:0]   nbyte = 0;\nreg [7:0]   hrow = 0;\nreg [2:0]   gbyte = 0;\nreg [31:0]  gsnap = 0;\nreg         h_we = 0;\nreg [127:0] h_wdata = 0;\nreg [7:0]   h_waddr = 0;\nreg [7:0]   txd = 0;\nreg         txs = 0;\nreg [1:0]   rdwait = 0;\n// register + pre-decode received bytes (keeps the state machine fast)\nreg [7:0]   rxd = 0;\nreg         rxv = 0, is_s = 0, is_l = 0, is_v = 0, is_n = 0;\nalways @(posedge clk) begin\n  rxv <= rx_valid; rxd <= rx_data;\n  is_s <= rx_data == \"S\"; is_l <= rx_data == \"L\";\n  is_v <= rx_data == \"V\"; is_n <= rx_data == \"N\";\nend\nalways @(posedge clk) begin\n  txs <= 0; h_we <= 0; step_pulse <= 0; speed_pulse <= 0;\n  case (hs)\n    H_IDLE: if (rxv) begin\n      cmd <= rxd;\n      if (is_v) hs <= H_SPEED;\n      else if (is_n) begin step_pulse <= 1; hs <= H_STEP; end\n      else if (is_s || is_l) begin pause_req <= 1; hs <= H_WAIT; end\n    end\n    H_SPEED: if (rxv) begin speed <= rxd; speed_pulse <= 1; hs <= H_ACK; end\n    H_STEP: if (gen_tick) hs <= H_ACK;            // ack once the step is done\n    H_WAIT: if (idle) begin                       // engine parked between gens\n      hrow <= 0; nbyte <= 0; gbyte <= 0; gsnap <= gen;\n      hs <= (cmd == \"S\") ? H_DUMPGEN : H_LOAD;\n    end\n    H_DUMPGEN: if (!tx_busy && !txs) begin\n      txd <= gsnap[7:0]; gsnap <= gsnap >> 8; txs <= 1;\n      gbyte <= gbyte + 1;\n      if (gbyte == 3) begin hs <= H_DUMPRD; rdwait <= 0; end\n    end\n    H_DUMPRD: begin                               // read row hrow (2-cycle wait)\n      rdwait <= rdwait + 1;\n      if (rdwait == 2) begin acc <= rdata; nbyte <= 0; hs <= H_DUMPROW; end\n    end\n    H_DUMPROW: if (!tx_busy && !txs) begin\n      txd <= acc[7:0]; acc <= acc >> 8; txs <= 1;\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        hrow <= hrow + 1; rdwait <= 0;\n        if (hrow == 127) begin pause_req <= 0; hs <= H_IDLE; end\n        else hs <= H_DUMPRD;\n      end\n    end\n    H_LOAD: if (rxv) begin\n      acc <= {rxd, acc[127:8]};\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        h_we <= 1; h_waddr <= {bank, hrow[6:0]}; h_wdata <= {rxd, acc[127:8]};\n        hrow <= hrow + 1;\n        if (hrow == 127) hs <= H_ACK;\n      end\n    end\n    H_ACK: if (!tx_busy && !txs) begin\n      txd <= \"k\"; txs <= 1; pause_req <= 0; hs <= H_IDLE;\n    end\n  endcase\nend\n\n// memory port mux: the PC link only touches memory while the engine is parked\nalways @(*) begin\n  raddr = running ? e_raddr : {bank, hrow[6:0]};\n  we    = running ? e_we : (h_we | e_we);\n  waddr = h_we ? h_waddr : e_waddr;\n  wdata = h_we ? h_wdata : e_wdata;\nend\n\nassign tx_data = txd;\nassign tx_send = txs;\nassign cmd_idle = (hs == H_IDLE);\n// LED: blinks with the generation count (slower bit when running flat out)\nassign led = (speed == 0) ? gen[18] : gen[2];\n// copy of every grid write for the VGA display\nassign disp_we = we;\nassign disp_row = waddr[6:0];\nassign disp_data = wdata;\n"
          },
          "position": {
            "x": 1100,
            "y": 40
          },
          "size": {
            "width": 760,
            "height": 520
          }
        },
        {
          "id": "9a96b1fd-34db-4814-b871-deab4e9022a4",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "above",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "row",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "below",
                  "range": "[127:0]",
                  "size": 128
                }
              ],
              "out": [
                {
                  "name": "new_row",
                  "range": "[127:0]",
                  "size": 128
                }
              ]
            },
            "params": [],
            "code": "// Life rule x128 (one whole row per clock)\n// 128 copies of Conway's rule, side by side in hardware. They all\n// evaluate at the same instant: a full row of the grid every clock.\ngenvar k;\ngenerate\n  for (k = 0; k < 128; k = k + 1) begin : life_cell\n    localparam L = (k + 127) % 128;    // wrap around left/right edges\n    localparam R = (k + 1) % 128;\n    wire [3:0] n = above[L] + above[k] + above[R]\n                 + row[L]              + row[R]\n                 + below[L] + below[k] + below[R];\n    assign new_row[k] = (n == 3) || (row[k] && n == 2);\n  end\nendgenerate\n"
          },
          "position": {
            "x": 2200,
            "y": 40
          },
          "size": {
            "width": 560,
            "height": 300
          }
        },
        {
          "id": "a54047b6-b791-41ce-a18b-7fc61ce95943",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "rx_valid"
                },
                {
                  "name": "life_idle"
                },
                {
                  "name": "io_idle"
                },
                {
                  "name": "life_tx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "life_tx_send"
                },
                {
                  "name": "io_tx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "io_tx_send"
                }
              ],
              "out": [
                {
                  "name": "life_rx_valid"
                },
                {
                  "name": "io_rx_valid"
                },
                {
                  "name": "tx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "tx_send"
                }
              ]
            },
            "params": [],
            "code": "// Command router\n// One UART, two command sets: S L V N go to the Life engine,\n// X Y C D I G go to the I/O bridge. The first byte of a command picks the\n// owner, which then gets every byte until it is back to idle.\nreg [1:0] owner = 0;              // 0 none, 1 life, 2 io\nreg started = 0;\nwire is_life = rx_data == \"S\" || rx_data == \"L\" || rx_data == \"V\" || rx_data == \"N\";\nwire is_io   = rx_data == \"X\" || rx_data == \"Y\" || rx_data == \"C\" || rx_data == \"D\" ||\n               rx_data == \"I\" || rx_data == \"G\";\nwire [1:0] route = owner != 0 ? owner : is_life ? 2'd1 : is_io ? 2'd2 : 2'd0;\nwire sub_idle = owner == 1 ? life_idle : io_idle;\nalways @(posedge clk) begin\n  if (owner == 0) begin\n    if (rx_valid && route != 0) begin owner <= route; started <= 0; end\n  end else if (!sub_idle) started <= 1;\n  else if (started) owner <= 0;\nend\nassign life_rx_valid = rx_valid && route == 1;\nassign io_rx_valid   = rx_valid && route == 2;\nassign tx_send = life_tx_send | io_tx_send;\nassign tx_data = life_tx_send ? life_tx_data : io_tx_data;\n"
          },
          "position": {
            "x": 1100,
            "y": -620
          },
          "size": {
            "width": 760,
            "height": 480
          }
        },
        {
          "id": "a4c8f81d-5717-4720-8323-0e322f707f40",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "rx_valid"
                },
                {
                  "name": "tx_busy"
                },
                {
                  "name": "btn"
                },
                {
                  "name": "usb_int"
                },
                {
                  "name": "sd_miso"
                },
                {
                  "name": "life_led"
                }
              ],
              "out": [
                {
                  "name": "tx_data",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "tx_send"
                },
                {
                  "name": "idle"
                },
                {
                  "name": "sd_sck"
                },
                {
                  "name": "sd_mosi"
                },
                {
                  "name": "sd_cs"
                },
                {
                  "name": "usb_cs"
                },
                {
                  "name": "usb_rst"
                },
                {
                  "name": "led"
                },
                {
                  "name": "rgb0"
                },
                {
                  "name": "rgb1"
                },
                {
                  "name": "rgb2"
                },
                {
                  "name": "gfx",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// I/O bridge: SPI (SD + USB host), button, LEDs\n// Lets the PC use the board's peripherals through the FPGA:\n//   'X' n data      SPI exchange of n bytes (0 = 256), replies n bytes\n//   'Y' cs n data   same, with chip selects in mask cs (bit0 SD, bit1 USB)\n//                   pulled low around the transfer\n//   'C' v           bit0 SD_CS, bit1 USB_CS, bit2 USB_RST, bit3 LED1,\n//                   bit4 red, bit5 blue, bit6 green                -> 'k'\n//   'D' d           SPI clock = 24 MHz / (2*(d+1))                 -> 'k'\n//   'I'             bit0 SW2 (1 = released), bit1 USB_INT, bit2 SD_MISO\n//   'G' s           VGA scene: 0-7 holds one, 255 = cycle (default) -> 'k'\n\n// ---- SPI master, mode 0 ----\nreg [7:0] div = 29;\nreg [7:0] scnt = 0; reg [2:0] sbit = 0;\nreg [7:0] stx = 0, srx = 0, sin = 0;\nreg sck = 0, sbusy = 0, sgo = 0, sdone = 0;\nalways @(posedge clk) begin\n  sdone <= 0;\n  if (!sbusy) begin\n    if (sgo) begin sbusy <= 1; stx <= sin; sbit <= 0; scnt <= div; sck <= 0; end\n  end else if (scnt != 0) scnt <= scnt - 1;\n  else begin\n    scnt <= div;\n    if (!sck) begin sck <= 1; srx <= {srx[6:0], sd_miso}; end\n    else begin\n      sck <= 0;\n      if (sbit == 7) begin sbusy <= 0; sdone <= 1; end\n      else begin sbit <= sbit + 1; stx <= {stx[6:0], 1'b0}; end\n    end\n  end\nend\nassign sd_sck = sck;\nassign sd_mosi = stx[7];\n\n// ---- command handler ----\nreg [7:0] outs = 8'b0000_0111;\nreg [7:0] scene = 8'hFF;\nreg [1:0] csm = 0;                         // chip selects held low during 'Y'\nreg [7:0] buffer [0:255];\nreg [7:0] bwa = 0, bra = 0, bwd = 0, brd = 0; reg bwe = 0;\nalways @(posedge clk) begin\n  if (bwe) buffer[bwa] <= bwd;\n  brd <= buffer[bra];\nend\nlocalparam IDLE = 0, LEN = 1, FILL = 2, XRD = 3, XGO = 4, XWAIT = 5, SEND_RD = 6,\n           SEND = 7, ARG = 8, ACK = 9, INP = 10, CSB = 11;\nreg [3:0] st = IDLE; reg [7:0] cmd = 0; reg [8:0] n = 0, i = 0; reg [1:0] w = 0;\nreg [7:0] txd = 0; reg txs = 0;\nalways @(posedge clk) begin\n  txs <= 0; sgo <= 0; bwe <= 0;\n  case (st)\n    IDLE: if (rx_valid) begin\n      cmd <= rx_data;\n      if (rx_data == \"X\") st <= LEN;\n      else if (rx_data == \"Y\") st <= CSB;\n      else if (rx_data == \"C\" || rx_data == \"D\" || rx_data == \"G\") st <= ARG;\n      else if (rx_data == \"I\") st <= INP;\n    end\n    CSB:  if (rx_valid) begin csm <= rx_data[1:0]; st <= LEN; end\n    LEN:  if (rx_valid) begin n <= (rx_data == 0) ? 9'd256 : {1'b0, rx_data}; i <= 0; st <= FILL; end\n    FILL: if (rx_valid) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= rx_data; i <= i + 1;\n      if (i + 1 == n) begin i <= 0; st <= XRD; w <= 0; end\n    end\n    XRD:  begin bra <= i[7:0]; w <= w + 1; if (w == 2) st <= XGO; end\n    XGO:  begin sin <= brd; sgo <= 1; st <= XWAIT; end\n    XWAIT: if (sdone) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= srx; i <= i + 1; w <= 0;\n      if (i + 1 == n) begin i <= 0; csm <= 0; st <= SEND_RD; end\n      else st <= XRD;\n    end\n    SEND_RD: begin bra <= i[7:0]; w <= w + 1; if (w == 2) begin w <= 0; st <= SEND; end end\n    SEND: if (!tx_busy && !txs) begin\n      txd <= brd; txs <= 1; i <= i + 1;\n      st <= (i + 1 == n) ? IDLE : SEND_RD;\n    end\n    ARG:  if (rx_valid) begin\n      if (cmd == \"C\") outs <= rx_data;\n      else if (cmd == \"G\") scene <= rx_data;\n      else div <= rx_data;\n      st <= ACK;\n    end\n    ACK:  if (!tx_busy && !txs) begin txd <= \"k\"; txs <= 1; st <= IDLE; end\n    INP:  if (!tx_busy && !txs) begin txd <= {5'b0, sd_miso, usb_int, btn}; txs <= 1; st <= IDLE; end\n  endcase\nend\nassign tx_data = txd;\nassign tx_send = txs;\nassign idle = (st == IDLE);\nassign gfx = scene;\n\nassign sd_cs   = outs[0] & ~csm[0];\nassign usb_cs  = outs[1] & ~csm[1];\nassign usb_rst = outs[2];\nassign led     = life_led | outs[3] | ~btn;     // also lights while SW2 is held\nSB_RGBA_DRV #(.CURRENT_MODE(\"0b1\"), .RGB0_CURRENT(\"0b000011\"),\n              .RGB1_CURRENT(\"0b000011\"), .RGB2_CURRENT(\"0b000011\")) rgb (\n  .CURREN(1'b1), .RGBLEDEN(1'b1),\n  .RGB0PWM(outs[4]), .RGB1PWM(outs[5]), .RGB2PWM(outs[6]),\n  .RGB0(rgb0), .RGB1(rgb1), .RGB2(rgb2));\n"
          },
          "position": {
            "x": 2200,
            "y": 980
          },
          "size": {
            "width": 760,
            "height": 560
          }
        },
        {
          "id": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                }
              ],
              "out": [
                {
                  "name": "hs"
                },
                {
                  "name": "vs"
                },
                {
                  "name": "de"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "heartbeat"
                }
              ]
            },
            "params": [],
            "code": "// VGA 640x480 timing\n// 800 clocks per line, 525 lines per frame -> 60 Hz\nreg [9:0] hc = 0, vc = 0;\nreg [7:0] frame = 0;\nalways @(posedge clk) begin\n  if (hc == 799) begin\n    hc <= 0;\n    if (vc == 524) vc <= 0; else vc <= vc + 1;\n    if (vc == 479) frame <= frame + 1;   // tick once per frame\n  end else hc <= hc + 1;\nend\nassign x  = hc;\nassign y  = vc;\nassign de = (hc < 640) && (vc < 480);\nassign hs = ~(hc >= 656 && hc < 752);    // negative sync pulses\nassign vs = ~(vc >= 490 && vc < 492);\nassign t  = frame;\nassign heartbeat = frame[5];             // LED blinks ~1 Hz\n"
          },
          "position": {
            "x": 600,
            "y": 1700
          },
          "size": {
            "width": 480,
            "height": 340
          }
        },
        {
          "id": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "rgb",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Effect 1: sine plasma\n// 8-bit sine: quarter-wave table + symmetry (pure logic, no memory)\nfunction [7:0] sin8(input [7:0] a);\n  reg [5:0] i; reg [6:0] q;\n  begin\n    i = a[6] ? ~a[5:0] : a[5:0];\n    case (i)\n      0: q = 2;\n      1: q = 5;\n      2: q = 8;\n      3: q = 11;\n      4: q = 14;\n      5: q = 17;\n      6: q = 20;\n      7: q = 23;\n      8: q = 26;\n      9: q = 29;\n      10: q = 32;\n      11: q = 35;\n      12: q = 38;\n      13: q = 41;\n      14: q = 44;\n      15: q = 47;\n      16: q = 50;\n      17: q = 53;\n      18: q = 56;\n      19: q = 58;\n      20: q = 61;\n      21: q = 64;\n      22: q = 67;\n      23: q = 69;\n      24: q = 72;\n      25: q = 74;\n      26: q = 77;\n      27: q = 79;\n      28: q = 82;\n      29: q = 84;\n      30: q = 86;\n      31: q = 89;\n      32: q = 91;\n      33: q = 93;\n      34: q = 95;\n      35: q = 97;\n      36: q = 99;\n      37: q = 101;\n      38: q = 103;\n      39: q = 105;\n      40: q = 106;\n      41: q = 108;\n      42: q = 110;\n      43: q = 111;\n      44: q = 113;\n      45: q = 114;\n      46: q = 115;\n      47: q = 117;\n      48: q = 118;\n      49: q = 119;\n      50: q = 120;\n      51: q = 121;\n      52: q = 122;\n      53: q = 123;\n      54: q = 124;\n      55: q = 124;\n      56: q = 125;\n      57: q = 125;\n      58: q = 126;\n      59: q = 126;\n      60: q = 127;\n      61: q = 127;\n      62: q = 127;\n      63: q = 127;\n    endcase\n    sin8 = a[7] ? 8'd127 - q : 8'd128 + q;\n  end\nendfunction\n\n// 4 sine waves summed per pixel, then a 3-sine palette:\n// 7 sine lookups for EVERY pixel, 25 million times a second.\nreg [7:0] a1, a2, a3, a4, s1, s2, s3, s4, p0, p1, p2;\nwire [9:0] cx = (x > 320) ? x - 320 : 320 - x;\nwire [9:0] cy = (y > 240) ? y - 240 : 240 - y;\nwire [9:0] sum = s1 + s2 + s3 + s4;\nwire [7:0] v = sum[9:2] + t;\nalways @(posedge clk) begin\n  // stage 1: wave phases\n  a1 <= x[8:1] + t;\n  a2 <= y[7:0] - {t[6:0], 1'b0};\n  a3 <= x[9:2] + y[8:1] + {t[6:0], 1'b0};\n  a4 <= cx[7:0] + cy[7:0] - {t[5:0], 2'b0};\n  // stage 2: sines\n  s1 <= sin8(a1); s2 <= sin8(a2); s3 <= sin8(a3); s4 <= sin8(a4);\n  // stage 3: palette\n  p0 <= sin8(v); p1 <= sin8(v + 8'd85); p2 <= sin8(v + 8'd170);\nend\nassign rgb = {p0[7:5], p1[7:5], p2[7:6]};\n"
          },
          "position": {
            "x": 1300,
            "y": 1700
          },
          "size": {
            "width": 560,
            "height": 420
          }
        },
        {
          "id": "555182f5-f94e-4d92-beea-0f056105125b",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "rgb",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Effect 2: XOR fractal\n// x XOR y makes nested-square fractals; scroll it and cycle the colours\nreg [7:0] c, k;\nreg [7:0] r1, r2;\nwire [8:0] u = x[8:0] + {t, 1'b0};\nwire [8:0] w = y[8:0] - {1'b0, t};\nalways @(posedge clk) begin\n  c  <= u[7:0] ^ w[7:0];\n  k  <= u[8:1] + w[8:1] + t;\n  r1 <= {c[7:5], c[4:2] ^ k[7:5], c[7] ^ k[7], c[1]};\n  r2 <= r1;                     // pad to the common 3-clock latency\nend\nassign rgb = r2;\n"
          },
          "position": {
            "x": 1300,
            "y": 2180
          },
          "size": {
            "width": 560,
            "height": 260
          }
        },
        {
          "id": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "rgb",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Effect 3: two-source interference\n// Two bouncing point sources; each pixel computes its squared distance\n// to both (4 multipliers per pixel) -> ripple interference pattern.\n// The multiplies use 4 of the chip's DSP blocks (SB_MAC16) directly, so\n// they don't eat logic cells (the rest of this design needs them).\nreg [9:0] ax = 160, ay = 120, bx = 480, by = 360;\nreg adx = 1, ady = 1, bdx = 0, bdy = 1;\nwire frame = (x == 0) && (y == 480);\nalways @(posedge clk) if (frame) begin\n  ax <= adx ? ax + 3 : ax - 3;  ay <= ady ? ay + 2 : ay - 2;\n  bx <= bdx ? bx + 2 : bx - 2;  by <= bdy ? by + 3 : by - 3;\n  if (ax > 630) adx <= 0; if (ax < 10) adx <= 1;\n  if (ay > 470) ady <= 0; if (ay < 10) ady <= 1;\n  if (bx > 630) bdx <= 0; if (bx < 10) bdx <= 1;\n  if (by > 470) bdy <= 0; if (by < 10) bdy <= 1;\nend\nreg [9:0] dx1, dy1, dx2, dy2;\nreg [19:0] q1, q2, q3, q4;\nreg [7:0] r;\nwire [31:0] m [0:3];                      // dx1^2, dy1^2, dx2^2, dy2^2\nwire [9:0] sq [0:3];\nassign sq[0] = dx1; assign sq[1] = dy1; assign sq[2] = dx2; assign sq[3] = dy2;\ngenvar k;\ngenerate\n  for (k = 0; k < 4; k = k + 1) begin : mul\n    SB_MAC16 #(.TOPOUTPUT_SELECT(2'b11), .BOTOUTPUT_SELECT(2'b11),\n               .MODE_8x8(1'b0), .A_SIGNED(1'b0), .B_SIGNED(1'b0)) dsp (\n      .CLK(1'b0), .CE(1'b1), .A({6'd0, sq[k]}), .B({6'd0, sq[k]}),\n      .C(16'd0), .D(16'd0), .AHOLD(1'b0), .BHOLD(1'b0), .CHOLD(1'b0),\n      .DHOLD(1'b0), .IRSTTOP(1'b0), .IRSTBOT(1'b0), .ORSTTOP(1'b0),\n      .ORSTBOT(1'b0), .OLOADTOP(1'b0), .OLOADBOT(1'b0), .ADDSUBTOP(1'b0),\n      .ADDSUBBOT(1'b0), .OHOLDTOP(1'b0), .OHOLDBOT(1'b0), .CI(1'b0),\n      .ACCUMCI(1'b0), .SIGNEXTIN(1'b0), .O(m[k]));\n  end\nendgenerate\nwire [20:0] d1 = q1 + q2, d2 = q3 + q4;\nwire [7:0] v1 = d1[14:7] - {t[5:0], 2'b0};   // rings expand outwards\nwire [7:0] v2 = d2[14:7] - {t[5:0], 2'b0};\nalways @(posedge clk) begin\n  dx1 <= (x > ax) ? x - ax : ax - x;  dy1 <= (y > ay) ? y - ay : ay - y;\n  dx2 <= (x > bx) ? x - bx : bx - x;  dy2 <= (y > by) ? y - by : by - y;\n  q1 <= m[0][19:0];  q2 <= m[1][19:0];  q3 <= m[2][19:0];  q4 <= m[3][19:0];\n  if (d1 < 400 || d2 < 400) r <= 8'hFF;              // the sources\n  else r <= {v1[7:5], v2[7:5], v1[7] ^ v2[7], v1[6] ^ v2[6]};\n  // red = waves from A, green = waves from B, blue = where they interfere\nend\nassign rgb = r;\n"
          },
          "position": {
            "x": 1300,
            "y": 2500
          },
          "size": {
            "width": 620,
            "height": 640
          }
        },
        {
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "rgb",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Effect 4: all 256 colours\n// The DAC does 3 bits red, 3 green, 2 blue = 256 colours. Show every one\n// as a 16x16 wall of swatches scrolling upwards, with rainbow bars at the\n// sides sweeping the other way.\nreg [7:0] sw = 0, bar = 0, r = 0, r2 = 0;\nreg edge = 0, side = 0;\nwire [9:0] xs = x - 10'd64;               // swatches span x = 64..575\nwire [9:0] ys = y + {t, 1'b0};            // scroll up 2 lines per frame\nfunction [2:0] ramp(input [7:0] a);       // triangle wave, 3 bits\n  ramp = a[7] ? ~a[6:4] : a[6:4];\nendfunction\nwire [2:0] br = ramp(bar), bg = ramp(bar + 8'd85), bb = ramp(bar + 8'd170);\nalways @(posedge clk) begin\n  // stage 1: which swatch, or the side bars\n  sw   <= {ys[8:5], xs[8:5]};             // colour index = row, column\n  edge <= (xs[4:0] == 0) || (ys[4:0] == 0);\n  side <= (x < 64) || (x >= 576);\n  bar  <= y[8:1] - {t, 1'b0};\n  // stage 2: colour\n  if (side) r <= {br, bg, bb[2:1]};\n  else if (edge) r <= 8'd0;\n  else r <= sw;\n  // stage 3\n  r2 <= r;\nend\nassign rgb = r2;\n"
          },
          "id": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
          "position": {
            "x": 1300,
            "y": 3020
          },
          "size": {
            "width": 560,
            "height": 380
          }
        },
        {
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "wclk"
                },
                {
                  "name": "we"
                },
                {
                  "name": "wrow",
                  "range": "[6:0]",
                  "size": 7
                },
                {
                  "name": "wdata",
                  "range": "[127:0]",
                  "size": 128
                },
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "t",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "cell"
                },
                {
                  "name": "ingrid"
                },
                {
                  "name": "frame"
                },
                {
                  "name": "color",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Life on VGA\n// Keeps its own copy of the 128x128 grid in block RAM: written by the\n// Life engine at 24 MHz, read by the beam at 25 MHz (the RAM has separate\n// read and write clocks). Each cell is drawn 3x3 pixels: a 384x384 board\n// in the middle of the screen. One row is fetched per scan line during\n// blanking, so the engine never has to wait for the display.\n// Outputs line up with the effects (3 clocks after x/y).\nreg [127:0] dmem [0:127];\nalways @(posedge wclk) if (we) dmem[wrow] <= wdata;\nreg [6:0]   raddr = 0;\nreg [127:0] rdata = 0, rowbuf = 0;\nalways @(posedge clk) rdata <= dmem[raddr];\n\n// vertical: which grid row the NEXT line shows (updated after each line)\nlocalparam X0 = 128, Y0 = 48;             // board at x 128..511, y 48..431\nreg [6:0] vrow = 0; reg [1:0] vsub = 0; reg vin = 0;\nwire [9:0] ny = (y == 524) ? 10'd0 : y + 10'd1;\nalways @(posedge clk) begin\n  if (x == 640) begin\n    if (ny == Y0) begin vrow <= 0; vsub <= 0; vin <= 1; end\n    else if (vin) begin\n      if (vsub == 2) begin\n        vsub <= 0;\n        if (vrow == 127) vin <= 0; else vrow <= vrow + 1;\n      end else vsub <= vsub + 1;\n    end\n  end\n  if (x == 650) raddr <= vrow;\n  if (x == 660) rowbuf <= rdata;          // used for the whole next line\nend\n\n// horizontal, stage 1: column of pixel x\nreg [6:0] col = 0; reg [1:0] hsub = 0; reg hin = 0;\nreg box1 = 0, gap1 = 0;\nalways @(posedge clk) begin\n  if (x == X0) begin col <= 0; hsub <= 0; hin <= 1; end\n  else if (hin) begin\n    if (hsub == 2) begin\n      hsub <= 0;\n      if (col == 127) hin <= 0; else col <= col + 1;\n    end else hsub <= hsub + 1;\n  end\n  box1 <= (x >= X0 - 4) && (x < X0 + 388) && (y >= Y0 - 4) && (y < Y0 + 388);\n  gap1 <= (x >= X0 - 2) && (x < X0 + 386) && (y >= Y0 - 2) && (y < Y0 + 386);\nend\n// stage 2: look up the cell, pick its colour (rainbow across the board,\n// drifting with time)\nreg c2 = 0, in2 = 0, fr2 = 0;\nreg [7:0] hue = 0;\nalways @(posedge clk) begin\n  c2  <= rowbuf[col];\n  in2 <= hin && vin;\n  fr2 <= box1 && !gap1;\n  hue <= {1'b0, col} + {1'b0, vrow} + t;\nend\n// colour wheel: each channel is bright for a third of the circle\nfunction [2:0] wheel(input [7:0] a);\n  reg [7:0] d;\n  begin\n    d = a[7] ? 8'd0 - a : a;               // distance from 0 on the circle\n    wheel = d < 43 ? 3'd7 : d < 64 ? 3'd5 : d < 85 ? 3'd2 : 3'd0;\n  end\nendfunction\n// stage 3\nreg c3 = 0, in3 = 0, fr3 = 0;\nreg [7:0] col3 = 0;\nwire [2:0] wr = wheel(hue), wg = wheel(hue - 8'd85), wb = wheel(hue - 8'd170);\nalways @(posedge clk) begin\n  c3 <= c2 && in2; in3 <= in2; fr3 <= fr2;\n  col3 <= {wr, wg, wb[2:1]};\nend\nassign cell = c3;\nassign ingrid = in3;\nassign frame = fr3;\nassign color = col3;\n"
          },
          "id": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
          "position": {
            "x": 600,
            "y": 2200
          },
          "size": {
            "width": 620,
            "height": 720
          }
        },
        {
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "x",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "y",
                  "range": "[9:0]",
                  "size": 10
                },
                {
                  "name": "gfx",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "scene",
                  "range": "[2:0]",
                  "size": 3
                }
              ]
            },
            "params": [],
            "code": "// Scene director\n// Cycles through the scenes on its own (~70 s loop), or holds the one the\n// PC asks for (bridge command 'G': 0-7, 255 = cycle).\n//   0 Life, rainbow cells         4 Life over the interference\n//   1 plasma                      5 interference\n//   2 Life over the plasma        6 all 256 colours\n//   3 XOR fractal                 7 Life, rainbow cells over XOR\nreg [7:0] g1 = 8'hFF, g2 = 8'hFF;         // from the 24 MHz side\nreg [5:0] fr = 0;                         // 64 frames = ~1 s\nreg [3:0] left = 10;\nreg [2:0] step = 0, s = 0;\nwire tick = (x == 0) && (y == 480) && (fr == 63);\nfunction [3:0] len(input [2:0] i);        // seconds per scene, minus 1\n  len = (i == 0 || i == 2 || i == 4 || i == 7) ? 4'd9 : 4'd5;\nendfunction\nalways @(posedge clk) begin\n  g1 <= gfx; g2 <= g1;\n  if ((x == 0) && (y == 480)) fr <= fr + 1;\n  if (tick) begin\n    if (left == 0) begin step <= step + 1; left <= len(step + 3'd1); end\n    else left <= left - 1;\n  end\n  if ((x == 0) && (y == 480))             // change scene between frames\n    s <= g2[7] ? step : g2[2:0];\nend\nassign scene = s;\n"
          },
          "id": "6ab860e1-5288-4f70-bab1-3652aff90586",
          "position": {
            "x": 600,
            "y": 1080
          },
          "size": {
            "width": 480,
            "height": 560
          }
        },
        {
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "scene",
                  "range": "[2:0]",
                  "size": 3
                },
                {
                  "name": "fx1",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "fx2",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "fx3",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "fx4",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "cell"
                },
                {
                  "name": "ingrid"
                },
                {
                  "name": "frame"
                },
                {
                  "name": "color",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "hs"
                },
                {
                  "name": "vs"
                },
                {
                  "name": "de"
                }
              ],
              "out": [
                {
                  "name": "r",
                  "range": "[2:0]",
                  "size": 3
                },
                {
                  "name": "g",
                  "range": "[2:0]",
                  "size": 3
                },
                {
                  "name": "b",
                  "range": "[1:0]",
                  "size": 2
                },
                {
                  "name": "hsync"
                },
                {
                  "name": "vsync"
                }
              ]
            },
            "params": [],
            "code": "// Compositor + VGA output\n// Every effect and the Life layer are computed for every pixel, all the\n// time; this block layers them according to the scene. The inputs are\n// 3 clocks behind the beam, so sync and blanking are delayed to match.\nreg [2:0] hsd = 3'b111, vsd = 3'b111, ded = 0;\nreg [7:0] px = 0;\nreg hso = 1, vso = 1;\nfunction [7:0] dim(input [7:0] c);        // half brightness\n  dim = {1'b0, c[7:6], 1'b0, c[4:3], 1'b0, c[1]};\nendfunction\nwire life_on = scene == 0 || scene == 2 || scene == 4 || scene == 7;\nwire rainbow = scene == 0 || scene == 7;\nreg [7:0] back;\nalways @(*) begin\n  case (scene)\n    0: back = 8'b000_000_01;              // dark blue\n    1: back = fx1;\n    2: back = dim(fx1);\n    3: back = fx2;\n    4: back = dim(fx3);\n    5: back = fx3;\n    6: back = fx4;\n    default: back = dim(dim(fx2));\n  endcase\nend\nalways @(posedge clk) begin\n  hsd <= {hsd[1:0], hs};\n  vsd <= {vsd[1:0], vs};\n  ded <= {ded[1:0], de};\n  if (!ded[2]) px <= 8'd0;\n  else if (life_on && cell) px <= rainbow ? color : 8'hFF;\n  else if (life_on && ingrid) px <= scene == 0 ? 8'd0 : back;\n  else if (life_on && frame) px <= 8'b101_101_10;\n  else px <= back;\n  hso <= hsd[2];\n  vso <= vsd[2];\nend\nassign r = px[7:5];\nassign g = px[4:2];\nassign b = px[1:0];\nassign hsync = hso;\nassign vsync = vso;\n"
          },
          "id": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
          "position": {
            "x": 2200,
            "y": 1700
          },
          "size": {
            "width": 620,
            "height": 640
          }
        },
        {
          "id": "7a01043c-ec2c-4e91-a5e5-4791ea21c0f5",
          "type": "basic.input",
          "data": {
            "name": "RX",
            "pins": [
              {
                "index": "0",
                "name": "RX",
                "value": "46"
              }
            ],
            "virtual": false,
            "clock": false
          },
          "position": {
            "x": 40,
            "y": 200
          }
        },
        {
          "id": "5208719d-2905-45d0-a87b-00d4c8bd0dce",
          "type": "basic.output",
          "data": {
            "name": "TX",
            "pins": [
              {
                "index": "0",
                "name": "TX",
                "value": "47"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 2760,
            "y": 600
          }
        },
        {
          "id": "cfefc8fc-b480-460b-bef9-b7bf281bbb4c",
          "type": "basic.input",
          "data": {
            "name": "BTN",
            "pins": [
              {
                "index": "0",
                "name": "BTN",
                "value": "6"
              }
            ],
            "virtual": false,
            "clock": false
          },
          "position": {
            "x": 1940,
            "y": 1040
          }
        },
        {
          "id": "38617af2-e2dd-413d-af2a-11348fcc25bc",
          "type": "basic.input",
          "data": {
            "name": "USB_INT",
            "pins": [
              {
                "index": "0",
                "name": "USB_INT",
                "value": "4"
              }
            ],
            "virtual": false,
            "clock": false
          },
          "position": {
            "x": 1940,
            "y": 1140
          }
        },
        {
          "id": "08a24b66-65b4-4a43-9136-85cbf8be118b",
          "type": "basic.input",
          "data": {
            "name": "SD_MISO",
            "pins": [
              {
                "index": "0",
                "name": "SD_MISO",
                "value": "45"
              }
            ],
            "virtual": false,
            "clock": false
          },
          "position": {
            "x": 1940,
            "y": 1240
          }
        },
        {
          "id": "30b4c6d7-f3ec-4456-822d-3826b0439530",
          "type": "basic.output",
          "data": {
            "name": "LED",
            "pins": [
              {
                "index": "0",
                "name": "LED",
                "value": "9"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 980
          }
        },
        {
          "id": "d1902b1a-a307-49b0-94fb-0b65d9a1ee2a",
          "type": "basic.output",
          "data": {
            "name": "SD_SCK",
            "pins": [
              {
                "index": "0",
                "name": "SD_SCK",
                "value": "44"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1080
          }
        },
        {
          "id": "c6cc5fd3-3155-433d-9a8e-08c1567026c1",
          "type": "basic.output",
          "data": {
            "name": "SD_MOSI",
            "pins": [
              {
                "index": "0",
                "name": "SD_MOSI",
                "value": "48"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1180
          }
        },
        {
          "id": "bdcd152c-a860-4834-b48d-a5718413cac9",
          "type": "basic.output",
          "data": {
            "name": "SD_CS",
            "pins": [
              {
                "index": "0",
                "name": "SD_CS",
                "value": "10"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1280
          }
        },
        {
          "id": "57f0e6aa-89b3-4305-9cfc-852fc043cb4e",
          "type": "basic.output",
          "data": {
            "name": "USB_CS",
            "pins": [
              {
                "index": "0",
                "name": "USB_CS",
                "value": "2"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1380
          }
        },
        {
          "id": "15199c72-098a-4085-9088-17dbc6a4a963",
          "type": "basic.output",
          "data": {
            "name": "USB_RST",
            "pins": [
              {
                "index": "0",
                "name": "USB_RST",
                "value": "3"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1480
          }
        },
        {
          "id": "de37a619-15d8-414e-a094-c685f52f6df5",
          "type": "basic.output",
          "data": {
            "name": "RGB0",
            "pins": [
              {
                "index": "0",
                "name": "RGB0",
                "value": "39"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1580
          }
        },
        {
          "id": "a009a495-a4a7-4cf1-bf7b-443c8dbf9243",
          "type": "basic.output",
          "data": {
            "name": "RGB1",
            "pins": [
              {
                "index": "0",
                "name": "RGB1",
                "value": "40"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1680
          }
        },
        {
          "id": "ecdeeadb-0113-406d-b318-9681c245c0a2",
          "type": "basic.output",
          "data": {
            "name": "RGB2",
            "pins": [
              {
                "index": "0",
                "name": "RGB2",
                "value": "41"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 1780
          }
        },
        {
          "id": "4216f2a5-46ad-4718-939c-9f5dddd51ea7",
          "type": "basic.output",
          "data": {
            "name": "VGA_R",
            "pins": [
              {
                "index": "2",
                "name": "VGA_R2",
                "value": "21"
              },
              {
                "index": "1",
                "name": "VGA_R1",
                "value": "13"
              },
              {
                "index": "0",
                "name": "VGA_R0",
                "value": "20"
              }
            ],
            "virtual": false,
            "range": "[2:0]"
          },
          "position": {
            "x": 3200,
            "y": 1700
          }
        },
        {
          "id": "05a34e42-4f6e-4ad5-ba2d-71f98ee0265e",
          "type": "basic.output",
          "data": {
            "name": "VGA_G",
            "pins": [
              {
                "index": "2",
                "name": "VGA_G2",
                "value": "19"
              },
              {
                "index": "1",
                "name": "VGA_G1",
                "value": "18"
              },
              {
                "index": "0",
                "name": "VGA_G0",
                "value": "25"
              }
            ],
            "virtual": false,
            "range": "[2:0]"
          },
          "position": {
            "x": 3200,
            "y": 1800
          }
        },
        {
          "id": "46629e16-aa4b-4baa-a638-4c2c3beeb7dd",
          "type": "basic.output",
          "data": {
            "name": "VGA_B",
            "pins": [
              {
                "index": "1",
                "name": "VGA_B1",
                "value": "23"
              },
              {
                "index": "0",
                "name": "VGA_B0",
                "value": "27"
              }
            ],
            "virtual": false,
            "range": "[1:0]"
          },
          "position": {
            "x": 3200,
            "y": 1900
          }
        },
        {
          "id": "da453713-3966-48d5-8458-9a7b1f72568c",
          "type": "basic.output",
          "data": {
            "name": "HSYNC",
            "pins": [
              {
                "index": "0",
                "name": "HSYNC",
                "value": "26"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 2000
          }
        },
        {
          "id": "a11d8323-3457-47d8-8cc8-f2f17f68646c",
          "type": "basic.output",
          "data": {
            "name": "VSYNC",
            "pins": [
              {
                "index": "0",
                "name": "VSYNC",
                "value": "28"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 3200,
            "y": 2100
          }
        },
        {
          "id": "d3a9e13f-daa8-45e6-b28c-61a80fe6107e",
          "type": "basic.info",
          "data": {
            "info": "## Icey showcase + VGA\n\nRun `./firmware/life-demo.sh --vga` (it builds and loads this project) with a VGA monitor plugged into the board. Everything from the showcase still runs: Life engine, microSD, USB keyboard, button and RGB LED over one 3 Mbaud link. On top of that the VGA port shows the **live Life grid**, and cycles through colour schemes and the racing-the-beam effects from `vga_demo.ice`.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": -300
          },
          "size": {
            "width": 960,
            "height": 220
          }
        },
        {
          "id": "50f99fe2-e389-4939-99b3-c6b9cb2fbb01",
          "type": "basic.info",
          "data": {
            "info": "### Why this needs an FPGA\n\n* The Life engine computes a whole 128-cell row per clock at 24 MHz, while the VGA side draws 25 million pixels a second at 25 MHz. Two clock domains, one chip, neither waits for the other.\n* Every pixel, **all four effects and the Life layer are computed at once**; the compositor just picks how to layer them.\n* No framebuffer: the display keeps a 2 KB copy of the grid and everything else is computed as the beam draws it.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": 700
          },
          "size": {
            "width": 480,
            "height": 340
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "clk"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "wclk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "555182f5-f94e-4d92-beea-0f056105125b",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "data"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "valid"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "data"
          },
          "target": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "data"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "life_rx_valid"
          },
          "target": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "io_rx_valid"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "cmd_idle"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "life_idle"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "idle"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "io_idle"
          }
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "tx_data"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "life_tx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "tx_send"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "life_tx_send"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "tx_data"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "io_tx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "tx_send"
          },
          "target": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "io_tx_send"
          }
        },
        {
          "source": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "tx_data"
          },
          "target": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "a54047b6-b791-41ce-a18b-7fc61ce95943",
            "port": "tx_send"
          },
          "target": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "send"
          }
        },
        {
          "source": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "busy"
          },
          "target": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "tx_busy"
          }
        },
        {
          "source": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "busy"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "tx_busy"
          }
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "above"
          },
          "target": {
            "block": "9a96b1fd-34db-4814-b871-deab4e9022a4",
            "port": "above"
          },
          "size": 128
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "row"
          },
          "target": {
            "block": "9a96b1fd-34db-4814-b871-deab4e9022a4",
            "port": "row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "below"
          },
          "target": {
            "block": "9a96b1fd-34db-4814-b871-deab4e9022a4",
            "port": "below"
          },
          "size": 128
        },
        {
          "source": {
            "block": "9a96b1fd-34db-4814-b871-deab4e9022a4",
            "port": "new_row"
          },
          "target": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "new_row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "led"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "life_led"
          }
        },
        {
          "source": {
            "block": "7a01043c-ec2c-4e91-a5e5-4791ea21c0f5",
            "port": "out"
          },
          "target": {
            "block": "23ece895-14a0-4d3f-9624-af197c278a3d",
            "port": "rx"
          }
        },
        {
          "source": {
            "block": "e287aef8-e066-4261-bcbd-61bc661993b9",
            "port": "tx"
          },
          "target": {
            "block": "5208719d-2905-45d0-a87b-00d4c8bd0dce",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "cfefc8fc-b480-460b-bef9-b7bf281bbb4c",
            "port": "out"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "btn"
          }
        },
        {
          "source": {
            "block": "38617af2-e2dd-413d-af2a-11348fcc25bc",
            "port": "out"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "usb_int"
          }
        },
        {
          "source": {
            "block": "08a24b66-65b4-4a43-9136-85cbf8be118b",
            "port": "out"
          },
          "target": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "sd_miso"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "led"
          },
          "target": {
            "block": "30b4c6d7-f3ec-4456-822d-3826b0439530",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "sd_sck"
          },
          "target": {
            "block": "d1902b1a-a307-49b0-94fb-0b65d9a1ee2a",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "sd_mosi"
          },
          "target": {
            "block": "c6cc5fd3-3155-433d-9a8e-08c1567026c1",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "sd_cs"
          },
          "target": {
            "block": "bdcd152c-a860-4834-b48d-a5718413cac9",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "usb_cs"
          },
          "target": {
            "block": "57f0e6aa-89b3-4305-9cfc-852fc043cb4e",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "usb_rst"
          },
          "target": {
            "block": "15199c72-098a-4085-9088-17dbc6a4a963",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "rgb0"
          },
          "target": {
            "block": "de37a619-15d8-414e-a094-c685f52f6df5",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "rgb1"
          },
          "target": {
            "block": "a009a495-a4a7-4cf1-bf7b-443c8dbf9243",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "rgb2"
          },
          "target": {
            "block": "ecdeeadb-0113-406d-b318-9681c245c0a2",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "disp_we"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "we"
          }
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "disp_row"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "wrow"
          },
          "size": 7
        },
        {
          "source": {
            "block": "ef0dd1e7-819e-4399-8406-4fc9dcc26a0d",
            "port": "disp_data"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "wdata"
          },
          "size": 128
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "t"
          },
          "target": {
            "block": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "555182f5-f94e-4d92-beea-0f056105125b",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "555182f5-f94e-4d92-beea-0f056105125b",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "t"
          },
          "target": {
            "block": "555182f5-f94e-4d92-beea-0f056105125b",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "t"
          },
          "target": {
            "block": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "t"
          },
          "target": {
            "block": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "t"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "y"
          },
          "target": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "gfx"
          },
          "target": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "gfx"
          },
          "size": 8
        },
        {
          "source": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "scene"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "scene"
          },
          "size": 3
        },
        {
          "source": {
            "block": "e5c36f28-fdeb-4a09-8f5a-e8f22e663bbf",
            "port": "rgb"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "fx1"
          },
          "size": 8
        },
        {
          "source": {
            "block": "555182f5-f94e-4d92-beea-0f056105125b",
            "port": "rgb"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "fx2"
          },
          "size": 8
        },
        {
          "source": {
            "block": "b1f45904-d4fc-4a13-8c7b-32448ae863f4",
            "port": "rgb"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "fx3"
          },
          "size": 8
        },
        {
          "source": {
            "block": "4419ad56-d167-459b-93ca-1fb4c61d3ab8",
            "port": "rgb"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "fx4"
          },
          "size": 8
        },
        {
          "source": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "cell"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "cell"
          }
        },
        {
          "source": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "ingrid"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "ingrid"
          }
        },
        {
          "source": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "frame"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "frame"
          }
        },
        {
          "source": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "color"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "color"
          },
          "size": 8
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "hs"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "hs"
          }
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "vs"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "vs"
          }
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "de"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "de"
          }
        },
        {
          "source": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "r"
          },
          "target": {
            "block": "4216f2a5-46ad-4718-939c-9f5dddd51ea7",
            "port": "in"
          },
          "size": 3
        },
        {
          "source": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "g"
          },
          "target": {
            "block": "05a34e42-4f6e-4ad5-ba2d-71f98ee0265e",
            "port": "in"
          },
          "size": 3
        },
        {
          "source": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "b"
          },
          "target": {
            "block": "46629e16-aa4b-4baa-a638-4c2c3beeb7dd",
            "port": "in"
          },
          "size": 2
        },
        {
          "source": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "hsync"
          },
          "target": {
            "block": "da453713-3966-48d5-8458-9a7b1f72568c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "vsync"
          },
          "target": {
            "block": "a11d8323-3457-47d8-8cc8-f2f17f68646c",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}