`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_uart_fifo.sv
// Module : rv32i_uart_fifo
//
// 16-Byte Synchronous Hardware FIFO for UART TX/RX Buffering.

module rv32i_uart_fifo #(
    parameter int unsigned DEPTH = 16,
    parameter int unsigned DATA_WIDTH = 8
)(
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic                    push_i,
    input  logic [DATA_WIDTH-1:0]   data_in_i,

    input  logic                    pop_i,
    output logic [DATA_WIDTH-1:0]   data_out_o,

    input  logic                    flush_i,

    output logic                    full_o,
    output logic                    empty_o,
    output logic [$clog2(DEPTH):0]  count_o
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] wr_ptr_q;
    logic [$clog2(DEPTH)-1:0] rd_ptr_q;
    logic [$clog2(DEPTH):0]   count_q;

    assign full_o      = (count_q == 5'(DEPTH));
    assign empty_o     = (count_q == 0);
    assign count_o     = count_q;
    assign data_out_o  = mem[rd_ptr_q];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q  <= '0;
        end else if (flush_i) begin
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q  <= '0;
        end else begin
            case ({push_i && !full_o, pop_i && !empty_o})
                2'b10: begin // Push only
                    mem[wr_ptr_q] <= data_in_i;
                    wr_ptr_q      <= wr_ptr_q + 1'b1;
                    count_q       <= count_q + 1'b1;
                end

                2'b01: begin // Pop only
                    rd_ptr_q <= rd_ptr_q + 1'b1;
                    count_q  <= count_q - 1'b1;
                end

                2'b11: begin // Push & Pop simultaneously
                    mem[wr_ptr_q] <= data_in_i;
                    wr_ptr_q      <= wr_ptr_q + 1'b1;
                    rd_ptr_q      <= rd_ptr_q + 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
