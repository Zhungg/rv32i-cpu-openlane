`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/memory/sky130_sram_2kbyte_1rw1r_32x512_8.sv
// Module : sky130_sram_2kbyte_1rw1r_32x512_8
//
// Standard OpenRAM 2KB SRAM Hard Macro (512 words x 32 bits, 1RW1R) for SkyWater 130nm.
// Features 1 Read/Write Port and 1 Read-Only Port with byte-write masking.

module sky130_sram_2kbyte_1rw1r_32x512_8 (
    // Port 0: Read / Write Port
    input  logic        clk0,
    input  logic        csb0,       // Chip select (active-low)
    input  logic        web0,       // Write enable (active-low)
    input  logic [3:0]  wmask0,     // Byte write mask
    input  logic [8:0]  addr0,      // 9-bit address (512 words)
    input  logic [31:0] din0,       // Data input
    output logic [31:0] dout0,      // Data output

    // Port 1: Read-Only Port
    input  logic        clk1,
    input  logic        csb1,       // Chip select (active-low)
    input  logic [8:0]  addr1,      // 9-bit address
    output logic [31:0] dout1       // Data output
);

    // Memory array: 512 x 32-bit words
    reg [31:0] mem [0:511];

    // Port 0 synchronous operation
    always_ff @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin
                // Byte-masked write
                if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
                if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
                if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
                if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
            end
            dout0 <= mem[addr0];
        end
    end

    // Port 1 synchronous read
    always_ff @(posedge clk1) begin
        if (!csb1) begin
            dout1 <= mem[addr1];
        end
    end

endmodule
