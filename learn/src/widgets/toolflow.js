import { register } from './index.js';
import { runYosysScript, buildForIcey } from '../engine/toolchain.js';
import { prelude, stripAnsi } from '../engine/yosys.js';

const DEFAULT = `module top(input clk, input BTN, output LED);
  reg [3:0] count = 0;
  always @(posedge clk)
    if (!BTN) count <= count + 1;
  assign LED = count[3];
endmodule`;

const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

// Runs the real toolchain on a small design and shows what each stage made.
register('toolflow', el => {
  el.innerHTML = `<div class="wtitle">Follow one design through the tools</div>
    <textarea spellcheck="false" style="width:100%;height:130px;font-family:var(--mono);font-size:13px;background:#16171a;color:#e7e7e9;border-radius:6px;padding:8px;border:none">${esc(DEFAULT)}</textarea>
    <div class="row" style="margin:8px 0"><button class="primary go">Run the toolchain</button><span class="st small muted"></span></div>
    <div class="row stages" style="gap:4px"></div>
    <div class="explain small" style="margin:10px 0 6px"></div>
    <pre class="out" style="display:none"></pre>`;
  const STAGES = [
    ['parse', '1. Parse', 'Yosys reads the text and builds a tree of the language constructs, then turns the always block into generic cells: a 4-bit register ($dff), an adder ($add), a multiplexer for the enable ($mux). Nothing here is specific to any chip yet.'],
    ['generic', '2. Generic gates', 'Every cell broken down into single-bit gates and flip-flops. This is the netlist the browser simulator runs, and what the Gates tab draws.'],
    ['ice40', '3. Mapped to iCE40', 'synth_ice40 rewrites the design using only parts the iCE40 actually has: SB_LUT4 (a 4-input lookup table), SB_DFF* (flip-flops, with enable/reset variants), SB_CARRY (the dedicated carry logic). Each LUT shows its 16-bit truth table as LUT_INIT.'],
    ['placed', '4. Placed and routed', 'nextpnr picks a physical logic cell for every LUT and flip-flop, then finds a path through the routing switches for every wire. The numbers are tile coordinates on the chip.'],
    ['bits', '5. Bitstream', 'icepack turns the placement into the configuration file. It starts with the sync word 7E AA 99 7E that tells the iCE40 a bitstream is coming, then a few commands, then tens of kilobytes of switch settings. Most of it is zeros: switches that stay open.'],
  ];
  const outs = {};
  const stagesEl = el.querySelector('.stages');
  let cur = null;
  const show = k => {
    cur = k;
    stagesEl.querySelectorAll('button').forEach(b => b.classList.toggle('primary', b.dataset.k === k));
    el.querySelector('.explain').textContent = STAGES.find(s => s[0] === k)[2];
    const pre = el.querySelector('.out');
    pre.style.display = '';
    pre.textContent = outs[k] ?? '(run the toolchain first)';
  };
  for (const [k, label] of STAGES) {
    const b = document.createElement('button');
    b.textContent = label; b.dataset.k = k; b.className = 'tiny';
    b.onclick = () => show(k);
    stagesEl.append(b);
  }
  el.querySelector('.go').onclick = async () => {
    const src = el.querySelector('textarea').value;
    const st = el.querySelector('.st');
    st.textContent = 'running Yosys…';
    try {
      const files = { 'design.v': prelude(src) };
      const a = await runYosysScript('read_verilog -sv design.v; hierarchy -top top; proc; opt_clean; write_verilog -noattr parsed.v', files);
      outs.parse = a.ok ? a.files['parsed.v'] : stripAnsi(a.log).slice(-2000);
      const b = await runYosysScript('read_verilog -sv design.v; hierarchy -top top; proc; flatten; opt; memory; opt; techmap; opt -fast; opt_clean -purge; write_verilog -noattr gates.v', files);
      outs.generic = b.ok ? b.files['gates.v'] : stripAnsi(b.log).slice(-2000);
      const c = await runYosysScript('read_verilog -sv design.v; synth_ice40 -top top; opt_clean -purge; write_verilog -noattr mapped.v', files);
      outs.ice40 = c.ok ? c.files['mapped.v'] : stripAnsi(c.log).slice(-2000);
      st.textContent = 'running nextpnr…';
      const r = await buildForIcey(src);
      if (r.ok) {
        outs.placed = r.cells.filter(x => x.bel).map(x => `${x.bel.padEnd(16)} ${x.type.padEnd(14)} ${x.type === 'ICESTORM_LC' ? `LUT=${(x.params.LUT_INIT || '').padStart(16, '0')} FF=${x.params.DFF_ENABLE} CARRY=${x.params.CARRY_ENABLE}` : ''}  ${x.name}`).join('\n') +
          `\n\n${(r.pnrLog.match(/Max frequency.*$/m) || [''])[0]}`;
        const bytes = r.bin;
        let hex = '';
        for (let i = 0; i < 256; i += 16) hex += i.toString(16).padStart(6, '0') + '  ' + Array.from(bytes.slice(i, i + 16), x => x.toString(16).padStart(2, '0')).join(' ') + '\n';
        const nonzero = bytes.reduce((n, x) => n + (x !== 0), 0);
        outs.bits = `${bytes.length} bytes, ${nonzero} of them non-zero. The first 256:\n\n${hex}`;
      } else {
        outs.placed = outs.bits = r.diags.map(d => d.message).join('\n');
      }
      st.textContent = `done: Yosys + nextpnr ran in your browser in ${((r.synthMs + (r.pnrMs || 0)) / 1000).toFixed(1)} s`;
      show(cur || 'parse');
    } catch (e) {
      st.textContent = e.message;
    }
  };
});
