# Moon-SoC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ISA: RISC-V RV64IMA](https://img.shields.io/badge/ISA-RISC--V_RV64IMA-orange.svg)](https://riscv.org/)
[![Simulator: Verilator](https://img.shields.io/badge/Simulator-Verilator_5+-lightgrey.svg)](https://www.veripool.org/verilator/)
[![Verification: Cocotb](https://img.shields.io/badge/Verification-Cocotb_2.x-brightgreen.svg)](https://www.cocotb.org/)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg)](https://www.python.org/)
[![Build: Passing](https://img.shields.io/badge/Build-Passing-success.svg)](#running-simulation)

Moon-SoC is a modular, high-performance 64-bit RISC-V (RV64IMA) processor core written in SystemVerilog. Designed with simplicity, extensibility, and testability in mind, Moon-SoC features a classic 5-stage in-order pipeline, complete integer arithmetic with hardware multiply/divide, atomic memory operations, and privileged Machine-mode CSR and trap handling.

Verification is implemented in Python using [cocotb](https://www.cocotb.org/) and [Verilator](https://www.veripool.org/verilator/), providing fast simulation alongside flexible test orchestration.

---

## Key Features

- **RISC-V RV64I Base Integer ISA**:
  - Full 64-bit integer compute, branching, and immediate generation.
  - Complete support for RV64 32-bit word operations (`addiw`, `subw`, `sllw`, `srlw`, `sraw`, `addw`, `subw`, etc.).
  - 32 x 64-bit general-purpose integer register file (`x0` hardwired to zero).
- **RV64M Hardware Multiplier & Divider**:
  - Single-cycle 64-bit multiplier (`mul`, `mulh`, `mulhu`, `mulhsu`, `mulw`).
  - Multi-cycle radix-2 hardware non-restoring divider/remainder engine (`div`, `divu`, `rem`, `remu`, `divw`, `divuw`, `remw`, `remuw`).
- **RV64A Atomic Extension**:
  - Load-Reserved / Store-Conditional (`lr.d`, `sc.d`) with reservation register and external coherence bus invalidation interface (`inv_valid_i`, `inv_addr_i`).
  - Atomic Memory Operations (AMO): `amoadd`, `amoswap`, `amoxor`, `amoand`, `amoor`, `amomin`, `amomax`, `amominu`, `amomaxu`.
- **Privileged Machine-Mode Trap & CSR Architecture**:
  - Standard Machine-mode CSRs: `mstatus`, `misa`, `mie`, `mtvec`, `mepc`, `mcause`, `mtval`, `mip`, `mhartid`, `mcycle`, `minstret`, and `fcsr`.
  - Vectored and direct trap entry, exception decoding, interrupt handling (timer, software, external), and return via `mret`.
- **5-Stage Pipeline & Hazard Management**:
  - In-order pipeline stages: **IF** (Fetch), **ID** (Decode), **EX** (Execute), **MEM** (Memory), **WB** (Writeback).
  - Forwarding paths from EX/MEM and MEM/WB to execution operands.
  - Automatic load-use stalls, multi-cycle divider stalls, CSR serialization, and branch misprediction / trap flushes.
- **Python / Cocotb Test Framework**:
  - Fast, scriptable, asynchronous tests powered by `cocotb` and `pytest`.
  - Cycle-by-cycle instruction tracing, memory inspection, and timeout safety.

---

## Core Pipeline Architecture

```text
       +----------+    +----------+    +----------+    +----------+    +----------+
       |    IF    |    |    ID    |    |    EX    |    |   MEM    |    |    WB    |
       |  Fetch   |--->|  Decode  |--->| Execute  |--->|  Memory  |--->|Writeback |
       +----------+    +----------+    +----------+    +----------+    +----------+
            |               |               |               |               |
         PC Gen         Regfile Read    64-bit ALU      Load / Store     Regfile
        imem bus         Imm Gen        HW Multiplier   AMO Unit         Commit
                         Hazard Unit    HW Divider      LR/SC Check
                                        Branch Target   dmem bus
            ^               ^               |               |               |
            |               |               v               v               |
            +---------------+-------- Forwarding & Hazard Control ----------+
```

---

## Repository Structure

```text
moon-soc/
├── rtl/
│   └── core/                   # Synthesizable SystemVerilog core modules
│       ├── moon_pkg.sv         # Global types, opcodes, CSR definitions, constants
│       ├── moon_core.sv        # Top-level core module and inter-stage interconnect
│       ├── moon_if_stage.sv    # Instruction Fetch stage and PC generation
│       ├── moon_id_stage.sv    # Instruction Decode and immediate extraction
│       ├── moon_regfile.sv     # 32 x 64-bit integer register file
│       ├── moon_ex_stage.sv    # Execution stage multiplexers and branch logic
│       ├── moon_alu.sv         # 64-bit and 32-bit ALU
│       ├── moon_mul.sv         # Hardware integer multiplier
│       ├── moon_div.sv         # Multi-cycle radix-2 divider / remainder
│       ├── moon_mem_stage.sv   # Memory stage, sign/zero extension, aligner
│       ├── moon_amo.sv         # Atomic Memory Operation ALU
│       ├── moon_wb_stage.sv    # Writeback selection and register file commit
│       ├── moon_hazard_unit.sv # Hazard detection, forwarding, stalls, flushes
│       └── moon_csr.sv         # Machine-mode CSRs, interrupts, and trap engine
├── sw/
│   ├── common/
│   │   └── link_test.ld        # RISC-V linker script (ROM 0x1000, RAM 0x8000_0000)
│   └── tests/
│       └── asm/
│           ├── test_rv64_all.s   # Self-checking directed test assembly suite
│           └── test_rv64_all.hex # Assembled 32-bit little-endian simulation hex
├── scripts/
│   └── bin2hex.py              # Flat binary to 32-bit hex word converter
├── tb/
│   ├── sv/
│   │   └── tb_moon_core.sv     # SystemVerilog testbench memory harness
│   └── cocotb/
│       ├── Makefile            # Standalone cocotb Makefile
│       ├── run_test.py         # Python test runner and pytest entrypoint
│       └── test_moon_core.py   # Cocotb asynchronous test routines
├── Makefile                    # Root project Makefile
└── CLAUDE.md                   # Developer guidance and architectural notes
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
  pip install cocotb pytest
  ```

### Running Simulation

All simulation commands can be run from the root directory:

1. **Run Default Test Suite**:
   ```bash
   make test
   ```
   Runs `test_rv64_all.hex` through cocotb and Verilator, verifying RV64I, RV64M, RV64A, and CSR operations.

2. **Run with Verbose Cycle Trace**:
   ```bash
   make verbose-test
   ```
   Prints cycle-by-cycle program counter (`PC`) and instruction traces.

3. **Run via Pytest**:
   ```bash
   make pytest
   # or directly:
   pytest tb/cocotb/run_test.py
   ```

4. **Run a Custom Firmware Image**:
   ```bash
   python3 tb/cocotb/run_test.py path/to/firmware.hex
   ```

5. **Generate Waveforms**:
   ```bash
   python3 tb/cocotb/run_test.py --waves
   ```

6. **Clean Build Directory**:
   ```bash
   make clean
   ```

---

## Firmware Protocol

In simulation, `tb/sv/tb_moon_core.sv` monitors writes to physical memory address `0x8000_1000`:
- **`0xCAFE_BABE`**: Test passed successfully.
- **`0xDEAD_00xx`**: Test failed with specific error code `xx`.

---

## Contributing

Contributions are warmly welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, testing workflows, and the pull request process. Community interactions are governed by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
