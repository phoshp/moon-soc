# ==============================================================================
# Makefile for Moon-SoC RV64 (Cocotb Simulation)
# ==============================================================================

PYTHON ?= python3
SIM ?= verilator
TEST_HEX ?= $(PWD)/sw/tests/asm/test_rv64_all.hex
SIM_BUILD ?= sim_build

.PHONY: all test sim verbose-test pytest soc-test soc-periph-test soc-wfi-test soc-cache-test soc-bitmanip-test soc-compressed-test soc-smode-test soc-pmp-test soc-mmu-test soc-fp-test clean

all: test soc-test

# Run simulation using cocotb runner (core-level)
test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX)

sim: test

# Run SoC Top-Level simulation test
soc-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(TEST_HEX)

# Run SoC Bitmanipulation verification test (Zba, Zbb, Zbs)
soc-bitmanip-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_bitmanip.hex

# Run SoC Compressed 16-bit instructions verification test (Zca, Zcb)
soc-compressed-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_compressed.hex

# Run SoC Supervisor Mode & Privilege Architecture verification test
soc-smode-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_smode.hex

# Run SoC Physical Memory Protection (PMP & Smepmp) verification test
soc-pmp-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_pmp.hex

# Run SoC Sv39 virtual memory translation verification test
soc-mmu-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_mmu_sv39.hex

.PHONY: soc-crypto-test soc-crypto-aes-test soc-crypto-aes-rounds-test soc-crypto-sha512-test soc-rvv-test soc-rvv-memory-test soc-rvv-csr-test soc-rvv-fault-test soc-rvv-fault-restart-test
soc-crypto-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_crypto_sha256.hex

soc-crypto-aes-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_crypto_aes64ks2.hex

soc-crypto-aes-rounds-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_crypto_aes64rounds.hex

soc-crypto-sha512-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_crypto_sha512.hex

soc-rvv-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_rvv_base.hex

soc-rvv-memory-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_rvv_memory.hex

soc-rvv-csr-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_rvv_csrs.hex

soc-rvv-fault-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_rvv_fault.hex

soc-rvv-fault-restart-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_rvv_fault_restart.hex

soc-fp-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_fp_moves.hex

# Run SoC Peripherals verification test
soc-periph-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_soc_periphs.hex

# Run SoC WFI and PMU clock-gating wake-up test
soc-wfi-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_wfi_pmu.hex

# Run L1 Cache Subsystem verification test (writeback, eviction, hits)
soc-cache-test:
	$(PYTHON) tb/cocotb/soc/run_soc_test.py $(PWD)/sw/tests/asm/test_cache_ops.hex

# Run simulation with verbose cycle trace
verbose-test:
	$(PYTHON) tb/cocotb/run_test.py $(TEST_HEX) -v

# Run simulation via pytest
pytest:
	pytest tb/cocotb/run_test.py tb/cocotb/soc/run_soc_test.py

clean:
	rm -rf $(SIM_BUILD) sim_build_soc obj_dir results.xml tb/cocotb/sim_build tb/cocotb/results.xml
	rm -rf .pytest_cache tb/cocotb/__pycache__ tb/cocotb/soc/__pycache__
