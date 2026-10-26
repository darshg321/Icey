// Node-side compile helper for tests and for checking lesson solutions.
import { runYosys } from '@yowasp/yosys';
import { SIM_SCRIPT, ICE40_SCRIPT, prelude, diagnostics, stats } from '../src/engine/yosys.js';

export async function compile(src, { top = 'top', ice40 = false, params } = {}) {
  let log = '';
  const cap = b => { if (b) log += new TextDecoder().decode(b); };
  let files, ok = true;
  try {
    files = await runYosys(['-p', (ice40 ? ICE40_SCRIPT(top) : SIM_SCRIPT(top, params))], { 'design.v': prelude(src) }, { stdout: cap, stderr: cap, fetchProgress: () => {} });
  } catch (e) { ok = false; }
  return { ok, log, diags: diagnostics(log), stats: stats(log), json: ok ? JSON.parse(files[ice40 ? 'ice40.json' : 'out.json']) : null, lutJson: ok && !ice40 ? JSON.parse(files['lut.json']) : null };
}

import { ice40Build } from '../src/engine/flow.js';
import { runNextpnrIce40, runIcepack } from '../public/yowasp/nextpnr/bundle.js';
import fs from 'node:fs';
const pcf = fs.readFileSync(new URL('../../firmware/icey.pcf', import.meta.url), 'utf8');
export const buildIcey = (src, top = 'top', opts = {}) => ice40Build({ runYosys, runNextpnrIce40, runIcepack }, { src, top, pcf, ...opts, fetchProgress: () => () => {} });
