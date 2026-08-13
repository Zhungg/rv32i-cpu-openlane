#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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

    rtl/predict/rv32i_ghr.sv
    rtl/predict/rv32i_pht.sv
    rtl/predict/rv32i_btb.sv
    rtl/predict/rv32i_branch_predictor.sv

    rtl/frontend/rv32i_pc.sv
    rtl/frontend/rv32i_fetch_buffer.sv
    rtl/frontend/rv32i_fetch_unit.sv

    rtl/decode/rv32i_alu_decoder.sv
    rtl/decode/rv32i_illegal_detect.sv
    rtl/decode/rv32i_decoder.sv
    rtl/decode/rv32i_imm_gen.sv
    rtl/decode/rv32i_regfile.sv

    rtl/execute/rv32i_operand_mux.sv
    rtl/execute/rv32i_alu.sv
    rtl/execute/rv32i_branch_compare.sv
    rtl/execute/rv32i_target_generator.sv

    rtl/memory/rv32i_misaligned_detect.sv
    rtl/memory/rv32i_store_aligner.sv
    rtl/memory/rv32i_load_aligner.sv
    rtl/memory/rv32i_memory_controller.sv
    rtl/memory/rv32i_lsu.sv

    rtl/control/rv32i_hazard_unit.sv
    rtl/control/rv32i_forwarding_unit.sv

    rtl/trap/rv32i_csr_file.sv
    rtl/trap/rv32i_trap_redirect.sv

    rtl/pipeline/rv32i_if_id.sv
    rtl/pipeline/rv32i_id_ex.sv
    rtl/pipeline/rv32i_ex_mem.sv
    rtl/pipeline/rv32i_mem_wb.sv

    rtl/core/rv32i_datapath.sv
    rtl/core/rv32i_core.sv

    rtl/soc/rv32i_boot_controller.sv
    rtl/soc/rv32i_imem_wrapper.sv
    rtl/soc/rv32i_dmem_wrapper.sv
    rtl/soc/rv32i_uart.sv
    rtl/soc/rv32i_timer.sv
    rtl/soc/rv32i_address_decoder.sv
    rtl/soc/rv32i_soc.sv

    tb/integration/tb_rv32i_soc.sv
)

TOP="tb_rv32i_soc"
OUTPUT="sim/icarus/work/${TOP}.vvp"

mkdir -p \
    sim/icarus/work \
    reports/lint \
    reports/rtl_sim

echo "[0/3] Source-file integrity check"

for source_file in "${SOURCES[@]}"; do
    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Missing source file: $source_file"
        exit 1
    fi
done

echo "Source-file integrity check: PASS"

echo
echo "[1/2] Verilator SoC Compilation"

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
    -f config/soc_rtl.f \
    tb/integration/tb_rv32i_soc.sv \
    --top-module "$TOP" \
    -o tb_rv32i_soc_vl \
    2>&1 | tee reports/lint/soc_verilator.log

echo
echo "[2/2] SoC self-checking simulation"

./obj_dir/tb_rv32i_soc_vl \
    2>&1 | tee reports/rtl_sim/soc.log

echo
echo "RV32I SoC Integration Regression: PASS"
