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
    rtl/decode/rv32i_alu_decoder.sv
    rtl/decode/rv32i_illegal_detect.sv
    rtl/decode/rv32i_decoder.sv
    tb/unit/tb_rv32i_decoder.sv
)

TOP="tb_rv32i_decoder"
OUTPUT="sim/icarus/work/${TOP}.vvp"

mkdir -p sim/icarus/work reports/lint reports/rtl_sim

echo "[1/3] Verilator decoder lint"

verilator \
    --lint-only \
    --Wall \
    --timing \
    -Wno-fatal \
    --top-module "$TOP" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/decoder_verilator.log

echo
echo "[2/3] Icarus decoder compilation"

iverilog \
    -g2012 \
    -Wall \
    -s "$TOP" \
    -o "$OUTPUT" \
    "${SOURCES[@]}" \
    2>&1 | tee reports/lint/decoder_iverilog.log

echo
echo "[3/3] Decoder self-checking simulation"

vvp "$OUTPUT" \
    2>&1 | tee reports/rtl_sim/decoder.log

echo
echo "Decoder RTL regression: PASS"
