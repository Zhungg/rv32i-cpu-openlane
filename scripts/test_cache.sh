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

TOP="tb_rv32i_cache"
SOURCES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
    rtl/pkg/rv32i_wishbone_pkg.sv
    rtl/pkg/rv32i_cache_pkg.sv
    rtl/cache/rv32i_icache.sv
    rtl/cache/rv32i_dcache.sv
    tb/unit/tb_rv32i_cache.sv
)

mkdir -p reports/lint reports/rtl_sim

echo "[1/2] Verilator L1 Cache Compilation"

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
    -o tb_rv32i_cache_vl \
    2>&1 | tee reports/lint/cache_verilator.log

echo
echo "[2/2] L1 I-Cache & D-Cache Unit Simulation"

./obj_dir/tb_rv32i_cache_vl \
    2>&1 | tee reports/rtl_sim/cache.log

echo
echo "L1 Cache Subsystem Regression: PASS"
