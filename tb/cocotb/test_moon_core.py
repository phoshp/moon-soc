import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def run_cpu_test(dut):
    """Run Moon-SoC RV64 core test with cocotb."""
    # Clock generator: 10ns period (100 MHz)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Apply reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    max_cycles = int(os.environ.get("MAX_CYCLES", "10000"))
    verbose = os.environ.get("VERBOSE", "0") == "1"

    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)

        if verbose:
            pc = int(dut.debug_pc.value)
            instr = int(dut.debug_instr.value)
            dut._log.info(f"[CYCLE {cycle}] PC=0x{pc:x} instr=0x{instr:x}")

        if dut.test_passed.value == 1:
            dut._log.info(f">>> [PASS] All Moon-SoC RV64 core tests passed at cycle {cycle}! <<<")
            return

        if dut.test_failed.value == 1:
            code = int(dut.test_error_code.value)
            dut._log.error(f">>> [FAIL] Test reported failure code: 0x{code:x} at cycle {cycle} <<<")
            raise AssertionError(f"Test failed with error code: 0x{code:x}")

    raise TimeoutError(f"Simulation timed out after {max_cycles} cycles!")
