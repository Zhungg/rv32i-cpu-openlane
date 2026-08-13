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

TOP="tb_rv32i_power_controller"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/control/rv32i_clock_gate.sv
    rtl/control/rv32i_power_controller.sv
    tb/unit/tb_rv32i_power_controller.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator Power Controller Compilation"

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
    -o tb_rv32i_power_controller_vl \
    2>&1 | tee reports/lint/power_verilator.log

echo
echo "[2/2] Low-Power Clock Gating Simulation"

./obj_dir/tb_rv32i_power_controller_vl \
    2>&1 | tee reports/rtl_sim/power.log

echo
echo "RV32I Low-Power & Clock Gating Regression: PASS"
