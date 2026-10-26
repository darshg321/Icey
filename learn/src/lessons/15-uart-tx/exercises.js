const clock = { port: 'clk', hz: 12e6 };

const UART_TX_SOL = `module uart_tx #(parameter CLKS_PER_BIT = 104) (
  input        clk,
  input  [7:0] data,
  input        send,      // pulse high for one clock to start
  output reg   tx = 1,
  output       busy
);
  reg [9:0] frame = 10'h3ff;   // bits still to send, bit 0 goes out next
  reg [3:0] bits_left = 0;
  reg [15:0] timer = 0;

  assign busy = (bits_left != 0);

  always @(posedge clk) begin
    if (!busy) begin
      if (send) begin
        frame <= {1'b1, data, 1'b0};
        bits_left <= 10;
        timer <= 0;
      end
    end else if (timer == CLKS_PER_BIT - 1) begin
      timer <= 0;
      frame <= {1'b1, frame[9:1]};
      bits_left <= bits_left - 1;
    end else begin
      timer <= timer + 1;
    end
    tx <= busy ? frame[0] : 1'b1;
  end
endmodule`;

const DEBOUNCE = `module debounce(input clk, input btn, output press);
  reg [1:0] sync = 2'b11;
  reg stable = 1, prev = 1;
  reg [15:0] timer = 0;
  always @(posedge clk) begin
    sync <= {sync[0], btn};
    if (sync[1] == stable) timer <= 0;
    else if (&timer)       stable <= sync[1];
    else                   timer <= timer + 1;
    prev <= stable;
  end
  assign press = prev & ~stable;
endmodule`;

const LETTERS_TOP = `module top(
  input  clk,
  input  BTN,
  output TX
);
  wire press;
  debounce db(.clk(clk), .btn(BTN), .press(press));

  reg [4:0] n = 0;
  always @(posedge clk) if (press) n <= (n == 25) ? 0 : n + 1;

  uart_tx u(.clk(clk), .data("A" + n), .send(press), .tx(TX), .busy());
endmodule`;

function readString(t, n, timeout = 40000) {
  let s = '';
  for (let i = 0; i < n; i++) s += String.fromCharCode(t.uartReadByte('tx' in t.sim.signals ? 'tx' : 'TX', 104, timeout));
  return s;
}

