#!/usr/bin/env python3
"""Moon-SoC RV64 Cocotb Test Runner."""

import os
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
try:
    from cocotb_tools.runner import get_runner
except ImportError:
    from cocotb.runner import get_runner

def run_test(test_hex=None, waves=False, verbose=False):
    repo_root = Path(__file__).resolve().parent.parent.parent
    rtl_dir = repo_root / "rtl" / "core"
    tb_dir = repo_root / "tb" / "core"
    sources = [tb_dir / "tb_moon_core.sv"]

    if test_hex is None:
        test_hex = os.environ.get(
            "TEST_HEX", str(repo_root / "tb" / "tests" / "asm" / "base" / "test_rv64_all.hex")
        )
    test_hex = str(Path(test_hex).resolve())

    runner = get_runner("verilator")
    build_dir = repo_root / "sim_build"

    runner.build(
        sources=sources,
        hdl_toplevel="tb_moon_core",
        build_args=[
            "-Wno-fatal",
            "-Wno-WIDTHEXPAND",
            "-Wno-WIDTHTRUNC",
            "-Wno-UNUSED",
            "-Wno-BLKLOOPINIT",
            "--unroll-stmts",
            "1000000",
            f"-I{rtl_dir}",
            f"-I{rtl_dir / 'mmu'}",
            f"-I{tb_dir}",
        ],
        waves=waves,
        build_dir=build_dir,
    )

    cocotb_dir = str(Path(__file__).resolve().parent)
    if cocotb_dir not in sys.path:
        sys.path.insert(0, cocotb_dir)

    results_file = runner.test(
        hdl_toplevel="tb_moon_core",
        hdl_toplevel_lang="verilog",
        test_module="test_moon_core",
        build_dir=build_dir,
        test_dir=build_dir,
        plusargs=[f"+hex_file={test_hex}"],
        extra_env={
            "VERBOSE": "1" if verbose else "0",
            "MAX_CYCLES": os.environ.get("MAX_CYCLES", "10000"),
        },
        waves=waves,
    )
    _assert_results_passed(_resolve_results_file(build_dir, results_file))


def _assert_results_passed(results_xml):
    if not results_xml.exists():
        raise RuntimeError(f"Missing cocotb results file: {results_xml}")
    root = ET.parse(results_xml).getroot()
    failed = 0
    for suite in root.findall(".//testsuite"):
        failed += int(suite.attrib.get("failures", "0"))
        failed += int(suite.attrib.get("errors", "0"))
    if failed:
        raise RuntimeError(f"Cocotb reported {failed} test failure(s); see {results_xml}")


def _resolve_results_file(build_dir, reported_path):
    if reported_path:
        candidate = Path(reported_path)
        if candidate.exists():
            return candidate
    for candidate in (build_dir / "results.xml", *sorted(build_dir.glob("test_*.None"))):
        if candidate.exists():
            return candidate
    return build_dir / "results.xml"

def test_moon_core():
    """Pytest entrypoint for Moon-SoC RV64 cocotb regression."""
    run_test()

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run Moon-SoC cocotb simulation")
    parser.add_argument("hex", nargs="?", default=None, help="Path to firmware hex file")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable cycle trace logging")
    parser.add_argument("--waves", action="store_true", help="Enable waveform dumping")
    args = parser.parse_args()

    run_test(test_hex=args.hex, waves=args.waves, verbose=args.verbose)
