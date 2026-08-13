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

TOP="tb_rv32i_compliance"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
    rtl/pkg/rv32i_pmp_pkg.sv
    rtl/pkg/rv32i_wishbone_pkg.sv
    rtl/pkg/rv32i_cache_pkg.sv
    rtl/pkg/rv32m_pkg.sv
    rtl/execute/rv32i_alu.sv
    rtl/execute/rv32i_branch_compare.sv
    rtl/mdu/rv32m_multiplier.sv
    rtl/mdu/rv32m_divider.sv
    rtl/mdu/rv32m_mdu.sv
    tb/compliance/tb_rv32i_compliance.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator Architectural Compliance Compilation"

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
    -o tb_rv32i_compliance_vl \
    2>&1 | tee reports/lint/compliance_verilator.log

echo
echo "[2/2] RISC-V Architectural Compliance Simulation"

./obj_dir/tb_rv32i_compliance_vl \
    2>&1 | tee reports/rtl_sim/compliance.log

echo
echo "RISC-V Architectural Compliance Regression: PASS"
