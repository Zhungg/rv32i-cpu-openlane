#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

for tool in verilator iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found: $tool"
        exit 1
    fi
done

PACKAGE_FILES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_encoding_pkg.sv
    rtl/pkg/rv32i_csr_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
)

TESTBENCH="tb/unit/tb_pkg_smoke.sv"
VVP_OUTPUT="sim/icarus/work/tb_pkg_smoke.vvp"

mkdir -p sim/icarus/work
mkdir -p reports/lint
mkdir -p reports/rtl_sim

echo "[1/3] Verilator package lint"

verilator \
    --lint-only \
    --Wall \
    -Wno-fatal \
    --top-module tb_pkg_smoke \
    "${PACKAGE_FILES[@]}" \
    "$TESTBENCH" \
    2>&1 | tee reports/lint/packages_verilator.log

echo
echo "[2/3] Icarus package compilation"

iverilog \
    -g2012 \
    -Wall \
    -s tb_pkg_smoke \
    -o "$VVP_OUTPUT" \
    "${PACKAGE_FILES[@]}" \
    "$TESTBENCH" \
    2>&1 | tee reports/lint/packages_iverilog.log

echo
echo "[3/3] Package smoke simulation"

vvp "$VVP_OUTPUT" \
    2>&1 | tee reports/rtl_sim/packages_smoke.log

echo
echo "RTL package foundation check: PASS"
