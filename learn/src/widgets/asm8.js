import { register } from './index.js';
import { assemble, toInitial } from '../lessons/22-cpu/exercises.js';

const FIB = `; Fibonacci numbers until they overflow 8 bits
        LDI 0
        STA x
        LDI 1
        STA y
loop:   LDA y
        OUT
        ADD x
        JC  done
        STA t
        LDA y
        STA x
        LDA t
        STA y
        JMP loop
done:   HLT

.org $80
x:      .byte 0
y:      .byte 0
t:      .byte 0`;

// An assembler for Icey-8 that writes the Verilog initial block for you.
register('asm8', el => {
  el.innerHTML = `<div class="wtitle">Icey-8 assembler</div>
    <textarea spellcheck="false" style="width:100%;height:260px;font-family:var(--mono);font-size:13px;background:#16171a;color:#e7e7e9;border-radius:6px;padding:8px;border:none"></textarea>
    <div class="row" style="margin:8px 0"><button class="primary go">Assemble</button><button class="copy tiny">copy</button><span class="err small" style="color:#c0392b"></span></div>
    <pre class="out"></pre>`;
  const ta = el.querySelector('textarea');
  ta.value = FIB;
  const out = el.querySelector('.out');
  const go = () => {
    try {
      out.textContent = toInitial(assemble(ta.value));
      el.querySelector('.err').textContent = '';
    } catch (e) {
      el.querySelector('.err').textContent = e.message;
    }
  };
  el.querySelector('.go').onclick = go;
  el.querySelector('.copy').onclick = () => navigator.clipboard.writeText(out.textContent);
  go();
});
