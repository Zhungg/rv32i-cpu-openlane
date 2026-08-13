`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/decode/rv32m_alu_decoder.sv
//
// ALU and MDU operation decoder for RV32I + RV32M extension.

module rv32m_alu_decoder
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32m_pkg::*;
(
    input  opcode_t opcode_i,
    input  logic [2:0] funct3_i,
    input  logic [6:0] funct7_i,

    output alu_op_e    alu_op_o,
    output mdu_op_e    mdu_op_o,
    output logic       illegal_o
);

    always_comb begin
        alu_op_o  = ALU_ADD;
        mdu_op_o  = MDU_NONE;
        illegal_o = 1'b0;

        if (opcode_i == OPCODE_OP && funct7_i == FUNCT7_M_EXT) begin
            case (funct3_i)
                FUNCT3_MUL:    mdu_op_o = MDU_MUL;
                FUNCT3_MULH:   mdu_op_o = MDU_MULH;
                FUNCT3_MULHSU: mdu_op_o = MDU_MULHSU;
                FUNCT3_MULHU:  mdu_op_o = MDU_MULHU;
                FUNCT3_DIV:    mdu_op_o = MDU_DIV;
                FUNCT3_DIVU:   mdu_op_o = MDU_DIVU;
                FUNCT3_REM:    mdu_op_o = MDU_REM;
                FUNCT3_REMU:   mdu_op_o = MDU_REMU;
                default:       illegal_o = 1'b1;
            endcase
        end else begin
            // Base RV32I ALU decode
            case (opcode_i)
                OPCODE_OP: begin
                    case (funct3_i)
                        FUNCT3_ADD_SUB: begin
                            case (funct7_i)
                                FUNCT7_BASE:    alu_op_o = ALU_ADD;
                                FUNCT7_SUB_SRA: alu_op_o = ALU_SUB;
                                default:        illegal_o = 1'b1;
                            endcase
                        end
                        FUNCT3_SLL: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_SLL;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_SLT: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_SLT;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_SLTU: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_SLTU;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_XOR: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_XOR;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_SRL_SRA: begin
                            case (funct7_i)
                                FUNCT7_BASE:    alu_op_o = ALU_SRL;
                                FUNCT7_SUB_SRA: alu_op_o = ALU_SRA;
                                default:        illegal_o = 1'b1;
                            endcase
                        end
                        FUNCT3_OR: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_OR;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_AND: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_AND;
                            else illegal_o = 1'b1;
                        end
                        default: illegal_o = 1'b1;
                    endcase
                end

                OPCODE_OP_IMM: begin
                    case (funct3_i)
                        FUNCT3_ADD_SUB: alu_op_o = ALU_ADD;
                        FUNCT3_SLL: begin
                            if (funct7_i == FUNCT7_BASE) alu_op_o = ALU_SLL;
                            else illegal_o = 1'b1;
                        end
                        FUNCT3_SLT:     alu_op_o = ALU_SLT;
                        FUNCT3_SLTU:    alu_op_o = ALU_SLTU;
                        FUNCT3_XOR:     alu_op_o = ALU_XOR;
                        FUNCT3_SRL_SRA: begin
                            case (funct7_i)
                                FUNCT7_BASE:    alu_op_o = ALU_SRL;
                                FUNCT7_SUB_SRA: alu_op_o = ALU_SRA;
                                default:        illegal_o = 1'b1;
                            endcase
                        end
                        FUNCT3_OR:      alu_op_o = ALU_OR;
                        FUNCT3_AND:     alu_op_o = ALU_AND;
                        default:        illegal_o = 1'b1;
                    endcase
                end

                default: illegal_o = 1'b1;
            endcase
        end
    end

endmodule
