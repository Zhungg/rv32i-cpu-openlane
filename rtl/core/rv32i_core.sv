`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I core top-level wrapper.
//
// Data-memory, CSR and interrupt interfaces will be added during Step 6.
// The instruction-memory interface is already ready/valid based and does
// not assume zero-wait-state memory.

module rv32i_core #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000,
    parameter logic [31:0] TRAP_VECTOR  = 32'h0000_0100
) (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    output logic                              imem_req_valid_o,
    input  logic                              imem_req_ready_i,
    output rv32i_types_pkg::imem_request_t    imem_req_o,

    input  logic                              imem_rsp_valid_i,
    output logic                              imem_rsp_ready_o,
    input  rv32i_types_pkg::imem_response_t   imem_rsp_i,

    output logic                              dmem_req_valid_o,
    input  logic                              dmem_req_ready_i,
    output rv32i_types_pkg::dmem_request_t    dmem_req_o,

    input  logic                              dmem_rsp_valid_i,
    output logic                              dmem_rsp_ready_o,
    input  rv32i_types_pkg::dmem_response_t   dmem_rsp_i,

    output logic                              commit_valid_o,
    output logic                              commit_trap_o,
    output rv32i_pkg::addr_t                  commit_pc_o,
    output rv32i_pkg::addr_t                  commit_next_pc_o,
    output rv32i_pkg::insn_t                  commit_instruction_o,
    output logic                              commit_rd_write_o,
    output rv32i_pkg::reg_idx_t               commit_rd_index_o,
    output rv32i_pkg::xlen_t                  commit_rd_data_o,

    output logic                              baseline_stall_o,
    output logic                              debug_redirect_valid_o,
    output rv32i_pkg::addr_t                  debug_redirect_pc_o
);

    rv32i_datapath #(
        .RESET_VECTOR (RESET_VECTOR),
        .TRAP_VECTOR  (TRAP_VECTOR)
    ) u_datapath (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_ni),

        .imem_req_valid_o        (imem_req_valid_o),
        .imem_req_ready_i        (imem_req_ready_i),
        .imem_req_o              (imem_req_o),

        .imem_rsp_valid_i        (imem_rsp_valid_i),
        .imem_rsp_ready_o        (imem_rsp_ready_o),
        .imem_rsp_i              (imem_rsp_i),

        .dmem_req_valid_o        (dmem_req_valid_o),
        .dmem_req_ready_i        (dmem_req_ready_i),
        .dmem_req_o              (dmem_req_o),

        .dmem_rsp_valid_i        (dmem_rsp_valid_i),
        .dmem_rsp_ready_o        (dmem_rsp_ready_o),
        .dmem_rsp_i              (dmem_rsp_i),

        .commit_valid_o          (commit_valid_o),
        .commit_trap_o           (commit_trap_o),
        .commit_pc_o             (commit_pc_o),
        .commit_next_pc_o        (commit_next_pc_o),
        .commit_instruction_o    (commit_instruction_o),
        .commit_rd_write_o       (commit_rd_write_o),
        .commit_rd_index_o       (commit_rd_index_o),
        .commit_rd_data_o        (commit_rd_data_o),

        .baseline_stall_o        (baseline_stall_o),
        .debug_redirect_valid_o  (debug_redirect_valid_o),
        .debug_redirect_pc_o     (debug_redirect_pc_o)
    );

endmodule
