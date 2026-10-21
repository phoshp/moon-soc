# Moon-SoC

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ISA: RISC-V RV64GC](https://img.shields.io/badge/ISA-RISC--V_RV64GC-orange.svg)](https://riscv.org/)
[![Simulator: Verilator](https://img.shields.io/badge/Simulator-Verilator_5+-lightgrey.svg)](https://www.veripool.org/verilator/)
[![Verification: Cocotb](https://img.shields.io/badge/Verification-Cocotb-brightgreen.svg)](https://www.cocotb.org/)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-yellow.svg)](https://www.python.org/)

Moon-SoC is an open-source, synthesizable 64-bit RISC-V System-on-Chip (SoC) implemented in SystemVerilog. It features a 5-stage in-order pipeline, standard **RV64GC** (RV64IMAFD_Zicsr_Zifencei_C) compliance, Sv39 virtual memory, 4-way set-associative L1 caches, and a full peripheral subsystem designed for ASIC implementation on the SkyWater 130nm (Sky130) node using LibreLane and OpenROAD.

Verification is implemented in Python using [cocotb](https://www.cocotb.org/) and [Verilator](https://www.veripool.org/verilator/).

---

## Features

### Processor Core
- **Pipeline**: 64-bit 5-stage in-order execution (IF, ID, EX, MEM, WB).
- **RV64GC ISA**:
  - **RV64I**: Base integer instruction set and 32-bit word operations.
  - **RV64M**: Hardware integer multiplication (4-cycle compact iterative multiplier) and division (radix-2 digit-recurrence divider).
  - **RV64A**: Atomic memory operations (AMO) and LR/SC reservation tracking.
  - **RV64F / RV64D**: IEEE-754 single and double-precision floating-point operations.
  - **RV64C**: 16-bit compressed instruction decoder.
- **Privilege Architecture**: Machine (M), Supervisor (S), and User (U) modes with standard CSRs, exception delegation, and trap handling.
- **Memory Management**: Sv39 MMU with a 3-level hardware page table walker, ITLB, DTLB, and Physical Memory Protection (PMP).

### Cache & Memory Subsystem
- **L1 Caches**: 4-way set-associative L1-I and L1-D caches with 64-byte line size.
  - L1-D features write-back, write-allocate, AXI4 burst refills/evictions, and uncached I/O bypass.
- **On-Chip Memory**: Integrated Boot ROM and SRAM controller supporting SkyWater Sky130 OpenRAM dual-port SRAM macros.

### Interconnect & Peripherals
- **System Interconnect**: 64-bit multi-master AXI4 crossbar fabric and AXI4-to-APB4 bridge.
- **Peripherals**:
  - 16550-compatible UART console controller
  - Core-Local Interruptor (CLINT) for software and timer interrupts
  - Platform-Level Interrupt Controller (PLIC) for external device interrupts
  - SPI and I2C master controllers
  - Clock & Reset Generator (CRG) and Power Management Unit (PMU) with WFI clock-gating support

---

## Architecture Overview

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

## Repository Structure

```text
moon-soc/
├── rtl/
│   ├── core/           # CPU pipeline, ALU, FPU, MMU, CSRs, regfiles
│   └── soc/            # SoC top-level, caches, AXI4/APB fabric, peripherals
├── tb/
│   ├── core/           # Standalone core Cocotb testbench and runner
│   ├── soc/            # Full SoC Cocotb testbench and harness
│   └── tests/          # Assembly and C test suites (hex/bin)
└── synth/              # OpenROAD / LibreLane macro configs and notebooks
```

---

## Getting Started

### Prerequisites

- **Verilator** (v5.0 or newer):
  ```bash
  # Fedora / RHEL
  sudo dnf install verilator

  # Ubuntu / Debian
  sudo apt-get install verilator
  ```

- **Python 3.10+** and verification dependencies:
  ```bash
  pip install -r requirements.txt
  ```

- **RISC-V 64-bit GCC Toolchain** (for compiling custom firmware):
  ```bash
  # Fedora / RHEL
  sudo dnf install gcc-riscv64-linux-gnu

  # Ubuntu / Debian
  sudo apt-get install gcc-riscv64-linux-gnu
  ```

### Running Simulation

All simulation targets run directly from the repository root:

```bash
# Run core-level verification suite
make test

# Run full SoC verification suite
make soc-test

# Run full regression suite (core + SoC)
make all
```

#### Specialized Test Targets

| Target | Description |
| :--- | :--- |
| `make all` | Runs whole test suite |
| `make test` | Runs core tests |
| `make soc-compressed-test` | RV64C 16-bit compressed instruction verification |
| `make soc-smode-test` | Supervisor mode privilege transitions and trap delegation |
| `make soc-pmp-test` | Physical Memory Protection (PMP) access enforcement |
| `make soc-mmu-test` | Sv39 3-level page table walking and address translation |
| `make soc-fp-test` | Scalar F/D floating-point operations and moves |
| `make soc-cache-test` | L1 cache hits, misses, writeback, and evictions |
| `make soc-periph-test` | SoC peripherals (UART, SRAM, CLINT, PLIC, CRG, PMU) |
| `make soc-wfi-test` | WFI instruction and PMU clock-gating wake-up sequencing |
| `make verbose-test` | Core simulation with cycle-by-cycle instruction tracing |
| `make clean` | Remove simulation build artifacts |

#### Custom Firmware Execution

To run a custom assembled firmware hex image:

```bash
python3 tb/soc/run_soc_test.py path/to/firmware.hex [--verbose] [--waves]
```

To convert a raw binary to simulation hex format:

```bash
python3 tb/bin2hex.py firmware.bin firmware.hex
```

---

## ASIC Synthesis & Macro Hardening

Moon-SoC is organized into modular macro partitions for hierarchical ASIC hardening using [LibreLane](https://github.com/efabless/librelane) and [OpenROAD](https://theopenroadproject.org/) targeting the **SkyWater Sky130** process node:

- **Compute Tile** (`rtl/soc/cpu/`): Processor core, register files, MMU, and PMP.
- **Cache Tile** (`rtl/soc/cache/`): 4-way set-associative L1-I and L1-D cache controllers.
- **Memory Subsystem** (`rtl/soc/memory/`): Boot ROM and dual-port Sky130 OpenRAM macros.
- **System Fabric** (`rtl/soc/interconnect/`): 64-bit AXI4 crossbar and APB bridge.
- **Peripheral Subsystem** (`rtl/soc/periph/`): 16550 UART, CLINT, PLIC, SPI, and I2C.
- **System Control** (`rtl/soc/sysctrl/`): Clock & Reset Generator and Power Management Unit.

Hardening configurations and macro placement specifications are located under `synth/`.

---

## Contributing

Contributions and issue reports are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code standards and the pull request workflow, and review our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

This project is licensed under the [MIT License](LICENSE).
