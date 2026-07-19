`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I integer arithmetic and logic unit.
//
// Physical-design notes:
// - Pure combinational logic.
// - Shift amount is limited to operand_b_i[4:0] for RV32.
// - No flag registers are created.
// - Branch comparison is handled by a dedicated comparator module.

import rv32i_pkg::*;
import rv32i_types_pkg::*;

module rv32i_alu (
    input  rv32i_pkg::xlen_t          operand_a_i,
    input  rv32i_pkg::xlen_t          operand_b_i,
    input  rv32i_types_pkg::alu_op_e  alu_op_i,

    output rv32i_pkg::xlen_t          result_o
);


    always_comb begin
        result_o = '0;

        case (alu_op_i)
            ALU_ADD: begin
                result_o = operand_a_i + operand_b_i;
            end

            ALU_SUB: begin
                result_o = operand_a_i - operand_b_i;
            end

            ALU_SLL: begin
                result_o = operand_a_i << operand_b_i[4:0];
            end

            ALU_SLT: begin
                result_o = {
                    {(XLEN-1){1'b0}},
                    ($signed(operand_a_i) < $signed(operand_b_i))
                };
            end

            ALU_SLTU: begin
                result_o = {
                    {(XLEN-1){1'b0}},
                    (operand_a_i < operand_b_i)
                };
            end

            ALU_XOR: begin
                result_o = operand_a_i ^ operand_b_i;
            end

            ALU_SRL: begin
                result_o = operand_a_i >> operand_b_i[4:0];
            end

            ALU_SRA: begin
                result_o = $signed(operand_a_i) >>> operand_b_i[4:0];
            end

            ALU_OR: begin
                result_o = operand_a_i | operand_b_i;
            end

            ALU_AND: begin
                result_o = operand_a_i & operand_b_i;
            end

            ALU_COPY_A: begin
                result_o = operand_a_i;
            end

            ALU_COPY_B: begin
                result_o = operand_b_i;
            end

            default: begin
                result_o = '0;
            end
        endcase
    end

endmodule
