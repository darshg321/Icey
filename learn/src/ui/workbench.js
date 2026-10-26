// The right-hand side of a lesson: editor + virtual board + tests + views.
import { createEditor } from './editor.js';
import { Board } from './board.js';
import { renderWaves } from './waves.js';
import { renderGates } from './gates.js';
import { renderChip } from './chip.js';
import { compileForSim, buildForIcey, runYosysScript, ICEY_PCF } from '../engine/toolchain.js';
import { Sim, simNetlist } from '../engine/sim.js';
import { runTests } from '../engine/tests.js';
import { progress } from '../progress.js';
import { wrapForIcey } from './wrap.js';
import { withLibs } from '../lib/index.js';

const TABS = ['board', 'tests', 'waves', 'gates', 'chip', 'log'];
const LABEL = { board: 'Board', tests: 'Tests', waves: 'Waves', gates: 'Gates', chip: 'Chip', log: 'Log' };

export class Workbench {
  constructor(root) {
    this.root = root;
    root.innerHTML = `
      <div class="wb-head">
        <div class="wb-title"></div>
        <span class="spacer"></span>
        <button class="run primary" title="Ctrl+Enter">Run</button>
      </div>
      <div class="wb-editor"></div>
      <div class="wb-tools">
        <button class="tiny reset-code">reset code</button>
        <button class="tiny show-solution">stuck? see a solution</button>
        <span class="spacer"></span>
        <button class="tiny build-icey" title="Synthesise for the real iCE40 and place-and-route it">build for Icey</button>
      </div>
      <div class="wb-tabs">${TABS.map(t => `<button data-tab="${t}">${LABEL[t]}</button>`).join('')}</div>
      <div class="wb-panels">${TABS.map(t => `<div class="wb-panel" data-panel="${t}"></div>`).join('')}</div>
      <div class="wb-status"></div>`;
    this.$ = s => root.querySelector(s);
    this.editor = createEditor(this.$('.wb-editor'), {
      onRun: () => this.run(),
      onChange: v => { if (this.ex) localStorage.setItem(`code:${this.ex.id}`, v); },
    });
    this.$('.run').onclick = () => this.run();
    this.$('.reset-code').onclick = () => {
      if (confirmInline(this.$('.reset-code'), 'really reset?')) this.editor.value = this.ex.starter;
    };
    this.$('.show-solution').onclick = () => this.showSolution();
    this.$('.build-icey').onclick = () => this.buildIcey();
    root.querySelectorAll('[data-tab]').forEach(b => b.onclick = () => this.tab(b.dataset.tab));
    this.panel = t => this.$(`[data-panel="${t}"]`);
  }

  tab(name) {
    this.currentTab = name;
    this.root.querySelectorAll('[data-tab]').forEach(b => b.classList.toggle('on', b.dataset.tab === name));
    this.root.querySelectorAll('[data-panel]').forEach(p => p.classList.toggle('on', p.dataset.panel === name));
    if (name === 'gates' && this.json && !this.gatesFor) this.drawGates();
  }

