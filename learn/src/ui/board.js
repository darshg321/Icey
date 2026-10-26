// The virtual board: buttons, switches, LEDs, a 7-segment display, an RGB
// LED, a serial terminal and a VGA monitor, all wired to ports of the
// learner's top module and driven by the gate-level simulator.

const h = (tag, attrs = {}, ...kids) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (v !== undefined && v !== null && v !== false) el.setAttribute(k, v === true ? '' : v);
  }
  for (const kid of kids.flat()) if (kid !== null && kid !== undefined) el.append(kid);
  return el;
};

// Segment layout in a 40x70 box. seg[0] = a ... seg[6] = g.
const SEGS = [
  'M8,4 L32,4 L28,10 L12,10 Z', // a
  'M34,6 L34,33 L29,30 L29,11 Z', // b
  'M34,37 L34,64 L29,59 L29,40 Z', // c
  'M8,66 L32,66 L28,60 L12,60 Z', // d
  'M6,37 L6,64 L11,59 L11,40 Z', // e
  'M6,6 L6,33 L11,30 L11,11 Z', // f
  'M8,35 L12,31 L28,31 L32,35 L28,39 L12,39 Z', // g
];

export class Board {
  constructor(root, parts = [], { clockPort = 'clk', clockHz = 12e6 } = {}) {
    this.root = root;
    this.parts = parts;
    this.clockPort = clockPort;
    this.clockHz = clockHz;
    this.sim = null;
    this.inputs = {}; // port -> value driven by the UI
    this.outputs = []; // {port, bits:[], acc:Float32Array, el...}
    this.hooks = [];
    this.running = false;
    this.paused = false;
    this.speedEl = null;
    this.render();
  }

  render() {
    this.root.innerHTML = '';
    this.root.classList.add('board');
    this.outputs = [];
    this.renderers = [];
    this.attachHooks = [];
    const area = h('div', { class: 'board-parts' });
    for (const p of this.parts) {
      const el = this[`part_${p.type}`] ? this[`part_${p.type}`](p) : h('div', {}, `unknown part ${p.type}`);
      area.append(el);
    }
    this.speedEl = h('span', { class: 'board-speed' }, 'not running');
    this.pauseBtn = h('button', { class: 'tiny', onclick: () => this.togglePause(), title: 'Pause the clock' }, 'pause');
    this.stepBtn = h('button', { class: 'tiny', onclick: () => this.step(), title: 'One clock cycle' }, 'step');
    this.resetBtn = h('button', { class: 'tiny', onclick: () => this.onReset && this.onReset(), title: 'Power-cycle the board' }, 'reset');
    const status = h('div', { class: 'board-status' }, this.speedEl, h('span', { class: 'spacer' }), this.stepBtn, this.pauseBtn, this.resetBtn);
    this.root.append(area, status);
    this.updateControls();
  }

  updateControls() {
    const clocked = !!(this.sim && this.sim.has(this.clockPort));
    this.pauseBtn.style.display = clocked ? '' : 'none';
    this.stepBtn.style.display = clocked && this.paused ? '' : 'none';
    this.pauseBtn.textContent = this.paused ? 'run' : 'pause';
  }

  // --- parts ---
  addOutput(port, opts, draw) {
    const o = { port, opts, draw, acc: null, n: 0 };
    this.outputs.push(o);
    return o;
  }

  part_led(p) {
    const lamp = h('div', { class: 'led', style: { '--c': p.color || '#3dff6e' } });
    this.addOutput(p.port, p, (o, lvl) => lamp.style.setProperty('--b', p.activeLow ? 1 - lvl[0] : lvl[0]));
    return h('div', { class: 'part' }, lamp, h('label', {}, p.label || p.port));
  }

  part_leds(p) {
    const wrap = h('div', { class: 'leds' });
    const lamps = [];
    const o = this.addOutput(p.port, p, (o, lvl) => {
      if (lamps.length !== lvl.length) {
        wrap.innerHTML = '';
        lamps.length = 0;
        for (let i = lvl.length - 1; i >= 0; i--) {
          const l = h('div', { class: 'led', style: { '--c': p.color || '#3dff6e' } });
          lamps[i] = l;
          wrap.append(h('div', { class: 'ledcell' }, l, h('small', {}, String(i))));
        }
      }
      lvl.forEach((x, i) => lamps[i].style.setProperty('--b', p.activeLow ? 1 - x : x));
    });
    return h('div', { class: 'part' }, wrap, h('label', {}, `${p.label || p.port}`));
  }

