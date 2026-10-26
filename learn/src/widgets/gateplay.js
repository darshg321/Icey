import { register } from './index.js';

const OPS = {
  AND: (a, b) => a & b, OR: (a, b) => a | b, XOR: (a, b) => a ^ b,
  NAND: (a, b) => 1 - (a & b), NOR: (a, b) => 1 - (a | b), XNOR: (a, b) => 1 - (a ^ b),
};
const SYM = { AND: 'a & b', OR: 'a | b', XOR: 'a ^ b', NAND: '~(a & b)', NOR: '~(a | b)', XNOR: '~(a ^ b)' };

register('gate-play', el => {
  let op = 'AND', a = 0, b = 0;
  el.innerHTML = `<div class="wtitle">Try the gates</div>
    <div class="row ops">${Object.keys(OPS).map(k => `<button data-op="${k}">${k}</button>`).join('')}</div>
    <div class="row" style="margin-top:12px;gap:24px;align-items:flex-start">
      <div class="row"><span>a</span><button class="bit" data-in="a">0</button><span>b</span><button class="bit" data-in="b">0</button>
        <span style="margin-left:10px">→</span><code class="expr"></code> = <b class="out" style="font-size:22px"></b></div>
      <table class="tt"></table>
    </div>`;
  const draw = () => {
    el.querySelectorAll('[data-op]').forEach(x => x.classList.toggle('primary', x.dataset.op === op));
    el.querySelector('[data-in=a]').textContent = a; el.querySelector('[data-in=a]').classList.toggle('on', !!a);
    el.querySelector('[data-in=b]').textContent = b; el.querySelector('[data-in=b]').classList.toggle('on', !!b);
    el.querySelector('.expr').textContent = SYM[op];
    el.querySelector('.out').textContent = OPS[op](a, b);
    let rows = '<tr><th>a</th><th>b</th><th>out</th></tr>';
    for (const [x, y] of [[0, 0], [0, 1], [1, 0], [1, 1]]) {
      const cur = x === a && y === b ? ' class="cur"' : '';
      rows += `<tr><td${cur}>${x}</td><td${cur}>${y}</td><td${cur}><b>${OPS[op](x, y)}</b></td></tr>`;
    }
    el.querySelector('.tt').innerHTML = rows;
  };
  el.querySelectorAll('[data-op]').forEach(x => x.onclick = () => { op = x.dataset.op; draw(); });
  el.querySelector('[data-in=a]').onclick = () => { a ^= 1; draw(); };
  el.querySelector('[data-in=b]').onclick = () => { b ^= 1; draw(); };
  draw();
});
