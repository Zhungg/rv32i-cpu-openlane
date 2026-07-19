`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I EX-stage ALU operand selection.
//
// Forwarded rs1/rs2 values must be selected before entering this module.
// This

import rv32i_types_pkg::*;

module only selects architectural operand classes.

module rv32i_operand_mux (
    input  rv32i_pkg::xlen_t                  rs1_value_i,
    input  rv32i_pkg::xlen_t                  rs2_value_i,
    input  rv32i_pkg::addr_t                  pc_i,
    input  rv32i_pkg::xlen_t                  immediate_i,

    input  rv32i_types_pkg::operand_a_sel_e   operand_a_sel_i,
    input  rv32i_types_pkg::operand_b_sel_e   operand_b_sel_i,

    output rv32i_pkg::xlen_t                  operand_a_o,
    output rv32i_pkg::xlen_t                  operand_b_o
);


    always_comb begin
        operand_a_o = '0;

        case (operand_a_sel_i)
            OP_A_RS1:  operand_a_o = rs1_value_i;
            OP_A_PC:   operand_a_o = pc_i;
            OP_A_ZERO: operand_a_o = '0;
            default:   operand_a_o = '0;
        endcase
    end

    always_comb begin
        operand_b_o = '0;

        case (operand_b_sel_i)
            OP_B_RS2:     operand_b_o = rs2_value_i;
            OP_B_IMM:     operand_b_o = immediate_i;
            OP_B_CONST_4: operand_b_o = 32'd4;
            OP_B_ZERO:    operand_b_o = '0;
            default:      operand_b_o = '0;
        endcase
    end

endmodule
