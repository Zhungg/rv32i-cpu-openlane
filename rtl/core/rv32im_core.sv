`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/core/rv32im_core.sv
// Module : rv32im_core
//
// RV32IM Processor Core integrating standard RV32I base integer pipeline
// with hardware Multiply and Divide Unit (MDU - RV32M extension).

module rv32im_core
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32m_pkg::*;
#(
    parameter addr_t RESET_VECTOR = 32'h0000_0000,
    parameter addr_t TRAP_VECTOR  = 32'h0000_0100
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    // Instruction memory interface
    output logic              imem_req_valid_o,
    input  logic              imem_req_ready_i,
    output imem_request_t     imem_req_o,

    input  logic              imem_rsp_valid_i,
    output logic              imem_rsp_ready_o,
    input  imem_response_t    imem_rsp_i,

    // Data memory interface
    output logic              dmem_req_valid_o,
    input  logic              dmem_req_ready_i,
    output dmem_request_t     dmem_req_o,

    input  logic              dmem_rsp_valid_i,
    output logic              dmem_rsp_ready_o,
    input  dmem_response_t    dmem_rsp_i,

    // Architectural commit bus
    output logic              commit_valid_o,
    output logic              commit_trap_o,
    output addr_t             commit_pc_o,
    output addr_t             commit_next_pc_o,
    output insn_t             commit_instruction_o,
    output logic              commit_rd_write_o,
    output reg_idx_t          commit_rd_index_o,
    output xlen_t             commit_rd_data_o,

    // Debug / Baseline observability
    output logic              baseline_stall_o,
    output logic              debug_redirect_valid_o,
    output addr_t             debug_redirect_pc_o
);

    // MDU Decoding logic for EX stage
    mdu_op_e ex_mdu_op;
    wire [6:0] ex_opcode = u_base_core.u_datapath.id_ex_payload.instruction[6:0];
    wire [2:0] ex_funct3 = u_base_core.u_datapath.id_ex_payload.instruction[14:12];
    wire [6:0] ex_funct7 = u_base_core.u_datapath.id_ex_payload.instruction[31:25];

    always_comb begin
        if (ex_opcode == OPCODE_OP && ex_funct7 == FUNCT7_M_EXT) begin
            case (ex_funct3)
                FUNCT3_MUL:    ex_mdu_op = MDU_MUL;
                FUNCT3_MULH:   ex_mdu_op = MDU_MULH;
                FUNCT3_MULHSU: ex_mdu_op = MDU_MULHSU;
                FUNCT3_MULHU:  ex_mdu_op = MDU_MULHU;
                FUNCT3_DIV:    ex_mdu_op = MDU_DIV;
                FUNCT3_DIVU:   ex_mdu_op = MDU_DIVU;
                FUNCT3_REM:    ex_mdu_op = MDU_REM;
                FUNCT3_REMU:   ex_mdu_op = MDU_REMU;
                default:       ex_mdu_op = MDU_NONE;
            endcase
        end else begin
            ex_mdu_op = MDU_NONE;
        end
    end

    // MDU Execution
    xlen_t mdu_result;
    rv32m_mdu u_mdu (
        .mdu_op_i   (ex_mdu_op),
        .operand_a_i(u_base_core.u_datapath.ex_operand_a),
        .operand_b_i(u_base_core.u_datapath.ex_operand_b),
        .result_o   (mdu_result)
    );

    // Instantiate Base Core
    rv32i_core #(
        .RESET_VECTOR (RESET_VECTOR),
        .TRAP_VECTOR  (TRAP_VECTOR)
    ) u_base_core (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),

        .imem_req_valid_o       (imem_req_valid_o),
        .imem_req_ready_i       (imem_req_ready_i),
        .imem_req_o             (imem_req_o),

        .imem_rsp_valid_i       (imem_rsp_valid_i),
        .imem_rsp_ready_o       (imem_rsp_ready_o),
        .imem_rsp_i             (imem_rsp_i),

        .dmem_req_valid_o       (dmem_req_valid_o),
        .dmem_req_ready_i       (dmem_req_ready_i),
        .dmem_req_o             (dmem_req_o),

        .dmem_rsp_valid_i       (dmem_rsp_valid_i),
        .dmem_rsp_ready_o       (dmem_rsp_ready_o),
        .dmem_rsp_i             (dmem_rsp_i),

        .commit_valid_o         (commit_valid_o),
        .commit_trap_o          (commit_trap_o),
        .commit_pc_o            (commit_pc_o),
        .commit_next_pc_o       (commit_next_pc_o),
        .commit_instruction_o   (commit_instruction_o),
        .commit_rd_write_o      (commit_rd_write_o),
        .commit_rd_index_o      (commit_rd_index_o),
        .commit_rd_data_o       (commit_rd_data_o),

        .baseline_stall_o       (baseline_stall_o),
        .debug_redirect_valid_o (debug_redirect_valid_o),
        .debug_redirect_pc_o    (debug_redirect_pc_o)
    );

endmodule
