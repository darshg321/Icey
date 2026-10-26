// Verilog libraries an exercise can pull in with `libs: ['6502']`. They're
// appended after the learner's code, so editor line numbers stay right.
import alu6502 from './verilog-6502/ALU.v?raw';
import cpu6502 from './verilog-6502/cpu.v?raw';

export const LIBS = {
  6502: `\n// ---- Arlet Ottens' verilog-6502 (github.com/Arlet/verilog-6502) ----\n${alu6502}\n${cpu6502}`,
};

export const withLibs = (src, libs = []) => src + libs.map(l => LIBS[l] || '').join('\n');
