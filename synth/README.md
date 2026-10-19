# Hierarchical SoC Partitioning & Macro Synthesis Guide

This document describes the hierarchical partitioning and macro-based ASIC synthesis methodology for **Moon-SoC** using **Yosys**, **OpenROAD**, and **LibreLane** targeting the **SkyWater Sky130** process node.

---

## 1. Motivation: Why Monolithic SoC Synthesis Fails in Colab

In monolithic synthesis, Yosys attempts to elaborate, optimize, and tech-map the entire System-on-Chip at once:
- RV64 64-bit integer pipeline with forwarding matrix, multi-cycle divider, and 64-bit multiplier
- MMU (Sv39 page-table walker, 8-entry ITLB, 8-entry DTLB, PMP checker)
- Scalar F/D FPU and RVV Vector execution slice
- 4-way set-associative L1 Instruction and Data caches with write-back buffers
- Multi-master multi-slave 64-bit AXI4 crossbar and 7-peripheral APB crossbar
- Peripherals (CLINT, PLIC, UART 16550, SPI, I2C), CRG, and PMU

Attempting to run `OPT_EXPR`, logic restructuring, and ABC technology mapping across >150,000 standard cells causes Yosys and ABC to consume gigabytes of RAM and run for hours without converging, frequently triggering Google Colab memory crashes or timeouts.

### The Solution: Modular Hierarchical Tile Architecture
Moon-SoC is partitioned into **distinct, self-contained macro blocks** (Compute, Cache, Memory, Interconnect, Peripherals, System Control, and PHYs). Each macro is hardened independently and then assembled into the top-level chip floorplan using **Blackbox Stubs** and **LEF/LIB abstractions**.

---

## 2. Chip Architecture & Partitioning

The SoC floorplan is partitioned into 8 standardized macro blocks:

