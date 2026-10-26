// Main-thread side of worker.js. One worker, jobs run one at a time.
import pcfText from '../../../firmware/icey.pcf?raw';

export const ICEY_PCF = pcfText;

let worker = null;
let nextId = 1;
const pending = new Map();
const listeners = new Set();

function getWorker() {
  if (worker) return worker;
  worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
  worker.onmessage = ({ data }) => {
    const job = pending.get(data.id);
    if (!job) return;
    if (data.progress) {
      job.onProgress && job.onProgress(data.progress);
      for (const l of listeners) l(data.progress);
      return;
    }
    pending.delete(data.id);
    for (const l of listeners) l(null);
    if (data.error) job.reject(new Error(data.error));
    else job.resolve(data.result);
  };
  worker.onerror = e => {
    for (const job of pending.values()) job.reject(new Error(e.message || 'worker crashed'));
    pending.clear();
    worker = null;
  };
  return worker;
}

function call(cmd, args, onProgress) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject, onProgress });
    // The worker loads the toolchains relative to the site's base URL.
    getWorker().postMessage({ id, cmd, args, base: new URL(import.meta.env.BASE_URL, document.baseURI).href });
  });
}

// Global "toolchain is downloading/working" indicator hooks into this.
export const onToolchainProgress = fn => { listeners.add(fn); return () => listeners.delete(fn); };

const simCache = new Map();
export async function compileForSim(src, top = 'top', onProgress, params) {
  const key = top + '\0' + JSON.stringify(params || {}) + '\0' + src;
  if (simCache.has(key)) return simCache.get(key);
  const r = await call('sim', { src, top, params }, onProgress);
  simCache.set(key, r);
  if (simCache.size > 20) simCache.delete(simCache.keys().next().value);
  return r;
}

export const buildForIcey = (src, top = 'top', onProgress, opts = {}) => call('ice40', { src, top, pcf: pcfText, ...opts }, onProgress);
export const runYosysScript = (script, files, onProgress) => call('yosys', { script, files }, onProgress);

// Start downloading Yosys in the background so the first Run is quick.
export function warmUp() {
  compileForSim('module top(input a, output y); assign y = a; endmodule').catch(() => {});
}
