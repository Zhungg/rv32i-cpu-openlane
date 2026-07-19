`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I frontend program counter.
//
// Priority:
//     asynchronous reset
//     > architectural redirect
//     > accepted next-PC update
//     > hold
//
// The PC changes only when a request is accepted or when an older
// instruction redirects the frontend.

module rv32i_pc #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
) (
    input  logic                 clk_i,
    input  logic                 rst_ni,

    input  logic                 next_valid_i,
    input  logic [31:0]     next_pc_i,

    input  logic                 redirect_valid_i,
    input  logic [31:0]     redirect_pc_i,

    output logic [31:0]     pc_o
);
    logic [31:0] pc_q;

    assign pc_o = pc_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pc_q <= RESET_VECTOR;
        end
        else if (redirect_valid_i) begin
            pc_q <= redirect_pc_i;
        end
        else if (next_valid_i) begin
            pc_q <= next_pc_i;
        end
    end

endmodule