  part_rgb(p) {
    const lamp = h('div', { class: 'rgb' });
    const lv = { r: 0, g: 0, b: 0 };
    const paint = () => {
      const f = x => Math.round(255 * Math.min(1, x));
      lamp.style.background = `rgb(${f(lv.r)},${f(lv.g)},${f(lv.b)})`;
      lamp.style.boxShadow = `0 0 ${8 + 20 * Math.max(lv.r, lv.g, lv.b)}px rgb(${f(lv.r)},${f(lv.g)},${f(lv.b)})`;
    };
    for (const c of ['r', 'g', 'b']) {
      if (!p.ports[c]) continue;
      this.addOutput(p.ports[c], p, (o, lvl) => { lv[c] = p.activeLow ? 1 - lvl[0] : lvl[0]; paint(); });
    }
    return h('div', { class: 'part' }, lamp, h('label', {}, p.label || 'RGB'));
  }

  part_seg7(p) {
    const ports = p.ports || [p.port];
    const digits = h('div', { class: 'seg7' });
    for (const port of ports) {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 40 70');
      const paths = SEGS.map(d => {
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', d);
        svg.append(path);
        return path;
      });
      digits.append(svg);
      this.addOutput(port, p, (o, lvl) => lvl.forEach((x, i) => {
        if (paths[i]) paths[i].style.setProperty('--b', p.activeLow ? 1 - x : x);
      }));
    }
    return h('div', { class: 'part' }, digits, h('label', {}, p.label || ports.join(' ')));
  }

  part_matrix(p) {
    // An LED matrix; bit (r * cols + c) of the port is row r, column c.
    const rows = p.rows || 8, cols = p.cols || 8;
    const grid = h('div', { class: 'matrix', style: { gridTemplateColumns: `repeat(${cols}, 1fr)` } });
    const dots = [];
    for (let i = 0; i < rows * cols; i++) { const d = h('i', { style: { '--c': p.color || '#ff4a3d' } }); dots.push(d); grid.append(d); }
    this.addOutput(p.port, p, (o, lvl) => lvl.forEach((x, i) => { if (dots[i]) dots[i].style.setProperty('--b', x); }));
    return h('div', { class: 'part' }, grid, h('label', {}, p.label || p.port));
  }

