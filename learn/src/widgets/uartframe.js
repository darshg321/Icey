import { register } from './index.js';

// Draws the serial frame for a character the reader types.
register('uartframe', el => {
  el.innerHTML = `<div class="wtitle">One byte on the wire</div>
    <div class="row">character: <input maxlength="1" value="K" style="width:44px;font-size:18px;text-align:center;font-family:var(--mono)"> <span class="code small muted"></span></div>
    <svg viewBox="0 0 640 120" style="width:100%;margin-top:8px;background:#16171a;border-radius:6px"></svg>`;
  const input = el.querySelector('input');
  const svg = el.querySelector('svg');
  const draw = () => {
    const c = (input.value || ' ').charCodeAt(0) & 255;
    el.querySelector('.code').textContent = `= 0x${c.toString(16).padStart(2, '0')} = 8'b${c.toString(2).padStart(8, '0')}`;
    const bits = [1, 0, ...Array.from({ length: 8 }, (_, i) => (c >> i) & 1), 1, 1];
    const labels = ['idle', 'start', ...Array.from({ length: 8 }, (_, i) => `bit ${i}`), 'stop', 'idle'];
    const w = 640 / bits.length;
    let d = '', out = '';
    bits.forEach((b, i) => {
      const y = b ? 25 : 70;
      d += `${i ? 'L' : 'M'}${i * w},${y} L${(i + 1) * w},${y} `;
      const fill = i === 1 ? '#2b59c3' : i === 10 ? '#8fb4ff' : i > 1 && i < 10 ? '#8bd5a0' : '#8b8f97';
      out += `<line x1="${i * w}" y1="10" x2="${i * w}" y2="85" stroke="#2a2d33"/>`;
      out += `<text x="${i * w + w / 2}" y="104" text-anchor="middle" font-size="11" fill="${fill}" font-family="monospace">${labels[i]}</text>`;
      if (i > 1 && i < 10) out += `<text x="${i * w + w / 2}" y="52" text-anchor="middle" font-size="15" fill="#e7e7e9" font-family="monospace">${b}</text>`;
    });
    svg.innerHTML = `${out}<path d="${d}" fill="none" stroke="#8bd5a0" stroke-width="2.5"/>`;
  };
  input.oninput = draw;
  draw();
});
