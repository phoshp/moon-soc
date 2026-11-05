#!/usr/bin/env python3
"""
Official RISC-V Architectural & Compliance Test Runner for Moon-SoC RV64 core.
Tests against official RISC-V testbenches (RV64I, RV64M, RV64A, RV64C, RV64F, RV64D, Privileged M/S).
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
COMPLIANCE_DIR = REPO_ROOT / "tb" / "compliance"
ISA_DIR = COMPLIANCE_DIR / "tests" / "isa"
ENV_DIR = COMPLIANCE_DIR / "tests" / "env"
MACROS_DIR = COMPLIANCE_DIR / "tests" / "macros"
LD_SCRIPT = COMPLIANCE_DIR / "link.ld"
BUILD_DIR = REPO_ROOT / "sim_build_compliance"

SUITES = {
    "rv64ui": {"desc": "RV64I Base Integer Instruction Set", "march": "-march=rv64g"},
    "rv64um": {"desc": "RV64M Hardware Multiplier & Radix-2 Divider", "march": "-march=rv64g"},
    "rv64ua": {"desc": "RV64A Atomic Operations & LR/SC Reservations", "march": "-march=rv64g"},
    "rv64uc": {"desc": "RV64C Compressed 16-bit Instructions", "march": "-march=rv64gc"},
    "rv64uf": {"desc": "RV64F Scalar Single-Precision Floating-Point", "march": "-march=rv64g"},
    "rv64ud": {"desc": "RV64D Scalar Double-Precision Floating-Point", "march": "-march=rv64g"},
    "rv64mi": {"desc": "Privileged Machine-Mode CSR & Trap Architecture", "march": "-march=rv64g"},
    "rv64si": {"desc": "Privileged Supervisor-Mode Architecture & CSRs", "march": "-march=rv64g"},
}

# Tests requiring hardware misaligned data access extension (Zicclsm)
# Base RV64GC cores raise CAUSE_MISALIGNED_LOAD/STORE (verified via rv64mi-ma_addr suite)
SKIP_TESTS = {
    "rv64ui": ["ma_data"],
    "rv64si": ["dirty", "icache-alias"], # Memory-model specific Sv39 tests (verified via test_mmu_sv39)
}

def main():
    parser = argparse.ArgumentParser(description="Moon-SoC RISC-V Compliance Test Runner")
    parser.add_argument("--suite", choices=list(SUITES.keys()), help="Run specific test suite only")
    parser.add_argument("--test", help="Run a specific test name only (e.g. add, mul, fadd)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose simulation logging")
    parser.add_argument("--max-cycles", default="20000", help="Max simulation cycles per test")
    args = parser.parse_args()

    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    suites_to_run = [args.suite] if args.suite else list(SUITES.keys())

    print("=" * 78)
    print(" Moon-SoC RV64GC Official RISC-V Compliance Test Suite")
    print("=" * 78)

    overall_passed = 0
    overall_total = 0
    suite_summaries = []

    for suite_name in suites_to_run:
        suite_info = SUITES[suite_name]
        suite_path = ISA_DIR / suite_name
        test_files = sorted(suite_path.glob("*.S"))

        if args.test:
            test_files = [f for f in test_files if f.stem == args.test]

        # Filter out tests requiring non-standard/unimplemented extensions
        skip_list = SKIP_TESTS.get(suite_name, [])
        test_files = [f for f in test_files if f.stem not in skip_list]

        if not test_files:
            continue

        print(f"\n[+] Suite: {suite_name} - {suite_info['desc']}")
        print("-" * 78)

        passed_count = 0
        failed_tests = []

        for test_s in test_files:
            test_stem = test_s.stem
            elf_file = BUILD_DIR / f"{suite_name}_{test_stem}.elf"
            bin_file = BUILD_DIR / f"{suite_name}_{test_stem}.bin"
            hex_file = BUILD_DIR / f"{suite_name}_{test_stem}.hex"

            # 1. Compile
            compile_cmd = [
                "riscv64-linux-gnu-gcc",
                suite_info["march"],
                "-mabi=lp64d",
                "-static",
                "-mcmodel=medany",
                "-fvisibility=hidden",
                "-nostdlib",
                "-nostartfiles",
                f"-I{ENV_DIR / 'p'}",
                f"-I{MACROS_DIR / 'scalar'}",
                f"-T{LD_SCRIPT}",
                str(test_s),
                "-o", str(elf_file),
            ]
            res = subprocess.run(compile_cmd, capture_output=True, text=True)
            if res.returncode != 0:
                print(f"  {test_stem:<20} [COMPILE ERROR]: {res.stderr.strip()[:60]}")
                failed_tests.append((test_stem, "compile_error"))
                continue

            # 2. Objcopy to flat binary
            subprocess.run(
                ["riscv64-linux-gnu-objcopy", "-O", "binary", str(elf_file), str(bin_file)],
                check=True,
            )

            # 3. Bin to Hex conversion
            subprocess.run(
                [sys.executable, str(REPO_ROOT / "tb" / "bin2hex.py"), str(bin_file), str(hex_file)],
                check=True,
            )

            # 4. Run testbench with cocotb
            run_cmd = [
                sys.executable,
                str(REPO_ROOT / "tb" / "core" / "run_test.py"),
                str(hex_file),
            ]
            if args.verbose:
                run_cmd.append("-v")

            env = os.environ.copy()
            env["MAX_CYCLES"] = str(args.max_cycles)

            res = subprocess.run(run_cmd, capture_output=True, text=True, env=env)
            if res.returncode == 0:
                print(f"  {test_stem:<20} [PASS]")
                passed_count += 1
            else:
                err_msg = "Unknown error"
                for line in res.stdout.splitlines() + res.stderr.splitlines():
                    if "[FAIL]" in line or "TimeoutError" in line:
                        err_msg = line.strip()
                        break
                print(f"  {test_stem:<20} [FAIL]: {err_msg}")
                failed_tests.append((test_stem, err_msg))

        overall_passed += passed_count
        overall_total += len(test_files)
        suite_summaries.append((suite_name, passed_count, len(test_files), failed_tests))

    # Print Summary Report
    print("\n" + "=" * 78)
    print(" COMPLIANCE VERIFICATION SUMMARY REPORT")
    print("=" * 78)
    print(f"{'Suite':<12} | {'Category':<45} | {'Result':<15}")
    print("-" * 78)
    for name, passed, total, failed in suite_summaries:
        status_str = f"{passed}/{total} PASSED"
        pct = (passed / total * 100) if total > 0 else 0
        res_display = f"{status_str} ({pct:.0f}%)"
        print(f"{name:<12} | {SUITES[name]['desc']:<45} | {res_display}")
        if failed:
            for f_name, f_err in failed:
                print(f"    - Failed: {f_name} ({f_err})")

    print("=" * 78)
    print(f" TOTAL: {overall_passed}/{overall_total} tests passed ({overall_passed/overall_total*100:.1f}%)")
    print("=" * 78)

    if overall_passed == overall_total:
        print("\n>>> ALL OFFICIAL RISC-V COMPLIANCE TESTS PASSED SUCCESSFULLY! <<<\n")
        return 0
    else:
        print(f"\n>>> WARNING: {overall_total - overall_passed} COMPLIANCE TEST(S) FAILED! <<<\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
