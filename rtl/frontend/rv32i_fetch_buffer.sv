`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// One-entry frontend fetch buffer.
//
// Protocol:
// - valid_i && ready_o pushes a fetched instruction.
// - valid_o && ready_i pops the current instruction.
// - Push and pop may occur in the same cycle.
// - flush_i invalidates a wrong-path buffered instruction.
// - Only valid_q is reset; payload_q is intentionally not reset.

import rv32i_types_pkg::*;

module rv32i_fetch_buffer (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    input  logic                              flush_i,

    input  logic                              valid_i,
    output logic                              ready_o,
    input  rv32i_types_pkg::if_id_payload_t   payload_i,

    output logic                              valid_o,
    input  logic                              ready_i,
    output rv32i_types_pkg::if_id_payload_t   payload_o
);


    logic           valid_q;
    if_id_payload_t payload_q;

    always_comb begin
        ready_o = !valid_q || ready_i;
    end

    assign valid_o   = valid_q;
    assign payload_o = payload_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_q <= 1'b0;
        end
        else if (flush_i) begin
            valid_q <= 1'b0;
        end
        else if (ready_o) begin
            valid_q <= valid_i;

            if (valid_i) begin
                payload_q <= payload_i;
            end
        end
    end

endmodule
