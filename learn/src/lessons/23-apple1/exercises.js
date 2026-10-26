const clock = { port: 'clk', hz: 12e6 };

// Until the Woz Monitor is loaded, the ROM holds a little program that says so.
const PLACEHOLDER = (() => {
  const msg = 'NO MONITOR IN ROM YET. LOAD WOZMON (LESSON 23)';
  const bytes = [0xa2, 0x00, 0xbd, 0x20, 0xff, 0xf0, 0x0c, 0x2c, 0x12, 0xd0, 0x30, 0xfb, 0x8d, 0x12, 0xd0, 0xe8, 0xd0, 0xf0, 0xea, 0x4c, 0x13, 0xff];
  const rom = new Array(256).fill(0);
  bytes.forEach((b, i) => { rom[i] = b; });
  [...msg].forEach((c, i) => { rom[0x20 + i] = c.charCodeAt(0) | 0x80; });
  rom[0x20 + msg.length] = 0x8d;
  [0xa9, 0xa7, 0x8d, 0x13, 0xd0, 0x8d, 0x11, 0xd0, 0x4c, 0x00, 0xff].forEach((b, i) => { rom[0xa0 + i] = b; });  // PIA setup, then $FF00
  rom[0xfc] = 0xa0; rom[0xfd] = 0xff;
  const lines = [];
  for (let a = 0; a < 256; a += 8) lines.push('    ' + rom.slice(a, a + 8).map((v, i) => `rom[8'h${(a + i).toString(16).padStart(2, '0')}] = 8'h${v.toString(16).padStart(2, '0')};`).join(' '));
  return `  // A placeholder: prints a reminder. Replace this whole block with the Woz Monitor.\n  initial begin\n${lines.join('\n')}\n  end`;
})();

const DECODE = `module decode(
  input  [15:0] addr,
  output        ram_sel,   // $0000-$1FFF  8 KB of RAM
  output        pia_sel,   // $D010-$D01F  keyboard and display
  output        rom_sel    // $FF00-$FFFF  the Woz Monitor
);
  assign ram_sel = (addr[15:13] == 3'b000);
  assign pia_sel = (addr[15:4] == 12'hD01);
  assign rom_sel = (addr[15:8] == 8'hFF);
endmodule`;

const PIA = `module pia(
  input            clk,
  input            en,         // the CPU's clock enable: one pulse per 6502 cycle
  input            sel,
  input      [1:0] addr,
  input            we,
  input      [7:0] di,
  output reg [7:0] dout = 0,
  input      [7:0] key,        // from the keyboard (serial)
  input            key_valid,
  output reg [6:0] char = 0,   // to the display (serial)
  output reg       char_send = 0,
  input            char_busy
);
  reg [6:0] kbd = 0;
  reg       kbd_ready = 0;
  reg [5:0] kbdcr = 0, dspcr = 0;   // control registers; bit 2 = 1 selects the data register

  always @(posedge clk) begin
    char_send <= 0;
    if (key_valid) begin
      kbd <= key[6:0];
      kbd_ready <= 1;
    end
    if (en && sel && !we) begin
      case (addr)
        2'd0: begin dout <= {1'b1, kbd}; kbd_ready <= 0; end    // KBD: reading takes the key
        2'd1: dout <= {kbd_ready, 1'b0, kbdcr};                 // KBDCR: bit 7 = key waiting
        2'd2: dout <= {char_busy | char_send, 7'd0};            // DSP: bit 7 = display busy
        default: dout <= {2'b00, dspcr};                        // DSPCR
      endcase
    end
    if (en && sel && we) begin
      case (addr)
        2'd1: kbdcr <= di[5:0];
        2'd2: if (dspcr[2]) begin char <= di[6:0]; char_send <= 1; end   // else it's the direction register
        2'd3: dspcr <= di[5:0];
        default: ;
      endcase
    end
  end
endmodule`;

