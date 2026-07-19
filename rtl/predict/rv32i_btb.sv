`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Direct-mapped Branch Target Buffer.
//
// Baseline design:
// - index by PC[INDEX_WIDTH+1:2]
// - tag by remaining upper PC bits
// - update only when branch/jump is resolved as taken

module rv32i_btb #(
    parameter int unsigned INDEX_WIDTH = 6
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic [31:0]             read_pc_i,
    output logic                         hit_o,
    output logic [31:0]             target_o,

    input  logic                         update_valid_i,
    input  logic [31:0]             update_pc_i,
    input  logic [31:0]             update_target_i
);
    localparam int unsigned ENTRY_COUNT = 1 << INDEX_WIDTH;
    localparam int unsigned INDEX_LSB   = 2;
    localparam int unsigned INDEX_MSB   = INDEX_LSB + INDEX_WIDTH - 1;
    localparam int unsigned TAG_WIDTH   = 32 - INDEX_WIDTH - INDEX_LSB;

    typedef logic [INDEX_WIDTH-1:0] index_t;
    typedef logic [TAG_WIDTH-1:0]   tag_t;

    logic  valid_q  [0:ENTRY_COUNT-1];
    tag_t  tag_q    [0:ENTRY_COUNT-1];
    logic [31:0] target_q [0:ENTRY_COUNT-1];

    index_t read_index;
    tag_t   read_tag;

    index_t update_index;
    tag_t   update_tag;

    integer reset_index;

    assign read_index   = read_pc_i[INDEX_MSB:INDEX_LSB];
    assign read_tag     = read_pc_i[31:INDEX_MSB+1];

    assign update_index = update_pc_i[INDEX_MSB:INDEX_LSB];
    assign update_tag   = update_pc_i[31:INDEX_MSB+1];

    always @* begin
        hit_o    = valid_q[read_index] && (tag_q[read_index] == read_tag);
        target_o = target_q[read_index];
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (reset_index = 0; reset_index < ENTRY_COUNT; reset_index++) begin
                valid_q[reset_index]  <= 1'b0;
                tag_q[reset_index]    <= '0;
                target_q[reset_index] <= '0;
            end
        end
        else if (update_valid_i) begin
            valid_q[update_index]  <= 1'b1;
            tag_q[update_index]    <= update_tag;
            target_q[update_index] <= update_target_i;
        end
    end

endmodule