  load(ex) {
    if (this.board) this.board.destroy();
    this.ex = ex;
    this.json = null;
    this.gates = null;
    this.gatesFor = null;
    this.$('.wb-title').innerHTML = `<small>${ex.lessonTitle || ''}</small>${ex.title}`;
    // A project step starts from the learner's own design from the step
    // before (`carry`), once that step was passed, instead of the starter.
    const saved = localStorage.getItem(`code:${ex.id}`);
    const prev = ex.carry && saved == null && progress.isDone(ex.carry) ? localStorage.getItem(`code:${ex.carry}`) : null;
    this.editor.value = saved ?? prev ?? ex.starter;
    this.carried = prev != null;
    this.editor.showDiagnostics([]);
    this.$('.show-solution').style.display = ex.solution ? '' : 'none';
    this.$('.build-icey').style.display = ex.icey === false ? 'none' : '';
    for (const t of TABS) this.panel(t).innerHTML = '';
    const tabs = { board: !!(ex.board && ex.board.length), tests: !!(ex.tests && ex.tests.length), waves: true, gates: ex.gates !== false, chip: ex.icey !== false, log: true };
    this.root.querySelectorAll('[data-tab]').forEach(b => { b.style.display = tabs[b.dataset.tab] ? '' : 'none'; });
    this.board = new Board(this.panel('board'), ex.board || [], { clockPort: ex.clock?.port || 'clk', clockHz: ex.clock?.hz || 12e6 });
    this.board.onReset = () => this.restartSim();
    if (!ex.board?.length) this.panel('board').innerHTML = '';
    this.panel('tests').innerHTML = '<p class="muted">Press Run (or Ctrl+Enter) to check your design.</p>';
    this.panel('chip').innerHTML = `<p class="muted">“Build for Icey” runs the real toolchain on your code: Yosys maps it to the iCE40's lookup tables and flip-flops, then nextpnr places and routes it. The first build downloads about 25 MB, after that it's cached.</p>${ex.iceyNote ? `<p>${ex.iceyNote}</p>` : ''}`;
    this.panel('log').innerHTML = '<p class="muted">Yosys output shows up here.</p>';
    this.tab(ex.board?.length ? 'board' : ex.tests?.length ? 'tests' : 'waves');
    this.status(this.carried ? `This is your design from last session, where you left it. (<b>reset code</b> swaps in a fresh starter instead.)` : '');
    if (ex.autorun !== false && !this.carried && localStorage.getItem(`code:${ex.id}`) == null) this.run({ quiet: true });
  }

  status(html, kind = '') {
    const s = this.$('.wb-status');
    s.innerHTML = html;
    s.className = `wb-status ${kind}`;
  }

