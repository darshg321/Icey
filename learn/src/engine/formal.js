// Formal verification with Yosys's built-in SAT solver: equivalence checks
// and induction proofs of `assert` statements. `run(script, files)` is the
// worker's free-form Yosys runner (or the Node one in the tests).
import { prelude } from './yosys.js';

// Parse the "Time Signal Name Dec Hex Bin" tables Yosys prints with a model
// into a waveform for the Waves tab.
export function traceFromLog(log) {
  const i = log.lastIndexOf('Time Signal Name');
  if (i < 0) return null;
  const rows = [];
  for (const line of log.slice(i).split('\n').slice(2)) {
    const m = line.match(/^\s+(init|\d+)\s+\\(\S+)\s+(-?\d+)\s+\S+\s+([01x]+)\s*$/);
    if (m) rows.push({ t: m[1], name: m[2], value: +m[3], width: m[4].length });
    else if (!/^\s+-{4}/.test(line) && rows.length && !/^\s*$/.test(line)) break;
  }
  const names = [...new Set(rows.filter(r => r.t !== 'init').map(r => r.name))];
  const steps = [...new Set(rows.filter(r => r.t !== 'init').map(r => r.t))];
  if (!names.length) return null;
  const widths = names.map(n => rows.find(r => r.name === n).width);
  const samples = steps.map(t => names.map(n => (rows.find(r => r.t === t && r.name === n) || { value: 0 }).value));
  return { names, widths, samples, marks: [] };
}

const lastFail = log => (log.match(/^ERROR: (.*)$/m) || [])[1] || '';

// Prove two modules give the same outputs for every possible input.
export async function equivalent(run, src, gold, gate) {
  const r = await run(`read_verilog -sv design.v; prep; chformal -remove; miter -equiv -flatten -make_assert ${gold} ${gate} miter; sat -verify -prove-asserts -show-inputs -show-outputs miter`, { 'design.v': prelude(src) });
  if (r.ok) return { pass: true, log: r.log };
  if (/model found: FAIL/.test(r.log)) {
    const cex = {};
    for (const m of r.log.matchAll(/^\s+\\in_(\w+)\s+(-?\d+)\s+\S+\s+[01x]+\s*$/gm)) cex[m[1]] = +m[2];
    const desc = Object.entries(cex).map(([k, v]) => `${k} = ${v}`).join(', ');
    return { pass: false, log: r.log, cex, message: `Found an input where they differ: ${desc}.` };
  }
  return { pass: false, log: r.log, message: lastFail(r.log) || 'Yosys stopped with an error; see the Log tab.' };
}

// Prove every `assert` in `top` holds forever, starting from the initial state.
export async function proveAsserts(run, src, top, { maxSteps = 20 } = {}) {
  const r = await run(`read_verilog -formal design.v; prep -top ${top}; chformal -lower; memory; flatten; opt_clean; sat -tempinduct -verify -prove-asserts -set-init-zero -seq 1 -show-inputs -show-regs -maxsteps ${maxSteps} ${top}`, { 'design.v': prelude(src) });
  if (!/\$assert|\$check/.test(r.log)) return { pass: false, log: r.log, message: 'There are no assertions to prove.' };
  if (/Induction step proven: SUCCESS/.test(r.log)) {
    const n = (r.log.match(/Trying induction with length (\d+)/g) || []).length;
    return { pass: true, log: r.log, message: `Proven for every reachable state (induction length ${n}).` };
  }
  if (/model found for base case: FAIL/.test(r.log)) {
    const wave = traceFromLog(r.log);
    return { pass: false, log: r.log, wave, message: `An assertion fails ${wave ? wave.samples.length : 'a few'} clocks after reset. The Waves tab shows how to get there.` };
  }
  if (/Reached maximum number of time steps|maximum number/i.test(r.log)) {
    return { pass: false, log: r.log, wave: traceFromLog(r.log), message: `No assertion fails within ${maxSteps} clocks of reset, but induction couldn't finish the proof: the assertions aren't strong enough to rule out states that can't really happen. Add an assertion that ties the registers together.` };
  }
  return { pass: false, log: r.log, message: lastFail(r.log) || 'Yosys stopped with an error; see the Log tab.' };
}
