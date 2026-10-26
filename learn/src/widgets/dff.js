import { register } from './index.js';

// Hands-on D flip-flop: change D whenever you like, Q only follows on a clock edge.
register('dff', el => {
  let d = 0, q = 0, clk = 0;
  const hist = [{ clk: 0, d: 0, q: 0 }];
  el.innerHTML = `<div class="wtitle">A D flip-flop</div>
    <div class="row">
      <span>D</span><button class="bit dbtn">0</button>
      <button class="edge primary">clock edge ↑</button>
      <span style="margin-left:12px">Q =</span><b class="q" style="font-size:22px">0</b>
    </div>
    <svg class="trace" height="110" style="width:100%;margin-top:10px"></svg>
    <div class="small muted">Flip D as often as you like. Q only changes when you press the clock edge.</div>`;
  const svg = el.querySelector('.trace');
  const draw = () => {
    el.querySelector('.dbtn').textContent = d;
    el.querySelector('.dbtn').classList.toggle('on', !!d);
    el.querySelector('.q').textContent = q;
    const W = svg.clientWidth || 600, step = Math.min(40, (W - 50) / Math.max(hist.length, 12));
    const row = (name, y, key) => {
      let p = '';
      hist.forEach((hh, i) => { const yy = hh[key] ? y : y + 20; p += `${i ? 'L' : 'M'}${40 + i * step},${yy} L${40 + (i + 1) * step},${yy} `; });
      return `<text x="0" y="${y + 15}" font-size="13" font-family="monospace">${name}</text><path d="${p}" fill="none" stroke="${key === 'q' ? '#2b59c3' : '#1f6e2c'}" stroke-width="2"/>`;
    };
    svg.innerHTML = row('clk', 2, 'clk') + row('D', 40, 'd') + row('Q', 78, 'q');
  };
  const push = () => { hist.push({ clk, d, q }); if (hist.length > 40) hist.shift(); draw(); };
  el.querySelector('.dbtn').onclick = () => { d ^= 1; push(); };
  el.querySelector('.edge').onclick = () => {
    clk = 1; q = d; push();
    setTimeout(() => { clk = 0; push(); }, 250);
  };
  draw();
});
