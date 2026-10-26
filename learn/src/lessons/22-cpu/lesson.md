---
title: A CPU of your own
part: 4
blurb: Design a small processor from nothing: an instruction set, an ALU, a datapath and a state machine to drive it. Then program it.
---

Everything you've built so far does one job. The stopwatch counts time, the reaction timer runs its game. A processor is a circuit whose job is decided by numbers in memory, which means one circuit can do any job you can write a program for. That idea is about eighty years old, and it's still the most useful trick in computing.

This lesson builds a complete, working CPU. It's small, eight bits and thirteen instructions, but it has every part a real one has, and once you've built it, the 6502 in the Apple I is the same thing with more instructions.

## The instruction set

A CPU starts as a list of instructions it understands, its *instruction set architecture* (ISA). Ours, which we'll call Icey-8, has one 8-bit working register, the *accumulator* `A`, an 8-bit program counter `PC`, two flags, `Z` (the last result was zero) and `C` (the last add carried, or the last subtract borrowed), and 256 bytes of memory shared by the program and its data.

Every instruction is two bytes: an opcode, then an operand.

| opcode | name | does |
|---|---|---|
| 0 | `LDI n` | A = n |
| 1 | `LDA m` | A = mem[m] |
| 2 | `STA m` | mem[m] = A |
| 3 | `ADD m` | A = A + mem[m], sets C |
| 4 | `SUB m` | A = A − mem[m], sets C on borrow |
| 5, 6, 7 | `AND`, `OR`, `XOR m` | A = A op mem[m] |
| 8 | `JMP a` | PC = a |
| 9 | `JZ a` | if Z, PC = a |
| 10 | `JC a` | if C, PC = a |
| 11 | `OUT` | send A to the output port |
| 12 | `IN` | A = the input port |
| 15 | `HLT` | stop |

Instructions that change A also set Z. That's enough to write loops, make decisions, do arithmetic, and talk to the outside world, which is all a program ever does.

## The ALU

The *arithmetic logic unit* does the actual computing: given two bytes and an operation, produce a result. You've built every part of it already, the adder in lesson 4 and the gates in lesson 2. Now it's one `case`.

@exercise alu

## How the CPU runs a program

A CPU repeats one loop forever: **fetch** an instruction from memory at PC, **decode** what it means, **execute** it. Ours is built around the block RAM from lesson 17, where a read takes a clock, so each instruction takes four:

1. **FETCH**: put PC on the memory address.
2. **OP**: the opcode arrives from memory; keep it. Put PC + 1 on the address.
3. **ARG**: the operand arrives; keep it, and move PC on by 2. Also put the operand on the address, in case this instruction needs a byte from memory. Most do.
4. **EXEC**: that byte has now arrived. Do whatever the opcode says: load it into A, add it, store A into memory, change PC for a jump. Then back to FETCH.

Step 3 has a small trick in it: the operand is used as a memory address in the *same* clock that it arrives. Since the memory reads on the clock edge, it starts fetching `mem[operand]` straight away, and the data's ready for EXEC. Without that, the CPU would need five clocks per instruction.

Hardware designers split a CPU into the *datapath* (registers, the ALU, the memory, and the muxes that route data between them) and the *control* (the state machine that sets those muxes on each clock). Here, the datapath is `A`, `PC`, the ALU and the RAM. The control is the four-state machine. The `case (state)` that chooses the memory address is the clearest example: that one mux is how the same memory serves instructions in one clock and data in the next.

## Writing programs

Typing opcodes into `initial` blocks by hand is how the first programmers worked, and they quickly wrote programs to do it for them. That program is an *assembler*. Here's one for Icey-8. It turns readable instructions into the `initial` block for your memory:

@widget asm8

Labels like `loop:` stand for the address they're attached to, so you can write `JMP loop` instead of working out where the loop starts. `.org $80` moves to address `0x80` and `.byte` puts raw data there, which is where the Fibonacci program keeps its variables.

## Project: build Icey-8

The starter has the declarations and the Fibonacci program already in memory. The tests load their own programs into `mem` and check what comes out of `OUT`. They try each instruction, a loop, a carry, and the full Fibonacci run.

On the board the CPU runs at 40 Hz, ten instructions a second, so you can follow `PC` and `A` as they change. The LEDs show each Fibonacci number as it's output, up to 233, and then it halts. Try writing your own program in the assembler and pasting it in: a counter on the LEDs, or something that reads the switches with `IN`.

@exercise cpu

## What it costs

Build it for Icey. The whole CPU is a couple of hundred logic cells and one block RAM, a few percent of the chip. That's the remarkable thing about processors. A circuit this small can run any program that fits in its memory, given enough time; it's the time that's the catch. Fibonacci up to 233 takes Icey-8 about 500 clocks, while a dedicated adder circuit could produce a new number every clock. A CPU trades speed for flexibility, and an FPGA lets you choose, per job, which one you want. Often the answer is both: a small CPU running the slow, complicated parts, with custom hardware beside it for the fast, simple ones. Every big FPGA project you'll see is built that way.

The next lesson puts a real CPU, one that sold millions, on Icey.
