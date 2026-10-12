# Shared build rules for Icey examples.  Usage from an example dir:
#   make        build top.bin
#   make prog   load into FPGA SRAM over USB
# Tools come from the venv created by tools/setup.sh (override ICEY_VENV),
# falling back to yosys/nextpnr-ice40/icepack on PATH.

ROOT    := $(dir $(lastword $(MAKEFILE_LIST)))..
ICEY_VENV ?= $(HOME)/.local/share/icey/venv
PCF     ?= $(ROOT)/icey.pcf
SRCS    ?= top.v
TOP     ?= top

ifneq ($(wildcard $(ICEY_VENV)/bin/yowasp-yosys),)
YOSYS   := $(ICEY_VENV)/bin/yowasp-yosys
NEXTPNR := $(ICEY_VENV)/bin/yowasp-nextpnr-ice40
ICEPACK := $(ICEY_VENV)/bin/yowasp-icepack
else
YOSYS   := yosys
NEXTPNR := nextpnr-ice40
ICEPACK := icepack
endif
PYTHON  := $(if $(wildcard $(ICEY_VENV)/bin/python),$(ICEY_VENV)/bin/python,python3)

all: $(TOP).bin

$(TOP).json: $(SRCS)
	$(YOSYS) -q -p 'synth_ice40 -top $(TOP) -json $@' $^

$(TOP).asc: $(TOP).json $(PCF)
	$(NEXTPNR) -q --up5k --package sg48 --json $< --pcf $(PCF) --asc $@

$(TOP).bin: $(TOP).asc
	$(ICEPACK) $< $@

prog: $(TOP).bin
	$(PYTHON) $(ROOT)/tools/iceyprog.py sram $<

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin

.PHONY: all prog clean
