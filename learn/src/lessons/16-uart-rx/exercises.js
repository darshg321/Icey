const clock = { port: 'clk', hz: 12e6 };

const UART_TX = `module uart_tx #(parameter CLKS_PER_BIT = 104) (
  input clk, input [7:0] data, input send, output reg tx = 1, output busy
);
  reg [9:0] frame = 10'h3ff;
  reg [3:0] bits_left = 0;
  reg [15:0] timer = 0;
  assign busy = (bits_left != 0);
  always @(posedge clk) begin
    if (!busy) begin
      if (send) begin frame <= {1'b1, data, 1'b0}; bits_left <= 10; timer <= 0; end
    end else if (timer == CLKS_PER_BIT - 1) begin
      timer <= 0; frame <= {1'b1, frame[9:1]}; bits_left <= bits_left - 1;
    end else timer <= timer + 1;
    tx <= busy ? frame[0] : 1'b1;
  end
endmodule`;

const UART_RX = `module uart_rx #(parameter CLKS_PER_BIT = 104) (
  input            clk,
  input            rx,
  output reg [7:0] data = 0,
  output reg       valid = 0
);
  reg [1:0] sync = 2'b11;
  always @(posedge clk) sync <= {sync[0], rx};
  wire r = sync[1];

  localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
  reg [1:0]  state = IDLE;
  reg [15:0] timer = 0;
  reg [2:0]  bitn = 0;
  reg [7:0]  sh = 0;

  always @(posedge clk) begin
    valid <= 0;
    case (state)
      IDLE: if (!r) begin state <= START; timer <= 0; end
      START:
        if (timer == CLKS_PER_BIT/2 - 1) begin
          if (!r) begin state <= DATA; timer <= 0; bitn <= 0; end
          else state <= IDLE;
        end else timer <= timer + 1;
      DATA:
        if (timer == CLKS_PER_BIT - 1) begin
          timer <= 0;
          sh <= {r, sh[7:1]};
          if (bitn == 7) state <= STOP; else bitn <= bitn + 1;
        end else timer <= timer + 1;
      STOP:
        if (timer == CLKS_PER_BIT - 1) begin
          state <= IDLE;
          if (r) begin data <= sh; valid <= 1; end
        end else timer <= timer + 1;
    endcase
  end
endmodule`;

const ECHO_TOP = `module top(
  input  clk,
  input  RX,
  output TX
);
  wire [7:0] data;
  wire valid;
  uart_rx rx(.clk(clk), .rx(RX), .data(data), .valid(valid));
  uart_tx tx(.clk(clk), .data(data), .send(valid), .tx(TX), .busy());
endmodule`;

const BCD = `module bcd(
  input      [13:0] bin,
  output reg [15:0] dec     // four decimal digits, 4 bits each
);
  integer i;
  always @(*) begin
    dec = 0;
    for (i = 13; i >= 0; i = i - 1) begin
      if (dec[3:0]   >= 5) dec[3:0]   = dec[3:0]   + 3;
      if (dec[7:4]   >= 5) dec[7:4]   = dec[7:4]   + 3;
      if (dec[11:8]  >= 5) dec[11:8]  = dec[11:8]  + 3;
      if (dec[15:12] >= 5) dec[15:12] = dec[15:12] + 3;
      dec = {dec[14:0], bin[i]};
    end
  end
endmodule`;

const DEBOUNCE = `module debounce #(parameter DB_BITS = 16) (input clk, input btn, output press);
  reg [1:0] sync = 2'b11;
  reg stable = 1, prev = 1;
  reg [DB_BITS-1:0] timer = 0;
  always @(posedge clk) begin
    sync <= {sync[0], btn};
    if (sync[1] == stable) timer <= 0;
    else if (&timer)       stable <= sync[1];
    else                   timer <= timer + 1;
    prev <= stable;
  end
  assign press = prev & ~stable;
endmodule`;

// reference LFSR, same taps as the lesson
const lfsrNext = x => (((x << 1) & 0xffff) | (((x >> 15) ^ (x >> 13) ^ (x >> 12) ^ (x >> 10)) & 1));
const toBcd = n => parseInt(String(n), 16);

function recvLine(t, timeout) {
  let s = '';
  for (let i = 0; i < 20; i++) {
    const c = String.fromCharCode(t.uartReadByte('TX', 104, i ? 2000 : timeout));
    s += c;
    if (c === '\n') return s;
  }
  return s;
}

