// Icey has no clock pin. If the design takes `clk`, wrap it in a top module
// that makes 12 MHz from the iCE40's internal oscillator, the same way the
// examples in firmware/ do. Also point out ports the board doesn't have.
export const CLOCKS = {
  // 48 MHz / 4 = 12 MHz, as in firmware/examples
  '12': { note: '12 MHz from the chip\'s internal oscillator (<code>SB_HFOSC</code>)', code: `SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(clk));` },
  // 48 MHz -> PLL -> 25.125 MHz, as in firmware/examples/icestudio/vga_demo.ice
  vga: { note: 'a 25.125 MHz pixel clock: the internal 48 MHz oscillator multiplied and divided by the PLL (<code>SB_PLL40_CORE</code>), exactly as in <code>vga_demo.ice</code>', code: `wire hf;
  SB_HFOSC #(.CLKHF_DIV("0b00")) osc (.CLKHFEN(1'b1), .CLKHFPU(1'b1), .CLKHF(hf));
  SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"), .DIVR(4'b0011), .DIVF(7'b1000010), .DIVQ(3'b101), .FILTER_RANGE(3'b001)) pll (
    .REFERENCECLK(hf), .PLLOUTGLOBAL(clk), .RESETB(1'b1), .BYPASS(1'b0));` },
};

export function wrapForIcey(src, top, ports, clock = '12', pins = null) {
  const notes = [];
  const missing = pins ? Object.keys(ports).filter(p => p !== 'clk' && !pins.has(p)) : [];
  if (missing.length) {
    notes.push(`Icey has no pins called ${missing.map(m => `<code>${m}</code>`).join(', ')} (they're on the browser's practice board). nextpnr will still build it, but it puts those signals on spare pins, so on the real board they won't be connected to anything useful.`);
  }
  if (!ports.clk || ports.clk.direction !== 'input') return { src, notes };
  const ck = CLOCKS[clock] || CLOCKS['12'];
  notes.push(`Your design has a <code>clk</code> input, and Icey has no clock pin, so this build wraps it in a top module that feeds it ${ck.note}. Lessons 10 and 18 show how that works.`);
  const decl = Object.entries(ports).filter(([n]) => n !== 'clk').map(([n, p]) =>
    `  ${p.direction} ${p.bits.length > 1 ? `[${p.bits.length - 1}:0] ` : ''}${n}`);
  const conns = Object.keys(ports).filter(n => n !== 'clk').map(n => `.${n}(${n})`);
  const renamed = src.replace(new RegExp(`\\bmodule\\s+${top}\\b`), 'module user_top');
  return {
    notes,
    src: `${renamed}

module ${top}(
${decl.join(',\n')}
);
  wire clk;
  ${ck.code}
  user_top u (.clk(clk)${conns.map(c => ', ' + c).join('')});
endmodule
`,
  };
}