const SERIAL = `module uart_tx #(parameter CLKS_PER_BIT = 104) (
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
endmodule

// The Apple I's terminal, as far as the CPU can tell: takes 7-bit characters,
// turns carriage return into CR LF, and says when it's busy.
module display(input clk, input [6:0] char, input send, output busy, output TX);
  reg lf_pending = 0;
  reg tx_send = 0;
  reg [7:0] tx_data = 0;
  wire tx_busy;
  always @(posedge clk) begin
    tx_send <= 0;
    if (send) begin tx_data <= {1'b0, char}; tx_send <= 1; lf_pending <= (char == 7'h0d); end
    else if (lf_pending && !tx_busy && !tx_send) begin tx_data <= 8'h0a; tx_send <= 1; lf_pending <= 0; end
  end
  assign busy = tx_busy | tx_send | lf_pending;
  uart_tx u(.clk(clk), .data(tx_data), .send(tx_send), .tx(TX), .busy(tx_busy));
endmodule

// Typing on a modern keyboard, made to look like an Apple I keyboard:
// upper case only, Enter is CR, backspace becomes the underscore Woz used for rubout.
module keyboard(input clk, input RX, output reg [7:0] key = 0, output reg valid = 0);
  wire [7:0] d;
  wire v;
  uart_rx u(.clk(clk), .rx(RX), .data(d), .valid(v));
  always @(posedge clk) begin
    valid <= 0;
    if (v && d != 8'h0a) begin
      valid <= 1;
      if (d >= "a" && d <= "z")          key <= d - 8'h20;
      else if (d == 8'h08 || d == 8'h7f) key <= "_";
      else                               key <= d;
    end
  end
endmodule`;

const TOP_SOL = `module top(
  input  clk,
  input  BTN,      // RESET, like the key on the Apple I's keyboard
  input  RX,
  output TX,
  output LED
);
  parameter CPU_DIV = 12;      // 12 MHz / 12 = 1 MHz, the Apple I's speed

  // ---- reset: at power-up, and while BTN is held
  reg [3:0] por = 0;
  always @(posedge clk) if (!BTN) por <= 0; else if (!(&por)) por <= por + 1;
  wire reset = !(&por);

  // ---- 1 MHz clock enable
  reg [3:0] div = 0;
  wire en = (div == CPU_DIV - 1);
  always @(posedge clk) div <= en ? 4'd0 : div + 1;

  // ---- the CPU
  wire [15:0] ab;
  wire [7:0] dout;
  wire we;
  reg  [7:0] din;
  cpu cpu(.clk(clk), .reset(reset), .AB(ab), .DI(din), .DO(dout), .WE(we),
          .IRQ(1'b0), .NMI(1'b0), .RDY(en));

  // ---- memory map
  wire ram_sel, pia_sel, rom_sel;
  decode dec(.addr(ab), .ram_sel(ram_sel), .pia_sel(pia_sel), .rom_sel(rom_sel));

  reg [7:0] ram [0:8191];
  reg [7:0] ram_q = 0;
  always @(posedge clk) begin
    if (en && we && ram_sel) ram[ab[12:0]] <= dout;
    ram_q <= ram[ab[12:0]];
  end

  reg [7:0] rom [0:255];
${PLACEHOLDER}
  reg [7:0] rom_q = 0;
  always @(posedge clk) rom_q <= rom[ab[7:0]];

  // ---- keyboard and display
  wire [7:0] key;
  wire key_valid, disp_busy, char_send;
  wire [6:0] char;
  wire [7:0] pia_q;
  keyboard kb(.clk(clk), .RX(RX), .key(key), .valid(key_valid));
  pia pia(.clk(clk), .en(en), .sel(pia_sel), .addr(ab[1:0]), .we(we), .di(dout), .dout(pia_q),
          .key(key), .key_valid(key_valid), .char(char), .char_send(char_send), .char_busy(disp_busy));
  display disp(.clk(clk), .char(char), .send(char_send), .busy(disp_busy), .TX(TX));

  // ---- read data: the RAMs answer a clock after the address, so the
  // choice of which one to listen to has to be a clock late too
  reg ram_r = 0, pia_r = 0, rom_r = 0;
  always @(posedge clk) if (en) begin ram_r <= ram_sel; pia_r <= pia_sel; rom_r <= rom_sel; end
  always @(*) begin
    if (ram_r)      din = ram_q;
    else if (pia_r) din = pia_q;
    else if (rom_r) din = rom_q;
    else            din = 8'hff;
  end

  assign LED = !reset;
endmodule`;

