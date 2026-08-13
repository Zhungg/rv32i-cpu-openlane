`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/cache/rv32i_icache.sv
// Module : rv32i_icache
//
// 2-Way Set-Associative L1 Instruction Cache (2KB, 16-Byte Line)
// with Wishbone B4 Line-Fill Engine and FENCE.I flush support.

module rv32i_icache
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
    import rv32i_cache_pkg::*;
(
    input  logic              clk_i,
    input  logic              rst_ni,

    // CPU Instruction Fetch Interface
    input  logic              cpu_req_valid_i,
    output logic              cpu_req_ready_o,
    input  addr_t             cpu_req_addr_i,

    output logic              cpu_rsp_valid_o,
    input  logic              cpu_rsp_ready_i,
    output insn_t             cpu_rsp_inst_o,

    // Flush control (FENCE.I)
    input  logic              flush_i,

    // Wishbone Master Interface (for Line Fill)
    output wb_req_t           wb_req_o,
    input  wb_rsp_t           wb_rsp_i,

    // Performance / Event Counters
    output logic              hit_count_o,
    output logic              miss_count_o
);

    // Cache Storage: 64 Sets, 2 Ways
    cache_line_t way0 [0:CACHE_SETS-1];
    cache_line_t way1 [0:CACHE_SETS-1];
    logic        lru  [0:CACHE_SETS-1]; // 0 = replace way0, 1 = replace way1

    typedef enum logic [2:0] {
        ST_IDLE      = 3'd0,
        ST_LOOKUP    = 3'd1,
        ST_FILL_REQ  = 3'd2,
        ST_FILL_WAIT = 3'd3,
        ST_RESPOND   = 3'd4
    } state_e;

    state_e state_q;

    // Latched request fields
    addr_t        pending_addr_q;
    cache_tag_t   pending_tag;
    cache_index_t pending_index;
    logic [1:0]   pending_word_idx;

    assign pending_tag      = pending_addr_q[31:10];
    assign pending_index    = pending_addr_q[9:4];
    assign pending_word_idx = pending_addr_q[3:2];

    // Combinational tag check on pending request
    wire way0_hit = way0[pending_index].valid && (way0[pending_index].tag == pending_tag);
    wire way1_hit = way1[pending_index].valid && (way1[pending_index].tag == pending_tag);
    wire cache_hit = way0_hit || way1_hit;

    // Line buffer for 4-word burst fill
    logic [127:0] fill_line_q;
    logic [1:0]   fill_word_cnt_q;
    logic         victim_way_q;

    // Word extraction function
    function automatic insn_t extract_word(input logic [127:0] line_data, input logic [1:0] word_idx);
        case (word_idx)
            2'd0: extract_word = line_data[31:0];
            2'd1: extract_word = line_data[63:32];
            2'd2: extract_word = line_data[95:64];
            2'd3: extract_word = line_data[127:96];
        endcase
    endfunction

    // Output signals
    always_comb begin
        wb_req_o        = WB_REQ_IDLE;
        cpu_req_ready_o = 1'b0;
        cpu_rsp_valid_o = 1'b0;
        cpu_rsp_inst_o  = 32'h0000_0013; // NOP
        hit_count_o     = 1'b0;
        miss_count_o    = 1'b0;

        case (state_q)
            ST_IDLE: begin
                cpu_req_ready_o = 1'b1;
            end

            ST_LOOKUP: begin
                if (cache_hit) begin
                    cpu_rsp_valid_o = 1'b1;
                    hit_count_o     = 1'b1;
                    if (way0_hit) cpu_rsp_inst_o = extract_word(way0[pending_index].data, pending_word_idx);
                    else          cpu_rsp_inst_o = extract_word(way1[pending_index].data, pending_word_idx);
                end
            end

            ST_FILL_REQ,
            ST_FILL_WAIT: begin
                wb_req_o.cyc   = 1'b1;
                wb_req_o.stb   = 1'b1;
                wb_req_o.we    = 1'b0;
                wb_req_o.sel   = 4'b1111;
                wb_req_o.adr   = {pending_addr_q[31:4], fill_word_cnt_q, 2'b00};
                wb_req_o.dat_w = 32'd0;
            end

            ST_RESPOND: begin
                cpu_rsp_valid_o = 1'b1;
                cpu_rsp_inst_o  = extract_word(fill_line_q, pending_word_idx);
            end

            default: ;
        endcase
    end

    // State machine & Cache update logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q         <= ST_IDLE;
            pending_addr_q  <= '0;
            fill_line_q     <= '0;
            fill_word_cnt_q <= '0;
            victim_way_q    <= 1'b0;

            for (int i = 0; i < CACHE_SETS; i++) begin
                way0[i].valid <= 1'b0;
                way0[i].tag   <= '0;
                way0[i].data  <= '0;
                way1[i].valid <= 1'b0;
                way1[i].tag   <= '0;
                way1[i].data  <= '0;
                lru[i]        <= 1'b0;
            end
        end else if (flush_i) begin
            // Invalidate all lines on FENCE.I flush
            for (int i = 0; i < CACHE_SETS; i++) begin
                way0[i].valid <= 1'b0;
                way1[i].valid <= 1'b0;
                lru[i]        <= 1'b0;
            end
            state_q <= ST_IDLE;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (cpu_req_valid_i && cpu_req_ready_o) begin
                        pending_addr_q <= cpu_req_addr_i;
                        state_q        <= ST_LOOKUP;
                    end
                end

                ST_LOOKUP: begin
                    if (cache_hit) begin
                        // Hit: update LRU (0 prefers way1 next, 1 prefers way0 next)
                        lru[pending_index] <= way0_hit ? 1'b1 : 1'b0;
                        if (cpu_rsp_ready_i) begin
                            state_q <= ST_IDLE;
                        end
                    end else begin
                        // Miss: Prepare line fill
                        victim_way_q    <= lru[pending_index];
                        fill_word_cnt_q <= 2'd0;
                        fill_line_q     <= '0;
                        state_q         <= ST_FILL_REQ;
                    end
                end

                ST_FILL_REQ: begin
                    state_q <= ST_FILL_WAIT;
                end

                ST_FILL_WAIT: begin
                    if (wb_rsp_i.ack) begin
                        case (fill_word_cnt_q)
                            2'd0: fill_line_q[31:0]   <= wb_rsp_i.dat_r;
                            2'd1: fill_line_q[63:32]  <= wb_rsp_i.dat_r;
                            2'd2: fill_line_q[95:64]  <= wb_rsp_i.dat_r;
                            2'd3: fill_line_q[127:96] <= wb_rsp_i.dat_r;
                        endcase

                        if (fill_word_cnt_q == 2'd3) begin
                            // Completed 4-word line fill: write to victim cache way
                            if (!victim_way_q) begin
                                way0[pending_index].valid <= 1'b1;
                                way0[pending_index].tag   <= pending_tag;
                                way0[pending_index].data  <= {wb_rsp_i.dat_r, fill_line_q[95:0]};
                                lru[pending_index]        <= 1'b1;
                            end else begin
                                way1[pending_index].valid <= 1'b1;
                                way1[pending_index].tag   <= pending_tag;
                                way1[pending_index].data  <= {wb_rsp_i.dat_r, fill_line_q[95:0]};
                                lru[pending_index]        <= 1'b0;
                            end
                            state_q <= ST_RESPOND;
                        end else begin
                            fill_word_cnt_q <= fill_word_cnt_q + 1'b1;
                            state_q         <= ST_FILL_REQ;
                        end
                    end
                end

                ST_RESPOND: begin
                    if (cpu_rsp_ready_i) begin
                        state_q <= ST_IDLE;
                    end
                end

                default: state_q <= ST_IDLE;
            endcase
        end
    end

endmodule
