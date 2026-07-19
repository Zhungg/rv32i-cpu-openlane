`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Baseline branch predictor.
//
// Components:
// - GHR: global branch history
// - PHT: 2-bit saturating counters
// - BTB: direct-mapped target cache
//
// Prediction policy:
// - PHT says taken AND BTB hits  => predict taken to BTB target
// - otherwise                   => predict not taken to PC+4
//
// Update policy:
// - PHT and GHR update for every resolved branch.
// - BTB updates only for actually taken branch/jump.

module rv32i_branch_predictor #(
    parameter int unsigned GHR_WIDTH       = rv32i_types_pkg::GHR_WIDTH,
    parameter int unsigned PHT_INDEX_WIDTH = rv32i_types_pkg::PHT_INDEX_WIDTH,
    parameter int unsigned BTB_INDEX_WIDTH = 6
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic                         clear_i,

    input  logic [31:0]             fetch_pc_i,
    output logic                         predict_taken_o,
    output logic [31:0]             predict_pc_o,
    output logic [PHT_INDEX_WIDTH-1:0]   predict_pht_index_o,
    output logic [GHR_WIDTH-1:0]         predict_ghr_o,
    output logic                         predict_btb_hit_o,
    output logic [31:0]             predict_btb_target_o,

    input  logic                         update_valid_i,
    input  logic [31:0]             update_pc_i,
    input  logic                         update_taken_i,
    input  logic [31:0]             update_target_i,
    input  logic [PHT_INDEX_WIDTH-1:0]   update_pht_index_i
);
    logic [GHR_WIDTH-1:0]         ghr_history;
    logic [PHT_INDEX_WIDTH-1:0]   pc_index;
    logic [PHT_INDEX_WIDTH-1:0]   gshare_index;

    logic                         pht_predict_taken;
    logic [1:0]                   pht_counter;

    logic                         btb_hit;
    logic [31:0]                        btb_target;

    rv32i_ghr #(
        .WIDTH (GHR_WIDTH)
    ) u_ghr (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .clear_i        (clear_i),

        .update_valid_i (update_valid_i),
        .update_taken_i (update_taken_i),

        .history_o      (ghr_history)
    );

    always @* begin
        pc_index = fetch_pc_i[PHT_INDEX_WIDTH+1:2];

        gshare_index = pc_index ^
            {{(PHT_INDEX_WIDTH-GHR_WIDTH){1'b0}}, ghr_history};
    end

    rv32i_pht #(
        .INDEX_WIDTH (PHT_INDEX_WIDTH)
    ) u_pht (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),

        .read_index_i    (gshare_index),
        .predict_taken_o (pht_predict_taken),
        .read_counter_o  (pht_counter),

        .update_valid_i  (update_valid_i),
        .update_index_i  (update_pht_index_i),
        .update_taken_i  (update_taken_i)
    );

    rv32i_btb #(
        .INDEX_WIDTH (BTB_INDEX_WIDTH)
    ) u_btb (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),

        .read_pc_i       (fetch_pc_i),
        .hit_o           (btb_hit),
        .target_o        (btb_target),

        .update_valid_i  (update_valid_i && update_taken_i),
        .update_pc_i     (update_pc_i),
        .update_target_i (update_target_i)
    );

    always @* begin
        predict_taken_o      = pht_predict_taken && btb_hit;
        predict_pc_o         = fetch_pc_i + 32'd4;
        predict_pht_index_o  = gshare_index;
        predict_ghr_o        = ghr_history;
        predict_btb_hit_o    = btb_hit;
        predict_btb_target_o = btb_target;

        if (predict_taken_o) begin
            predict_pc_o = btb_target;
        end
    end

    // Keep pht_counter visible to lint without changing behavior.
    logic unused_pht_counter;
    assign unused_pht_counter = ^pht_counter;

endmodule
