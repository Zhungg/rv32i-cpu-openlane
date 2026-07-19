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

    rtl/memory/rv32i_misaligned_detect.sv
    rtl/memory/rv32i_store_aligner.sv
    rtl/memory/rv32i_load_aligner.sv
    rtl/memory/rv32i_memory_controller.sv
    rtl/memory/rv32i_lsu.sv

    tb/unit/tb_rv32i_lsu_controller.sv
)

TOP="tb_rv32i_lsu_controller"
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
echo "[1/3] Verilator LSU controller lint"

verilator \
    --lint-only \
    --Wall \
    --timing \
    -Wno-fatal \
    --top-module "$TOP" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/lsu_controller_verilator.log

echo
echo "[2/3] Icarus LSU controller compilation"

iverilog \
    -g2012 \
    -Wall \
    -s "$TOP" \
    -o "$OUTPUT" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/lsu_controller_iverilog.log

echo
echo "[3/3] LSU controller self-checking simulation"

vvp "$OUTPUT" \
    2>&1 | tee reports/rtl_sim/lsu_controller.log

echo
echo "LSU controller RTL regression: PASS"
