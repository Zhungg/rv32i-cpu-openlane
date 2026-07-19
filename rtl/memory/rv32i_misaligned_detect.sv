`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I load/store address-alignment checker.
//
// RV32I baseline policy in this project:
// - Byte access: always aligned.
// - Halfword access: address[0] must be zero.
// - Word access: address[1:0] must be zero.
//
// Misaligned accesses are converted into precise traps by the LSU/MEM
// stage in Step 6C.

import rv32i_types_pkg::*;

module rv32i_misaligned_detect (
    input  rv32i_pkg::addr_t          address_i,
    input  rv32i_types_pkg::mem_size_e size_i,

    output logic                      misaligned_o
);


    always @* begin
        misaligned_o = 1'b0;

        case (size_i)
            MEM_SIZE_BYTE: begin
                misaligned_o = 1'b0;
            end

            MEM_SIZE_HALF: begin
                misaligned_o = address_i[0];
            end

            MEM_SIZE_WORD: begin
                misaligned_o = |address_i[1:0];
            end

            default: begin
                misaligned_o = 1'b1;
            end
        endcase
    end

endmodule