```
+-----------------------------------------------------------------------------------+
|                                  MOON-SOC DIE                                     |
|                                                                                   |
|  +--------------------+   +--------------------+   +---------------------------+  |
|  |                    |   |                    |   |                           |  |
|  |   COMPUTE TILE     |   |    CACHE TILE      |   |     MEMORY SUBSYSTEM      |  |
|  |  (moon_cpu_tile)   |===| (moon_cache_tile)  |   |    (moon_mem_subsystem)   |  |
|  |                    |   |                    |   |                           |  |
|  |  * RV64 Core       |   |  * 4KB 4-way L1-I  |   |   * 4KB Boot ROM          |  |
|  |  * CSR, MMU, PMP   |   |  * 4KB 4-way L1-D  |   |   * 4KB/128KB SRAM Ctrl   |  |
|  |  * FPU / RVV unit  |   |  * AXI Masters     |   |     (OpenRAM Macro target)|  |
|  +--------------------+   +--------------------+   +---------------------------+  |
|            ||                       ||                           ||               |
|  ===============================================================================  |
|                    SYSTEM FABRIC / UNCORE (moon_sys_fabric)                       |
|         * 64-bit AXI4 Multi-Master Crossbar    * AXI-to-APB Bridge                |
|         * 7-Peripheral APB Crossbar Matrix                                        |
|  ===============================================================================  |
|            ||                       ||                 ||            ||           |
|  +--------------------+   +--------------------+   +---------+  +--------------+  |
|  |   SYSTEM CONTROL   |   |     PERIPHERAL     |   | I/O PHY |  |  MEMORY PHY  |  |
|  | (sysctrl_subsystem)|   |     SUBSYSTEM      |   |(io_phy) |  |  (mem_phy)   |  |
|  |                    |   |(periph_subsystem)  |   |         |  |              |  |
|  | * Reset Sequencer  |   | * CLINT (Timer)    |===| * UART  |  | * AXI Timing |  |
|  | * CRG & Clock Gates|   | * PLIC (Interrupts)|   | * SPI   |  |   Registers  |  |
|  | * PMU (WFI States) |   | * UART 16550, SPI  |   | * I2C   |  | * DRAM Pad   |  |
|  | * PLL behavioral   |   | * I2C Master       |   | * IRQs  |  |   Boundary   |  |
|  +--------------------+   +--------------------+   +---------+  +--------------+  |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### Macro Directory Map:
1. **Compute Tile** (`rtl/soc/cpu/moon_cpu_tile.sv`):
   - Contains Moon RV64 Core with 5-stage pipeline, ALU, Mul/Div, MMU, CSR, and co-processor interfaces.
   - Macro Config: `synth/macros/cpu_tile/config.json`.
2. **Cache Tile** (`rtl/soc/cache/moon_cache_tile.sv`):
   - Contains 4-way set-associative L1-I and write-back L1-D cache arrays and AXI4 burst managers.
   - Macro Config: `synth/macros/cache_tile/config.json`.
3. **Memory Subsystem** (`rtl/soc/memory/moon_mem_subsystem.sv`):
   - Contains Boot ROM and On-Chip SRAM controller targeting Sky130 OpenRAM macros.
   - Macro Config: `synth/macros/mem_subsystem/config.json`.
4. **System Fabric** (`rtl/soc/interconnect/moon_sys_fabric.sv`):
   - Contains 64-bit multi-master AXI4 crossbar, AXI-to-APB bridge, and APB crossbar.
   - Macro Config: `synth/macros/sys_fabric/config.json`.
5. **Peripheral Subsystem** (`rtl/soc/periph/moon_periph_subsystem.sv`):
   - Contains CLINT, PLIC, 16550 UART, SPI Master, and I2C Master controllers.
   - Macro Config: `synth/macros/periph_subsystem/config.json`.
6. **System Control Subsystem** (`rtl/soc/sysctrl/moon_sysctrl_subsystem.sv`):
   - Contains Multi-Domain Reset Sequencer, Clock & Reset Generator (CRG), and PMU.
   - Macro Config: `synth/macros/sysctrl_subsystem/config.json`.
7. **Memory PHY** (`rtl/soc/phy/moon_mem_phy.sv`):
   - Provides timing isolation registers and pad interface for off-chip DRAM / HyperRAM.
   - Macro Config: `synth/macros/mem_phy/config.json`.
8. **I/O PHY** (`rtl/soc/phy/moon_io_phy.sv`):
   - Provides input synchronizers, glitch filters, and tri-state pad logic for board I/O.
   - Macro Config: `synth/macros/io_phy/config.json`.

---

## 3. Top-Level Assembly via Blackbox Macros

When synthesizing the top-level `moon_soc_top`, Yosys reads the blackbox stub file:
`synth/macros/blackbox/moon_soc_macros_bb.sv`.

Because all 8 macros are declared with the `(* blackbox *)` attribute, Yosys only synthesizes the top-level interconnect wires (~100 net connections) instead of hundreds of thousands of standard cells.

- **Top-Level Synthesis Time**: **Under 10 seconds** in Yosys.
- **Top-Level PnR**: OpenROAD uses `synth/top/macro_placement.cfg` to position the hardened macro LEFs on the die and routes global interconnect buses between macro pins.

---

## 4. Running the Flow in Google Colab (Step-by-Step)

An automated Jupyter notebook is provided at `synth/librelane_hierarchical_soc.ipynb`.

### Step A: Harden Each Macro
In Colab, run each macro flow using LibreLane. Each block typically completes in 1 to 5 minutes:

```python
from librelane.flows import Flow

# Harden Peripheral Subsystem
flow_periph = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/periph_subsystem"
)
flow_periph.start()

# Harden System Control (AON/CRG/PMU)
flow_sysctrl = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/sysctrl_subsystem"
)
flow_sysctrl.start()

# Harden System Fabric (Crossbar & APB Bridge)
flow_fabric = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/sys_fabric"
)
flow_fabric.start()

# Harden Memory Subsystem
flow_mem = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/mem_subsystem"
)
flow_mem.start()

# Harden Cache Tile
flow_cache = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/cache_tile"
)
flow_cache.start()

# Harden CPU Compute Tile
flow_cpu = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/macros/cpu_tile"
)
flow_cpu.start()
```

Each completed run exports:
- `<macro>.lef`: Physical pin placements and routing obstructions.
- `<macro>.lib`: Standard timing models.
- `<macro>.gds`: Hardened layout.

### Step B: Assemble Top-Level SoC
Once the macros are generated, run the top-level flow:

```python
flow_top = Flow.factory.get("Classic")(
    config_dir="/content/moon-soc/synth/top"
)
flow_top.start()
```

The top-level run takes the placed macros, inserts the power distribution network (PDN), routes top-level buses, and produces the complete `moon_soc_top.gds` chip layout!