// --- test helpers: put machine code in ROM, type, read the display ---
function loadRom(t, bytes) {
  const rom = t.sim.peekMem('rom');
  if (!rom) t.fail('The tests need a 256-byte memory called "rom": reg [7:0] rom [0:255];');
  rom.data.fill(0);
  for (const [addr, list] of bytes) list.forEach((v, i) => { const a = (addr + i) & 255; for (let b = 0; b < 8; b++) rom.data[a * 8 + b] = (v >> b) & 1; });
}
function serialIO(t, text, nChars, maxCycles) {
  // feeds `text` into RX (at 104 clocks/bit) while collecting nChars from TX
  const cpb = 104;
  let rxBits = [], out = '', state = 'idle', cnt = 0, bit = 0, byte = 0;
  for (const ch of text) rxBits.push(...[0, ...Array.from({ length: 8 }, (_, i) => (ch.charCodeAt(0) >> i) & 1), 1, 1, 1].flatMap(b => Array(cpb).fill(b)));
  t.sim.set('RX', 1);
  for (let i = 0; i < maxCycles && out.length < nChars; i++) {
    if (i < rxBits.length) t.sim.set('RX', rxBits[i]); else if (i === rxBits.length) t.sim.set('RX', 1);
    t.sim.tick('clk');
    const x = t.sim.get('TX');
    if (state === 'idle') { if (!x) { state = 'start'; cnt = cpb >> 1; } }
    else if (--cnt <= 0) {
      if (state === 'start') { state = 'data'; bit = 0; byte = 0; cnt = cpb; }
      else if (state === 'data') { byte |= x << bit++; cnt = cpb; if (bit === 8) state = 'stop'; }
      else { out += String.fromCharCode(byte); state = 'idle'; }
    }
  }
  return out;
}
// Like the Woz Monitor, set up the PIA (DSPCR = $A7) first, then jump to the program at $FF00.
const RESET_VECTOR = [0x40, [0xa9, 0xa7, 0x8d, 0x13, 0xd0, 0x8d, 0x11, 0xd0, 0x4c, 0x00, 0xff]];
const VEC = [0xfc, [0x40, 0xff]];
// Prints "HI" and a carriage return through the display register.
const PROG_HI = [[0x00, [0xa2, 0x00, 0xbd, 0x20, 0xff, 0xf0, 0x0c, 0x2c, 0x12, 0xd0, 0x30, 0xfb, 0x8d, 0x12, 0xd0, 0xe8, 0xd0, 0xf0, 0xea, 0x4c, 0x13, 0xff]],
  [0x20, [0xc8, 0xc9, 0x8d, 0x00]], RESET_VECTOR, VEC];
// Echoes every key back.
const PROG_ECHO = [[0x00, [0xad, 0x11, 0xd0, 0x10, 0xfb, 0xad, 0x10, 0xd0, 0x2c, 0x12, 0xd0, 0x30, 0xfb, 0x8d, 0x12, 0xd0, 0x4c, 0x00, 0xff]], RESET_VECTOR, VEC];
// Stores two letters at both ends of RAM, prints them back through a subroutine (which needs the stack in RAM).
const PROG_RAM = [[0x00, [0xa2, 0xff, 0x9a, 0xa9, 0xc1, 0x8d, 0x00, 0x03, 0xa9, 0xc2, 0x8d, 0xff, 0x1f, 0xad, 0x00, 0x03, 0x20, 0x30, 0xff, 0xad, 0xff, 0x1f, 0x20, 0x30, 0xff, 0x4c, 0x19, 0xff]],
  [0x30, [0x2c, 0x12, 0xd0, 0x30, 0xfb, 0x8d, 0x12, 0xd0, 0x60]], RESET_VECTOR, VEC];

