`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_dmem_wrapper.sv
// Module : rv32i_dmem_wrapper
//
// 1-cycle latency Data Memory (SRAM/RAM) wrapper with byte strobe support for rv32i_soc.

module rv32i_dmem_wrapper
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
#(
    parameter int unsigned MEM_SIZE_BYTES = 65536, // 64 KB
    parameter              INIT_HEX_FILE  = ""
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // Data Memory Interface
    input  logic                             dmem_req_valid_i,
    output logic                             dmem_req_ready_o,
    input  dmem_request_t                    dmem_req_i,

    output logic                             dmem_rsp_valid_o,
    input  logic                             dmem_rsp_ready_i,
    output dmem_response_t                   dmem_rsp_o
);

    localparam int unsigned WORDS = MEM_SIZE_BYTES / 4;
    localparam int unsigned ADDR_BITS = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

    logic          response_pending_q;
    dmem_request_t pending_req_q;

    // Optional Hex initialization
    initial begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] = 32'h0000_0000;
        end
        if (INIT_HEX_FILE != "") begin
            $readmemh(INIT_HEX_FILE, mem);
        end
    end

    assign dmem_req_ready_o = !response_pending_q;
    assign dmem_rsp_valid_o = response_pending_q;

    wire [ADDR_BITS-1:0] req_word_idx     = dmem_req_i.address[ADDR_BITS+1:2];
    wire [ADDR_BITS-1:0] pending_word_idx = pending_req_q.address[ADDR_BITS+1:2];

    always_comb begin
        dmem_rsp_o           = '0;
        dmem_rsp_o.read_data = mem[pending_word_idx];
        dmem_rsp_o.error     = 1'b0;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            response_pending_q <= 1'b0;
            pending_req_q      <= '0;
        end else begin
            // Synchronous write
            if (dmem_req_valid_i && dmem_req_ready_o && dmem_req_i.write) begin
                if (dmem_req_i.write_strobe[0]) mem[req_word_idx][7:0]   <= dmem_req_i.write_data[7:0];
                if (dmem_req_i.write_strobe[1]) mem[req_word_idx][15:8]  <= dmem_req_i.write_data[15:8];
                if (dmem_req_i.write_strobe[2]) mem[req_word_idx][23:16] <= dmem_req_i.write_data[23:16];
                if (dmem_req_i.write_strobe[3]) mem[req_word_idx][31:24] <= dmem_req_i.write_data[31:24];
            end

            // Response pipeline
            if (dmem_rsp_valid_o && dmem_rsp_ready_i) begin
                response_pending_q <= 1'b0;
            end

            if (dmem_req_valid_i && dmem_req_ready_o) begin
                response_pending_q <= 1'b1;
                pending_req_q      <= dmem_req_i;
            end
        end
    end

endmodule
