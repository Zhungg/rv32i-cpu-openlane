`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/mdu/rv32m_mdu.sv
// Module : rv32m_mdu
//
// Integrated Multiply-Divide Unit (MDU) with Operand Isolation for Dynamic Power Reduction.

module rv32m_mdu
    import rv32i_pkg::*;
    import rv32m_pkg::*;
(
    input  mdu_op_e       mdu_op_i,
    input  xlen_t         operand_a_i,
    input  xlen_t         operand_b_i,
    output xlen_t         result_o
);

    // Operand Isolation logic
    wire is_mul_op = (mdu_op_i == MDU_MUL || mdu_op_i == MDU_MULH ||
                      mdu_op_i == MDU_MULHSU || mdu_op_i == MDU_MULHU);

    wire is_div_op = (mdu_op_i == MDU_DIV || mdu_op_i == MDU_DIVU ||
                      mdu_op_i == MDU_REM || mdu_op_i == MDU_REMU);

    wire [31:0] mul_op_a = is_mul_op ? operand_a_i : 32'd0;
    wire [31:0] mul_op_b = is_mul_op ? operand_b_i : 32'd0;

    wire [31:0] div_op_a = is_div_op ? operand_a_i : 32'd0;
    wire [31:0] div_op_b = is_div_op ? operand_b_i : 32'd0;

    xlen_t mul_result;
    xlen_t div_result;

    rv32m_multiplier u_multiplier (
        .mdu_op_i   (mdu_op_i),
        .operand_a_i(mul_op_a),
        .operand_b_i(mul_op_b),
        .result_o   (mul_result)
    );

    rv32m_divider u_divider (
        .mdu_op_i   (mdu_op_i),
        .operand_a_i(div_op_a),
        .operand_b_i(div_op_b),
        .result_o   (div_result)
    );

    always_comb begin
        case (mdu_op_i)
            MDU_MUL,
            MDU_MULH,
            MDU_MULHSU,
            MDU_MULHU:  result_o = mul_result;

            MDU_DIV,
            MDU_DIVU,
            MDU_REM,
            MDU_REMU:   result_o = div_result;

            default:    result_o = 32'd0;
        endcase
    end

endmodule
