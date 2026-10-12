{
  "version": "1.2",
  "package": {
    "name": "Icey showcase",
    "version": "1.0",
    "description": "Game of Life (128 cells/clock) plus SD, USB host, button and RGB through one link",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "Icey",
    "graph": {
      "blocks": [
        {
          "id": "e304087e-424e-41b0-b6ae-aefd0bad578c",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [],
              "out": [
                {
                  "name": "clk"
                }
              ]
            },
            "params": [],
            "code": "// 24 MHz clock\n// Icey has no crystal for the FPGA: internal 48 MHz oscillator / 2\nSB_HFOSC #(.CLKHF_DIV(\"0b01\")) osc (\n  .CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));\n"
          },
          "position": {
            "x": 40,
            "y": 360
          },
          "size": {
            "width": 360,
            "height": 140
          }
        },
        {
          "id": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
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
            "x": 480,
            "y": 120
          },
          "size": {
            "width": 440,
            "height": 360
          }
        },
        {
          "id": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
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
            "x": 1960,
            "y": 560
          },
          "size": {
            "width": 440,
            "height": 300
          }
        },
        {
          "id": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
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
                }
              ]
            },
            "params": [],
            "code": "// Grid memory + scheduler + PC link\n// The 128x128 grid lives in block RAM, two copies (\"banks\"): the engine\n// reads generation N from one bank and writes generation N+1 to the other.\n// Every clock it reads one row, slides a 3-row window (above/row/below) and\n// the 128 rule copies produce a whole new row at once.\n//\n// PC commands (bytes on the UART):\n//   'S'         -> 4-byte generation counter + 2048-byte grid snapshot\n//   'L' + 2048  -> load a grid                         (replies 'k')\n//   'V' + n     -> speed: 0 = flat out, 255 = stop,\n//                  else wait n*65536 clocks (n*2.7 ms) per generation\n//   'N'         -> single step while stopped           (replies 'k')\n// Grid format: row 0..127, 16 bytes per row, bit x of the row = column x.\n\nreg [127:0] mem [0:255];      // {bank, row}\nreg [7:0]   raddr = 0;\nreg [127:0] rdata = 0;\nreg         we = 0;\nreg [7:0]   waddr = 0;\nreg [127:0] wdata = 0;\nalways @(posedge clk) begin\n  rdata <= mem[raddr];\n  if (we) mem[waddr] <= wdata;\nend\n\n// ---------------- generation engine ----------------\nreg         bank = 0;              // bank holding the current generation\nreg [31:0]  gen = 0;\nreg [7:0]   speed = 255;           // start stopped until the PC says go\nreg [23:0]  wait_cnt = 0;\nreg         running = 0;           // a generation is in progress\nreg [7:0]   i = 0;                 // read index 0..129\nreg         rd_v0 = 0, rd_v = 0;   // address issued / rdata valid this cycle\nreg [1:0]   filled = 0;            // rows in the window (saturates at 3)\nreg         win = 0;               // window full: compute a row this cycle\nreg [6:0]   wrow = 0;\nreg [127:0] a = 0, r = 0, b = 0;\nreg         pause_req = 0;         // PC link wants the engine parked\nreg         step_req = 0;          // engine-owned latch for single steps\nreg         step_pulse = 0, speed_pulse = 0;   // one-clock requests from PC link\nreg         gen_tick = 0;          // one clock when a generation completes\nassign above = a; assign row = r; assign below = b;\nwire idle = !running;\n\n// engine-side memory signals (muxed with the PC link below)\nreg [7:0]   e_raddr;\nreg         e_we;\nreg [7:0]   e_waddr;\nreg [127:0] e_wdata;\n\nalways @(posedge clk) begin\n  e_we <= 0;\n  gen_tick <= 0;\n  if (step_pulse) step_req <= 1;\n  if (!running) begin\n    rd_v0 <= 0; rd_v <= 0; win <= 0;\n    if (speed_pulse) wait_cnt <= 0;               // new speed takes effect now\n    else if (wait_cnt != 0) wait_cnt <= wait_cnt - 1;\n    else if (!pause_req && (speed != 255 || step_req)) begin\n      running <= 1; i <= 0; filled <= 0; wrow <= 0; step_req <= 0;\n    end\n  end else begin\n    // 1) issue reads for rows 127, 0, 1, ..., 127, 0 (wrap-around)\n    if (i <= 129) begin\n      e_raddr <= {bank, i[6:0] - 7'd1};\n      i <= i + 1;\n    end\n    rd_v0 <= (i <= 129);\n    rd_v  <= rd_v0;                 // block RAM answers one clock later\n    // 2) slide the 3-row window\n    if (rd_v) begin\n      a <= r; r <= b; b <= rdata;\n      if (filled != 3) filled <= filled + 1;\n    end\n    win <= rd_v && filled >= 2;\n    // 3) register the new row from the 128 rule copies, write next cycle\n    if (win) begin\n      e_we <= 1; e_waddr <= {~bank, wrow}; e_wdata <= new_row;\n      wrow <= wrow + 1;\n      if (wrow == 127) begin\n        running <= 0; bank <= ~bank; gen <= gen + 1; gen_tick <= 1;\n        wait_cnt <= (speed == 255) ? 24'd0 : {speed, 16'h0};\n      end\n    end\n  end\nend\n\n// ---------------- PC link ----------------\nlocalparam H_IDLE = 0, H_SPEED = 1, H_WAIT = 2, H_DUMPGEN = 3, H_DUMPRD = 4,\n           H_DUMPROW = 5, H_LOAD = 6, H_ACK = 7, H_STEP = 8;\nreg [3:0]   hs = H_IDLE;\nreg [7:0]   cmd = 0;\nreg [127:0] acc = 0;               // load accumulator / dump shift register\nreg [3:0]   nbyte = 0;\nreg [7:0]   hrow = 0;\nreg [2:0]   gbyte = 0;\nreg [31:0]  gsnap = 0;\nreg         h_we = 0;\nreg [127:0] h_wdata = 0;\nreg [7:0]   h_waddr = 0;\nreg [7:0]   txd = 0;\nreg         txs = 0;\nreg [1:0]   rdwait = 0;\n// register + pre-decode received bytes (keeps the state machine fast)\nreg [7:0]   rxd = 0;\nreg         rxv = 0, is_s = 0, is_l = 0, is_v = 0, is_n = 0;\nalways @(posedge clk) begin\n  rxv <= rx_valid; rxd <= rx_data;\n  is_s <= rx_data == \"S\"; is_l <= rx_data == \"L\";\n  is_v <= rx_data == \"V\"; is_n <= rx_data == \"N\";\nend\nalways @(posedge clk) begin\n  txs <= 0; h_we <= 0; step_pulse <= 0; speed_pulse <= 0;\n  case (hs)\n    H_IDLE: if (rxv) begin\n      cmd <= rxd;\n      if (is_v) hs <= H_SPEED;\n      else if (is_n) begin step_pulse <= 1; hs <= H_STEP; end\n      else if (is_s || is_l) begin pause_req <= 1; hs <= H_WAIT; end\n    end\n    H_SPEED: if (rxv) begin speed <= rxd; speed_pulse <= 1; hs <= H_ACK; end\n    H_STEP: if (gen_tick) hs <= H_ACK;            // ack once the step is done\n    H_WAIT: if (idle) begin                       // engine parked between gens\n      hrow <= 0; nbyte <= 0; gbyte <= 0; gsnap <= gen;\n      hs <= (cmd == \"S\") ? H_DUMPGEN : H_LOAD;\n    end\n    H_DUMPGEN: if (!tx_busy && !txs) begin\n      txd <= gsnap[7:0]; gsnap <= gsnap >> 8; txs <= 1;\n      gbyte <= gbyte + 1;\n      if (gbyte == 3) begin hs <= H_DUMPRD; rdwait <= 0; end\n    end\n    H_DUMPRD: begin                               // read row hrow (2-cycle wait)\n      rdwait <= rdwait + 1;\n      if (rdwait == 2) begin acc <= rdata; nbyte <= 0; hs <= H_DUMPROW; end\n    end\n    H_DUMPROW: if (!tx_busy && !txs) begin\n      txd <= acc[7:0]; acc <= acc >> 8; txs <= 1;\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        hrow <= hrow + 1; rdwait <= 0;\n        if (hrow == 127) begin pause_req <= 0; hs <= H_IDLE; end\n        else hs <= H_DUMPRD;\n      end\n    end\n    H_LOAD: if (rxv) begin\n      acc <= {rxd, acc[127:8]};\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        h_we <= 1; h_waddr <= {bank, hrow[6:0]}; h_wdata <= {rxd, acc[127:8]};\n        hrow <= hrow + 1;\n        if (hrow == 127) hs <= H_ACK;\n      end\n    end\n    H_ACK: if (!tx_busy && !txs) begin\n      txd <= \"k\"; txs <= 1; pause_req <= 0; hs <= H_IDLE;\n    end\n  endcase\nend\n\n// memory port mux: the PC link only touches memory while the engine is parked\nalways @(*) begin\n  raddr = running ? e_raddr : {bank, hrow[6:0]};\n  we    = running ? e_we : (h_we | e_we);\n  waddr = h_we ? h_waddr : e_waddr;\n  wdata = h_we ? h_wdata : e_wdata;\nend\n\nassign tx_data = txd;\nassign tx_send = txs;\nassign cmd_idle = (hs == H_IDLE);\n// LED: blinks with the generation count (slower bit when running flat out)\nassign led = (speed == 0) ? gen[18] : gen[2];\n"
          },
          "position": {
            "x": 1000,
            "y": 40
          },
          "size": {
            "width": 860,
            "height": 1180
          }
        },
        {
          "id": "ecf7ce8f-4213-48f2-b888-8c1c86d18f22",
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
            "x": 1960,
            "y": 40
          },
          "size": {
            "width": 560,
            "height": 440
          }
        },
        {
          "id": "d720e051-3545-4196-8ce3-8df5948d8bb1",
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
            "code": "// Command router\n// One UART, two command sets: S L V N go to the Life engine,\n// X Y C D I go to the I/O bridge. The first byte of a command picks the\n// owner, which then gets every byte until it is back to idle.\nreg [1:0] owner = 0;              // 0 none, 1 life, 2 io\nreg started = 0;\nwire is_life = rx_data == \"S\" || rx_data == \"L\" || rx_data == \"V\" || rx_data == \"N\";\nwire is_io   = rx_data == \"X\" || rx_data == \"Y\" || rx_data == \"C\" || rx_data == \"D\" ||\n               rx_data == \"I\";\nwire [1:0] route = owner != 0 ? owner : is_life ? 2'd1 : is_io ? 2'd2 : 2'd0;\nwire sub_idle = owner == 1 ? life_idle : io_idle;\nalways @(posedge clk) begin\n  if (owner == 0) begin\n    if (rx_valid && route != 0) begin owner <= route; started <= 0; end\n  end else if (!sub_idle) started <= 1;\n  else if (started) owner <= 0;\nend\nassign life_rx_valid = rx_valid && route == 1;\nassign io_rx_valid   = rx_valid && route == 2;\nassign tx_send = life_tx_send | io_tx_send;\nassign tx_data = life_tx_send ? life_tx_data : io_tx_data;\n"
          },
          "position": {
            "x": 1000,
            "y": -560
          },
          "size": {
            "width": 700,
            "height": 520
          }
        },
        {
          "id": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
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
                }
              ]
            },
            "params": [],
            "code": "// I/O bridge: SPI (SD + USB host), button, LEDs\n// Lets the PC use the board's peripherals through the FPGA:\n//   'X' n data      SPI exchange of n bytes (0 = 256), replies n bytes\n//   'Y' cs n data   same, with chip selects in mask cs (bit0 SD, bit1 USB)\n//                   pulled low around the transfer\n//   'C' v           bit0 SD_CS, bit1 USB_CS, bit2 USB_RST, bit3 LED1,\n//                   bit4 red, bit5 blue, bit6 green                -> 'k'\n//   'D' d           SPI clock = 24 MHz / (2*(d+1))                 -> 'k'\n//   'I'             bit0 SW2 (1 = released), bit1 USB_INT, bit2 SD_MISO\n\n// ---- SPI master, mode 0 ----\nreg [7:0] div = 29;\nreg [7:0] scnt = 0; reg [2:0] sbit = 0;\nreg [7:0] stx = 0, srx = 0, sin = 0;\nreg sck = 0, sbusy = 0, sgo = 0, sdone = 0;\nalways @(posedge clk) begin\n  sdone <= 0;\n  if (!sbusy) begin\n    if (sgo) begin sbusy <= 1; stx <= sin; sbit <= 0; scnt <= div; sck <= 0; end\n  end else if (scnt != 0) scnt <= scnt - 1;\n  else begin\n    scnt <= div;\n    if (!sck) begin sck <= 1; srx <= {srx[6:0], sd_miso}; end\n    else begin\n      sck <= 0;\n      if (sbit == 7) begin sbusy <= 0; sdone <= 1; end\n      else begin sbit <= sbit + 1; stx <= {stx[6:0], 1'b0}; end\n    end\n  end\nend\nassign sd_sck = sck;\nassign sd_mosi = stx[7];\n\n// ---- command handler ----\nreg [7:0] outs = 8'b0000_0111;\nreg [1:0] csm = 0;                         // chip selects held low during 'Y'\nreg [7:0] buffer [0:255];\nreg [7:0] bwa = 0, bra = 0, bwd = 0, brd = 0; reg bwe = 0;\nalways @(posedge clk) begin\n  if (bwe) buffer[bwa] <= bwd;\n  brd <= buffer[bra];\nend\nlocalparam IDLE = 0, LEN = 1, FILL = 2, XRD = 3, XGO = 4, XWAIT = 5, SEND_RD = 6,\n           SEND = 7, ARG = 8, ACK = 9, INP = 10, CSB = 11;\nreg [3:0] st = IDLE; reg [7:0] cmd = 0; reg [8:0] n = 0, i = 0; reg [1:0] w = 0;\nreg [7:0] txd = 0; reg txs = 0;\nalways @(posedge clk) begin\n  txs <= 0; sgo <= 0; bwe <= 0;\n  case (st)\n    IDLE: if (rx_valid) begin\n      cmd <= rx_data;\n      if (rx_data == \"X\") st <= LEN;\n      else if (rx_data == \"Y\") st <= CSB;\n      else if (rx_data == \"C\" || rx_data == \"D\") st <= ARG;\n      else if (rx_data == \"I\") st <= INP;\n    end\n    CSB:  if (rx_valid) begin csm <= rx_data[1:0]; st <= LEN; end\n    LEN:  if (rx_valid) begin n <= (rx_data == 0) ? 9'd256 : {1'b0, rx_data}; i <= 0; st <= FILL; end\n    FILL: if (rx_valid) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= rx_data; i <= i + 1;\n      if (i + 1 == n) begin i <= 0; st <= XRD; w <= 0; end\n    end\n    XRD:  begin bra <= i[7:0]; w <= w + 1; if (w == 2) st <= XGO; end\n    XGO:  begin sin <= brd; sgo <= 1; st <= XWAIT; end\n    XWAIT: if (sdone) begin\n      bwe <= 1; bwa <= i[7:0]; bwd <= srx; i <= i + 1; w <= 0;\n      if (i + 1 == n) begin i <= 0; csm <= 0; st <= SEND_RD; end\n      else st <= XRD;\n    end\n    SEND_RD: begin bra <= i[7:0]; w <= w + 1; if (w == 2) begin w <= 0; st <= SEND; end end\n    SEND: if (!tx_busy && !txs) begin\n      txd <= brd; txs <= 1; i <= i + 1;\n      st <= (i + 1 == n) ? IDLE : SEND_RD;\n    end\n    ARG:  if (rx_valid) begin\n      if (cmd == \"C\") outs <= rx_data; else div <= rx_data;\n      st <= ACK;\n    end\n    ACK:  if (!tx_busy && !txs) begin txd <= \"k\"; txs <= 1; st <= IDLE; end\n    INP:  if (!tx_busy && !txs) begin txd <= {5'b0, sd_miso, usb_int, btn}; txs <= 1; st <= IDLE; end\n  endcase\nend\nassign tx_data = txd;\nassign tx_send = txs;\nassign idle = (st == IDLE);\n\nassign sd_cs   = outs[0] & ~csm[0];\nassign usb_cs  = outs[1] & ~csm[1];\nassign usb_rst = outs[2];\nassign led     = life_led | outs[3] | ~btn;     // also lights while SW2 is held\nSB_RGBA_DRV #(.CURRENT_MODE(\"0b1\"), .RGB0_CURRENT(\"0b000011\"),\n              .RGB1_CURRENT(\"0b000011\"), .RGB2_CURRENT(\"0b000011\")) rgb (\n  .CURREN(1'b1), .RGBLEDEN(1'b1),\n  .RGB0PWM(outs[4]), .RGB1PWM(outs[5]), .RGB2PWM(outs[6]),\n  .RGB0(rgb0), .RGB1(rgb1), .RGB2(rgb2));\n"
          },
          "position": {
            "x": 1960,
            "y": 980
          },
          "size": {
            "width": 900,
            "height": 1300
          }
        },
        {
          "id": "6df01027-9242-4d32-8b8a-9e0358c9da0e",
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
          "id": "f43d0d62-1212-46eb-84e7-1602326d008f",
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
            "x": 2500,
            "y": 600
          }
        },
        {
          "id": "6947a4b7-48a7-478b-9f34-94e129e58695",
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
            "x": 1700,
            "y": 1040
          }
        },
        {
          "id": "1d93d475-cef3-4f8c-b831-f20414515604",
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
            "x": 1700,
            "y": 1140
          }
        },
        {
          "id": "916d0388-074c-47a3-a948-3c0bd8b06241",
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
            "x": 1700,
            "y": 1240
          }
        },
        {
          "id": "f1260ea4-b60d-4738-8d5a-6eca62b4cca0",
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
            "x": 2960,
            "y": 1000
          }
        },
        {
          "id": "e54334b4-458d-4e15-9514-c664a4bcd9af",
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
            "x": 2960,
            "y": 1100
          }
        },
        {
          "id": "e6516ff1-691b-4e45-a87a-abbb95b8e77f",
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
            "x": 2960,
            "y": 1200
          }
        },
        {
          "id": "f6002e25-e8a2-48c3-8a73-9d4f5caf2af4",
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
            "x": 2960,
            "y": 1300
          }
        },
        {
          "id": "35058362-395b-4ffb-aedb-cacc5bb9524e",
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
            "x": 2960,
            "y": 1400
          }
        },
        {
          "id": "7f8dc830-099b-4d98-9ea2-7606b5899f5d",
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
            "x": 2960,
            "y": 1500
          }
        },
        {
          "id": "9e869f1b-fa48-45a1-abec-1560ce492361",
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
            "x": 2960,
            "y": 1600
          }
        },
        {
          "id": "5d1de017-a693-42d3-80d3-3cd4ddb5e4da",
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
            "x": 2960,
            "y": 1700
          }
        },
        {
          "id": "c826c5ee-2b9e-4f8d-a28b-8c693aba89ae",
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
            "x": 2960,
            "y": 1800
          }
        },
        {
          "id": "d4a3f091-5849-4285-84c5-e7e116932d93",
          "type": "basic.info",
          "data": {
            "info": "## Icey showcase: Game of Life + the whole board\n\nRun `./firmware/life-demo.sh` (it builds and loads this project). The Life engine computes 128 cells per clock; the I/O bridge lets the PC use the board's microSD slot, USB host port (plug in a keyboard to steer the show), button and RGB LED through the FPGA. All of it runs in parallel and shares one 3 Mbaud link.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": -260
          },
          "size": {
            "width": 900,
            "height": 240
          }
        },
        {
          "id": "4f33229f-16f9-49e9-9ce5-2f257fe23cc9",
          "type": "basic.info",
          "data": {
            "info": "### Why this needs an FPGA\n\n* The rule block on the right is **128 copies of the Life rule built into the chip**. They all evaluate at once, so a whole row of the grid is computed every clock tick.\n* A full 128x128 generation takes ~135 clocks at 24 MHz: **~175,000 generations per second, ~3 billion cell updates per second.**\n* A microcontroller computes cells one instruction at a time. Even with bit-twiddling tricks, a 240 MHz MCU is far behind.\n* Meanwhile the UART and the memory scheduler run in their own hardware at the same time, so streaming never slows the simulation.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": 560
          },
          "size": {
            "width": 900,
            "height": 400
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "e304087e-424e-41b0-b6ae-aefd0bad578c",
            "port": "clk"
          },
          "target": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e304087e-424e-41b0-b6ae-aefd0bad578c",
            "port": "clk"
          },
          "target": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e304087e-424e-41b0-b6ae-aefd0bad578c",
            "port": "clk"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e304087e-424e-41b0-b6ae-aefd0bad578c",
            "port": "clk"
          },
          "target": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e304087e-424e-41b0-b6ae-aefd0bad578c",
            "port": "clk"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "data"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "valid"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "data"
          },
          "target": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "data"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "life_rx_valid"
          },
          "target": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "io_rx_valid"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "cmd_idle"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "life_idle"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "idle"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "io_idle"
          }
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "tx_data"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "life_tx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "tx_send"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "life_tx_send"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "tx_data"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "io_tx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "tx_send"
          },
          "target": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "io_tx_send"
          }
        },
        {
          "source": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "tx_data"
          },
          "target": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "d720e051-3545-4196-8ce3-8df5948d8bb1",
            "port": "tx_send"
          },
          "target": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "send"
          }
        },
        {
          "source": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "busy"
          },
          "target": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "tx_busy"
          }
        },
        {
          "source": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "busy"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "tx_busy"
          }
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "above"
          },
          "target": {
            "block": "ecf7ce8f-4213-48f2-b888-8c1c86d18f22",
            "port": "above"
          },
          "size": 128
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "row"
          },
          "target": {
            "block": "ecf7ce8f-4213-48f2-b888-8c1c86d18f22",
            "port": "row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "below"
          },
          "target": {
            "block": "ecf7ce8f-4213-48f2-b888-8c1c86d18f22",
            "port": "below"
          },
          "size": 128
        },
        {
          "source": {
            "block": "ecf7ce8f-4213-48f2-b888-8c1c86d18f22",
            "port": "new_row"
          },
          "target": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "new_row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "0e05de87-eef0-4e9a-ba65-ed76b06c2d51",
            "port": "led"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "life_led"
          }
        },
        {
          "source": {
            "block": "6df01027-9242-4d32-8b8a-9e0358c9da0e",
            "port": "out"
          },
          "target": {
            "block": "cf270663-a8d4-4a54-a1b7-76b413f683f5",
            "port": "rx"
          }
        },
        {
          "source": {
            "block": "08b1674d-1ce8-448c-b58e-2a3a45e06e78",
            "port": "tx"
          },
          "target": {
            "block": "f43d0d62-1212-46eb-84e7-1602326d008f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "6947a4b7-48a7-478b-9f34-94e129e58695",
            "port": "out"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "btn"
          }
        },
        {
          "source": {
            "block": "1d93d475-cef3-4f8c-b831-f20414515604",
            "port": "out"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "usb_int"
          }
        },
        {
          "source": {
            "block": "916d0388-074c-47a3-a948-3c0bd8b06241",
            "port": "out"
          },
          "target": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "sd_miso"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "led"
          },
          "target": {
            "block": "f1260ea4-b60d-4738-8d5a-6eca62b4cca0",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "sd_sck"
          },
          "target": {
            "block": "e54334b4-458d-4e15-9514-c664a4bcd9af",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "sd_mosi"
          },
          "target": {
            "block": "e6516ff1-691b-4e45-a87a-abbb95b8e77f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "sd_cs"
          },
          "target": {
            "block": "f6002e25-e8a2-48c3-8a73-9d4f5caf2af4",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "usb_cs"
          },
          "target": {
            "block": "35058362-395b-4ffb-aedb-cacc5bb9524e",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "usb_rst"
          },
          "target": {
            "block": "7f8dc830-099b-4d98-9ea2-7606b5899f5d",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "rgb0"
          },
          "target": {
            "block": "9e869f1b-fa48-45a1-abec-1560ce492361",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "rgb1"
          },
          "target": {
            "block": "5d1de017-a693-42d3-80d3-3cd4ddb5e4da",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d8f385e7-5c2c-4a85-91eb-3f00dcf01248",
            "port": "rgb2"
          },
          "target": {
            "block": "c826c5ee-2b9e-4f8d-a28b-8c693aba89ae",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}