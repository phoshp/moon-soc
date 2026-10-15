# Moon-SoC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ISA: RISC-V RV64IMAFD+](https://img.shields.io/badge/ISA-RISC--V_RV64IMAFD%2B-orange.svg)](https://riscv.org/)
[![Simulator: Verilator](https://img.shields.io/badge/Simulator-Verilator_5+-lightgrey.svg)](https://www.veripool.org/verilator/)
[![Verification: Cocotb](https://img.shields.io/badge/Verification-Cocotb_2.x-brightgreen.svg)](https://www.cocotb.org/)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg)](https://www.python.org/)
[![Build: Passing](https://img.shields.io/badge/Build-Passing-success.svg)](#running-simulation)

Moon-SoC is a modular 64-bit RISC-V processor and SoC written in SystemVerilog. It features a classic 5-stage in-order pipeline, integer arithmetic with hardware multiply/divide, atomic memory operations, privileged architecture support, caches, and an evolving set of RVA23 computational extensions.

Verification is implemented in Python using [cocotb](https://www.cocotb.org/) and [Verilator](https://www.veripool.org/verilator/), providing fast simulation alongside flexible test orchestration.

Still work in progress.

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
- **RVA23 Computational Extensions (in progress)**:
  - Scalar F/D operations include arithmetic, division, square root, comparisons, conversions, and fused multiply-add.
  - Scalar AES64 and SHA-256/SHA-512 integer operations are available.
  - The RVV unit currently provides a VLEN=128, LMUL=1 slice with e8/e16/e32/e64 configuration, integer arithmetic and reductions, mask operations, and unit-stride, strided, and indexed memory operations.
  - Selected vector floating-point operations are implemented, including arithmetic, fused operations, comparisons, classification, min/max, sign injection, and conversions. Widening conversions support e32 source elements and e64 destinations, including signed/unsigned integer conversions and float-to-float conversion.
  - RVV 1.0 is not complete. Vector operation families, CSR and restart behavior, and tail/mask policy coverage remain partial; the implemented subset is not full RVV compliance.
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
       |  Fetch   |--->|  Decode  |--->| ALU/FPU/ |--->|  Memory  |--->|Writeback |
       |          |    |          |    |   RVV    |    |          |    |          |
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
   pytest tb/core/run_test.py
   ```

4. **Run a Custom Firmware Image**:
   ```bash
   python3 tb/core/run_test.py path/to/firmware.hex
   ```

5. **Generate Waveforms**:
   ```bash
   python3 tb/core/run_test.py --waves
   ```

6. **Clean Build Directory**:
   ```bash
   make clean
   ```

Testbench files are grouped by target: `tb/core/` contains the standalone core cocotb runner and SystemVerilog harness, while `tb/soc/` contains the SoC equivalents. `tb/bin2hex.py` converts firmware binaries to simulation hex images.

Firmware regressions are grouped under `tb/tests/asm/` by area (`base/`, `privileged/`, `crypto/`, `fp/`, `rvv/`, and `soc/`). Each tracked test keeps its assembly source and simulation images together.

---

## Contributing

Contributions are warmly welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, testing workflows, and the pull request process. Community interactions are governed by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
