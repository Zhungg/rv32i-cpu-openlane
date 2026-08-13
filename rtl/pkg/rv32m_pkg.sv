`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32m_pkg.sv
//
// RV32M standard Hardware Multiply & Divide Extension encodings and types.

package rv32m_pkg;

    localparam logic [6:0] FUNCT7_M_EXT = 7'b0000001;

    localparam logic [2:0] FUNCT3_MUL    = 3'b000;
    localparam logic [2:0] FUNCT3_MULH   = 3'b001;
    localparam logic [2:0] FUNCT3_MULHSU = 3'b010;
    localparam logic [2:0] FUNCT3_MULHU  = 3'b011;
    localparam logic [2:0] FUNCT3_DIV    = 3'b100;
    localparam logic [2:0] FUNCT3_DIVU   = 3'b101;
    localparam logic [2:0] FUNCT3_REM    = 3'b110;
    localparam logic [2:0] FUNCT3_REMU   = 3'b111;

    typedef enum logic [3:0] {
        MDU_NONE   = 4'd0,
        MDU_MUL    = 4'd1,
        MDU_MULH   = 4'd2,
        MDU_MULHSU = 4'd3,
        MDU_MULHU  = 4'd4,
        MDU_DIV    = 4'd5,
        MDU_DIVU   = 4'd6,
        MDU_REM    = 4'd7,
        MDU_REMU   = 4'd8
    } mdu_op_e;

endpackage
