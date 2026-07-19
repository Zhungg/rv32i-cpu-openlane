`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I immediate reconstruction unit.
//
// Supported immediate formats:
// - I: arithmetic immediate, load, JALR
// - S: store
// - B: conditional branch
// - U: LUI/AUIPC
// - J: JAL
// - Z: CSR immediate

import rv32i_pkg::*;
import rv32i_types_pkg::*;

module rv32i_imm_gen (
    input  rv32i_pkg::insn_t           instruction_i,
    input  rv32i_types_pkg::imm_sel_e  imm_sel_i,

    output rv32i_pkg::xlen_t           immediate_o
);


    always_comb begin
        immediate_o = '0;

        case (imm_sel_i)
            IMM_I: begin
                immediate_o = {
                    {20{instruction_i[31]}},
                    instruction_i[31:20]
                };
            end

            IMM_S: begin
                immediate_o = {
                    {20{instruction_i[31]}},
                    instruction_i[31:25],
                    instruction_i[11:7]
                };
            end

            IMM_B: begin
                immediate_o = {
                    {19{instruction_i[31]}},
                    instruction_i[31],
                    instruction_i[7],
                    instruction_i[30:25],
                    instruction_i[11:8],
                    1'b0
                };
            end

            IMM_U: begin
                immediate_o = {
                    instruction_i[31:12],
                    12'b0
                };
            end

            IMM_J: begin
                immediate_o = {
                    {11{instruction_i[31]}},
                    instruction_i[31],
                    instruction_i[19:12],
                    instruction_i[20],
                    instruction_i[30:21],
                    1'b0
                };
            end

            IMM_Z: begin
                immediate_o = {
                    27'b0,
                    instruction_i[19:15]
                };
            end

            IMM_NONE: begin
                immediate_o = '0;
            end

            default: begin
                immediate_o = '0;
            end
        endcase
    end

endmodule
