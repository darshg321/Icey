import { register } from './index.js';

const PRESETS = {
  'AND of all four': i => +(i === 15),
  'OR of all four': i => +(i !== 0),
  'XOR (parity)': i => [0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0][i],
  'is it prime?': i => +[2, 3, 5, 7, 11, 13].includes(i),
  'majority of I0, I1, I2': i => +(((i & 1) + ((i >> 1) & 1) + ((i >> 2) & 1)) >= 2),
  'all zero': () => 0,
};

// A 4-input lookup table: 16 bits of memory, the inputs pick one.
register('lut', el => {
  let mem = Array.from({ length: 16 }, (_, i) => PRESETS['is it prime?'](i));
  let inp = 5;
  el.innerHTML = `<div class="wtitle">Inside one iCE40 logic cell: a 4-input lookup table</div>
    <div class="row">inputs I3 I2 I1 I0: <span class="ins row"></span><span style="margin-left:12px">→ output</span> <b class="out" style="font-size:22px"></b></div>
    <div style="margin-top:12px" class="small muted">The LUT's 16 memory bits (click to change). The inputs form a 4-bit address that picks one:</div>
    <div class="row mem" style="gap:4px;margin-top:6px"></div>
    <div class="row" style="margin-top:10px;gap:6px"><span class="small muted">load a function:</span>${Object.keys(PRESETS).map(k => `<button class="tiny" data-p="${k}">${k}</button>`).join('')}</div>`;
  const ins = el.querySelector('.ins'), memEl = el.querySelector('.mem');
  for (let b = 3; b >= 0; b--) {
    const btn = document.createElement('button');
    btn.className = 'bit';
    btn.onclick = () => { inp ^= 1 << b; draw(); };
    btn.dataset.b = b;
    ins.append(btn);
  }
  for (let i = 0; i < 16; i++) {
    const c = document.createElement('div');
    c.style.textAlign = 'center';
    c.innerHTML = `<button class="bit" style="width:28px;height:28px;font-size:13px"></button><div class="small muted" style="font-size:10px">${i.toString(2).padStart(4, '0')}</div>`;
    c.querySelector('button').onclick = () => { mem[i] ^= 1; draw(); };
    memEl.append(c);
  }
  el.querySelectorAll('[data-p]').forEach(b => b.onclick = () => { mem = mem.map((_, i) => PRESETS[b.dataset.p](i)); draw(); });
  const draw = () => {
    ins.querySelectorAll('button').forEach(b => { const v = (inp >> +b.dataset.b) & 1; b.textContent = v; b.classList.toggle('on', !!v); });
    [...memEl.children].forEach((c, i) => {
      const b = c.querySelector('button');
      b.textContent = mem[i]; b.classList.toggle('on', !!mem[i]);
      c.style.outline = i === inp ? '3px solid #2b59c3' : 'none';
      c.style.borderRadius = '6px';
    });
    el.querySelector('.out').textContent = mem[inp];
  };
  draw();
});
