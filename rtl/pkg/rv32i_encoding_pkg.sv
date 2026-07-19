`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32i_encoding_pkg.sv
//
// RV32I, Zicsr, Zifencei and Machine-mode instruction encodings.

package rv32i_encoding_pkg;

    typedef logic [6:0] opcode_t;

    typedef enum logic [2:0] {
        INSN_FORMAT_R,
        INSN_FORMAT_I,
        INSN_FORMAT_S,
        INSN_FORMAT_B,
        INSN_FORMAT_U,
        INSN_FORMAT_J,
        INSN_FORMAT_NONE
    } insn_format_e;

    // ---------------------------------------------------------------------
    // Major opcodes
    // ---------------------------------------------------------------------

    localparam opcode_t OPCODE_LOAD     = 7'b0000011;
    localparam opcode_t OPCODE_MISC_MEM = 7'b0001111;
    localparam opcode_t OPCODE_OP_IMM   = 7'b0010011;
    localparam opcode_t OPCODE_AUIPC    = 7'b0010111;
    localparam opcode_t OPCODE_STORE    = 7'b0100011;
    localparam opcode_t OPCODE_OP       = 7'b0110011;
    localparam opcode_t OPCODE_LUI      = 7'b0110111;
    localparam opcode_t OPCODE_BRANCH   = 7'b1100011;
    localparam opcode_t OPCODE_JALR     = 7'b1100111;
    localparam opcode_t OPCODE_JAL      = 7'b1101111;
    localparam opcode_t OPCODE_SYSTEM   = 7'b1110011;

    // ---------------------------------------------------------------------
    // OP / OP-IMM funct3 values
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_ADD_SUB = 3'b000;
    localparam logic [2:0] FUNCT3_SLL     = 3'b001;
    localparam logic [2:0] FUNCT3_SLT     = 3'b010;
    localparam logic [2:0] FUNCT3_SLTU    = 3'b011;
    localparam logic [2:0] FUNCT3_XOR     = 3'b100;
    localparam logic [2:0] FUNCT3_SRL_SRA = 3'b101;
    localparam logic [2:0] FUNCT3_OR      = 3'b110;
    localparam logic [2:0] FUNCT3_AND     = 3'b111;

    localparam logic [6:0] FUNCT7_BASE    = 7'b0000000;
    localparam logic [6:0] FUNCT7_SUB_SRA = 7'b0100000;

    // ---------------------------------------------------------------------
    // Branch funct3 values
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_BEQ  = 3'b000;
    localparam logic [2:0] FUNCT3_BNE  = 3'b001;
    localparam logic [2:0] FUNCT3_BLT  = 3'b100;
    localparam logic [2:0] FUNCT3_BGE  = 3'b101;
    localparam logic [2:0] FUNCT3_BLTU = 3'b110;
    localparam logic [2:0] FUNCT3_BGEU = 3'b111;

    // ---------------------------------------------------------------------
    // Load funct3 values
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_LB  = 3'b000;
    localparam logic [2:0] FUNCT3_LH  = 3'b001;
    localparam logic [2:0] FUNCT3_LW  = 3'b010;
    localparam logic [2:0] FUNCT3_LBU = 3'b100;
    localparam logic [2:0] FUNCT3_LHU = 3'b101;

    // ---------------------------------------------------------------------
    // Store funct3 values
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_SB = 3'b000;
    localparam logic [2:0] FUNCT3_SH = 3'b001;
    localparam logic [2:0] FUNCT3_SW = 3'b010;

    // ---------------------------------------------------------------------
    // Memory ordering
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_FENCE   = 3'b000;
    localparam logic [2:0] FUNCT3_FENCE_I = 3'b001;

    // ---------------------------------------------------------------------
    // SYSTEM / CSR funct3 values
    // ---------------------------------------------------------------------

    localparam logic [2:0] FUNCT3_PRIV   = 3'b000;
    localparam logic [2:0] FUNCT3_CSRRW  = 3'b001;
    localparam logic [2:0] FUNCT3_CSRRS  = 3'b010;
    localparam logic [2:0] FUNCT3_CSRRC  = 3'b011;
    localparam logic [2:0] FUNCT3_CSRRWI = 3'b101;
    localparam logic [2:0] FUNCT3_CSRRSI = 3'b110;
    localparam logic [2:0] FUNCT3_CSRRCI = 3'b111;

    // SYSTEM instruction immediate fields: instruction[31:20].
    localparam logic [11:0] SYSTEM_ECALL  = 12'h000;
    localparam logic [11:0] SYSTEM_EBREAK = 12'h001;
    localparam logic [11:0] SYSTEM_WFI    = 12'h105;
    localparam logic [11:0] SYSTEM_MRET   = 12'h302;

endpackage
