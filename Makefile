# ==============================================================================
# Makefile for Moon-SoC RV64 (Cocotb Simulation)
# ==============================================================================

PYTHON ?= python3
SIM ?= verilator
TEST_HEX ?= $(PWD)/sw/tests/asm/test_rv64_all.hex
SIM_BUILD ?= sim_build

.PHONY: all test sim verbose-test pytest soc-test soc-periph-test soc-wfi-test clean

all: test soc-test

# Run simulation using cocotb runner (core-level)
test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX)

sim: test

# Run SoC Top-Level simulation test
soc-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(TEST_HEX)

# Run SoC Peripherals verification test
soc-periph-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_soc_periphs.hex

# Run SoC WFI and PMU clock-gating wake-up test
soc-wfi-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_wfi_pmu.hex

# Run simulation with verbose cycle trace
verbose-test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX) -v

# Run simulation via pytest
pytest:
	pytest tb/cocotb/run_test.py tb/cocotb/soc/run_soc_test.py

clean:
	rm -rf $(SIM_BUILD) sim_build_soc obj_dir results.xml tb/cocotb/sim_build tb/cocotb/results.xml
	rm -rf .pytest_cache tb/cocotb/__pycache__ tb/cocotb/soc/__pycache__
