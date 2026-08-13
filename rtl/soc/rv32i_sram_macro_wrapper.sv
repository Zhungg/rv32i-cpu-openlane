`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_sram_macro_wrapper.sv
// Module : rv32i_sram_macro_wrapper
//
// Wishbone B4 Slave Adapter for Sky130 OpenRAM 2KB SRAM Hard Macro.

module rv32i_sram_macro_wrapper
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
(
    input  logic         clk_i,
    input  logic         rst_ni,

    // Wishbone Slave Interface
    input  wb_req_t      wb_req_i,
    output wb_rsp_t      wb_rsp_o
);

    wire sram_csb0   = !(wb_req_i.cyc && wb_req_i.stb);
    wire sram_web0   = !wb_req_i.we;
    wire [3:0] sram_wmask0 = wb_req_i.sel;
    wire [8:0] sram_addr0  = wb_req_i.adr[10:2]; // 512 words (2KB)
    wire [31:0] sram_din0  = wb_req_i.dat_w;
    wire [31:0] sram_dout0;

    // Instantiate OpenRAM 2KB Hard Macro
    sky130_sram_2kbyte_1rw1r_32x512_8 u_openram_2kb (
        .clk0   (clk_i),
        .csb0   (sram_csb0),
        .web0   (sram_web0),
        .wmask0 (sram_wmask0),
        .addr0  (sram_addr0),
        .din0   (sram_din0),
        .dout0  (sram_dout0),

        // Unused Port 1 tied off
        .clk1   (clk_i),
        .csb1   (1'b1),
        .addr1  (9'd0),
        .dout1  ()
    );

    logic wb_ack_q;

    // Synchronous Wishbone ACK response
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_ack_q <= 1'b0;
        end else begin
            wb_ack_q <= 1'b0;
            if (wb_req_i.cyc && wb_req_i.stb && !wb_ack_q) begin
                wb_ack_q <= 1'b1;
            end
        end
    end

    always_comb begin
        wb_rsp_o.ack   = wb_ack_q;
        wb_rsp_o.dat_r = sram_dout0;
    end

endmodule
