// Chip view: where nextpnr put your design on the iCE40UP5K, what each
// logic cell's lookup table holds, and how fast it can run.
import { uploadToIcey, webUsbSupported } from '../engine/webusb.js';

const W = 26, H = 32; // UP5K tile grid

export function renderChip(root, res, { name = 'design' } = {}) {
  root.innerHTML = '';
  const u = res.report?.utilization || {};
  const use = k => u[k] ? `${u[k].used} / ${u[k].available}` : '0';
  const pct = k => u[k] ? (100 * u[k].used / u[k].available) : 0;
  const fmax = Object.entries(res.report?.fmax || {}).map(([clk, f]) =>
    `<div class="fmax ${f.achieved >= f.constraint ? 'ok' : 'bad'}"><b>${f.achieved.toFixed(1)} MHz</b> max for <code>${clk.replace(/^.*\./, '')}</code> (needs ${f.constraint.toFixed(1)})</div>`).join('') ||
    '<div class="fmax">No clocked paths, so there is no maximum frequency to report.</div>';

  const top = document.createElement('div');
  top.className = 'chip-top';
  top.innerHTML = `
    <div class="util">
      ${bar('Logic cells', use('ICESTORM_LC'), pct('ICESTORM_LC'))}
      ${bar('Block RAM (4 kbit)', use('ICESTORM_RAM'), pct('ICESTORM_RAM'))}
      ${bar('DSP multipliers', use('ICESTORM_DSP'), pct('ICESTORM_DSP'))}
      ${bar('I/O pins', use('SB_IO'), pct('SB_IO'))}
      ${fmax}
      <div class="muted small">Yosys ${(res.synthMs / 1000).toFixed(1)} s · nextpnr ${(res.pnrMs / 1000).toFixed(1)} s · bitstream ${(res.bin.length / 1024).toFixed(0)} KB</div>
      <div class="chip-actions"></div>
    </div>
    <div class="chip-detail"><p class="muted">Click a cell on the chip to look inside it.</p></div>`;
  root.append(top);

  const actions = top.querySelector('.chip-actions');
  const dl = document.createElement('button');
  dl.textContent = 'Download .bin';
  dl.onclick = () => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([res.bin], { type: 'application/octet-stream' }));
    a.download = `${name}.bin`;
    a.click();
  };
  actions.append(dl);
  if (webUsbSupported()) {
    const up = document.createElement('button');
    up.className = 'primary';
    up.textContent = 'Upload to Icey (USB)';
    const msg = document.createElement('div');
    msg.className = 'small muted';
    up.onclick = async () => {
      up.disabled = true;
      msg.textContent = 'Connecting…';
      try {
        const ok = await uploadToIcey(res.bin, s => { msg.textContent = s; });
        msg.textContent = ok ? 'Configured: CDONE went high and the design is running.' : 'Sent the bitstream, but CDONE stayed low. Check the build and try again.';
      } catch (e) {
        msg.textContent = e.message;
      }
      up.disabled = false;
    };
    actions.append(up, msg);
  } else {
    const p = document.createElement('div');
    p.className = 'small muted';
    p.innerHTML = 'Load it with <code>python iceyprog.py sram design.bin</code>. (Chrome or Edge can upload straight from this page.)';
    actions.append(p);
  }

  // --- floorplan ---
  const tiles = new Map();
  const kinds = { lc: 0, ram: 0, dsp: 0, io: 0 };
  for (const c of res.cells || []) {
    const m = c.bel && c.bel.match(/^X(\d+)\/Y(\d+)\/(\w+?)(\d*)$/);
    if (!m) continue;
    const key = `${m[1]},${m[2]}`;
    if (!tiles.has(key)) tiles.set(key, []);
    tiles.get(key).push({ ...c, x: +m[1], y: +m[2], kind: m[3], idx: +m[4] || 0 });
  }
  const S = 22;
  const svgNS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(svgNS, 'svg');
  svg.setAttribute('viewBox', `-4 -4 ${W * S + 8} ${H * S + 8}`);
  svg.classList.add('floorplan');
  const add = (tag, attrs, parent = svg) => {
    const el = document.createElementNS(svgNS, tag);
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
    parent.append(el);
    return el;
  };
  const px = x => x * S, py = y => (H - 1 - y) * S;
  for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
    const edgeY = y === 0 || y === H - 1;
    const edgeX = x === 0 || x === W - 1;
    const cls = edgeY ? 'io' : edgeX ? 'dsp' : x === 6 || x === 19 ? 'ramcol' : 'logic';
    add('rect', { x: px(x) + 1, y: py(y) + 1, width: S - 2, height: S - 2, class: `tile ${cls}` });
  }
  const detail = top.querySelector('.chip-detail');
  for (const list of tiles.values()) {
    for (const c of list) {
      let el;
      if (c.kind === 'lc') {
        const col = c.idx;
        const lutUsed = c.params.LUT_INIT && /1/.test(c.params.LUT_INIT);
        const ff = c.params.DFF_ENABLE === '1';
        const carry = c.params.CARRY_ENABLE === '1';
        el = add('rect', {
          x: px(c.x) + 3, y: py(c.y) + 2 + col * 2.25, width: S - 6, height: 1.9,
          class: `cell lc ${ff ? 'ff' : ''} ${carry ? 'carry' : ''} ${lutUsed ? '' : 'nolut'}`,
        });
        kinds.lc++;
      } else {
        const k = /ram/.test(c.kind) ? 'ram' : /dsp|mac/.test(c.type.toLowerCase()) ? 'dsp' : /io/.test(c.kind) ? 'io' : 'other';
        el = add('rect', { x: px(c.x) + 2, y: py(c.y) + 2, width: S - 4, height: S - 4, class: `cell ${k}` });
        if (kinds[k] !== undefined) kinds[k]++;
      }
      el.addEventListener('click', () => showCell(detail, c));
      const title = document.createElementNS(svgNS, 'title');
      title.textContent = `${c.type} at ${c.bel}\n${c.name}`;
      el.append(title);
    }
  }
  // critical path
  const cp = res.report?.critical_paths?.[0];
  if (cp) {
    const pts = [];
    for (const step of cp.path) for (const end of [step.from, step.to]) {
      if (!end?.loc) continue;
      const p = `${px(end.loc[0]) + S / 2},${py(end.loc[1]) + S / 2}`;
      if (pts[pts.length - 1] !== p) pts.push(p);
    }
    if (pts.length > 1) add('polyline', { points: pts.join(' '), class: 'critpath' });
  }
  const fp = document.createElement('div');
  fp.className = 'floorplan-wrap';
  fp.append(svg);
  const key = document.createElement('div');
  key.className = 'fp-key small';
  key.innerHTML = '<span class="k lc"></span>LUT only <span class="k lc ff"></span>LUT + flip-flop <span class="k lc carry"></span>carry chain <span class="k ram"></span>block RAM <span class="k io"></span>pin <span class="k crit"></span>slowest path';
  root.append(key, fp);
}