export default [
  {
    id: 'uart-rx',
    title: 'A UART receiver',
    prompt: 'Receive bytes on `rx`: synchronise, find the start bit, check it again half a bit later, sample 8 bits in their middles, check the stop bit, then pulse `valid` for one clock with the byte on `data`.',
    starter: `${UART_TX}

module uart_rx #(parameter CLKS_PER_BIT = 104) (
  input            clk,
  input            rx,
  output reg [7:0] data = 0,
  output reg       valid = 0
);
  reg [1:0] sync = 2'b11;
  always @(posedge clk) sync <= {sync[0], rx};
  wire r = sync[1];

  // IDLE -> START -> DATA -> STOP
endmodule

${ECHO_TOP}
`,
    solution: `${UART_TX}

${UART_RX}

${ECHO_TOP}
`,
    board: [{ type: 'uart', tx: 'TX', rx: 'RX', baud: 115200 }],
    clock,
    testTop: 'uart_rx',
    waves: ['clk', 'rx', 'valid', 'data'],
    tests: [
      { name: 'receives bytes', run(t) {
        t.set('rx', 1); t.tick(20);
        for (const b of [0x41, 0x00, 0xff, 0x5a, 0x0d]) {
          for (const bit of [0, ...Array.from({ length: 8 }, (_, i) => (b >> i) & 1)]) { t.set('rx', bit); t.tick(104); }
          t.set('rx', 1);
          let pulses = 0, got = null;
          for (let i = 0; i < 160; i++) { t.tick(1); if (t.get('valid')) { pulses++; got = t.get('data'); } }
          t.ok(pulses === 1, `After sending 0x${b.toString(16)}, valid should pulse exactly once (it pulsed ${pulses} times).`);
          t.ok(got === b, `Sent 0x${b.toString(16)}, received 0x${(got ?? 0).toString(16)}.`);
          t.tick(60);
        }
      } },
      { name: 'ignores a short glitch', run(t) {
        t.set('rx', 1); t.tick(20);
        t.set('rx', 0); t.tick(20); t.set('rx', 1);
        let pulses = 0;
        for (let i = 0; i < 1500; i++) { t.tick(1); pulses += t.get('valid'); }
        t.ok(pulses === 0, 'A 20-clock blip on rx was received as a byte. Check the start bit again half a bit-time after the falling edge.');
      } },
      { name: 'drops a byte with a bad stop bit', run(t) {
        t.set('rx', 1); t.tick(20);
        for (const bit of [0, 1, 0, 1, 0, 1, 0, 1, 0, 0]) { t.set('rx', bit); t.tick(104); }
        t.set('rx', 1);
        let pulses = 0;
        for (let i = 0; i < 300; i++) { t.tick(1); pulses += t.get('valid'); }
        t.ok(pulses === 0, 'A frame whose stop bit was 0 should be thrown away, not reported as valid.');
      } },
    ],
  },
  {
    id: 'lfsr',
    title: 'A random number generator',
    prompt: 'A 16-bit LFSR starting at `16\'hACE1`, shifting left every clock, feeding back `lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]`. Show the low 8 bits on the LEDs.',
    starter: `module top(
  input         clk,
  output [15:0] lfsr_out,
  output [7:0]  led
);
  reg [15:0] lfsr = 16'hACE1;
  // shift

  assign lfsr_out = lfsr;
  assign led = lfsr[7:0];
endmodule
`,
    solution: `module top(
  input         clk,
  output [15:0] lfsr_out,
  output [7:0]  led
);
  reg [15:0] lfsr = 16'hACE1;
  always @(posedge clk)
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
  assign lfsr_out = lfsr;
  assign led = lfsr[7:0];
endmodule
`,
    board: [{ type: 'leds', port: 'led', label: 'lfsr[7:0]' }],
    clock: { port: 'clk', hz: 10 },
    tests: [
      { name: 'matches the reference sequence', run(t) {
        let x = 0xace1;
        t.eq('lfsr_out', x, 'at power-up');
        for (let i = 1; i <= 200; i++) { t.tick(1); x = lfsrNext(x); t.eq('lfsr_out', x, `after ${i} clocks`); }
      } },
      { name: 'repeats only after 65,535 steps', run(t) {
        const start = t.get('lfsr_out');
        let n = 0;
        do { t.tick(1); n++; } while (t.get('lfsr_out') !== start && n < 70000);
        t.ok(n === 65535, `The sequence repeated after ${n} steps, not 65,535. Check the taps.`);
      } },
    ],
  },
  {
    id: 'bcd',
    title: 'Binary to decimal',
    prompt: 'Double dabble: turn a 14-bit number (0 to 9999) into four BCD digits. The display shows them; the input is on the switches.',
    starter: `module bcd(
  input      [13:0] bin,
  output reg [15:0] dec
);
  always @(*) begin
    dec = 0;
  end
endmodule

module top(
  input  [13:0] sw,
  output [15:0] dec,
  output [6:0]  hex3, hex2, hex1, hex0
);
  bcd b(.bin(sw), .dec(dec));
  hex7 h3(.digit(dec[15:12]), .seg(hex3));
  hex7 h2(.digit(dec[11:8]),  .seg(hex2));
  hex7 h1(.digit(dec[7:4]),   .seg(hex1));
  hex7 h0(.digit(dec[3:0]),   .seg(hex0));
endmodule

module hex7(input [3:0] digit, output reg [6:0] seg);
  always @(*) case (digit)
    4'h0: seg = 7'b0111111;  4'h1: seg = 7'b0000110;  4'h2: seg = 7'b1011011;  4'h3: seg = 7'b1001111;
    4'h4: seg = 7'b1100110;  4'h5: seg = 7'b1101101;  4'h6: seg = 7'b1111101;  4'h7: seg = 7'b0000111;
    4'h8: seg = 7'b1111111;  4'h9: seg = 7'b1101111;  default: seg = 7'b1000000;
  endcase
endmodule
`,
    solution: `${BCD}

module top(
  input  [13:0] sw,
  output [15:0] dec,
  output [6:0]  hex3, hex2, hex1, hex0
);
  bcd b(.bin(sw), .dec(dec));
  hex7 h3(.digit(dec[15:12]), .seg(hex3));
  hex7 h2(.digit(dec[11:8]),  .seg(hex2));
  hex7 h1(.digit(dec[7:4]),   .seg(hex1));
  hex7 h0(.digit(dec[3:0]),   .seg(hex0));
endmodule

module hex7(input [3:0] digit, output reg [6:0] seg);
  always @(*) case (digit)
    4'h0: seg = 7'b0111111;  4'h1: seg = 7'b0000110;  4'h2: seg = 7'b1011011;  4'h3: seg = 7'b1001111;
    4'h4: seg = 7'b1100110;  4'h5: seg = 7'b1101101;  4'h6: seg = 7'b1111101;  4'h7: seg = 7'b0000111;
    4'h8: seg = 7'b1111111;  4'h9: seg = 7'b1101111;  default: seg = 7'b1000000;
  endcase
endmodule
`,
    board: [{ type: 'switches', port: 'sw', width: 14, label: 'binary', initial: 347 }, { type: 'value', port: 'sw', label: 'value' }, { type: 'seg7', ports: ['hex3', 'hex2', 'hex1', 'hex0'], label: 'decimal' }],
    gates: false,
    tests: [{ name: 'every number from 0 to 9999', run(t) {
      for (let n = 0; n < 10000; n++) {
        t.sim.set('sw', n); t.sim.settle();
        const got = t.sim.get('dec');
        if (got !== toBcd(n)) t.fail(`For ${n}, dec should be 16'h${String(n).padStart(4, '0')}, but it was 16'h${got.toString(16).padStart(4, '0')}.`);
      }
    } }],
  },
  {
    id: 'reaction',
    project: true,
    title: 'Reaction timer',
    prompt: 'Press SW2 to start. After 1 s + `lfsr[10:0]` ms the LED lights; press again and Icey sends e.g. `247 ms\\r\\n`. Pressing early sends `too soon!\\r\\n`. Parameters `MS` (clocks per ms) and `DB_BITS`. (The virtual board sets `MS = 750`, because the simulator runs slower than the real chip; that keeps the game at roughly real speed.)',
    starter: `${DEBOUNCE}

${UART_TX}

${BCD}

module top(
  input  clk,
  input  BTN,
  output LED,
  output TX
);
  parameter MS = 12_000;      // clocks per millisecond
  parameter DB_BITS = 16;

  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  // LFSR, millisecond tick, state machine, message feeder...

  assign LED = 0;
  uart_tx u(.clk(clk), .data(8'd0), .send(1'b0), .tx(TX), .busy());
endmodule
`,
    solution: `${DEBOUNCE}

${UART_TX}

${BCD}

module top(
  input  clk,
  input  BTN,
  output LED,
  output TX
);
  parameter MS = 12_000;
  parameter DB_BITS = 16;

  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  reg [15:0] lfsr = 16'hACE1;
  always @(posedge clk) lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

  reg [15:0] pre = 0;
  wire ms_tick = (pre == MS - 1);
  always @(posedge clk) pre <= ms_tick ? 16'd0 : pre + 1;

  localparam IDLE = 3'd0, WAIT = 3'd1, GO = 3'd2, REPORT = 3'd3, EARLY = 3'd4;
  reg [2:0]  state = IDLE;
  reg [13:0] count = 0;
  wire msg_done;

  always @(posedge clk) begin
    case (state)
      IDLE: if (press) begin state <= WAIT; count <= 14'd1000 + lfsr[10:0]; end
      WAIT:
        if (press) state <= EARLY;
        else if (ms_tick) begin
          if (count == 0) state <= GO;
          else count <= count - 1;
        end
      GO:
        if (press) state <= REPORT;
        else if (ms_tick && count != 9999) count <= count + 1;
      REPORT, EARLY: if (msg_done) state <= IDLE;
      default: state <= IDLE;
    endcase
  end
  assign LED = (state == GO);

  wire [15:0] dec;
  bcd conv(.bin(count), .dec(dec));
  wire [3:0] d3 = dec[15:12], d2 = dec[11:8], d1 = dec[7:4], d0 = dec[3:0];

  reg [3:0] p = 0;
  reg [7:0] ch;
  reg skip, last;
  always @(*) begin
    ch = " "; skip = 0; last = 0;
    if (state == EARLY) begin
      case (p)
        0: ch = "t"; 1: ch = "o"; 2: ch = "o"; 3: ch = " "; 4: ch = "s";
        5: ch = "o"; 6: ch = "o"; 7: ch = "n"; 8: ch = "!"; 9: ch = 8'h0d;
        default: ch = 8'h0a;
      endcase
      last = (p == 10);
    end else begin
      case (p)
        0: ch = "0" + d3; 1: ch = "0" + d2; 2: ch = "0" + d1; 3: ch = "0" + d0;
        4: ch = " "; 5: ch = "m"; 6: ch = "s"; 7: ch = 8'h0d;
        default: ch = 8'h0a;
      endcase
      skip = (p == 0 && d3 == 0) || (p == 1 && d3 == 0 && d2 == 0) || (p == 2 && d3 == 0 && d2 == 0 && d1 == 0);
      last = (p == 8);
    end
  end

  wire active = (state == REPORT) || (state == EARLY);
  wire busy;
  reg send = 0, done = 0;
  reg [7:0] data = 0;
  always @(posedge clk) begin
    send <= 0;
    if (!active) begin
      p <= 0;
      done <= 0;
    end else if (!done && !busy && !send) begin
      if (!skip) begin send <= 1; data <= ch; end
      if (last) done <= 1; else p <= p + 1;
    end
  end
  assign msg_done = done && !busy && !send;

  uart_tx u(.clk(clk), .data(data), .send(send), .tx(TX), .busy(busy));
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ', bounce: true }, { type: 'led', port: 'LED', label: 'LED1' }, { type: 'uart', tx: 'TX', baud: 115200 }],
    clock,
    testParams: { MS: 20, DB_BITS: 4 },
    // The browser simulates this design about 14 times slower than the chip,
    // so the board runs it with 16 times fewer clocks per millisecond.
    simParams: { MS: 750, DB_BITS: 12 },
    gates: false,
    tests: [
      { name: 'measures the reaction time', run(t) {
        const press = () => { t.set('BTN', 0); t.tick(60); t.set('BTN', 1); };
        t.set('BTN', 1); t.tick(37);
        for (const ms of [250, 31]) {
          press();
          const waited = t.until(() => t.get('LED') === 1, 20 * 3200, 'the LED to light');
          t.ok(waited >= 20 * 990, `The LED lit after only ${(waited / 20).toFixed(0)} ms. The delay should be at least 1000 ms.`);
          t.tick(20 * ms - 60);
          press();
          const line = recvLine(t, 5000);
          const v = parseInt(line, 10);
          t.ok(/^\d+ ms\r\n$/.test(line), `Expected something like "${ms} ms\\r\\n", got ${JSON.stringify(line)}.`);
          t.ok(Math.abs(v - ms) <= 3, `Pressed ${ms} ms after the LED lit, but it reported ${v} ms.`);
          t.tick(500);
        }
      } },
      { name: 'catches an early press', run(t) {
        const press = () => { t.set('BTN', 0); t.tick(60); t.set('BTN', 1); };
        t.set('BTN', 1); t.tick(10);
        press(); t.tick(20 * 300); press();
        const line = recvLine(t, 5000);
        t.ok(line === 'too soon!\r\n', `Pressing 300 ms after the start should send "too soon!\\r\\n", got ${JSON.stringify(line)}.`);
        t.eq('LED', 0, 'after a too-soon press');
      } },
    ],
  },
];
