# Contributing to Moon-SoC

Thank you for your interest in contributing to Moon-SoC! We welcome contributions from the community, whether you are fixing bugs, implementing new RISC-V extensions, improving verification coverage, or polishing documentation.

Please read this document to understand our contribution guidelines and workflow.

---

## Code of Conduct

All contributors and participants are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please be welcoming, respectful, and considerate of others.

---

## Getting Started

### Prerequisites

Ensure you have the required toolchain installed:

- **SystemVerilog Simulator**: [Verilator](https://www.veripool.org/verilator/) (v5.0 or newer).
- **Python**: Python 3.10+ with `pip`.
- **Verification Libraries**:
  ```bash
  python3 -m pip install -r requirements.txt
  ```

### Fork & Clone

1. Fork the repository on GitHub.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/moon-soc.git
   cd moon-soc
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```

---

## Development & Testing Workflow

Before submitting a pull request, ensure all tests pass locally.

### Running Simulations

- **Execute default test suite**:
  ```bash
  make test
  ```
- **Run regression via pytest**:
  ```bash
  make pytest
  ```
- **Run with verbose cycle-by-cycle trace**:
  ```bash
  make verbose-test
  ```
- **Run a specific test firmware image**:
  ```bash
  python3 tb/core/run_test.py path/to/test.hex
  ```

---

## Coding Guidelines

### SystemVerilog RTL (`rtl/core/`)

- **Synthesizability**: Keep all core logic synthesizable and portable.
- **File & Module Naming**:
  - File names must match the module name (e.g. `moon_alu.sv` defines `module moon_alu`).
  - Use `snake_case` for module, signal, and wire names.
- **Port Naming Conventions**:
  - Inputs end with `_i` (e.g., `clk_i`, `dmem_rdata_i`).
  - Active-low inputs end with `_ni` (e.g., `rst_ni`).
  - Outputs end with `_o` (e.g., `imem_req_o`, `wb_wdata_o`).
- **Sequential and Combinational Blocks**:
  - Use `always_ff @(posedge clk_i or negedge rst_ni)` for sequential state with non-blocking assignments (`<=`).
  - Use `always_comb` for pure combinational logic with blocking assignments (`=`).
- **Data Types**: Use SystemVerilog types (`logic`, `bit`, `enum`, `typedef struct`). Avoid legacy `wire`/`reg`.

### Verification & Tests (`tb/`)

- Write tests asynchronously using `cocotb` coroutines (`@cocotb.test()`, `async def`, `await`).
- Use clear assertions with informative failure messages when conditions fail.
- Follow [PEP 8](https://peps.python.org/pep-0008/) style for Python code.

---

## Submitting Pull Requests

1. **Keep Pull Requests Focused**: Each PR should address a single bug fix or feature.
2. **Include Verification**: Add or update test cases verifying your changes.
3. **Commit Messages**:
   - Write clear, imperative commit messages (e.g., `Add support for CSR mtvec mode bits`).
   - Describe the problem and the rationale for the solution in the commit body.
4. **Open a PR**: Open a pull request against the `main` branch. Fill out the provided pull request template completely.

---

## Reporting Issues

- **Bug Reports**: Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md). Include steps to reproduce, simulator version, and terminal/trace output.
- **Feature Requests**: Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md) describing the motivation, desired behavior, and architectural impact.
