// Gate-level simulator for the netlists Yosys produces with SIM_SCRIPT (see
// yosys.js). Every combinational gate becomes one line of generated JS, sorted
// so each gate runs after the gates feeding it. Flip-flops are grouped by
// clock and edge; a group samples all its D inputs before any Q changes, which
// is what makes nonblocking assignment work.

const BIN = { $_AND_: '&', $_OR_: '|', $_XOR_: '^' };

function bitIndex(b) {
  if (typeof b === 'number') return b;
  return b === '1' ? 1 : 0; // '0', 'x' and 'z' all read as 0, like an iCE40 at power-up
}

function paramInt(p) {
  if (p === undefined) return 0;
  if (typeof p === 'number') return p;
  return parseInt(p.replace(/[xz]/g, '0'), 2) || 0;
}

function paramBits(p, n) {
  // Yosys writes parameters MSB first. Return LSB-first array of n bits.
  const s = typeof p === 'string' ? p : (p >>> 0).toString(2);
  const out = new Uint8Array(n);
  for (let i = 0; i < n && i < s.length; i++) out[i] = s[s.length - 1 - i] === '1' ? 1 : 0;
  return out;
}

export class SimError extends Error {}

export class Sim {
  constructor(json, top) {
    const mod = json.modules[top] || Object.values(json.modules).find(m => m.attributes && m.attributes.top) || Object.values(json.modules)[0];
    if (!mod) throw new SimError('No module in netlist');
    this.mod = mod;
    let maxBit = 1;
    const scan = bits => { for (const b of bits) if (typeof b === 'number' && b > maxBit) maxBit = b; };
    for (const p of Object.values(mod.ports)) scan(p.bits);
    for (const c of Object.values(mod.cells)) for (const bits of Object.values(c.connections)) scan(bits);
    for (const n of Object.values(mod.netnames)) scan(n.bits);
    this.v = new Uint8Array(maxBit + 1);
    this.v[1] = 1;

    this.ports = {};
    for (const [name, p] of Object.entries(mod.ports)) {
      this.ports[name] = { dir: p.direction, bits: p.bits.map(bitIndex), width: p.bits.length, signed: !!p.signed };
    }
    this.signals = {};
    for (const [name, n] of Object.entries(mod.netnames)) {
      if (n.hide_name) continue;
      this.signals[name] = { bits: n.bits.map(bitIndex), width: n.bits.length, signed: !!n.signed };
    }
    for (const [name, p] of Object.entries(this.ports)) this.signals[name] = p;

    this.cellCount = Object.keys(mod.cells).length;
    this.#build();

    // Power-up state: registers start at their `initial`/declaration value, or 0.
    for (const n of Object.values(mod.netnames)) {
      const init = n.attributes && n.attributes.init;
      if (init === undefined) continue;
      // MSB first; 'x' means "no initial value here", which matters when two
      // names share wires and only one of them carries the real value.
      const str = typeof init === 'string' ? init : (init >>> 0).toString(2).padStart(n.bits.length, '0');
      n.bits.forEach((b, i) => {
        const c = str[str.length - 1 - i];
        if (typeof b === 'number' && (c === '0' || c === '1')) this.v[b] = +c;
      });
    }
    this.cycles = 0;
    this.dirty = true;
    this.settle();
    this.lastClk.set(this.groups.map(g => this.v[g.clk]));
  }

  // Put every flip-flop in a random state, the way a real chip powers up
  // (an FPGA loads the initial values; silicon doesn't).
  scramble(random = Math.random) {
    for (const g of this.groups) for (const { q } of g.ffs) this.v[q] = random() < 0.5 ? 0 : 1;
    this.dirty = true;
    this.settle();
  }

