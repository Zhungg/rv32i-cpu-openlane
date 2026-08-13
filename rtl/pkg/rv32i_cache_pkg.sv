`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32i_cache_pkg.sv
//
// L1 Cache parameters, structures, and definitions.

package rv32i_cache_pkg;

    localparam int unsigned CACHE_LINE_BYTES      = 16;
    localparam int unsigned CACHE_WORDS_PER_LINE  = 4;
    localparam int unsigned CACHE_WAYS            = 2;
    localparam int unsigned CACHE_SETS            = 64; // 64 sets * 2 ways * 16B = 2048 B (2 KB)

    localparam int unsigned OFFSET_BITS           = 4; // log2(16)
    localparam int unsigned INDEX_BITS            = 6; // log2(64)
    localparam int unsigned TAG_BITS              = 32 - INDEX_BITS - OFFSET_BITS; // 22 bits

    typedef logic [TAG_BITS-1:0]    cache_tag_t;
    typedef logic [INDEX_BITS-1:0]  cache_index_t;
    typedef logic [OFFSET_BITS-1:0] cache_offset_t;

    typedef struct packed {
        logic [127:0] data;  // 4 words = 16 bytes
        cache_tag_t   tag;
        logic         valid;
    } cache_line_t;

endpackage
