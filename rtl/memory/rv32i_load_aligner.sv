`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I load-data aligner for a 32-bit little-endian data bus.
//
// This

import rv32i_types_pkg::*;

module extracts byte/halfword/word data and performs sign or zero
// extension according to the decoded load instruction.

module rv32i_load_aligner (
    input  rv32i_pkg::addr_t           address_i,
    input  rv32i_pkg::xlen_t           read_data_i,
    input  rv32i_types_pkg::mem_size_e size_i,
    input  logic                       unsigned_load_i,

    output rv32i_pkg::xlen_t           load_data_o
);


    logic [7:0]  selected_byte;
    logic [15:0] selected_halfword;

    always @* begin
        selected_byte = 8'b0;

        case (address_i[1:0])
            2'b00: selected_byte = read_data_i[7:0];
            2'b01: selected_byte = read_data_i[15:8];
            2'b10: selected_byte = read_data_i[23:16];
            2'b11: selected_byte = read_data_i[31:24];
            default: selected_byte = 8'b0;
        endcase
    end

    always @* begin
        selected_halfword = 16'b0;

        if (address_i[1]) begin
            selected_halfword = read_data_i[31:16];
        end
        else begin
            selected_halfword = read_data_i[15:0];
        end
    end

    always @* begin
        load_data_o = '0;

        case (size_i)
            MEM_SIZE_BYTE: begin
                if (unsigned_load_i) begin
                    load_data_o = {
                        24'b0,
                        selected_byte
                    };
                end
                else begin
                    load_data_o = {
                        {24{selected_byte[7]}},
                        selected_byte
                    };
                end
            end

            MEM_SIZE_HALF: begin
                if (unsigned_load_i) begin
                    load_data_o = {
                        16'b0,
                        selected_halfword
                    };
                end
                else begin
                    load_data_o = {
                        {16{selected_halfword[15]}},
                        selected_halfword
                    };
                end
            end

            MEM_SIZE_WORD: begin
                load_data_o = read_data_i;
            end

            default: begin
                load_data_o = '0;
            end
        endcase
    end

endmodule
