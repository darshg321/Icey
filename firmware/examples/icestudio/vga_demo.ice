{
  "version": "1.2",
  "package": {
    "name": "Icey VGA demo",
    "version": "1.0",
    "description": "Six racing-the-beam effects on the VGA port, cycling on their own",
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
          "id": "7869e2b2-6182-5f32-995b-039ae93d9035",
          "position": {
            "x": 1100,
            "y": 1360
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
            "code": "// Effect 5: starfield\n// Three layers of stars sliding sideways at 1, 2 and 4 pixels a frame:\n// near stars are brighter, faster and longer. Each scan line holds one\n// star per layer, at a position scrambled from the line number, so there\n// is nothing to store: 900 stars on screen from a few XOR gates.\nreg [9:0] f = 0;                          // own frame counter (wraps with the 1024-wide sky)\nalways @(posedge clk) if (x == 0 && y == 480) f <= f + 1;\nfunction [11:0] scramble(input [11:0] a); // xorshift: neighbouring lines land far apart\n  reg [11:0] h;\n  begin\n    h = a ^ {a[6:0], 5'b0};\n    h = h ^ {3'b0, h[11:3]};\n    scramble = h ^ {h[4:0], 7'b0};\n  end\nendfunction\nwire [11:0] h1 = scramble({y, 2'd1}), h2 = scramble({y, 2'd2}), h3 = scramble({y, 2'd3});\n// distance from each layer's star, along the line\nwire [9:0] d1 = x + f - h1[11:2];\nwire [9:0] d2 = x + {f[8:0], 1'b0} - h2[11:2];\nwire [9:0] d3 = x + {f[7:0], 2'b0} - h3[11:2];\nreg s1 = 0, s2 = 0, s3 = 0, tw = 0;\nreg [7:0] r = 0, r2 = 0;\nalways @(posedge clk) begin\n  // stage 1: is a star here? (far stars only on even lines)\n  s1 <= d1 == 0 && !y[0];\n  s2 <= d2 < 2;\n  s3 <= d3 < 4;\n  tw <= h1[1] ^ f[3];                     // far stars twinkle\n  // stage 2: colour, nearest layer wins\n  r <= s3 ? 8'b111_111_11 : s2 ? 8'b101_101_10 : (s1 && tw) ? 8'b011_011_10 :\n       s1 ? 8'b010_010_01 : 8'b000_000_00;\n  // stage 3\n  r2 <= r;\nend\nassign rgb = r2;\n"
          },
          "id": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
          "position": {
            "x": 1100,
            "y": 1800
          },
          "size": {
            "width": 560,
            "height": 520
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
            "code": "// Effect 6: rotozoomer\n// A tiled texture, turning and zooming every frame. Per pixel this is two\n// additions: the texture position (u, v) steps by (du, dv) along the scan\n// line, and by (-dv, du) from one line to the next. The sines and the\n// multiplies happen once a frame, during vertical blanking.\nfunction [7:0] sin8(input [7:0] a);\n  reg [5:0] i; reg [6:0] q;\n  begin\n    i = a[6] ? ~a[5:0] : a[5:0];\n    case (i)\n      0: q = 2;\n      1: q = 5;\n      2: q = 8;\n      3: q = 11;\n      4: q = 14;\n      5: q = 17;\n      6: q = 20;\n      7: q = 23;\n      8: q = 26;\n      9: q = 29;\n      10: q = 32;\n      11: q = 35;\n      12: q = 38;\n      13: q = 41;\n      14: q = 44;\n      15: q = 47;\n      16: q = 50;\n      17: q = 53;\n      18: q = 56;\n      19: q = 58;\n      20: q = 61;\n      21: q = 64;\n      22: q = 67;\n      23: q = 69;\n      24: q = 72;\n      25: q = 74;\n      26: q = 77;\n      27: q = 79;\n      28: q = 82;\n      29: q = 84;\n      30: q = 86;\n      31: q = 89;\n      32: q = 91;\n      33: q = 93;\n      34: q = 95;\n      35: q = 97;\n      36: q = 99;\n      37: q = 101;\n      38: q = 103;\n      39: q = 105;\n      40: q = 106;\n      41: q = 108;\n      42: q = 110;\n      43: q = 111;\n      44: q = 113;\n      45: q = 114;\n      46: q = 115;\n      47: q = 117;\n      48: q = 118;\n      49: q = 119;\n      50: q = 120;\n      51: q = 121;\n      52: q = 122;\n      53: q = 123;\n      54: q = 124;\n      55: q = 124;\n      56: q = 125;\n      57: q = 125;\n      58: q = 126;\n      59: q = 126;\n      60: q = 127;\n      61: q = 127;\n      62: q = 127;\n      63: q = 127;\n    endcase\n    sin8 = a[7] ? 8'd127 - q : 8'd128 + q;\n  end\nendfunction\n\nreg [7:0] ang = 0, zph = 0;\nreg [7:0] sn = 0, cs = 0, z = 0;          // sin and cos (offset by 128), zoom\nreg [15:0] du = 0, dv = 0;                // texture step per pixel (8.8, signed)\nreg [15:0] cu = 0, cv = 0;                // texture point at the screen centre\nreg [15:0] ul = 0, vl = 0, u = 0, v = 0;  // start of the next line, current pixel\nwire [7:0] sin_c = sin8(ang + 8'd64), sin_s = sin8(ang), sin_z = sin8(zph);\nwire signed [8:0] scs = {1'b0, cs} - 9'sd128, ssn = {1'b0, sn} - 9'sd128;\nwire signed [17:0] pc = scs * $signed({1'b0, z}), ps = ssn * $signed({1'b0, z});\nwire signed [17:0] pcs = pc >>> 6, pss = ps >>> 6;\nalways @(posedge clk) begin\n  // once a frame, on line 480, a step per clock\n  if (y == 480) case (x)\n    0: begin ang <= ang + 1; zph <= zph + 2; cu <= cu + 16'd96; cv <= cv + 16'd40; end\n    1: begin cs <= sin_c; sn <= sin_s; z <= 8'd40 + sin_z[7:1]; end\n    2: begin du <= pcs[15:0]; dv <= pss[15:0]; end\n    3: begin                              // top-left corner = centre - 320 across - 240 down\n      ul <= cu - (du << 8) - (du << 6) + (dv << 8) - (dv << 4);\n      vl <= cv - (dv << 8) - (dv << 6) - (du << 8) + (du << 4);\n    end\n  endcase\n  // next line: from the end of line 524 (for line 0) through line 478\n  if (x == 799 && (y == 524 || y < 479)) begin\n    u <= ul; v <= vl; ul <= ul - dv; vl <= vl + du;\n  end else begin\n    u <= u + du; v <= v + dv;\n  end\nend\n// texture: 32-texel tiles, two colour schemes in a checkerboard, XOR detail\nwire [7:0] tu = u[15:8], tv = v[15:8];\nwire [7:0] p = tu ^ tv;\nreg [7:0] r = 0, r2 = 0, r3 = 0;\nalways @(posedge clk) begin\n  if (tu[4:0] == 0 || tv[4:0] == 0) r <= 8'b111_111_11;      // grout\n  else if (tu[5] ^ tv[5]) r <= {3'b111, p[4:2], p[4:3]};      // warm tiles\n  else r <= {1'b0, p[3:2], p[4:2], 2'b11};                    // cool tiles\n  r2 <= r;\n  r3 <= r2;\nend\nassign rgb = r3;\n"
          },
          "id": "2aac17d8-e301-5853-ba26-c0efce94f392",
          "position": {
            "x": 1100,
            "y": 2380
          },
          "size": {
            "width": 560,
            "height": 640
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
                }
              ],
              "out": [
                {
                  "name": "mode",
                  "range": "[2:0]",
                  "size": 3
                }
              ]
            },
            "params": [],
            "code": "// Effect director\n// Moves to the next effect every ~8 s on its own, so the board works as a\n// standalone display. SW2 (debounced, active low) skips to the next one\n// straight away, and the 8 s start again.\nreg [17:0] div = 0;\nreg [1:0] sync = 2'b11;\nreg prev = 1;\nreg [2:0] m = 0;\nreg [8:0] frames = 0;\nalways @(posedge clk) begin\n  div  <= div + 1;\n  sync <= {sync[0], btn};\n  if (x == 0 && y == 480) frames <= frames + 1;     // 512 frames = 8.5 s\n  if (div == 0) prev <= sync[1];                    // sample every ~10 ms\n  if ((div == 0 && prev && !sync[1]) ||             // press, or time is up\n      (x == 0 && y == 480 && frames == 511)) begin\n    m <= (m == 5) ? 3'd0 : m + 3'd1;\n    frames <= 0;\n  end\nend\nassign mode = m;\n"
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
                  "name": "fx5",
                  "range": "[7:0]",
                  "size": 8
                },
                {
                  "name": "fx6",
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
            "code": "// Pick effect + VGA output\n// All six effects run every clock; this just selects one.\n// Effects take 3 clocks, so delay sync/blanking by 3 to line up.\nreg [2:0] hsd = 3'b111, vsd = 3'b111, ded = 0;\nreg [7:0] px = 0, sel;\nreg hso = 1, vso = 1;\nalways @(*) case (mode)\n  0: sel = fx1;  1: sel = fx2;  2: sel = fx3;\n  3: sel = fx4;  4: sel = fx5;  default: sel = fx6;\nendcase\nalways @(posedge clk) begin\n  hsd <= {hsd[1:0], hs};\n  vsd <= {vsd[1:0], vs};\n  ded <= {ded[1:0], de};\n  px  <= !ded[2] ? 8'd0 : sel;\n  hso <= hsd[2];\n  vso <= vsd[2];\nend\nassign r = px[7:5];\nassign g = px[4:2];\nassign b = px[1:0];\nassign hsync = hso;\nassign vsync = vso;\n"
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
            "info": "## Icey VGA: racing the beam\n\nPlug a VGA monitor into Icey, hit **Upload** (or run `./firmware/life-demo.sh --patterns`). Six effects take turns, about 8 s each; **SW2** skips to the next one. After loading, the board runs on its own: no PC, keyboard or Life engine involved.\n\nThere is **no framebuffer and no CPU**. Every pixel is computed by dedicated hardware at the exact moment the monitor draws it: 25 million pixels per second.",
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
            "info": "### Why this needs an FPGA\n\n* All **10 blocks run at the same time**, every clock tick. All six effects are computed for every pixel even though only one is shown.\n* Per pixel: **7 sine lookups** (plasma) + **4 multiplies** (interference) + XOR math, all done in parallel in one 40 ns pixel period.\n* A 240 MHz microcontroller gets ~10 instructions per pixel at this rate. It has to pre-render into a framebuffer (640x480x8 bit = 300 KB) and can't redo this math live.\n* Sync timing is exact to the clock cycle, with zero jitter from interrupts or WiFi.",
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
          "size": 3
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
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "7869e2b2-6182-5f32-995b-039ae93d9035",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "7869e2b2-6182-5f32-995b-039ae93d9035",
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
            "block": "7869e2b2-6182-5f32-995b-039ae93d9035",
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
            "block": "7869e2b2-6182-5f32-995b-039ae93d9035",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "7869e2b2-6182-5f32-995b-039ae93d9035",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx4"
          },
          "size": 8
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
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
            "block": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
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
            "block": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "f8a61458-7875-51fe-9f0d-ed2d94e9795c",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx5"
          },
          "size": 8
        },
        {
          "source": {
            "block": "e823ad8a-8254-47bb-8e3f-9682fb05157a",
            "port": "clk"
          },
          "target": {
            "block": "2aac17d8-e301-5853-ba26-c0efce94f392",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "2aac17d8-e301-5853-ba26-c0efce94f392",
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
            "block": "2aac17d8-e301-5853-ba26-c0efce94f392",
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
            "block": "2aac17d8-e301-5853-ba26-c0efce94f392",
            "port": "t"
          },
          "size": 8
        },
        {
          "source": {
            "block": "2aac17d8-e301-5853-ba26-c0efce94f392",
            "port": "rgb"
          },
          "target": {
            "block": "24cbf95a-e5bc-4c2c-8373-6216407e84d9",
            "port": "fx6"
          },
          "size": 8
        },
        {
          "source": {
            "block": "61635dd0-a3db-49a8-beb2-a5ab8ebb1550",
            "port": "x"
          },
          "target": {
            "block": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
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
            "block": "c3bcaffd-f540-4a22-9070-dc30d1ad753b",
            "port": "y"
          },
          "size": 10
        }
      ]
    }
  },
  "dependencies": {}
}