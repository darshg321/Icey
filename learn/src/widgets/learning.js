// The learning blocks lessons are built from (see markdown.js):
//   resource   a reading/exercise from elsewhere, opened in the side reader
//   recall     retrieval practice: answer from memory, then check yourself;
//              "not yet" puts a question on a review list that comes back later
//   predict    write down what you think will happen before seeing it
//   parsons    put scrambled lines of code in order
//   reflect    explain something in your own words (kept in this browser)
//   sidequest  optional practice that goes beyond the project
import { marked } from 'marked';
import { register } from './index.js';
import { progress } from '../progress.js';

const md = s => marked.parse(s || '');
const mdi = s => marked.parseInline(s || '');
const hash = s => { let h = 5381; for (const c of s) h = ((h * 33) ^ c.charCodeAt(0)) >>> 0; return h.toString(36); };
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// "key: value" lines; a line without a key continues the previous value.
function fields(src) {
  const out = {};
  let key = null;
  for (const line of src.split('\n')) {
    const m = line.match(/^(\w+):\s?(.*)$/);
    if (m) { key = m[1]; out[key] = m[2]; } else if (key) out[key] += '\n' + line;
  }
  return out;
}

// Blocks separated by blank lines.
const blocks = src => src.split(/\n\s*\n/).map(b => b.trim()).filter(Boolean);

// Q:/A: pairs; each may run over several lines.
function qa(src) {
  const items = [];
  let cur = null, part = null;
  for (const line of src.split('\n')) {
    const m = line.match(/^(Q|A|From):\s?(.*)$/);
    if (m && m[1] === 'Q') { cur = { q: m[2], a: '', from: '' }; items.push(cur); part = 'q'; }
    else if (m && cur) { part = m[1] === 'A' ? 'a' : 'from'; cur[part] = m[2]; }
    else if (cur && part) cur[part] += '\n' + line;
  }
  return items;
}

export const openReader = (url, title) => window.dispatchEvent(new CustomEvent('icey:read', { detail: { url, title } }));

register('resource', (el, { src }) => {
  const f = fields(src);
  const id = `res:${f.url}`;
  el.innerHTML = `
    <div class="res-main">
      <div class="res-meta">${esc(f.source || new URL(f.url).hostname)}${f.time ? ` · ${esc(f.time)}` : ''}</div>
      <div class="res-title">${esc(f.title)}</div>
      ${f.do ? `<div class="res-do">${mdi(f.do)}</div>` : ''}
    </div>
    <div class="res-actions">
      <button class="read">Open</button>
      <a class="ext" href="${esc(f.url)}" target="_blank" rel="noopener" title="Open in a new tab">↗</a>
      <label class="res-check" title="Mark as done"><input type="checkbox"> done</label>
    </div>`;
  const box = el.querySelector('input');
  box.checked = progress.isDone(id);
  el.classList.toggle('done', box.checked);
  box.onchange = () => { box.checked ? progress.markDone(id) : progress.unmark(id); el.classList.toggle('done', box.checked); };
  el.querySelector('.read').onclick = () => openReader(f.url, f.title);
});

// ---- retrieval practice with a review list ----
const REVIEW = 'icey-review';
const review = {
  all: () => { try { return JSON.parse(localStorage.getItem(REVIEW)) || {}; } catch { return {}; } },
  save(v) { localStorage.setItem(REVIEW, JSON.stringify(v)); },
  add(item) { const v = review.all(); v[hash(item.q)] = { ...item, added: Date.now() }; review.save(v); },
  remove(q) { const v = review.all(); delete v[hash(q)]; review.save(v); },
};

function recallItem(item, { predict = false } = {}) {
  const div = document.createElement('div');
  div.className = 'rq';
  div.innerHTML = `
    <div class="rq-q">${md(item.q)}</div>
    ${predict ? '<textarea class="guess" rows="2" placeholder="Your prediction, before you look"></textarea>' : ''}
    <div class="rq-actions"><button class="show">${predict ? 'Check my prediction' : 'Show answer'}</button></div>
    <div class="rq-a" hidden>${md(item.a)}${item.from ? `<div class="rq-from">${mdi(item.from)}</div>` : ''}</div>
    <div class="rq-rate" hidden><span>Did you have it?</span><button class="yes">Yes</button><button class="no">Not yet</button></div>`;
  const show = div.querySelector('.show');
  const guess = div.querySelector('.guess');
  if (guess) {
    const key = `predict:${hash(item.q)}`;
    guess.value = localStorage.getItem(key) || '';
    show.disabled = !guess.value.trim();
    guess.oninput = () => { show.disabled = !guess.value.trim(); localStorage.setItem(key, guess.value); };
  }
  show.onclick = () => {
    div.querySelector('.rq-a').hidden = false;
    div.querySelector('.rq-rate').hidden = false;
    show.hidden = true;
    if (guess) guess.readOnly = true;
  };
  const rate = ok => {
    div.querySelector('.rq-rate').innerHTML = ok ? '<span class="good">Good. It won’t come back unless you miss it later.</span>' : '<span>Added to your review list; it will come back in a later session.</span>';
    if (ok) review.remove(item.q); else review.add(item);
  };
  div.querySelector('.yes').onclick = () => rate(true);
  div.querySelector('.no').onclick = () => rate(false);
  return div;
}

