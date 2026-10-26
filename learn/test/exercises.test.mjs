// Every exercise's reference solution must pass its own tests, and the
// starter code should not (otherwise the exercise is a no-op).
// usage: node test/exercises.test.mjs [lesson-dir-filter]
import fs from 'node:fs';
import path from 'node:path';
import { compile, buildIcey } from './compile-node.mjs';
import { runTests } from '../src/engine/tests.js';
import { simNetlist } from '../src/engine/sim.js';
import { runYosys } from '@yowasp/yosys';

const filter = process.argv[2] || '';
const roots = ['lessons', 'chip'].map(d => new URL(`../src/${d}/`, import.meta.url).pathname);
let bad = 0, n = 0;

const libDir = new URL('../src/lib/', import.meta.url).pathname;
const LIBS = { 6502: `\n${fs.readFileSync(libDir + 'verilog-6502/ALU.v', 'utf8')}\n${fs.readFileSync(libDir + 'verilog-6502/cpu.v', 'utf8')}` };
const withLibs = (src, libs = []) => src + libs.map(l => LIBS[l]).join('\n');

// Same clock wrapping the workbench does before building for Icey.
import { wrapForIcey } from '../src/ui/wrap.js';
const wrapCache = new Map();
function wrap(ex) { return wrapCache.get(ex) ?? withLibs(ex.solution, ex.libs); }
async function prepareWrap(ex) {
  if (ex.iceyWrap) { wrapCache.set(ex, ex.iceyWrap(ex.solution)); return; }
  if (ex.noSim) return;
  const r = await compile(withLibs(ex.solution, ex.libs), { top: ex.top || 'top' });
  if (r.ok) wrapCache.set(ex, wrapForIcey(withLibs(ex.solution, ex.libs), ex.top || 'top', r.json.modules[ex.top || 'top'].ports, ex.iceyClock).src);
}

async function yosysRun(script, files) {
  let log = '';
  const cap = b => { if (b) log += new TextDecoder().decode(b); };
  let out = null, ok = true;
  try { out = await runYosys(['-p', script], files, { stdout: cap, stderr: cap, fetchProgress: () => {} }); } catch { ok = false; }
  return { ok, log: log.replace(/\x1b\[[0-9;]*m/g, ''), files: out, diags: [] };
}

async function check(ex, src0) {
  const src = withLibs(src0, ex.libs);
  if (ex.formal) return (await ex.formal(src, yosysRun)).map(r => ({ ...r }));
  const top = ex.testTop || ex.top || 'top';
  const r = await compile(src, { top, params: ex.testParams });
  if (!r.ok) return [{ name: 'compile', pass: false, message: r.diags.map(d => `${d.line}: ${d.message}`).join('; ') || r.log.slice(-800) }];
  const extra = {};
  for (const name of ex.extraTops || []) {
    const r2 = await compile(src, { top: name });
    if (!r2.ok) return [{ name: `compile ${name}`, pass: false, message: r2.diags.map(d => d.message).join('; ') }];
    extra[name] = simNetlist(r2, name);
  }
  return runTests(simNetlist(r, top), top, ex, { src, extra });
}

for (const [root, dir] of roots.flatMap(r => fs.readdirSync(r).sort().map(d => [r, d]))) {
  const name = `${path.basename(root)}/${dir}`;
  if (!name.includes(filter)) continue;
  const f = path.join(root, dir, 'exercises.js');
  if (!fs.existsSync(f)) continue;
  const exs = (await import(f)).default;
  for (const ex of exs) {
    if (ex.chipTests) {
      await prepareWrap(ex);
      const t0 = Date.now();
      const res = await buildIcey(wrap(ex), ex.iceyTop || ex.top || 'top', { dsp: ex.iceyDsp !== false });
      const fails = res.ok ? ex.chipTests.map(c => [c.name, c.check(res)]).filter(([, m]) => m) : [['build', res.diags.map(d => d.message).join('; ')]];
      console.log(`${fails.length ? 'FAIL' : 'ok  '} ${name}/${ex.id} [chip] (${Date.now() - t0} ms)`);
      for (const [nm, m] of fails) console.log('     ✗', nm, '—', m);
      if (fails.length) bad++;
    }
    if (!ex.tests?.length && !ex.formal) {
      if (ex.solution && !ex.noSim) { // still has to compile
        const r = await compile(withLibs(ex.solution, ex.libs), { top: ex.top || 'top' });
        console.log(`${r.ok ? 'ok  ' : 'FAIL'} ${name}/${ex.id} (compile only)`);
        if (!r.ok) { bad++; console.log('   ', r.diags); }
      }
      continue;
    }
    n++;
    const t0 = Date.now();
    const sol = await check(ex, ex.solution);
    const failed = sol.filter(x => !x.pass);
    const st = ex.starterPasses ? [] : await check(ex, ex.starter);
    const starterPasses = st.length && st.every(x => x.pass);
    console.log(`${failed.length ? 'FAIL' : 'ok  '} ${name}/${ex.id} (${Date.now() - t0} ms)${starterPasses ? '  [warning: starter passes]' : ''}`);
    for (const x of failed) console.log('     ✗', x.name, '—', x.message);
    if (failed.length) bad++;
  }
}
console.log(`${n} exercises, ${bad} failing`);
process.exit(bad ? 1 : 0);
