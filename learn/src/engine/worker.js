// Runs Yosys and nextpnr (WebAssembly, from YoWASP) off the main thread.
import { SIM_SCRIPT, prelude, diagnostics, stats, stripAnsi } from './yosys.js';
import { ice40Build } from './flow.js';

let base = new URL(import.meta.env.BASE_URL, self.location.origin).href;
let yosysP, pnrP;
const yosys = () => (yosysP ||= import(/* @vite-ignore */ base + 'yowasp/yosys/bundle.js'));
const pnr = () => (pnrP ||= import(/* @vite-ignore */ base + 'yowasp/nextpnr/bundle.js'));

let currentId = null;
const progress = (stage) => ({ totalLength, doneLength }) =>
  self.postMessage({ id: currentId, progress: { stage, done: doneLength, total: totalLength } });

function capture() {
  let log = '';
  const dec = new TextDecoder();
  const cb = b => { if (b) log += dec.decode(b, { stream: true }); };
  return { cb, get log() { return log; } };
}

async function runYosys(script, files) {
  const { runYosys } = await yosys();
  const cap = capture();
  let out = null, ok = true;
  try {
    out = await runYosys(['-p', script], files, { stdout: cap.cb, stderr: cap.cb, fetchProgress: progress('Loading Yosys') });
  } catch (e) {
    if (!e.files && !/Exited with status/.test(e.message)) throw e;
    ok = false;
  }
  return { ok, out, log: stripAnsi(cap.log) };
}

const handlers = {
  async sim({ src, top = 'top', params }) {
    const r = await runYosys(SIM_SCRIPT(top, params), { 'design.v': prelude(src) });
    return { ok: r.ok, log: r.log, diags: diagnostics(r.log), stats: stats(r.log), json: r.ok ? JSON.parse(r.out['out.json']) : null, lutJson: r.ok && r.out['lut.json'] ? JSON.parse(r.out['lut.json']) : null };
  },

  async ice40({ src, top = 'top', pcf, dsp = true }) {
    const [y, n] = await Promise.all([yosys(), pnr()]);
    return ice40Build({ runYosys: y.runYosys, runNextpnrIce40: n.runNextpnrIce40, runIcepack: n.runIcepack }, {
      src, top, pcf, dsp, fetchProgress: progress,
      onStage: stage => self.postMessage({ id: currentId, progress: { stage, done: 0, total: 0 } }),
    });
  },

  // Free-form Yosys run, used by the formal-verification lessons.
  async yosys({ script, files }) {
    const r = await runYosys(script, files);
    return { ok: r.ok, log: r.log, diags: diagnostics(r.log), files: r.out };
  },
};

self.onmessage = async ({ data }) => {
  const { id, cmd, args } = data;
  if (data.base) base = data.base;
  currentId = id;
  try {
    const result = await handlers[cmd](args);
    self.postMessage({ id, result }, result.bin ? [result.bin.buffer] : []);
  } catch (e) {
    self.postMessage({ id, error: String(e && e.stack || e) });
  }
};
