# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Moon-SoC is a 64-bit RISC-V processor and SoC implementation in SystemVerilog. It has a 5-stage in-order pipeline, hardware integer multiply/divide, atomic operations, privileged architecture support, caches, scalar F/D and crypto extensions, and an evolving RVV unit. Simulation uses cocotb and Verilator.

## Current RVA23 Development Status

Phase 4 (integer, compressed, Supervisor-mode, PMP, and Sv39 work) is complete for the current project scope and has directed SoC test targets. Phase 5 is active:

- Scalar F/D paths cover arithmetic, division, square root, comparisons, conversions, moves/classification, and fused multiply-add. Target: `make soc-fp-test`.
- Scalar AES64 and SHA-256/SHA-512 integer operations are implemented. Targets: `make soc-crypto-test`, `make soc-crypto-aes-test`, `make soc-crypto-aes-rounds-test`, and `make soc-crypto-sha512-test`.
- `rtl/core/moon_vector_unit.sv` currently provides a VLEN=128, LMUL=1 integer slice with e8/e16/e32/e64 configuration and execution, including v0-masked arithmetic and mask logical operations. Target: `make soc-rvv-test`.
- RVV 1.0 is not complete. Vector memory operations, full vector CSR/vstart/vill behavior, complete tail and mask policies, reductions, remaining vector arithmetic families, and vector floating point remain future work. Do not describe the Phase 5 implementation as full RVV compliance.

The user prefers each minimal implementation and its regression to be committed as separate small commits. Keep generated firmware `.s`, `.bin`, and `.hex` changes together in the regression commit. `ROADMAP_RVA23_PLAN.md` is intentionally gitignored and serves as a local progress plan.

## Build, Test, and Simulation Commands

The project uses `cocotb`, Python, and Verilator for RTL simulation and verification.

### Cocotb Simulation
- **Run default test suite**: `make test` (or `make sim`). Runs `python3 tb/cocotb/run_test.py sw/tests/asm/test_rv64_all.hex`.
- **Run full suite (core + SoC)**: `make all`.
- **Run SoC Top-Level test suite**: `make soc-test` (runs `tb/cocotb/soc/run_soc_test.py` with `test_rv64_all.hex`).
- **Run SoC Peripherals verification**: `make soc-periph-test` (verifies UART 16550, SRAM, CLINT, PLIC, CRG, PMU).
- **Run SoC WFI & PMU clock-gating test**: `make soc-wfi-test` (verifies WFI execution, PMU clock-gating, and timer wake-up).
- **Run SoC L1 Cache verification**: `make soc-cache-test` (verifies 32KB L1-I and L1-D caches, writeback, eviction, hits).
- **Run scalar F/D verification**: `make soc-fp-test`.
- **Run scalar crypto verification**: `make soc-crypto-test`, `make soc-crypto-aes-test`, `make soc-crypto-aes-rounds-test`, and `make soc-crypto-sha512-test`.
- **Run the implemented RVV integer-slice verification**: `make soc-rvv-test`.
- **Run with verbose cycle trace**: `make verbose-test`.
- **Run via pytest**: `make pytest` (runs both core and SoC regression testbenches).
- **Run a specific firmware test**:
  `python3 tb/cocotb/run_test.py <path_to_hex_file> [-v|--verbose] [--waves]`
  or for SoC top-level:
  `python3 tb/cocotb/soc/run_soc_test.py <path_to_hex_file> [-v|--verbose] [--waves]`
- **Clean build artifacts**: `make clean` (deletes `sim_build/`, `sim_build_soc/`, `obj_dir/`, caches).

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
   - Instantiates scalar F/D datapaths and the current RVV integer slice; see the Phase 5 status above for the supported subset and gaps.

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

