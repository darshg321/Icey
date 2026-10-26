const HEX = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c, 0x39, 0x5e, 0x79, 0x71];
const HEX7 = `module hex7(input [3:0] digit, output reg [6:0] seg);
  always @(*) begin
    case (digit)
      4'h0: seg = 7'b0111111;  4'h1: seg = 7'b0000110;  4'h2: seg = 7'b1011011;  4'h3: seg = 7'b1001111;
      4'h4: seg = 7'b1100110;  4'h5: seg = 7'b1101101;  4'h6: seg = 7'b1111101;  4'h7: seg = 7'b0000111;
      4'h8: seg = 7'b1111111;  4'h9: seg = 7'b1101111;  4'ha: seg = 7'b1110111;  4'hb: seg = 7'b1111100;
      4'hc: seg = 7'b0111001;  4'hd: seg = 7'b1011110;  4'he: seg = 7'b1111001;  default: seg = 7'b1110001;
    endcase
  end
endmodule`;
const clock = { port: 'clk', hz: 12e6 };

export default [
  {
    id: 'counter',
    title: 'A counter you can see',
    prompt: 'Make a 28-bit counter that goes up by one every clock, and show its top eight bits, `count[27:20]`, on the LEDs.',
    starter: `module top(
  input        clk,
  output [7:0] led
);
  reg [27:0] count = 0;

  // count up on every rising edge of clk

  assign led = 0;
endmodule
`,
    solution: `module top(
  input        clk,
  output [7:0] led
);
  reg [27:0] count = 0;
  always @(posedge clk)
    count <= count + 1;
  assign led = count[27:20];
endmodule
`,
    board: [{ type: 'leds', port: 'led', label: 'led[7:0]' }],
    clock,
    waves: ['clk', 'led'],
    tests: [
      { name: 'led shows count[27:20]', run(t) {
        t.eq('led', 0, 'at power-up');
        for (let k = 1; k <= 5; k++) {
          t.tick((1 << 20) - 1);
          t.eq('led', k - 1, `after ${k * (1 << 20) - 1} clocks`);
          t.tick(1);
          t.eq('led', k, `after ${k * (1 << 20)} clocks`);
        }
      } },
    ],
  },
  {
    id: 'blink',
    title: 'One blink per second',
    prompt: 'Toggle `LED` every 6,000,000 clocks, so it\'s on for half a second and off for half a second.',
    starter: `module top(
  input  clk,       // 12 MHz
  output LED
);
  reg [22:0] count = 0;
  reg led = 0;

  always @(posedge clk) begin
    // count to 5,999,999, then wrap and flip led
  end

  assign LED = led;
endmodule
`,
    solution: `module top(
  input  clk,
  output LED
);
  reg [22:0] count = 0;
  reg led = 0;

  always @(posedge clk) begin
    if (count == 23'd5_999_999) begin
      count <= 0;
      led <= ~led;
    end else begin
      count <= count + 1;
    end
  end

  assign LED = led;
endmodule
`,
    board: [{ type: 'led', port: 'LED', label: 'LED1' }],
    clock,
    tests: [
      { name: 'LED changes exactly every 6,000,000 clocks', run(t) {
        t.eq('LED', 0, 'at power-up');
        let last = 0, at = 0;
        for (let k = 1; k <= 3; k++) {
          t.tick(6_000_000 * k - 2 - at); at = 6_000_000 * k - 2;
          t.ok(t.get('LED') === last, `LED changed before ${(6_000_000 * k).toLocaleString("en-US")} clocks. It should stay ${last} for 6,000,000 clocks; check you're counting from 0 to 5,999,999.`);
          t.tick(2); at += 2;
          t.ok(t.get('LED') !== last, `LED should have changed after ${(6_000_000 * k).toLocaleString("en-US")} clocks, but it's still ${last}.`);
          last ^= 1;
        }
      } },
    ],
  },
  {
    id: 'stopwatch',
    project: true,
    title: 'Stopwatch',
    prompt: 'Seconds on `hex1`, tenths on `hex0`, counting 0.0 to 9.9 and wrapping. Holding `BTN` (active low) resets to 0.0.',
    starter: `${HEX7}

module top(
  input        clk,     // 12 MHz
  input        BTN,     // 0 while pressed
  output [6:0] hex1,    // seconds
  output [6:0] hex0     // tenths
);
  // 1. a pulse every 1,200,000 clocks
  // 2. tenths digit, 0..9
  // 3. seconds digit, 0..9

  hex7 d1(.digit(4'd0), .seg(hex1));
  hex7 d0(.digit(4'd0), .seg(hex0));
endmodule
`,
    solution: `${HEX7}

module top(
  input        clk,
  input        BTN,
  output [6:0] hex1,
  output [6:0] hex0
);
  reg [20:0] pre = 0;
  wire tick = (pre == 21'd1_199_999);
  always @(posedge clk)
    pre <= tick ? 21'd0 : pre + 1;

  reg [3:0] tenths = 0, secs = 0;
  always @(posedge clk) begin
    if (!BTN) begin
      tenths <= 0;
      secs <= 0;
    end else if (tick) begin
      if (tenths == 9) begin
        tenths <= 0;
        secs <= (secs == 9) ? 4'd0 : secs + 1;
      end else begin
        tenths <= tenths + 1;
      end
    end
  end

  hex7 d1(.digit(secs),   .seg(hex1));
  hex7 d0(.digit(tenths), .seg(hex0));
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'reset (SW2)', activeLow: true, key: ' ' }, { type: 'seg7', ports: ['hex1', 'hex0'], label: 'seconds . tenths' }],
    clock,
    tests: [
      { name: 'counts tenths and seconds', run(t) {
        t.set('BTN', 1);
        const show = n => `${Math.floor(n / 10) % 10}.${n % 10}`;
        for (const n of [1, 2, 9, 10, 11, 12]) {
          t.tick(n * 1_200_000 - (t._at || 0) + 4); t._at = n * 1_200_000 + 4;
          const want = { hex1: HEX[Math.floor(n / 10) % 10], hex0: HEX[n % 10] };
          const got1 = t.get('hex1'), got0 = t.get('hex0');
          t.ok(got1 === want.hex1 && got0 === want.hex0, `After ${n / 10} s (${n * 1_200_000} clocks) the display should read ${show(n)}.`);
        }
      } },
      { name: 'BTN resets to 0.0', run(t) {
        t.set('BTN', 1);
        t.tick(3 * 1_200_000 + 10);
        t.set('BTN', 0); t.tick(2); t.set('BTN', 1);
        t.ok(t.get('hex1') === HEX[0] && t.get('hex0') === HEX[0], 'After pressing the button the display should read 0.0.');
        t.tick(1_200_000 + 10);
        t.ok(t.get('hex0') === HEX[1] || t.get('hex0') === HEX[0], 'After a reset it should start counting again.');
      } },
    ],
  },
];
