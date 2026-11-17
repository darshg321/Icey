{
  "version": "1.2",
  "package": {
    "name": "Icey showcase + VGA",
    "version": "1.0",
    "description": "The showcase (Game of Life, SD, USB host, typing test) shown on a VGA monitor: live grid, text layer and effects",
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
            "code": "// Command router\n// One UART, two command sets: S L V N go to the Life engine,\n// X Y C D I G T go to the I/O bridge. The first byte of a command picks the\n// owner, which then gets every byte until it is back to idle.\nreg [1:0] owner = 0;              // 0 none, 1 life, 2 io\nreg started = 0;\nwire is_life = rx_data == \"S\" || rx_data == \"L\" || rx_data == \"V\" || rx_data == \"N\";\nwire is_io   = rx_data == \"X\" || rx_data == \"Y\" || rx_data == \"C\" || rx_data == \"D\" ||\n               rx_data == \"I\" || rx_data == \"G\" || rx_data == \"T\";\nwire [1:0] route = owner != 0 ? owner : is_life ? 2'd1 : is_io ? 2'd2 : 2'd0;\nwire sub_idle = owner == 1 ? life_idle : io_idle;\nalways @(posedge clk) begin\n  if (owner == 0) begin\n    if (rx_valid && route != 0) begin owner <= route; started <= 0; end\n  end else if (!sub_idle) started <= 1;\n  else if (started) owner <= 0;\nend\nassign life_rx_valid = rx_valid && route == 1;\nassign io_rx_valid   = rx_valid && route == 2;\nassign tx_send = life_tx_send | io_tx_send;\nassign tx_data = life_tx_send ? life_tx_data : io_tx_data;\n"
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
                },
                {
                  "name": "txt_addr",
                  "range": "[11:0]",
                  "size": 12
                },
                {
                  "name": "txt_data",
                  "range": "[15:0]",
                  "size": 16
                },
                {
                  "name": "txt_tog"
                }
              ]
            },
            "params": [],
            "code": "// I/O bridge: SPI (SD + USB host), button, LEDs\n// Lets the PC use the board's peripherals through the FPGA:\n//   'X' n data      SPI exchange of n bytes (0 = 256), replies n bytes\n//   'Y' cs n data   same, with chip selects in mask cs (bit0 SD, bit1 USB)\n//                   pulled low around the transfer\n//   'C' v           bit0 SD_CS, bit1 USB_CS, bit2 USB_RST, bit3 LED1,\n//                   bit4 red, bit5 blue, bit6 green                -> 'k'\n//   'D' d           SPI clock = 24 MHz / (2*(d+1))                 -> 'k'\n//   'I'             bit0 SW2 (1 = released), bit1 USB_INT, bit2 SD_MISO\n//   'G' s           VGA scene: bit7 = cycle on its own, bit6 = hide the\n//                   text, bit5 = Life grid centred, bits 3-0 = scene to\n//                   hold (255 = cycle, no text: the power-up default) -> 'k'\n//   'T' ah al n (ch col)*n   VGA text: write n cells (0 = 256) starting\n//                   at cell {ah, al} = row*128 + column               -> 'k'\n\n// ---- SPI master, mode 0 ----\nreg [7:0] div = 29;\nreg [7:0] scnt = 0; reg [2:0] sbit = 0;\nreg [7:0] stx = 0, srx = 0, sin = 0;\nreg sck = 0, sbusy = 0, sgo = 0, sdone = 0;\nalways @(posedge clk) begin\n  sdone <= 0;\n  if (!sbusy) begin\n    if (sgo) begin sbusy <= 1; stx <= sin; sbit <= 0; scnt <= div; sck <= 0; end\n  end else if (scnt != 0) scnt <= scnt - 1;\n  else begin\n    scnt <= div;\n    if (!sck) begin sck <= 1; srx <= {srx[6:0], sd_miso}; end\n    else begin\n      sck <= 0;\n      if (sbit == 7) begin sbusy <= 0; sdone <= 1; end\n      else begin sbit <= sbit + 1; stx <= {stx[6:0], 1'b0}; end\n    end\n  end\nend\nassign sd_sck = sck;\nassign sd_mosi = stx[7];\n\n// ---- command handler ----\nreg [7:0] outs = 8'b0000_0111;\nreg [7:0] scene = 8'hFF;\nreg [1:0] csm = 0;                         // chip selects held low during 'Y'\nreg [7:0] buffer [0:255];\nreg [7:0] bwa = 0, bra = 0, bwd = 0, brd = 0; reg bwe = 0;\nalways @(posedge clk) begin\n  if (bwe) buffer[bwa] <= bwd;\n  brd <= buffer[bra];\nend\nlocalparam IDLE = 0, LEN = 1, FILL = 2, XRD = 3, XGO = 4, XWAIT = 5, SEND_RD = 6,\n           SEND = 7, ARG = 8, ACK = 9, INP = 10, CSB = 11,\n           TAH = 12, TAL = 13, TLEN = 14, TCH = 15, TCOL = 16;\nreg [4:0] st = IDLE; reg [7:0] cmd = 0; reg [8:0] n = 0, i = 0; reg [1:0] w = 0;\nreg [7:0] txd = 0; reg txs = 0;\n// text cell write for the VGA side: address and data stay put until the\n// next cell (many clocks later), the toggle tells the pixel clock side\nreg [11:0] taddr = 0; reg [15:0] tdata = 0; reg [7:0] tch = 0; reg ttog = 0;\nalways @(posedge clk) begin\n  txs <= 0; sgo <= 0; bwe <= 0;\n  case (st)\n    IDLE: if (rx_valid) begin\n      cmd <= rx_data;\n      if (rx_data == \"X\") st <= LEN;\n      else if (rx_data == \"Y\") st <= CSB;\n      else if (rx_data == \"C\" || rx_data == \"D\" || rx_data == \"G\") st <= ARG;\n      else if (rx_data == \"I\") st <= INP;\n      else if (rx_data == \"T\") st <= TAH;\n    end\n    CSB:  if (rx_valid) begin csm <= rx_data[1:0]; st <= LEN; end\n    LEN:  if (rx_valid) begin n <= (rx_data == 0) ? 9'd256 : {1'b0, rx_data}; i <= 0; st <= FILL; end\n    FILL: if (rx_valid) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= rx_data; i <= i + 1;\n      if (i + 1 == n) begin i <= 0; st <= XRD; w <= 0; end\n    end\n    XRD:  begin bra <= i[7:0]; w <= w + 1; if (w == 2) st <= XGO; end\n    XGO:  begin sin <= brd; sgo <= 1; st <= XWAIT; end\n    XWAIT: if (sdone) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= srx; i <= i + 1; w <= 0;\n      if (i + 1 == n) begin i <= 0; csm <= 0; st <= SEND_RD; end\n      else st <= XRD;\n    end\n    SEND_RD: begin bra <= i[7:0]; w <= w + 1; if (w == 2) begin w <= 0; st <= SEND; end end\n    SEND: if (!tx_busy && !txs) begin\n      txd <= brd; txs <= 1; i <= i + 1;\n      st <= (i + 1 == n) ? IDLE : SEND_RD;\n    end\n    ARG:  if (rx_valid) begin\n      if (cmd == \"C\") outs <= rx_data;\n      else if (cmd == \"G\") scene <= rx_data;\n      else div <= rx_data;\n      st <= ACK;\n    end\n    TAH:  if (rx_valid) begin taddr[11:8] <= rx_data[3:0]; st <= TAL; end\n    TAL:  if (rx_valid) begin taddr[7:0] <= rx_data; st <= TLEN; end\n    TLEN: if (rx_valid) begin n <= (rx_data == 0) ? 9'd256 : {1'b0, rx_data}; i <= 0; st <= TCH; end\n    TCH:  if (rx_valid) begin\n      tch <= rx_data; st <= TCOL;\n      if (i != 0) taddr <= taddr + 1;      // previous cell is written by now\n    end\n    TCOL: if (rx_valid) begin\n      tdata <= {rx_data, tch}; ttog <= ~ttog; i <= i + 1;\n      st <= (i + 1 == n) ? ACK : TCH;\n    end\n    ACK:  if (!tx_busy && !txs) begin txd <= \"k\"; txs <= 1; st <= IDLE; end\n    INP:  if (!tx_busy && !txs) begin txd <= {5'b0, sd_miso, usb_int, btn}; txs <= 1; st <= IDLE; end\n  endcase\nend\nassign tx_data = txd;\nassign tx_send = txs;\nassign idle = (st == IDLE);\nassign gfx = scene;\nassign txt_addr = taddr;\nassign txt_data = tdata;\nassign txt_tog = ttog;\n\nassign sd_cs   = outs[0] & ~csm[0];\nassign usb_cs  = outs[1] & ~csm[1];\nassign usb_rst = outs[2];\nassign led     = life_led | outs[3] | ~btn;     // also lights while SW2 is held\nSB_RGBA_DRV #(.CURRENT_MODE(\"0b1\"), .RGB0_CURRENT(\"0b000011\"),\n              .RGB1_CURRENT(\"0b000011\"), .RGB2_CURRENT(\"0b000011\")) rgb (\n  .CURREN(1'b1), .RGBLEDEN(1'b1),\n  .RGB0PWM(outs[4]), .RGB1PWM(outs[5]), .RGB2PWM(outs[6]),\n  .RGB0(rgb0), .RGB1(rgb1), .RGB2(rgb2));\n"
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
            "code": "// Effect 1: sine plasma\n// 4 sine waves summed per pixel, then a 3-sine palette:\n// 7 sine lookups for EVERY pixel, 25 million times a second.\n// The sines are tables in block RAM: one copy per wave (a block RAM has\n// one read port), plus one table holding all three palette sines, so the\n// effect costs almost no logic.\nreg [7:0] sin1 [0:255], sin2 [0:255], sin3 [0:255], sin4 [0:255];  // 128 + 127*sin(2*pi*a/256)\nreg [7:0] pal [0:255];         // {sin(v)[7:5], sin(v+85)[7:5], sin(v+170)[7:6]}\ninitial begin\n  sin1[0]=8'd130; sin1[1]=8'd133; sin1[2]=8'd136; sin1[3]=8'd139; sin1[4]=8'd142; sin1[5]=8'd145; sin1[6]=8'd148; sin1[7]=8'd151;\n  sin1[8]=8'd154; sin1[9]=8'd157; sin1[10]=8'd160; sin1[11]=8'd163; sin1[12]=8'd166; sin1[13]=8'd169; sin1[14]=8'd172; sin1[15]=8'd175;\n  sin1[16]=8'd178; sin1[17]=8'd181; sin1[18]=8'd184; sin1[19]=8'd186; sin1[20]=8'd189; sin1[21]=8'd192; sin1[22]=8'd195; sin1[23]=8'd197;\n  sin1[24]=8'd200; sin1[25]=8'd202; sin1[26]=8'd205; sin1[27]=8'd207; sin1[28]=8'd210; sin1[29]=8'd212; sin1[30]=8'd214; sin1[31]=8'd217;\n  sin1[32]=8'd219; sin1[33]=8'd221; sin1[34]=8'd223; sin1[35]=8'd225; sin1[36]=8'd227; sin1[37]=8'd229; sin1[38]=8'd231; sin1[39]=8'd233;\n  sin1[40]=8'd234; sin1[41]=8'd236; sin1[42]=8'd238; sin1[43]=8'd239; sin1[44]=8'd241; sin1[45]=8'd242; sin1[46]=8'd243; sin1[47]=8'd245;\n  sin1[48]=8'd246; sin1[49]=8'd247; sin1[50]=8'd248; sin1[51]=8'd249; sin1[52]=8'd250; sin1[53]=8'd251; sin1[54]=8'd252; sin1[55]=8'd252;\n  sin1[56]=8'd253; sin1[57]=8'd253; sin1[58]=8'd254; sin1[59]=8'd254; sin1[60]=8'd255; sin1[61]=8'd255; sin1[62]=8'd255; sin1[63]=8'd255;\n  sin1[64]=8'd255; sin1[65]=8'd255; sin1[66]=8'd255; sin1[67]=8'd255; sin1[68]=8'd254; sin1[69]=8'd254; sin1[70]=8'd253; sin1[71]=8'd253;\n  sin1[72]=8'd252; sin1[73]=8'd252; sin1[74]=8'd251; sin1[75]=8'd250; sin1[76]=8'd249; sin1[77]=8'd248; sin1[78]=8'd247; sin1[79]=8'd246;\n  sin1[80]=8'd245; sin1[81]=8'd243; sin1[82]=8'd242; sin1[83]=8'd241; sin1[84]=8'd239; sin1[85]=8'd238; sin1[86]=8'd236; sin1[87]=8'd234;\n  sin1[88]=8'd233; sin1[89]=8'd231; sin1[90]=8'd229; sin1[91]=8'd227; sin1[92]=8'd225; sin1[93]=8'd223; sin1[94]=8'd221; sin1[95]=8'd219;\n  sin1[96]=8'd217; sin1[97]=8'd214; sin1[98]=8'd212; sin1[99]=8'd210; sin1[100]=8'd207; sin1[101]=8'd205; sin1[102]=8'd202; sin1[103]=8'd200;\n  sin1[104]=8'd197; sin1[105]=8'd195; sin1[106]=8'd192; sin1[107]=8'd189; sin1[108]=8'd186; sin1[109]=8'd184; sin1[110]=8'd181; sin1[111]=8'd178;\n  sin1[112]=8'd175; sin1[113]=8'd172; sin1[114]=8'd169; sin1[115]=8'd166; sin1[116]=8'd163; sin1[117]=8'd160; sin1[118]=8'd157; sin1[119]=8'd154;\n  sin1[120]=8'd151; sin1[121]=8'd148; sin1[122]=8'd145; sin1[123]=8'd142; sin1[124]=8'd139; sin1[125]=8'd136; sin1[126]=8'd133; sin1[127]=8'd130;\n  sin1[128]=8'd125; sin1[129]=8'd122; sin1[130]=8'd119; sin1[131]=8'd116; sin1[132]=8'd113; sin1[133]=8'd110; sin1[134]=8'd107; sin1[135]=8'd104;\n  sin1[136]=8'd101; sin1[137]=8'd98; sin1[138]=8'd95; sin1[139]=8'd92; sin1[140]=8'd89; sin1[141]=8'd86; sin1[142]=8'd83; sin1[143]=8'd80;\n  sin1[144]=8'd77; sin1[145]=8'd74; sin1[146]=8'd71; sin1[147]=8'd69; sin1[148]=8'd66; sin1[149]=8'd63; sin1[150]=8'd60; sin1[151]=8'd58;\n  sin1[152]=8'd55; sin1[153]=8'd53; sin1[154]=8'd50; sin1[155]=8'd48; sin1[156]=8'd45; sin1[157]=8'd43; sin1[158]=8'd41; sin1[159]=8'd38;\n  sin1[160]=8'd36; sin1[161]=8'd34; sin1[162]=8'd32; sin1[163]=8'd30; sin1[164]=8'd28; sin1[165]=8'd26; sin1[166]=8'd24; sin1[167]=8'd22;\n  sin1[168]=8'd21; sin1[169]=8'd19; sin1[170]=8'd17; sin1[171]=8'd16; sin1[172]=8'd14; sin1[173]=8'd13; sin1[174]=8'd12; sin1[175]=8'd10;\n  sin1[176]=8'd9; sin1[177]=8'd8; sin1[178]=8'd7; sin1[179]=8'd6; sin1[180]=8'd5; sin1[181]=8'd4; sin1[182]=8'd3; sin1[183]=8'd3;\n  sin1[184]=8'd2; sin1[185]=8'd2; sin1[186]=8'd1; sin1[187]=8'd1; sin1[188]=8'd0; sin1[189]=8'd0; sin1[190]=8'd0; sin1[191]=8'd0;\n  sin1[192]=8'd0; sin1[193]=8'd0; sin1[194]=8'd0; sin1[195]=8'd0; sin1[196]=8'd1; sin1[197]=8'd1; sin1[198]=8'd2; sin1[199]=8'd2;\n  sin1[200]=8'd3; sin1[201]=8'd3; sin1[202]=8'd4; sin1[203]=8'd5; sin1[204]=8'd6; sin1[205]=8'd7; sin1[206]=8'd8; sin1[207]=8'd9;\n  sin1[208]=8'd10; sin1[209]=8'd12; sin1[210]=8'd13; sin1[211]=8'd14; sin1[212]=8'd16; sin1[213]=8'd17; sin1[214]=8'd19; sin1[215]=8'd21;\n  sin1[216]=8'd22; sin1[217]=8'd24; sin1[218]=8'd26; sin1[219]=8'd28; sin1[220]=8'd30; sin1[221]=8'd32; sin1[222]=8'd34; sin1[223]=8'd36;\n  sin1[224]=8'd38; sin1[225]=8'd41; sin1[226]=8'd43; sin1[227]=8'd45; sin1[228]=8'd48; sin1[229]=8'd50; sin1[230]=8'd53; sin1[231]=8'd55;\n  sin1[232]=8'd58; sin1[233]=8'd60; sin1[234]=8'd63; sin1[235]=8'd66; sin1[236]=8'd69; sin1[237]=8'd71; sin1[238]=8'd74; sin1[239]=8'd77;\n  sin1[240]=8'd80; sin1[241]=8'd83; sin1[242]=8'd86; sin1[243]=8'd89; sin1[244]=8'd92; sin1[245]=8'd95; sin1[246]=8'd98; sin1[247]=8'd101;\n  sin1[248]=8'd104; sin1[249]=8'd107; sin1[250]=8'd110; sin1[251]=8'd113; sin1[252]=8'd116; sin1[253]=8'd119; sin1[254]=8'd122; sin1[255]=8'd125;\n  sin2[0]=8'd130; sin2[1]=8'd133; sin2[2]=8'd136; sin2[3]=8'd139; sin2[4]=8'd142; sin2[5]=8'd145; sin2[6]=8'd148; sin2[7]=8'd151;\n  sin2[8]=8'd154; sin2[9]=8'd157; sin2[10]=8'd160; sin2[11]=8'd163; sin2[12]=8'd166; sin2[13]=8'd169; sin2[14]=8'd172; sin2[15]=8'd175;\n  sin2[16]=8'd178; sin2[17]=8'd181; sin2[18]=8'd184; sin2[19]=8'd186; sin2[20]=8'd189; sin2[21]=8'd192; sin2[22]=8'd195; sin2[23]=8'd197;\n  sin2[24]=8'd200; sin2[25]=8'd202; sin2[26]=8'd205; sin2[27]=8'd207; sin2[28]=8'd210; sin2[29]=8'd212; sin2[30]=8'd214; sin2[31]=8'd217;\n  sin2[32]=8'd219; sin2[33]=8'd221; sin2[34]=8'd223; sin2[35]=8'd225; sin2[36]=8'd227; sin2[37]=8'd229; sin2[38]=8'd231; sin2[39]=8'd233;\n  sin2[40]=8'd234; sin2[41]=8'd236; sin2[42]=8'd238; sin2[43]=8'd239; sin2[44]=8'd241; sin2[45]=8'd242; sin2[46]=8'd243; sin2[47]=8'd245;\n  sin2[48]=8'd246; sin2[49]=8'd247; sin2[50]=8'd248; sin2[51]=8'd249; sin2[52]=8'd250; sin2[53]=8'd251; sin2[54]=8'd252; sin2[55]=8'd252;\n  sin2[56]=8'd253; sin2[57]=8'd253; sin2[58]=8'd254; sin2[59]=8'd254; sin2[60]=8'd255; sin2[61]=8'd255; sin2[62]=8'd255; sin2[63]=8'd255;\n  sin2[64]=8'd255; sin2[65]=8'd255; sin2[66]=8'd255; sin2[67]=8'd255; sin2[68]=8'd254; sin2[69]=8'd254; sin2[70]=8'd253; sin2[71]=8'd253;\n  sin2[72]=8'd252; sin2[73]=8'd252; sin2[74]=8'd251; sin2[75]=8'd250; sin2[76]=8'd249; sin2[77]=8'd248; sin2[78]=8'd247; sin2[79]=8'd246;\n  sin2[80]=8'd245; sin2[81]=8'd243; sin2[82]=8'd242; sin2[83]=8'd241; sin2[84]=8'd239; sin2[85]=8'd238; sin2[86]=8'd236; sin2[87]=8'd234;\n  sin2[88]=8'd233; sin2[89]=8'd231; sin2[90]=8'd229; sin2[91]=8'd227; sin2[92]=8'd225; sin2[93]=8'd223; sin2[94]=8'd221; sin2[95]=8'd219;\n  sin2[96]=8'd217; sin2[97]=8'd214; sin2[98]=8'd212; sin2[99]=8'd210; sin2[100]=8'd207; sin2[101]=8'd205; sin2[102]=8'd202; sin2[103]=8'd200;\n  sin2[104]=8'd197; sin2[105]=8'd195; sin2[106]=8'd192; sin2[107]=8'd189; sin2[108]=8'd186; sin2[109]=8'd184; sin2[110]=8'd181; sin2[111]=8'd178;\n  sin2[112]=8'd175; sin2[113]=8'd172; sin2[114]=8'd169; sin2[115]=8'd166; sin2[116]=8'd163; sin2[117]=8'd160; sin2[118]=8'd157; sin2[119]=8'd154;\n  sin2[120]=8'd151; sin2[121]=8'd148; sin2[122]=8'd145; sin2[123]=8'd142; sin2[124]=8'd139; sin2[125]=8'd136; sin2[126]=8'd133; sin2[127]=8'd130;\n  sin2[128]=8'd125; sin2[129]=8'd122; sin2[130]=8'd119; sin2[131]=8'd116; sin2[132]=8'd113; sin2[133]=8'd110; sin2[134]=8'd107; sin2[135]=8'd104;\n  sin2[136]=8'd101; sin2[137]=8'd98; sin2[138]=8'd95; sin2[139]=8'd92; sin2[140]=8'd89; sin2[141]=8'd86; sin2[142]=8'd83; sin2[143]=8'd80;\n  sin2[144]=8'd77; sin2[145]=8'd74; sin2[146]=8'd71; sin2[147]=8'd69; sin2[148]=8'd66; sin2[149]=8'd63; sin2[150]=8'd60; sin2[151]=8'd58;\n  sin2[152]=8'd55; sin2[153]=8'd53; sin2[154]=8'd50; sin2[155]=8'd48; sin2[156]=8'd45; sin2[157]=8'd43; sin2[158]=8'd41; sin2[159]=8'd38;\n  sin2[160]=8'd36; sin2[161]=8'd34; sin2[162]=8'd32; sin2[163]=8'd30; sin2[164]=8'd28; sin2[165]=8'd26; sin2[166]=8'd24; sin2[167]=8'd22;\n  sin2[168]=8'd21; sin2[169]=8'd19; sin2[170]=8'd17; sin2[171]=8'd16; sin2[172]=8'd14; sin2[173]=8'd13; sin2[174]=8'd12; sin2[175]=8'd10;\n  sin2[176]=8'd9; sin2[177]=8'd8; sin2[178]=8'd7; sin2[179]=8'd6; sin2[180]=8'd5; sin2[181]=8'd4; sin2[182]=8'd3; sin2[183]=8'd3;\n  sin2[184]=8'd2; sin2[185]=8'd2; sin2[186]=8'd1; sin2[187]=8'd1; sin2[188]=8'd0; sin2[189]=8'd0; sin2[190]=8'd0; sin2[191]=8'd0;\n  sin2[192]=8'd0; sin2[193]=8'd0; sin2[194]=8'd0; sin2[195]=8'd0; sin2[196]=8'd1; sin2[197]=8'd1; sin2[198]=8'd2; sin2[199]=8'd2;\n  sin2[200]=8'd3; sin2[201]=8'd3; sin2[202]=8'd4; sin2[203]=8'd5; sin2[204]=8'd6; sin2[205]=8'd7; sin2[206]=8'd8; sin2[207]=8'd9;\n  sin2[208]=8'd10; sin2[209]=8'd12; sin2[210]=8'd13; sin2[211]=8'd14; sin2[212]=8'd16; sin2[213]=8'd17; sin2[214]=8'd19; sin2[215]=8'd21;\n  sin2[216]=8'd22; sin2[217]=8'd24; sin2[218]=8'd26; sin2[219]=8'd28; sin2[220]=8'd30; sin2[221]=8'd32; sin2[222]=8'd34; sin2[223]=8'd36;\n  sin2[224]=8'd38; sin2[225]=8'd41; sin2[226]=8'd43; sin2[227]=8'd45; sin2[228]=8'd48; sin2[229]=8'd50; sin2[230]=8'd53; sin2[231]=8'd55;\n  sin2[232]=8'd58; sin2[233]=8'd60; sin2[234]=8'd63; sin2[235]=8'd66; sin2[236]=8'd69; sin2[237]=8'd71; sin2[238]=8'd74; sin2[239]=8'd77;\n  sin2[240]=8'd80; sin2[241]=8'd83; sin2[242]=8'd86; sin2[243]=8'd89; sin2[244]=8'd92; sin2[245]=8'd95; sin2[246]=8'd98; sin2[247]=8'd101;\n  sin2[248]=8'd104; sin2[249]=8'd107; sin2[250]=8'd110; sin2[251]=8'd113; sin2[252]=8'd116; sin2[253]=8'd119; sin2[254]=8'd122; sin2[255]=8'd125;\n  sin3[0]=8'd130; sin3[1]=8'd133; sin3[2]=8'd136; sin3[3]=8'd139; sin3[4]=8'd142; sin3[5]=8'd145; sin3[6]=8'd148; sin3[7]=8'd151;\n  sin3[8]=8'd154; sin3[9]=8'd157; sin3[10]=8'd160; sin3[11]=8'd163; sin3[12]=8'd166; sin3[13]=8'd169; sin3[14]=8'd172; sin3[15]=8'd175;\n  sin3[16]=8'd178; sin3[17]=8'd181; sin3[18]=8'd184; sin3[19]=8'd186; sin3[20]=8'd189; sin3[21]=8'd192; sin3[22]=8'd195; sin3[23]=8'd197;\n  sin3[24]=8'd200; sin3[25]=8'd202; sin3[26]=8'd205; sin3[27]=8'd207; sin3[28]=8'd210; sin3[29]=8'd212; sin3[30]=8'd214; sin3[31]=8'd217;\n  sin3[32]=8'd219; sin3[33]=8'd221; sin3[34]=8'd223; sin3[35]=8'd225; sin3[36]=8'd227; sin3[37]=8'd229; sin3[38]=8'd231; sin3[39]=8'd233;\n  sin3[40]=8'd234; sin3[41]=8'd236; sin3[42]=8'd238; sin3[43]=8'd239; sin3[44]=8'd241; sin3[45]=8'd242; sin3[46]=8'd243; sin3[47]=8'd245;\n  sin3[48]=8'd246; sin3[49]=8'd247; sin3[50]=8'd248; sin3[51]=8'd249; sin3[52]=8'd250; sin3[53]=8'd251; sin3[54]=8'd252; sin3[55]=8'd252;\n  sin3[56]=8'd253; sin3[57]=8'd253; sin3[58]=8'd254; sin3[59]=8'd254; sin3[60]=8'd255; sin3[61]=8'd255; sin3[62]=8'd255; sin3[63]=8'd255;\n  sin3[64]=8'd255; sin3[65]=8'd255; sin3[66]=8'd255; sin3[67]=8'd255; sin3[68]=8'd254; sin3[69]=8'd254; sin3[70]=8'd253; sin3[71]=8'd253;\n  sin3[72]=8'd252; sin3[73]=8'd252; sin3[74]=8'd251; sin3[75]=8'd250; sin3[76]=8'd249; sin3[77]=8'd248; sin3[78]=8'd247; sin3[79]=8'd246;\n  sin3[80]=8'd245; sin3[81]=8'd243; sin3[82]=8'd242; sin3[83]=8'd241; sin3[84]=8'd239; sin3[85]=8'd238; sin3[86]=8'd236; sin3[87]=8'd234;\n  sin3[88]=8'd233; sin3[89]=8'd231; sin3[90]=8'd229; sin3[91]=8'd227; sin3[92]=8'd225; sin3[93]=8'd223; sin3[94]=8'd221; sin3[95]=8'd219;\n  sin3[96]=8'd217; sin3[97]=8'd214; sin3[98]=8'd212; sin3[99]=8'd210; sin3[100]=8'd207; sin3[101]=8'd205; sin3[102]=8'd202; sin3[103]=8'd200;\n  sin3[104]=8'd197; sin3[105]=8'd195; sin3[106]=8'd192; sin3[107]=8'd189; sin3[108]=8'd186; sin3[109]=8'd184; sin3[110]=8'd181; sin3[111]=8'd178;\n  sin3[112]=8'd175; sin3[113]=8'd172; sin3[114]=8'd169; sin3[115]=8'd166; sin3[116]=8'd163; sin3[117]=8'd160; sin3[118]=8'd157; sin3[119]=8'd154;\n  sin3[120]=8'd151; sin3[121]=8'd148; sin3[122]=8'd145; sin3[123]=8'd142; sin3[124]=8'd139; sin3[125]=8'd136; sin3[126]=8'd133; sin3[127]=8'd130;\n  sin3[128]=8'd125; sin3[129]=8'd122; sin3[130]=8'd119; sin3[131]=8'd116; sin3[132]=8'd113; sin3[133]=8'd110; sin3[134]=8'd107; sin3[135]=8'd104;\n  sin3[136]=8'd101; sin3[137]=8'd98; sin3[138]=8'd95; sin3[139]=8'd92; sin3[140]=8'd89; sin3[141]=8'd86; sin3[142]=8'd83; sin3[143]=8'd80;\n  sin3[144]=8'd77; sin3[145]=8'd74; sin3[146]=8'd71; sin3[147]=8'd69; sin3[148]=8'd66; sin3[149]=8'd63; sin3[150]=8'd60; sin3[151]=8'd58;\n  sin3[152]=8'd55; sin3[153]=8'd53; sin3[154]=8'd50; sin3[155]=8'd48; sin3[156]=8'd45; sin3[157]=8'd43; sin3[158]=8'd41; sin3[159]=8'd38;\n  sin3[160]=8'd36; sin3[161]=8'd34; sin3[162]=8'd32; sin3[163]=8'd30; sin3[164]=8'd28; sin3[165]=8'd26; sin3[166]=8'd24; sin3[167]=8'd22;\n  sin3[168]=8'd21; sin3[169]=8'd19; sin3[170]=8'd17; sin3[171]=8'd16; sin3[172]=8'd14; sin3[173]=8'd13; sin3[174]=8'd12; sin3[175]=8'd10;\n  sin3[176]=8'd9; sin3[177]=8'd8; sin3[178]=8'd7; sin3[179]=8'd6; sin3[180]=8'd5; sin3[181]=8'd4; sin3[182]=8'd3; sin3[183]=8'd3;\n  sin3[184]=8'd2; sin3[185]=8'd2; sin3[186]=8'd1; sin3[187]=8'd1; sin3[188]=8'd0; sin3[189]=8'd0; sin3[190]=8'd0; sin3[191]=8'd0;\n  sin3[192]=8'd0; sin3[193]=8'd0; sin3[194]=8'd0; sin3[195]=8'd0; sin3[196]=8'd1; sin3[197]=8'd1; sin3[198]=8'd2; sin3[199]=8'd2;\n  sin3[200]=8'd3; sin3[201]=8'd3; sin3[202]=8'd4; sin3[203]=8'd5; sin3[204]=8'd6; sin3[205]=8'd7; sin3[206]=8'd8; sin3[207]=8'd9;\n  sin3[208]=8'd10; sin3[209]=8'd12; sin3[210]=8'd13; sin3[211]=8'd14; sin3[212]=8'd16; sin3[213]=8'd17; sin3[214]=8'd19; sin3[215]=8'd21;\n  sin3[216]=8'd22; sin3[217]=8'd24; sin3[218]=8'd26; sin3[219]=8'd28; sin3[220]=8'd30; sin3[221]=8'd32; sin3[222]=8'd34; sin3[223]=8'd36;\n  sin3[224]=8'd38; sin3[225]=8'd41; sin3[226]=8'd43; sin3[227]=8'd45; sin3[228]=8'd48; sin3[229]=8'd50; sin3[230]=8'd53; sin3[231]=8'd55;\n  sin3[232]=8'd58; sin3[233]=8'd60; sin3[234]=8'd63; sin3[235]=8'd66; sin3[236]=8'd69; sin3[237]=8'd71; sin3[238]=8'd74; sin3[239]=8'd77;\n  sin3[240]=8'd80; sin3[241]=8'd83; sin3[242]=8'd86; sin3[243]=8'd89; sin3[244]=8'd92; sin3[245]=8'd95; sin3[246]=8'd98; sin3[247]=8'd101;\n  sin3[248]=8'd104; sin3[249]=8'd107; sin3[250]=8'd110; sin3[251]=8'd113; sin3[252]=8'd116; sin3[253]=8'd119; sin3[254]=8'd122; sin3[255]=8'd125;\n  sin4[0]=8'd130; sin4[1]=8'd133; sin4[2]=8'd136; sin4[3]=8'd139; sin4[4]=8'd142; sin4[5]=8'd145; sin4[6]=8'd148; sin4[7]=8'd151;\n  sin4[8]=8'd154; sin4[9]=8'd157; sin4[10]=8'd160; sin4[11]=8'd163; sin4[12]=8'd166; sin4[13]=8'd169; sin4[14]=8'd172; sin4[15]=8'd175;\n  sin4[16]=8'd178; sin4[17]=8'd181; sin4[18]=8'd184; sin4[19]=8'd186; sin4[20]=8'd189; sin4[21]=8'd192; sin4[22]=8'd195; sin4[23]=8'd197;\n  sin4[24]=8'd200; sin4[25]=8'd202; sin4[26]=8'd205; sin4[27]=8'd207; sin4[28]=8'd210; sin4[29]=8'd212; sin4[30]=8'd214; sin4[31]=8'd217;\n  sin4[32]=8'd219; sin4[33]=8'd221; sin4[34]=8'd223; sin4[35]=8'd225; sin4[36]=8'd227; sin4[37]=8'd229; sin4[38]=8'd231; sin4[39]=8'd233;\n  sin4[40]=8'd234; sin4[41]=8'd236; sin4[42]=8'd238; sin4[43]=8'd239; sin4[44]=8'd241; sin4[45]=8'd242; sin4[46]=8'd243; sin4[47]=8'd245;\n  sin4[48]=8'd246; sin4[49]=8'd247; sin4[50]=8'd248; sin4[51]=8'd249; sin4[52]=8'd250; sin4[53]=8'd251; sin4[54]=8'd252; sin4[55]=8'd252;\n  sin4[56]=8'd253; sin4[57]=8'd253; sin4[58]=8'd254; sin4[59]=8'd254; sin4[60]=8'd255; sin4[61]=8'd255; sin4[62]=8'd255; sin4[63]=8'd255;\n  sin4[64]=8'd255; sin4[65]=8'd255; sin4[66]=8'd255; sin4[67]=8'd255; sin4[68]=8'd254; sin4[69]=8'd254; sin4[70]=8'd253; sin4[71]=8'd253;\n  sin4[72]=8'd252; sin4[73]=8'd252; sin4[74]=8'd251; sin4[75]=8'd250; sin4[76]=8'd249; sin4[77]=8'd248; sin4[78]=8'd247; sin4[79]=8'd246;\n  sin4[80]=8'd245; sin4[81]=8'd243; sin4[82]=8'd242; sin4[83]=8'd241; sin4[84]=8'd239; sin4[85]=8'd238; sin4[86]=8'd236; sin4[87]=8'd234;\n  sin4[88]=8'd233; sin4[89]=8'd231; sin4[90]=8'd229; sin4[91]=8'd227; sin4[92]=8'd225; sin4[93]=8'd223; sin4[94]=8'd221; sin4[95]=8'd219;\n  sin4[96]=8'd217; sin4[97]=8'd214; sin4[98]=8'd212; sin4[99]=8'd210; sin4[100]=8'd207; sin4[101]=8'd205; sin4[102]=8'd202; sin4[103]=8'd200;\n  sin4[104]=8'd197; sin4[105]=8'd195; sin4[106]=8'd192; sin4[107]=8'd189; sin4[108]=8'd186; sin4[109]=8'd184; sin4[110]=8'd181; sin4[111]=8'd178;\n  sin4[112]=8'd175; sin4[113]=8'd172; sin4[114]=8'd169; sin4[115]=8'd166; sin4[116]=8'd163; sin4[117]=8'd160; sin4[118]=8'd157; sin4[119]=8'd154;\n  sin4[120]=8'd151; sin4[121]=8'd148; sin4[122]=8'd145; sin4[123]=8'd142; sin4[124]=8'd139; sin4[125]=8'd136; sin4[126]=8'd133; sin4[127]=8'd130;\n  sin4[128]=8'd125; sin4[129]=8'd122; sin4[130]=8'd119; sin4[131]=8'd116; sin4[132]=8'd113; sin4[133]=8'd110; sin4[134]=8'd107; sin4[135]=8'd104;\n  sin4[136]=8'd101; sin4[137]=8'd98; sin4[138]=8'd95; sin4[139]=8'd92; sin4[140]=8'd89; sin4[141]=8'd86; sin4[142]=8'd83; sin4[143]=8'd80;\n  sin4[144]=8'd77; sin4[145]=8'd74; sin4[146]=8'd71; sin4[147]=8'd69; sin4[148]=8'd66; sin4[149]=8'd63; sin4[150]=8'd60; sin4[151]=8'd58;\n  sin4[152]=8'd55; sin4[153]=8'd53; sin4[154]=8'd50; sin4[155]=8'd48; sin4[156]=8'd45; sin4[157]=8'd43; sin4[158]=8'd41; sin4[159]=8'd38;\n  sin4[160]=8'd36; sin4[161]=8'd34; sin4[162]=8'd32; sin4[163]=8'd30; sin4[164]=8'd28; sin4[165]=8'd26; sin4[166]=8'd24; sin4[167]=8'd22;\n  sin4[168]=8'd21; sin4[169]=8'd19; sin4[170]=8'd17; sin4[171]=8'd16; sin4[172]=8'd14; sin4[173]=8'd13; sin4[174]=8'd12; sin4[175]=8'd10;\n  sin4[176]=8'd9; sin4[177]=8'd8; sin4[178]=8'd7; sin4[179]=8'd6; sin4[180]=8'd5; sin4[181]=8'd4; sin4[182]=8'd3; sin4[183]=8'd3;\n  sin4[184]=8'd2; sin4[185]=8'd2; sin4[186]=8'd1; sin4[187]=8'd1; sin4[188]=8'd0; sin4[189]=8'd0; sin4[190]=8'd0; sin4[191]=8'd0;\n  sin4[192]=8'd0; sin4[193]=8'd0; sin4[194]=8'd0; sin4[195]=8'd0; sin4[196]=8'd1; sin4[197]=8'd1; sin4[198]=8'd2; sin4[199]=8'd2;\n  sin4[200]=8'd3; sin4[201]=8'd3; sin4[202]=8'd4; sin4[203]=8'd5; sin4[204]=8'd6; sin4[205]=8'd7; sin4[206]=8'd8; sin4[207]=8'd9;\n  sin4[208]=8'd10; sin4[209]=8'd12; sin4[210]=8'd13; sin4[211]=8'd14; sin4[212]=8'd16; sin4[213]=8'd17; sin4[214]=8'd19; sin4[215]=8'd21;\n  sin4[216]=8'd22; sin4[217]=8'd24; sin4[218]=8'd26; sin4[219]=8'd28; sin4[220]=8'd30; sin4[221]=8'd32; sin4[222]=8'd34; sin4[223]=8'd36;\n  sin4[224]=8'd38; sin4[225]=8'd41; sin4[226]=8'd43; sin4[227]=8'd45; sin4[228]=8'd48; sin4[229]=8'd50; sin4[230]=8'd53; sin4[231]=8'd55;\n  sin4[232]=8'd58; sin4[233]=8'd60; sin4[234]=8'd63; sin4[235]=8'd66; sin4[236]=8'd69; sin4[237]=8'd71; sin4[238]=8'd74; sin4[239]=8'd77;\n  sin4[240]=8'd80; sin4[241]=8'd83; sin4[242]=8'd86; sin4[243]=8'd89; sin4[244]=8'd92; sin4[245]=8'd95; sin4[246]=8'd98; sin4[247]=8'd101;\n  sin4[248]=8'd104; sin4[249]=8'd107; sin4[250]=8'd110; sin4[251]=8'd113; sin4[252]=8'd116; sin4[253]=8'd119; sin4[254]=8'd122; sin4[255]=8'd125;\n  pal[0]=8'd156; pal[1]=8'd156; pal[2]=8'd156; pal[3]=8'd156; pal[4]=8'd156; pal[5]=8'd156; pal[6]=8'd156; pal[7]=8'd156;\n  pal[8]=8'd152; pal[9]=8'd152; pal[10]=8'd184; pal[11]=8'd184; pal[12]=8'd184; pal[13]=8'd184; pal[14]=8'd184; pal[15]=8'd184;\n  pal[16]=8'd184; pal[17]=8'd184; pal[18]=8'd184; pal[19]=8'd184; pal[20]=8'd184; pal[21]=8'd216; pal[22]=8'd212; pal[23]=8'd212;\n  pal[24]=8'd212; pal[25]=8'd212; pal[26]=8'd212; pal[27]=8'd212; pal[28]=8'd212; pal[29]=8'd212; pal[30]=8'd212; pal[31]=8'd212;\n  pal[32]=8'd212; pal[33]=8'd208; pal[34]=8'd208; pal[35]=8'd240; pal[36]=8'd240; pal[37]=8'd240; pal[38]=8'd240; pal[39]=8'd240;\n  pal[40]=8'd240; pal[41]=8'd240; pal[42]=8'd240; pal[43]=8'd236; pal[44]=8'd236; pal[45]=8'd236; pal[46]=8'd236; pal[47]=8'd236;\n  pal[48]=8'd236; pal[49]=8'd236; pal[50]=8'd236; pal[51]=8'd236; pal[52]=8'd236; pal[53]=8'd232; pal[54]=8'd232; pal[55]=8'd232;\n  pal[56]=8'd232; pal[57]=8'd232; pal[58]=8'd232; pal[59]=8'd232; pal[60]=8'd232; pal[61]=8'd232; pal[62]=8'd232; pal[63]=8'd232;\n  pal[64]=8'd228; pal[65]=8'd229; pal[66]=8'd229; pal[67]=8'd229; pal[68]=8'd229; pal[69]=8'd229; pal[70]=8'd229; pal[71]=8'd229;\n  pal[72]=8'd229; pal[73]=8'd229; pal[74]=8'd229; pal[75]=8'd229; pal[76]=8'd229; pal[77]=8'd229; pal[78]=8'd225; pal[79]=8'd225;\n  pal[80]=8'd225; pal[81]=8'd225; pal[82]=8'd225; pal[83]=8'd225; pal[84]=8'd225; pal[85]=8'd225; pal[86]=8'd226; pal[87]=8'd226;\n  pal[88]=8'd226; pal[89]=8'd226; pal[90]=8'd226; pal[91]=8'd226; pal[92]=8'd226; pal[93]=8'd194; pal[94]=8'd194; pal[95]=8'd194;\n  pal[96]=8'd194; pal[97]=8'd194; pal[98]=8'd194; pal[99]=8'd194; pal[100]=8'd194; pal[101]=8'd194; pal[102]=8'd194; pal[103]=8'd194;\n  pal[104]=8'd194; pal[105]=8'd194; pal[106]=8'd194; pal[107]=8'd163; pal[108]=8'd163; pal[109]=8'd163; pal[110]=8'd163; pal[111]=8'd163;\n  pal[112]=8'd163; pal[113]=8'd163; pal[114]=8'd163; pal[115]=8'd163; pal[116]=8'd163; pal[117]=8'd163; pal[118]=8'd131; pal[119]=8'd131;\n  pal[120]=8'd131; pal[121]=8'd131; pal[122]=8'd131; pal[123]=8'd131; pal[124]=8'd131; pal[125]=8'd131; pal[126]=8'd131; pal[127]=8'd131;\n  pal[128]=8'd99; pal[129]=8'd99; pal[130]=8'd99; pal[131]=8'd99; pal[132]=8'd99; pal[133]=8'd99; pal[134]=8'd99; pal[135]=8'd99;\n  pal[136]=8'd103; pal[137]=8'd103; pal[138]=8'd71; pal[139]=8'd71; pal[140]=8'd71; pal[141]=8'd71; pal[142]=8'd71; pal[143]=8'd71;\n  pal[144]=8'd71; pal[145]=8'd71; pal[146]=8'd71; pal[147]=8'd71; pal[148]=8'd71; pal[149]=8'd39; pal[150]=8'd43; pal[151]=8'd43;\n  pal[152]=8'd43; pal[153]=8'd43; pal[154]=8'd43; pal[155]=8'd43; pal[156]=8'd43; pal[157]=8'd43; pal[158]=8'd43; pal[159]=8'd43;\n  pal[160]=8'd43; pal[161]=8'd47; pal[162]=8'd47; pal[163]=8'd15; pal[164]=8'd15; pal[165]=8'd15; pal[166]=8'd15; pal[167]=8'd15;\n  pal[168]=8'd15; pal[169]=8'd15; pal[170]=8'd15; pal[171]=8'd19; pal[172]=8'd19; pal[173]=8'd19; pal[174]=8'd19; pal[175]=8'd19;\n  pal[176]=8'd19; pal[177]=8'd19; pal[178]=8'd19; pal[179]=8'd19; pal[180]=8'd19; pal[181]=8'd23; pal[182]=8'd23; pal[183]=8'd23;\n  pal[184]=8'd23; pal[185]=8'd23; pal[186]=8'd23; pal[187]=8'd23; pal[188]=8'd23; pal[189]=8'd23; pal[190]=8'd23; pal[191]=8'd23;\n  pal[192]=8'd27; pal[193]=8'd26; pal[194]=8'd26; pal[195]=8'd26; pal[196]=8'd26; pal[197]=8'd26; pal[198]=8'd26; pal[199]=8'd26;\n  pal[200]=8'd26; pal[201]=8'd26; pal[202]=8'd26; pal[203]=8'd26; pal[204]=8'd26; pal[205]=8'd26; pal[206]=8'd30; pal[207]=8'd30;\n  pal[208]=8'd30; pal[209]=8'd30; pal[210]=8'd30; pal[211]=8'd30; pal[212]=8'd30; pal[213]=8'd30; pal[214]=8'd29; pal[215]=8'd29;\n  pal[216]=8'd29; pal[217]=8'd29; pal[218]=8'd29; pal[219]=8'd29; pal[220]=8'd29; pal[221]=8'd61; pal[222]=8'd61; pal[223]=8'd61;\n  pal[224]=8'd61; pal[225]=8'd61; pal[226]=8'd61; pal[227]=8'd61; pal[228]=8'd61; pal[229]=8'd61; pal[230]=8'd61; pal[231]=8'd61;\n  pal[232]=8'd61; pal[233]=8'd61; pal[234]=8'd61; pal[235]=8'd92; pal[236]=8'd92; pal[237]=8'd92; pal[238]=8'd92; pal[239]=8'd92;\n  pal[240]=8'd92; pal[241]=8'd92; pal[242]=8'd92; pal[243]=8'd92; pal[244]=8'd92; pal[245]=8'd92; pal[246]=8'd124; pal[247]=8'd124;\n  pal[248]=8'd124; pal[249]=8'd124; pal[250]=8'd124; pal[251]=8'd124; pal[252]=8'd124; pal[253]=8'd124; pal[254]=8'd124; pal[255]=8'd124;\nend\n\nreg [7:0] a1, a2, a3, a4, s1, s2, s3, s4, p;\nwire [9:0] cx = (x > 320) ? x - 320 : 320 - x;\nwire [9:0] cy = (y > 240) ? y - 240 : 240 - y;\nwire [9:0] sum = s1 + s2 + s3 + s4;\nwire [7:0] v = sum[9:2] + t;\nalways @(posedge clk) begin\n  // stage 1: wave phases\n  a1 <= x[8:1] + t;\n  a2 <= y[7:0] - {t[6:0], 1'b0};\n  a3 <= x[9:2] + y[8:1] + {t[6:0], 1'b0};\n  a4 <= cx[7:0] + cy[7:0] - {t[5:0], 2'b0};\nend\n// stage 2: sines (one table read each)\nalways @(posedge clk) s1 <= sin1[a1];\nalways @(posedge clk) s2 <= sin2[a2];\nalways @(posedge clk) s3 <= sin3[a3];\nalways @(posedge clk) s4 <= sin4[a4];\n// stage 3: palette\nalways @(posedge clk) p <= pal[v];\nassign rgb = p;\n"
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
            "code": "// Effect 3: two-source interference\n// Two bouncing point sources; each pixel computes its squared distance\n// to both (4 multipliers per pixel) -> ripple interference pattern.\n// The multiplies use 4 of the chip's DSP blocks (SB_MAC16) directly, so\n// they don't eat logic cells (the rest of this design needs them). They\n// square signed differences, so no absolute values are needed.\nreg [9:0] ax = 160, ay = 120, bx = 480, by = 360;\nreg adx = 1, ady = 1, bdx = 0, bdy = 1;\nwire frame = (x == 0) && (y == 480);\nalways @(posedge clk) if (frame) begin\n  ax <= ax + (adx ? 10'd3 : -10'd3);  ay <= ay + (ady ? 10'd2 : -10'd2);\n  bx <= bx + (bdx ? 10'd2 : -10'd2);  by <= by + (bdy ? 10'd3 : -10'd3);\n  if (ax > 630) adx <= 0; if (ax < 10) adx <= 1;\n  if (ay > 470) ady <= 0; if (ay < 10) ady <= 1;\n  if (bx > 630) bdx <= 0; if (bx < 10) bdx <= 1;\n  if (by > 470) bdy <= 0; if (by < 10) bdy <= 1;\nend\nreg [10:0] dx1, dy1, dx2, dy2;            // signed x - ax, ...\nreg [14:0] q1, q2, q3, q4;                // low bits of the squares\nreg [3:0] z;                              // square < 512\nreg [7:0] r;\nwire [31:0] m [0:3];                      // dx1^2, dy1^2, dx2^2, dy2^2\nwire [10:0] sq [0:3];\nassign sq[0] = dx1; assign sq[1] = dy1; assign sq[2] = dx2; assign sq[3] = dy2;\ngenvar k;\ngenerate\n  for (k = 0; k < 4; k = k + 1) begin : mul\n    SB_MAC16 #(.TOPOUTPUT_SELECT(2'b11), .BOTOUTPUT_SELECT(2'b11),\n               .MODE_8x8(1'b0), .A_SIGNED(1'b1), .B_SIGNED(1'b1)) dsp (\n      .CLK(1'b0), .CE(1'b1), .A({{5{sq[k][10]}}, sq[k]}), .B({{5{sq[k][10]}}, sq[k]}),\n      .C(16'd0), .D(16'd0), .AHOLD(1'b0), .BHOLD(1'b0), .CHOLD(1'b0),\n      .DHOLD(1'b0), .IRSTTOP(1'b0), .IRSTBOT(1'b0), .ORSTTOP(1'b0),\n      .ORSTBOT(1'b0), .OLOADTOP(1'b0), .OLOADBOT(1'b0), .ADDSUBTOP(1'b0),\n      .ADDSUBBOT(1'b0), .OHOLDTOP(1'b0), .OHOLDBOT(1'b0), .CI(1'b0),\n      .ACCUMCI(1'b0), .SIGNEXTIN(1'b0), .O(m[k]));\n  end\nendgenerate\n// distance^2 to each source; only bits 14..7 make the rings, and a\n// source dot is where the whole sum is < 400 (so both squares are < 512)\nwire [14:0] d1 = q1 + q2, d2 = q3 + q4;\nwire [7:0] v1 = d1[14:7] - {t[5:0], 2'b0};   // rings expand outwards\nwire [7:0] v2 = d2[14:7] - {t[5:0], 2'b0};\nwire near = (z[0] && z[1] && d1[9:0] < 400) || (z[2] && z[3] && d2[9:0] < 400);\nalways @(posedge clk) begin\n  dx1 <= {1'b0, x} - {1'b0, ax};  dy1 <= {1'b0, y} - {1'b0, ay};\n  dx2 <= {1'b0, x} - {1'b0, bx};  dy2 <= {1'b0, y} - {1'b0, by};\n  q1 <= m[0][14:0];  q2 <= m[1][14:0];  q3 <= m[2][14:0];  q4 <= m[3][14:0];\n  z <= {m[3][19:9] == 0, m[2][19:9] == 0, m[1][19:9] == 0, m[0][19:9] == 0};\n  if (near) r <= 8'hFF;                               // the sources\n  else r <= {v1[7:5], v2[7:5], v1[7] ^ v2[7], v1[6] ^ v2[6]};\n  // red = waves from A, green = waves from B, blue = where they interfere\nend\nassign rgb = r;\n"
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
                },
                {
                  "name": "centre"
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
            "code": "// Life on VGA\n// Keeps its own copy of the 128x128 grid in block RAM: written by the\n// Life engine at 24 MHz, read by the beam at 25 MHz (the RAM has separate\n// read and write clocks). Each cell is drawn 3x3 pixels: a 384x384 board,\n// in the middle of the screen (centre = 1) or at the left beside the text\n// panel. One row is fetched per scan line during blanking, so the engine\n// never has to wait for the display.\n// Outputs line up with the effects (3 clocks after x/y).\nreg [127:0] dmem [0:127];\nalways @(posedge wclk) if (we) dmem[wrow] <= wdata;\nreg [6:0]   raddr = 0;\nreg [127:0] rdata = 0, rowbuf = 0;\nalways @(posedge clk) rdata <= dmem[raddr];\n\n// vertical: which grid row the NEXT line shows (updated after each line)\nlocalparam Y0 = 48;                       // board at y 48..431, and x\nwire [9:0] X0 = centre ? 10'd128 : 10'd16; // 128..511 or 16..399\nreg [6:0] vrow = 0; reg [1:0] vsub = 0; reg vin = 0;\nwire [9:0] ny = (y == 524) ? 10'd0 : y + 10'd1;\nalways @(posedge clk) begin\n  if (x == 640) begin\n    if (ny == Y0) begin vrow <= 0; vsub <= 0; vin <= 1; end\n    else if (vin) begin\n      if (vsub == 2) begin\n        vsub <= 0;\n        if (vrow == 127) vin <= 0; else vrow <= vrow + 1;\n      end else vsub <= vsub + 1;\n    end\n  end\n  if (x == 650) raddr <= vrow;\n  if (x == 660) rowbuf <= rdata;          // used for the whole next line\nend\n\n// horizontal, stage 1: column of pixel x\nreg [6:0] col = 0; reg [1:0] hsub = 0; reg hin = 0;\nreg box1 = 0, gap1 = 0;\nalways @(posedge clk) begin\n  if (x == X0) begin col <= 0; hsub <= 0; hin <= 1; end\n  else if (hin) begin\n    if (hsub == 2) begin\n      hsub <= 0;\n      if (col == 127) hin <= 0; else col <= col + 1;\n    end else hsub <= hsub + 1;\n  end\n  box1 <= (centre ? (x >= 124 && x < 516) : (x >= 12 && x < 404)) &&\n          (y >= Y0 - 4) && (y < Y0 + 388);\n  gap1 <= (centre ? (x >= 126 && x < 514) : (x >= 14 && x < 402)) &&\n          (y >= Y0 - 2) && (y < Y0 + 386);\nend\n// stage 2: look up the cell, pick its colour (rainbow across the board,\n// drifting with time)\nreg c2 = 0, in2 = 0, fr2 = 0;\nreg [7:0] hue = 0;\nalways @(posedge clk) begin\n  c2  <= rowbuf[col];\n  in2 <= hin && vin;\n  fr2 <= box1 && !gap1;\n  hue <= {1'b0, col} + {1'b0, vrow} + t;\nend\n// colour wheel: each channel is bright for a third of the circle\nfunction [2:0] wheel(input [7:0] a);\n  reg [7:0] d;\n  begin\n    d = a[7] ? 8'd0 - a : a;               // distance from 0 on the circle\n    wheel = d < 43 ? 3'd7 : d < 64 ? 3'd5 : d < 85 ? 3'd2 : 3'd0;\n  end\nendfunction\n// stage 3\nreg c3 = 0, in3 = 0, fr3 = 0;\nreg [7:0] col3 = 0;\nwire [2:0] wr = wheel(hue), wg = wheel(hue - 8'd85), wb = wheel(hue - 8'd170);\nalways @(posedge clk) begin\n  c3 <= c2 && in2; in3 <= in2; fr3 <= fr2;\n  col3 <= {wr, wg, wb[2:1]};\nend\nassign cell = c3;\nassign ingrid = in3;\nassign frame = fr3;\nassign color = col3;\n"
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
                  "name": "waddr",
                  "range": "[11:0]",
                  "size": 12
                },
                {
                  "name": "wdata",
                  "range": "[15:0]",
                  "size": 16
                },
                {
                  "name": "wtog"
                }
              ],
              "out": [
                {
                  "name": "vis"
                },
                {
                  "name": "color",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            },
            "params": [],
            "code": "// Text layer (80x30 characters)\n// An 80x30 text screen over everything else, written by the PC (bridge\n// command 'T'). Each cell is a character (8x16 font, below) and a colour\n// byte: foreground in bits 3-0, background in bits 7-4, both picked from\n// the 16-colour palette (0 = see-through, so the Life grid and effects\n// show around and behind the text). The cells live in one of the UP5K's\n// 32 KB single-port RAMs (SPRAM) at row*128 + column. The beam reads\n// each cell 8 pixels early; a PC write takes one of the free RAM cycles\n// in between. Outputs line up with the effects (3 clocks after x/y).\n\n// write request from the 24 MHz side: address and data are held still\n// for many clocks, so only the toggle needs synchronising\nreg [2:0] ws = 0;\nreg pend = 0;\nalways @(posedge clk) ws <= {ws[1:0], wtog};\n\n// the cell the beam reaches 8 pixels from now (wraps to the next line)\nwire       nl = x >= 792;\nwire [9:0] ny = (y == 524) ? 10'd0 : y + 10'd1;\nwire [9:0] fy = nl ? ny : y;\nwire [6:0] fcol = nl ? 7'd0 : x[9:3] + 7'd1;\nwire       wr = pend && x[2:0] == 4;\nalways @(posedge clk) begin\n  if (wr) pend <= 0;\n  if (ws[2] ^ ws[1]) pend <= 1;\nend\nwire [15:0] q;\nSB_SPRAM256KA cells (\n  .ADDRESS(wr ? {2'b00, waddr} : {2'b00, fy[8:4], fcol}),\n  .DATAIN(wdata), .MASKWREN(4'b1111), .WREN(wr), .CHIPSELECT(1'b1),\n  .CLOCK(clk), .STANDBY(1'b0), .SLEEP(1'b0), .POWEROFF(1'b1), .DATAOUT(q));\n\nreg [7:0] font [0:2047];\n// 8x16 font: ASCII from Terminus Bold 16 (SIL Open Font License),\n// codes 0-31 = █▀▁▂▃▄▅▆▇▏▎▍▌▋▊▉─│╭╮╰╯✔✘○×…·→•░  (tools/vga_font.py)\ninitial begin\n  font[0]=8'h00; font[1]=8'h00; font[2]=8'h00; font[3]=8'h00; font[4]=8'h00; font[5]=8'h00; font[6]=8'h00; font[7]=8'h00; font[8]=8'h00; font[9]=8'h00; font[10]=8'h00; font[11]=8'h00; font[12]=8'h00; font[13]=8'h00; font[14]=8'h00; font[15]=8'h00;\n  font[16]=8'hff; font[17]=8'hff; font[18]=8'hff; font[19]=8'hff; font[20]=8'hff; font[21]=8'hff; font[22]=8'hff; font[23]=8'hff; font[24]=8'hff; font[25]=8'hff; font[26]=8'hff; font[27]=8'hff; font[28]=8'hff; font[29]=8'hff; font[30]=8'hff; font[31]=8'hff;\n  font[32]=8'hff; font[33]=8'hff; font[34]=8'hff; font[35]=8'hff; font[36]=8'hff; font[37]=8'hff; font[38]=8'hff; font[39]=8'hff; font[40]=8'h00; font[41]=8'h00; font[42]=8'h00; font[43]=8'h00; font[44]=8'h00; font[45]=8'h00; font[46]=8'h00; font[47]=8'h00;\n  font[48]=8'h00; font[49]=8'h00; font[50]=8'h00; font[51]=8'h00; font[52]=8'h00; font[53]=8'h00; font[54]=8'h00; font[55]=8'h00; font[56]=8'h00; font[57]=8'h00; font[58]=8'h00; font[59]=8'h00; font[60]=8'h00; font[61]=8'h00; font[62]=8'hff; font[63]=8'hff;\n  font[64]=8'h00; font[65]=8'h00; font[66]=8'h00; font[67]=8'h00; font[68]=8'h00; font[69]=8'h00; font[70]=8'h00; font[71]=8'h00; font[72]=8'h00; font[73]=8'h00; font[74]=8'h00; font[75]=8'h00; font[76]=8'hff; font[77]=8'hff; font[78]=8'hff; font[79]=8'hff;\n  font[80]=8'h00; font[81]=8'h00; font[82]=8'h00; font[83]=8'h00; font[84]=8'h00; font[85]=8'h00; font[86]=8'h00; font[87]=8'h00; font[88]=8'h00; font[89]=8'h00; font[90]=8'hff; font[91]=8'hff; font[92]=8'hff; font[93]=8'hff; font[94]=8'hff; font[95]=8'hff;\n  font[96]=8'h00; font[97]=8'h00; font[98]=8'h00; font[99]=8'h00; font[100]=8'h00; font[101]=8'h00; font[102]=8'h00; font[103]=8'h00; font[104]=8'hff; font[105]=8'hff; font[106]=8'hff; font[107]=8'hff; font[108]=8'hff; font[109]=8'hff; font[110]=8'hff; font[111]=8'hff;\n  font[112]=8'h00; font[113]=8'h00; font[114]=8'h00; font[115]=8'h00; font[116]=8'h00; font[117]=8'h00; font[118]=8'hff; font[119]=8'hff; font[120]=8'hff; font[121]=8'hff; font[122]=8'hff; font[123]=8'hff; font[124]=8'hff; font[125]=8'hff; font[126]=8'hff; font[127]=8'hff;\n  font[128]=8'h00; font[129]=8'h00; font[130]=8'h00; font[131]=8'h00; font[132]=8'hff; font[133]=8'hff; font[134]=8'hff; font[135]=8'hff; font[136]=8'hff; font[137]=8'hff; font[138]=8'hff; font[139]=8'hff; font[140]=8'hff; font[141]=8'hff; font[142]=8'hff; font[143]=8'hff;\n  font[144]=8'h00; font[145]=8'h00; font[146]=8'hff; font[147]=8'hff; font[148]=8'hff; font[149]=8'hff; font[150]=8'hff; font[151]=8'hff; font[152]=8'hff; font[153]=8'hff; font[154]=8'hff; font[155]=8'hff; font[156]=8'hff; font[157]=8'hff; font[158]=8'hff; font[159]=8'hff;\n  font[160]=8'h80; font[161]=8'h80; font[162]=8'h80; font[163]=8'h80; font[164]=8'h80; font[165]=8'h80; font[166]=8'h80; font[167]=8'h80; font[168]=8'h80; font[169]=8'h80; font[170]=8'h80; font[171]=8'h80; font[172]=8'h80; font[173]=8'h80; font[174]=8'h80; font[175]=8'h80;\n  font[176]=8'hc0; font[177]=8'hc0; font[178]=8'hc0; font[179]=8'hc0; font[180]=8'hc0; font[181]=8'hc0; font[182]=8'hc0; font[183]=8'hc0; font[184]=8'hc0; font[185]=8'hc0; font[186]=8'hc0; font[187]=8'hc0; font[188]=8'hc0; font[189]=8'hc0; font[190]=8'hc0; font[191]=8'hc0;\n  font[192]=8'he0; font[193]=8'he0; font[194]=8'he0; font[195]=8'he0; font[196]=8'he0; font[197]=8'he0; font[198]=8'he0; font[199]=8'he0; font[200]=8'he0; font[201]=8'he0; font[202]=8'he0; font[203]=8'he0; font[204]=8'he0; font[205]=8'he0; font[206]=8'he0; font[207]=8'he0;\n  font[208]=8'hf0; font[209]=8'hf0; font[210]=8'hf0; font[211]=8'hf0; font[212]=8'hf0; font[213]=8'hf0; font[214]=8'hf0; font[215]=8'hf0; font[216]=8'hf0; font[217]=8'hf0; font[218]=8'hf0; font[219]=8'hf0; font[220]=8'hf0; font[221]=8'hf0; font[222]=8'hf0; font[223]=8'hf0;\n  font[224]=8'hf8; font[225]=8'hf8; font[226]=8'hf8; font[227]=8'hf8; font[228]=8'hf8; font[229]=8'hf8; font[230]=8'hf8; font[231]=8'hf8; font[232]=8'hf8; font[233]=8'hf8; font[234]=8'hf8; font[235]=8'hf8; font[236]=8'hf8; font[237]=8'hf8; font[238]=8'hf8; font[239]=8'hf8;\n  font[240]=8'hfc; font[241]=8'hfc; font[242]=8'hfc; font[243]=8'hfc; font[244]=8'hfc; font[245]=8'hfc; font[246]=8'hfc; font[247]=8'hfc; font[248]=8'hfc; font[249]=8'hfc; font[250]=8'hfc; font[251]=8'hfc; font[252]=8'hfc; font[253]=8'hfc; font[254]=8'hfc; font[255]=8'hfc;\n  font[256]=8'hfe; font[257]=8'hfe; font[258]=8'hfe; font[259]=8'hfe; font[260]=8'hfe; font[261]=8'hfe; font[262]=8'hfe; font[263]=8'hfe; font[264]=8'hfe; font[265]=8'hfe; font[266]=8'hfe; font[267]=8'hfe; font[268]=8'hfe; font[269]=8'hfe; font[270]=8'hfe; font[271]=8'hfe;\n  font[272]=8'h00; font[273]=8'h00; font[274]=8'h00; font[275]=8'h00; font[276]=8'h00; font[277]=8'h00; font[278]=8'h00; font[279]=8'hff; font[280]=8'hff; font[281]=8'h00; font[282]=8'h00; font[283]=8'h00; font[284]=8'h00; font[285]=8'h00; font[286]=8'h00; font[287]=8'h00;\n  font[288]=8'h18; font[289]=8'h18; font[290]=8'h18; font[291]=8'h18; font[292]=8'h18; font[293]=8'h18; font[294]=8'h18; font[295]=8'h18; font[296]=8'h18; font[297]=8'h18; font[298]=8'h18; font[299]=8'h18; font[300]=8'h18; font[301]=8'h18; font[302]=8'h18; font[303]=8'h18;\n  font[304]=8'h00; font[305]=8'h00; font[306]=8'h00; font[307]=8'h00; font[308]=8'h00; font[309]=8'h00; font[310]=8'h00; font[311]=8'h1f; font[312]=8'h1f; font[313]=8'h18; font[314]=8'h18; font[315]=8'h18; font[316]=8'h18; font[317]=8'h18; font[318]=8'h18; font[319]=8'h18;\n  font[320]=8'h00; font[321]=8'h00; font[322]=8'h00; font[323]=8'h00; font[324]=8'h00; font[325]=8'h00; font[326]=8'h00; font[327]=8'hf8; font[328]=8'hf8; font[329]=8'h18; font[330]=8'h18; font[331]=8'h18; font[332]=8'h18; font[333]=8'h18; font[334]=8'h18; font[335]=8'h18;\n  font[336]=8'h18; font[337]=8'h18; font[338]=8'h18; font[339]=8'h18; font[340]=8'h18; font[341]=8'h18; font[342]=8'h18; font[343]=8'h1f; font[344]=8'h1f; font[345]=8'h00; font[346]=8'h00; font[347]=8'h00; font[348]=8'h00; font[349]=8'h00; font[350]=8'h00; font[351]=8'h00;\n  font[352]=8'h18; font[353]=8'h18; font[354]=8'h18; font[355]=8'h18; font[356]=8'h18; font[357]=8'h18; font[358]=8'h18; font[359]=8'hf8; font[360]=8'hf8; font[361]=8'h00; font[362]=8'h00; font[363]=8'h00; font[364]=8'h00; font[365]=8'h00; font[366]=8'h00; font[367]=8'h00;\n  font[368]=8'h00; font[369]=8'h00; font[370]=8'h00; font[371]=8'h03; font[372]=8'h07; font[373]=8'h06; font[374]=8'h0e; font[375]=8'h9c; font[376]=8'hd8; font[377]=8'hf8; font[378]=8'h70; font[379]=8'h20; font[380]=8'h00; font[381]=8'h00; font[382]=8'h00; font[383]=8'h00;\n  font[384]=8'h00; font[385]=8'h00; font[386]=8'h00; font[387]=8'h00; font[388]=8'h00; font[389]=8'hc6; font[390]=8'hc6; font[391]=8'h6c; font[392]=8'h38; font[393]=8'h6c; font[394]=8'hc6; font[395]=8'hc6; font[396]=8'h00; font[397]=8'h00; font[398]=8'h00; font[399]=8'h00;\n  font[400]=8'h00; font[401]=8'h00; font[402]=8'h00; font[403]=8'h3c; font[404]=8'h66; font[405]=8'hc3; font[406]=8'h81; font[407]=8'h81; font[408]=8'h81; font[409]=8'hc3; font[410]=8'h66; font[411]=8'h3c; font[412]=8'h00; font[413]=8'h00; font[414]=8'h00; font[415]=8'h00;\n  font[416]=8'h00; font[417]=8'h00; font[418]=8'h00; font[419]=8'h00; font[420]=8'h00; font[421]=8'hc6; font[422]=8'h6c; font[423]=8'h38; font[424]=8'h38; font[425]=8'h6c; font[426]=8'hc6; font[427]=8'h00; font[428]=8'h00; font[429]=8'h00; font[430]=8'h00; font[431]=8'h00;\n  font[432]=8'h00; font[433]=8'h00; font[434]=8'h00; font[435]=8'h00; font[436]=8'h00; font[437]=8'h00; font[438]=8'h00; font[439]=8'h00; font[440]=8'h00; font[441]=8'h00; font[442]=8'hdb; font[443]=8'hdb; font[444]=8'h00; font[445]=8'h00; font[446]=8'h00; font[447]=8'h00;\n  font[448]=8'h00; font[449]=8'h00; font[450]=8'h00; font[451]=8'h00; font[452]=8'h00; font[453]=8'h00; font[454]=8'h00; font[455]=8'h18; font[456]=8'h18; font[457]=8'h00; font[458]=8'h00; font[459]=8'h00; font[460]=8'h00; font[461]=8'h00; font[462]=8'h00; font[463]=8'h00;\n  font[464]=8'h00; font[465]=8'h00; font[466]=8'h00; font[467]=8'h00; font[468]=8'h00; font[469]=8'h08; font[470]=8'h0c; font[471]=8'hfe; font[472]=8'hfe; font[473]=8'h0c; font[474]=8'h08; font[475]=8'h00; font[476]=8'h00; font[477]=8'h00; font[478]=8'h00; font[479]=8'h00;\n  font[480]=8'h00; font[481]=8'h00; font[482]=8'h00; font[483]=8'h00; font[484]=8'h00; font[485]=8'h00; font[486]=8'h18; font[487]=8'h3c; font[488]=8'h3c; font[489]=8'h18; font[490]=8'h00; font[491]=8'h00; font[492]=8'h00; font[493]=8'h00; font[494]=8'h00; font[495]=8'h00;\n  font[496]=8'h88; font[497]=8'h22; font[498]=8'h88; font[499]=8'h22; font[500]=8'h88; font[501]=8'h22; font[502]=8'h88; font[503]=8'h22; font[504]=8'h88; font[505]=8'h22; font[506]=8'h88; font[507]=8'h22; font[508]=8'h88; font[509]=8'h22; font[510]=8'h88; font[511]=8'h22;\n  font[512]=8'h00; font[513]=8'h00; font[514]=8'h00; font[515]=8'h00; font[516]=8'h00; font[517]=8'h00; font[518]=8'h00; font[519]=8'h00; font[520]=8'h00; font[521]=8'h00; font[522]=8'h00; font[523]=8'h00; font[524]=8'h00; font[525]=8'h00; font[526]=8'h00; font[527]=8'h00;\n  font[528]=8'h00; font[529]=8'h00; font[530]=8'h18; font[531]=8'h18; font[532]=8'h18; font[533]=8'h18; font[534]=8'h18; font[535]=8'h18; font[536]=8'h18; font[537]=8'h00; font[538]=8'h18; font[539]=8'h18; font[540]=8'h00; font[541]=8'h00; font[542]=8'h00; font[543]=8'h00;\n  font[544]=8'h00; font[545]=8'h66; font[546]=8'h66; font[547]=8'h66; font[548]=8'h00; font[549]=8'h00; font[550]=8'h00; font[551]=8'h00; font[552]=8'h00; font[553]=8'h00; font[554]=8'h00; font[555]=8'h00; font[556]=8'h00; font[557]=8'h00; font[558]=8'h00; font[559]=8'h00;\n  font[560]=8'h00; font[561]=8'h00; font[562]=8'h6c; font[563]=8'h6c; font[564]=8'h6c; font[565]=8'hfe; font[566]=8'h6c; font[567]=8'h6c; font[568]=8'hfe; font[569]=8'h6c; font[570]=8'h6c; font[571]=8'h6c; font[572]=8'h00; font[573]=8'h00; font[574]=8'h00; font[575]=8'h00;\n  font[576]=8'h00; font[577]=8'h10; font[578]=8'h10; font[579]=8'h7c; font[580]=8'hd6; font[581]=8'hd0; font[582]=8'hd0; font[583]=8'h7c; font[584]=8'h16; font[585]=8'h16; font[586]=8'hd6; font[587]=8'h7c; font[588]=8'h10; font[589]=8'h10; font[590]=8'h00; font[591]=8'h00;\n  font[592]=8'h00; font[593]=8'h00; font[594]=8'h66; font[595]=8'hd6; font[596]=8'h6c; font[597]=8'h0c; font[598]=8'h18; font[599]=8'h18; font[600]=8'h30; font[601]=8'h36; font[602]=8'h6b; font[603]=8'h66; font[604]=8'h00; font[605]=8'h00; font[606]=8'h00; font[607]=8'h00;\n  font[608]=8'h00; font[609]=8'h00; font[610]=8'h38; font[611]=8'h6c; font[612]=8'h6c; font[613]=8'h38; font[614]=8'h76; font[615]=8'hdc; font[616]=8'hcc; font[617]=8'hcc; font[618]=8'hdc; font[619]=8'h76; font[620]=8'h00; font[621]=8'h00; font[622]=8'h00; font[623]=8'h00;\n  font[624]=8'h00; font[625]=8'h18; font[626]=8'h18; font[627]=8'h18; font[628]=8'h00; font[629]=8'h00; font[630]=8'h00; font[631]=8'h00; font[632]=8'h00; font[633]=8'h00; font[634]=8'h00; font[635]=8'h00; font[636]=8'h00; font[637]=8'h00; font[638]=8'h00; font[639]=8'h00;\n  font[640]=8'h00; font[641]=8'h00; font[642]=8'h0c; font[643]=8'h18; font[644]=8'h30; font[645]=8'h30; font[646]=8'h30; font[647]=8'h30; font[648]=8'h30; font[649]=8'h30; font[650]=8'h18; font[651]=8'h0c; font[652]=8'h00; font[653]=8'h00; font[654]=8'h00; font[655]=8'h00;\n  font[656]=8'h00; font[657]=8'h00; font[658]=8'h30; font[659]=8'h18; font[660]=8'h0c; font[661]=8'h0c; font[662]=8'h0c; font[663]=8'h0c; font[664]=8'h0c; font[665]=8'h0c; font[666]=8'h18; font[667]=8'h30; font[668]=8'h00; font[669]=8'h00; font[670]=8'h00; font[671]=8'h00;\n  font[672]=8'h00; font[673]=8'h00; font[674]=8'h00; font[675]=8'h00; font[676]=8'h00; font[677]=8'h6c; font[678]=8'h38; font[679]=8'hfe; font[680]=8'h38; font[681]=8'h6c; font[682]=8'h00; font[683]=8'h00; font[684]=8'h00; font[685]=8'h00; font[686]=8'h00; font[687]=8'h00;\n  font[688]=8'h00; font[689]=8'h00; font[690]=8'h00; font[691]=8'h00; font[692]=8'h00; font[693]=8'h18; font[694]=8'h18; font[695]=8'h7e; font[696]=8'h18; font[697]=8'h18; font[698]=8'h00; font[699]=8'h00; font[700]=8'h00; font[701]=8'h00; font[702]=8'h00; font[703]=8'h00;\n  font[704]=8'h00; font[705]=8'h00; font[706]=8'h00; font[707]=8'h00; font[708]=8'h00; font[709]=8'h00; font[710]=8'h00; font[711]=8'h00; font[712]=8'h00; font[713]=8'h00; font[714]=8'h18; font[715]=8'h18; font[716]=8'h30; font[717]=8'h00; font[718]=8'h00; font[719]=8'h00;\n  font[720]=8'h00; font[721]=8'h00; font[722]=8'h00; font[723]=8'h00; font[724]=8'h00; font[725]=8'h00; font[726]=8'h00; font[727]=8'hfe; font[728]=8'h00; font[729]=8'h00; font[730]=8'h00; font[731]=8'h00; font[732]=8'h00; font[733]=8'h00; font[734]=8'h00; font[735]=8'h00;\n  font[736]=8'h00; font[737]=8'h00; font[738]=8'h00; font[739]=8'h00; font[740]=8'h00; font[741]=8'h00; font[742]=8'h00; font[743]=8'h00; font[744]=8'h00; font[745]=8'h00; font[746]=8'h18; font[747]=8'h18; font[748]=8'h00; font[749]=8'h00; font[750]=8'h00; font[751]=8'h00;\n  font[752]=8'h00; font[753]=8'h00; font[754]=8'h06; font[755]=8'h06; font[756]=8'h0c; font[757]=8'h0c; font[758]=8'h18; font[759]=8'h18; font[760]=8'h30; font[761]=8'h30; font[762]=8'h60; font[763]=8'h60; font[764]=8'h00; font[765]=8'h00; font[766]=8'h00; font[767]=8'h00;\n  font[768]=8'h00; font[769]=8'h00; font[770]=8'h7c; font[771]=8'hc6; font[772]=8'hc6; font[773]=8'hce; font[774]=8'hde; font[775]=8'hf6; font[776]=8'he6; font[777]=8'hc6; font[778]=8'hc6; font[779]=8'h7c; font[780]=8'h00; font[781]=8'h00; font[782]=8'h00; font[783]=8'h00;\n  font[784]=8'h00; font[785]=8'h00; font[786]=8'h18; font[787]=8'h38; font[788]=8'h78; font[789]=8'h18; font[790]=8'h18; font[791]=8'h18; font[792]=8'h18; font[793]=8'h18; font[794]=8'h18; font[795]=8'h7e; font[796]=8'h00; font[797]=8'h00; font[798]=8'h00; font[799]=8'h00;\n  font[800]=8'h00; font[801]=8'h00; font[802]=8'h7c; font[803]=8'hc6; font[804]=8'hc6; font[805]=8'h06; font[806]=8'h0c; font[807]=8'h18; font[808]=8'h30; font[809]=8'h60; font[810]=8'hc0; font[811]=8'hfe; font[812]=8'h00; font[813]=8'h00; font[814]=8'h00; font[815]=8'h00;\n  font[816]=8'h00; font[817]=8'h00; font[818]=8'h7c; font[819]=8'hc6; font[820]=8'hc6; font[821]=8'h06; font[822]=8'h3c; font[823]=8'h06; font[824]=8'h06; font[825]=8'hc6; font[826]=8'hc6; font[827]=8'h7c; font[828]=8'h00; font[829]=8'h00; font[830]=8'h00; font[831]=8'h00;\n  font[832]=8'h00; font[833]=8'h00; font[834]=8'h06; font[835]=8'h0e; font[836]=8'h1e; font[837]=8'h36; font[838]=8'h66; font[839]=8'hc6; font[840]=8'hfe; font[841]=8'h06; font[842]=8'h06; font[843]=8'h06; font[844]=8'h00; font[845]=8'h00; font[846]=8'h00; font[847]=8'h00;\n  font[848]=8'h00; font[849]=8'h00; font[850]=8'hfe; font[851]=8'hc0; font[852]=8'hc0; font[853]=8'hc0; font[854]=8'hfc; font[855]=8'h06; font[856]=8'h06; font[857]=8'h06; font[858]=8'hc6; font[859]=8'h7c; font[860]=8'h00; font[861]=8'h00; font[862]=8'h00; font[863]=8'h00;\n  font[864]=8'h00; font[865]=8'h00; font[866]=8'h3c; font[867]=8'h60; font[868]=8'hc0; font[869]=8'hc0; font[870]=8'hfc; font[871]=8'hc6; font[872]=8'hc6; font[873]=8'hc6; font[874]=8'hc6; font[875]=8'h7c; font[876]=8'h00; font[877]=8'h00; font[878]=8'h00; font[879]=8'h00;\n  font[880]=8'h00; font[881]=8'h00; font[882]=8'hfe; font[883]=8'h06; font[884]=8'h06; font[885]=8'h0c; font[886]=8'h0c; font[887]=8'h18; font[888]=8'h18; font[889]=8'h30; font[890]=8'h30; font[891]=8'h30; font[892]=8'h00; font[893]=8'h00; font[894]=8'h00; font[895]=8'h00;\n  font[896]=8'h00; font[897]=8'h00; font[898]=8'h7c; font[899]=8'hc6; font[900]=8'hc6; font[901]=8'hc6; font[902]=8'h7c; font[903]=8'hc6; font[904]=8'hc6; font[905]=8'hc6; font[906]=8'hc6; font[907]=8'h7c; font[908]=8'h00; font[909]=8'h00; font[910]=8'h00; font[911]=8'h00;\n  font[912]=8'h00; font[913]=8'h00; font[914]=8'h7c; font[915]=8'hc6; font[916]=8'hc6; font[917]=8'hc6; font[918]=8'hc6; font[919]=8'h7e; font[920]=8'h06; font[921]=8'h06; font[922]=8'h0c; font[923]=8'h78; font[924]=8'h00; font[925]=8'h00; font[926]=8'h00; font[927]=8'h00;\n  font[928]=8'h00; font[929]=8'h00; font[930]=8'h00; font[931]=8'h00; font[932]=8'h00; font[933]=8'h18; font[934]=8'h18; font[935]=8'h00; font[936]=8'h00; font[937]=8'h00; font[938]=8'h18; font[939]=8'h18; font[940]=8'h00; font[941]=8'h00; font[942]=8'h00; font[943]=8'h00;\n  font[944]=8'h00; font[945]=8'h00; font[946]=8'h00; font[947]=8'h00; font[948]=8'h00; font[949]=8'h18; font[950]=8'h18; font[951]=8'h00; font[952]=8'h00; font[953]=8'h00; font[954]=8'h18; font[955]=8'h18; font[956]=8'h30; font[957]=8'h00; font[958]=8'h00; font[959]=8'h00;\n  font[960]=8'h00; font[961]=8'h00; font[962]=8'h00; font[963]=8'h06; font[964]=8'h0c; font[965]=8'h18; font[966]=8'h30; font[967]=8'h60; font[968]=8'h30; font[969]=8'h18; font[970]=8'h0c; font[971]=8'h06; font[972]=8'h00; font[973]=8'h00; font[974]=8'h00; font[975]=8'h00;\n  font[976]=8'h00; font[977]=8'h00; font[978]=8'h00; font[979]=8'h00; font[980]=8'h00; font[981]=8'hfe; font[982]=8'h00; font[983]=8'h00; font[984]=8'hfe; font[985]=8'h00; font[986]=8'h00; font[987]=8'h00; font[988]=8'h00; font[989]=8'h00; font[990]=8'h00; font[991]=8'h00;\n  font[992]=8'h00; font[993]=8'h00; font[994]=8'h00; font[995]=8'h60; font[996]=8'h30; font[997]=8'h18; font[998]=8'h0c; font[999]=8'h06; font[1000]=8'h0c; font[1001]=8'h18; font[1002]=8'h30; font[1003]=8'h60; font[1004]=8'h00; font[1005]=8'h00; font[1006]=8'h00; font[1007]=8'h00;\n  font[1008]=8'h00; font[1009]=8'h00; font[1010]=8'h7c; font[1011]=8'hc6; font[1012]=8'hc6; font[1013]=8'hc6; font[1014]=8'h0c; font[1015]=8'h18; font[1016]=8'h18; font[1017]=8'h00; font[1018]=8'h18; font[1019]=8'h18; font[1020]=8'h00; font[1021]=8'h00; font[1022]=8'h00; font[1023]=8'h00;\n  font[1024]=8'h00; font[1025]=8'h00; font[1026]=8'h7c; font[1027]=8'hc6; font[1028]=8'hce; font[1029]=8'hd6; font[1030]=8'hd6; font[1031]=8'hd6; font[1032]=8'hd6; font[1033]=8'hce; font[1034]=8'hc0; font[1035]=8'h7e; font[1036]=8'h00; font[1037]=8'h00; font[1038]=8'h00; font[1039]=8'h00;\n  font[1040]=8'h00; font[1041]=8'h00; font[1042]=8'h7c; font[1043]=8'hc6; font[1044]=8'hc6; font[1045]=8'hc6; font[1046]=8'hc6; font[1047]=8'hfe; font[1048]=8'hc6; font[1049]=8'hc6; font[1050]=8'hc6; font[1051]=8'hc6; font[1052]=8'h00; font[1053]=8'h00; font[1054]=8'h00; font[1055]=8'h00;\n  font[1056]=8'h00; font[1057]=8'h00; font[1058]=8'hfc; font[1059]=8'hc6; font[1060]=8'hc6; font[1061]=8'hc6; font[1062]=8'hfc; font[1063]=8'hc6; font[1064]=8'hc6; font[1065]=8'hc6; font[1066]=8'hc6; font[1067]=8'hfc; font[1068]=8'h00; font[1069]=8'h00; font[1070]=8'h00; font[1071]=8'h00;\n  font[1072]=8'h00; font[1073]=8'h00; font[1074]=8'h7c; font[1075]=8'hc6; font[1076]=8'hc6; font[1077]=8'hc0; font[1078]=8'hc0; font[1079]=8'hc0; font[1080]=8'hc0; font[1081]=8'hc6; font[1082]=8'hc6; font[1083]=8'h7c; font[1084]=8'h00; font[1085]=8'h00; font[1086]=8'h00; font[1087]=8'h00;\n  font[1088]=8'h00; font[1089]=8'h00; font[1090]=8'hf8; font[1091]=8'hcc; font[1092]=8'hc6; font[1093]=8'hc6; font[1094]=8'hc6; font[1095]=8'hc6; font[1096]=8'hc6; font[1097]=8'hc6; font[1098]=8'hcc; font[1099]=8'hf8; font[1100]=8'h00; font[1101]=8'h00; font[1102]=8'h00; font[1103]=8'h00;\n  font[1104]=8'h00; font[1105]=8'h00; font[1106]=8'hfe; font[1107]=8'hc0; font[1108]=8'hc0; font[1109]=8'hc0; font[1110]=8'hf8; font[1111]=8'hc0; font[1112]=8'hc0; font[1113]=8'hc0; font[1114]=8'hc0; font[1115]=8'hfe; font[1116]=8'h00; font[1117]=8'h00; font[1118]=8'h00; font[1119]=8'h00;\n  font[1120]=8'h00; font[1121]=8'h00; font[1122]=8'hfe; font[1123]=8'hc0; font[1124]=8'hc0; font[1125]=8'hc0; font[1126]=8'hf8; font[1127]=8'hc0; font[1128]=8'hc0; font[1129]=8'hc0; font[1130]=8'hc0; font[1131]=8'hc0; font[1132]=8'h00; font[1133]=8'h00; font[1134]=8'h00; font[1135]=8'h00;\n  font[1136]=8'h00; font[1137]=8'h00; font[1138]=8'h7c; font[1139]=8'hc6; font[1140]=8'hc6; font[1141]=8'hc0; font[1142]=8'hc0; font[1143]=8'hde; font[1144]=8'hc6; font[1145]=8'hc6; font[1146]=8'hc6; font[1147]=8'h7c; font[1148]=8'h00; font[1149]=8'h00; font[1150]=8'h00; font[1151]=8'h00;\n  font[1152]=8'h00; font[1153]=8'h00; font[1154]=8'hc6; font[1155]=8'hc6; font[1156]=8'hc6; font[1157]=8'hc6; font[1158]=8'hfe; font[1159]=8'hc6; font[1160]=8'hc6; font[1161]=8'hc6; font[1162]=8'hc6; font[1163]=8'hc6; font[1164]=8'h00; font[1165]=8'h00; font[1166]=8'h00; font[1167]=8'h00;\n  font[1168]=8'h00; font[1169]=8'h00; font[1170]=8'h3c; font[1171]=8'h18; font[1172]=8'h18; font[1173]=8'h18; font[1174]=8'h18; font[1175]=8'h18; font[1176]=8'h18; font[1177]=8'h18; font[1178]=8'h18; font[1179]=8'h3c; font[1180]=8'h00; font[1181]=8'h00; font[1182]=8'h00; font[1183]=8'h00;\n  font[1184]=8'h00; font[1185]=8'h00; font[1186]=8'h1e; font[1187]=8'h0c; font[1188]=8'h0c; font[1189]=8'h0c; font[1190]=8'h0c; font[1191]=8'h0c; font[1192]=8'h0c; font[1193]=8'hcc; font[1194]=8'hcc; font[1195]=8'h78; font[1196]=8'h00; font[1197]=8'h00; font[1198]=8'h00; font[1199]=8'h00;\n  font[1200]=8'h00; font[1201]=8'h00; font[1202]=8'hc6; font[1203]=8'hc6; font[1204]=8'hcc; font[1205]=8'hd8; font[1206]=8'hf0; font[1207]=8'hf0; font[1208]=8'hd8; font[1209]=8'hcc; font[1210]=8'hc6; font[1211]=8'hc6; font[1212]=8'h00; font[1213]=8'h00; font[1214]=8'h00; font[1215]=8'h00;\n  font[1216]=8'h00; font[1217]=8'h00; font[1218]=8'hc0; font[1219]=8'hc0; font[1220]=8'hc0; font[1221]=8'hc0; font[1222]=8'hc0; font[1223]=8'hc0; font[1224]=8'hc0; font[1225]=8'hc0; font[1226]=8'hc0; font[1227]=8'hfe; font[1228]=8'h00; font[1229]=8'h00; font[1230]=8'h00; font[1231]=8'h00;\n  font[1232]=8'h00; font[1233]=8'h00; font[1234]=8'h82; font[1235]=8'hc6; font[1236]=8'hee; font[1237]=8'hfe; font[1238]=8'hd6; font[1239]=8'hc6; font[1240]=8'hc6; font[1241]=8'hc6; font[1242]=8'hc6; font[1243]=8'hc6; font[1244]=8'h00; font[1245]=8'h00; font[1246]=8'h00; font[1247]=8'h00;\n  font[1248]=8'h00; font[1249]=8'h00; font[1250]=8'hc6; font[1251]=8'hc6; font[1252]=8'hc6; font[1253]=8'he6; font[1254]=8'hf6; font[1255]=8'hde; font[1256]=8'hce; font[1257]=8'hc6; font[1258]=8'hc6; font[1259]=8'hc6; font[1260]=8'h00; font[1261]=8'h00; font[1262]=8'h00; font[1263]=8'h00;\n  font[1264]=8'h00; font[1265]=8'h00; font[1266]=8'h7c; font[1267]=8'hc6; font[1268]=8'hc6; font[1269]=8'hc6; font[1270]=8'hc6; font[1271]=8'hc6; font[1272]=8'hc6; font[1273]=8'hc6; font[1274]=8'hc6; font[1275]=8'h7c; font[1276]=8'h00; font[1277]=8'h00; font[1278]=8'h00; font[1279]=8'h00;\n  font[1280]=8'h00; font[1281]=8'h00; font[1282]=8'hfc; font[1283]=8'hc6; font[1284]=8'hc6; font[1285]=8'hc6; font[1286]=8'hc6; font[1287]=8'hfc; font[1288]=8'hc0; font[1289]=8'hc0; font[1290]=8'hc0; font[1291]=8'hc0; font[1292]=8'h00; font[1293]=8'h00; font[1294]=8'h00; font[1295]=8'h00;\n  font[1296]=8'h00; font[1297]=8'h00; font[1298]=8'h7c; font[1299]=8'hc6; font[1300]=8'hc6; font[1301]=8'hc6; font[1302]=8'hc6; font[1303]=8'hc6; font[1304]=8'hc6; font[1305]=8'hc6; font[1306]=8'hde; font[1307]=8'h7c; font[1308]=8'h06; font[1309]=8'h00; font[1310]=8'h00; font[1311]=8'h00;\n  font[1312]=8'h00; font[1313]=8'h00; font[1314]=8'hfc; font[1315]=8'hc6; font[1316]=8'hc6; font[1317]=8'hc6; font[1318]=8'hc6; font[1319]=8'hfc; font[1320]=8'hf0; font[1321]=8'hd8; font[1322]=8'hcc; font[1323]=8'hc6; font[1324]=8'h00; font[1325]=8'h00; font[1326]=8'h00; font[1327]=8'h00;\n  font[1328]=8'h00; font[1329]=8'h00; font[1330]=8'h7c; font[1331]=8'hc6; font[1332]=8'hc0; font[1333]=8'hc0; font[1334]=8'h7c; font[1335]=8'h06; font[1336]=8'h06; font[1337]=8'hc6; font[1338]=8'hc6; font[1339]=8'h7c; font[1340]=8'h00; font[1341]=8'h00; font[1342]=8'h00; font[1343]=8'h00;\n  font[1344]=8'h00; font[1345]=8'h00; font[1346]=8'hff; font[1347]=8'h18; font[1348]=8'h18; font[1349]=8'h18; font[1350]=8'h18; font[1351]=8'h18; font[1352]=8'h18; font[1353]=8'h18; font[1354]=8'h18; font[1355]=8'h18; font[1356]=8'h00; font[1357]=8'h00; font[1358]=8'h00; font[1359]=8'h00;\n  font[1360]=8'h00; font[1361]=8'h00; font[1362]=8'hc6; font[1363]=8'hc6; font[1364]=8'hc6; font[1365]=8'hc6; font[1366]=8'hc6; font[1367]=8'hc6; font[1368]=8'hc6; font[1369]=8'hc6; font[1370]=8'hc6; font[1371]=8'h7c; font[1372]=8'h00; font[1373]=8'h00; font[1374]=8'h00; font[1375]=8'h00;\n  font[1376]=8'h00; font[1377]=8'h00; font[1378]=8'hc6; font[1379]=8'hc6; font[1380]=8'hc6; font[1381]=8'hc6; font[1382]=8'hc6; font[1383]=8'h6c; font[1384]=8'h6c; font[1385]=8'h6c; font[1386]=8'h38; font[1387]=8'h38; font[1388]=8'h00; font[1389]=8'h00; font[1390]=8'h00; font[1391]=8'h00;\n  font[1392]=8'h00; font[1393]=8'h00; font[1394]=8'hc6; font[1395]=8'hc6; font[1396]=8'hc6; font[1397]=8'hc6; font[1398]=8'hc6; font[1399]=8'hd6; font[1400]=8'hfe; font[1401]=8'hee; font[1402]=8'hc6; font[1403]=8'h82; font[1404]=8'h00; font[1405]=8'h00; font[1406]=8'h00; font[1407]=8'h00;\n  font[1408]=8'h00; font[1409]=8'h00; font[1410]=8'hc6; font[1411]=8'hc6; font[1412]=8'h6c; font[1413]=8'h6c; font[1414]=8'h38; font[1415]=8'h38; font[1416]=8'h6c; font[1417]=8'h6c; font[1418]=8'hc6; font[1419]=8'hc6; font[1420]=8'h00; font[1421]=8'h00; font[1422]=8'h00; font[1423]=8'h00;\n  font[1424]=8'h00; font[1425]=8'h00; font[1426]=8'hc3; font[1427]=8'hc3; font[1428]=8'h66; font[1429]=8'h66; font[1430]=8'h3c; font[1431]=8'h18; font[1432]=8'h18; font[1433]=8'h18; font[1434]=8'h18; font[1435]=8'h18; font[1436]=8'h00; font[1437]=8'h00; font[1438]=8'h00; font[1439]=8'h00;\n  font[1440]=8'h00; font[1441]=8'h00; font[1442]=8'hfe; font[1443]=8'h06; font[1444]=8'h06; font[1445]=8'h0c; font[1446]=8'h18; font[1447]=8'h30; font[1448]=8'h60; font[1449]=8'hc0; font[1450]=8'hc0; font[1451]=8'hfe; font[1452]=8'h00; font[1453]=8'h00; font[1454]=8'h00; font[1455]=8'h00;\n  font[1456]=8'h00; font[1457]=8'h00; font[1458]=8'h3c; font[1459]=8'h30; font[1460]=8'h30; font[1461]=8'h30; font[1462]=8'h30; font[1463]=8'h30; font[1464]=8'h30; font[1465]=8'h30; font[1466]=8'h30; font[1467]=8'h3c; font[1468]=8'h00; font[1469]=8'h00; font[1470]=8'h00; font[1471]=8'h00;\n  font[1472]=8'h00; font[1473]=8'h00; font[1474]=8'h60; font[1475]=8'h60; font[1476]=8'h30; font[1477]=8'h30; font[1478]=8'h18; font[1479]=8'h18; font[1480]=8'h0c; font[1481]=8'h0c; font[1482]=8'h06; font[1483]=8'h06; font[1484]=8'h00; font[1485]=8'h00; font[1486]=8'h00; font[1487]=8'h00;\n  font[1488]=8'h00; font[1489]=8'h00; font[1490]=8'h3c; font[1491]=8'h0c; font[1492]=8'h0c; font[1493]=8'h0c; font[1494]=8'h0c; font[1495]=8'h0c; font[1496]=8'h0c; font[1497]=8'h0c; font[1498]=8'h0c; font[1499]=8'h3c; font[1500]=8'h00; font[1501]=8'h00; font[1502]=8'h00; font[1503]=8'h00;\n  font[1504]=8'h00; font[1505]=8'h18; font[1506]=8'h3c; font[1507]=8'h66; font[1508]=8'h00; font[1509]=8'h00; font[1510]=8'h00; font[1511]=8'h00; font[1512]=8'h00; font[1513]=8'h00; font[1514]=8'h00; font[1515]=8'h00; font[1516]=8'h00; font[1517]=8'h00; font[1518]=8'h00; font[1519]=8'h00;\n  font[1520]=8'h00; font[1521]=8'h00; font[1522]=8'h00; font[1523]=8'h00; font[1524]=8'h00; font[1525]=8'h00; font[1526]=8'h00; font[1527]=8'h00; font[1528]=8'h00; font[1529]=8'h00; font[1530]=8'h00; font[1531]=8'h00; font[1532]=8'h00; font[1533]=8'hfe; font[1534]=8'h00; font[1535]=8'h00;\n  font[1536]=8'h30; font[1537]=8'h18; font[1538]=8'h00; font[1539]=8'h00; font[1540]=8'h00; font[1541]=8'h00; font[1542]=8'h00; font[1543]=8'h00; font[1544]=8'h00; font[1545]=8'h00; font[1546]=8'h00; font[1547]=8'h00; font[1548]=8'h00; font[1549]=8'h00; font[1550]=8'h00; font[1551]=8'h00;\n  font[1552]=8'h00; font[1553]=8'h00; font[1554]=8'h00; font[1555]=8'h00; font[1556]=8'h00; font[1557]=8'h7c; font[1558]=8'h06; font[1559]=8'h7e; font[1560]=8'hc6; font[1561]=8'hc6; font[1562]=8'hc6; font[1563]=8'h7e; font[1564]=8'h00; font[1565]=8'h00; font[1566]=8'h00; font[1567]=8'h00;\n  font[1568]=8'h00; font[1569]=8'h00; font[1570]=8'hc0; font[1571]=8'hc0; font[1572]=8'hc0; font[1573]=8'hfc; font[1574]=8'hc6; font[1575]=8'hc6; font[1576]=8'hc6; font[1577]=8'hc6; font[1578]=8'hc6; font[1579]=8'hfc; font[1580]=8'h00; font[1581]=8'h00; font[1582]=8'h00; font[1583]=8'h00;\n  font[1584]=8'h00; font[1585]=8'h00; font[1586]=8'h00; font[1587]=8'h00; font[1588]=8'h00; font[1589]=8'h7c; font[1590]=8'hc6; font[1591]=8'hc0; font[1592]=8'hc0; font[1593]=8'hc0; font[1594]=8'hc6; font[1595]=8'h7c; font[1596]=8'h00; font[1597]=8'h00; font[1598]=8'h00; font[1599]=8'h00;\n  font[1600]=8'h00; font[1601]=8'h00; font[1602]=8'h06; font[1603]=8'h06; font[1604]=8'h06; font[1605]=8'h7e; font[1606]=8'hc6; font[1607]=8'hc6; font[1608]=8'hc6; font[1609]=8'hc6; font[1610]=8'hc6; font[1611]=8'h7e; font[1612]=8'h00; font[1613]=8'h00; font[1614]=8'h00; font[1615]=8'h00;\n  font[1616]=8'h00; font[1617]=8'h00; font[1618]=8'h00; font[1619]=8'h00; font[1620]=8'h00; font[1621]=8'h7c; font[1622]=8'hc6; font[1623]=8'hc6; font[1624]=8'hfe; font[1625]=8'hc0; font[1626]=8'hc0; font[1627]=8'h7c; font[1628]=8'h00; font[1629]=8'h00; font[1630]=8'h00; font[1631]=8'h00;\n  font[1632]=8'h00; font[1633]=8'h00; font[1634]=8'h1e; font[1635]=8'h30; font[1636]=8'h30; font[1637]=8'hfc; font[1638]=8'h30; font[1639]=8'h30; font[1640]=8'h30; font[1641]=8'h30; font[1642]=8'h30; font[1643]=8'h30; font[1644]=8'h00; font[1645]=8'h00; font[1646]=8'h00; font[1647]=8'h00;\n  font[1648]=8'h00; font[1649]=8'h00; font[1650]=8'h00; font[1651]=8'h00; font[1652]=8'h00; font[1653]=8'h7e; font[1654]=8'hc6; font[1655]=8'hc6; font[1656]=8'hc6; font[1657]=8'hc6; font[1658]=8'hc6; font[1659]=8'h7e; font[1660]=8'h06; font[1661]=8'h06; font[1662]=8'h7c; font[1663]=8'h00;\n  font[1664]=8'h00; font[1665]=8'h00; font[1666]=8'hc0; font[1667]=8'hc0; font[1668]=8'hc0; font[1669]=8'hfc; font[1670]=8'hc6; font[1671]=8'hc6; font[1672]=8'hc6; font[1673]=8'hc6; font[1674]=8'hc6; font[1675]=8'hc6; font[1676]=8'h00; font[1677]=8'h00; font[1678]=8'h00; font[1679]=8'h00;\n  font[1680]=8'h00; font[1681]=8'h00; font[1682]=8'h18; font[1683]=8'h18; font[1684]=8'h00; font[1685]=8'h38; font[1686]=8'h18; font[1687]=8'h18; font[1688]=8'h18; font[1689]=8'h18; font[1690]=8'h18; font[1691]=8'h3c; font[1692]=8'h00; font[1693]=8'h00; font[1694]=8'h00; font[1695]=8'h00;\n  font[1696]=8'h00; font[1697]=8'h00; font[1698]=8'h06; font[1699]=8'h06; font[1700]=8'h00; font[1701]=8'h0e; font[1702]=8'h06; font[1703]=8'h06; font[1704]=8'h06; font[1705]=8'h06; font[1706]=8'h06; font[1707]=8'h06; font[1708]=8'h66; font[1709]=8'h66; font[1710]=8'h3c; font[1711]=8'h00;\n  font[1712]=8'h00; font[1713]=8'h00; font[1714]=8'hc0; font[1715]=8'hc0; font[1716]=8'hc0; font[1717]=8'hc6; font[1718]=8'hcc; font[1719]=8'hd8; font[1720]=8'hf0; font[1721]=8'hd8; font[1722]=8'hcc; font[1723]=8'hc6; font[1724]=8'h00; font[1725]=8'h00; font[1726]=8'h00; font[1727]=8'h00;\n  font[1728]=8'h00; font[1729]=8'h00; font[1730]=8'h38; font[1731]=8'h18; font[1732]=8'h18; font[1733]=8'h18; font[1734]=8'h18; font[1735]=8'h18; font[1736]=8'h18; font[1737]=8'h18; font[1738]=8'h18; font[1739]=8'h3c; font[1740]=8'h00; font[1741]=8'h00; font[1742]=8'h00; font[1743]=8'h00;\n  font[1744]=8'h00; font[1745]=8'h00; font[1746]=8'h00; font[1747]=8'h00; font[1748]=8'h00; font[1749]=8'hfc; font[1750]=8'hd6; font[1751]=8'hd6; font[1752]=8'hd6; font[1753]=8'hd6; font[1754]=8'hd6; font[1755]=8'hd6; font[1756]=8'h00; font[1757]=8'h00; font[1758]=8'h00; font[1759]=8'h00;\n  font[1760]=8'h00; font[1761]=8'h00; font[1762]=8'h00; font[1763]=8'h00; font[1764]=8'h00; font[1765]=8'hfc; font[1766]=8'hc6; font[1767]=8'hc6; font[1768]=8'hc6; font[1769]=8'hc6; font[1770]=8'hc6; font[1771]=8'hc6; font[1772]=8'h00; font[1773]=8'h00; font[1774]=8'h00; font[1775]=8'h00;\n  font[1776]=8'h00; font[1777]=8'h00; font[1778]=8'h00; font[1779]=8'h00; font[1780]=8'h00; font[1781]=8'h7c; font[1782]=8'hc6; font[1783]=8'hc6; font[1784]=8'hc6; font[1785]=8'hc6; font[1786]=8'hc6; font[1787]=8'h7c; font[1788]=8'h00; font[1789]=8'h00; font[1790]=8'h00; font[1791]=8'h00;\n  font[1792]=8'h00; font[1793]=8'h00; font[1794]=8'h00; font[1795]=8'h00; font[1796]=8'h00; font[1797]=8'hfc; font[1798]=8'hc6; font[1799]=8'hc6; font[1800]=8'hc6; font[1801]=8'hc6; font[1802]=8'hc6; font[1803]=8'hfc; font[1804]=8'hc0; font[1805]=8'hc0; font[1806]=8'hc0; font[1807]=8'h00;\n  font[1808]=8'h00; font[1809]=8'h00; font[1810]=8'h00; font[1811]=8'h00; font[1812]=8'h00; font[1813]=8'h7e; font[1814]=8'hc6; font[1815]=8'hc6; font[1816]=8'hc6; font[1817]=8'hc6; font[1818]=8'hc6; font[1819]=8'h7e; font[1820]=8'h06; font[1821]=8'h06; font[1822]=8'h06; font[1823]=8'h00;\n  font[1824]=8'h00; font[1825]=8'h00; font[1826]=8'h00; font[1827]=8'h00; font[1828]=8'h00; font[1829]=8'hde; font[1830]=8'hf0; font[1831]=8'he0; font[1832]=8'hc0; font[1833]=8'hc0; font[1834]=8'hc0; font[1835]=8'hc0; font[1836]=8'h00; font[1837]=8'h00; font[1838]=8'h00; font[1839]=8'h00;\n  font[1840]=8'h00; font[1841]=8'h00; font[1842]=8'h00; font[1843]=8'h00; font[1844]=8'h00; font[1845]=8'h7e; font[1846]=8'hc0; font[1847]=8'hc0; font[1848]=8'h7c; font[1849]=8'h06; font[1850]=8'h06; font[1851]=8'hfc; font[1852]=8'h00; font[1853]=8'h00; font[1854]=8'h00; font[1855]=8'h00;\n  font[1856]=8'h00; font[1857]=8'h00; font[1858]=8'h30; font[1859]=8'h30; font[1860]=8'h30; font[1861]=8'hfc; font[1862]=8'h30; font[1863]=8'h30; font[1864]=8'h30; font[1865]=8'h30; font[1866]=8'h30; font[1867]=8'h1e; font[1868]=8'h00; font[1869]=8'h00; font[1870]=8'h00; font[1871]=8'h00;\n  font[1872]=8'h00; font[1873]=8'h00; font[1874]=8'h00; font[1875]=8'h00; font[1876]=8'h00; font[1877]=8'hc6; font[1878]=8'hc6; font[1879]=8'hc6; font[1880]=8'hc6; font[1881]=8'hc6; font[1882]=8'hc6; font[1883]=8'h7e; font[1884]=8'h00; font[1885]=8'h00; font[1886]=8'h00; font[1887]=8'h00;\n  font[1888]=8'h00; font[1889]=8'h00; font[1890]=8'h00; font[1891]=8'h00; font[1892]=8'h00; font[1893]=8'hc6; font[1894]=8'hc6; font[1895]=8'hc6; font[1896]=8'h6c; font[1897]=8'h6c; font[1898]=8'h38; font[1899]=8'h38; font[1900]=8'h00; font[1901]=8'h00; font[1902]=8'h00; font[1903]=8'h00;\n  font[1904]=8'h00; font[1905]=8'h00; font[1906]=8'h00; font[1907]=8'h00; font[1908]=8'h00; font[1909]=8'hc6; font[1910]=8'hc6; font[1911]=8'hd6; font[1912]=8'hd6; font[1913]=8'hd6; font[1914]=8'hd6; font[1915]=8'h7c; font[1916]=8'h00; font[1917]=8'h00; font[1918]=8'h00; font[1919]=8'h00;\n  font[1920]=8'h00; font[1921]=8'h00; font[1922]=8'h00; font[1923]=8'h00; font[1924]=8'h00; font[1925]=8'hc6; font[1926]=8'hc6; font[1927]=8'h6c; font[1928]=8'h38; font[1929]=8'h6c; font[1930]=8'hc6; font[1931]=8'hc6; font[1932]=8'h00; font[1933]=8'h00; font[1934]=8'h00; font[1935]=8'h00;\n  font[1936]=8'h00; font[1937]=8'h00; font[1938]=8'h00; font[1939]=8'h00; font[1940]=8'h00; font[1941]=8'hc6; font[1942]=8'hc6; font[1943]=8'hc6; font[1944]=8'hc6; font[1945]=8'hc6; font[1946]=8'hc6; font[1947]=8'h7e; font[1948]=8'h06; font[1949]=8'h06; font[1950]=8'h7c; font[1951]=8'h00;\n  font[1952]=8'h00; font[1953]=8'h00; font[1954]=8'h00; font[1955]=8'h00; font[1956]=8'h00; font[1957]=8'hfe; font[1958]=8'h0c; font[1959]=8'h18; font[1960]=8'h30; font[1961]=8'h60; font[1962]=8'hc0; font[1963]=8'hfe; font[1964]=8'h00; font[1965]=8'h00; font[1966]=8'h00; font[1967]=8'h00;\n  font[1968]=8'h00; font[1969]=8'h00; font[1970]=8'h1c; font[1971]=8'h30; font[1972]=8'h30; font[1973]=8'h30; font[1974]=8'h60; font[1975]=8'h30; font[1976]=8'h30; font[1977]=8'h30; font[1978]=8'h30; font[1979]=8'h1c; font[1980]=8'h00; font[1981]=8'h00; font[1982]=8'h00; font[1983]=8'h00;\n  font[1984]=8'h00; font[1985]=8'h00; font[1986]=8'h18; font[1987]=8'h18; font[1988]=8'h18; font[1989]=8'h18; font[1990]=8'h18; font[1991]=8'h18; font[1992]=8'h18; font[1993]=8'h18; font[1994]=8'h18; font[1995]=8'h18; font[1996]=8'h00; font[1997]=8'h00; font[1998]=8'h00; font[1999]=8'h00;\n  font[2000]=8'h00; font[2001]=8'h00; font[2002]=8'h70; font[2003]=8'h18; font[2004]=8'h18; font[2005]=8'h18; font[2006]=8'h0c; font[2007]=8'h18; font[2008]=8'h18; font[2009]=8'h18; font[2010]=8'h18; font[2011]=8'h70; font[2012]=8'h00; font[2013]=8'h00; font[2014]=8'h00; font[2015]=8'h00;\n  font[2016]=8'h00; font[2017]=8'h00; font[2018]=8'h00; font[2019]=8'h00; font[2020]=8'h00; font[2021]=8'h00; font[2022]=8'h73; font[2023]=8'hdb; font[2024]=8'hce; font[2025]=8'h00; font[2026]=8'h00; font[2027]=8'h00; font[2028]=8'h00; font[2029]=8'h00; font[2030]=8'h00; font[2031]=8'h00;\n  font[2032]=8'h00; font[2033]=8'h00; font[2034]=8'h00; font[2035]=8'h00; font[2036]=8'h00; font[2037]=8'h00; font[2038]=8'h00; font[2039]=8'h00; font[2040]=8'h00; font[2041]=8'h00; font[2042]=8'h00; font[2043]=8'h00; font[2044]=8'h00; font[2045]=8'h00; font[2046]=8'h00; font[2047]=8'h00;\nend\n// cell read at phase 0, its glyph row at phase 1, both ready by phase 7\nreg [7:0] fq = 0, nattr = 0, nbits = 0, attr = 0, bits = 0;\nalways @(posedge clk) begin\n  fq <= font[{q[6:0], fy[3:0]}];\n  if (x[2:0] == 1) nattr <= q[15:8];\n  if (x[2:0] == 2) nbits <= fq;\n  if (x[2:0] == 7) begin attr <= nattr; bits <= nbits; end\nend\n\n// 16 colours (3 bits red, 3 green, 2 blue); 0 = see-through\nfunction [7:0] pal(input [3:0] i);\n  case (i)\n    1:  pal = 8'b000_000_00;   // black\n    2:  pal = 8'b000_000_01;   // navy (panels)\n    3:  pal = 8'b011_100_10;   // muted\n    4:  pal = 8'b111_111_11;   // white\n    5:  pal = 8'b010_110_11;   // accent blue\n    6:  pal = 8'b011_110_10;   // green\n    7:  pal = 8'b111_101_01;   // orange\n    8:  pal = 8'b111_010_01;   // red\n    9:  pal = 8'b110_101_00;   // yellow\n    10: pal = 8'b001_001_01;   // dark grey\n    11: pal = 8'b011_011_01;   // grey\n    12: pal = 8'b110_110_10;   // cream\n    13: pal = 8'b110_010_01;   // rose\n    14: pal = 8'b011_001_00;   // maroon\n    15: pal = 8'b010_010_01;   // slate\n    default: pal = 8'd0;\n  endcase\nendfunction\nreg [3:0] ci = 0;\nreg [7:0] c2 = 0, c3 = 0;\nreg v2 = 0, v3 = 0;\nalways @(posedge clk) begin\n  ci <= bits[~x[2:0]] ? attr[3:0] : attr[7:4];   // stage 1\n  c2 <= pal(ci); v2 <= ci != 0;                  // stage 2\n  c3 <= c2; v3 <= v2;                            // stage 3\nend\nassign vis = v3;\nassign color = c3;\n"
          },
          "id": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
          "position": {
            "x": 2200,
            "y": 2440
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
                  "name": "gfx",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "scene",
                  "range": "[3:0]",
                  "size": 4
                },
                {
                  "name": "text_on"
                },
                {
                  "name": "centre"
                }
              ]
            },
            "params": [],
            "code": "// Scene director\n// Cycles through scenes 0-7 on its own (~70 s loop), or holds the one the\n// PC asks for. Bridge command 'G' byte: bit 7 = cycle on its own, bit 6 =\n// hide the text layer, bit 5 = Life grid in the middle (else at the left,\n// beside the text), bits 3-0 = scene to hold. 255 (the power-up default)\n// = cycle, no text, grid in the middle.\n//   0 Life, rainbow cells         5 interference\n//   1 plasma                      6 all 256 colours\n//   2 Life over the plasma        7 Life, rainbow cells over XOR\n//   3 XOR fractal                 8 text only, on black\n//   4 Life over the interference\nreg [7:0] g1 = 8'hFF, g2 = 8'hFF;         // from the 24 MHz side\nreg [5:0] fr = 0;                         // 64 frames = ~1 s\nreg [3:0] left = 10;\nreg [2:0] step = 0;\nreg [3:0] s = 0;\nreg ton = 0, mid = 1;\nwire tick = (x == 0) && (y == 480) && (fr == 63);\nfunction [3:0] len(input [2:0] i);        // seconds per scene, minus 1\n  len = (i == 0 || i == 2 || i == 4 || i == 7) ? 4'd9 : 4'd5;\nendfunction\nalways @(posedge clk) begin\n  g1 <= gfx; g2 <= g1;\n  if ((x == 0) && (y == 480)) fr <= fr + 1;\n  if (tick) begin\n    if (left == 0) begin step <= step + 1; left <= len(step + 3'd1); end\n    else left <= left - 1;\n  end\n  if ((x == 0) && (y == 480)) begin       // change scene between frames\n    s <= g2[7] ? {1'b0, step} : g2[3:0];\n    ton <= !g2[6];\n    mid <= g2[5];\n  end\nend\nassign scene = s;\nassign text_on = ton;\nassign centre = mid;\n"
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
                  "name": "text_on"
                },
                {
                  "name": "tvis"
                },
                {
                  "name": "tcolor",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "scene",
                  "range": "[3:0]",
                  "size": 4
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
            "code": "// Compositor + VGA output\n// Every effect, the Life layer and the text are computed for every pixel,\n// all the time; this block layers them according to the scene, with the\n// text on top. The inputs are 3 clocks behind the beam, so sync and\n// blanking are delayed to match.\nreg [2:0] hsd = 3'b111, vsd = 3'b111, ded = 0;\nreg [7:0] px = 0;\nreg hso = 1, vso = 1;\nfunction [7:0] dim(input [7:0] c);        // half brightness\n  dim = {1'b0, c[7:6], 1'b0, c[4:3], 1'b0, c[1]};\nendfunction\nwire life_on = scene == 0 || scene == 2 || scene == 4 || scene == 7;\nwire rainbow = scene == 0 || scene == 7;\nreg [7:0] back;\nalways @(*) begin\n  case (scene)\n    0: back = 8'b000_000_01;              // dark blue\n    1: back = fx1;\n    2: back = dim(fx1);\n    3: back = fx2;\n    4: back = dim(fx3);\n    5: back = fx3;\n    6: back = fx4;\n    7: back = dim(dim(fx2));\n    default: back = 8'd0;                 // 8: text only\n  endcase\nend\nalways @(posedge clk) begin\n  hsd <= {hsd[1:0], hs};\n  vsd <= {vsd[1:0], vs};\n  ded <= {ded[1:0], de};\n  if (!ded[2]) px <= 8'd0;\n  else if (text_on && tvis) px <= tcolor;\n  else if (life_on && cell) px <= rainbow ? color : 8'hFF;\n  else if (life_on && ingrid) px <= scene == 0 ? 8'd0 : back;\n  else if (life_on && frame) px <= 8'b101_101_10;\n  else px <= back;\n  hso <= hsd[2];\n  vso <= vsd[2];\nend\nassign r = px[7:5];\nassign g = px[4:2];\nassign b = px[1:0];\nassign hsync = hso;\nassign vsync = vso;\n"
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
            "info": "## Icey showcase + VGA\n\nRun `./firmware/life-demo.sh --vga` (it builds and loads this project) with a VGA monitor plugged into the board. The whole show runs **on the monitor**: board check, the live Life grid with its stats, the benchmark and proof, patterns from the microSD, the Monkeytype-style typing test and the racing-the-beam effects. The Life engine, microSD, USB keyboard, button and RGB LED share one 3 Mbaud link, and the PC draws text on an 80x30 text layer the FPGA overlays on the picture.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": -300
          },
          "size": {
            "width": 960,
            "height": 260
          }
        },
        {
          "id": "50f99fe2-e389-4939-99b3-c6b9cb2fbb01",
          "type": "basic.info",
          "data": {
            "info": "### Why this needs an FPGA\n\n* The Life engine computes a whole 128-cell row per clock at 24 MHz, while the VGA side draws 25 million pixels a second at 25 MHz. Two clock domains, one chip, neither waits for the other.\n* Every pixel, **all four effects, the Life layer and the text are computed at once**; the compositor just picks how to layer them.\n* No framebuffer: the display keeps a 2 KB copy of the grid and 80x30 text cells in SPRAM; everything else is computed as the beam draws it.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": 700
          },
          "size": {
            "width": 480,
            "height": 380
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
          "size": 4
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
        },
        {
          "source": {
            "block": "39e9458f-85f8-44b3-a336-c742f136e704",
            "port": "pclk"
          },
          "target": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "66f2339c-58f7-4f9b-ba47-964a5049fa7d",
            "port": "x"
          },
          "target": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
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
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "txt_addr"
          },
          "target": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "waddr"
          },
          "size": 12
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "txt_data"
          },
          "target": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "wdata"
          },
          "size": 16
        },
        {
          "source": {
            "block": "a4c8f81d-5717-4720-8323-0e322f707f40",
            "port": "txt_tog"
          },
          "target": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "wtog"
          }
        },
        {
          "source": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "vis"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "tvis"
          }
        },
        {
          "source": {
            "block": "7940ef4d-9c31-54c1-8d4c-3e8447e25ffb",
            "port": "color"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "tcolor"
          },
          "size": 8
        },
        {
          "source": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "text_on"
          },
          "target": {
            "block": "03e3bee4-0eaa-42b8-a0cb-3d43b11cb088",
            "port": "text_on"
          }
        },
        {
          "source": {
            "block": "6ab860e1-5288-4f70-bab1-3652aff90586",
            "port": "centre"
          },
          "target": {
            "block": "a2299b47-0e27-4d7b-b50d-e68c631e9d09",
            "port": "centre"
          }
        }
      ]
    }
  },
  "dependencies": {}
}