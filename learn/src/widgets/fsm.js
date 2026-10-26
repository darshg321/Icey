import { register } from './index.js';

// A state diagram: states on a circle, arrows between them. Click a state
// to step the machine along its first outgoing edge.
register('fsm', (el, { states = [], edges = [], title = 'State diagram' }) => {
  const W = 520, H = 260, R = 34;
  const n = states.length;
  const pos = {};
  states.forEach((s, i) => {
    const a = -Math.PI / 2 + (2 * Math.PI * i) / n;
    pos[s] = { x: W / 2 + Math.cos(a) * 170, y: H / 2 + Math.sin(a) * 90 };
  });
  let cur = states[0];
  el.innerHTML = `<div class="wtitle">${title}</div><svg viewBox="0 0 ${W} ${H}" style="width:100%;max-width:560px"></svg>
    <div class="small muted">Click a state to follow its arrow. The highlighted state is where the machine is now.</div>`;
  const svg = el.querySelector('svg');
  const draw = () => {
    let out = `<defs><marker id="arr" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="#57534e"/></marker></defs>`;
    for (const [a, b, label] of edges) {
      const p = pos[a], q = pos[b];
      const dx = q.x - p.x, dy = q.y - p.y, d = Math.hypot(dx, dy);
      const ux = dx / d, uy = dy / d;
      const sx = p.x + ux * R, sy = p.y + uy * R, ex = q.x - ux * (R + 2), ey = q.y - uy * (R + 2);
      const mx = (sx + ex) / 2 - uy * 30, my = (sy + ey) / 2 + ux * 30;
      out += `<path d="M${sx},${sy} Q${mx},${my} ${ex},${ey}" fill="none" stroke="#57534e" stroke-width="1.6" marker-end="url(#arr)"/>`;
      out += `<text x="${mx}" y="${my}" text-anchor="middle" font-size="13" fill="#2b59c3" font-family="sans-serif">${label || ''}</text>`;
    }
    for (const s of states) {
      const p = pos[s];
      out += `<g data-s="${s}" style="cursor:pointer"><circle cx="${p.x}" cy="${p.y}" r="${R}" fill="${s === cur ? '#2b59c3' : '#fff'}" stroke="#1f6e2c" stroke-width="2"/>
        <text x="${p.x}" y="${p.y + 4}" text-anchor="middle" font-size="12" font-weight="700" fill="${s === cur ? '#fff' : '#1c1917'}" font-family="sans-serif">${s}</text></g>`;
    }
    svg.innerHTML = out;
    svg.querySelectorAll('[data-s]').forEach(g => g.onclick = () => {
      const e = edges.find(x => x[0] === g.dataset.s);
      cur = e ? e[1] : g.dataset.s;
      draw();
    });
  };
  draw();
});
