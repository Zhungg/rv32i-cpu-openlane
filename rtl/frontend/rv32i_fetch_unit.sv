`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I fetch unit with branch prediction.
//
// Step 7B scope:
// - Integrate branch predictor into fetch PC selection.
// - Carry prediction metadata with each fetched instruction.
// - Update predictor from resolved branch/jump feedback.
// - Redirect input still has highest priority.

import rv32i_pkg::*;
import rv32i_types_pkg::*;

module rv32i_fetch_unit #(
    parameter logic [31:0] RESET_VECTOR    = 32'h0000_0000,
    parameter int unsigned BTB_INDEX_WIDTH = 6
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic                         redirect_valid_i,
    input  rv32i_pkg::addr_t             redirect_pc_i,

    input  logic                         predictor_update_valid_i,
    input  rv32i_pkg::addr_t             predictor_update_pc_i,
    input  logic                         predictor_update_taken_i,
    input  rv32i_pkg::addr_t             predictor_update_target_i,
    input  logic [rv32i_types_pkg::PHT_INDEX_WIDTH-1:0]
                                           predictor_update_pht_index_i,

    output logic                         imem_req_valid_o,
    input  logic                         imem_req_ready_i,
    output rv32i_types_pkg::imem_request_t
                                           imem_req_o,

    input  logic                         imem_rsp_valid_i,
    output logic                         imem_rsp_ready_o,
    input  rv32i_types_pkg::imem_response_t
                                           imem_rsp_i,

    output logic                         fetch_valid_o,
    input  logic                         fetch_ready_i,
    output rv32i_types_pkg::if_id_payload_t
                                           fetch_payload_o
);


    addr_t              pc_q;
    addr_t              pc_next;

    logic               request_fire;
    logic               response_fire;
    logic               can_issue_request;

    logic [FETCH_EPOCH_W-1:0] epoch_q;
    logic [FETCH_EPOCH_W-1:0] request_epoch;

    logic               pending_valid_q;
    addr_t              pending_pc_q;
    addr_t              pending_pc_plus_4_q;
    prediction_meta_t   pending_prediction_q;

    logic               buffer_valid_q;
    if_id_payload_t     buffer_payload_q;

    logic               predict_taken;
    addr_t              predict_pc;
    logic [PHT_INDEX_WIDTH-1:0] predict_pht_index;
    logic [GHR_WIDTH-1:0]       predict_ghr;
    logic               predict_btb_hit;
    addr_t              predict_btb_target;

    prediction_meta_t   current_prediction;

    rv32i_branch_predictor #(
        .GHR_WIDTH       (GHR_WIDTH),
        .PHT_INDEX_WIDTH (PHT_INDEX_WIDTH),
        .BTB_INDEX_WIDTH (BTB_INDEX_WIDTH)
    ) u_branch_predictor (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),

        .clear_i              (1'b0),

        .fetch_pc_i           (pc_q),
        .predict_taken_o      (predict_taken),
        .predict_pc_o         (predict_pc),
        .predict_pht_index_o  (predict_pht_index),
        .predict_ghr_o        (predict_ghr),
        .predict_btb_hit_o    (predict_btb_hit),
        .predict_btb_target_o (predict_btb_target),

        .update_valid_i       (predictor_update_valid_i),
        .update_pc_i          (predictor_update_pc_i),
        .update_taken_i       (predictor_update_taken_i),
        .update_target_i      (predictor_update_target_i),
        .update_pht_index_i   (predictor_update_pht_index_i)
    );

    always @* begin
        current_prediction = '0;
        current_prediction.valid           = 1'b1;
        current_prediction.predicted_taken = predict_taken;
        current_prediction.predicted_pc    = predict_pc;
        current_prediction.pht_index       = predict_pht_index;
        current_prediction.ghr             = predict_ghr;
        current_prediction.btb_hit         = predict_btb_hit;
        current_prediction.btb_target      = predict_btb_target;
    end

    assign can_issue_request =
        (!pending_valid_q || response_fire) &&
        (!buffer_valid_q || fetch_ready_i);

    assign imem_req_valid_o =
        can_issue_request;

    assign request_fire =
        imem_req_valid_o &&
        imem_req_ready_i;

    assign response_fire =
        imem_rsp_valid_i &&
        imem_rsp_ready_o;

    assign request_epoch =
        epoch_q;

    always @* begin
        imem_req_o         = '0;
        imem_req_o.address = pc_q;
        imem_req_o.epoch   = request_epoch;
    end

    assign imem_rsp_ready_o =
        !buffer_valid_q ||
        fetch_ready_i;

    assign fetch_valid_o =
        buffer_valid_q;

    assign fetch_payload_o =
        buffer_payload_q;

    always @* begin
        pc_next = pc_q;

        if (redirect_valid_i) begin
            pc_next = redirect_pc_i;
        end
        else if (request_fire) begin
            pc_next = predict_pc;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pc_q              <= addr_t'(RESET_VECTOR);
            epoch_q           <= '0;

            pending_valid_q   <= 1'b0;
            pending_pc_q      <= '0;
            pending_pc_plus_4_q <= '0;
            pending_prediction_q <= '0;

            buffer_valid_q    <= 1'b0;
            buffer_payload_q  <= '0;
        end
        else begin
            if (redirect_valid_i) begin
                pc_q            <= redirect_pc_i;
                epoch_q         <= epoch_q + {{(FETCH_EPOCH_W-1){1'b0}}, 1'b1};

                pending_valid_q <= 1'b0;
                buffer_valid_q  <= 1'b0;
            end
            else begin
                pc_q <= pc_next;

                if (fetch_ready_i) begin
                    buffer_valid_q <= 1'b0;
                end

                if (response_fire) begin
                    pending_valid_q <= 1'b0;

                    if (
                        pending_valid_q &&
                        (imem_rsp_i.epoch == epoch_q)
                    ) begin
                        buffer_valid_q <= 1'b1;

                        buffer_payload_q                 <= '0;
                        buffer_payload_q.pc              <= pending_pc_q;
                        buffer_payload_q.instruction     <= imem_rsp_i.instruction;
                        buffer_payload_q.prediction      <= pending_prediction_q;
                        buffer_payload_q.fetch_error     <= imem_rsp_i.error;
                    end
                end

                if (request_fire) begin
                    pending_valid_q      <= 1'b1;
                    pending_pc_q         <= pc_q;
                    pending_pc_plus_4_q  <= pc_q + 32'd4;
                    pending_prediction_q <= current_prediction;
                end
            end
        end
    end

endmodule