export default [
  {
    id: 'decode',
    title: 'The memory map',
    prompt: 'Decode a 16-bit address: RAM at `$0000`–`$1FFF`, the PIA at `$D010`–`$D01F`, the ROM at `$FF00`–`$FFFF`. Nothing else is selected.',
    starter: `module decode(
  input  [15:0] addr,
  output        ram_sel,
  output        pia_sel,
  output        rom_sel
);
  assign ram_sel = 0;
  assign pia_sel = 0;
  assign rom_sel = 0;
endmodule
`,
    solution: DECODE,
    top: 'decode',
    tests: [{ name: 'every one of the 65,536 addresses', run(t) {
      t.table(['addr'], ['ram_sel', 'pia_sel', 'rom_sel'], e => ({ ram_sel: +(e.addr < 0x2000), pia_sel: +(e.addr >= 0xd010 && e.addr <= 0xd01f), rom_sel: +(e.addr >= 0xff00) }),
        { max: 65536, describe: e => `addr = $${e.addr.toString(16).toUpperCase().padStart(4, '0')}` });
    } }],
  },
  {
    id: 'pia',
    title: 'Keyboard and display registers',
    prompt: 'The four registers of the Apple I\'s 6821 PIA, as the Woz Monitor uses them. Reads land in `dout` on the clock after `en && sel`, like a block RAM.',
    starter: `module pia(
  input            clk,
  input            en,
  input            sel,
  input      [1:0] addr,
  input            we,
  input      [7:0] di,
  output reg [7:0] dout = 0,
  input      [7:0] key,
  input            key_valid,
  output reg [6:0] char = 0,
  output reg       char_send = 0,
  input            char_busy
);
  reg [6:0] kbd = 0;
  reg       kbd_ready = 0;
  reg [5:0] kbdcr = 0, dspcr = 0;

  always @(posedge clk) begin
    char_send <= 0;
    // remember keys; answer reads of the four registers;
    // writes to KBDCR and DSPCR; writes to DSP go to the display only if dspcr[2]
  end
endmodule
`,
    solution: PIA,
    top: 'pia',
    waves: ['clk', 'en', 'sel', 'addr', 'we', 'di', 'dout', 'key_valid', 'char_send', 'char'],
    tests: [
      { name: 'a key sets KBDCR bit 7; reading KBD returns it with bit 7 set and clears the flag', run(t) {
        const rd = a => { t.set('en', 1); t.set('sel', 1); t.set('we', 0); t.set('addr', a); t.tick(1); t.set('en', 0); t.set('sel', 0); return t.get('dout'); };
        t.ok((rd(1) & 0x80) === 0, 'KBDCR bit 7 should be 0 before any key arrives.');
        t.set('key', 0x41); t.set('key_valid', 1); t.tick(1); t.set('key_valid', 0); t.tick(3);
        t.ok((rd(1) & 0x80) !== 0, 'After a key arrives, KBDCR bit 7 should be 1.');
        const k = rd(0);
        t.ok(k === 0xc1, `Reading KBD should give the key with bit 7 set: 0xc1 for "A". Got 0x${k.toString(16)}.`);
        t.ok((rd(1) & 0x80) === 0, 'Reading KBD should clear KBDCR bit 7.');
      } },
      { name: 'before DSPCR is set up, writes to DSP go to the direction register', run(t) {
        t.set('char_busy', 0);
        t.set('en', 1); t.set('sel', 1); t.set('we', 1); t.set('addr', 2); t.set('di', 0x7f); t.tick(1);
        t.set('en', 0); t.set('sel', 0); t.set('we', 0);
        t.eq('char_send', 0, 'after writing $7F to DSP with DSPCR still 0 (the Woz Monitor does exactly this at reset)');
      } },
      { name: 'writing DSP sends a character; DSP bit 7 says busy', run(t) {
        t.set('char_busy', 0);
        t.set('en', 1); t.set('sel', 1); t.set('we', 1); t.set('addr', 3); t.set('di', 0xa7); t.tick(1);
        t.set('addr', 2); t.set('di', 0xc8); t.tick(1);
        t.set('en', 0); t.set('sel', 0); t.set('we', 0);
        t.eq('char_send', 1, 'on the clock after a write to DSP');
        t.eq('char', 0x48, 'after writing 0xc8 ("H" with bit 7 set): the display gets the low 7 bits');
        t.tick(1); t.eq('char_send', 0, 'one clock later (it should be a single pulse)');
        t.set('char_busy', 1);
        t.set('en', 1); t.set('sel', 1); t.set('addr', 2); t.tick(1); t.set('en', 0); t.set('sel', 0);
        t.ok((t.get('dout') & 0x80) !== 0, 'Reading DSP while the display is busy should return bit 7 = 1.');
      } },
      { name: 'nothing happens without en', run(t) {
        t.set('key', 0x42); t.set('key_valid', 1); t.tick(1); t.set('key_valid', 0);
        t.set('en', 1); t.set('sel', 1); t.set('we', 1); t.set('addr', 3); t.set('di', 0xa7); t.tick(1);
        t.set('en', 0); t.set('addr', 2); t.set('di', 0xc1); t.tick(3);
        t.set('we', 0); t.set('addr', 0); t.tick(3); t.set('sel', 0);
        t.eq('char_send', 0, 'when sel and we were high but en was not');
        t.set('en', 1); t.set('sel', 1); t.set('addr', 1); t.tick(1); t.set('en', 0); t.set('sel', 0);
        t.ok((t.get('dout') & 0x80) !== 0, 'A read of KBD without en shouldn\'t have taken the key.');
      } },
    ],
  },
  {
    id: 'apple1',
    project: true,
    title: 'An Apple I',
    prompt: 'Put the 6502, RAM, ROM, decoder and PIA together. The tests run their own small 6502 programs from your ROM; for the real thing, load the Woz Monitor with the ROM tool below. The core is included for you as `cpu`.',
    libs: ['6502'],
    starter: `${DECODE}

${PIA}

${SERIAL}

module top(
  input  clk,
  input  BTN,      // RESET
  input  RX,
  output TX,
  output LED
);
  parameter CPU_DIV = 12;      // 12 MHz / 12 = 1 MHz

  // reset, clock enable, cpu, memory map, RAM, ROM, keyboard, PIA, display,
  // and the read-data mux. The 6502 is:
  //   cpu cpu(.clk(clk), .reset(reset), .AB(ab), .DI(din), .DO(dout), .WE(we),
  //           .IRQ(1'b0), .NMI(1'b0), .RDY(en));

  reg [7:0] rom [0:255];
${PLACEHOLDER}

  assign TX = 1;
  assign LED = 0;
endmodule
`,
    solution: `${DECODE}

${PIA}

${SERIAL}

${TOP_SOL}
`,
    board: [{ type: 'button', port: 'BTN', label: 'RESET', activeLow: true }, { type: 'led', port: 'LED', label: 'running' }, { type: 'uart', tx: 'TX', rx: 'RX', baud: 115200 }],
    clock,
    simParams: { CPU_DIV: 1 },
    testParams: { CPU_DIV: 1 },
    gates: false,
    tests: [
      { name: 'prints through the display register', run(t) {
        t.set('BTN', 1); loadRom(t, PROG_HI);
        const out = serialIO(t, '', 4, 40000);
        t.ok(out === 'HI\r\n', `A program that writes "HI" and a carriage return to $D012 should print "HI\\r\\n". Got ${JSON.stringify(out)}.`);
      } },
      { name: 'reads the keyboard', run(t) {
        t.set('BTN', 1); loadRom(t, PROG_ECHO);
        const out = serialIO(t, 'ok\r', 4, 60000);
        t.ok(out === 'OK\r\n', `An echo program, given "ok" and Enter, should print "OK\\r\\n" (the Apple I keyboard was upper case only). Got ${JSON.stringify(out)}.`);
      } },
      { name: 'RAM and the stack work', run(t) {
        t.set('BTN', 1); loadRom(t, PROG_RAM);
        const out = serialIO(t, '', 2, 40000);
        t.ok(out === 'AB', `A program that stores to $0300 and $1FFF and prints them back through a subroutine should print "AB". Got ${JSON.stringify(out)}.`);
      } },
      { name: 'BTN resets the computer', run(t) {
        t.set('BTN', 1); loadRom(t, PROG_HI);
        serialIO(t, '', 4, 40000);
        t.set('BTN', 0); t.tick(20); t.set('BTN', 1);
        const out = serialIO(t, '', 4, 40000);
        t.ok(out === 'HI\r\n', `After pressing reset the program should run again from the start and print "HI\\r\\n". Got ${JSON.stringify(out)}.`);
      } },
    ],
  },
];
