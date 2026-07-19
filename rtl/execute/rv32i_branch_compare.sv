`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I branch condition comparator.
//
// This module evaluates both conditional branches and unconditional jumps.
// It is purely combinational and produces no architectural state.

module rv32i_branch_compare (
    input  rv32i_pkg::xlen_t             operand_a_i,
    input  rv32i_pkg::xlen_t             operand_b_i,
    input  rv32i_types_pkg::branch_op_e  branch_op_i,

    output logic                         branch_taken_o
);

    import rv32i_types_pkg::*;

    always_comb begin
        branch_taken_o = 1'b0;

        case (branch_op_i)
            BR_EQ: begin
                branch_taken_o = (operand_a_i == operand_b_i);
            end

            BR_NE: begin
                branch_taken_o = (operand_a_i != operand_b_i);
            end

            BR_LT: begin
                branch_taken_o =
                    ($signed(operand_a_i) < $signed(operand_b_i));
            end

            BR_GE: begin
                branch_taken_o =
                    ($signed(operand_a_i) >= $signed(operand_b_i));
            end

            BR_LTU: begin
                branch_taken_o = (operand_a_i < operand_b_i);
            end

            BR_GEU: begin
                branch_taken_o = (operand_a_i >= operand_b_i);
            end

            BR_JAL,
            BR_JALR: begin
                branch_taken_o = 1'b1;
            end

            BR_NONE: begin
                branch_taken_o = 1'b0;
            end

            default: begin
                branch_taken_o = 1'b0;
            end
        endcase
    end

endmodule
