# ============================================================================
# File: tb/cocotb/soc/test_moon_soc.py
# Description: Cocotb test routines for Moon-SoC Top-Level verification.
# ============================================================================

import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def run_soc_test(dut):
    """Run Moon-SoC Top-Level test with AXI4 interconnect and peripherals."""
    cocotb.log.info("Starting Moon-SoC Top-Level Cocotb Test...")

    # Start 100 MHz clock (10 ns period)
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Initialize Inputs
    dut.rst_n.value = 0
    await Timer(50, unit="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    cocotb.log.info("Reset released.")

    max_cycles = int(os.environ.get("MAX_CYCLES", "5000"))
    verbose = os.environ.get("VERBOSE", "0") == "1"

    cycle = 0
    passed = False
    failed = False
    last_pc = None

    while cycle < max_cycles:
        await RisingEdge(dut.clk)
        cycle += 1

        pc = dut.debug_pc.value.to_unsigned()
        if verbose and (pc != last_pc):
            cocotb.log.info(f"Cycle {cycle:5d} | PC: 0x{pc:016x} | Instr: 0x{dut.debug_instr.value.to_unsigned():08x}")
        last_pc = pc

        if dut.test_passed.value == 1:
            passed = True
            break

        if dut.test_failed.value == 1:
            failed = True
            err_code = dut.test_error_code.value.to_unsigned()
            cocotb.log.error(f">>> [FAIL] Test failed at cycle {cycle} with error code: 0x{err_code:08x} at PC 0x{pc:016x}")
            break

    if passed:
        cocotb.log.info(f">>> [PASS] Moon-SoC Top-Level test passed at cycle {cycle}! <<<")
    elif not failed:
        raise AssertionError(f"Moon-SoC test timed out after {max_cycles} cycles at PC 0x{last_pc:016x}")
    else:
        raise AssertionError(f"Test failed at cycle {cycle} with error code 0x{dut.test_error_code.value.to_unsigned():08x}")
