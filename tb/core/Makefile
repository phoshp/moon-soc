# ==============================================================================
# Cocotb Simulation Makefile for Moon-SoC RV64
# ==============================================================================

SIM ?= verilator
TOPLEVEL_LANG ?= verilog

REPO_ROOT ?= $(shell cd ../.. && pwd)
VERILOG_SOURCES = $(REPO_ROOT)/tb/core/tb_moon_core.sv
TOPLEVEL = tb_moon_core
COCOTB_TEST_MODULES = test_moon_core

EXTRA_ARGS += -I$(REPO_ROOT)/rtl/core -I$(REPO_ROOT)/tb/core
EXTRA_ARGS += -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-UNUSED

TEST_HEX ?= $(REPO_ROOT)/sw/tests/asm/test_rv64_all.hex
COCOTB_PLUSARGS += +hex_file=$(TEST_HEX)

include $(shell cocotb-config --makefiles)/Makefile.sim
