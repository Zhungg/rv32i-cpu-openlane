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

    rtl/pipeline/rv32i_if_id.sv
    rtl/pipeline/rv32i_id_ex.sv
    rtl/pipeline/rv32i_ex_mem.sv
    rtl/pipeline/rv32i_mem_wb.sv

    tb/unit/tb_rv32i_pipeline_registers.sv
)

TOP="tb_rv32i_pipeline_registers"
OUTPUT="sim/icarus/work/${TOP}.vvp"

mkdir -p sim/icarus/work
mkdir -p reports/lint
mkdir -p reports/rtl_sim

echo "[1/3] Verilator pipeline-register lint"

verilator \
    --lint-only \
    --Wall \
    --timing \
    -Wno-fatal \
    --top-module "$TOP" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/pipeline_registers_verilator.log

echo
echo "[2/3] Icarus pipeline-register compilation"

iverilog \
    -g2012 \
    -Wall \
    -s "$TOP" \
    -o "$OUTPUT" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/pipeline_registers_iverilog.log

echo
echo "[3/3] Pipeline-register self-checking simulation"

vvp "$OUTPUT" \
    2>&1 | tee reports/rtl_sim/pipeline_registers.log

echo
echo "Pipeline-register RTL regression: PASS"
