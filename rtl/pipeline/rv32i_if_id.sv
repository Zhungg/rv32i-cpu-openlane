`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pipeline/rv32i_if_id.sv
//
// IF/ID pipeline register.
//
// Protocol:
// - valid_i && ready_o transfers input payload into this stage.
// - valid_o && ready_i transfers the current payload downstream.
// - When downstream is not ready, valid and payload are held.
// - flush_i and kill_i invalidate the current stage entry.
// - Only the valid bit is reset; the payload is intentionally not reset.
//
// Priority:
//     asynchronous reset
//     > flush/kill
//     > valid-ready transfer
//     > hold

module rv32i_if_id (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    input  logic                              flush_i,
    input  logic                              kill_i,

    input  logic                              valid_i,
    output logic                              ready_o,
    input  rv32i_types_pkg::if_id_payload_t    payload_i,

    output logic                              valid_o,
    input  logic                              ready_i,
    output rv32i_types_pkg::if_id_payload_t    payload_o
);

    import rv32i_types_pkg::*;

    logic              valid_q;
    if_id_payload_t     payload_q;

    // The stage can accept a new payload when it is empty, or when its
    // current payload will be consumed by the downstream stage.
    always_comb begin
        ready_o = !valid_q || ready_i;
    end

    assign valid_o   = valid_q;
    assign payload_o = payload_q;

    // Reset, flush and kill affect only the architectural validity state.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_q <= 1'b0;
        end
        else if (flush_i || kill_i) begin
            valid_q <= 1'b0;
        end
        else if (ready_o) begin
            valid_q <= valid_i;
        end
    end

    // The payload is architecturally meaningful only while valid_q is high.
    //
    // Payload capture intentionally does not depend on flush_i or kill_i.
    // A payload captured during a flush cycle is invalidated by valid_q and
    // therefore cannot propagate as an architectural pipeline transaction.
    //
    // Keeping flush/kill out of this enable cone prevents the late redirect
    // path from driving the D-input hold/load muxes of the full IF/ID payload.
    always_ff @(posedge clk_i) begin
        if (ready_o && valid_i) begin
            payload_q <= payload_i;
        end
    end

endmodule
