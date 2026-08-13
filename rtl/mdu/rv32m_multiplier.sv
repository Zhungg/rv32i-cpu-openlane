`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/mdu/rv32m_multiplier.sv
// Module : rv32m_multiplier
//
// Unified High-Performance Multiplier for RV32M Extension.
// Unified single 33x33 multiplier for MUL, MULH, MULHSU, MULHU to optimize Area, Delay, and Power.

module rv32m_multiplier
    import rv32i_pkg::*;
    import rv32m_pkg::*;
(
    input  mdu_op_e       mdu_op_i,
    input  xlen_t         operand_a_i,
    input  xlen_t         operand_b_i,
    output xlen_t         result_o
);

    // Operand sign extension conditioning
    wire a_is_signed = (mdu_op_i != MDU_MULHU);
    wire b_is_signed = (mdu_op_i != MDU_MULHU && mdu_op_i != MDU_MULHSU);

    wire signed [32:0] op_a_ext = a_is_signed ? {operand_a_i[31], operand_a_i} : {1'b0, operand_a_i};
    wire signed [32:0] op_b_ext = b_is_signed ? {operand_b_i[31], operand_b_i} : {1'b0, operand_b_i};

    // Unified 33x33 signed multiplier
    wire signed [65:0] prod_unified = op_a_ext * op_b_ext;

    always_comb begin
        case (mdu_op_i)
            MDU_MUL:    result_o = prod_unified[31:0];
            MDU_MULH,
            MDU_MULHSU,
            MDU_MULHU:  result_o = prod_unified[63:32];
            default:    result_o = 32'd0;
        endcase
    end

endmodule
