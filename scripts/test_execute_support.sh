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

SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_encoding_pkg.sv
    rtl/pkg/rv32i_csr_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv

    rtl/execute/rv32i_branch_compare.sv
    rtl/execute/rv32i_target_generator.sv
    rtl/execute/rv32i_operand_mux.sv

    tb/unit/tb_rv32i_execute_support.sv
)

TOP="tb_rv32i_execute_support"
OUTPUT="sim/icarus/work/${TOP}.vvp"

mkdir -p sim/icarus/work
mkdir -p reports/lint
mkdir -p reports/rtl_sim

echo "[1/3] Verilator execute-support lint"

verilator \
    --lint-only \
    --Wall \
    --timing \
    -Wno-fatal \
    --top-module "$TOP" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/execute_support_verilator.log

echo
echo "[2/3] Icarus execute-support compilation"

iverilog \
    -g2012 \
    -Wall \
    -s "$TOP" \
    -o "$OUTPUT" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/execute_support_iverilog.log

echo
echo "[3/3] Execute-support self-checking simulation"

vvp "$OUTPUT" \
    2>&1 | tee reports/rtl_sim/execute_support.log

echo
echo "Execute-support RTL regression: PASS"
