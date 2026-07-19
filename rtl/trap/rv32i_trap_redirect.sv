`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Basic trap redirect unit.
//
// Step 6G update:
// - Trap redirect PC comes from mtvec CSR state.
// - CSR side effects are handled by rv32i_csr_file.

module rv32i_trap_redirect (
    input  logic                          commit_valid_i,
    input  rv32i_types_pkg::exception_t   exception_i,
    input  rv32i_pkg::addr_t              trap_vector_i,

    output logic                          trap_taken_o,
    output logic                          trap_redirect_valid_o,
    output rv32i_pkg::addr_t              trap_redirect_pc_o
);

    always @* begin
        trap_taken_o          = commit_valid_i && exception_i.valid;
        trap_redirect_valid_o = trap_taken_o;
        trap_redirect_pc_o    = trap_vector_i;
    end

endmodule