  async run({ quiet = false } = {}) {
    const ex = this.ex;
    const src = withLibs(this.editor.value, ex.libs);
    if (ex.formal) return this.runFormal(this.editor.value, quiet);
    if (ex.noSim) { if (!quiet) this.buildIcey(); return; } // uses real iCE40 blocks the simulator can't run
    this.$('.run').disabled = true;
    this.status('<span class="spin"></span> Synthesising with Yosys…');
    let r;
    try {
      r = await compileForSim(src, ex.top || 'top', p => {
        if (p.total) this.status(`<span class="spin"></span> ${p.stage}: ${(p.done / 1e6).toFixed(0)} / ${(p.total / 1e6).toFixed(0)} MB (first run only)`);
      }, ex.simParams);
    } catch (e) {
      this.status(`Toolchain error: ${e.message}`, 'bad');
      this.$('.run').disabled = false;
      return;
    }
    this.$('.run').disabled = false;
    if (this.ex !== ex) return;
    this.editor.showDiagnostics(r.diags);
    this.panel('log').innerHTML = `<pre class="log">${escapeHtml(trimLog(r.log))}</pre>`;
    const errs = r.diags.filter(d => d.severity === 'error');
    const warns = r.diags.filter(d => d.severity === 'warning');
    if (!r.ok) {
      this.status(`<b>Didn't compile.</b> ${errs.map(d => `${d.line ? `Line ${d.line}: ` : ''}${escapeHtml(d.message)}`).join('<br>') || 'See the Log tab.'}`, 'bad');
      if (!errs.length) this.tab('log');
      return;
    }
    this.json = r.json;
    this.simJson = simNetlist(r, ex.top || 'top');
    this.gatesFor = null;
    let sim;
    try {
      sim = new Sim(this.simJson, ex.top || 'top');
    } catch (e) {
      this.status(`<b>Can't simulate this.</b> ${escapeHtml(e.message)}`, 'bad');
      return;
    }
    const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;
    const gateNote = `${sim.lutCount ? `${sim.lutCount.toLocaleString()} lookup tables` : sim.gateCount ? plural(sim.gateCount, 'gate') : 'no gates (just wires)'}, ${plural(sim.ffCount, 'flip-flop')}${sim.mems.length ? `, ${sim.mems.length} memor${sim.mems.length > 1 ? 'ies' : 'y'}` : ''}`;
    const warnHtml = warns.length ? `<div class="warns">${warns.map(d => `⚠ ${d.line ? `line ${d.line}: ` : ''}${escapeHtml(d.message)}`).join('<br>')}</div>` : '';
    this.sim = sim;
    if (ex.board?.length) this.board.attach(sim);
    this.startGateUpdates();
    if (this.currentTab === 'gates') this.drawGates();

    if (!ex.tests?.length) {
      this.status(`Compiled: ${gateNote}.${warnHtml}`, 'ok');
      if (!quiet) this.tab(ex.board?.length ? 'board' : 'waves');
      if (ex.trace) this.trace(r.json);
      return;
    }
    this.status(`<span class="spin"></span> Running tests… (${gateNote})`);
    const list = document.createElement('ul');
    list.className = 'testlist';
    this.panel('tests').innerHTML = '';
    this.panel('tests').append(list);
    let testJson = this.simJson, testTop = ex.top || 'top';
    if ((ex.testTop && ex.testTop !== testTop) || ex.testParams) {
      // Tests can drive a submodule directly (e.g. the FSM without its clock
      // divider) and shrink its timing parameters.
      testTop = ex.testTop || testTop;
      const r2 = await compileForSim(src, testTop, null, ex.testParams);
      if (!r2.ok) {
        this.status(`<b>The tests need a module called <code>${testTop}</code>${ex.testParams ? ` with parameter${Object.keys(ex.testParams).length > 1 ? 's' : ''} ${Object.keys(ex.testParams).map(k => `<code>${k}</code>`).join(', ')}` : ''}.</b> ${escapeHtml(r2.diags.map(d => d.message).join(' '))}`, 'bad');
        return;
      }
      testJson = simNetlist(r2, testTop);
    }
    const extra = {};
    for (const name of ex.extraTops || []) {
      const r3 = await compileForSim(src, name, null);
      if (!r3.ok) {
        this.status(`<b>The tests need a module called <code>${name}</code>.</b> ${escapeHtml(r3.diags.map(d => d.message).join(' '))}`, 'bad');
        return;
      }
      extra[name] = simNetlist(r3, name);
    }
    const results = await runTests(testJson, testTop, ex, {
      src,
      extra,
      onResult: res => {
        const li = document.createElement('li');
        li.className = res.pass ? 'pass' : 'fail';
        li.innerHTML = `<b>${res.pass ? '✓' : '✗'}</b> ${escapeHtml(res.name)}${res.message ? `<div class="why">${escapeHtml(res.message)}</div>` : ''}`;
        if (res.wave) {
          li.style.cursor = 'pointer';
          li.title = 'Show the waveform for this test';
          li.onclick = () => { renderWaves(this.panel('waves'), res.wave, { title: res.name }); this.tab('waves'); };
        }
        list.append(li);
      },
    });
    if (this.ex !== ex) return;
    const failed = results.filter(x => !x.pass);
    if (failed.length) {
      this.status(`<b>${results.length - failed.length} of ${results.length} tests pass.</b> ${escapeHtml(failed[0].message || '')}${warnHtml}`, 'bad');
      if (failed[0].wave) renderWaves(this.panel('waves'), failed[0].wave, { title: `${failed[0].name} (failed)` });
      if (!quiet) this.tab('tests');
    } else {
      const first = !progress.isDone(ex.id) && !ex.chipTests;
      if (!ex.chipTests) progress.markDone(ex.id);
      this.status(`<b>All ${results.length} tests pass.</b> ${gateNote}.${ex.chipTests ? ' Now press <b>build for Icey</b> to check how it fits on the chip.' : ex.board?.length ? ' Try it on the board.' : ''}${warnHtml}`, 'ok');
      if (results[results.length - 1].wave) renderWaves(this.panel('waves'), results[results.length - 1].wave, { title: results[results.length - 1].name });
      if (!quiet) this.tab(ex.board?.length ? 'board' : 'tests');
      if (first && !quiet) this.onPass && this.onPass(ex);
    }
  }

