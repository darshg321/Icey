{
  "version": "1.2",
  "package": {
    "name": "Icey blink",
    "version": "1.0",
    "description": "Blink LED1 and cycle the RGB LED on the Icey board",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "Icey",
    "graph": {
      "blocks": [
        {
          "id": "55cee31b-b15b-4fbe-b367-baa2b96a7c2e",
          "type": "basic.code",
          "data": {
            "ports": {
              "in": [],
              "out": [
                {
                  "name": "clk_out"
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
            "code": "// Icey has no external clock: use the internal 12 MHz oscillator.\nwire clk;\nSB_HFOSC #(.CLKHF_DIV(\"0b10\")) osc (\n  .CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));\n\nreg [25:0] c = 0;\nalways @(posedge clk) c <= c + 1;\n\n// clk_out lets other blocks use the 12 MHz clock\nassign clk_out = clk;\nassign led = c[23];\n\n// RGB LED pins are open-drain current sinks: drive them with SB_RGBA_DRV\nSB_RGBA_DRV #(.CURRENT_MODE(\"0b1\"), .RGB0_CURRENT(\"0b000001\"),\n              .RGB1_CURRENT(\"0b000001\"), .RGB2_CURRENT(\"0b000001\")) rgb (\n  .CURREN(1'b1), .RGBLEDEN(1'b1),\n  .RGB0PWM(c[25:24] == 2'd1), .RGB1PWM(c[25:24] == 2'd2),\n  .RGB2PWM(c[25:24] == 2'd3),\n  .RGB0(rgb0), .RGB1(rgb1), .RGB2(rgb2));\n"
          },
          "position": {
            "x": 80,
            "y": 120
          },
          "size": {
            "width": 560,
            "height": 440
          }
        },
        {
          "id": "aa3c31bd-8649-4b98-bfd9-03a805420e0c",
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
            "x": 760,
            "y": 200
          }
        },
        {
          "id": "5452dbcf-0db5-428d-8da5-c124a972d3d6",
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
            "x": 760,
            "y": 296
          }
        },
        {
          "id": "5fd516a9-b21c-46bc-848f-91d084534326",
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
            "x": 760,
            "y": 392
          }
        },
        {
          "id": "e8c1a85f-86d9-4e46-87ca-59ab8d3f828d",
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
            "x": 760,
            "y": 488
          }
        },
        {
          "id": "86c6d45e-6a4a-4d65-9447-e192e161e6d0",
          "type": "basic.info",
          "data": {
            "info": "Icey blink: LED1 blinks, the RGB LED cycles.\nUpload loads the design into FPGA SRAM (it is lost at power-off).",
            "readonly": true
          },
          "position": {
            "x": 80,
            "y": 24
          },
          "size": {
            "width": 560,
            "height": 64
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "55cee31b-b15b-4fbe-b367-baa2b96a7c2e",
            "port": "led"
          },
          "target": {
            "block": "aa3c31bd-8649-4b98-bfd9-03a805420e0c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "55cee31b-b15b-4fbe-b367-baa2b96a7c2e",
            "port": "rgb0"
          },
          "target": {
            "block": "5452dbcf-0db5-428d-8da5-c124a972d3d6",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "55cee31b-b15b-4fbe-b367-baa2b96a7c2e",
            "port": "rgb1"
          },
          "target": {
            "block": "5fd516a9-b21c-46bc-848f-91d084534326",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "55cee31b-b15b-4fbe-b367-baa2b96a7c2e",
            "port": "rgb2"
          },
          "target": {
            "block": "e8c1a85f-86d9-4e46-87ca-59ab8d3f828d",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}