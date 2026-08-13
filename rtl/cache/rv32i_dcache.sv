`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/cache/rv32i_dcache.sv
// Module : rv32i_dcache
//
// 2-Way Set-Associative L1 Data Cache (2KB, 16-Byte Line)
// with Write-Through No-Write-Allocate policy and MMIO uncached bypass.

module rv32i_dcache
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
    import rv32i_cache_pkg::*;
(
    input  logic              clk_i,
    input  logic              rst_ni,

    // Core LSU Native Interface
    input  logic              cpu_req_valid_i,
    output logic              cpu_req_ready_o,
    input  dmem_request_t     cpu_req_i,

    output logic              cpu_rsp_valid_o,
    input  logic              cpu_rsp_ready_i,
    output dmem_response_t    cpu_rsp_o,

    // Flush control (FENCE)
    input  logic              flush_i,

    // Wishbone Master Interface (to Crossbar)
    output wb_req_t           wb_req_o,
    input  wb_rsp_t           wb_rsp_i,

    // Performance Counters
    output logic              hit_count_o,
    output logic              miss_count_o
);

    // Cache Storage: 64 Sets, 2 Ways
    cache_line_t way0 [0:CACHE_SETS-1];
    cache_line_t way1 [0:CACHE_SETS-1];
    logic        lru  [0:CACHE_SETS-1];

    typedef enum logic [2:0] {
        ST_IDLE         = 3'd0,
        ST_LOOKUP       = 3'd1,
        ST_READ_FILL    = 3'd2,
        ST_FILL_WAIT    = 3'd3,
        ST_WRITE_THROUGH= 3'd4,
        ST_UNCACHED_WAIT= 3'd5,
        ST_RESPOND      = 3'd6
    } state_e;

    state_e state_q;

    dmem_request_t pending_req_q;
    cache_tag_t    pending_tag;
    cache_index_t  pending_index;
    logic [1:0]    pending_word_idx;

    assign pending_tag      = pending_req_q.address[31:10];
    assign pending_index    = pending_req_q.address[9:4];
    assign pending_word_idx = pending_req_q.address[3:2];

    // MMIO check: Addresses >= 0x4000_0000 are uncacheable
    wire is_uncacheable = (pending_req_q.address >= 32'h4000_0000);

    // Tag comparison
    wire way0_hit = way0[pending_index].valid && (way0[pending_index].tag == pending_tag);
    wire way1_hit = way1[pending_index].valid && (way1[pending_index].tag == pending_tag);
    wire cache_hit = (way0_hit || way1_hit) && !is_uncacheable;

    // Line fill buffer
    logic [127:0] fill_line_q;
    logic [1:0]   fill_word_cnt_q;
    logic         victim_way_q;
    xlen_t        rsp_data_q;

    function automatic xlen_t extract_word(input logic [127:0] line_data, input logic [1:0] word_idx);
        case (word_idx)
            2'd0: extract_word = line_data[31:0];
            2'd1: extract_word = line_data[63:32];
            2'd2: extract_word = line_data[95:64];
            2'd3: extract_word = line_data[127:96];
        endcase
    endfunction

    // Output assignments
    always_comb begin
        wb_req_o         = WB_REQ_IDLE;
        cpu_req_ready_o  = 1'b0;
        cpu_rsp_valid_o  = 1'b0;
        cpu_rsp_o        = '0;
        hit_count_o      = 1'b0;
        miss_count_o     = 1'b0;

        case (state_q)
            ST_IDLE: begin
                cpu_req_ready_o = 1'b1;
            end

            ST_LOOKUP: begin
                if (!pending_req_q.write && cache_hit) begin
                    cpu_rsp_valid_o     = 1'b1;
                    hit_count_o         = 1'b1;
                    if (way0_hit) cpu_rsp_o.read_data = extract_word(way0[pending_index].data, pending_word_idx);
                    else          cpu_rsp_o.read_data = extract_word(way1[pending_index].data, pending_word_idx);
                end
            end

            ST_READ_FILL,
            ST_FILL_WAIT: begin
                wb_req_o.cyc   = 1'b1;
                wb_req_o.stb   = 1'b1;
                wb_req_o.we    = 1'b0;
                wb_req_o.sel   = 4'b1111;
                wb_req_o.adr   = {pending_req_q.address[31:4], fill_word_cnt_q, 2'b00};
                wb_req_o.dat_w = 32'd0;
            end

            ST_WRITE_THROUGH: begin
                wb_req_o.cyc   = 1'b1;
                wb_req_o.stb   = 1'b1;
                wb_req_o.we    = 1'b1;
                wb_req_o.sel   = pending_req_q.write_strobe;
                wb_req_o.adr   = pending_req_q.address;
                wb_req_o.dat_w = pending_req_q.write_data;
            end

            ST_UNCACHED_WAIT: begin
                wb_req_o.cyc   = 1'b1;
                wb_req_o.stb   = 1'b1;
                wb_req_o.we    = pending_req_q.write;
                wb_req_o.sel   = pending_req_q.write ? pending_req_q.write_strobe : 4'b1111;
                wb_req_o.adr   = pending_req_q.address;
                wb_req_o.dat_w = pending_req_q.write_data;
            end

            ST_RESPOND: begin
                cpu_rsp_valid_o     = 1'b1;
                cpu_rsp_o.read_data = rsp_data_q;
            end

            default: ;
        endcase
    end

    // State machine & Updates
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q         <= ST_IDLE;
            pending_req_q   <= '0;
            fill_line_q     <= '0;
            fill_word_cnt_q <= '0;
            victim_way_q    <= 1'b0;
            rsp_data_q      <= '0;

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
                        pending_req_q <= cpu_req_i;
                        state_q       <= ST_LOOKUP;
                    end
                end

                ST_LOOKUP: begin
                    if (is_uncacheable) begin
                        state_q <= ST_UNCACHED_WAIT;
                    end else if (pending_req_q.write) begin
                        // Write hit: Update cache line & write-through to memory
                        if (way0_hit) begin
                            if (pending_req_q.write_strobe[0]) way0[pending_index].data[pending_word_idx*32 +: 8]  <= pending_req_q.write_data[7:0];
                            if (pending_req_q.write_strobe[1]) way0[pending_index].data[pending_word_idx*32+8 +: 8] <= pending_req_q.write_data[15:8];
                            if (pending_req_q.write_strobe[2]) way0[pending_index].data[pending_word_idx*32+16 +: 8] <= pending_req_q.write_data[23:16];
                            if (pending_req_q.write_strobe[3]) way0[pending_index].data[pending_word_idx*32+24 +: 8] <= pending_req_q.write_data[31:24];
                        end else if (way1_hit) begin
                            if (pending_req_q.write_strobe[0]) way1[pending_index].data[pending_word_idx*32 +: 8]  <= pending_req_q.write_data[7:0];
                            if (pending_req_q.write_strobe[1]) way1[pending_index].data[pending_word_idx*32+8 +: 8] <= pending_req_q.write_data[15:8];
                            if (pending_req_q.write_strobe[2]) way1[pending_index].data[pending_word_idx*32+16 +: 8] <= pending_req_q.write_data[23:16];
                            if (pending_req_q.write_strobe[3]) way1[pending_index].data[pending_word_idx*32+24 +: 8] <= pending_req_q.write_data[31:24];
                        end
                        state_q <= ST_WRITE_THROUGH;
                    end else begin
                        // Read request
                        if (cache_hit) begin
                            lru[pending_index] <= way0_hit ? 1'b1 : 1'b0;
                            if (cpu_rsp_ready_i) state_q <= ST_IDLE;
                        end else begin
                            victim_way_q    <= lru[pending_index];
                            fill_word_cnt_q <= 2'd0;
                            fill_line_q     <= '0;
                            state_q         <= ST_READ_FILL;
                        end
                    end
                end

                ST_READ_FILL: begin
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
                            rsp_data_q <= (pending_word_idx == 2'd3) ? wb_rsp_i.dat_r : extract_word(fill_line_q, pending_word_idx);
                            state_q    <= ST_RESPOND;
                        end else begin
                            fill_word_cnt_q <= fill_word_cnt_q + 1'b1;
                            state_q         <= ST_READ_FILL;
                        end
                    end
                end

                ST_WRITE_THROUGH: begin
                    if (wb_rsp_i.ack) begin
                        state_q <= ST_RESPOND;
                    end
                end

                ST_UNCACHED_WAIT: begin
                    if (wb_rsp_i.ack) begin
                        rsp_data_q <= wb_rsp_i.dat_r;
                        state_q    <= ST_RESPOND;
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
