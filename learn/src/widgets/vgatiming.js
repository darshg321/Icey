import { register } from './index.js';

// One VGA line and one frame drawn to scale.
register('vgatiming', el => {
  const seg = (parts, total, y, label) => {
    const small = [];
    let x = 0, out = `<text x="0" y="${y - 8}" font-size="12" font-weight="700" fill="#1c1917">${label}</text>`;
    for (const [n, name, col] of parts) {
      const w = (n / total) * 600;
      out += `<rect x="${x}" y="${y}" width="${w}" height="26" fill="${col}" stroke="#fff"/>`;
      if (w > 52) out += `<text x="${x + w / 2}" y="${y + 17}" text-anchor="middle" font-size="11" fill="#fff">${name} ${n}</text>`;
      else small.push(`${name} ${n}`);
      x += w;
    }
    if (small.length) out += `<text x="600" y="${y + 42}" text-anchor="end" font-size="11" fill="#57534e">narrow parts, left to right: ${small.join(', ')}</text>`;
    return out;
  };
  const line = [[640, 'visible', '#2b59c3'], [16, 'front porch', '#8b8f97'], [96, 'sync', '#2b59c3'], [48, 'back porch', '#8b8f97']];
  const frame = [[480, 'visible lines', '#2b59c3'], [10, 'front porch', '#8b8f97'], [2, 'sync', '#2b59c3'], [33, 'back porch', '#8b8f97']];
  el.innerHTML = `<div class="wtitle">640×480 at 60 Hz, to scale</div>
    <svg viewBox="0 0 600 150" style="width:100%" font-family="sans-serif">
      ${seg(line, 800, 22, 'One line: 800 pixel clocks (31.5 kHz)')}
      ${seg(frame, 525, 95, 'One frame: 525 lines (60 Hz)')}
    </svg>`;
});