  // Formal exercises: no simulation, Yosys proves (or disproves) properties.
  async runFormal(src, quiet) {
    const ex = this.ex;
    this.$('.run').disabled = true;
    this.status('<span class="spin"></span> Asking the solver…');
    const list = document.createElement('ul');
    list.className = 'testlist';
    this.panel('tests').innerHTML = '';
    this.panel('tests').append(list);
    let results;
    try {
      results = await ex.formal(src, (script, files) => runYosysScript(script, files));
    } catch (e) {
      results = [{ name: 'formal run', pass: false, message: e.message }];
    }
    this.$('.run').disabled = false;
    if (this.ex !== ex) return;
    const logs = results.filter(x => x.log).map(x => `===== ${x.name} =====\n${trimLog(x.log)}`).join('\n\n');
    this.panel('log').innerHTML = `<pre class="log">${escapeHtml(logs)}</pre>`;
    this.editor.showDiagnostics(results.flatMap(x => x.diags || []));
    for (const res of results) {
      const li = document.createElement('li');
      li.className = res.pass ? 'pass' : 'fail';
      li.innerHTML = `<b>${res.pass ? '✓' : '✗'}</b> ${escapeHtml(res.name)}${res.message ? `<div class="why">${escapeHtml(res.message)}</div>` : ''}`;
      if (res.wave) {
        li.style.cursor = 'pointer';
        li.onclick = () => { renderWaves(this.panel('waves'), res.wave, { title: res.name }); this.tab('waves'); };
      }
      list.append(li);
    }
    const failed = results.filter(x => !x.pass);
    if (failed.length) {
      this.status(`<b>${results.length - failed.length} of ${results.length} checks pass.</b> ${escapeHtml(failed[0].message || '')}`, 'bad');
      const cex = failed.find(x => x.wave);
      if (cex) { renderWaves(this.panel('waves'), cex.wave, { title: `counterexample: ${cex.name}` }); if (!quiet) this.tab('waves'); }
      else if (!quiet) this.tab('tests');
    } else {
      const first = !progress.isDone(ex.id);
      progress.markDone(ex.id);
      this.status(`<b>All ${results.length} checks pass.</b>`, 'ok');
      if (!quiet) this.tab('tests');
      if (first && !quiet) this.onPass && this.onPass(ex);
    }
  }

  restartSim() {
    if (!this.json) return;
    try {
      this.sim = new Sim(this.simJson, this.ex.top || 'top');
      this.board.attach(this.sim);
      this.startGateUpdates();
    } catch {}
  }

  async drawGates() {
    const json = this.json;
    this.gatesFor = json;
    try {
      this.gates = await renderGates(this.panel('gates'), json, this.ex.top || 'top');
    } catch (e) {
      this.panel('gates').innerHTML = `<p class="muted">Couldn't draw the gates: ${escapeHtml(e.message)}</p>`;
    }
  }

  startGateUpdates() {
    cancelAnimationFrame(this.gateFrame);
    const tick = () => {
      if (this.gates && this.sim && this.currentTab === 'gates') this.gates.update(this.sim);
      this.gateFrame = requestAnimationFrame(tick);
    };
    tick();
  }

  // Record a fixed run for exercises with no tests (shows up under Waves).
  trace(json) {
    const ex = this.ex;
    const sim = new Sim(this.simJson || json, ex.top || 'top');
    const names = ex.trace.signals.filter(n => sim.has(n));
    const samples = [];
    for (let i = 0; i < ex.trace.cycles; i++) {
      if (ex.trace.drive) ex.trace.drive(sim, i);
      sim.settle();
      samples.push(names.map(n => sim.get(n)));
      if (sim.has(ex.clock?.port || 'clk')) sim.tick(ex.clock?.port || 'clk');
    }
    renderWaves(this.panel('waves'), { names, widths: names.map(n => sim.signals[n].width), samples }, { title: `first ${ex.trace.cycles} clock cycles` });
  }

