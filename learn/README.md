# Learn FPGAs with Icey

A project-based Verilog and FPGA course for the Icey board, as a website. It
runs the real open-source toolchain in the browser:

- **Run** compiles your Verilog with Yosys (WebAssembly, from [YoWASP](https://yowasp.org))
  down to gates, then simulates those exact gates on a virtual board: LEDs,
  buttons that bounce, switches, 7-segment displays, an RGB LED, an LED matrix,
  a serial terminal, a VGA monitor and an SPI flash chip.
- **build for Icey** runs `synth_ice40` + nextpnr + icepack and shows the design
  placed on the iCE40UP5K, with LUT contents, utilisation and Fmax, and gives you
  the `.bin`. In Chrome/Edge it can load it onto the board over WebUSB.
- Formal exercises use Yosys's built-in SAT solver (equivalence checks, induction
  proofs of `assert`s).

25 lessons in four parts: logic in the browser → onto the real chip (Icestudio) →
command line, testbenches, UART, memory, VGA, timing → Game of Life, SPI, a CPU of
your own, an Apple I running the Woz Monitor, and ASIC-style verification.

There's also **Make a chip** (`src/chip/`): one project in 14 sessions of about
30 minutes, a VGA graphics chip from a first line of Verilog to a GF180 layout ready
for the Hack Club #asic shared chip. Sessions are built from learning blocks
(`resource`, `recall`, `predict`, `parsons`, `reflect`, `sidequest` fenced blocks
in the markdown, see `src/widgets/learning.js`); resources open in a reader beside
the lesson, and later sessions start from the learner's own code from the session
before (`carry`). Why it's built that way, with sources: [PEDAGOGY.md](PEDAGOGY.md).
The board part `icey` is a perspective-corrected photo of the real board with the
LEDs, SW2, SW3 and header pins P1–P9 placed from the PCB coordinates.

## Running it

```sh
cd learn
npm install          # also runs scripts/vendor.mjs (copies the toolchains into public/)
npm run dev          # http://localhost:5173
```

`npm run build` makes a static site in `dist/` (about 100 MB, nearly all of it the
Yosys and nextpnr WebAssembly). It works from any path, so GitHub Pages is fine.
The first Run in a browser downloads Yosys (~75 MB); the first chip build downloads
nextpnr and the UP5K chip database (~25 MB). Both are cached after that.

## Tests

```sh
node test/sim.test.mjs         # the gate-level simulator
node test/exercises.test.mjs   # every exercise's reference solution against its own tests
node test/exercises.test.mjs 23   # just the lessons whose folder name contains "23"
node test/exercises.test.mjs chip/  # just the chip path
```

The exercise test also builds every exercise that has chip checks for the real
iCE40, so it takes a few minutes.

## Layout

```
src/
  lessons/NN-name/lesson.md     prose (markdown, plus @exercise id and @widget name lines)
  lessons/NN-name/exercises.js  starter code, solutions, board parts, tests
  engine/sim.js                 gate-level simulator (compiles the netlist to JS)
  engine/yosys.js               Yosys scripts and log parsing
  engine/flow.js                the iCE40 build (shared by the browser and the tests)
  engine/formal.js              equivalence checks and induction proofs
  engine/tests.js               the exercise test API (t.set / t.tick / t.eq / t.table ...)
  engine/webusb.js              iceyprog.py ported to WebUSB
  engine/worker.js              runs the toolchains off the main thread
  ui/                           editor, virtual board, waves, gates, chip view
  widgets/                      interactive figures used inside lessons
  lib/verilog-6502/             Arlet Ottens' 6502 core (used by the Apple I lesson)
```

Exercise options worth knowing: `testTop` / `testParams` test a submodule with
smaller timing constants, `simParams` does the same for the virtual board,
`chipTests` check the real build (cell counts, Fmax), `libs: ['6502']` appends
library code, `iceyClock: 'vga'` builds with the 25 MHz PLL, and `formal` replaces
simulation with proofs.

## Notes

- nextpnr's default placer never finishes under WebAssembly when it's allowed
  threads, so the builds use `--threads 1`.
- The simulator splits the generated code into ~300-line functions; V8 stops
  optimising much bigger ones and everything gets 3× slower. Designs over 450
  cells simulate from a LUT-mapped copy of the netlist, which runs about a third faster.
- The WebUSB upload has not been tried on a real board yet. The pin sequence is the
  one `firmware/tools/iceyprog.py` uses.
