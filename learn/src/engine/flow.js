// The full iCE40 build (Yosys -> nextpnr -> icepack), shared by the browser
// worker and the Node test scripts. Tool runners are passed in.
import { ICE40_SCRIPT, prelude, diagnostics, stats, stripAnsi } from './yosys.js';

function capture() {
  let log = '';
  const dec = new TextDecoder();
  return { cb: b => { if (b) log += dec.decode(b, { stream: true }); }, get log() { return stripAnsi(log); } };
}

export async function ice40Build({ runYosys, runNextpnrIce40, runIcepack }, { src, top = 'top', pcf, dsp = true, onStage = () => {}, fetchProgress }) {
  const now = () => (globalThis.performance ? performance.now() : Date.now());
  const t0 = now();
  const ycap = capture();
  let yout = null, ok = true;
  try {
    yout = await runYosys(['-p', ICE40_SCRIPT(top, { dsp })], { 'design.v': prelude(src) }, { stdout: ycap.cb, stderr: ycap.cb, fetchProgress: fetchProgress && fetchProgress('Loading Yosys') });
  } catch (e) {
    if (!/Exited with status/.test(e.message)) throw e;
    ok = false;
  }
  const res = { ok, log: ycap.log, diags: diagnostics(ycap.log), stats: stats(ycap.log), synthMs: now() - t0 };
  if (!ok) return res;

  onStage('Placing and routing');
  const cap = capture();
  const t1 = now();
  let f;
  try {
    // --threads 1: the multi-threaded placer never finishes under WebAssembly.
    f = await runNextpnrIce40(['--up5k', '--package', 'sg48', '--json', 'in.json', '--pcf', 'icey.pcf', '--pcf-allow-unconstrained',
      '--asc', 'out.asc', '--write', 'placed.json', '--report', 'report.json', '--threads', '1', '--seed', '1'],
    { 'in.json': yout['ice40.json'], 'icey.pcf': pcf }, { stdout: cap.cb, stderr: cap.cb, fetchProgress: fetchProgress && fetchProgress('Loading nextpnr') });
  } catch (e) {
    res.ok = false;
    res.pnrLog = cap.log;
    if (!/Exited with status/.test(e.message)) res.diags.push({ line: null, severity: 'error', message: `nextpnr crashed: ${e.message}` });
    res.diags.push(...cap.log.split('\n').filter(l => /^ERROR/.test(l)).map(l => ({ line: null, severity: 'error', message: l.replace(/^ERROR: /, 'nextpnr: ') })));
    return res;
  }
  res.pnrMs = now() - t1;
  res.pnrLog = cap.log;
  res.report = JSON.parse(f['report.json']);
  const placed = JSON.parse(f['placed.json']);
  const mod = Object.values(placed.modules).find(m => Object.keys(m.cells).length) || {};
  res.cells = Object.entries(mod.cells || {}).map(([name, c]) => ({
    name, type: c.type, bel: c.attributes.NEXTPNR_BEL,
    params: c.type === 'ICESTORM_LC' ? { LUT_INIT: c.parameters.LUT_INIT, DFF_ENABLE: c.parameters.DFF_ENABLE, CARRY_ENABLE: c.parameters.CARRY_ENABLE } : c.parameters,
    src: c.attributes.src,
  }));
  res.asc = f['out.asc'];
  const p = await runIcepack(['out.asc', 'out.bin'], { 'out.asc': f['out.asc'] }, { decodeASCII: false, fetchProgress: () => {} });
  res.bin = p['out.bin'];
  return res;
}

// Handy numbers for chip tests.
export const used = (res, kind) => res.report?.utilization?.[kind]?.used ?? 0;
export const fmax = res => Math.min(...Object.values(res.report?.fmax || {}).map(f => f.achieved), Infinity);
// Logic cells doing real work: nextpnr also spends a cell or two making
// constant 0s and 1s ($PACKER_GND / $PACKER_VCC), which its report counts.
export const logicCells = res => (res.cells || []).filter(c => c.type === 'ICESTORM_LC' && !c.name.startsWith('$PACKER_')).length;
