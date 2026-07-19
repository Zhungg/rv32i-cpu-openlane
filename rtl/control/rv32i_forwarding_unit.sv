`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I baseline forwarding unit.
//
// Step 6E scope:
// - Forward EX/MEM result to EX operands.
// - Forward MEM/WB writeback data to EX operands.
// - Give EX/MEM priority over MEM/WB.
// - Do not forward load data from EX/MEM because the value is not
//   available until the memory response reaches MEM/WB.
//
// This unit forwards the raw register operand values. Operand-A/Operand-B
// selection is still handled later by rv32i_operand_mux.

import rv32i_pkg::*;
import rv32i_types_pkg::*;

module rv32i_forwarding_unit (
    input  logic                  ex_valid_i,

    input  logic                  ex_use_rs1_i,
    input  rv32i_pkg::reg_idx_t   ex_rs1_index_i,
    input  rv32i_pkg::xlen_t      ex_rs1_value_i,

    input  logic                  ex_use_rs2_i,
    input  rv32i_pkg::reg_idx_t   ex_rs2_index_i,
    input  rv32i_pkg::xlen_t      ex_rs2_value_i,

    // Older instruction currently in EX/MEM.
    input  logic                  mem_valid_i,
    input  logic                  mem_exception_valid_i,
    input  logic                  mem_gpr_write_i,
    input  rv32i_pkg::reg_idx_t   mem_rd_index_i,
    input  rv32i_types_pkg::wb_sel_e mem_wb_sel_i,
    input  rv32i_pkg::xlen_t      mem_alu_result_i,
    input  rv32i_pkg::xlen_t      mem_pc_plus_4_i,

    // Older instruction currently in MEM/WB.
    input  logic                  wb_valid_i,
    input  logic                  wb_exception_valid_i,
    input  logic                  wb_gpr_write_i,
    input  rv32i_pkg::reg_idx_t   wb_rd_index_i,
    input  rv32i_pkg::xlen_t      wb_writeback_data_i,

    output rv32i_pkg::xlen_t      rs1_value_o,
    output rv32i_pkg::xlen_t      rs2_value_o,

    output logic                  rs1_forwarded_o,
    output logic                  rs2_forwarded_o
);


    logic mem_forward_allowed;
    logic wb_forward_allowed;

    xlen_t mem_forward_data;

    logic rs1_match_mem;
    logic rs2_match_mem;

    logic rs1_match_wb;
    logic rs2_match_wb;

    always @* begin
        mem_forward_data = '0;

        case (mem_wb_sel_i)
            WB_ALU,
            WB_IMMEDIATE: begin
                mem_forward_data = mem_alu_result_i;
            end

            WB_PC_PLUS_4: begin
                mem_forward_data = mem_pc_plus_4_i;
            end

            default: begin
                mem_forward_data = '0;
            end
        endcase
    end

    always @* begin
        mem_forward_allowed =
            mem_valid_i &&
            mem_gpr_write_i &&
            !mem_exception_valid_i &&
            (mem_rd_index_i != REG_X0) &&
            (
                (mem_wb_sel_i == WB_ALU) ||
                (mem_wb_sel_i == WB_IMMEDIATE) ||
                (mem_wb_sel_i == WB_PC_PLUS_4)
            );

        wb_forward_allowed =
            wb_valid_i &&
            wb_gpr_write_i &&
            !wb_exception_valid_i &&
            (wb_rd_index_i != REG_X0);

        rs1_match_mem =
            ex_valid_i &&
            ex_use_rs1_i &&
            mem_forward_allowed &&
            (ex_rs1_index_i == mem_rd_index_i);

        rs2_match_mem =
            ex_valid_i &&
            ex_use_rs2_i &&
            mem_forward_allowed &&
            (ex_rs2_index_i == mem_rd_index_i);

        rs1_match_wb =
            ex_valid_i &&
            ex_use_rs1_i &&
            wb_forward_allowed &&
            (ex_rs1_index_i == wb_rd_index_i);

        rs2_match_wb =
            ex_valid_i &&
            ex_use_rs2_i &&
            wb_forward_allowed &&
            (ex_rs2_index_i == wb_rd_index_i);

        rs1_value_o     = ex_rs1_value_i;
        rs2_value_o     = ex_rs2_value_i;
        rs1_forwarded_o = 1'b0;
        rs2_forwarded_o = 1'b0;

        // Priority: EX/MEM over MEM/WB.
        if (rs1_match_mem) begin
            rs1_value_o     = mem_forward_data;
            rs1_forwarded_o = 1'b1;
        end
        else if (rs1_match_wb) begin
            rs1_value_o     = wb_writeback_data_i;
            rs1_forwarded_o = 1'b1;
        end

        if (rs2_match_mem) begin
            rs2_value_o     = mem_forward_data;
            rs2_forwarded_o = 1'b1;
        end
        else if (rs2_match_wb) begin
            rs2_value_o     = wb_writeback_data_i;
            rs2_forwarded_o = 1'b1;
        end
    end

endmodule
