# ==============================================================================
# Makefile for Moon-SoC RV64 (Cocotb Simulation)
# ==============================================================================

PYTHON ?= python3
SIM ?= verilator
TEST_HEX ?= $(PWD)/sw/tests/asm/test_rv64_all.hex
SIM_BUILD ?= sim_build

.PHONY: all test sim verbose-test pytest clean

all: test

# Run simulation using cocotb runner
test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX)

sim: test

# Run simulation with verbose cycle trace
verbose-test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX) -v

# Run simulation via pytest
pytest:
	pytest tb/cocotb/run_test.py

clean:
	rm -rf $(SIM_BUILD) obj_dir results.xml tb/cocotb/sim_build tb/cocotb/results.xml
	rm -rf .pytest_cache tb/cocotb/__pycache__
