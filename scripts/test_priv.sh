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

TOP="tb_rv32i_priv_controller"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
    rtl/pkg/rv32i_pmp_pkg.sv
    rtl/trap/rv32i_priv_controller.sv
    tb/unit/tb_rv32i_priv_controller.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator Privilege Controller Compilation"

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
    -o tb_rv32i_priv_controller_vl \
    2>&1 | tee reports/lint/priv_verilator.log

echo
echo "[2/2] Multi-Privilege Mode Simulation"

./obj_dir/tb_rv32i_priv_controller_vl \
    2>&1 | tee reports/rtl_sim/priv.log

echo
echo "RV32I Multi-Privilege Mode (M & U Mode) Regression: PASS"
