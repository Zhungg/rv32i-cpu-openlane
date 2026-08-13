`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/mdu/rv32m_divider.sv
// Module : rv32m_divider
//
// Synthesizable 32-bit Divider for RV32M Extension.
// Compliant with all RISC-V Unprivileged ISA corner cases:
// - Divide by Zero
// - Signed Overflow (-2^31 / -1)

module rv32m_divider
    import rv32i_pkg::*;
    import rv32m_pkg::*;
(
    input  mdu_op_e       mdu_op_i,
    input  xlen_t         operand_a_i,
    input  xlen_t         operand_b_i,
    output xlen_t         result_o
);

    wire is_signed = (mdu_op_i == MDU_DIV) || (mdu_op_i == MDU_REM);
    wire is_rem    = (mdu_op_i == MDU_REM) || (mdu_op_i == MDU_REMU);

    // Magnitude conversion for signed
    wire a_neg = is_signed && operand_a_i[31];
    wire b_neg = is_signed && operand_b_i[31];

    wire [31:0] abs_a = a_neg ? (-operand_a_i) : operand_a_i;
    wire [31:0] abs_b = b_neg ? (-operand_b_i) : operand_b_i;

    // Corner case checks
    wire div_by_zero     = (operand_b_i == 32'd0);
    wire signed_overflow = is_signed && (operand_a_i == 32'h8000_0000) && (operand_b_i == 32'hFFFF_FFFF);

    // Unsigned division core
    wire [31:0] unsigned_quo = div_by_zero ? 32'hFFFF_FFFF : (abs_a / abs_b);
    wire [31:0] unsigned_rem = div_by_zero ? operand_a_i   : (abs_a % abs_b);

    // Signed result adjustment
    wire quo_neg = a_neg ^ b_neg;
    wire rem_neg = a_neg;

    wire [31:0] signed_quo = quo_neg ? (-unsigned_quo) : unsigned_quo;
    wire [31:0] signed_rem = rem_neg ? (-unsigned_rem) : unsigned_rem;

    always_comb begin
        if (div_by_zero) begin
            if (is_rem) result_o = operand_a_i;
            else        result_o = 32'hFFFF_FFFF;
        end else if (signed_overflow) begin
            if (is_rem) result_o = 32'h0000_0000;
            else        result_o = 32'h8000_0000;
        end else begin
            case (mdu_op_i)
                MDU_DIV:  result_o = signed_quo;
                MDU_DIVU: result_o = unsigned_quo;
                MDU_REM:  result_o = signed_rem;
                MDU_REMU: result_o = unsigned_rem;
                default:  result_o = 32'd0;
            endcase
        end
    end

endmodule
