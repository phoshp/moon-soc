# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## Overview

Moon-SoC is a 64-bit RISC-V processor and SoC implementation in SystemVerilog. It has a 5-stage in-order pipeline, hardware integer multiply/divide, atomic operations, privileged architecture support (M/S/U modes), Sv39 MMU, caches, and scalar F/D support. Simulation uses cocotb and Verilator.

## Current RV64GC Compliance Status

The core is structured for synthesizable, legit **RISC-V RV64GC** (RV64IMAFD_Zicsr_Zifencei_C) compliance with Privileged Machine/Supervisor/User modes and Sv39 MMU virtual memory translation:

- **RV64I**: 64-bit base integer and 32-bit word operations.
- **RV64M**: 4-cycle compact 32×32 iterative hardware multiplier (`moon_mul.sv`) and multi-cycle radix-2 divider (`moon_div.sv`). Multi-cycle execution is properly stalled via `busy_mul` and `busy_div` in `moon_hazard_unit.sv`.
- **RV64A**: Atomic memory operations and LR/SC reservation tracking (`moon_amo.sv`).
- **RV64F/D**: Scalar single and double-precision floating-point execution. Target: `make soc-fp-test`.
- **RV64C**: Standard 16-bit compressed instruction decoder (`moon_c_decoder.sv`). Target: `make soc-compressed-test`.
- **Sv39 MMU**: 3-level page table walker (`moon_ptw.sv`), DTLB, and ITLB. Target: `make soc-mmu-test`.
- **PMP**: Physical memory protection unit (`moon_pmp.sv`). Target: `make soc-pmp-test`.
- **Non-standard bloat removed**: Scalar AES and SHA cryptography extensions, bitmanip (Zba/Zbb/Zbs), compressed subwords (Zcb), and experimental vector extensions were stripped to ensure compact ASIC synthesizability and strict RV64GC compliance.

## Build, Test, and Simulation Commands

The project uses `cocotb`, Python, and Verilator for RTL simulation and verification.

### Cocotb Simulation
- **Run default test suite**: `make test` (or `make sim`). Runs `python3 tb/core/run_test.py tb/tests/asm/base/test_rv64_all.hex`.
- **Run full suite (core + SoC)**: `make all`.
- **Run SoC Top-Level test suite**: `make soc-test` (runs `tb/soc/run_soc_test.py` with `test_rv64_all.hex`).
- **Run SoC Compressed instructions test**: `make soc-compressed-test`.
- **Run SoC Supervisor Mode test**: `make soc-smode-test`.
- **Run SoC Physical Memory Protection test**: `make soc-pmp-test`.
- **Run SoC Sv39 MMU virtual memory test**: `make soc-mmu-test`.
- **Run scalar F/D verification**: `make soc-fp-test`.
- **Run SoC Peripherals verification**: `make soc-periph-test` (verifies UART 16550, SRAM, CLINT, PLIC, CRG, PMU).
- **Run SoC WFI & PMU clock-gating test**: `make soc-wfi-test` (verifies WFI execution, PMU clock-gating, and timer wake-up).
- **Run SoC L1 Cache verification**: `make soc-cache-test` (verifies 4-way set-associative L1-I and L1-D caches, writeback, eviction, hits).
- **Run with verbose cycle trace**: `make verbose-test`.
- **Run via pytest**: `make pytest` (runs both core and SoC regression testbenches).
- **Clean build artifacts**: `make clean` (deletes `sim_build/`, `sim_build_soc/`, `obj_dir/`, caches).

### Test Assembly & Hex Conversion
Software tests are assembled into raw flat binaries and converted to little-endian hex files:
- **Convert binary to simulation hex**: `python3 tb/bin2hex.py <input.bin> <output.hex>`
- **Linker script**: `tb/link_test.ld` defines:
  - Reset vector / `.text`: `0x00001000`
  - Data / `.data` & `.bss`: `0x80000000`

### Simulation Pass/Fail Protocol
In the testbench (`tb/core/tb_moon_core.sv`), the core signals test completion by writing to physical memory address `0x80001000`:
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
The SoC is structured into modern macro partitions (matching commercial AMD/Intel/Nvidia floorplans) enabling modular ASIC hardening and fast top-level synthesis:
- **Compute Tile (`rtl/soc/cpu/moon_cpu_tile.sv`)**: Encapsulates `moon_core` (RV64IMA, CSRs, MMU, PMP, optional FPU and Vector co-processors).
- **Cache Subsystem Tile (`rtl/soc/cache/moon_cache_tile.sv`)**:
  - `moon_icache.sv`: 4-way set-associative L1 instruction cache with 64-byte lines, AXI4 burst refill (M0), and FENCE.I support.
  - `moon_dcache.sv`: 4-way set-associative L1 data cache with write-back, write-allocate, AXI4 burst refill/eviction (M1), uncached I/O bypass, and RVA23 Zicbom/Zicboz operations.
  - `moon_l1_cache_subsystem.sv`: Integrated L1 cache wrapper connecting core IF/MEM interfaces directly to AXI4 masters.
