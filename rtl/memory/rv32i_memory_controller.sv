`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// One-outstanding data-memory transaction controller.
//
// This

import rv32i_types_pkg::*;

module does not perform alignment or exception classification.
// It only transfers one request to the external D-memory interface and
// waits for the matching response.
//
// Contract:
// - valid_i && ready_o accepts one transaction.
// - dmem_req_valid_o && dmem_req_ready_i issues that transaction.
// - dmem_rsp_valid_i && dmem_rsp_ready_o completes the transaction.
// - complete_o is a one-cycle pulse on response acceptance.

module rv32i_memory_controller (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    input  logic                              valid_i,
    output logic                              ready_o,
    input  rv32i_types_pkg::dmem_request_t    request_i,

    output logic                              complete_o,
    output rv32i_types_pkg::dmem_response_t   response_o,

    output logic                              dmem_req_valid_o,
    input  logic                              dmem_req_ready_i,
    output rv32i_types_pkg::dmem_request_t    dmem_req_o,

    input  logic                              dmem_rsp_valid_i,
    output logic                              dmem_rsp_ready_o,
    input  rv32i_types_pkg::dmem_response_t   dmem_rsp_i
);


    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_WAIT_RESPONSE
    } state_e;

    state_e state_q;
    state_e state_d;

    logic request_fire;
    logic response_fire;

    assign request_fire =
        dmem_req_valid_o &&
        dmem_req_ready_i;

    assign response_fire =
        dmem_rsp_valid_i &&
        dmem_rsp_ready_o;

    always_comb begin
        state_d = state_q;

        case (state_q)
            STATE_IDLE: begin
                if (request_fire) begin
                    state_d = STATE_WAIT_RESPONSE;
                end
            end

            STATE_WAIT_RESPONSE: begin
                if (response_fire) begin
                    state_d = STATE_IDLE;
                end
            end

            default: begin
                state_d = STATE_IDLE;
            end
        endcase
    end

    always_comb begin
        dmem_req_valid_o = 1'b0;
        dmem_req_o       = request_i;

        dmem_rsp_ready_o = 1'b0;

        complete_o = 1'b0;
        response_o = dmem_rsp_i;

        ready_o = 1'b0;

        case (state_q)
            STATE_IDLE: begin
                dmem_req_valid_o = valid_i;
                ready_o          = !valid_i || dmem_req_ready_i;
            end

            STATE_WAIT_RESPONSE: begin
                dmem_rsp_ready_o = 1'b1;
                complete_o       = response_fire;
                response_o       = dmem_rsp_i;
                ready_o          = 1'b0;
            end

            default: begin
                ready_o = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= STATE_IDLE;
        end
        else begin
            state_q <= state_d;
        end
    end

endmodule
