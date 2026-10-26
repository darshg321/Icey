---
title: Verifying it like a chip company
part: 4
blurb: Why silicon gets tested more thoroughly than anything else, reference models, proofs instead of tests, and how a design like yours becomes a real chip.
---

An FPGA forgives you. Find a bug, fix the Verilog, rebuild, reload, and the bug is gone a minute later. A custom chip, an ASIC, doesn't forgive anything. Its logic is etched into silicon through a set of photomasks, and on a modern process a mask set costs millions of dollars and the fab takes months. A bug in silicon is permanent. The famous one is the Pentium FDIV bug in 1994: five missing entries in a lookup table inside the floating-point divider, found after the chips had shipped, and Intel took a charge of $475 million to replace them.

That's why chip companies have more verification engineers than designers, and why the techniques in this lesson exist. You don't need to tape out a chip to use them. They make FPGA designs better too, and the last one, formal proof, is something you can run in this page.

## A ladder of confidence

**Directed tests** check the cases you thought of. Every exercise in this course started there: press the button three times, expect 3. They're quick to write and they catch obvious mistakes, but they only ever cover what you already expected.

**Reference models** compare your design against a simpler, slower implementation that's obviously correct. You've seen the most dramatic one on Icey already: `life.py` runs the same generations in NumPy and checks all 16,384 cells after twenty thousand generations of the FPGA running flat out. The hardware is clever and fast; the model is dumb and trustworthy; agreement between them is strong evidence. Reference models are the backbone of real verification. In processor design, they're often a full instruction-set simulator in C, checked against the RTL after every instruction.

**Random testing** generates inputs nobody thought of. Combine it with a reference model and you can run millions of cases overnight. Real flows use *constrained* random generation, random but within the rules (only legal instructions, say), and measure *coverage* to find out which parts of the design the random tests have actually exercised.

**Formal verification** stops sampling and proves. Instead of running inputs through the design, a solver reasons about *all* inputs at once, and either proves a property holds or produces the exact input sequence that breaks it.

## Proving two designs are the same

Here's a small, realistic situation. You've written a clever, fast implementation of something, and you have a slow, obviously-correct version to compare it against. The question is whether they agree for every possible input.

For a function of 8 inputs you could try all 256. But for a 32-bit multiplier that's 2⁶⁴ cases, more than you could ever simulate. A formal *equivalence check* answers the question without enumerating them. Yosys builds a *miter*: both designs side by side, fed the same inputs, with an XOR comparing their outputs. Then it asks a SAT solver whether there's any input that makes that XOR output 1. If the solver says no, the designs are equivalent, proven. If it says yes, it hands you the input.

@exercise equiv

This is the same technique chip companies run after every synthesis and place-and-route step, to prove the tools didn't change what the design does. Yosys has a whole set of commands for it (`equiv_make`, `equiv_simple`, `equiv_induct`), and the open-source chip flows use them.

## Proving properties: assertions

Equivalence needs a second design to compare against. Often you don't have one, but you do know some things that must always be true. A FIFO's count can never exceed its size. The traffic light never shows green and red together. Your CPU's PC never points into the stack. Those are *properties*, and you write them inside the design as assertions:

```verilog
always @(*) begin
  assert(count <= 4);
  assert(!(full && empty));
end
```

Simulators check assertions as they run. A formal tool tries to prove them for every possible input sequence, forever, and the usual method is *induction*, the same idea as proofs by induction in maths. First the base case: from the initial state, no assertion fails in the first k clocks. Then the step: from *any* state where the assertions held for k clocks in a row, they still hold on the next clock. If both go through, the assertions hold forever.

There's a subtlety that catches everyone the first time. The induction step starts from *any* state where the assertions hold, including states your design can never actually reach. If your assertions are weak, the solver will find a strange unreachable state (say, a write pointer and a count that disagree) and complain that the assertions fail from there. The proof isn't wrong; it's telling you that your assertions don't capture everything you know. The fix is to write down the invariant that connects the registers. For a FIFO, the write pointer minus the read pointer equals the count. With that added, the unreachable states are excluded and the proof goes through.

@exercise fifo

That exercise follows the real workflow: the prover found the bug in a few seconds, with a trace showing exactly how to trigger it from reset. A random test only finds this one if it happens to push and pop at the same moment while the FIFO is full.

## Doing it on your own machine

The browser runs Yosys's built-in SAT solver, which is fine for small designs. For real work, use SymbiYosys (`sby`), which drives much stronger solvers. It's part of the OSS CAD Suite. A proof is described by a small file:

```
[options]
mode prove

[engines]
smtbmc

[script]
read -formal fifo.v
prep -top fifo

[files]
fifo.v
```

`sby -f fifo.sby` runs it, and if a property fails it writes the counterexample as a VCD you can open in GTKWave. There's also cocotb, which lets you write testbenches in Python, so a reference model can be a few lines of NumPy, much like `life.py`.

## From your Verilog to a real chip

Everything you've written could, in principle, become an ASIC. The flow mirrors the FPGA one with different targets. Synthesis maps to a *standard cell library* (real gates and flip-flops, each a little drawing of transistors) instead of LUTs. Place and route puts those cells on a die and draws the metal wires between them, millions of polygons. Then come checks FPGAs never needed: design rule checks that every shape can be manufactured, and *layout versus schematic*, which proves the drawn transistors match the netlist. The result is a GDS file, the drawing the fab makes masks from.

Fully open-source versions of all of this exist now: Yosys again for synthesis, OpenROAD for place and route, and open process design kits from SkyWater (130 nm) and IHP (130 nm SiGe) that describe real manufacturing processes. And there's a way to actually get a chip made without millions of dollars: **Tiny Tapeout**, which puts hundreds of small designs from different people onto one shared chip, splitting the mask cost. Each project gets a small tile of silicon, and you design it with a template that's mostly a Verilog module with 8 inputs, 8 outputs and 8 bidirectional pins. Your reaction timer or your Icey-8 would fit. Their website has the current tile sizes, prices and deadlines, and their template repository runs a cocotb test and the full ASIC flow in GitHub Actions every time you push.

Three habits change when you design for an ASIC instead of an FPGA, and it's worth adopting them now:

- **No initial values.** `reg [7:0] count = 0;` works on an FPGA because the bitstream sets every flip-flop. Silicon flip-flops power up random. Every register that matters needs a real reset.
- **Memories are different.** There's no block RAM to infer. Small memories become flip-flops; big ones are pre-designed SRAM blocks you instantiate.
- **Verify before, not after.** On an FPGA, the board is part of your test bench. On an ASIC, simulation and proof are all you've got until the chip comes back months later. Everything you can check beforehand, you check.

The last lesson is about the next design, the one that's entirely yours.
