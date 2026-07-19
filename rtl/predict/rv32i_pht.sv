`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Pattern History Table with 2-bit saturating counters.
//
// Counter encoding:
//   00 strongly not taken
//   01 weakly not taken
//   10 weakly taken
//   11 strongly taken
//
// Prediction is counter[1].

module rv32i_pht #(
    parameter int unsigned INDEX_WIDTH = 8
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,

    input  logic [INDEX_WIDTH-1:0]   read_index_i,
    output logic                     predict_taken_o,
    output logic [1:0]               read_counter_o,

    input  logic                     update_valid_i,
    input  logic [INDEX_WIDTH-1:0]   update_index_i,
    input  logic                     update_taken_i
);

    localparam int unsigned ENTRY_COUNT = 1 << INDEX_WIDTH;

    logic [1:0] table_q [0:ENTRY_COUNT-1];

    integer reset_index;

    always @* begin
        read_counter_o   = table_q[read_index_i];
        predict_taken_o  = table_q[read_index_i][1];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (reset_index = 0; reset_index < ENTRY_COUNT; reset_index++) begin
                table_q[reset_index] <= 2'b01; // weakly not taken
            end
        end
        else if (update_valid_i) begin
            if (update_taken_i) begin
                if (table_q[update_index_i] != 2'b11) begin
                    table_q[update_index_i] <= table_q[update_index_i] + 2'b01;
                end
            end
            else begin
                if (table_q[update_index_i] != 2'b00) begin
                    table_q[update_index_i] <= table_q[update_index_i] - 2'b01;
                end
            end
        end
    end

endmodule
