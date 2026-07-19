`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I baseline hazard unit.
//
// Step 6D scope:
// - Detect load-use RAW hazard.
// - Stall IF/ID.
// - Insert bubble into ID/EX.
//
// This unit intentionally handles only load-use hazards. ALU-to-ALU
// forwarding is implemented in Step 6E.

import rv32i_pkg::*;

module rv32i_hazard_unit (
    input  logic                  id_valid_i,
    input  rv32i_pkg::reg_idx_t   id_rs1_index_i,
    input  rv32i_pkg::reg_idx_t   id_rs2_index_i,
    input  logic                  id_use_rs1_i,
    input  logic                  id_use_rs2_i,

    input  logic                  ex_valid_i,
    input  rv32i_pkg::reg_idx_t   ex_rd_index_i,
    input  logic                  ex_gpr_write_i,
    input  logic                  ex_memory_valid_i,
    input  logic                  ex_memory_write_i,

    input  logic                  mem_valid_i,
    input  rv32i_pkg::reg_idx_t   mem_rd_index_i,
    input  logic                  mem_gpr_write_i,
    input  logic                  mem_memory_valid_i,
    input  logic                  mem_memory_write_i,

    output logic                  load_use_stall_o
);


    logic ex_is_load;
    logic mem_is_load;

    logic rs1_depends_on_ex_load;
    logic rs2_depends_on_ex_load;
    logic rs1_depends_on_mem_load;
    logic rs2_depends_on_mem_load;

    always @* begin
        ex_is_load =
            ex_valid_i &&
            ex_gpr_write_i &&
            ex_memory_valid_i &&
            !ex_memory_write_i &&
            (ex_rd_index_i != REG_X0);

        mem_is_load =
            mem_valid_i &&
            mem_gpr_write_i &&
            mem_memory_valid_i &&
            !mem_memory_write_i &&
            (mem_rd_index_i != REG_X0);

        rs1_depends_on_ex_load =
            id_use_rs1_i &&
            (id_rs1_index_i == ex_rd_index_i) &&
            ex_is_load;

        rs2_depends_on_ex_load =
            id_use_rs2_i &&
            (id_rs2_index_i == ex_rd_index_i) &&
            ex_is_load;

        rs1_depends_on_mem_load =
            id_use_rs1_i &&
            (id_rs1_index_i == mem_rd_index_i) &&
            mem_is_load;

        rs2_depends_on_mem_load =
            id_use_rs2_i &&
            (id_rs2_index_i == mem_rd_index_i) &&
            mem_is_load;

        load_use_stall_o =
            id_valid_i &&
            (
                rs1_depends_on_ex_load ||
                rs2_depends_on_ex_load ||
                rs1_depends_on_mem_load ||
                rs2_depends_on_mem_load
            );
    end

endmodule