- **Memory Subsystem (`rtl/soc/memory/moon_mem_subsystem.sv`)**:
  - `moon_bootrom.sv`: Boot ROM at `0x0000_1000`.
  - `moon_sram_ctrl.sv`: On-Chip SRAM controller at `0x7000_0000` supporting behavioral SRAM and OpenRAM physical macro arrays (`openram_sram_wrapper.sv`).
- **System Interconnect Fabric (`rtl/soc/interconnect/moon_sys_fabric.sv`)**:
  - `axi_pkg.sv`: AXI4 and APB4 signal definitions, transaction structs, and burst/response codes.
  - `axi_crossbar.sv`: Multi-master, multi-slave 64-bit crossbar switch (M0: Fetch, M1: Data; S0: Boot ROM, S1: SRAM, S2: APB Bridge, S3: External RAM).
  - `axi_to_apb_bridge.sv`: 64-bit AXI4 to 32-bit APB4 transaction converter.
  - `apb_crossbar.sv`: Address decoder demultiplexing APB peripheral requests (CLINT, PLIC, UART, CRG, PMU, SPI, I2C).
- **Peripheral Subsystem (`rtl/soc/periph/moon_periph_subsystem.sv`)**:
  - `moon_clint.sv`: Core-Local Interruptor (`mtime`, `mtimecmp`, `msip`) at `0x0200_0000`.
  - `moon_plic.sv`: Platform-Level Interrupt Controller at `0x0C00_0000`.
  - `moon_uart.sv`: 16550 UART console controller at `0x1000_0000`.
  - `moon_spi.sv`: SPI master controller at `0x1000_6000`.
  - `moon_i2c.sv`: I2C master controller at `0x1000_7000`.
- **System Control Subsystem (`rtl/soc/sysctrl/moon_sysctrl_subsystem.sv`)**:
  - `moon_reset_ctrl.sv`: Central reset sequencer with 2-stage synchronizers and multi-cycle domain reset release (AON -> Memory/Periph -> Core).
  - `moon_crg.sv`: Clock & Reset Generator with APB registers (`0x1000_5000`), glitchless multiplexers (`clk_mux_glitchless.sv`), clock gating cells (`cg_cell.sv`), and PLL synthesizer (`moon_pll_model.sv`).
  - `moon_pmu.sv`: Multi-state Power Management Unit (`0x1000_5080`) handling RUN, WFI clock gating, SLEEP, DEEP-SLEEP, and wake-up interrupt routing.
- **PHY Blocks (`rtl/soc/phy/`)**:
  - `moon_mem_phy.sv`: External Memory PHY providing timing isolation registers for external DRAM/HyperRAM AXI bus pads.
  - `moon_io_phy.sv`: Peripheral I/O PHY providing pad drivers, tri-state control, and glitch/metastability synchronizers.
- **Top-Level Integration (`rtl/soc/top/moon_soc_top.sv`)**: Integrates the 8 macro blocks into the unified SoC die.
- **Synthesis & Macro Infrastructure (`synth/`)**:
  - `synth/macros/blackbox/moon_soc_macros_bb.sv`: Macro blackbox stubs for instantaneous Yosys top-level elaboration.
  - `synth/macros/*/config.json`: Independent LibreLane hardening configs for each block.
  - `synth/top/config.json` & `synth/top/macro_placement.cfg`: Top-level chip assembly and macro floorplan.
  - `synth/librelane_hierarchical_soc.ipynb`: Automated Google Colab notebook for hardening macros and assembling the top-level chip.

### Testbench Hierarchy
- `tb/core/tb_moon_core.sv`: Standalone core memory harness.
- `tb/soc/tb_moon_soc.sv`: Full SoC simulation harness integrating Boot ROM, external AXI RAM model, and UART sink.
- `tb/core/test_moon_core.py` & `tb/core/run_test.py`: Standalone core testbench runner.
- `tb/soc/test_moon_soc.py` & `tb/soc/run_soc_test.py`: Full SoC testbench runner.
- `tb/core/Makefile`: Standard cocotb Makefile integrating `Makefile.sim`.