  #build() {
    const mod = this.mod;
    const nodes = []; // combinational: {ins:[net], outs:[net], code}
    const groups = new Map(); // `${clk}:${pol}` -> {clk, pol, ffs:[{d,q}], memW:[], memR:[]}
    this.mems = [];
    this.slots = [];
    const latches = [];
    const group = (clk, pol) => {
      const key = `${clk}:${pol}`;
      if (!groups.has(key)) groups.set(key, { clk, pol, ffs: [], memW: [], memR: [] });
      return groups.get(key);
    };
    const unsupported = new Set();

    for (const [cname, c] of Object.entries(mod.cells)) {
      const k = {};
      for (const [port, bits] of Object.entries(c.connections)) k[port] = bits.map(bitIndex);
      const A = k.A && k.A[0], B = k.B && k.B[0], Y = k.Y && k.Y[0];
      switch (c.type) {
        case '$_AND_': case '$_OR_': case '$_XOR_':
          nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=v[${A}]${BIN[c.type]}v[${B}];` }); break;
        case '$_NAND_': nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=(v[${A}]&v[${B}])^1;` }); break;
        case '$_NOR_': nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=(v[${A}]|v[${B}])^1;` }); break;
        case '$_XNOR_': nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=v[${A}]^v[${B}]^1;` }); break;
        case '$_ANDNOT_': nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=v[${A}]&(v[${B}]^1);` }); break;
        case '$_ORNOT_': nodes.push({ ins: [A, B], outs: [Y], code: `v[${Y}]=v[${A}]|(v[${B}]^1);` }); break;
        case '$_NOT_': nodes.push({ ins: [A], outs: [Y], code: `v[${Y}]=v[${A}]^1;` }); break;
        case '$_BUF_': nodes.push({ ins: [A], outs: [Y], code: `v[${Y}]=v[${A}];` }); break;
        case '$_MUX_': {
          const S = k.S[0];
          nodes.push({ ins: [A, B, S], outs: [Y], code: `v[${Y}]=v[${S}]?v[${B}]:v[${A}];` }); break;
        }
        case '$_NMUX_': {
          const S = k.S[0];
          nodes.push({ ins: [A, B, S], outs: [Y], code: `v[${Y}]=(v[${S}]?v[${B}]:v[${A}])^1;` }); break;
        }
        case '$_TBUF_': {
          const E = k.E[0];
          nodes.push({ ins: [A, E], outs: [Y], code: `v[${Y}]=v[${A}]&v[${E}];` }); break;
        }
        case '$lut': {
          // a lookup table: the inputs form an index into the LUT parameter
          const K = paramInt(c.parameters.LUT);
          const idx = k.A.map((b, i) => (i ? `(v[${b}]<<${i})` : `v[${b}]`)).join('|');
          nodes.push({ ins: k.A, outs: [Y], code: `v[${Y}]=(${K}>>(${idx}))&1;`, lut: true }); break;
        }
        case '$_DFF_P_': case '$_DFF_N_':
          group(k.C[0], c.type === '$_DFF_P_' ? 1 : 0).ffs.push({ d: k.D[0], q: k.Q[0] }); break;
        case '$_DLATCH_P_': case '$_DLATCH_N_': {
          const E = k.E[0], D = k.D[0], Q = k.Q[0];
          const on = c.type === '$_DLATCH_P_' ? `v[${E}]` : `!v[${E}]`;
          latches.push(cname);
          nodes.push({ ins: [E, D], outs: [Q], code: `if(${on})v[${Q}]=v[${D}];`, latch: true }); break;
        }
        case '$mem_v2': this.#memory(c, k, nodes, group); break;
        default: unsupported.add(c.type);
      }
    }
    if (unsupported.size) {
      const list = [...unsupported];
      const hw = list.filter(t => /^SB_/.test(t));
      if (hw.length) throw new SimError(`${hw.join(', ')} ${hw.length > 1 ? 'are' : 'is'} a real iCE40 hardware block. The browser simulator doesn't model ${hw.length > 1 ? 'them' : 'it'}; build this one for the board instead.`);
      throw new SimError(`The simulator can't run these cells: ${list.join(', ')}`);
    }
    this.latches = latches;

    // Topological sort (Kahn) over nets.
    const driver = new Map();
    nodes.forEach((n, i) => n.outs.forEach(o => driver.set(o, i)));
    const indeg = new Int32Array(nodes.length);
    const users = nodes.map(() => []);
    nodes.forEach((n, i) => {
      const seen = new Set();
      for (const inp of n.ins) {
        const d = driver.get(inp);
        if (d === undefined || d === i && n.latch || seen.has(d)) continue;
        seen.add(d);
        indeg[i]++;
        users[d].push(i);
      }
    });
    const order = [];
    const queue = [];
    indeg.forEach((d, i) => { if (d === 0) queue.push(i); });
    while (queue.length) {
      const i = queue.pop();
      order.push(i);
      for (const u of users[i]) if (--indeg[u] === 0) queue.push(u);
    }
    if (order.length !== nodes.length) {
      const stuck = new Set();
      indeg.forEach((d, i) => { if (d > 0) nodes[i].outs.forEach(o => stuck.add(o)); });
      const names = this.#namesFor(stuck);
      throw new SimError(`Combinational loop: a signal feeds back into itself with no flip-flop in between${names.length ? ` (through ${names.slice(0, 6).join(', ')})` : ''}. Real hardware would oscillate or latch up here.`);
    }
    this.gateCount = nodes.filter(n => !n.mem && !n.lut).length;
    this.lutCount = nodes.filter(n => n.lut).length;

    // Which nets does combinational logic actually read? Changing a pure clock
    // net then doesn't require re-running the gates.
    this.combInputs = new Set();
    for (const n of nodes) for (const i of n.ins) this.combInputs.add(i);

    const CHUNK = 300; // V8 stops optimising generated functions much bigger than this
    const lines = order.map(i => nodes[i].code);
    const fns = [];
    for (let i = 0; i < lines.length; i += CHUNK) {
      fns.push(new Function('v', 'M', lines.slice(i, i + CHUNK).join('\n')));
    }
    const M = this.mems.map(m => m.data);
    this.comb = fns.length === 1 ? () => fns[0](this.v, M) : () => { for (const f of fns) f(this.v, M); };

    this.groups = [...groups.values()];
    this.lastClk = new Uint8Array(this.groups.length);
    let tOff = 0;
    for (const g of this.groups) {
      const s = [], c = [];
      g.ffs.forEach(({ d, q }, i) => { s.push(`T[${tOff + i}]=v[${d}];`); c.push(`v[${q}]=T[${tOff + i}];`); });
      tOff += g.ffs.length;
      // Memories: read (old data) during sample, write during commit.
      for (const r of g.memR) s.push(r.sample);
      for (const w of g.memW) { s.push(w.sample(tOff)); c.push(w.commit(tOff)); tOff += w.temps; }
      // Read ports land before the writes commit (read-old-data), except
      // transparent ones, which read again afterwards and see the new value.
      c.unshift(...g.memR.map(r => r.commit));
      for (const r of g.memR) if (r.transparent) c.push(r.retransparent);
      g.sample = new Function('v', 'M', 'T', 'S', s.join('\n'));
      g.commit = new Function('v', 'M', 'T', 'S', c.join('\n'));
    }
    this.T = new Uint8Array(tOff + 1);
    this.S = new Int32Array(this.slots.length + 1);
    this.M = M;
    this.ffCount = this.groups.reduce((n, g) => n + g.ffs.length, 0);
    this.clockNets = new Set(this.groups.map(g => g.clk));
  }

  #memory(c, k, nodes, group) {
    const p = c.parameters;
    const size = paramInt(p.SIZE), width = paramInt(p.WIDTH), abits = paramInt(p.ABITS), offset = paramInt(p.OFFSET);
    const nR = paramInt(p.RD_PORTS), nW = paramInt(p.WR_PORTS);
    const data = new Uint8Array(size * width);
    if (p.INIT) data.set(paramBits(p.INIT, size * width));
    const mi = this.mems.length;
    this.mems.push({ name: (p.MEMID || '').replace(/^\\/, ''), size, width, offset, data });
    const rdClkEn = paramBits(p.RD_CLK_ENABLE, nR), rdClkPol = paramBits(p.RD_CLK_POLARITY, nR);
    const wrClkEn = paramBits(p.WR_CLK_ENABLE, nW), wrClkPol = paramBits(p.WR_CLK_POLARITY, nW);
    const trans = paramBits(p.RD_TRANSPARENCY_MASK, nR * nW);
    const srstVal = paramBits(p.RD_SRST_VALUE, nR * width), arstVal = paramBits(p.RD_ARST_VALUE, nR * width);
    const initVal = paramBits(p.RD_INIT_VALUE, nR * width);
    const addrExpr = bits => bits.map((b, i) => `(v[${b}]<<${i})`).join('|') || '0';

    const wrClks = [];
    for (let w = 0; w < nW; w++) {
      const addr = k.WR_ADDR.slice(w * abits, (w + 1) * abits);
      const wd = k.WR_DATA.slice(w * width, (w + 1) * width);
      const we = k.WR_EN.slice(w * width, (w + 1) * width);
      if (!wrClkEn[w]) throw new SimError('Memory with an asynchronous write port is not supported');
      const clk = k.WR_CLK[w];
      wrClks.push(clk);
      const slot = this.slots.length; // the write address is kept in S[slot] between sample and commit
      this.slots.push(0);
      const temps = width * 2;
      group(clk, wrClkPol[w]).memW.push({
        temps,
        sample: t => `S[${slot}]=(${addrExpr(addr)})-${offset};` +
          wd.map((b, i) => `T[${t + i}]=v[${b}];T[${t + width + i}]=v[${we[i]}];`).join(''),
        commit: t => `{const a=S[${slot}];if(a>=0&&a<${size}){const m=M[${mi}];` +
          wd.map((_, i) => `if(T[${t + width + i}])m[a*${width}+${i}]=T[${t + i}];`).join('') + '}}',
      });
    }

    for (let r = 0; r < nR; r++) {
      const addr = k.RD_ADDR.slice(r * abits, (r + 1) * abits);
      const rd = k.RD_DATA.slice(r * width, (r + 1) * width);
      const read = `{const a=(${addrExpr(addr)})-${offset};const m=M[${mi}];if(a>=0&&a<${size}){` +
        rd.map((b, i) => `v[${b}]=m[a*${width}+${i}];`).join('') + `}else{${rd.map(b => `v[${b}]=0;`).join('')}}}`;
      if (!rdClkEn[r]) {
        nodes.push({ ins: addr, outs: rd, code: read, mem: true });
        continue;
      }
      const en = k.RD_EN[r], srst = k.RD_SRST[r], arst = k.RD_ARST[r];
      const slot = this.slots.length; // S[slot] = mode, S[slot+1] = address
      this.slots.push(0, 0);
      const sv = srstVal.slice(r * width, (r + 1) * width), av = arstVal.slice(r * width, (r + 1) * width);
      rd.forEach((b, i) => { this.v[b] = initVal[r * width + i]; });
      const transparent = wrClks.some((clk, w) => trans[r * nW + w] && clk === k.RD_CLK[r]);
      // mode: 0 hold, 1 read, 2 srst, 3 arst
      group(k.RD_CLK[r], rdClkPol[r]).memR.push({
        transparent,
        sample: `S[${slot}]=v[${arst}]?3:v[${srst}]?2:v[${en}]?1:0;S[${slot + 1}]=(${addrExpr(addr)})-${offset};`,
        commit: `{const mode=S[${slot}];` +
          `if(mode===3){${rd.map((b, i) => `v[${b}]=${av[i]};`).join('')}}` +
          `else if(mode===2){${rd.map((b, i) => `v[${b}]=${sv[i]};`).join('')}}` +
          `else if(mode===1){const a=S[${slot + 1}];const m=M[${mi}];if(a>=0&&a<${size}){${rd.map((b, i) => `v[${b}]=m[a*${width}+${i}];`).join('')}}}}`,
        retransparent: `{const a=S[${slot + 1}];const m=M[${mi}];if(S[${slot}]===1&&a>=0&&a<${size}){${rd.map((b, i) => `v[${b}]=m[a*${width}+${i}];`).join('')}}}`,
      });
    }
  }

  #namesFor(nets) {
    const out = [];
    for (const [name, s] of Object.entries(this.signals)) {
      if (s.bits.some(b => nets.has(b))) out.push(name);
    }
    return out;
  }

  // Run the gates, then fire any flip-flops whose clock just had their edge,
  // and repeat until nothing moves. Handles clocks made by logic (dividers).
  settle() {
    const g = this.groups, v = this.v, last = this.lastClk;
    if (this.dirty) { this.comb(); this.dirty = false; }
    for (let iter = 0; iter < 64; iter++) {
      let fired = null;
      for (let i = 0; i < g.length; i++) {
        const now = v[g[i].clk];
        if (now !== last[i]) {
          last[i] = now;
          if (now === g[i].pol) (fired || (fired = [])).push(g[i]);
        }
      }
      if (!fired) return;
      for (const f of fired) f.sample(v, this.M, this.T, this.S);
      for (const f of fired) f.commit(v, this.M, this.T, this.S);
      this.comb();
    }
    throw new SimError('Clocks kept changing for 64 rounds in a row; is a clock driven by a loop?');
  }

  #bits(name) {
    const s = this.signals[name];
    if (!s) throw new SimError(`No signal called "${name}"`);
    return s;
  }

  has(name) { return name in this.signals; }

  set(name, value) {
    const s = this.#bits(name);
    const v = this.v;
    let changedComb = false;
    if (typeof value === 'bigint') {
      s.bits.forEach((b, i) => { const x = Number((value >> BigInt(i)) & 1n); if (v[b] !== x) { v[b] = x; if (this.combInputs.has(b)) changedComb = true; } });
    } else {
      s.bits.forEach((b, i) => { const x = i < 32 ? (value >>> i) & 1 : Math.floor(value / 2 ** i) & 1; if (v[b] !== x) { v[b] = x; if (this.combInputs.has(b)) changedComb = true; } });
    }
    if (changedComb) this.dirty = true;
  }

  get(name, signed) {
    const s = this.#bits(name);
    const v = this.v;
    if (s.width > 32) {
      let r = 0n;
      for (let i = s.width - 1; i >= 0; i--) r = (r << 1n) | BigInt(v[s.bits[i]]);
      if ((signed ?? s.signed) && v[s.bits[s.width - 1]]) r -= 1n << BigInt(s.width);
      return r;
    }
    let r = 0;
    for (let i = s.width - 1; i >= 0; i--) r = r * 2 + v[s.bits[i]];
    if ((signed ?? s.signed) && v[s.bits[s.width - 1]]) r -= 2 ** s.width;
    return r;
  }

  // One full clock period: rising edge, then falling edge.
  tick(clk = 'clk', n = 1) {
    const s = this.#bits(clk);
    const b = s.bits[0], v = this.v;
    const comb = this.combInputs.has(b);
    for (let i = 0; i < n; i++) {
      v[b] = 1; if (comb) this.dirty = true; this.settle();
      v[b] = 0; if (comb) this.dirty = true; this.settle();
      this.cycles++;
    }
  }

  peekMem(name) {
    return this.mems.find(m => m.name === name || m.name.endsWith('.' + name));
  }
}

// Small designs simulate from the gate netlist (it's what the Gates tab
// draws). Big ones use the LUT-packed copy, which runs faster.
export function simNetlist(r, top, limit = 450) {
  const cells = Object.keys(r.json.modules[top]?.cells || {}).length;
  return cells > limit && r.lutJson ? r.lutJson : r.json;
}
