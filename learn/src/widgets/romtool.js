import { register } from './index.js';

// Turn a ROM image (a .bin file, or a hex listing like "FF00: D8 58 A0 ...")
// into a Verilog initial block.
register('romtool', (el, { name = 'rom', size = 256 }) => {
  el.innerHTML = `<div class="wtitle">ROM image to Verilog</div>
    <div class="row"><label>Choose a ${size}-byte .bin file: <input type="file" accept=".bin,.rom,application/octet-stream"></label></div>
    <div class="small muted" style="margin:8px 0 4px">or paste a hex listing (addresses before a colon are skipped):</div>
    <textarea spellcheck="false" placeholder="FF00: D8 58 A0 7F ..." style="width:100%;height:110px;font-family:var(--mono);font-size:12px"></textarea>
    <div class="row" style="margin:8px 0"><button class="primary go">Make the initial block</button><button class="tiny copy">copy</button><span class="msg small"></span></div>
    <pre class="out"></pre>`;
  const out = el.querySelector('.out'), msg = el.querySelector('.msg');
  const emit = bytes => {
    if (bytes.length !== size) { msg.textContent = `That's ${bytes.length} bytes; the ROM is ${size}.`; msg.style.color = '#c0392b'; }
    else { msg.textContent = `${size} bytes. Replace the placeholder initial block in your ROM with this.`; msg.style.color = ''; }
    const lines = [];
    for (let a = 0; a < bytes.length; a += 8) lines.push('    ' + Array.from(bytes.slice(a, a + 8), (v, i) => `${name}[8'h${(a + i).toString(16).padStart(2, '0')}] = 8'h${v.toString(16).padStart(2, '0')};`).join(' '));
    out.textContent = `  initial begin\n${lines.join('\n')}\n  end`;
  };
  el.querySelector('input[type=file]').onchange = async e => {
    const f = e.target.files[0];
    if (f) emit(new Uint8Array(await f.arrayBuffer()));
  };
  el.querySelector('.go').onclick = () => {
    const text = el.querySelector('textarea').value;
    const bytes = text.split('\n').flatMap(l => l.replace(/^\s*[0-9a-fA-F]+\s*:/, '').match(/\b[0-9a-fA-F]{2}\b/g) || []).map(h => parseInt(h, 16));
    emit(Uint8Array.from(bytes));
  };
  el.querySelector('.copy').onclick = () => navigator.clipboard.writeText(out.textContent);
});
