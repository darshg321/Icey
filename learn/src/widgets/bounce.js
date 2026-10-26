import { register } from './index.js';

// A fake oscilloscope trace of a button press, different every time.
register('bounce', el => {
  el.innerHTML = `<div class="wtitle">What the FPGA pin sees during one press</div>
    <svg viewBox="0 0 600 130" style="width:100%;background:#16171a;border-radius:6px"></svg>
    <div class="row small muted" style="margin-top:6px"><span>A few milliseconds of a button going down (3.3 V to 0 V). Each edge here would count as a press.</span><span class="spacer"></span><button class="again tiny">press again</button></div>`;
  const svg = el.querySelector('svg');
  const draw = () => {
    let x = 40, v = 1, d = 'M0,20 L40,20';
    const edges = [];
    while (x < 330) {
      x += 4 + Math.random() * (v ? 30 : 22) * (1 - (x - 40) / 400);
      d += ` L${x},${v ? 20 : 105}`;
      v ^= 1;
      d += ` L${x},${v ? 20 : 105}`;
      edges.push(x);
    }
    if (v) { d += ` L${x + 6},20 L${x + 6},105`; }
    d += ' L600,105';
    let grid = '';
    for (let gx = 0; gx <= 600; gx += 60) grid += `<line x1="${gx}" y1="0" x2="${gx}" y2="130" stroke="#2a2d33"/>`;
    svg.innerHTML = `${grid}<path d="${d}" fill="none" stroke="#8bd5a0" stroke-width="2"/>
      <text x="8" y="14" fill="#8b8f97" font-size="11" font-family="monospace">3.3 V</text>
      <text x="8" y="122" fill="#8b8f97" font-size="11" font-family="monospace">0 V</text>
      <text x="420" y="60" fill="#e5b450" font-size="13" font-family="monospace">${edges.length} edges</text>
      <text x="420" y="78" fill="#8b8f97" font-size="11" font-family="monospace">1 grid square ≈ 0.5 ms</text>`;
  };
  el.querySelector('.again').onclick = draw;
  draw();
});
