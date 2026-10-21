# Moon-SoC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ISA: RISC-V RV64GC](https://img.shields.io/badge/ISA-RISC--V_RV64GC-orange.svg)](https://riscv.org/)
[![Simulator: Verilator](https://img.shields.io/badge/Simulator-Verilator_5+-lightgrey.svg)](https://www.veripool.org/verilator/)
[![Verification: Cocotb](https://img.shields.io/badge/Verification-Cocotb_2.x-brightgreen.svg)](https://www.cocotb.org/)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg)](https://www.python.org/)
[![Build: Passing](https://img.shields.io/badge/Build-Passing-success.svg)](#running-simulation)

Moon-SoC is a compact, synthesizable 64-bit RISC-V processor and SoC written in SystemVerilog. It implements standard **RISC-V RV64GC** (RV64IMAFD_Zicsr_Zifencei_C) compliance with a 5-stage in-order pipeline, multi-cycle hardware integer multiply/divide, atomic memory operations, privileged architecture (M, S, U modes), Sv39 MMU virtual memory translation, 4-way set-associative L1 caches, and physical Sky130 OpenRAM SRAM macro integration.

Verification is implemented in Python using [cocotb](https://www.cocotb.org/) and [Verilator](https://www.veripool.org/verilator/), providing fast simulation alongside flexible test orchestration.

---

## Current Project Status: Clean RV64GC Compliance

The design is optimized for clean ASIC standard-cell synthesis and timing closure targeting **SkyWater Sky130** via **LibreLane** / **OpenROAD**. Non-standard, high-area extensions (scalar AES/SHA cryptography, Zba/Zbb/Zbs bitmanipulation, Zcb, and experimental vector units) have been stripped to deliver a lean, tapeout-ready, standards-compliant RV64GC core.

### Implemented ISA Extensions & Features

- **RV64I Base Integer ISA**:
  - Full 64-bit integer compute, branching, and immediate generation.
  - Complete support for RV64 32-bit word operations (`addiw`, `subw`, `sllw`, `srlw`, `sraw`, `addw`, `subw`, etc.).
  - 32 × 64-bit general-purpose integer register file (`x0` hardwired to zero; `x1`..`x31` implemented without unnecessary hardware reset overhead).
- **RV64M Hardware Multiplier & Divider**:
  - **Compact 4-Cycle Iterative Multiplier** (`moon_mul.sv`): Uses a single 32×32-bit multiplier core with early completion (1-cycle `mulw`, 2-cycle `mul`, 3–4 cycle `mulh`/`mulhu`/`mulhsu`), reducing multiplier gate count by ~75% compared to monolithic 64×64 arrays.
  - **Multi-Cycle Radix-2 Hardware Divider** (`moon_div.sv`): Digit-recurrence restoring/non-restoring engine with word-level early termination (`div`, `divu`, `rem`, `remu`, `divw`, `divuw`, `remw`, `remuw`).
  - Stalls are automatically orchestrated through `busy_mul` and `busy_div` in `moon_hazard_unit.sv`.
- **RV64A Atomic Extension**:
  - Load-Reserved / Store-Conditional (`lr.d`, `sc.d`) with reservation register and external coherence bus invalidation interface (`inv_valid_i`, `inv_addr_i`).
  - Atomic Memory Operations (AMO): `amoadd`, `amoswap`, `amoxor`, `amoand`, `amoor`, `amomin`, `amomax`, `amominu`, `amomaxu` in both `.w` and `.d` widths.
- **RV64F & RV64D Floating-Point Extensions**:
  - IEEE-754 single-precision (binary32) and double-precision (binary64) scalar execution with dedicated 32 × 64-bit floating-point register file (`moon_fregfile.sv`) and `fcsr` rounding mode/exception flag management.
- **RV64C Standard Compressed Instructions**:
  - Full standard 16-bit compressed instruction decoding (`moon_c_decoder.sv`) across Quadrants 0, 1, and 2 (`c.addi`, `c.li`, `c.lui`, `c.lw`, `c.ld`, `c.sw`, `c.sd`, `c.j`, `c.jal`, `c.beqz`, `c.bnez`, etc.).
- **Privileged Architecture (Machine, Supervisor, User Modes)**:
  - Complete trap vectoring, exception delegation (`medeleg`), interrupt delegation (`mideleg`), and return via `mret`/`sret`.
  - Machine and Supervisor CSRs: `mstatus`, `misa`, `mie`, `mtvec`, `mepc`, `mcause`, `mtval`, `mip`, `mhartid`, `mcycle`, `minstret`, `sstatus`, `stvec`, `sscratch`, `sepc`, `scause`, `stval`, `sip`, `satp`.
- **Sv39 Memory Management Unit (MMU)**:
  - 3-level hardware Page Table Walker (`moon_ptw.sv`) with gigapage (1 GB), megapage (2 MB), and base page (4 KB) leaf support.
  - Fully associative L1 Data TLB (`moon_dtlb.sv`) and Instruction TLB (`moon_itlb.sv`).
  - Hardware `sfence.vma` address space and virtual address invalidation.
- **Physical Memory Protection (PMP)**:
  - Programmable PMP entries with TOR, NA4, and NAPOT matching modes and lock bits (`moon_pmp.sv`).
- **L1 Cache Subsystem**:
  - 4-way set-associative L1-I Cache (64-byte lines, AXI4 burst refills, FENCE.I support).
  - 4-way set-associative L1-D Cache (64-byte lines, write-back, write-allocate, AXI4 burst refills and evictions, uncached I/O bypass).
- **Physical Silicon Memory Macro Integration**:
  - On-Chip SRAM uses dual-port **SkyWater Sky130 OpenRAM macros** (`sky130_sram_2kbyte_1rw1r_32x512_8`).
  - Pre-CTS ideal clock constraints (`pnr.sdc`) and nominal corner consolidation keep OpenROAD PnR memory consumption well below **2 GB RAM**.

---

## Core Pipeline Architecture

```text
       +----------+    +----------+    +----------+    +----------+    +----------+
       |    IF    |    |    ID    |    |    EX    |    |   MEM    |    |    WB    |
       |  Fetch   |--->|  Decode  |--->| ALU/FPU/ |--->|  Memory  |--->|Writeback |
       |          |    |          |    | Mul/Div  |    |          |    |          |
       +----------+    +----------+    +----------+    +----------+    +----------+
            |               |               |               |               |
         PC Gen         Regfile Read    64-bit ALU      Load / Store     Regfile
        imem bus         Imm Gen        4-Cycle Mul     AMO Unit         Commit
        ITLB / MMU      Hazard Unit     64-Cycle Div    LR/SC Check
                                        Branch Target   dmem bus
                                        DTLB / MMU
            ^               ^               |               |               |
            |               |               v               v               |
            +---------------+-------- Forwarding & Hazard Control ----------+
```

---

## Getting Started

### Prerequisites

- **Verilator** (version 5.0 or newer):
  ```bash
  # Fedora / RHEL
  sudo dnf install verilator
  # Ubuntu / Debian
  sudo apt-get install verilator
  ```
- **Python 3.10+**, **cocotb**, and **pytest**:
  ```bash
  python3 -m pip install -r requirements.txt
  ```
- **RISC-V 64-bit Cross-Compiler** (for assembling test firmware):
  ```bash
  # Fedora
  sudo dnf install gcc-riscv64-linux-gnu
  # Ubuntu / Debian
  sudo apt-get install gcc-riscv64-linux-gnu
  ```

---

## Running Simulation

All simulation commands can be run directly from the repository root:

| Command | Description |
| :--- | :--- |
| `make test` | Runs core-level verification suite (`test_rv64_all.hex`: RV64I, RV64M, RV64A). |
| `make soc-test` | Runs SoC top-level verification suite with AXI4 interconnect and peripherals. |
| `make all` | Runs both core-level and full SoC top-level suites. |
| `make soc-compressed-test` | Verifies standard RV64C 16-bit compressed instruction execution. |
| `make soc-smode-test` | Verifies Supervisor Mode privilege transitions and CSR delegation. |
| `make soc-pmp-test` | Verifies Physical Memory Protection (PMP & Smepmp) access controls. |
| `make soc-mmu-test` | Verifies Sv39 MMU 3-level page table walking and `sfence.vma` invalidation. |
| `make soc-fp-test` | Verifies scalar F/D floating-point register operations and moves. |
| `make soc-periph-test` | Verifies SoC peripherals (16550 UART, SRAM, CLINT, PLIC, CRG, PMU). |
| `make soc-wfi-test` | Verifies WFI execution, PMU clock-gating, and timer wake-up. |
| `make soc-cache-test` | Verifies 4-way L1-I and L1-D caches (hits, misses, writeback, eviction). |
| `make pytest` | Runs both core and SoC regression testbenches via `pytest`. |
| `make verbose-test` | Runs core simulation with cycle-by-cycle instruction and PC traces. |
| `make clean` | Removes build directories (`sim_build/`, `sim_build_soc/`, `obj_dir/`). |

### Custom Firmware Execution

To simulate custom assembled firmware:
```bash
python3 tb/soc/run_soc_test.py path/to/firmware.hex [--verbose] [--waves]
```

Firmware binaries are converted to simulation hex format using:
```bash
python3 tb/bin2hex.py firmware.bin firmware.hex
```

---

## ASIC Synthesis & Macro Hardening

Moon-SoC is structured into modular macro partitions for fast hierarchical ASIC hardening with LibreLane / OpenROAD targeting SkyWater Sky130:

- **Compute Tile** (`rtl/soc/cpu/` -> `synth/macros/cpu_tile/`): Hardens `moon_cpu_tile` with area-optimized synthesis and pre-CTS ideal clocks (`pnr.sdc`).
- **Cache Tile** (`rtl/soc/cache/` -> `synth/macros/cache_tile/`): 4-way L1-I and L1-D cache subsystem.
- **Memory Subsystem** (`rtl/soc/memory/` -> `synth/macros/mem_subsystem/`): Integrates 4 KB Boot ROM and Sky130 OpenRAM macros.
- **System Fabric** (`rtl/soc/interconnect/` -> `synth/macros/sys_fabric/`): 64-bit multi-master AXI4 crossbar and APB bridge.
- **System Control** (`rtl/soc/sysctrl/` -> `synth/macros/sysctrl_subsystem/`): Clock & Reset Generator (CRG), reset sequencer, and Power Management Unit (PMU).
- **Peripheral Subsystem** (`rtl/soc/periph/` -> `synth/macros/periph_subsystem/`): CLINT, PLIC, UART 16550, SPI, and I2C.

See `synth/README.md` and `synth/librelane_hierarchical_soc.ipynb` for automated hardening notebooks and macro placement configurations.

---

## Contributing

Contributions are warmly welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, testing workflows, and the pull request process. Community interactions are governed by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
