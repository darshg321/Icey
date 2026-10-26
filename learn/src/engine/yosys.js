// Yosys scripts and log parsing. Runs anywhere `runYosys` from @yowasp/yosys
// runs: the browser worker and the Node test scripts share this file.

// Lowers a design to single-bit gates ($_AND_, $_XOR_, $_MUX_ ...) and plain
// D flip-flops, keeping memories whole. That's what sim.js executes and what
// the gate view draws.
export const SIM_SCRIPT = (top, params = {}) => [
  'read_verilog -sv design.v',
  // Tests can shrink timing constants (e.g. a 1 s delay to 100 clocks).
  ...Object.entries(params).map(([k, v]) => `chparam -set ${k} ${v} ${top}`),
  `hierarchy -check -top ${top}`,
  'proc -norom',        // keep case tables as logic: they'd otherwise show up as "memories"
  'chformal -remove',   // assertions are for the prover, not the simulator
  'flatten',
  'opt_expr',
  'opt_clean',
  'check',
  'opt -nodffe -nosdff',
  'memory -nomap',
  'opt -nodffe -nosdff',
  // async resets become synchronous; latches are left alone so they can be shown misbehaving
  'async2sync t:$adff t:$adffe t:$dffsr t:$dffsre t:$aldff t:$aldffe t:$mem_v2',
  'wreduce',
  'opt_clean',
  'techmap',
  'opt -fast -nodffe -nosdff',
  'abc -g AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX',
  'opt_clean',
  'dfflegalize -cell $_DFF_P_ 01 -cell $_DFF_N_ 01 -cell $_DLATCH_P_ 01 -cell $_DLATCH_N_ 01',
  'opt_clean -purge',
  'stat',
  'write_json out.json',
  // Also a copy packed into 4-input lookup tables, like the real chip. It has
  // about half as many cells, so big designs simulate faster from it.
  'abc -lut 4',
  'opt_clean',
  'write_json lut.json',
].join('; ');

// The same flow Icestudio, apio and the Makefiles use for a real iCE40.
export const ICE40_SCRIPT = (top, opts = {}) => [
  'read_verilog -sv design.v',
  'proc',
  'chformal -remove',
  `synth_ice40 -top ${top}${opts.dsp === false ? '' : ' -dsp'}`,
  'stat',
  'write_json ice40.json',
].join('; ');

// `default_nettype none on the first line (no newline, so line numbers stay
// put) turns a typo'd name into an error instead of a silent new 1-bit wire.
export const prelude = src => '`default_nettype none ' + src;

const strip = s => s.replace(/\x1b\[[0-9;]*m/g, '');

const FRIENDLY = [
  [/syntax error, unexpected (\S+)/, (m) => `Syntax error near ${tokenName(m[1])}. Often it's a missing semicolon on the line before.`],
  [/Identifier `\\?([^']+)' is implicitly declared and `default_nettype is set to none/, m => `"${m[1]}" isn't declared. Check the spelling, or declare it with wire/reg first.`],
  [/Module `\\?top' not found/, () => 'There needs to be a module called top. That is the one the board connects to.'],
  [/Latch inferred for signal `\\[^.]*\.\\?([^']+)'/, m => `Latch inferred for "${m[1]}": some path through the always @(*) block never assigns it, so it has to remember its old value.`],
  [/is assigned in a block at/, () => null],
  [/found logic loop/, () => 'A signal feeds back into itself through gates only (no flip-flop). That makes an oscillator or a latch.'],
];

function tokenName(t) {
  const map = { TOK_ENDMODULE: 'endmodule', TOK_END: 'end', TOK_ID: 'a name', TOK_ASSIGN: 'assign', TOK_ALWAYS: 'always', TOK_REG: 'reg', TOK_WIRE: 'wire', TOK_ELSE: 'else', TOK_BEGIN: 'begin', TOK_CONSTVAL: 'a number', TOK_INPUT: 'input', TOK_OUTPUT: 'output', TOK_MODULE: 'module', TOK_ENDCASE: 'endcase', TOK_CASE: 'case', TOK_IF: 'if' };
  if (map[t]) return `"${map[t]}"`;
  if (/^'.'$/.test(t)) return `"${t[1]}"`;
  return t.replace(/^TOK_/, '').toLowerCase();
}

// Turn a Yosys log into [{line, severity, message, raw}].
export function diagnostics(log) {
  const out = [];
  const seen = new Set();
  for (const raw0 of strip(log).split('\n')) {
    const raw = raw0.trim();
    let m = raw.match(/^(?:design\.v:(\d+)(?:\.\d+-\d+\.\d+)?: )?(ERROR|Warning): (.*)$/);
    if (!m) {
      m = raw.match(/^ERROR: Parser error in line design\.v:(\d+): (.*)$/);
      if (m) m = [m[0], m[1], 'ERROR', m[2]];
    }
    if (!m) continue;
    let [, line, sev, msg] = m;
    let lineNo = line ? +line : null;
    const at = msg.match(/design\.v:(\d+)/);
    if (!lineNo && at) lineNo = +at[1];
    let friendly = msg;
    for (const [re, fn] of FRIENDLY) {
      const mm = msg.match(re);
      if (mm) { friendly = fn(mm); break; }
    }
    if (friendly === null) continue;
    const key = `${lineNo}:${friendly}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ line: lineNo, severity: sev === 'ERROR' ? 'error' : 'warning', message: friendly, raw: msg });
  }
  return out;
}

// Pull numbers out of `stat` output.
export function stats(log) {
  const text = strip(log);
  const idx = text.lastIndexOf('Printing statistics');
  const part = idx >= 0 ? text.slice(idx) : text;
  const cells = {};
  for (const m of part.matchAll(/^\s+(\d+)\s+(?:[\d.]+\s+)?(\$?[\w$]+)\s*$/gm)) cells[m[2]] = (cells[m[2]] || 0) + +m[1];
  for (const m of part.matchAll(/^\s+(\$?[\w$]+)\s+(\d+)\s*$/gm)) cells[m[1]] = (cells[m[1]] || 0) + +m[2];
  return cells;
}

export { strip as stripAnsi };
