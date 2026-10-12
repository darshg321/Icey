{
  "version": "1.2",
  "package": {
    "name": "Icey VGA demo",
    "version": "1.0",
    "description": "Racing-the-beam VGA effects computed live in parallel hardware",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "Icey",
    "graph": {
      "blocks": [
        {
          "id": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
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
            "code": "// 25 MHz pixel clock\n// No crystal on Icey: internal 48 MHz oscillator -> PLL -> 25.125 MHz\n// (VGA 640x480@60 wants 25.175 MHz; 0.2% off is fine for monitors)\nwire hf;\nSB_HFOSC #(.CLKHF_DIV(\"0b00\")) osc (\n  .CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(hf));\nSB_PLL40_CORE #(.FEEDBACK_PATH(\"SIMPLE\"), .DIVR(4'b0011),\n  .DIVF(7'b1000010), .DIVQ(3'b101), .FILTER_RANGE(3'b001)) pll (\n  .REFERENCECLK(hf), .PLLOUTGLOBAL(clk), .RESETB(1'b1), .BYPASS(1'b0));\n"
          },
          "position": {
            "x": 40,
            "y": 260
          },
          "size": {
            "width": 400,
            "height": 240
          }
        },
        {
          "id": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
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
            "x": 520,
            "y": 220
          },
          "size": {
            "width": 480,
            "height": 340
          }
        },
        {
          "id": "f2619600-bbea-4a71-813e-5aaf294ce74a",
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
            "x": 1100,
            "y": 40
          },
          "size": {
            "width": 560,
            "height": 420
          }
        },
        {
          "id": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
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
            "x": 1100,
            "y": 520
          },
          "size": {
            "width": 560,
            "height": 260
          }
        },
        {
          "id": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
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
            "code": "// Effect 3: two-source interference\n// Two bouncing point sources; each pixel computes its squared distance\n// to both (4 multipliers per pixel) -> ripple interference pattern.\nreg [9:0] ax = 160, ay = 120, bx = 480, by = 360;\nreg adx = 1, ady = 1, bdx = 0, bdy = 1;\nwire frame = (x == 0) && (y == 480);\nalways @(posedge clk) if (frame) begin\n  ax <= adx ? ax + 3 : ax - 3;  ay <= ady ? ay + 2 : ay - 2;\n  bx <= bdx ? bx + 2 : bx - 2;  by <= bdy ? by + 3 : by - 3;\n  if (ax > 630) adx <= 0; if (ax < 10) adx <= 1;\n  if (ay > 470) ady <= 0; if (ay < 10) ady <= 1;\n  if (bx > 630) bdx <= 0; if (bx < 10) bdx <= 1;\n  if (by > 470) bdy <= 0; if (by < 10) bdy <= 1;\nend\nreg [9:0] dx1, dy1, dx2, dy2;\nreg [19:0] q1, q2, q3, q4;\nreg [7:0] r;\nwire [20:0] d1 = q1 + q2, d2 = q3 + q4;\nwire [7:0] v1 = d1[14:7] - {t[5:0], 2'b0};   // rings expand outwards\nwire [7:0] v2 = d2[14:7] - {t[5:0], 2'b0};\nalways @(posedge clk) begin\n  dx1 <= (x > ax) ? x - ax : ax - x;  dy1 <= (y > ay) ? y - ay : ay - y;\n  dx2 <= (x > bx) ? x - bx : bx - x;  dy2 <= (y > by) ? y - by : by - y;\n  q1 <= dx1 * dx1;  q2 <= dy1 * dy1;  q3 <= dx2 * dx2;  q4 <= dy2 * dy2;\n  if (d1 < 400 || d2 < 400) r <= 8'hFF;              // the sources\n  else r <= {v1[7:5], v2[7:5], v1[7] ^ v2[7], v1[6] ^ v2[6]};\n  // red = waves from A, green = waves from B, blue = where they interfere\nend\nassign rgb = r;\n"
          },
          "position": {
            "x": 1100,
            "y": 840
          },
          "size": {
            "width": 560,
            "height": 460
          }
        },
        {
          "id": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "btn"
                }
              ],
              "out": [
                {
                  "name": "mode",
                  "range": "[1:0]",
                  "size": 2
                }
              ]
            },
            "params": [],
            "code": "// Button: next effect\n// Debounced button (active low) cycles through the 3 effects\nreg [17:0] div = 0;\nreg [1:0] sync = 2'b11;\nreg prev = 1, m0 = 0, m1 = 0;\nalways @(posedge clk) begin\n  div  <= div + 1;\n  sync <= {sync[0], btn};\n  if (div == 0) begin                  // sample every ~10 ms\n    prev <= sync[1];\n    if (prev && !sync[1])              // falling edge = press\n      {m1, m0} <= ({m1, m0} == 2) ? 2'd0 : {m1, m0} + 2'd1;\n  end\nend\nassign mode = {m1, m0};\n"
          },
          "position": {
            "x": 520,
            "y": 640
          },
          "size": {
            "width": 480,
            "height": 300
          }
        },
        {
          "id": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "mode",
                  "range": "[1:0]",
                  "size": 2
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
            "code": "// Pick effect + VGA output\n// All three effects run every clock; this just selects one.\n// Effects take 3 clocks, so delay sync/blanking by 3 to line up.\nreg [2:0] hsd = 3'b111, vsd = 3'b111, ded = 0;\nreg [7:0] px = 0;\nreg hso = 1, vso = 1;\nalways @(posedge clk) begin\n  hsd <= {hsd[1:0], hs};\n  vsd <= {vsd[1:0], vs};\n  ded <= {ded[1:0], de};\n  px  <= !ded[2] ? 8'd0 : mode == 0 ? fx1 : mode == 1 ? fx2 : fx3;\n  hso <= hsd[2];\n  vso <= vsd[2];\nend\nassign r = px[7:5];\nassign g = px[4:2];\nassign b = px[1:0];\nassign hsync = hso;\nassign vsync = vso;\n"
          },
          "position": {
            "x": 1760,
            "y": 360
          },
          "size": {
            "width": 520,
            "height": 400
          }
        },
        {
          "id": "442921cf-84b6-4b11-9986-e0a7c4fe6237",
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
            "x": 40,
            "y": 700
          }
        },
        {
          "id": "1f9561bd-0056-4738-831f-ad58dbf2e4f7",
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
            "x": 1120,
            "y": 1380
          }
        },
        {
          "id": "8d9baf56-b0b5-4ea7-b948-a3f50f788bc3",
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
            "x": 2380,
            "y": 360
          }
        },
        {
          "id": "b693e8be-9efd-4bc5-b751-204318242cd7",
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
            "x": 2380,
            "y": 460
          }
        },
        {
          "id": "5f73b28a-6c3a-4e0a-b552-11c89e6e3eff",
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
            "x": 2380,
            "y": 560
          }
        },
        {
          "id": "e3f42d1f-f26f-45cf-bf18-eb0b69b0961c",
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
            "x": 2380,
            "y": 660
          }
        },
        {
          "id": "5a668b37-e5aa-4b93-a19b-abb0d6ff3e80",
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
            "x": 2380,
            "y": 760
          }
        },
        {
          "id": "57253a9b-8deb-4b82-8152-389c668fc5d7",
          "type": "basic.info",
          "data": {
            "info": "## Icey VGA: racing the beam\n\nPlug a VGA monitor into Icey, hit **Upload**. Press **SW2** to switch effects.\n\nThere is **no framebuffer and no CPU**. Every pixel is computed by dedicated hardware at the exact moment the monitor draws it: 25 million pixels per second.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": 20
          },
          "size": {
            "width": 1000,
            "height": 170
          }
        },
        {
          "id": "33cfe60e-acfd-4ba3-a55f-8429b9d6ef45",
          "type": "basic.info",
          "data": {
            "info": "### Why this needs an FPGA\n\n* All **7 blocks run at the same time**, every clock tick. All three effects are computed for every pixel even though only one is shown.\n* Per pixel: **7 sine lookups** (plasma) + **4 multiplies** (interference) + XOR math, all done in parallel in one 40 ns pixel period.\n* A 240 MHz microcontroller gets ~10 instructions per pixel at this rate. It has to pre-render into a framebuffer (640x480x8 bit = 300 KB) and can't redo this math live.\n* Sync timing is exact to the clock cycle, with zero jitter from interrupts or WiFi.",
            "readonly": true
          },
          "position": {
            "x": 40,
            "y": 1000
          },
          "size": {
            "width": 1000,
            "height": 330
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "f2619600-bbea-4a71-813e-5aaf294ce74a",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "f2619600-bbea-4a71-813e-5aaf294ce74a",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "y"
          },
          "target": {
            "block": "f2619600-bbea-4a71-813e-5aaf294ce74a",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "t"
          },
          "target": {
            "block": "f2619600-bbea-4a71-813e-5aaf294ce74a",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "y"
          },
          "target": {
            "block": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "t"
          },
          "target": {
            "block": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
            "port": "x"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "y"
          },
          "target": {
            "block": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
            "port": "y"
          },
          "size": 10
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "t"
          },
          "target": {
            "block": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "hs"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "hs"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "vs"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "vs"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "de"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "de"
          }
        },
        {
          "source": {
            "block": "f2619600-bbea-4a71-813e-5aaf294ce74a",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx1"
          },
          "size": 8
        },
        {
          "source": {
            "block": "6091f95d-da78-40a2-a1eb-c6f7d7448191",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx2"
          },
          "size": 8
        },
        {
          "source": {
            "block": "739d9f04-7cdf-4b39-a892-b5d6d4a877b9",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx3"
          },
          "size": 8
        },
        {
          "source": {
            "block": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
            "port": "mode"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "mode"
          },
          "size": 2
        },
        {
          "source": {
            "block": "442921cf-84b6-4b11-9986-e0a7c4fe6237",
            "port": "out"
          },
          "target": {
            "block": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
            "port": "btn"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "heartbeat"
          },
          "target": {
            "block": "1f9561bd-0056-4738-831f-ad58dbf2e4f7",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "r"
          },
          "target": {
            "block": "8d9baf56-b0b5-4ea7-b948-a3f50f788bc3",
            "port": "in"
          },
          "size": 3
        },
        {
          "source": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "g"
          },
          "target": {
            "block": "b693e8be-9efd-4bc5-b751-204318242cd7",
            "port": "in"
          },
          "size": 3
        },
        {
          "source": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "b"
          },
          "target": {
            "block": "5f73b28a-6c3a-4e0a-b552-11c89e6e3eff",
            "port": "in"
          },
          "size": 2
        },
        {
          "source": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "hsync"
          },
          "target": {
            "block": "e3f42d1f-f26f-45cf-bf18-eb0b69b0961c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "vsync"
          },
          "target": {
            "block": "5a668b37-e5aa-4b93-a19b-abb0d6ff3e80",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}