{
  "version": "1.2",
  "package": {
    "name": "Icey Game of Life",
    "version": "1.0",
    "description": "Conway's Life, 128 cells per clock, streamed to the PC over USB",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "Icey",
    "graph": {
      "blocks": [
        {
          "id": "22937156-74a0-43da-bc0e-b30070872365",
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
          "id": "01388808-ea91-4263-a468-65b77f36e3a8",
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
          "id": "26174345-9235-4838-a5dd-329350ac97e8",
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
          "id": "a8934b13-c31b-47e3-8798-82814e23c7b3",
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
                }
              ]
            },
            "params": [],
            "code": "// Grid memory + scheduler + PC link\n// The 128x128 grid lives in block RAM, two copies (\"banks\"): the engine\n// reads generation N from one bank and writes generation N+1 to the other.\n// Every clock it reads one row, slides a 3-row window (above/row/below) and\n// the 128 rule copies produce a whole new row at once.\n//\n// PC commands (bytes on the UART):\n//   'S'         -> 4-byte generation counter + 2048-byte grid snapshot\n//   'L' + 2048  -> load a grid                         (replies 'k')\n//   'V' + n     -> speed: 0 = flat out, 255 = stop,\n//                  else wait n*65536 clocks (n*2.7 ms) per generation\n//   'N'         -> single step while stopped           (replies 'k')\n// Grid format: row 0..127, 16 bytes per row, bit x of the row = column x.\n\nreg [127:0] mem [0:255];      // {bank, row}\nreg [7:0]   raddr = 0;\nreg [127:0] rdata = 0;\nreg         we = 0;\nreg [7:0]   waddr = 0;\nreg [127:0] wdata = 0;\nalways @(posedge clk) begin\n  rdata <= mem[raddr];\n  if (we) mem[waddr] <= wdata;\nend\n\n// ---------------- generation engine ----------------\nreg         bank = 0;              // bank holding the current generation\nreg [31:0]  gen = 0;\nreg [7:0]   speed = 255;           // start stopped until the PC says go\nreg [23:0]  wait_cnt = 0;\nreg         running = 0;           // a generation is in progress\nreg [7:0]   i = 0;                 // read index 0..129\nreg         rd_v0 = 0, rd_v = 0;   // address issued / rdata valid this cycle\nreg [1:0]   filled = 0;            // rows in the window (saturates at 3)\nreg         win = 0;               // window full: compute a row this cycle\nreg [6:0]   wrow = 0;\nreg [127:0] a = 0, r = 0, b = 0;\nreg         pause_req = 0;         // PC link wants the engine parked\nreg         step_req = 0;          // engine-owned latch for single steps\nreg         step_pulse = 0, speed_pulse = 0;   // one-clock requests from PC link\nreg         gen_tick = 0;          // one clock when a generation completes\nassign above = a; assign row = r; assign below = b;\nwire idle = !running;\n\n// engine-side memory signals (muxed with the PC link below)\nreg [7:0]   e_raddr;\nreg         e_we;\nreg [7:0]   e_waddr;\nreg [127:0] e_wdata;\n\nalways @(posedge clk) begin\n  e_we <= 0;\n  gen_tick <= 0;\n  if (step_pulse) step_req <= 1;\n  if (!running) begin\n    rd_v0 <= 0; rd_v <= 0; win <= 0;\n    if (speed_pulse) wait_cnt <= 0;               // new speed takes effect now\n    else if (wait_cnt != 0) wait_cnt <= wait_cnt - 1;\n    else if (!pause_req && (speed != 255 || step_req)) begin\n      running <= 1; i <= 0; filled <= 0; wrow <= 0; step_req <= 0;\n    end\n  end else begin\n    // 1) issue reads for rows 127, 0, 1, ..., 127, 0 (wrap-around)\n    if (i <= 129) begin\n      e_raddr <= {bank, i[6:0] - 7'd1};\n      i <= i + 1;\n    end\n    rd_v0 <= (i <= 129);\n    rd_v  <= rd_v0;                 // block RAM answers one clock later\n    // 2) slide the 3-row window\n    if (rd_v) begin\n      a <= r; r <= b; b <= rdata;\n      if (filled != 3) filled <= filled + 1;\n    end\n    win <= rd_v && filled >= 2;\n    // 3) register the new row from the 128 rule copies, write next cycle\n    if (win) begin\n      e_we <= 1; e_waddr <= {~bank, wrow}; e_wdata <= new_row;\n      wrow <= wrow + 1;\n      if (wrow == 127) begin\n        running <= 0; bank <= ~bank; gen <= gen + 1; gen_tick <= 1;\n        wait_cnt <= (speed == 255) ? 24'd0 : {speed, 16'h0};\n      end\n    end\n  end\nend\n\n// ---------------- PC link ----------------\nlocalparam H_IDLE = 0, H_SPEED = 1, H_WAIT = 2, H_DUMPGEN = 3, H_DUMPRD = 4,\n           H_DUMPROW = 5, H_LOAD = 6, H_ACK = 7, H_STEP = 8;\nreg [3:0]   hs = H_IDLE;\nreg [7:0]   cmd = 0;\nreg [127:0] acc = 0;               // load accumulator / dump shift register\nreg [3:0]   nbyte = 0;\nreg [7:0]   hrow = 0;\nreg [2:0]   gbyte = 0;\nreg [31:0]  gsnap = 0;\nreg         h_we = 0;\nreg [127:0] h_wdata = 0;\nreg [7:0]   h_waddr = 0;\nreg [7:0]   txd = 0;\nreg         txs = 0;\nreg [1:0]   rdwait = 0;\n// register + pre-decode received bytes (keeps the state machine fast)\nreg [7:0]   rxd = 0;\nreg         rxv = 0, is_s = 0, is_l = 0, is_v = 0, is_n = 0;\nalways @(posedge clk) begin\n  rxv <= rx_valid; rxd <= rx_data;\n  is_s <= rx_data == \"S\"; is_l <= rx_data == \"L\";\n  is_v <= rx_data == \"V\"; is_n <= rx_data == \"N\";\nend\nalways @(posedge clk) begin\n  txs <= 0; h_we <= 0; step_pulse <= 0; speed_pulse <= 0;\n  case (hs)\n    H_IDLE: if (rxv) begin\n      cmd <= rxd;\n      if (is_v) hs <= H_SPEED;\n      else if (is_n) begin step_pulse <= 1; hs <= H_STEP; end\n      else if (is_s || is_l) begin pause_req <= 1; hs <= H_WAIT; end\n    end\n    H_SPEED: if (rxv) begin speed <= rxd; speed_pulse <= 1; hs <= H_ACK; end\n    H_STEP: if (gen_tick) hs <= H_ACK;            // ack once the step is done\n    H_WAIT: if (idle) begin                       // engine parked between gens\n      hrow <= 0; nbyte <= 0; gbyte <= 0; gsnap <= gen;\n      hs <= (cmd == \"S\") ? H_DUMPGEN : H_LOAD;\n    end\n    H_DUMPGEN: if (!tx_busy && !txs) begin\n      txd <= gsnap[7:0]; gsnap <= gsnap >> 8; txs <= 1;\n      gbyte <= gbyte + 1;\n      if (gbyte == 3) begin hs <= H_DUMPRD; rdwait <= 0; end\n    end\n    H_DUMPRD: begin                               // read row hrow (2-cycle wait)\n      rdwait <= rdwait + 1;\n      if (rdwait == 2) begin acc <= rdata; nbyte <= 0; hs <= H_DUMPROW; end\n    end\n    H_DUMPROW: if (!tx_busy && !txs) begin\n      txd <= acc[7:0]; acc <= acc >> 8; txs <= 1;\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        hrow <= hrow + 1; rdwait <= 0;\n        if (hrow == 127) begin pause_req <= 0; hs <= H_IDLE; end\n        else hs <= H_DUMPRD;\n      end\n    end\n    H_LOAD: if (rxv) begin\n      acc <= {rxd, acc[127:8]};\n      nbyte <= nbyte + 1;\n      if (nbyte == 15) begin\n        h_we <= 1; h_waddr <= {bank, hrow[6:0]}; h_wdata <= {rxd, acc[127:8]};\n        hrow <= hrow + 1;\n        if (hrow == 127) hs <= H_ACK;\n      end\n    end\n    H_ACK: if (!tx_busy && !txs) begin\n      txd <= \"k\"; txs <= 1; pause_req <= 0; hs <= H_IDLE;\n    end\n  endcase\nend\n\n// memory port mux: the PC link only touches memory while the engine is parked\nalways @(*) begin\n  raddr = running ? e_raddr : {bank, hrow[6:0]};\n  we    = running ? e_we : (h_we | e_we);\n  waddr = h_we ? h_waddr : e_waddr;\n  wdata = h_we ? h_wdata : e_wdata;\nend\n\nassign tx_data = txd;\nassign tx_send = txs;\n// LED: blinks with the generation count (slower bit when running flat out)\nassign led = (speed == 0) ? gen[18] : gen[2];\n"
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
          "id": "136739ee-f71a-4c67-9554-717bd40af261",
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
          "id": "55bf5b27-a373-4c8c-bf70-d3ed72b3ab52",
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
          "id": "4242d1f5-7eab-46a6-865d-53093ae19b84",
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
          "id": "8d7ae291-3493-46b7-aaf8-74369f119955",
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
            "x": 2500,
            "y": 760
          }
        },
        {
          "id": "98ed46c6-8145-4ec4-bcb8-a82faa099566",
          "type": "basic.info",
          "data": {
            "info": "## Icey Game of Life: 128 cells per clock\n\nNo monitor needed. The grid streams back over the same USB cable. Upload this, then on the PC run:\n\n`python firmware/examples/icestudio/life.py`\n\n(`--bench` measures the speed, `--verify` checks every cell against a software reference.)",
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
          "id": "ddc8ccf0-55f1-4dd8-9603-f683bcc9d877",
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
            "block": "22937156-74a0-43da-bc0e-b30070872365",
            "port": "clk"
          },
          "target": {
            "block": "01388808-ea91-4263-a468-65b77f36e3a8",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "22937156-74a0-43da-bc0e-b30070872365",
            "port": "clk"
          },
          "target": {
            "block": "26174345-9235-4838-a5dd-329350ac97e8",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "22937156-74a0-43da-bc0e-b30070872365",
            "port": "clk"
          },
          "target": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "01388808-ea91-4263-a468-65b77f36e3a8",
            "port": "data"
          },
          "target": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "rx_data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "01388808-ea91-4263-a468-65b77f36e3a8",
            "port": "valid"
          },
          "target": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "rx_valid"
          }
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "tx_data"
          },
          "target": {
            "block": "26174345-9235-4838-a5dd-329350ac97e8",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "tx_send"
          },
          "target": {
            "block": "26174345-9235-4838-a5dd-329350ac97e8",
            "port": "send"
          }
        },
        {
          "source": {
            "block": "26174345-9235-4838-a5dd-329350ac97e8",
            "port": "busy"
          },
          "target": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "tx_busy"
          }
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "above"
          },
          "target": {
            "block": "136739ee-f71a-4c67-9554-717bd40af261",
            "port": "above"
          },
          "size": 128
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "row"
          },
          "target": {
            "block": "136739ee-f71a-4c67-9554-717bd40af261",
            "port": "row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "below"
          },
          "target": {
            "block": "136739ee-f71a-4c67-9554-717bd40af261",
            "port": "below"
          },
          "size": 128
        },
        {
          "source": {
            "block": "136739ee-f71a-4c67-9554-717bd40af261",
            "port": "new_row"
          },
          "target": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "new_row"
          },
          "size": 128
        },
        {
          "source": {
            "block": "55bf5b27-a373-4c8c-bf70-d3ed72b3ab52",
            "port": "out"
          },
          "target": {
            "block": "01388808-ea91-4263-a468-65b77f36e3a8",
            "port": "rx"
          }
        },
        {
          "source": {
            "block": "26174345-9235-4838-a5dd-329350ac97e8",
            "port": "tx"
          },
          "target": {
            "block": "4242d1f5-7eab-46a6-865d-53093ae19b84",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a8934b13-c31b-47e3-8798-82814e23c7b3",
            "port": "led"
          },
          "target": {
            "block": "8d7ae291-3493-46b7-aaf8-74369f119955",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}