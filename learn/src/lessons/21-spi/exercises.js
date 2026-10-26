const clock = { port: 'clk', hz: 12e6 };

const SPI_BYTE = `module spi_byte #(parameter HALF = 8) (   // SCK half-period, in clocks
  input            clk,
  input            start,      // pulse: begin exchanging tx
  input      [7:0] tx,
  output reg [7:0] rx = 0,
  output           busy,
  output reg       sck = 0,
  output           mosi,
  input            miso
);
  reg [7:0] sh = 0;            // outgoing bits, MSB first
  reg [3:0] bits = 0;          // bits still to go
  reg [7:0] timer = 0;
  assign busy = (bits != 0);
  assign mosi = sh[7];

  always @(posedge clk) begin
    if (!busy) begin
      sck <= 0;
      if (start) begin sh <= tx; bits <= 8; timer <= 0; end
    end else if (timer == HALF - 1) begin
      timer <= 0;
      sck <= ~sck;
      if (!sck) rx <= {rx[6:0], miso};               // rising edge: sample
      else begin sh <= {sh[6:0], 1'b0}; bits <= bits - 1; end  // falling edge: next bit
    end else
      timer <= timer + 1;
  end
endmodule`;

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

// A software SPI slave for the tests. respond(bytesSoFar) gives the next byte to send.
function spiSlave(t, { sck, mosi, miso, cs }, respond) {
  const st = { lastSck: t.get(sck), lastCs: cs ? t.get(cs) : 0, inByte: 0, n: 0, bytes: [], out: 0xff, outBits: 0, transactions: [] };
  if (!cs) { st.out = respond([]); t.sim.set(miso, (st.out >> 7) & 1); st.outBits = 1; }
  return () => {
    const c = cs ? t.sim.get(cs) : 0, k = t.sim.get(sck);
    if (c === 1) {
      if (st.lastCs === 0) st.transactions.push(st.bytes);
      st.n = 0; st.bytes = []; st.inByte = 0; st.outBits = 0;
    } else {
      if (st.lastCs === 1 && cs) { st.out = respond([]); st.outBits = 0; t.sim.set(miso, (st.out >> 7) & 1); st.outBits = 1; }
      if (st.lastSck === 0 && k === 1) {
        st.inByte = ((st.inByte << 1) | t.sim.get(mosi)) & 255;
        if (++st.n === 8) { st.bytes.push(st.inByte); st.n = 0; st.out = respond(st.bytes); st.outBits = 0; }
      }
      if (st.lastSck === 1 && k === 0) { t.sim.set(miso, (st.out >> (7 - st.outBits)) & 1); st.outBits = Math.min(st.outBits + 1, 7); }
    }
    st.lastSck = k; st.lastCs = c;
    return st;
  };
}

function run(t, n, hook) { let st; for (let i = 0; i < n; i++) { t.sim.tick('clk'); st = hook(); } return st; }

