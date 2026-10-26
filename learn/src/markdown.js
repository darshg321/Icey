// Lesson markdown -> HTML. Two additions to plain markdown:
//   @exercise some-id            an exercise card that opens in the workbench
//   @widget name {"json": "args"}  an interactive figure (see widgets/)
import { marked } from 'marked';

const KW = new Set(('module endmodule input output inout wire reg logic assign always initial begin end if else case casez casex endcase default ' +
  'posedge negedge or and not for while integer parameter localparam generate endgenerate genvar function endfunction task endtask signed unsigned ' +
  'always_ff always_comb assert assume cover property').split(' '));

export function highlightVerilog(code) {
  const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  const re = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|("(?:[^"\\]|\\.)*")|(\d+'[sS]?[bBoOdDhH][0-9a-fA-FxXzZ_?]+|'[bBoOdDhH][0-9a-fA-FxXzZ_]+|\b\d[\d_]*(?:\.\d+)?\b)|(`\w+|\$\w+)|([A-Za-z_][\w$]*)/g;
  let out = '', last = 0, m;
  while ((m = re.exec(code))) {
    out += esc(code.slice(last, m.index));
    const [t, com, str, num, dir, id] = m;
    if (com) out += `<span class="t-com">${esc(t)}</span>`;
    else if (str) out += `<span class="t-str">${esc(t)}</span>`;
    else if (num) out += `<span class="t-num">${esc(t)}</span>`;
    else if (dir) out += `<span class="t-dir">${esc(t)}</span>`;
    else if (id && KW.has(id)) out += `<span class="t-kw">${t}</span>`;
    else out += esc(t);
    last = m.index + t.length;
  }
  return out + esc(code.slice(last));
}

const renderer = new marked.Renderer();
// Fenced blocks with these names become learning widgets (widgets/learning.js):
// ```resource, ```recall, ```predict, ```parsons, ```reflect, ```sidequest
const LEARNING_BLOCKS = new Set(['resource', 'recall', 'predict', 'parsons', 'reflect', 'sidequest']);

renderer.code = ({ text, lang }) => {
  const l = (lang || '').trim();
  if (LEARNING_BLOCKS.has(l)) return `<div class="widget ${l}" data-widget="${l}" data-src="${encodeURIComponent(text)}"></div>`;
  if (l === 'verilog' || l === 'v' || l === 'systemverilog') return `<pre class="code"><code>${highlightVerilog(text)}</code></pre>`;
  const esc = text.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  return `<pre class="code ${l ? 'lang-' + l : ''}"><code>${esc}</code></pre>`;
};
marked.use({ renderer, gfm: true });

export function parseFrontmatter(src) {
  const m = src.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) return { meta: {}, body: src };
  const meta = {};
  for (const line of m[1].split('\n')) {
    const i = line.indexOf(':');
    if (i > 0) meta[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return { meta, body: src.slice(m[0].length) };
}

export function renderLesson(body) {
  const pre = body
    .replace(/^@exercise\s+(\S+)\s*$/gm, (_, id) => `\n<div class="ex-slot" data-id="${id}"></div>\n`)
    .replace(/^@widget\s+(\S+)(?:\s+(\{.*\}))?\s*$/gm, (_, name, args) =>
      `\n<div class="widget" data-widget="${name}" data-args='${(args || '{}').replace(/'/g, '&#39;')}'></div>\n`);
  return marked.parse(pre);
}
