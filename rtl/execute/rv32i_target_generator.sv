`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I control-transfer target generator.
//
// BRANCH/JAL:
//     target = PC + immediate
//
// JALR:
//     target = (rs1 + immediate) with bit zero cleared
//
// For IALIGN=32, the resulting target must be four-byte aligned.

import rv32i_pkg::*;
import rv32i_types_pkg::*;

module rv32i_target_generator (
    input  rv32i_pkg::addr_t             pc_i,
    input  rv32i_pkg::xlen_t             rs1_value_i,
    input  rv32i_pkg::xlen_t             immediate_i,
    input  rv32i_types_pkg::branch_op_e  branch_op_i,

    output rv32i_pkg::addr_t             target_o,
    output logic                         target_misaligned_o
);


    addr_t jalr_raw_target;

    always_comb begin
        target_o           = pc_i + addr_t'(32'd4);
        jalr_raw_target    = rs1_value_i + immediate_i;
        target_misaligned_o = 1'b0;

        case (branch_op_i)
            BR_EQ,
            BR_NE,
            BR_LT,
            BR_GE,
            BR_LTU,
            BR_GEU,
            BR_JAL: begin
                target_o = pc_i + immediate_i;
            end

            BR_JALR: begin
                target_o = {
                    jalr_raw_target[XLEN-1:1],
                    1'b0
                };
            end

            BR_NONE: begin
                target_o = pc_i + addr_t'(32'd4);
            end

            default: begin
                target_o = pc_i + addr_t'(32'd4);
            end
        endcase

        if (branch_op_i != BR_NONE) begin
            target_misaligned_o = !is_instruction_aligned(target_o);
        end
    end

endmodule