  async buildIcey() {
    const ex = this.ex;
    let src = withLibs(this.editor.value, ex.libs);
    let notes = [];
    if (ex.iceyWrap) src = ex.iceyWrap(src);
    else {
      const r = await compileForSim(src, ex.top || 'top').catch(() => null);
      const ports = r?.ok ? r.json.modules[ex.top || 'top'].ports : null;
      if (ports) {
        const w = wrapForIcey(src, ex.top || 'top', ports, ex.iceyClock, ICEY_PINS);
        src = w.src;
        notes = w.notes;
      }
    }
    this.tab('chip');
    this.panel('chip').innerHTML = '<p><span class="spin"></span> Building for the iCE40UP5K…</p>';
    const btn = this.$('.build-icey');
    btn.disabled = true;
    try {
      const res = await buildForIcey(src, ex.iceyTop || ex.top || 'top', p => {
        this.panel('chip').innerHTML = `<p><span class="spin"></span> ${p.stage}${p.total ? `: ${(p.done / 1e6).toFixed(0)} / ${(p.total / 1e6).toFixed(0)} MB` : '…'}</p>`;
      }, { dsp: ex.iceyDsp !== false });
      if (ex.iceyDsp === false) notes.push('This build leaves out Yosys\'s <code>-dsp</code> option, the way Icestudio does, so multiplications are built from logic cells instead of the hardware multipliers.');
      if (!res.ok) {
        const msg = res.diags.filter(d => d.severity === 'error').map(d => d.message).join('\n') || 'see the log';
        this.panel('chip').innerHTML = `<p class="bad">The build failed.</p><pre class="log">${escapeHtml(msg)}\n\n${escapeHtml(trimLog(res.pnrLog || res.log))}</pre>`;
      } else {
        renderChip(this.panel('chip'), res, { name: ex.id });
        if (ex.chipTests) this.chipTests(res);
        else if (ex.doneOn === 'build' && !progress.isDone(ex.id)) { progress.markDone(ex.id); this.onPass && this.onPass(ex); }
        if (notes.length) this.panel('chip').insertAdjacentHTML('afterbegin', `<div class="chip-notes">${notes.map(n => `<p>${n}</p>`).join('')}</div>`);
        this.panel('log').innerHTML = `<pre class="log">${escapeHtml(trimLog(res.log))}\n\n${escapeHtml(trimLog(res.pnrLog))}</pre>`;
      }
    } catch (e) {
      this.panel('chip').innerHTML = `<p class="bad">Toolchain error: ${escapeHtml(e.message)}</p>`;
    }
    btn.disabled = false;
  }

  // Checks on the real iCE40 build: logic cell counts, Fmax and so on.
  chipTests(res) {
    const ex = this.ex;
    const results = ex.chipTests.map(ct => {
      try { const msg = ct.check(res); return { name: ct.name, pass: !msg, message: msg || '' }; } catch (e) { return { name: ct.name, pass: false, message: e.message }; }
    });
    const box = document.createElement('ul');
    box.className = 'testlist';
    box.innerHTML = results.map(r => `<li class="${r.pass ? 'pass' : 'fail'}"><b>${r.pass ? '✓' : '✗'}</b> ${escapeHtml(r.name)}${r.message ? `<div class="why">${escapeHtml(r.message)}</div>` : ''}</li>`).join('');
    this.panel('chip').prepend(box);
    const failed = results.filter(r => !r.pass);
    if (failed.length) this.status(`<b>On the chip: ${results.length - failed.length} of ${results.length} checks pass.</b> ${escapeHtml(failed[0].message)}`, 'bad');
    else {
      this.status(`<b>On the chip: all ${results.length} checks pass.</b>`, 'ok');
      if (!progress.isDone(ex.id)) { progress.markDone(ex.id); this.onPass && this.onPass(ex); }
    }
  }

  showSolution() {
    const ex = this.ex;
    const box = document.createElement('div');
    box.className = 'solution-pop';
    box.innerHTML = `<p>Here's one way to do it. Yours doesn't have to match. If you're stuck, read it, close it, and write your own from memory; that sticks far better than pasting.</p><pre></pre>
      <div><button class="tiny use">put it in the editor</button> <button class="tiny close">close</button></div>`;
    box.querySelector('pre').textContent = ex.solution;
    box.querySelector('.close').onclick = () => box.remove();
    box.querySelector('.use').onclick = () => { this.editor.value = ex.solution; box.remove(); };
    this.root.append(box);
  }
}

const ICEY_PINS = new Set([...ICEY_PCF.matchAll(/set_io\s+(?:-\S+\s+)*([A-Za-z_]\w*)/g)].map(m => m[1]));

function confirmInline(btn, text) {
  if (btn.dataset.armed) { delete btn.dataset.armed; btn.textContent = btn.dataset.orig; return true; }
  btn.dataset.orig = btn.textContent;
  btn.dataset.armed = '1';
  btn.textContent = text;
  setTimeout(() => { if (btn.dataset.armed) { delete btn.dataset.armed; btn.textContent = btn.dataset.orig; } }, 3000);
  return false;
}

function trimLog(log = '') {
  return log.split("\n").slice(-400).join("\n");
}

export const escapeHtml = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
