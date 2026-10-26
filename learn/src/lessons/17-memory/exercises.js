import { used, logicCells } from '../../engine/flow.js';

const clock = { port: 'clk', hz: 12e6 };
const UART = `module uart_tx #(parameter CLKS_PER_BIT = 104) (
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
endmodule

module uart_rx #(parameter CLKS_PER_BIT = 104) (
  input clk, input rx, output reg [7:0] data = 0, output reg valid = 0
);
  reg [1:0] sync = 2'b11;
  always @(posedge clk) sync <= {sync[0], rx};
  wire r = sync[1];
  reg [1:0] state = 0;
  reg [15:0] timer = 0;
  reg [2:0] bitn = 0;
  reg [7:0] sh = 0;
  always @(posedge clk) begin
    valid <= 0;
    case (state)
      0: if (!r) begin state <= 1; timer <= 0; end
      1: if (timer == CLKS_PER_BIT/2 - 1) begin
           if (!r) begin state <= 2; timer <= 0; bitn <= 0; end else state <= 0;
         end else timer <= timer + 1;
      2: if (timer == CLKS_PER_BIT - 1) begin
           timer <= 0; sh <= {r, sh[7:1]};
           if (bitn == 7) state <= 3; else bitn <= bitn + 1;
         end else timer <= timer + 1;
      3: if (timer == CLKS_PER_BIT - 1) begin
           state <= 0;
           if (r) begin data <= sh; valid <= 1; end
         end else timer <= timer + 1;
    endcase
  end
endmodule`;

const RAM_SOL = `module ram(
  input            clk,
  input            we,
  input      [7:0] waddr,
  input      [7:0] wdata,
  input      [7:0] raddr,
  output reg [7:0] rdata
);
  reg [7:0] mem [0:255];
  always @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
    rdata <= mem[raddr];
  end
endmodule`;

export default [
  {
    id: 'ram',
    title: 'A 256-byte RAM',
    prompt: 'Write to `mem[waddr]` when `we` is high; `rdata` shows `mem[raddr]` one clock later. Then build for Icey and check it landed in a block RAM.',
    starter: `module ram(
  input            clk,
  input            we,
  input      [7:0] waddr,
  input      [7:0] wdata,
  input      [7:0] raddr,
  output reg [7:0] rdata
);
  reg [7:0] mem [0:255];

endmodule
`,
    solution: RAM_SOL,
    top: 'ram',
    iceyTop: 'ram',
    waves: ['clk', 'we', 'waddr', 'wdata', 'raddr', 'rdata'],
    tests: [
      { name: 'writes then reads back', run(t) {
        const vals = Array.from({ length: 256 }, (_, i) => (i * 37 + 11) & 255);
        t.set('we', 1);
        for (let a = 0; a < 256; a++) { t.set('waddr', a); t.set('wdata', vals[a]); t.tick(1); }
        t.set('we', 0);
        for (let a = 0; a < 256; a += 7) { t.set('raddr', a); t.tick(1); t.eq('rdata', vals[a], `one clock after setting raddr = ${a}`); }
      } },
      { name: 'the read is registered (one clock of latency)', run(t) {
        t.set('we', 1); t.set('waddr', 1); t.set('wdata', 0xaa); t.tick(1); t.set('waddr', 2); t.set('wdata', 0x55); t.tick(1); t.set('we', 0);
        t.set('raddr', 1); t.tick(1);
        t.set('raddr', 2);
        t.eq('rdata', 0xaa, 'right after changing raddr from 1 to 2, before the clock. It should still show address 1: block RAM reads happen on the clock edge');
        t.tick(1); t.eq('rdata', 0x55, 'one clock after raddr = 2');
      } },
    ],
    chipTests: [
      { name: 'uses a block RAM', check: r => used(r, 'ICESTORM_RAM') >= 1 ? null : 'No block RAM used, so the memory was built out of flip-flops. Is the read inside the clocked block?' },
      { name: 'hardly any logic', check: r => logicCells(r) <= 100 ? null : `${logicCells(r)} logic cells. In block RAM the memory needs almost none (a few dozen cells just pass the pins' signals in and out). Built from flip-flops it takes thousands.` },
    ],
  },
  {
    id: 'reverse',
    project: true,
    title: 'Backwards line editor',
    prompt: 'Store each received character in RAM. On Enter (13), send the line back reversed, then `\\r\\n`.',
    starter: `${UART}

${RAM_SOL}

module top(
  input  clk,
  input  RX,
  output TX
);
  wire [7:0] rx_data;
  wire rx_valid;
  uart_rx rx(.clk(clk), .rx(RX), .data(rx_data), .valid(rx_valid));

  // a RAM, a pointer, a state machine

  uart_tx tx(.clk(clk), .data(8'd0), .send(1'b0), .tx(TX), .busy());
endmodule
`,
    solution: `${UART}

${RAM_SOL}

module top(
  input  clk,
  input  RX,
  output TX
);
  wire [7:0] rx_data;
  wire rx_valid;
  uart_rx rx(.clk(clk), .rx(RX), .data(rx_data), .valid(rx_valid));

  reg  [7:0] len = 0;      // characters stored so far
  reg  [7:0] raddr = 0;
  wire [7:0] rdata;
  wire typing = (state == TYPE);
  ram mem(.clk(clk), .we(typing && rx_valid && rx_data != 8'd13 && len != 8'd255),
          .waddr(len), .wdata(rx_data), .raddr(raddr), .rdata(rdata));

  localparam TYPE = 2'd0, FETCH = 2'd1, SEND = 2'd2, CR = 2'd3;
  reg [1:0] state = TYPE;
  reg lf = 0;               // in CR state: 0 = send \\r next, 1 = send \\n next
  wire busy;
  reg send = 0;
  reg [7:0] data = 0;

  always @(posedge clk) begin
    send <= 0;
    case (state)
      TYPE:
        if (rx_valid) begin
          if (rx_data == 8'd13) begin
            if (len == 0) begin state <= CR; lf <= 0; end
            else begin raddr <= len - 1; state <= FETCH; end
          end else if (len != 8'd255) len <= len + 1;
        end
      FETCH: state <= SEND;           // wait one clock for the RAM
      SEND:
        if (!busy && !send) begin
          data <= rdata;
          send <= 1;
          if (raddr == 0) begin state <= CR; lf <= 0; end
          else begin raddr <= raddr - 1; state <= FETCH; end
        end
      CR:
        if (!busy && !send) begin
          data <= lf ? 8'h0a : 8'h0d;
          send <= 1;
          if (lf) begin state <= TYPE; len <= 0; end
          lf <= 1;
        end
    endcase
  end

  uart_tx tx(.clk(clk), .data(data), .send(send), .tx(TX), .busy(busy));
endmodule
`,
    board: [{ type: 'uart', tx: 'TX', rx: 'RX', baud: 115200 }],
    clock,
    gates: false,
    tests: [
      { name: 'reverses lines', run(t) {
        t.set('RX', 1); t.tick(50);
        for (const line of ['hello', 'Icey!', '', 'a', 'racecar stressed']) {
          for (const ch of line) t.uartSendByte('RX', ch.charCodeAt(0), 104);
          t.uartSendByte('RX', 13, 104);
          let got = '';
          for (let i = 0; i < line.length + 2; i++) got += String.fromCharCode(t.uartReadByte('TX', 104, 3000));
          const want = [...line].reverse().join('') + '\r\n';
          t.ok(got === want, `Sent ${JSON.stringify(line)}, expected ${JSON.stringify(want)}, got ${JSON.stringify(got)}.`);
        }
      } },
    ],
  },
];
