`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Global History Register for branch prediction.
//
// History convention:
//   newest branch outcome shifts into bit[0].
//   older history moves toward MSB.

module rv32i_ghr #(
    parameter int unsigned WIDTH = 8
) (
    input  logic             clk_i,
    input  logic             rst_ni,

    input  logic             clear_i,

    input  logic             update_valid_i,
    input  logic             update_taken_i,

    output logic [WIDTH-1:0] history_o
);

    logic [WIDTH-1:0] history_q;

    assign history_o = history_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            history_q <= '0;
        end
        else if (clear_i) begin
            history_q <= '0;
        end
        else if (update_valid_i) begin
            history_q <= {
                history_q[WIDTH-2:0],
                update_taken_i
            };
        end
    end

endmodule
