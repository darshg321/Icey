import { used } from '../../engine/flow.js';

export default [
  {
    id: 'first-light',
    title: 'First light',
    prompt: 'Press **build for Icey**, then upload the result and press SW2 on the board. (This one counts as done once it builds.)',
    starter: `module top(
  input  BTN,
  output LED
);
  assign LED = ~BTN;
endmodule
`,
    solution: `module top(
  input  BTN,
  output LED
);
  assign LED = ~BTN;
endmodule
`,
    board: [{ type: 'button', port: 'BTN', label: 'SW2', activeLow: true, key: ' ' }, { type: 'led', port: 'LED', label: 'LED1' }],
    doneOn: 'build',
  },
  {
    id: 'hfosc',
    title: 'Blink, with your own oscillator',
    prompt: 'Add an `SB_HFOSC` running at 12 MHz and use it to blink `LED` once a second. Run builds it for the chip; the checks look at the result.',
    noSim: true,
    gates: false,
    starter: `module top(
  output LED
);
  wire clk;
  // SB_HFOSC goes here

  reg [22:0] count = 0;
  reg led = 0;
  always @(posedge clk) begin
    if (count == 23'd5_999_999) begin
      count <= 0;
      led <= ~led;
    end else
      count <= count + 1;
  end
  assign LED = led;
endmodule
`,
    solution: `module top(
  output LED
);
  wire clk;
  SB_HFOSC #(.CLKHF_DIV("0b10")) osc (
    .CLKHFEN(1'b1),
    .CLKHFPU(1'b1),
    .CLKHF(clk)
  );

  reg [22:0] count = 0;
  reg led = 0;
  always @(posedge clk) begin
    if (count == 23'd5_999_999) begin
      count <= 0;
      led <= ~led;
    end else
      count <= count + 1;
  end
  assign LED = led;
endmodule
`,
    chipTests: [
      { name: 'uses the internal oscillator', check: r => used(r, 'ICESTORM_HFOSC') === 1 ? null : 'No SB_HFOSC in the design. Without it nothing drives clk, so the counter never moves.' },
      { name: 'divides it down to 12 MHz', check: r => {
        const div = r.cells.find(c => c.type === 'ICESTORM_HFOSC')?.params.CLKHF_DIV;
        return div === '0b10' ? null : `The oscillator's CLKHF_DIV is ${div || 'not set'}. "0b10" divides 48 MHz by 4 to get 12 MHz.`;
      } },
      { name: 'the counter and LED are there', check: r => used(r, 'ICESTORM_LC') >= 20 ? null : `Only ${used(r, 'ICESTORM_LC')} logic cells used. Yosys removes logic that doesn't affect any output, so if the counter vanished, check that LED really depends on it.` },
    ],
  },
];
