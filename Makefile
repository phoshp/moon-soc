# ==============================================================================
# Makefile for Moon-SoC RV64 (Cocotb Simulation)
# ==============================================================================

PYTHON ?= $(if $(wildcard $(PWD)/.venv/bin/python3),$(PWD)/.venv/bin/python3,python3)
SIM ?= verilator
TEST_HEX ?= $(PWD)/tb/tests/asm/base/test_rv64_all.hex
SIM_BUILD ?= sim_build

.PHONY: all test sim verbose-test pytest soc-test soc-periph-test soc-wfi-test soc-cache-test soc-compressed-test soc-smode-test soc-pmp-test soc-mmu-test soc-fp-test clean

all: test soc-test

# Run simulation using cocotb runner (core-level)
test:
	$(PYTHON) tb/core/run_test.py $(TEST_HEX)

sim: test

# Run SoC Top-Level simulation test
soc-test:
	$(PYTHON) tb/soc/run_soc_test.py $(TEST_HEX)

# Run SoC Compressed 16-bit instructions verification test (RV64C)
soc-compressed-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/base/test_compressed.hex

# Run SoC Supervisor Mode & Privilege Architecture verification test
soc-smode-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/privileged/test_smode.hex

# Run SoC Physical Memory Protection (PMP & Smepmp) verification test
soc-pmp-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/privileged/test_pmp.hex

# Run SoC Sv39 virtual memory translation verification test
soc-mmu-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/privileged/test_mmu_sv39.hex

# Run scalar F/D floating-point verification test
soc-fp-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/fp/test_fp_moves.hex

# Run SoC Peripherals verification test (UART, SRAM, CLINT, PLIC, CRG, PMU)
soc-periph-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/soc/test_soc_periphs.hex

# Run SoC WFI and PMU clock-gating wake-up test
soc-wfi-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/soc/test_wfi_pmu.hex

# Run L1 Cache Subsystem verification test (writeback, eviction, hits)
soc-cache-test:
	$(PYTHON) tb/soc/run_soc_test.py $(PWD)/tb/tests/asm/soc/test_cache_ops.hex

# Run simulation with verbose cycle trace
verbose-test:
	$(PYTHON) tb/core/run_test.py $(TEST_HEX) -v

# Run simulation via pytest
pytest:
	pytest tb/core/run_test.py tb/soc/run_soc_test.py

clean:
	rm -rf $(SIM_BUILD) sim_build_soc obj_dir results.xml tb/core/sim_build tb/core/results.xml
	rm -rf .pytest_cache tb/core/__pycache__ tb/soc/__pycache__
