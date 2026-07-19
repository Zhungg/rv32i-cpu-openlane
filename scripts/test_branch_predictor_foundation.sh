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

    rtl/predict/rv32i_ghr.sv
    rtl/predict/rv32i_pht.sv
    rtl/predict/rv32i_btb.sv
    rtl/predict/rv32i_branch_predictor.sv

    tb/predict/tb_rv32i_branch_predictor.sv
)

TOP="tb_rv32i_branch_predictor"
OUTPUT="sim/icarus/work/${TOP}.vvp"

mkdir -p \
    sim/icarus/work \
    reports/lint \
    reports/rtl_sim

echo "[0/3] Source-file integrity check"

for source_file in "${SOURCES[@]}"; do
    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Missing source file: $source_file"
        exit 1
    fi
done

echo "Source-file integrity check: PASS"

echo
echo "[1/3] Verilator branch predictor foundation lint"

verilator \
    --lint-only \
    --Wall \
    --timing \
    -Wno-fatal \
    -Wno-UNUSEDSIGNAL \
    --top-module "$TOP" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/branch_predictor_foundation_verilator.log

echo
echo "[2/3] Icarus branch predictor foundation compilation"

iverilog \
    -g2012 \
    -Wall \
    -s "$TOP" \
    -o "$OUTPUT" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/branch_predictor_foundation_iverilog.log

echo
echo "[3/3] Branch predictor foundation self-checking simulation"

vvp "$OUTPUT" \
    2>&1 | tee reports/rtl_sim/branch_predictor_foundation.log

echo
echo "Branch predictor foundation regression: PASS"
