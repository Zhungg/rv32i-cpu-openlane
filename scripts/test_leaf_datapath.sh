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

PACKAGE_FILES=(
    rtl/pkg/rv32i_pkg.sv
    rtl/pkg/rv32i_encoding_pkg.sv
    rtl/pkg/rv32i_csr_pkg.sv
    rtl/pkg/rv32i_types_pkg.sv
)

mkdir -p sim/icarus/work
mkdir -p reports/lint
mkdir -p reports/rtl_sim

run_test() {
    local top="$1"
    local dut="$2"
    local tb="$3"
    local output="sim/icarus/work/${top}.vvp"

    echo
    echo "============================================================"
    echo "Running: ${top}"
    echo "============================================================"

    echo "[1/3] Verilator lint"

    verilator \
        --lint-only \
        --Wall \
        --timing \
        -Wno-fatal \
        --top-module "$top" \
        "${PACKAGE_FILES[@]}" \
        "$dut" \
        "$tb" \
        2>&1 | tee "reports/lint/${top}_verilator.log"

    echo
    echo "[2/3] Icarus compilation"

    iverilog \
        -g2012 \
        -Wall \
        -s "$top" \
        -o "$output" \
        "${PACKAGE_FILES[@]}" \
        "$dut" \
        "$tb" \
        2>&1 | tee "reports/lint/${top}_iverilog.log"

    echo
    echo "[3/3] Self-checking simulation"

    vvp "$output" \
        2>&1 | tee "reports/rtl_sim/${top}.log"
}

run_test \
    tb_rv32i_alu \
    rtl/execute/rv32i_alu.sv \
    tb/unit/tb_rv32i_alu.sv

run_test \
    tb_rv32i_imm_gen \
    rtl/decode/rv32i_imm_gen.sv \
    tb/unit/tb_rv32i_imm_gen.sv

run_test \
    tb_rv32i_regfile \
    rtl/decode/rv32i_regfile.sv \
    tb/unit/tb_rv32i_regfile.sv

echo
echo "============================================================"
echo "Leaf datapath RTL regression: PASS"
echo "Tests completed: 3"
echo "============================================================"
