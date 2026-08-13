`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_dmem_wb.sv
// Module : rv32i_dmem_wb
//
// Wishbone B4 Slave interface for Data Memory (SRAM) with byte strobe support.

module rv32i_dmem_wb
    import rv32i_wishbone_pkg::*;
#(
    parameter int unsigned MEM_SIZE_BYTES = 65536,
    parameter              INIT_HEX_FILE  = ""
) (
    input  logic    clk_i,
    input  logic    rst_ni,

    // Wishbone Slave
    input  wb_req_t wb_req_i,
    output wb_rsp_t wb_rsp_o
);

    localparam int unsigned WORDS = MEM_SIZE_BYTES / 4;
    localparam int unsigned ADDR_BITS = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];
    wire [ADDR_BITS-1:0] word_idx = wb_req_i.adr[ADDR_BITS+1:2];

    initial begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] = 32'h0000_0000;
        end
        if (INIT_HEX_FILE != "") begin
            $readmemh(INIT_HEX_FILE, mem);
        end
    end

    // 1-cycle pipeline response
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_rsp_o <= WB_RSP_IDLE;
        end else begin
            wb_rsp_o.ack <= 1'b0;
            wb_rsp_o.err <= 1'b0;

            if (wb_req_i.cyc && wb_req_i.stb && !wb_rsp_o.ack) begin
                wb_rsp_o.ack <= 1'b1;
                wb_rsp_o.err <= 1'b0;

                if (wb_req_i.we) begin
                    if (wb_req_i.sel[0]) mem[word_idx][7:0]   <= wb_req_i.dat_w[7:0];
                    if (wb_req_i.sel[1]) mem[word_idx][15:8]  <= wb_req_i.dat_w[15:8];
                    if (wb_req_i.sel[2]) mem[word_idx][23:16] <= wb_req_i.dat_w[23:16];
                    if (wb_req_i.sel[3]) mem[word_idx][31:24] <= wb_req_i.dat_w[31:24];
                end else begin
                    wb_rsp_o.dat_r <= mem[word_idx];
                end
            end
        end
    end

endmodule
