---
title: Leaving the GUI
part: 3
blurb: The same four tools from a terminal, a Makefile that drives them, and how to read what they tell you.
---

Icestudio and this website are both wrappers. Underneath, every build you've done ran four programs in a row. Running them yourself takes two minutes to learn, and after that you can build projects of any size, keep them in git, script them, and use any editor you like. Every professional FPGA flow works this way, even the ones with expensive GUIs on top.

## Getting the tools

If you ran `firmware/tools/setup.sh` in lesson 10, you already have them, in the virtual environment at `~/.local/share/icey/venv`. Put them on your path for the current terminal:

```sh
source ~/.local/share/icey/venv/bin/activate
```

The YoWASP builds are called `yowasp-yosys`, `yowasp-nextpnr-ice40` and `yowasp-icepack`. If you'd rather have native builds (they're a bit faster), install your distribution's `yosys`, `nextpnr-ice40` and `fpga-icestorm` packages, or the OSS CAD Suite, which bundles all of them plus a simulator. In that case drop the `yowasp-` prefixes from everything below. Either way, never use the `iceprog` that comes with those packages to load Icey; it drives the wrong pins on the FTDI chip. Use `iceyprog`.

## The four steps by hand

Make a folder with a `top.v` in it. Your mood lamp from lesson 12 is a good one, because it uses the clock wrapper idea: put the `SB_HFOSC` in the top module yourself, as in lesson 10, since no website is going to add it for you now. Then:

```sh
yowasp-yosys -p 'synth_ice40 -top top -json top.json' top.v
```

That's synthesis. `-p` gives Yosys a script to run, and the script is a single command, `synth_ice40`, which runs the whole iCE40 synthesis recipe: the parsing, optimisation, mapping to LUTs and flip-flops, all of it. `-json top.json` writes the resulting netlist. Expect a few hundred lines of log; the useful part is the statistics at the end, which list how many of each cell type you're using.

```sh
yowasp-nextpnr-ice40 --up5k --package sg48 --pcf ~/Icey/firmware/icey.pcf --json top.json --asc top.asc
```

Place and route. `--up5k --package sg48` names the exact chip. `--pcf` is the *physical constraints file*, the list that says port `LED` is on pin 9 and so on. Open `icey.pcf` and have a look; it's short and every line is commented. `--asc` writes the result as a text file describing every tile's configuration.

```sh
yowasp-icepack top.asc top.bin
python ~/Icey/firmware/tools/iceyprog.py sram top.bin
```

Pack the text into a binary bitstream, and load it.

## What to read in the output

nextpnr prints a lot. Three parts matter most of the time.

The **utilisation** report, near the start:

```
Info: Device utilisation:
Info: 	         ICESTORM_LC:      91/   5280     1%
Info: 	        ICESTORM_RAM:       0/     30     0%
Info: 	               SB_IO:       4/     96     4%
```

`ICESTORM_LC` is logic cells, `ICESTORM_RAM` is block RAM, `ICESTORM_DSP` is the multipliers. If any of them goes over 100%, the build fails and you need to make something smaller.

The **timing** line, near the end:

```
Info: Max frequency for clock 'clk': 73.25 MHz (PASS at 12.00 MHz)
```

PASS means the slowest path in your design is fast enough for the clock you're running. nextpnr knows about the 12 MHz because `SB_HFOSC` tells it; for a clock coming in on a pin you'd tell it with `--freq`. If you see FAIL, read lesson 19.

And **warnings**. Most are harmless. Two are worth looking for every single time. Yosys's "Latch inferred" means you've got a latch (lesson 5). nextpnr's "unconstrained IO" means a top-level port name doesn't match anything in the `.pcf`, and the tool put it on a random pin. That one usually means a typo, like `led` instead of `LED`, and it produces a design that builds perfectly and does nothing.

## A Makefile

Typing four commands every time gets old quickly. The Icey repository has a shared Makefile in `firmware/examples/common.mk`, and every example folder uses it. Here's a cut-down version you can drop into your own project:

```make
VENV    ?= $(HOME)/.local/share/icey/venv
ICEY    ?= $(HOME)/Icey
PCF     ?= $(ICEY)/firmware/icey.pcf
SRCS    ?= $(wildcard *.v)
TOP     ?= top

top.json: $(SRCS)
	$(VENV)/bin/yowasp-yosys -q -p 'synth_ice40 -dsp -top $(TOP) -json $@' $^

top.asc: top.json $(PCF)
	$(VENV)/bin/yowasp-nextpnr-ice40 --up5k --package sg48 --json $< --pcf $(PCF) --asc $@

top.bin: top.asc
	$(VENV)/bin/yowasp-icepack $< $@

prog: top.bin
	$(VENV)/bin/python $(ICEY)/firmware/tools/iceyprog.py sram $<

clean:
	rm -f top.json top.asc top.bin

.PHONY: prog clean
```

`make prog` now does everything, and only reruns the steps whose inputs changed. Note the `-dsp` flag, which lets Yosys use the iCE40's hardware multipliers for `*`. Without it, a multiplication gets built out of LUTs, which works but is large and slow. Icestudio's builds leave it off, which matters once you start multiplying (lesson 19), and it's one of the reasons people move to the command line.

## Splitting a project into files

With your own Makefile you can finally organise a design the way it wants to be organised: one module per file. `debounce.v`, `pwm.v`, `top.v`. The `$(wildcard *.v)` line picks them all up, and Yosys works out the hierarchy from the instantiations. Modules you've tested once, like the debouncer, you'll now copy from project to project without thinking about them again. That's the real payoff of leaving the GUI: you start accumulating a library.

Put the folder in git while you're at it. Bitstreams and `.asc` files are build outputs; leave them out of the repository.

## Check yourself

Before moving on, get your mood lamp building and loading from a Makefile, with the oscillator in your own `top.v`. If the RGB LED breathes when you run `make prog`, you've got everything you need for the rest of the course.
