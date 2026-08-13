`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_imem_wrapper.sv
// Module : rv32i_imem_wrapper
//
// 1-cycle latency Instruction Memory (ROM/RAM) wrapper for rv32i_soc.

module rv32i_imem_wrapper
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
#(
    parameter int unsigned MEM_SIZE_BYTES = 65536, // 64 KB
    parameter              INIT_HEX_FILE  = ""
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // Core Instruction Memory Interface
    input  logic                             imem_req_valid_i,
    output logic                             imem_req_ready_o,
    input  imem_request_t                    imem_req_i,

    output logic                             imem_rsp_valid_o,
    input  logic                             imem_rsp_ready_i,
    output imem_response_t                   imem_rsp_o
);

    localparam int unsigned WORDS = MEM_SIZE_BYTES / 4;
    localparam int unsigned ADDR_BITS = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];

    logic          response_pending_q;
    imem_request_t pending_req_q;

    // Optional Hex initialization for simulation / FPGA
    initial begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] = 32'h0000_0013; // NOP (addi x0, x0, 0)
        end
        if (INIT_HEX_FILE != "") begin
            $readmemh(INIT_HEX_FILE, mem);
        end
    end

    // Handshake
    assign imem_req_ready_o = !response_pending_q;
    assign imem_rsp_valid_o = response_pending_q;

    wire [ADDR_BITS-1:0] word_idx = pending_req_q.address[ADDR_BITS+1:2];

    always_comb begin
        imem_rsp_o             = '0;
        imem_rsp_o.instruction = mem[word_idx];
        imem_rsp_o.error       = 1'b0;
        imem_rsp_o.epoch       = pending_req_q.epoch;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            response_pending_q <= 1'b0;
            pending_req_q      <= '0;
        end else begin
            if (imem_rsp_valid_o && imem_rsp_ready_i) begin
                response_pending_q <= 1'b0;
            end

            if (imem_req_valid_i && imem_req_ready_o) begin
                response_pending_q <= 1'b1;
                pending_req_q      <= imem_req_i;
            end
        end
    end

endmodule
