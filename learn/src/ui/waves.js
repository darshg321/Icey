// Waveform viewer. `wave` = {names, widths, samples: [[v0, v1, ...], ...], marks}
// One column per sample (a sample is taken after every input change and every
// clock tick), so this reads like a logic analyser capture.

export function renderWaves(root, wave, { title, highlight } = {}) {
  root.innerHTML = '';
  if (!wave || !wave.samples.length) {
    root.innerHTML = '<p class="muted">Nothing recorded yet. Run the tests to capture a waveform.</p>';
    return;
  }
  const { names, widths, samples } = wave;
  const fmt = localStorage.getItem('wave-radix') || 'dec';
  const head = document.createElement('div');
  head.className = 'wave-head';
  head.innerHTML = `<span>${title || ''}</span><span class="spacer"></span>
    <label>values <select><option value="dec">decimal</option><option value="hex">hex</option><option value="bin">binary</option></select></label>
    <button class="tiny" data-z="-1">−</button><button class="tiny" data-z="1">+</button>`;
  const sel = head.querySelector('select');
  sel.value = fmt;
  root.append(head);

  const wrap = document.createElement('div');
  wrap.className = 'wave-wrap';
  const labels = document.createElement('div');
  labels.className = 'wave-labels';
  const scroller = document.createElement('div');
  scroller.className = 'wave-scroll';
  const canvas = document.createElement('canvas');
  scroller.append(canvas);
  wrap.append(labels, scroller);
  root.append(wrap);

  const ROW = 30, PAD = 8;
  let px = Math.max(6, Math.min(40, Math.floor(900 / samples.length)));
  for (const n of names) {
    const d = document.createElement('div');
    d.textContent = n + (widths[names.indexOf(n)] > 1 ? `[${widths[names.indexOf(n)] - 1}:0]` : '');
    d.style.height = ROW + 'px';
    if (highlight && highlight.includes(n)) d.classList.add('hl');
    labels.append(d);
  }
  labels.style.paddingTop = '18px';

  const show = (v, w) => {
    const r = sel.value;
    if (r === 'hex') return v.toString(16);
    if (r === 'bin') return v.toString(2).padStart(w, '0');
    return String(v);
  };

  function draw() {
    const dpr = window.devicePixelRatio || 1;
    const W = samples.length * px + PAD * 2, H = names.length * ROW + 20;
    canvas.width = W * dpr; canvas.height = H * dpr;
    canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
    const g = canvas.getContext('2d');
    g.scale(dpr, dpr);
    g.fillStyle = '#16171a';
    g.fillRect(0, 0, W, H);
    g.font = '11px ' + getComputedStyle(document.body).getPropertyValue('--mono');
    // time ruler
    g.fillStyle = '#5c6068';
    const every = Math.max(1, Math.ceil(50 / px));
    for (let i = 0; i < samples.length; i += every) {
      g.fillRect(PAD + i * px, 12, 1, H);
      g.fillText(String(i), PAD + i * px + 2, 10);
    }
    for (const m of wave.marks || []) {
      g.fillStyle = '#e5b450';
      g.fillRect(PAD + m.at * px, 0, 1, H);
      g.fillText(m.label, PAD + m.at * px + 3, 10);
    }
    names.forEach((n, r) => {
      const y0 = 20 + r * ROW, hi = y0 + 5, lo = y0 + ROW - 7;
      const w = widths[r];
      g.strokeStyle = w === 1 ? '#8bd5a0' : '#8fb4ff';
      g.lineWidth = 1.5;
      if (w === 1) {
        g.beginPath();
        samples.forEach((s, i) => {
          const y = s[r] ? hi : lo;
          if (i === 0) g.moveTo(PAD, y); else g.lineTo(PAD + i * px, y);
          g.lineTo(PAD + (i + 1) * px, y);
        });
        g.stroke();
      } else {
        let start = 0;
        const seg = (a, b) => {
          const x0 = PAD + a * px, x1 = PAD + b * px, mid = (hi + lo) / 2;
          g.beginPath();
          g.moveTo(x0, mid); g.lineTo(x0 + 2, hi); g.lineTo(x1 - 2, hi); g.lineTo(x1, mid);
          g.lineTo(x1 - 2, lo); g.lineTo(x0 + 2, lo); g.closePath(); g.stroke();
          const text = show(samples[a][r], w);
          if (g.measureText(text).width < x1 - x0 - 6) {
            g.fillStyle = '#e7e7e9';
            g.fillText(text, x0 + 4, mid + 4);
          }
        };
        for (let i = 1; i <= samples.length; i++) {
          if (i === samples.length || samples[i][r] !== samples[start][r]) { seg(start, i); start = i; }
        }
      }
    });
    if (wave.truncated) {
      g.fillStyle = '#e5b450';
      g.fillText('… (capture full)', W - 110, H - 4);
    }
  }
  draw();
  sel.onchange = () => { localStorage.setItem('wave-radix', sel.value); draw(); };
  head.querySelectorAll('[data-z]').forEach(b => b.onclick = () => {
    px = Math.max(2, Math.min(80, b.dataset.z === '1' ? px * 1.5 : px / 1.5));
    draw();
  });
  scroller.scrollLeft = Math.max(0, canvas.width);
}
