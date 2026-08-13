# Packages
rtl/pkg/rv32i_pkg.sv
rtl/pkg/rv32i_encoding_pkg.sv
rtl/pkg/rv32i_csr_pkg.sv
rtl/pkg/rv32i_types_pkg.sv

# Branch Predictor
rtl/predict/rv32i_ghr.sv
rtl/predict/rv32i_pht.sv
rtl/predict/rv32i_btb.sv
rtl/predict/rv32i_branch_predictor.sv

# Frontend
rtl/frontend/rv32i_pc.sv
rtl/frontend/rv32i_fetch_buffer.sv
rtl/frontend/rv32i_fetch_unit.sv

# Decode
rtl/decode/rv32i_alu_decoder.sv
rtl/decode/rv32i_illegal_detect.sv
rtl/decode/rv32i_decoder.sv
rtl/decode/rv32i_imm_gen.sv
rtl/decode/rv32i_regfile.sv

# Execute
rtl/execute/rv32i_operand_mux.sv
rtl/execute/rv32i_alu.sv
rtl/execute/rv32i_branch_compare.sv
rtl/execute/rv32i_target_generator.sv

# Memory
rtl/memory/rv32i_misaligned_detect.sv
rtl/memory/rv32i_store_aligner.sv
rtl/memory/rv32i_load_aligner.sv
rtl/memory/rv32i_memory_controller.sv
rtl/memory/rv32i_lsu.sv

# Control
rtl/control/rv32i_hazard_unit.sv
rtl/control/rv32i_forwarding_unit.sv

# Trap
rtl/trap/rv32i_csr_file.sv
rtl/trap/rv32i_trap_redirect.sv

# Pipeline Registers
rtl/pipeline/rv32i_if_id.sv
rtl/pipeline/rv32i_id_ex.sv
rtl/pipeline/rv32i_ex_mem.sv
rtl/pipeline/rv32i_mem_wb.sv

# Core Top
rtl/core/rv32i_datapath.sv
rtl/core/rv32i_core.sv

# SoC Subsystem & Peripherals
rtl/soc/rv32i_boot_controller.sv
rtl/soc/rv32i_imem_wrapper.sv
rtl/soc/rv32i_dmem_wrapper.sv
rtl/soc/rv32i_uart.sv
rtl/soc/rv32i_timer.sv
rtl/soc/rv32i_address_decoder.sv
rtl/soc/rv32i_soc.sv
