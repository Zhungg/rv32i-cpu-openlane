`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// ALU-operation decoder for RV32I OP and OP-IMM instructions.

import rv32i_encoding_pkg::*;
import rv32i_types_pkg::*;

module rv32i_alu_decoder (
    input  rv32i_encoding_pkg::opcode_t opcode_i,
    input  logic [2:0]                  funct3_i,
    input  logic [6:0]                  funct7_i,

    output rv32i_types_pkg::alu_op_e    alu_op_o,
    output logic                        illegal_o
);


    always_comb begin
        alu_op_o  = ALU_ADD;
        illegal_o = 1'b0;

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
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_SLL;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_SLT: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_SLT;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_SLTU: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_SLTU;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_XOR: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_XOR;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_SRL_SRA: begin
                        case (funct7_i)
                            FUNCT7_BASE:    alu_op_o = ALU_SRL;
                            FUNCT7_SUB_SRA: alu_op_o = ALU_SRA;
                            default:        illegal_o = 1'b1;
                        endcase
                    end

                    FUNCT3_OR: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_OR;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_AND: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_AND;
                        else
                            illegal_o = 1'b1;
                    end

                    default: illegal_o = 1'b1;
                endcase
            end

            OPCODE_OP_IMM: begin
                case (funct3_i)
                    FUNCT3_ADD_SUB: alu_op_o = ALU_ADD;
                    FUNCT3_SLT:     alu_op_o = ALU_SLT;
                    FUNCT3_SLTU:    alu_op_o = ALU_SLTU;
                    FUNCT3_XOR:     alu_op_o = ALU_XOR;
                    FUNCT3_OR:      alu_op_o = ALU_OR;
                    FUNCT3_AND:     alu_op_o = ALU_AND;

                    FUNCT3_SLL: begin
                        if (funct7_i == FUNCT7_BASE)
                            alu_op_o = ALU_SLL;
                        else
                            illegal_o = 1'b1;
                    end

                    FUNCT3_SRL_SRA: begin
                        case (funct7_i)
                            FUNCT7_BASE:    alu_op_o = ALU_SRL;
                            FUNCT7_SUB_SRA: alu_op_o = ALU_SRA;
                            default:        illegal_o = 1'b1;
                        endcase
                    end

                    default: illegal_o = 1'b1;
                endcase
            end

            default: begin
                alu_op_o  = ALU_ADD;
                illegal_o = 1'b1;
            end
        endcase
    end

endmodule
