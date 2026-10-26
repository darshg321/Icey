// Gate view: draws the simulator's own netlist with netlistsvg, then colours
// every 1-bit wire by its live value. What you see is exactly what runs.

const base = import.meta.env.BASE_URL;
let libP, skinP;
function loadLib() {
  const script = src => new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = base + src;
    s.onload = res;
    s.onerror = rej;
    document.head.append(s);
  });
  // netlistsvg's browser bundle expects ELK (its layout engine) as a global.
  libP ||= script('vendor/elk.bundled.js').then(() => script('vendor/netlistsvg.bundle.js')).then(() => window.netlistsvg);
  skinP ||= fetch(base + 'vendor/netlistsvg-skin.svg').then(r => r.text());
  return Promise.all([libP, skinP]);
}

export const GATE_LIMIT = 450;

export async function renderGates(root, json, top = 'top') {
  const mod = json.modules[top];
  const n = Object.keys(mod.cells).length;
  root.innerHTML = '';
  if (n > GATE_LIMIT) {
    root.innerHTML = `<p class="muted">This design is ${n} gates and flip-flops. That's too many to draw legibly (the limit here is ${GATE_LIMIT}), so the gate view is off. Try the Chip tab to see it laid out on the iCE40.</p>`;
    return null;
  }
  root.innerHTML = '<p class="muted">Laying out gates…</p>';
  const [lib, skin] = await loadLib();
  // Only the top module, and hide Yosys' internal names on wires.
  const clean = { modules: { [top]: { ...mod, attributes: { top: 1 } } } };
  const svgText = await lib.render(skin, clean);
  root.innerHTML = '';
  const holder = document.createElement('div');
  holder.className = 'gates-svg';
  holder.innerHTML = svgText;
  const counts = {};
  for (const c of Object.values(mod.cells)) {
    const t = c.type.replace(/^\$_?|_$/g, '').replace(/_[PN]$/, '').replace('_', '');
    counts[t] = (counts[t] || 0) + 1;
  }
  const legend = document.createElement('div');
  legend.className = 'gates-legend';
  legend.innerHTML = Object.entries(counts).map(([k, v]) => `<span><b>${v}</b> ${k}</span>`).join('') +
    '<span class="spacer"></span><span class="hint">green wire = 1</span>';
  root.append(legend, holder);

  // Map net id -> svg elements. netlistsvg classes wires as net_<bits joined by ,>.
  const byNet = new Map();
  for (const el of holder.querySelectorAll('[class*="net_"]')) {
    for (const cls of el.classList) {
      const m = cls.match(/^net_(\d+)$/);
      if (m) {
        const id = +m[1];
        if (!byNet.has(id)) byNet.set(id, []);
        byNet.get(id).push(el);
      }
    }
  }
  const svg = holder.querySelector('svg');
  if (svg) {
    const w = parseFloat(svg.getAttribute('width')) || 400, hgt = parseFloat(svg.getAttribute('height')) || 200;
    if (!svg.getAttribute('viewBox')) svg.setAttribute('viewBox', `-10 -10 ${w + 20} ${hgt + 20}`);
    svg.removeAttribute('width');
    svg.removeAttribute('height');
    // Small circuits get drawn big, big ones get the full panel and pan/zoom.
    holder.style.height = `${Math.round(Math.min(window.innerHeight * 0.6, Math.max(160, (hgt + 20) * Math.min(2.5, 560 / (w + 20)))))}px`;
    enablePanZoom(holder, svg);
  }
  const last = new Map();
  return {
    update(sim) {
      const v = sim.v;
      for (const [id, els] of byNet) {
        const x = v[id];
        if (last.get(id) === x) continue;
        last.set(id, x);
        for (const el of els) el.classList.toggle('hi', x === 1);
      }
    },
  };
}

function enablePanZoom(holder, svg) {
  const vb = svg.viewBox.baseVal;
  if (!vb || !vb.width) return;
  let { x, y, width, height } = vb;
  const apply = () => svg.setAttribute('viewBox', `${x} ${y} ${width} ${height}`);
  holder.addEventListener('wheel', e => {
    e.preventDefault();
    const k = e.deltaY > 0 ? 1.15 : 1 / 1.15;
    const r = svg.getBoundingClientRect();
    const fx = (e.clientX - r.left) / r.width, fy = (e.clientY - r.top) / r.height;
    const nw = width * k, nh = height * k;
    x += (width - nw) * fx; y += (height - nh) * fy;
    width = nw; height = nh;
    apply();
  }, { passive: false });
  let drag = null;
  holder.addEventListener('pointerdown', e => { drag = { sx: e.clientX, sy: e.clientY, x, y }; holder.setPointerCapture(e.pointerId); });
  holder.addEventListener('pointermove', e => {
    if (!drag) return;
    const r = svg.getBoundingClientRect();
    x = drag.x - (e.clientX - drag.sx) * width / r.width;
    y = drag.y - (e.clientY - drag.sy) * height / r.height;
    apply();
  });
  holder.addEventListener('pointerup', () => { drag = null; });
}
