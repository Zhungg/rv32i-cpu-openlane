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

TOP="tb_rv32m_mdu"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32m_pkg.sv
    rtl/mdu/rv32m_multiplier.sv
    rtl/mdu/rv32m_divider.sv
    rtl/mdu/rv32m_mdu.sv
    tb/unit/tb_rv32m_mdu.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator RV32M MDU Compilation"

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
    -o tb_rv32m_mdu_vl \
    2>&1 | tee reports/lint/mdu_verilator.log

echo
echo "[2/2] RV32M MDU Unit Simulation"

./obj_dir/tb_rv32m_mdu_vl \
    2>&1 | tee reports/rtl_sim/mdu.log

echo
echo "RV32M Hardware Multiplier & Divider Unit Regression: PASS"
