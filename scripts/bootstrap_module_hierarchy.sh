#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

modules=(
  # Packages
  "STEP5:rtl/pkg/rv32i_pkg.sv"
  "STEP5:rtl/pkg/rv32i_encoding_pkg.sv"
  "STEP6:rtl/pkg/rv32i_csr_pkg.sv"
  "STEP5:rtl/pkg/rv32i_types_pkg.sv"

  # Core
  "STEP5:rtl/core/rv32i_core.sv"
  "STEP5:rtl/core/rv32i_datapath.sv"
  "STEP5:rtl/core/rv32i_control.sv"

  # Frontend and branch prediction
  "STEP5:rtl/frontend/rv32i_fetch_unit.sv"
  "STEP5:rtl/frontend/rv32i_pc.sv"
  "STEP5:rtl/frontend/rv32i_fetch_buffer.sv"
  "STEP7:rtl/frontend/rv32i_bpu.sv"
  "STEP7:rtl/frontend/rv32i_btb.sv"
  "STEP7:rtl/frontend/rv32i_pht.sv"
  "STEP7:rtl/frontend/rv32i_ghr.sv"
  "STEP7:rtl/frontend/rv32i_ras.sv"

  # Decode
  "STEP5:rtl/decode/rv32i_decoder.sv"
  "STEP5:rtl/decode/rv32i_alu_decoder.sv"
  "STEP5:rtl/decode/rv32i_imm_gen.sv"
  "STEP5:rtl/decode/rv32i_regfile.sv"
  "STEP5:rtl/decode/rv32i_illegal_detect.sv"

  # Execute
  "STEP5:rtl/execute/rv32i_alu.sv"
  "STEP5:rtl/execute/rv32i_branch_compare.sv"
  "STEP5:rtl/execute/rv32i_target_generator.sv"
  "STEP5:rtl/execute/rv32i_operand_mux.sv"

  # Memory subsystem
  "STEP6:rtl/memory/rv32i_lsu.sv"
  "STEP6:rtl/memory/rv32i_load_aligner.sv"
  "STEP6:rtl/memory/rv32i_store_aligner.sv"
  "STEP6:rtl/memory/rv32i_misaligned_detect.sv"
  "STEP6:rtl/memory/rv32i_memory_controller.sv"
  "STEP6:rtl/memory/rv32i_fence_controller.sv"

  # Pipeline registers
  "STEP5:rtl/pipeline/rv32i_if_id.sv"
  "STEP5:rtl/pipeline/rv32i_id_ex.sv"
  "STEP5:rtl/pipeline/rv32i_ex_mem.sv"
  "STEP5:rtl/pipeline/rv32i_mem_wb.sv"

  # Pipeline control
  "STEP6:rtl/control/rv32i_hazard_unit.sv"
  "STEP6:rtl/control/rv32i_forwarding_unit.sv"
  "STEP6:rtl/control/rv32i_stall_controller.sv"
  "STEP6:rtl/control/rv32i_flush_kill_controller.sv"
  "STEP6:rtl/control/rv32i_redirect_arbiter.sv"

  # Commit and retirement
  "STEP6:rtl/commit/rv32i_writeback.sv"
  "STEP6:rtl/commit/rv32i_commit.sv"
  "STEP6:rtl/commit/rv32i_retirement.sv"
  "STEP8:rtl/commit/rv32i_rvfi_adapter.sv"

  # Trap, CSR and interrupts
  "STEP6:rtl/trap/rv32i_exception_detect.sv"
  "STEP6:rtl/trap/rv32i_trap_arbiter.sv"
  "STEP6:rtl/trap/rv32i_trap_controller.sv"
  "STEP6:rtl/trap/rv32i_csr_file.sv"
  "STEP6:rtl/trap/rv32i_interrupt_controller.sv"
  "STEP6:rtl/trap/rv32i_machine_mode.sv"

  # ASIC infrastructure
  "STEP5:rtl/infrastructure/rv32i_reset_controller.sv"
  "STEP6:rtl/infrastructure/rv32i_clock_enable.sv"
  "STEP9:rtl/infrastructure/rv32i_dft_wrapper.sv"

  # SoC integration
  "STEP5:rtl/soc/rv32i_soc.sv"
  "STEP5:rtl/soc/rv32i_imem_wrapper.sv"
  "STEP5:rtl/soc/rv32i_dmem_wrapper.sv"
  "STEP5:rtl/soc/rv32i_address_decoder.sv"
  "STEP5:rtl/soc/rv32i_boot_controller.sv"
)

mkdir -p config
printf "implementation_step,path,status\n" \
  > config/rtl_module_manifest.csv

created=0
existing=0

for item in "${modules[@]}"; do
  step="${item%%:*}"
  path="${item#*:}"

  mkdir -p "$(dirname "$path")"

  if [[ ! -e "$path" ]]; then
    module_name="$(basename "$path" .sv)"

    cat > "$path" <<EOF_FILE
// SPDX-License-Identifier: Apache-2.0
//
// File   : $path
// Module : $module_name
// Phase  : $step
//
// RV32I CPU RTL-to-GDSII Project
//
// This source file was created during Step 4:
// Repository and module hierarchy initialization.
//
// The synthesizable interface and implementation will be completed
// during the implementation step indicated above.
//
// IMPORTANT:
// - Do not add this file to config/rtl.f until it contains valid RTL.
// - Do not infer latches.
// - Do not create combinational clock logic.
// - Use definitions from rtl/pkg.
// - All architectural side effects must be qualified by stage validity.
//
// TODO: Define interface.
// TODO: Implement synthesizable logic.
// TODO: Add unit-level verification.
EOF_FILE

    created=$((created + 1))
  else
    existing=$((existing + 1))
  fi

  printf "%s,%s,PLACEHOLDER\n" "$step" "$path" \
    >> config/rtl_module_manifest.csv
done

echo "Module hierarchy bootstrap: PASS"
echo "Created files:  $created"
echo "Existing files: $existing"
echo "Manifest:       config/rtl_module_manifest.csv"
echo "Total entries:  ${#modules[@]}"
