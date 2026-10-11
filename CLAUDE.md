# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Moon-SoC is a 64-bit RISC-V (RV64IMA) processor core implementation in SystemVerilog featuring a 5-stage in-order pipeline, hardware multiplier/divider, atomic operations (LR/SC and AMO), Machine-mode CSR and trap support, and a cocotb-based Python simulation testbench with Verilator.

## Build, Test, and Simulation Commands

The project uses `cocotb`, Python, and Verilator for RTL simulation and verification.

### Cocotb Simulation
- **Run default test suite**: `make test` (or `make sim`, `make all`). Runs `python3 tb/cocotb/run_test.py sw/tests/asm/test_rv64_all.hex`.
- **Run with verbose cycle trace**: `make verbose-test` (prints cycle-by-cycle PC and instruction traces).
- **Run via pytest**: `make pytest` or `pytest tb/cocotb/run_test.py`.
- **Run a specific firmware test**:
  `python3 tb/cocotb/run_test.py <path_to_hex_file> [-v|--verbose] [--waves]`
- **Run using cocotb Makefile**:
  `make -C tb/cocotb SIM=verilator [TEST_HEX=<path_to_hex_file>]`
- **Legacy raw C++ Verilator runner**: `make legacy-test` (builds and runs `tb/verilator/tb_core_runner.cpp`).
- **Clean build artifacts**: `make clean` (deletes `sim_build/`, `obj_dir/`, `results.xml`, caches).

### Test Assembly & Hex Conversion
Software tests are assembled into raw flat binaries and converted to little-endian hex files:
- **Convert binary to simulation hex**: `python3 scripts/bin2hex.py <input.bin> <output.hex>`
- **Linker script**: `sw/common/link_test.ld` defines:
  - Reset vector / `.text`: `0x00001000`
  - Data / `.data` & `.bss`: `0x80000000`

### Simulation Pass/Fail Protocol
In the testbench (`tb/sv/tb_moon_core.sv`), the core signals test completion by writing to physical memory address `0x80001000`:
- `0xCAFEBABE`: Test Passed.
- Any other value (e.g. `0xDEAD00xx`): Test Failed with error code.

## Architecture & Code Structure

### Pipeline Architecture (5-Stage In-Order)

The core is structured across five sequential pipeline stages connected through top-level `rtl/core/moon_core.sv`:

1. **IF (Instruction Fetch - `rtl/core/moon_if_stage.sv`)**:
   - Manages PC starting at boot vector `0x00001000`.
   - Handles PC redirection for branches (from EX), traps, and `mret` (from CSR/EX).
   - Issues requests to instruction memory (`imem`).

2. **ID (Instruction Decode - `rtl/core/moon_id_stage.sv`)**:
   - Decodes RV64I base integer, RV64M (mul/div), RV64A (AMO & LR/SC), and SYSTEM/CSR instructions.
   - Instantiates 32 x 64-bit integer register file (`rtl/core/moon_regfile.sv`), with `x0` tied to zero.
   - Generates immediate values (I, S, B, U, J types) and control flags.

3. **EX (Execute - `rtl/core/moon_ex_stage.sv`)**:
   - Arithmetic/Logic: `rtl/core/moon_alu.sv` handles 64-bit operations and 32-bit W-variants (`addiw`, `subw`, `sllw`, etc.).
   - Multiplier: `rtl/core/moon_mul.sv` handles `mul`, `mulh`, `mulhsu`, `mulhu`, `mulw`.
   - Divider: `rtl/core/moon_div.sv` is a multi-cycle radix-2 divider asserting `busy_div` to stall upstream stages until complete.
   - Evaluates branch conditions and branch targets.
   - Contains operand forwarding multiplexers for ALU inputs.

4. **MEM (Memory - `rtl/core/moon_mem_stage.sv`)**:
   - Drives data memory bus (`dmem`) with byte strobes for SB, SH, SW, SD, and sign/zero-extends loads (LB, LH, LW, LD, LBU, LHU, LWU).
   - Atomic unit: `rtl/core/moon_amo.sv` executes atomic read-modify-write operations (AMOADD, AMOSWAP, etc.).
   - Reservation tracking: Implements `lr.d`/`sc.d` reservation register, with external invalidation input (`inv_valid_i`, `inv_addr_i`).

5. **WB (Writeback - `rtl/core/moon_wb_stage.sv`)**:
   - Commits results back to the register file, prioritizing: SC status, load data, jump link PC (`pc + 4`), CSR read data, multiplier result, divider result, or ALU result.

### Hazard and Pipeline Control (`rtl/core/moon_hazard_unit.sv`)
- **Forwarding**: Forwards data from EX/MEM and MEM/WB stages to EX stage operands (`fwd_a`, `fwd_b`).
- **Stalls**:
  - Load-Use hazard: Stalls IF and ID for 1 cycle, inserting a bubble into EX.
  - CSR hazard: Serializes CSR operations by stalling IF and ID while a CSR instruction is in EX or MEM.
  - Multi-cycle execution: Stalls IF, ID, EX, and MEM when `busy_div` is active.
- **Flushes**:
  - Branch misprediction: Flushes IF/ID and ID/EX stages.
  - Traps and `mret`: Flushes IF/ID, ID/EX, and EX/MEM stages.

### CSR & Trap Architecture (`rtl/core/moon_csr.sv`)
- Implements RISC-V Privileged Machine-Mode CSRs: `mstatus`, `misa` (RV64IMAFD), `mie`, `mtvec`, `mepc`, `mcause`, `mtval`, `mip`, `mhartid`, `mcycle`, `minstret`, and `fcsr`.
- Handles trap entry and vectoring via `mtvec` (default `0x00001000`) and return via `mret`.
- Supports timer, software (IPI), and external interrupt inputs.

### Testbench Hierarchy
- `tb/sv/tb_moon_core.sv`: SystemVerilog testbench wrapping `moon_core` with 256 KB memory space supporting ROM (`0x00001000`+) and RAM (`0x80000000`+), loading firmware via `$value$plusargs("hex_file=%s", ...)`.
- `tb/cocotb/test_moon_core.py`: Python cocotb test driving clock and reset, monitoring `test_passed`, `test_failed`, and cycle execution.
- `tb/cocotb/run_test.py`: Standalone Python runner using `cocotb_tools.runner`, supporting CLI arguments and `pytest`.
- `tb/cocotb/Makefile`: Standard cocotb Makefile integrating `Makefile.sim`.
