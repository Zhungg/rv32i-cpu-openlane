`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I store-data aligner for a 32-bit little-endian data bus.
//
// This module does not check alignment. Misalignment is detected by
// rv32i_misaligned_detect before the memory request is issued.

module rv32i_store_aligner (
    input  rv32i_pkg::addr_t           address_i,
    input  rv32i_pkg::xlen_t           store_data_i,
    input  rv32i_types_pkg::mem_size_e size_i,

    output rv32i_pkg::xlen_t           aligned_write_data_o,
    output logic [3:0]                 write_strobe_o
);

    import rv32i_types_pkg::*;

    always @* begin
        aligned_write_data_o = '0;
        write_strobe_o       = 4'b0000;

        case (size_i)
            MEM_SIZE_BYTE: begin
                case (address_i[1:0])
                    2'b00: begin
                        aligned_write_data_o = {
                            24'b0,
                            store_data_i[7:0]
                        };
                        write_strobe_o = 4'b0001;
                    end

                    2'b01: begin
                        aligned_write_data_o = {
                            16'b0,
                            store_data_i[7:0],
                            8'b0
                        };
                        write_strobe_o = 4'b0010;
                    end

                    2'b10: begin
                        aligned_write_data_o = {
                            8'b0,
                            store_data_i[7:0],
                            16'b0
                        };
                        write_strobe_o = 4'b0100;
                    end

                    2'b11: begin
                        aligned_write_data_o = {
                            store_data_i[7:0],
                            24'b0
                        };
                        write_strobe_o = 4'b1000;
                    end

                    default: begin
                        aligned_write_data_o = '0;
                        write_strobe_o       = 4'b0000;
                    end
                endcase
            end

            MEM_SIZE_HALF: begin
                if (address_i[1]) begin
                    aligned_write_data_o = {
                        store_data_i[15:0],
                        16'b0
                    };
                    write_strobe_o = 4'b1100;
                end
                else begin
                    aligned_write_data_o = {
                        16'b0,
                        store_data_i[15:0]
                    };
                    write_strobe_o = 4'b0011;
                end
            end

            MEM_SIZE_WORD: begin
                aligned_write_data_o = store_data_i;
                write_strobe_o       = 4'b1111;
            end

            default: begin
                aligned_write_data_o = '0;
                write_strobe_o       = 4'b0000;
            end
        endcase
    end

endmodule
