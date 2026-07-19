`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I instruction-encoding legality checker.
//
// This module checks encoding legality only. CSR existence, privilege and
// read-only access checks are handled by the CSR subsystem at execution.

module rv32i_illegal_detect (
    input  rv32i_pkg::insn_t instruction_i,
    output logic             illegal_o
);

    import rv32i_encoding_pkg::*;

    opcode_t   opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1;
    logic [4:0] rd;
    logic [11:0] system_code;


    rv32i_types_pkg::alu_op_e unused_alu_op;
    logic                     alu_illegal;

    assign opcode      = instruction_i[6:0];
    assign rd          = instruction_i[11:7];
    assign funct3      = instruction_i[14:12];
    assign rs1         = instruction_i[19:15];
    assign funct7      = instruction_i[31:25];
    assign system_code = instruction_i[31:20];

    rv32i_alu_decoder u_alu_decoder (
        .opcode_i  (opcode),
        .funct3_i  (funct3),
        .funct7_i  (funct7),
        .alu_op_o  (unused_alu_op),
        .illegal_o (alu_illegal)
    );

    always_comb begin
        illegal_o = 1'b1;

        case (opcode)
            OPCODE_LUI,
            OPCODE_AUIPC,
            OPCODE_JAL: begin
                illegal_o = 1'b0;
            end

            OPCODE_JALR: begin
                illegal_o = (funct3 != 3'b000);
            end

            OPCODE_BRANCH: begin
                case (funct3)
                    FUNCT3_BEQ,
                    FUNCT3_BNE,
                    FUNCT3_BLT,
                    FUNCT3_BGE,
                    FUNCT3_BLTU,
                    FUNCT3_BGEU: illegal_o = 1'b0;

                    default: illegal_o = 1'b1;
                endcase
            end

            OPCODE_LOAD: begin
                case (funct3)
                    FUNCT3_LB,
                    FUNCT3_LH,
                    FUNCT3_LW,
                    FUNCT3_LBU,
                    FUNCT3_LHU: illegal_o = 1'b0;

                    default: illegal_o = 1'b1;
                endcase
            end

            OPCODE_STORE: begin
                case (funct3)
                    FUNCT3_SB,
                    FUNCT3_SH,
                    FUNCT3_SW: illegal_o = 1'b0;

                    default: illegal_o = 1'b1;
                endcase
            end

            OPCODE_OP,
            OPCODE_OP_IMM: begin
                illegal_o = alu_illegal;
            end

            OPCODE_MISC_MEM: begin
                case (funct3)
                    FUNCT3_FENCE,
                    FUNCT3_FENCE_I: illegal_o = 1'b0;

                    default: illegal_o = 1'b1;
                endcase
            end

            OPCODE_SYSTEM: begin
                case (funct3)
                    FUNCT3_PRIV: begin
                        if ((rs1 == 5'd0) && (rd == 5'd0)) begin
                            case (system_code)
                                SYSTEM_ECALL,
                                SYSTEM_EBREAK,
                                SYSTEM_WFI,
                                SYSTEM_MRET: illegal_o = 1'b0;

                                default: illegal_o = 1'b1;
                            endcase
                        end
                        else begin
                            illegal_o = 1'b1;
                        end
                    end

                    FUNCT3_CSRRW,
                    FUNCT3_CSRRS,
                    FUNCT3_CSRRC,
                    FUNCT3_CSRRWI,
                    FUNCT3_CSRRSI,
                    FUNCT3_CSRRCI: begin
                        illegal_o = 1'b0;
                    end

                    default: illegal_o = 1'b1;
                endcase
            end

            default: illegal_o = 1'b1;
        endcase
    end

endmodule
