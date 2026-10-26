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
const board = [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ', bounce: true }, { type: 'seg7', ports: ['hex1', 'hex0'], label: 'presses (hex)' }];
const display = t => {
  const a = HEX.indexOf(t.get('hex1')), b = HEX.indexOf(t.get('hex0'));
  return a < 0 || b < 0 ? null : a * 16 + b;
};

// A press as a real button does it: bounces for a few ms, then holds.
function press(t, { bounceMs = 3, holdMs = 40, releaseMs = 40, bounce = true } = {}) {
  const ms = 12000;
  const chatter = (to) => {
    if (!bounce) { t.set('BTN', to); return; }
    let left = bounceMs * ms, v = to;
    while (left > 0) { const d = 200 + Math.floor(Math.random() * 2500); t.set('BTN', v); t.tick(Math.min(d, left)); left -= d; v ^= 1; }
    t.set('BTN', to);
  };
  chatter(0); t.tick(holdMs * ms);
  chatter(1); t.tick(releaseMs * ms);
}

export default [
  {
    id: 'edge',
    title: 'One count per press',
    prompt: 'Right now `count` races up while the button is held. Make it go up by one when the button goes *down*, and not again until it\'s released and pressed again.',
    starter: `${HEX7}

module top(
  input        clk,
  input        BTN,     // 0 while pressed
  output [6:0] hex1,
  output [6:0] hex0
);
  reg [7:0] count = 0;

  always @(posedge clk)
    if (!BTN) count <= count + 1;

  hex7 d1(.digit(count[7:4]), .seg(hex1));
  hex7 d0(.digit(count[3:0]), .seg(hex0));
endmodule
`,
    solution: `${HEX7}

module top(
  input        clk,
  input        BTN,
  output [6:0] hex1,
  output [6:0] hex0
);
  reg [7:0] count = 0;
  reg btn_prev = 1;
  always @(posedge clk) btn_prev <= BTN;
  wire pressed = btn_prev & ~BTN;

  always @(posedge clk)
    if (pressed) count <= count + 1;

  hex7 d1(.digit(count[7:4]), .seg(hex1));
  hex7 d0(.digit(count[3:0]), .seg(hex0));
endmodule
`,
    board,
    clock,
    tests: [
      { name: 'clean presses count once each', run(t) {
        t.set('BTN', 1); t.tick(5);
        t.ok(display(t) === 0, 'The display should start at 00.');
        for (let i = 1; i <= 5; i++) {
          t.set('BTN', 0); t.tick(1000); t.set('BTN', 1); t.tick(1000);
          const got = display(t);
          t.ok(got === i, `After ${i} press${i > 1 ? 'es' : ''} (each held for 1000 clocks) the count should be ${i}, but the display shows ${got === null ? 'something that isn\'t a hex digit' : got}.`);
        }
      } },
    ],
  },
  {
    id: 'debounce',
    project: true,
    title: 'A press counter that tells the truth',
    prompt: 'Synchronise `BTN`, debounce it (about 5 ms), then count presses of the clean signal. Try it on the board: it should go up by exactly one per press now.',
    starter: `${HEX7}

module top(
  input        clk,
  input        BTN,
  output [6:0] hex1,
  output [6:0] hex0
);
  // 1. two-flip-flop synchroniser
  // 2. debouncer
  // 3. edge detector on the debounced signal

  reg [7:0] count = 0;

  hex7 d1(.digit(count[7:4]), .seg(hex1));
  hex7 d0(.digit(count[3:0]), .seg(hex0));
endmodule
`,
    solution: `${HEX7}

module top(
  input        clk,
  input        BTN,
  output [6:0] hex1,
  output [6:0] hex0
);
  reg [1:0] sync = 2'b11;
  always @(posedge clk) sync <= {sync[0], BTN};
  wire btn_sync = sync[1];

  reg        stable = 1;
  reg [15:0] timer = 0;
  always @(posedge clk) begin
    if (btn_sync == stable) timer <= 0;
    else if (&timer)        stable <= btn_sync;
    else                    timer <= timer + 1;
  end

  reg stable_prev = 1;
  always @(posedge clk) stable_prev <= stable;
  wire pressed = stable_prev & ~stable;

  reg [7:0] count = 0;
  always @(posedge clk)
    if (pressed) count <= count + 1;

  hex7 d1(.digit(count[7:4]), .seg(hex1));
  hex7 d0(.digit(count[3:0]), .seg(hex0));
endmodule
`,
    board,
    clock,
    tests: [
      { name: 'bouncy presses count once each', run(t) {
        t.set('BTN', 1); t.tick(5);
        for (let i = 1; i <= 4; i++) {
          press(t);
          const got = display(t);
          t.ok(got === i, `After ${i} bouncy press${i > 1 ? 'es' : ''} the count should be ${i}, but the display shows ${got === null ? 'something that isn\'t a hex digit' : got}.`);
        }
      } },
      { name: 'a 1 ms glitch is ignored', run(t) {
        t.set('BTN', 1); t.tick(5);
        t.set('BTN', 0); t.tick(12000); t.set('BTN', 1); t.tick(200000);
        t.ok(display(t) === 0, 'A 1 ms blip on the button line counted as a press. The debouncer should wait about 5 ms before believing a change.');
      } },
      { name: 'reacts within 10 ms', run(t) {
        t.set('BTN', 1); t.tick(5);
        t.set('BTN', 0); t.tick(120000);
        t.ok(display(t) === 1, 'A press held for 10 ms should have been counted by now. Is the debounce time too long?');
      } },
    ],
  },
];