  // A W25Q128 flash chip on an SPI bus: answers 0x9F (JEDEC ID: ef 40 18)
  // and 0x03 (read data) with the bytes in p.data.
  part_spiflash(p) {
    const note = h('div', { class: 'small', style: { color: '#fffd', fontFamily: 'var(--mono)' } }, 'idle');
    const data = new TextEncoder().encode(p.data || 'Hello from the flash chip!');
    this.hooks.push({
      kind: 'spiflash',
      setup: sim => {
        const bit = n => (sim.has(n) ? sim.signals[n].bits[0] : -1);
        const sck = bit(p.sck), cs = bit(p.cs), mosi = bit(p.mosi);
        if (sck < 0 || cs < 0 || mosi < 0 || !sim.has(p.miso)) { note.textContent = 'not connected'; return () => {}; }
        const v = sim.v;
        let lastSck = 0, lastCs = 1, inByte = 0, nbits = 0, bytes = [], out = 0xff, outBits = 0, addr = 0;
        const nextOut = () => {
          const cmd = bytes[0];
          const k = bytes.length;
          if (cmd === 0x9f) return [0xef, 0x40, 0x18][k - 1] ?? 0xff;
          if (cmd === 0x03 && k >= 4) return data[(addr + k - 4) % data.length] ?? 0xff;
          return 0xff;
        };
        return () => {
          const c = v[cs], k = v[sck];
          if (c === 1) {
            if (lastCs === 0 && bytes.length) note.textContent = `last command: ${bytes.slice(0, 6).map(b => b.toString(16).padStart(2, '0')).join(' ')}${bytes.length > 6 ? ' …' : ''}`;
            nbits = 0; bytes = []; inByte = 0; outBits = 0;
          } else {
            if (lastSck === 0 && k === 1) { // rising edge: sample MOSI
              inByte = ((inByte << 1) | v[mosi]) & 255;
              if (++nbits === 8) {
                bytes.push(inByte); nbits = 0;
                if (bytes[0] === 0x03 && bytes.length === 4) addr = (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
                out = nextOut(); outBits = 0;
              }
            }
            if (lastSck === 1 && k === 0 && bytes.length) { // falling edge: shift out the next bit
              sim.set(p.miso, (out >> (7 - outBits)) & 1);
              outBits = Math.min(outBits + 1, 7);
            }
          }
          lastSck = k; lastCs = c;
        };
      },
    });
    return h('div', { class: 'part' }, h('div', { class: 'flashchip' }, 'W25Q128'), note, h('label', {}, 'SPI flash'));
  }

  part_value(p) {
    const out = h('code', { class: 'probe' }, '–');
    this.addOutput(p.port, { ...p, raw: true }, (o, lvl, val) => {
      const w = lvl.length;
      out.textContent = p.format === 'hex' ? '0x' + val.toString(16).padStart(Math.ceil(w / 4), '0')
        : p.format === 'bin' ? val.toString(2).padStart(w, '0') : String(val);
    });
    return h('div', { class: 'part' }, out, h('label', {}, p.label || p.port));
  }

  part_button(p) {
    // `bit` lets several buttons share one bus port, e.g. btn[3:0].
    const shift = p.bit ?? 0;
    const press = down => {
      const b = p.activeLow ? (down ? 0 : 1) : (down ? 1 : 0);
      const cur = this.inputs[p.port] ?? 0;
      const v = (cur & ~(1 << shift)) | (b << shift);
      if (p.bounce && this.sim && this.sim.has(this.clockPort)) this.bounce(p.port, v, v ^ (1 << shift));
      else this.setInput(p.port, v);
      btn.classList.toggle('down', down);
    };
    const btn = h('button', {
      class: 'pushbutton',
      onpointerdown: e => { e.preventDefault(); btn.setPointerCapture(e.pointerId); press(true); },
      onpointerup: () => press(false),
      onpointercancel: () => press(false),
    });
    this.inputs[p.port] = (this.inputs[p.port] ?? 0) | ((p.activeLow ? 1 : 0) << shift);
    if (p.key) {
      this.keys = this.keys || {};
      this.keys[p.key] = press;
    }
    return h('div', { class: 'part' }, btn, h('label', {}, p.label || p.port, p.key ? h('kbd', {}, p.key === ' ' ? 'space' : p.key) : null));
  }

  part_switches(p) {
    const wrap = h('div', { class: 'switches' });
    const width = p.width || 1;
    let value = p.initial || 0;
    this.inputs[p.port] = value;
    for (let i = width - 1; i >= 0; i--) {
      const sw = h('button', { class: 'switch' + ((value >> i) & 1 ? ' on' : ''), title: `${p.port}[${i}]` });
      sw.onclick = () => {
        value ^= 1 << i;
        sw.classList.toggle('on', !!((value >> i) & 1));
        this.setInput(p.port, value);
      };
      wrap.append(h('div', { class: 'swcell' }, sw, h('small', {}, String(i))));
    }
    return h('div', { class: 'part' }, wrap, h('label', {}, p.label || p.port));
  }

  part_uart(p) {
    const screen = h('pre', { class: 'terminal', tabindex: 0 });
    const input = h('input', { class: 'terminal-in', placeholder: p.rx ? 'type here, Enter sends' : 'receive only', disabled: !p.rx });
    screen.textContent = '';
    const st = { state: 'idle', count: 0, bit: 0, byte: 0, txq: [], txState: null };
    this.uart = { p, st, screen };
    input.addEventListener('keydown', e => {
      if (e.key === 'Enter') {
        for (const ch of input.value + (p.newline ?? '\r')) st.txq.push(ch.charCodeAt(0) & 0xff);
        input.value = '';
        e.preventDefault();
      }
    });
    const write = byte => {
      if (byte === 13) return;
      if (byte === 8 || byte === 127) { screen.textContent = screen.textContent.slice(0, -1); return; }
      screen.textContent += byte === 10 || byte >= 32 && byte < 127 ? String.fromCharCode(byte) : `\\x${byte.toString(16).padStart(2, '0')}`;
      if (screen.textContent.length > 20000) screen.textContent = screen.textContent.slice(-15000);
      screen.scrollTop = screen.scrollHeight;
    };
    this.hooks.push({
      kind: 'uart',
      setup: sim => {
        const cpb = Math.round(this.clockHz / (p.baud || 115200));
        const tx = sim.has(p.tx) ? sim.signals[p.tx].bits[0] : -1;
        const rx = p.rx && sim.has(p.rx) ? p.rx : null;
        if (rx) sim.set(rx, 1);
        const v = sim.v;
        let rxBits = null, rxCount = 0;
        return () => {
          if (tx >= 0) {
            const x = v[tx];
            if (st.state === 'idle') { if (x === 0) { st.state = 'start'; st.count = cpb >> 1; } }
            else if (--st.count <= 0) {
              if (st.state === 'start') {
                if (x === 0) { st.state = 'data'; st.bit = 0; st.byte = 0; st.count = cpb; } else st.state = 'idle';
              } else if (st.state === 'data') {
                st.byte |= x << st.bit++;
                st.count = cpb;
                if (st.bit === 8) st.state = 'stop';
              } else { write(st.byte); st.state = 'idle'; }
            }
          }
          if (rx) {
            if (!rxBits && st.txq.length) {
              const b = st.txq.shift();
              rxBits = [0, ...Array.from({ length: 8 }, (_, i) => (b >> i) & 1), 1];
              rxCount = 0;
            }
            if (rxBits) {
              const idx = Math.floor(rxCount / cpb);
              if (idx >= rxBits.length) { rxBits = null; sim.set(rx, 1); } else if (rxCount % cpb === 0) sim.set(rx, rxBits[idx]);
              rxCount++;
            }
          }
        };
      },
    });
    // Optionally talk to a real Icey instead (FT2232H channel B), via WebSerial.
    const real = navigator.serial ? h('button', { class: 'tiny', title: 'Use the serial port of a real Icey (Chrome/Edge)' }, 'connect a real Icey') : null;
    if (real) {
      real.onclick = async () => {
        if (this.serial) { await this.serial.close(); return; }
        try {
          const port = await navigator.serial.requestPort({ filters: [{ usbVendorId: 0x0403, usbProductId: 0x6010 }] });
          await port.open({ baudRate: p.baud || 115200 });
          const reader = port.readable.getReader();
          const writer = port.writable.getWriter();
          this.serial = {
            async close() { try { await reader.cancel(); reader.releaseLock(); writer.releaseLock(); await port.close(); } catch {} },
          };
          this.serialWrite = bytes => writer.write(new Uint8Array(bytes));
          real.textContent = 'disconnect (real Icey)';
          screen.textContent += '\n[connected to the real board. If nothing arrives, pick the other of the two serial ports: Icey has two, and the UART is the second.]\n';
          (async () => {
            try {
              for (;;) {
                const { value, done } = await reader.read();
                if (done) break;
                for (const b of value) write(b);
              }
            } catch {}
            this.serial = null; this.serialWrite = null;
            real.textContent = 'connect a real Icey';
            screen.textContent += '\n[disconnected]\n';
          })();
        } catch (e) {
          screen.textContent += `\n[${e.message}]\n`;
        }
      };
    }
    input.addEventListener('keydown', e => {
      if (e.key === 'Enter' && this.serialWrite) {
        // Typed text goes to the real board too while it's connected.
        this.serialWrite([...st.txq.splice(0)]);
      }
    });
    return h('div', { class: 'part wide' }, screen, input, h('label', {}, `serial ${p.baud || 115200} baud`, h('button', { class: 'tiny', onclick: () => { screen.textContent = ''; } }, 'clear'), real));
  }

  part_vga(p) {
    const canvas = h('canvas', { class: 'vga', width: 640, height: 480 });
    const ctx = canvas.getContext('2d');
    const img = ctx.createImageData(640, 480);
    const note = h('div', { class: 'vga-note' }, 'NO SIGNAL');
    const T = p.timing || { hfront: 16, hsync: 96, hback: 48, vfront: 10, vsync: 2, vback: 33, w: 640, h: 480 };
    const lineLen = T.w + T.hfront + T.hsync + T.hback;
    this.hooks.push({
      kind: 'vga',
      setup: sim => {
        const b = n => (n && sim.has(n) ? sim.signals[n].bits : []);
        const hs = b(p.hsync)[0], vs = b(p.vsync)[0];
        const R = b(p.r), G = b(p.g), B = b(p.b);
        const lut = bits => { const n = bits.length; return n ? 255 / (2 ** n - 1) : 0; };
        const kr = lut(R), kg = lut(G), kb = lut(B);
        const v = sim.v, data = img.data;
        let x = 0, y = 0, lastH = 1, lastV = 1, sinceV = 0, lineCycles = 0, measuredLine = 0;
        let frames = 0;
        if (hs === undefined || vs === undefined) { note.textContent = 'NO SIGNAL (no hsync/vsync port)'; return () => {}; }
        return () => {
          const H = v[hs], V = v[vs];
          lineCycles++;
          if (lastH === 1 && H === 0) { // start of hsync pulse
            measuredLine = lineCycles; lineCycles = 0;
            x = -(T.hsync + T.hback); y++;
          }
          if (lastV === 1 && V === 0) { // start of vsync pulse
            y = -(T.vsync + T.vback);
            ctx.putImageData(img, 0, 0);
            frames++;
            sinceV = 0;
            const ok = Math.abs(measuredLine - lineLen) <= 2;
            note.textContent = ok ? '' : measuredLine ? `OUT OF RANGE: lines are ${measuredLine} clocks, the monitor expects ${lineLen}` : 'NO SIGNAL';
          }
          lastH = H; lastV = V;
          if (x >= 0 && x < T.w && y >= 0 && y < T.h) {
            let r = 0, g = 0, bb = 0;
            for (let i = 0; i < R.length; i++) r |= v[R[i]] << i;
            for (let i = 0; i < G.length; i++) g |= v[G[i]] << i;
            for (let i = 0; i < B.length; i++) bb |= v[B[i]] << i;
            const o = (y * T.w + x) * 4;
            data[o] = r * kr; data[o + 1] = g * kg; data[o + 2] = bb * kb; data[o + 3] = 255;
          }
          x++;
          if (++sinceV > lineLen * 600 && frames >= 0) { note.textContent = 'NO SIGNAL'; sinceV = 0; }
        };
      },
    });
    return h('div', { class: 'part wide vga-wrap' }, canvas, note, h('label', {}, 'VGA monitor (640×480)'));
  }

  // Icey itself, from above (a photo of the real board, perspective-corrected
  // against the mounting holes so PCB coordinates land on the right parts),
  // with its parts wired to the board's pin names: LED, RGB0/1/2 (active low),
  // BTN (SW2, active low), RESET (SW3) and header pins P1..P9, which become
  // switches when they're inputs of the design and light up when they're outputs.
  part_icey(p) {
    // The photo is 24 px/mm and spans 70.667 x 64.833 mm, from 1 mm left of and above the PCB corner (119.3, 80.6).
    const at = (X, Y, el) => {
      el.style.left = `${100 * (X - 118.3) / 70.667}%`;
      el.style.top = `${100 * (Y - 79.6) / 64.833}%`;
      return el;
    };
    const glow = (X, Y, c, cls = '') => at(X, Y, h('div', { class: `icey-glow ${cls}`, style: { '--c': c } }));
    const pcb = h('div', { class: 'icey-pcb' }, h('img', { src: `${import.meta.env.BASE_URL}img/icey-photo.webp`, alt: 'Icey, top view', draggable: 'false' }));

    const led1 = glow(155, 82.98, '#ff2a1a');
    this.addOutput(p.led || 'LED', { optional: true }, (o, lvl) => led1.style.setProperty('--b', lvl[0]));

    // LED2 sits on CDONE: lit while the FPGA has no design in it.
    const led2 = glow(136.95, 87.85, '#ff2a1a');
    led2.style.setProperty('--b', 1);
    this.attachHooks.push(() => led2.style.setProperty('--b', 0));

    const rgb = glow(135.08, 114.01, '#000', 'big');
    const lv = { r: 0, g: 0, b: 0 };
    const paint = () => {
      const f = x => Math.round(255 * Math.min(1, x));
      const m = Math.max(lv.r, lv.g, lv.b);
      rgb.style.setProperty('--c', `rgb(${f(lv.r / (m || 1))},${f(lv.g / (m || 1))},${f(lv.b / (m || 1))})`);
      rgb.style.setProperty('--b', m);
    };
    const rgbPorts = p.rgb || { r: 'RGB0', g: 'RGB2', b: 'RGB1' };
    for (const c of ['r', 'g', 'b']) this.addOutput(rgbPorts[c], { optional: true }, (o, lvl) => { lv[c] = 1 - lvl[0]; paint(); });

    const btnPort = p.btn || 'BTN';
    this.inputs[btnPort] = 1;
    const sw2 = at(146.25, 84.5, h('button', { class: 'icey-btn', title: 'SW2 (BTN, active low). Space bar works too.' }));
    const press = down => { sw2.classList.toggle('down', down); if (p.bounce && this.sim?.has(this.clockPort)) this.bounce(btnPort, down ? 0 : 1, down ? 1 : 0); else this.setInput(btnPort, down ? 0 : 1); };
    sw2.onpointerdown = e => { e.preventDefault(); sw2.setPointerCapture(e.pointerId); press(true); };
    sw2.onpointerup = sw2.onpointercancel = () => press(false);
    this.keys = this.keys || {};
    this.keys[' '] = press;
    const sw3 = at(141.25, 84.5, h('button', { class: 'icey-btn', title: 'SW3 (reset): power-cycles the design' }));
    sw3.onclick = () => this.onReset && this.onReset();
    pcb.append(led1, led2, rgb, sw2, sw3);

    // Header J1: pin n is 2.54 mm below pin n-1.
    for (let n = 1; n <= 9; n++) {
      const port = `P${n}`;
      const pin = at(121.3, 90 + 2.54 * (n - 1), h('button', { class: 'icey-pin', title: port, disabled: true }));
      this.inputs[port] = 0;
      pin.onclick = () => { const v = this.inputs[port] ? 0 : 1; pin.classList.toggle('high', !!v); this.setInput(port, v); };
      this.addOutput(port, { optional: true }, (o, lvl) => pin.style.setProperty('--b', lvl[0]));
      this.attachHooks.push(sim => {
        const dir = sim.ports[port]?.dir;
        pin.className = `icey-pin ${dir === 'input' ? 'in' : dir === 'output' ? 'out' : ''} ${dir === 'input' && this.inputs[port] ? 'high' : ''}`;
        pin.disabled = dir !== 'input';
        pin.title = dir === 'input' ? `${port}: click to toggle (input)` : dir === 'output' ? `${port}: output` : `${port}: not used`;
      });
      pcb.append(pin);
    }
    return h('div', { class: 'part wide' }, pcb, h('label', {}, 'SW2: click or hold space · header pins with a ring are inputs: click to toggle'));
  }

  // --- simulation driving ---
  setInput(port, value) {
    this.inputs[port] = value;
    if (this.sim && this.sim.has(port)) {
      this.sim.set(port, value);
      if (!this.sim.has(this.clockPort) || this.paused) { this.sim.settle(); this.draw(true); }
    }
  }

  bounce(port, final, other) {
    // A real contact chatters for a few milliseconds before it settles.
    const cycles = Math.round(this.clockHz * 0.004);
    const flips = [];
    let t = 0;
    while (t < cycles) { t += Math.round(Math.random() * cycles / 6) + 1; flips.push(t); }
    this.bouncing = { port, final, other, start: this.sim.cycles, flips, i: 0 };
    this.inputs[port] = final;
  }

  attach(sim) {
    this.stop();
    this.sim = sim;
    this.paused = false;
    for (const [port, v] of Object.entries(this.inputs)) if (sim.has(port)) sim.set(port, v);
    sim.settle();
    this.activeHooks = this.hooks.map(hk => hk.setup(sim));
    for (const o of this.outputs) {
      o.bits = sim.has(o.port) ? sim.signals[o.port].bits : [];
      o.acc = new Float32Array(o.bits.length);
      o.n = 0;
    }
    for (const fn of this.attachHooks) fn(sim);
    this.missing = this.outputs.filter(o => !o.opts.optional && !sim.has(o.port)).map(o => o.port)
      .concat(this.parts.filter(p => ['button', 'switches'].includes(p.type) && !sim.has(p.port)).map(p => p.port));
    this.running = true;
    this.updateControls();
    this.lastFrame = performance.now();
    this.speedEl.textContent = sim.has(this.clockPort) ? 'starting…' : 'no clock: pure logic';
    this.frame = requestAnimationFrame(() => this.loop());
    if (!this.keyHandler && this.keys) {
      this.keyHandler = e => {
        if (!this.running || /INPUT|TEXTAREA/.test(document.activeElement?.tagName) || document.activeElement?.closest('.cm-editor')) return;
        const fn = this.keys[e.key];
        if (fn && !e.repeat) { fn(e.type === 'keydown'); e.preventDefault(); }
      };
      window.addEventListener('keydown', this.keyHandler);
      window.addEventListener('keyup', this.keyHandler);
    }
  }

  stop() {
    this.running = false;
    cancelAnimationFrame(this.frame);
  }

  destroy() {
    this.stop();
    if (this.keyHandler) { window.removeEventListener('keydown', this.keyHandler); window.removeEventListener('keyup', this.keyHandler); }
  }

  togglePause() { this.paused = !this.paused; this.updateControls(); }

  step() {
    if (!this.sim) return;
    this.sim.tick(this.clockPort);
    for (const hk of this.activeHooks) hk();
    this.draw(true);
  }

  loop() {
    if (!this.running) return;
    const sim = this.sim;
    const now = performance.now();
    const dt = Math.min(0.1, (now - this.lastFrame) / 1000);
    this.lastFrame = now;
    if (sim.has(this.clockPort) && !this.paused) {
      const want = Math.max(1, Math.round(this.clockHz * dt));
      const budget = 12; // ms per frame we're willing to spend
      const t0 = performance.now();
      let done = 0;
      const hooks = this.activeHooks;
      const stride = Math.max(1, Math.floor(want / 64));
      for (const o of this.outputs) { o.acc.fill(0); o.n = 0; }
      const clk = this.clockPort;
      while (done < want) {
        const chunk = Math.min(want - done, hooks.length ? 256 : 4096, stride);
        if (this.bouncing) this.applyBounce();
        if (hooks.length) {
          for (let i = 0; i < chunk; i++) { sim.tick(clk); for (const hk of hooks) hk(); }
        } else sim.tick(clk, chunk);
        done += chunk;
        this.sampleOutputs();
        if (performance.now() - t0 > budget) break;
      }
      const rate = done / dt;
      this.speedEl.textContent = rate >= this.clockHz * 0.97
        ? `${fmtHz(this.clockHz)}, real time`
        : `${fmtHz(rate)} (${(this.clockHz / rate).toFixed(rate > this.clockHz / 10 ? 1 : 0)}× slower than the real chip)`;
      this.draw(false);
    } else if (!sim.has(this.clockPort)) {
      this.draw(true);
    }
    if (this.missing && this.missing.length) {
      this.speedEl.textContent += ` · not connected: ${this.missing.join(', ')}`;
    }
    this.frame = requestAnimationFrame(() => this.loop());
  }

  applyBounce() {
    const b = this.bouncing;
    const t = this.sim.cycles - b.start;
    while (b.i < b.flips.length && b.flips[b.i] <= t) b.i++;
    if (b.i >= b.flips.length) { this.sim.set(b.port, b.final); this.bouncing = null; return; }
    this.sim.set(b.port, b.i % 2 ? b.other : b.final);
  }

  sampleOutputs() {
    const v = this.sim.v;
    this.sim.settle();
    for (const o of this.outputs) {
      for (let i = 0; i < o.bits.length; i++) o.acc[i] += v[o.bits[i]];
      o.n++;
    }
  }

  draw(instant) {
    const v = this.sim.v;
    for (const o of this.outputs) {
      if (!o.bits.length) continue;
      let lvl;
      if (instant || !o.n) lvl = Array.from(o.bits, b => v[b]);
      else lvl = Array.from(o.acc, a => a / o.n);
      const val = o.opts.raw ? this.sim.get(o.port) : 0;
      o.draw(o, lvl, val);
    }
  }
}

export function fmtHz(f) {
  if (f >= 1e6) return `${(f / 1e6).toFixed(f >= 1e7 ? 1 : 2)} MHz`;
  if (f >= 1e3) return `${(f / 1e3).toFixed(1)} kHz`;
  return `${Math.round(f)} Hz`;
}
