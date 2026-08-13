`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32i_wishbone_pkg.sv
//
// Standard Wishbone B4 bus interface types and definitions.

package rv32i_wishbone_pkg;

    typedef struct packed {
        logic [31:0] adr;
        logic [31:0] dat_w;
        logic [3:0]  sel;
        logic        we;
        logic        cyc;
        logic        stb;
    } wb_req_t;

    typedef struct packed {
        logic [31:0] dat_r;
        logic        ack;
        logic        err;
    } wb_rsp_t;

    localparam wb_req_t WB_REQ_IDLE = '{
        adr:   32'd0,
        dat_w: 32'd0,
        sel:   4'b0000,
        we:    1'b0,
        cyc:   1'b0,
        stb:   1'b0
    };

    localparam wb_rsp_t WB_RSP_IDLE = '{
        dat_r: 32'd0,
        ack:   1'b0,
        err:   1'b0
    };

endpackage
