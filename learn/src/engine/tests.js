// Exercise checker. Each test gets a fresh simulator and a small API (`t`)
// for poking inputs, ticking the clock and checking outputs. Everything the
// test does is recorded, so a failure can be shown as a waveform.
import { Sim } from './sim.js';

export class TestFail extends Error {}

const fmt = (v, width) => {
  if (width === 1) return String(v);
  const bits = (BigInt(v) & ((1n << BigInt(width)) - 1n)).toString(2).padStart(width, '0');
  return width > 16 ? `${v}` : `${v} (${width}'b${bits})`;
};

class Tester {
  constructor(sim, { clock = 'clk', record = [], maxSamples = 3000 } = {}) {
    this.sim = sim;
    this.clock = clock;
    this.rec = record.filter(n => sim.has(n));
    this.samples = [];
    this.maxSamples = maxSamples;
    this.truncated = false;
    this.marks = [];
  }

  #sample() {
    if (this.samples.length >= this.maxSamples) { this.truncated = true; return; }
    this.sim.settle();
    this.samples.push(this.rec.map(n => this.sim.get(n)));
  }

  width(name) { return this.sim.signals[name].width; }
  has(name) { return this.sim.has(name); }

  set(name, value) {
    if (!this.sim.has(name)) throw new TestFail(`Your module needs a port called "${name}".`);
    this.sim.set(name, value);
    this.sim.settle();
    this.#sample();
    return this;
  }

  get(name) {
    if (!this.sim.has(name)) throw new TestFail(`Your module needs a port called "${name}".`);
    this.sim.settle();
    return this.sim.get(name);
  }

  tick(n = 1, clk = this.clock) {
    if (!this.sim.has(clk)) throw new TestFail(`Your module needs a clock input called "${clk}".`);
    while (n > 0) {
      if (this.samples.length >= this.maxSamples) {
        // Recording is full, so run the rest at full speed.
        this.truncated = true;
        this.sim.tick(clk, n);
        return this;
      }
      this.sim.tick(clk);
      this.#sample();
      n--;
    }
    return this;
  }

  // Tick until `fn()` is true. Returns how many cycles that took.
  until(fn, max, what = 'the condition') {
    for (let i = 0; i <= max; i++) {
      if (fn()) return i;
      this.tick();
    }
    throw new TestFail(`Waited ${max} clock cycles for ${what}, and it never happened.`);
  }

  mark(label) { this.marks.push({ at: this.samples.length, label }); }

  eq(name, expected, when = '') {
    const got = this.get(name);
    const e = typeof got === 'bigint' ? BigInt(expected) : expected;
    if (got !== e) {
      const w = this.width(name);
      throw new TestFail(`${name} should be ${fmt(e, w)}${when ? ' ' + when : ''}, but it was ${fmt(got, w)}.`);
    }
  }

  ok(cond, message) { if (!cond) throw new TestFail(message); }
  fail(message) { throw new TestFail(message); }

  // Exhaustively (or randomly, if there are too many combinations) compare
  // outputs against a reference function of the inputs.
  table(inputs, outputs, ref, { max = 4096, describe } = {}) {
    for (const n of [...inputs, ...outputs]) if (!this.sim.has(n)) throw new TestFail(`Your module needs a port called "${n}".`);
    const widths = inputs.map(n => this.width(n));
    const total = widths.reduce((a, w) => a * 2 ** w, 1);
    const cases = [];
    if (total <= max) {
      for (let i = 0; i < total; i++) {
        let r = i;
        cases.push(widths.map(w => { const v = r % 2 ** w; r = Math.floor(r / 2 ** w); return v; }));
      }
    } else {
      for (let i = 0; i < max; i++) cases.push(widths.map(w => Math.floor(Math.random() * 2 ** Math.min(w, 31))));
    }
    for (const c of cases) {
      const env = {};
      inputs.forEach((n, i) => { env[n] = c[i]; this.sim.set(n, c[i]); });
      this.sim.settle();
      this.#sample();
      const want = ref(env);
      for (const o of outputs) {
        const got = this.sim.get(o);
        const exp = typeof want === 'object' ? want[o] : want;
        if (exp === undefined) continue;
        if (got !== exp) {
          const w = this.width(o);
          const inStr = describe ? describe(env) : inputs.map(n => `${n} = ${fmt(env[n], this.width(n))}`).join(', ');
          throw new TestFail(`With ${inStr}: ${o} should be ${fmt(exp, w)}, but it was ${fmt(got, w)}.`);
        }
      }
    }
  }

  // --- serial helpers (8N1, LSB first, idle high) ---
  uartSendByte(rx, byte, cyclesPerBit) {
    const bits = [0, ...Array.from({ length: 8 }, (_, i) => (byte >> i) & 1), 1];
    for (const b of bits) { this.sim.set(rx, b); this.tick(cyclesPerBit); }
  }

  uartReadByte(tx, cyclesPerBit, timeout) {
    this.until(() => this.get(tx) === 0, timeout, `a start bit on ${tx}`);
    this.tick(Math.floor(cyclesPerBit / 2));
    if (this.get(tx) !== 0) throw new TestFail(`${tx} went low but didn't stay low for a full start bit.`);
    let byte = 0;
    for (let i = 0; i < 8; i++) { this.tick(cyclesPerBit); byte |= this.get(tx) << i; }
    this.tick(cyclesPerBit);
    if (this.get(tx) !== 1) throw new TestFail(`After the 8 data bits, ${tx} should go high for the stop bit. It was low (byte so far: 0x${byte.toString(16)}).`);
    return byte;
  }
}

// `extra`: netlists of other modules (exercise.extraTops), simulated next to
// the main one as t.extra[name].
export async function runTests(json, top, exercise, { onResult, src = '', extra = {} } = {}) {
  const results = [];
  const record = exercise.waves || Object.keys(json.modules[top]?.ports || {});
  for (const test of exercise.tests || []) {
    let sim;
    const r = { name: test.name, pass: false };
    try {
      sim = new Sim(json, top);
      const t = new Tester(sim, { clock: exercise.clock?.port || 'clk', record, maxSamples: test.maxSamples || 3000 });
      t.src = src;
      t.extra = Object.fromEntries(Object.entries(extra).map(([n, j]) => [n, new Sim(j, n)]));
      // The code without comments, for tests that check how something was written.
      t.code = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
      r.tester = t;
      await test.run(t);
      r.pass = true;
    } catch (e) {
      r.message = e instanceof TestFail ? e.message : `${e.name === 'SimError' ? '' : 'The test crashed: '}${e.message}`;
      if (!(e instanceof TestFail) && e.name !== 'SimError') console.error(e);
    }
    if (r.tester) {
      r.wave = { names: r.tester.rec, widths: r.tester.rec.map(n => sim.signals[n].width), samples: r.tester.samples, truncated: r.tester.truncated, marks: r.tester.marks };
      delete r.tester;
    }
    results.push(r);
    onResult && onResult(r);
    await new Promise(res => setTimeout(res, 0));
  }
  return results;
}