export default [
  {
    id: 'spi-byte',
    title: 'One byte each way',
    prompt: 'An SPI mode 0 master for one byte: SCK idles low, MOSI changes on falling edges, MISO is sampled on rising edges, MSB first. Each half of an SCK period lasts `HALF` clocks.',
    starter: `module spi_byte #(parameter HALF = 8) (
  input            clk,
  input            start,
  input      [7:0] tx,
  output reg [7:0] rx = 0,
  output           busy,
  output reg       sck = 0,
  output           mosi,
  input            miso
);
  reg [7:0] sh = 0;
  reg [3:0] bits = 0;
  reg [7:0] timer = 0;
  assign busy = (bits != 0);
  assign mosi = sh[7];

  always @(posedge clk) begin
    // your SPI master
  end
endmodule
`,
    solution: SPI_BYTE,
    top: 'spi_byte',
    waves: ['clk', 'start', 'sck', 'mosi', 'miso', 'busy', 'rx'],
    tests: [
      { name: 'exchanges a byte in both directions', run(t) {
        for (const [send, reply] of [[0x9f, 0xa5], [0x3c, 0x0f], [0x00, 0xff], [0xff, 0x00]]) {
          const slave = spiSlave(t, { sck: 'sck', mosi: 'mosi', miso: 'miso' }, () => reply);
          t.set('tx', send); t.set('start', 1); t.tick(1); t.set('start', 0);
          let st = slave(), n = 0;
          while (t.get('busy') && n++ < 1000) { t.tick(1); st = slave(); }
          t.ok(n > 0, 'busy should go high the clock after start.');
          t.ok(n < 1000, 'busy never went low again.');
          t.ok(st.bytes[0] === send, `Sent 0x${send.toString(16)} but the slave received 0x${(st.bytes[0] ?? 0).toString(16)}. MSB first, and MOSI should only change on falling edges of SCK.`);
          t.eq('rx', reply, `after exchanging with a slave that sent 0x${reply.toString(16)}`);
          t.eq('sck', 0, 'between bytes (mode 0: SCK idles low)');
          t.tick(10);
        }
      } },
      { name: 'SCK runs at clk / (2 × HALF)', run(t) {
        t.set('tx', 0x55); t.set('start', 1); t.tick(1); t.set('start', 0);
        const edges = [];
        let last = t.get('sck');
        for (let i = 0; i < 200; i++) { t.tick(1); const k = t.get('sck'); if (k && !last) edges.push(i); last = k; }
        t.ok(edges.length === 8, `Counted ${edges.length} rising edges of SCK; one byte needs 8.`);
        const gaps = edges.slice(1).map((e, i) => e - edges[i]);
        t.ok(gaps.every(g => g === 16), `Rising edges should be 16 clocks apart (HALF = 8), but the gaps were ${gaps.join(', ')}.`);
      } },
    ],
  },
  {
    id: 'jedec',
    project: true,
    title: 'Ask the flash chip who it is',
    prompt: 'On a press of SW2: pull `FLASH_CS` low, send `0x9F`, read three bytes, raise `FLASH_CS`, then print them in hex over serial: `ef 40 18\\r\\n`. Parameter `DB_BITS` for the debouncer.',
    starter: `${DEBOUNCE}

${UART_TX}

${SPI_BYTE}

module top(
  input  clk,
  input  BTN,
  output TX,
  output FLASH_SCK,
  output FLASH_CS,
  output FLASH_MOSI,
  input  FLASH_MISO
);
  parameter DB_BITS = 16;
  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  // a state machine that drives spi_byte four times, then prints the ID

  assign FLASH_CS = 1;
  assign FLASH_SCK = 0;
  assign FLASH_MOSI = 0;
  assign TX = 1;
endmodule
`,
    solution: `${DEBOUNCE}

${UART_TX}

${SPI_BYTE}

module top(
  input  clk,
  input  BTN,
  output TX,
  output FLASH_SCK,
  output FLASH_CS,
  output FLASH_MOSI,
  input  FLASH_MISO
);
  parameter DB_BITS = 16;
  wire press;
  debounce #(.DB_BITS(DB_BITS)) db(.clk(clk), .btn(BTN), .press(press));

  reg spi_start = 0;
  reg [7:0] spi_tx = 0;
  wire [7:0] spi_rx;
  wire spi_busy;
  spi_byte spi(.clk(clk), .start(spi_start), .tx(spi_tx), .rx(spi_rx), .busy(spi_busy),
               .sck(FLASH_SCK), .mosi(FLASH_MOSI), .miso(FLASH_MISO));

  reg cs = 1;
  assign FLASH_CS = cs;

  reg [23:0] id = 0;
  reg [2:0] nbytes = 0;      // bytes exchanged so far in this transaction
  reg [3:0] p = 0;           // position in the printed line
  localparam IDLE = 2'd0, SPI = 2'd1, PRINT = 2'd2;
  reg [1:0] state = IDLE;

  // the line "ef 40 18\\r\\n", one character at a time
  function [7:0] hexch(input [3:0] n);
    hexch = (n < 10) ? "0" + n : "a" + n - 10;
  endfunction
  reg [7:0] ch;
  always @(*) begin
    case (p)
      0: ch = hexch(id[23:20]); 1: ch = hexch(id[19:16]); 2: ch = " ";
      3: ch = hexch(id[15:12]); 4: ch = hexch(id[11:8]);  5: ch = " ";
      6: ch = hexch(id[7:4]);   7: ch = hexch(id[3:0]);   8: ch = 8'h0d;
      default: ch = 8'h0a;
    endcase
  end

  wire busy;
  reg send = 0;
  reg [7:0] data = 0;
  uart_tx u(.clk(clk), .data(data), .send(send), .tx(TX), .busy(busy));

  always @(posedge clk) begin
    spi_start <= 0;
    send <= 0;
    case (state)
      IDLE:
        if (press) begin
          cs <= 0;
          spi_tx <= 8'h9f;
          spi_start <= 1;
          nbytes <= 0;
          state <= SPI;
        end
      SPI:
        if (!spi_busy && !spi_start) begin
          if (nbytes != 0) id <= {id[15:0], spi_rx};
          if (nbytes == 3) begin
            cs <= 1;
            p <= 0;
            state <= PRINT;
          end else begin
            spi_tx <= 8'h00;
            spi_start <= 1;
            nbytes <= nbytes + 1;
          end
        end
      PRINT:
        if (!busy && !send) begin
          data <= ch;
          send <= 1;
          if (p == 9) state <= IDLE; else p <= p + 1;
        end
      default: state <= IDLE;
    endcase
  end
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ' }, { type: 'spiflash', sck: 'FLASH_SCK', cs: 'FLASH_CS', mosi: 'FLASH_MOSI', miso: 'FLASH_MISO' }, { type: 'uart', tx: 'TX', baud: 115200 }],
    clock,
    testParams: { DB_BITS: 4 },
    gates: false,
    tests: [
      { name: 'reads ef 40 18 and prints it', run(t) {
        t.set('BTN', 1); t.set('FLASH_MISO', 1); t.tick(5);
        t.eq('FLASH_CS', 1, 'before anything has happened (CS is active low, so idle is 1)');
        const slave = spiSlave(t, { sck: 'FLASH_SCK', mosi: 'FLASH_MOSI', miso: 'FLASH_MISO', cs: 'FLASH_CS' },
          bytes => (bytes[0] === 0x9f ? [0xef, 0x40, 0x18][bytes.length - 1] ?? 0xff : 0xff));
        t.set('BTN', 0); run(t, 40, slave); t.set('BTN', 1);
        let st = null, n = 0;
        // run the SPI transaction while watching the line for the UART output
        let line = '';
        const cpb = 104;
        let state = 'idle', count = 0, bit = 0, byte = 0;
        while (n++ < 30000 && line.length < 10) {
          t.sim.tick('clk'); st = slave();
          const x = t.sim.get('TX');
          if (state === 'idle') { if (!x) { state = 'start'; count = cpb >> 1; } }
          else if (--count <= 0) {
            if (state === 'start') { state = 'data'; bit = 0; byte = 0; count = cpb; }
            else if (state === 'data') { byte |= x << bit++; count = cpb; if (bit === 8) state = 'stop'; }
            else { line += String.fromCharCode(byte); state = 'idle'; }
          }
        }
        const tr = st.transactions[0];
        t.ok(tr && tr[0] === 0x9f, `The first byte sent to the flash should be 0x9f, but it was ${tr ? '0x' + tr[0].toString(16) : 'nothing (did CS go low, and back high at the end?)'}.`);
        t.ok(tr.length === 4, `One transaction should be 4 bytes (0x9f + 3 ID bytes), with CS low for all of it. It was ${tr.length}.`);
        t.ok(line === 'ef 40 18\r\n', `Expected "ef 40 18\\r\\n" on the serial port, got ${JSON.stringify(line)}.`);
      } },
    ],
  },
];