register('recall', (el, { src }) => {
  const items = qa(src);
  el.innerHTML = `<div class="wtitle">Warm-up · from memory</div><p class="whint">Answer each one in your head (or on paper) before you look. Trying to remember is what makes it stick, even when you get it wrong.</p>`;
  for (const it of items) el.append(recallItem(it));
  // Spaced review: bring back up to 3 questions marked "not yet" elsewhere.
  const here = new Set(items.map(i => hash(i.q)));
  const due = Object.entries(review.all()).filter(([k]) => !here.has(k)).sort((a, b) => a[1].added - b[1].added).slice(0, 3);
  if (due.length) {
    const h = document.createElement('div');
    h.className = 'wtitle';
    h.textContent = 'From your review list';
    el.append(h);
    for (const [, it] of due) el.append(recallItem(it));
  }
});

register('predict', (el, { src }) => {
  el.innerHTML = '<div class="wtitle">Predict</div>';
  for (const it of qa(src)) el.append(recallItem(it, { predict: true }));
});

register('parsons', (el, { src }) => {
  const [prompt, code] = src.split(/\n---\n/);
  const answer = code.replace(/\n+$/, '').split('\n');
  const id = `parsons:${hash(code)}`;
  // a fixed shuffle (seeded by the code) that is never the answer itself
  let seed = parseInt(hash(code), 36) || 1;
  const rnd = () => (seed = (seed * 1103515245 + 12345) >>> 0) / 2 ** 32;
  let order = answer.map((_, i) => i);
  do { for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; } }
  while (order.every((v, i) => answer[v] === answer[i]) && answer.length > 1);
  el.innerHTML = `<div class="wtitle">Put the lines in order</div><div class="pp">${md(prompt)}</div><ol class="plines"></ol>
    <div class="rq-actions"><button class="check">Check</button><span class="pmsg"></span></div>`;
  const list = el.querySelector('.plines');
  let picked = null;
  const draw = () => {
    list.innerHTML = '';
    order.forEach((li, pos) => {
      const row = document.createElement('li');
      row.className = picked === pos ? 'picked' : '';
      row.innerHTML = `<code></code><span class="pbtn"><button class="up" title="Move up">↑</button><button class="down" title="Move down">↓</button></span>`;
      row.querySelector('code').textContent = answer[li];
      const move = d => { const to = pos + d; if (to < 0 || to >= order.length) return; [order[pos], order[to]] = [order[to], order[pos]]; picked = null; draw(); };
      row.querySelector('.up').onclick = e => { e.stopPropagation(); move(-1); };
      row.querySelector('.down').onclick = e => { e.stopPropagation(); move(1); };
      // click one line, then another, to swap them
      row.onclick = () => {
        if (picked === null) picked = pos;
        else { [order[picked], order[pos]] = [order[pos], order[picked]]; picked = null; }
        draw();
      };
      list.append(row);
    });
  };
  draw();
  const msg = el.querySelector('.pmsg');
  if (progress.isDone(id)) msg.textContent = 'You solved this one before.';
  el.querySelector('.check').onclick = () => {
    const wrong = order.findIndex((li, pos) => answer[li] !== answer[pos]);
    [...list.children].forEach((r, pos) => r.classList.toggle('bad', pos === wrong));
    if (wrong < 0) { msg.textContent = 'Correct.'; msg.className = 'pmsg good'; progress.markDone(id); }
    else { msg.textContent = `Line ${wrong + 1} is the first one out of place.`; msg.className = 'pmsg'; }
  };
});

register('reflect', (el, { src }) => {
  const key = `reflect:${hash(src)}`;
  el.innerHTML = `<div class="wtitle">In your own words</div><div class="pp">${md(src)}</div>
    <textarea rows="3" placeholder="A sentence or two. Only you see this."></textarea><div class="saved"></div>`;
  const ta = el.querySelector('textarea');
  ta.value = localStorage.getItem(key) || '';
  let t;
  ta.oninput = () => { clearTimeout(t); t = setTimeout(() => { localStorage.setItem(key, ta.value); el.querySelector('.saved').textContent = 'Saved in this browser.'; }, 400); };
});

register('sidequest', (el, { src }) => {
  el.innerHTML = '<div class="wtitle">Beyond the VGA</div><p class="whint">Optional, and best on a different day from the session: general Verilog your chip doesn’t need, but your next one will.</p>';
  for (const b of blocks(src)) {
    const f = fields(b);
    const internal = f.link.startsWith('#');
    const a = document.createElement(internal ? 'a' : 'button');
    a.className = 'sq';
    if (internal) a.href = f.link;
    else a.onclick = () => openReader(f.link, f.title);
    a.innerHTML = `<span class="sq-title">${esc(f.title)}</span>${f.time ? `<span class="sq-time">${esc(f.time)}</span>` : ''}<span class="sq-why">${mdi(f.why || '')}</span>`;
    el.append(a);
  }
});