export default [
  {
    id: 'uart-tx',
    title: 'A UART transmitter',
    prompt: 'Finish `uart_tx`. When `send` pulses, transmit `data` as start bit, 8 data bits LSB first, stop bit, each `CLKS_PER_BIT` clocks long. `busy` is high from the clock after `send` until the stop bit is over.',
    starter: `${DEBOUNCE}

module uart_tx #(parameter CLKS_PER_BIT = 104) (
  input        clk,
  input  [7:0] data,
  input        send,      // pulse high for one clock to start
  output reg   tx = 1,
  output       busy
);
  reg [9:0]  frame = 10'h3ff;
  reg [3:0]  bits_left = 0;
  reg [15:0] timer = 0;

  assign busy = (bits_left != 0);

  always @(posedge clk) begin
    // your transmitter
  end
endmodule

${LETTERS_TOP}
`,
    solution: `${DEBOUNCE}

${UART_TX_SOL}

${LETTERS_TOP}
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ' }, { type: 'uart', tx: 'TX', baud: 115200 }],
    clock,
    testTop: 'uart_tx',
    waves: ['clk', 'send', 'data', 'tx', 'busy'],
    tests: [
      { name: 'idle line is high', run(t) { t.set('send', 0); t.tick(50); t.eq('tx', 1, 'while nothing is being sent'); t.eq('busy', 0, 'while idle'); } },
      { name: 'sends one byte correctly', run(t) {
        t.set('data', 0x4b); t.set('send', 1); t.tick(1); t.set('send', 0); t.set('data', 0);
        t.eq('busy', 1, 'one clock after send');
        const b = t.uartReadByte('tx', 104, 400);
        t.ok(b === 0x4b, `Sent 0x4b ("K") but the line carried 0x${b.toString(16)}. Remember: least significant bit first.`);
      } },
      { name: 'bit timing is 104 clocks', run(t) {
        t.set('data', 0x00); t.set('send', 1); t.tick(1); t.set('send', 0);
        t.until(() => t.get('tx') === 0, 10, 'the start bit');
        let low = 0;
        while (t.get('tx') === 0 && low < 2000) { t.tick(1); low++; }
        t.ok(Math.abs(low - 9 * 104) <= 2, `Sending 0x00 should hold tx low for 9 bit-times (start + 8 zeros) = 936 clocks. It was low for ${low}.`);
      } },
      { name: 'busy covers the whole frame, then drops', run(t) {
        t.set('data', 0x55); t.set('send', 1); t.tick(1); t.set('send', 0);
        let n = 0;
        while (t.get('busy') && n < 3000) { t.tick(1); n++; }
        t.ok(n >= 10 * 104 - 3 && n <= 10 * 104 + 3, `busy was high for ${n} clocks; a frame is 10 bits × 104 = 1040.`);
      } },
      { name: 'back to back bytes', run(t) {
        let got = '';
        for (const ch of 'Hi!') {
          t.until(() => !t.get('busy'), 3000, 'busy to drop');
          t.set('data', ch.charCodeAt(0)); t.set('send', 1); t.tick(1); t.set('send', 0);
          got += String.fromCharCode(t.uartReadByte('tx', 104, 400));
        }
        t.ok(got === 'Hi!', `Sent "Hi!" and the line carried "${got}".`);
      } },
    ],
  },
  {
    id: 'hello',
    project: true,
    title: 'Hello from Icey',
    prompt: 'Send `Hello from Icey!` followed by `\\r\\n` (bytes 13 and 10), then wait `PERIOD` clocks, and repeat forever. Paste in your `uart_tx`.',
    starter: `module uart_tx #(parameter CLKS_PER_BIT = 104) (
  input clk, input [7:0] data, input send, output reg tx = 1, output busy
);
  // paste yours here
endmodule

module top(
  input  clk,
  output TX
);
  parameter PERIOD = 12_000_000;   // one second between messages

  reg [4:0] index = 0;
  reg [7:0] char;
  always @(*) begin
    case (index)
      0: char = "H";
      1: char = "e";
      // ...
      default: char = 8'h0a;
    endcase
  end

  // feeder state machine: send the chars one by one, then wait PERIOD

endmodule
`,
    solution: `${UART_TX_SOL}

module top(
  input  clk,
  output TX
);
  parameter PERIOD = 12_000_000;

  localparam LEN = 18;   // "Hello from Icey!\\r\\n"
  reg [4:0] index = 0;
  reg [7:0] char;
  always @(*) begin
    case (index)
      0: char = "H";  1: char = "e";  2: char = "l";  3: char = "l";  4: char = "o";
      5: char = " ";  6: char = "f";  7: char = "r";  8: char = "o";  9: char = "m";
      10: char = " "; 11: char = "I"; 12: char = "c"; 13: char = "e"; 14: char = "y";
      15: char = "!"; 16: char = 8'h0d;
      default: char = 8'h0a;
    endcase
  end

  wire busy;
  reg send = 0;
  reg [23:0] wait_timer = 0;
  localparam SENDING = 1'b0, WAITING = 1'b1;
  reg state = SENDING;

  always @(posedge clk) begin
    send <= 0;
    case (state)
      SENDING:
        if (!busy && !send) begin
          if (index == LEN) begin
            state <= WAITING;
            index <= 0;
            wait_timer <= 0;
          end else begin
            send <= 1;
            index <= index + 1;
          end
        end
      WAITING:
        if (wait_timer == PERIOD - 1) state <= SENDING;
        else wait_timer <= wait_timer + 1;
    endcase
  end

  // send is registered, so latch the character it refers to
  reg [7:0] data = 0;
  always @(posedge clk) if (state == SENDING && !busy && !send && index != LEN) data <= char;

  uart_tx u(.clk(clk), .data(data), .send(send), .tx(TX), .busy(busy));
endmodule
`,
    board: [{ type: 'uart', tx: 'TX', baud: 115200 }],
    clock,
    testParams: { PERIOD: 5000 },
    tests: [
      { name: 'sends the message', run(t) {
        const s = readString(t, 18);
        t.ok(s === 'Hello from Icey!\r\n', `Expected "Hello from Icey!\\r\\n", got ${JSON.stringify(s)}.`);
      } },
      { name: 'repeats it after the pause', run(t) {
        readString(t, 18);
        const s = readString(t, 18, 40000);
        t.ok(s === 'Hello from Icey!\r\n', `The second message came out as ${JSON.stringify(s)}.`);
      } },
    ],
  },
];