### SoC Subsystems & Infrastructure (`rtl/soc/`)
- **L1 Cache Subsystem (`rtl/core/cache/`)**:
  - `moon_icache.sv`: 32 KB 4-way set-associative L1 instruction cache with 64-byte lines, AXI4 burst refill (M0), and FENCE.I support.
  - `moon_dcache.sv`: 32 KB 4-way set-associative L1 data cache with write-back, write-allocate, AXI4 burst refill/eviction (M1), uncached I/O bypass, and RVA23 Zicbom/Zicboz operations.
  - `moon_l1_cache_subsystem.sv`: Integrated L1 cache wrapper connecting core IF/MEM interfaces directly to AXI4 masters.
- **Top-Level Integration (`rtl/soc/top/moon_soc_top.sv`)**: Integrates `moon_core`, `moon_l1_cache_subsystem`, 64-bit AXI4 crossbar, AXI-to-APB bridge, Boot ROM, On-Chip SRAM, CLINT, PLIC, UART 16550, CRG, PMU, and external AXI memory port.
- **Interconnect (`rtl/soc/interconnect/`)**:
  - `axi_pkg.sv`: AXI4 and APB4 signal definitions, transaction structs, and burst/response codes.
  - `axi_crossbar.sv`: Multi-master, multi-slave 64-bit crossbar switch (M0: Fetch, M1: Data; S0: Boot ROM, S1: SRAM, S2: APB Bridge, S3: External RAM).
  - `axi_to_apb_bridge.sv`: 64-bit AXI4 to 32-bit APB4 transaction converter.
  - `apb_crossbar.sv`: Address decoder demultiplexing APB peripheral requests (CLINT, PLIC, UART).
- **Core AXI Adapter (`rtl/soc/adapter/moon_core_axi_adapter.sv`)**: Converts `moon_core`'s `imem` and `dmem` interfaces to AXI4 master channels with prefetch buffering.
- **Memory Subsystem (`rtl/soc/memory/`)**:
  - `moon_bootrom.sv`: 32 KB Boot ROM at `0x0000_1000`.
  - `moon_sram_ctrl.sv`: 128 KB On-Chip SRAM controller at `0x7000_0000`.
- **Clock Subsystem (`rtl/soc/clock/`)**:
  - `moon_pll_model.sv`: Digital behavioral PLL frequency synthesizer with lock detection and programmable dividers.
  - `clk_mux_glitchless.sv`: Dual-input glitchless clock multiplexer for safe dynamic clock switching between reference and PLL clocks.
  - `cg_cell.sv`: Integrated Clock Gating (ICG) latch cell for glitch-free dynamic clock gating.
  - `moon_crg.sv`: Clock & Reset Generator with APB registers (`0x1000_5000`) for PLL control and domain clock gating.
- **Power Management Subsystem (`rtl/soc/pmu/`)**:
  - `moon_reset_ctrl.sv`: Central reset sequencer with 2-stage synchronizers and multi-cycle domain reset release (AON -> Memory/Periph -> Core).
  - `moon_pmu.sv`: Multi-state Power Management Unit (`0x1000_5080`) handling RUN, WFI clock gating, SLEEP, DEEP-SLEEP, and wake-up interrupt routing.
- **Peripherals Subsystem (`rtl/soc/periph/`)**:
  - `moon_clint.sv`: Core-Local Interruptor (`mtime`, `mtimecmp`, `msip`) at `0x0200_0000`.
  - `moon_plic.sv`: Platform-Level Interrupt Controller at `0x0C00_0000`.
  - `moon_uart.sv`: 16550 UART console controller at `0x1000_0000`.

### Testbench Hierarchy
- `tb/sv/tb_moon_core.sv`: Standalone core memory harness.
- `tb/sv/soc/tb_moon_soc.sv`: Full SoC simulation harness integrating Boot ROM, external AXI RAM model, and UART sink.
- `tb/cocotb/test_moon_core.py` & `tb/cocotb/run_test.py`: Standalone core testbench runner.
- `tb/cocotb/soc/test_moon_soc.py` & `tb/cocotb/soc/run_soc_test.py`: Full SoC testbench runner.
- `tb/cocotb/Makefile`: Standard cocotb Makefile integrating `Makefile.sim`.
