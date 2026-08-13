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

TOP="tb_rv32i_sram_macro"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
    rtl/pkg/rv32i_wishbone_pkg.sv
    rtl/memory/sky130_sram_2kbyte_1rw1r_32x512_8.sv
    rtl/soc/rv32i_sram_macro_wrapper.sv
    tb/unit/tb_rv32i_sram_macro.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator OpenRAM Macro Compilation"

verilator \
    --binary \
    -Wall \
    --timing \
    -Wno-fatal \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNDRIVEN \
    -Wno-UNUSED \
    -Wno-PINCONNECTEMPTY \
    -Wno-IMPORTSTAR \
    -Wno-VARHIDDEN \
    "${SOURCES[@]}" \
    --top-module "$TOP" \
    -o tb_rv32i_sram_macro_vl \
    2>&1 | tee reports/lint/sram_macro_verilator.log

echo
echo "[2/2] OpenRAM Macro Simulation"

./obj_dir/tb_rv32i_sram_macro_vl \
    2>&1 | tee reports/rtl_sim/sram_macro.log

echo
echo "OpenRAM 2KB SRAM Hard Macro Regression: PASS"
