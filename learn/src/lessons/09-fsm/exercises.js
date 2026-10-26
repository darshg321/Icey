const clock = { port: 'clk', hz: 12e6 };

const BUTTONS = `// Four copies of lesson 8's synchroniser + debouncer + edge detector.
// press[i] is high for one clock when button i goes down.
module buttons(input clk, input [3:0] btn, output [3:0] press);
  genvar i;
  generate for (i = 0; i < 4; i = i + 1) begin : b
    reg [1:0] sync = 0;
    reg stable = 0, prev = 0;
    reg [15:0] timer = 0;
    always @(posedge clk) begin
      sync <= {sync[0], btn[i]};
      if (sync[1] == stable) timer <= 0;
      else if (&timer)       stable <= sync[1];
      else                   timer <= timer + 1;
      prev <= stable;
    end
    assign press[i] = stable & ~prev;
  end endgenerate
endmodule`;

const TOP = `module top(
  input        clk,
  input  [3:0] btn,     // the four buttons on the practice board, 1 = pressed
  output       green,
  output       red
);
  wire [3:0] press;
  buttons b(.clk(clk), .btn(btn), .press(press));
  lock    l(.clk(clk), .press(press), .green(green), .red(red));
endmodule`;

export default [
  {
    id: 'traffic',
    title: 'Traffic light',
    prompt: 'Green for 5 s, yellow for 1 s, red for 4 s, forever. Exactly one light on at a time. Start in green.',
    starter: `module top(
  input  clk,
  output red,
  output yellow,
  output green
);
  parameter SEC = 12_000_000;   // clocks per second (the tests make this smaller)

  localparam GREEN = 2'd0, YELLOW = 2'd1, RED = 2'd2;
  reg [1:0]  state = GREEN;
  reg [25:0] timer = 0;

  always @(posedge clk) begin
    // your state machine
  end

  assign green  = (state == GREEN);
  assign yellow = 0;
  assign red    = 0;
endmodule
`,
    solution: `module top(
  input  clk,
  output red,
  output yellow,
  output green
);
  parameter SEC = 12_000_000;

  localparam GREEN = 2'd0, YELLOW = 2'd1, RED = 2'd2;
  reg [1:0]  state = GREEN;
  reg [25:0] timer = 0;

  always @(posedge clk) begin
    timer <= timer + 1;
    case (state)
      GREEN:  if (timer == 5*SEC - 1) begin state <= YELLOW; timer <= 0; end
      YELLOW: if (timer == 1*SEC - 1) begin state <= RED;    timer <= 0; end
      RED:    if (timer == 4*SEC - 1) begin state <= GREEN;  timer <= 0; end
      default: begin state <= GREEN; timer <= 0; end
    endcase
  end

  assign green  = (state == GREEN);
  assign yellow = (state == YELLOW);
  assign red    = (state == RED);
endmodule
`,
    board: [{ type: 'led', port: 'red', label: 'red', color: '#ff3b2f' }, { type: 'led', port: 'yellow', label: 'yellow', color: '#ffc21a' }, { type: 'led', port: 'green', label: 'green', color: '#3dff6e' }],
    clock,
    testParams: { SEC: 10 },
    waves: ['clk', 'green', 'yellow', 'red'],
    tests: [
      { name: 'green 5 s → yellow 1 s → red 4 s, twice round (with SEC = 10)', run(t) {
        const want = (g, y, r, when) => { t.eq('green', g, when); t.eq('yellow', y, when); t.eq('red', r, when); };
        let at = 0;
        for (let lap = 0; lap < 2; lap++) {
          for (const [len, g, y, r, name] of [[50, 1, 0, 0, 'green'], [10, 0, 1, 0, 'yellow'], [40, 0, 0, 1, 'red']]) {
            want(g, y, r, `at the start of ${name} (clock ${at})`);
            t.tick(len - 1); at += len - 1;
            want(g, y, r, `at the end of ${name} (clock ${at})`);
            t.tick(1); at += 1;
          }
        }
      } },
    ],
  },
  {
    id: 'lock',
    project: true,
    title: 'Combination lock',
    prompt: 'Code **2, 0, 3, 1**. Correct code: `green` on for 3 s (or until the next press). Wrong press: back to the start, `red` on for 0.5 s. Use the keys 0–3 or click the buttons.',
    starter: `${BUTTONS}

module lock(
  input       clk,
  input [3:0] press,    // one-clock pulse: which button was just pressed
  output      green,
  output      red
);
  parameter SEC = 12_000_000;

  // states, a timer for the open period, a timer for the red flash

  assign green = 0;
  assign red   = 0;
endmodule

${TOP}
`,
    solution: `${BUTTONS}

module lock(
  input       clk,
  input [3:0] press,
  output      green,
  output      red
);
  parameter SEC = 12_000_000;

  localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, OPEN = 3'd4;
  reg [2:0]  state = S0;
  reg [25:0] open_timer = 0;
  reg [25:0] red_timer = 0;

  wire any = |press;
  // the button each progress state is waiting for
  reg [3:0] want;
  always @(*) begin
    case (state)
      S0: want = 4'b0100;   // 2
      S1: want = 4'b0001;   // 0
      S2: want = 4'b1000;   // 3
      S3: want = 4'b0010;   // 1
      default: want = 4'b0000;
    endcase
  end

  always @(posedge clk) begin
    if (red_timer != 0) red_timer <= red_timer - 1;
    case (state)
      S0, S1, S2, S3:
        if (any) begin
          if (press == want) begin
            state <= (state == S3) ? OPEN : state + 1;
            open_timer <= 3*SEC - 1;
          end else begin
            state <= S0;
            red_timer <= SEC/2;
          end
        end
      OPEN:
        if (any || open_timer == 0) state <= S0;
        else open_timer <= open_timer - 1;
      default: state <= S0;
    endcase
  end

  assign green = (state == OPEN);
  assign red   = (red_timer != 0);
endmodule

${TOP}
`,
    board: [0, 1, 2, 3].map(i => ({ type: 'button', port: 'btn', bit: i, label: `${i}`, key: `${i}`, bounce: true })).concat([
      { type: 'led', port: 'red', label: 'wrong', color: '#ff3b2f' }, { type: 'led', port: 'green', label: 'open', color: '#3dff6e' }]),
    clock,
    testTop: 'lock',
    testParams: { SEC: 100 },
    waves: ['clk', 'press', 'green', 'red'],
    tests: [
      { name: 'the right code opens it', run(t) {
        const p = b => { t.set('press', 1 << b); t.tick(1); t.set('press', 0); t.tick(5); };
        t.eq('green', 0, 'at power-up');
        for (const b of [2, 0, 3]) { p(b); t.eq('green', 0, 'before the code is finished'); }
        p(1); t.eq('green', 1, 'after pressing 2, 0, 3, 1');
        t.eq('red', 0, 'after a correct code');
      } },
      { name: 'it locks again after 3 s', run(t) {
        const p = b => { t.set('press', 1 << b); t.tick(1); t.set('press', 0); t.tick(5); };
        for (const b of [2, 0, 3, 1]) p(b);
        t.eq('green', 1, 'just after the code');
        t.tick(250); t.eq('green', 1, 'after about 2.5 s (SEC = 100)');
        t.tick(60); t.eq('green', 0, 'after more than 3 s');
      } },
      { name: 'a wrong press resets and flashes red', run(t) {
        const p = b => { t.set('press', 1 << b); t.tick(1); t.set('press', 0); t.tick(5); };
        p(2); p(0); p(1);
        t.eq('red', 1, 'just after a wrong press (2, 0, then 1)');
        t.tick(60); t.eq('red', 0, 'more than half a second after the wrong press');
        p(3); p(1); t.eq('green', 0, 'after 2, 0, 1 then 3, 1. The wrong press should have sent it back to the start');
        p(2); p(0); p(3); p(1); t.eq('green', 1, 'after a full correct code following a mistake');
      } },
      { name: 'a press while open locks it', run(t) {
        const p = b => { t.set('press', 1 << b); t.tick(1); t.set('press', 0); t.tick(5); };
        for (const b of [2, 0, 3, 1]) p(b);
        p(0); t.eq('green', 0, 'after pressing a button while it was open');
      } },
    ],
  },
];