function bar(label, text, p) {
  return `<div class="ubar"><span>${label}</span><span class="b"><i style="width:${Math.max(p, p > 0 ? 1 : 0)}%"></i></span><span>${text}</span></div>`;
}

function showCell(detail, c) {
  let html = `<h4>${c.type} <small>${c.bel}</small></h4><div class="small muted">${escapeHtml(c.name)}</div>`;
  if (c.src) {
    const lines = [...new Set(c.src.split('|').map(s => s.match(/design\.v:(\d+)/)?.[1]).filter(Boolean))];
    if (lines.length) html += `<div class="small">from line ${lines.join(', ')} of your code</div>`;
  }
  if (c.kind === 'lc' && c.params.LUT_INIT) {
    const init = c.params.LUT_INIT.padStart(16, '0');
    html += `<p class="small">A 4-input lookup table is 16 bits of memory. The four inputs pick one bit; that bit is the output. This one's contents are <code>16'b${init}</code>:</p>`;
    html += '<table class="lut"><tr><th>I3</th><th>I2</th><th>I1</th><th>I0</th><th>O</th></tr>';
    for (let i = 0; i < 16; i++) {
      const o = init[15 - i];
      html += `<tr class="${o === '1' ? 'one' : ''}"><td>${i >> 3 & 1}</td><td>${i >> 2 & 1}</td><td>${i >> 1 & 1}</td><td>${i & 1}</td><td>${o}</td></tr>`;
    }
    html += '</table>';
    html += `<div class="small">Flip-flop after the LUT: <b>${c.params.DFF_ENABLE === '1' ? 'used' : 'bypassed'}</b>. Carry logic: <b>${c.params.CARRY_ENABLE === '1' ? 'used' : 'off'}</b>.</div>`;
  }
  detail.innerHTML = html;
}

const escapeHtml = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
