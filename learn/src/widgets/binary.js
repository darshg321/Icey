import { register } from './index.js';

register('binary', el => {
  let v = 0xa5;
  el.innerHTML = `<div class="wtitle">Bits and numbers</div>
    <div class="row bits"></div>
    <div class="row" style="margin-top:12px;gap:18px;font-family:var(--mono);font-size:15px">
      <span>decimal <b class="d"></b></span><span>hex <b class="h"></b></span><span><b class="lit"></b></span>
    </div>
    <div class="small muted" style="margin-top:6px">Click the bits. Each one is worth twice the one to its right.</div>`;
  const bits = el.querySelector('.bits');
  for (let i = 7; i >= 0; i--) {
    const cell = document.createElement('div');
    cell.style.textAlign = 'center';
    cell.innerHTML = `<button class="bit"></button><div class="small muted">${2 ** i}</div><div class="small muted">[${i}]</div>`;
    cell.querySelector('button').onclick = () => { v ^= 1 << i; draw(); };
    bits.append(cell);
  }
  const draw = () => {
    [...bits.children].forEach((c, k) => {
      const i = 7 - k, on = (v >> i) & 1;
      const b = c.querySelector('button');
      b.textContent = on; b.classList.toggle('on', !!on);
      if (k === 4) c.style.marginLeft = '12px';
    });
    el.querySelector('.d').textContent = v;
    el.querySelector('.h').textContent = v.toString(16).toUpperCase().padStart(2, '0');
    el.querySelector('.lit').textContent = `8'b${v.toString(2).padStart(8, '0').replace(/(....)(....)/, '$1_$2')}`;
  };
  draw();
});
