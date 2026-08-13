#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

for tool in verilator; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found: $tool"
        exit 1
    fi
done

TOP="tb_rv32i_soc_wb"

mkdir -p \
    reports/lint \
    reports/rtl_sim \
    obj_dir_wb

echo "[0/2] Source-file integrity check"
if [[ ! -f "config/soc_wb_rtl.f" ]] || [[ ! -f "tb/integration/tb_rv32i_soc_wb.sv" ]]; then
    echo "ERROR: Missing required Wishbone SoC files."
    exit 1
fi
echo "Source-file integrity check: PASS"

echo
echo "[1/2] Verilator Wishbone SoC Compilation"

verilator \
    --binary \
    -Wall \
    --timing \
    -Wno-fatal \
    -Wno-UNUSEDPARAM \
    -Wno-SYNCASYNCNET \
    -Wno-BLKSEQ \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNDRIVEN \
    -Wno-UNUSED \
    -Wno-PINCONNECTEMPTY \
    -Wno-IMPORTSTAR \
    -Wno-VARHIDDEN \
    -f config/soc_wb_rtl.f \
    tb/integration/tb_rv32i_soc_wb.sv \
    --top-module "$TOP" \
    -o tb_rv32i_soc_wb_vl \
    2>&1 | tee reports/lint/soc_wb_verilator.log

echo
echo "[2/2] Wishbone SoC self-checking simulation"

./obj_dir/tb_rv32i_soc_wb_vl \
    2>&1 | tee reports/rtl_sim/soc_wb.log

echo
echo "Wishbone RV32I SoC Integration Regression: PASS"
