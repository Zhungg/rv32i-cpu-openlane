`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_wb_interconnect.sv
// Module : rv32i_wb_interconnect
//
// 2-Master, 4-Slave Wishbone B4 Crossbar Interconnect with Round-Robin Arbitration.
//
// Memory Map:
// - Slave 0 (DMEM RAM) : 0x2000_0000 - 0x200F_FFFF (or 0x0000_0000 - 0x000F_FFFF if mapped)
// - Slave 1 (UART)     : 0x4000_0000 - 0x4000_0FFF
// - Slave 2 (Timer)    : 0x4000_1000 - 0x4000_1FFF
// - Slave 3 (DMA Regs) : 0x4000_2000 - 0x4000_2FFF

module rv32i_wb_interconnect
    import rv32i_wishbone_pkg::*;
(
    input  logic     clk_i,
    input  logic     rst_ni,

    // Master 0: CPU LSU
    input  wb_req_t  m0_req_i,
    output wb_rsp_t  m0_rsp_o,

    // Master 1: DMA Controller
    input  wb_req_t  m1_req_i,
    output wb_rsp_t  m1_rsp_o,

    // Slave 0: DMEM RAM
    output wb_req_t  s0_req_o,
    input  wb_rsp_t  s0_rsp_i,

    // Slave 1: UART
    output wb_req_t  s1_req_o,
    input  wb_rsp_t  s1_rsp_i,

    // Slave 2: Timer
    output wb_req_t  s2_req_o,
    input  wb_rsp_t  s2_rsp_i,

    // Slave 3: DMA Configuration Regs
    output wb_req_t  s3_req_o,
    input  wb_rsp_t  s3_rsp_i
);

    typedef enum logic [1:0] {
        M_NONE = 2'd0,
        M_M0   = 2'd1,
        M_M1   = 2'd2
    } master_id_e;

    typedef enum logic [2:0] {
        SLV_NONE  = 3'd0,
        SLV_DMEM  = 3'd1,
        SLV_UART  = 3'd2,
        SLV_TIMER = 3'd3,
        SLV_DMA   = 3'd4
    } slave_id_e;

    master_id_e active_master;
    master_id_e granted_master_q;
    logic       lock_grant_q;

    // -------------------------------------------------------------
    // Arbiter: Round-Robin when both request, locks until CYC drops
    // -------------------------------------------------------------
    always_comb begin
        if (lock_grant_q) begin
            active_master = granted_master_q;
        end else begin
            if (m0_req_i.cyc && m1_req_i.cyc) begin
                // If previous was M0, give M1 priority
                if (granted_master_q == M_M0) active_master = M_M1;
                else active_master = M_M0;
            end else if (m0_req_i.cyc) begin
                active_master = M_M0;
            end else if (m1_req_i.cyc) begin
                active_master = M_M1;
            end else begin
                active_master = M_NONE;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            granted_master_q <= M_NONE;
            lock_grant_q     <= 1'b0;
        end else begin
            if (active_master != M_NONE) begin
                granted_master_q <= active_master;
                // Keep lock while active master asserts cyc
                if (active_master == M_M0) lock_grant_q <= m0_req_i.cyc;
                else if (active_master == M_M1) lock_grant_q <= m1_req_i.cyc;
                else lock_grant_q <= 1'b0;
            end else begin
                lock_grant_q <= 1'b0;
            end
        end
    end

    // Selected active request
    wb_req_t active_req;
    always_comb begin
        case (active_master)
            M_M0:    active_req = m0_req_i;
            M_M1:    active_req = m1_req_i;
            default: active_req = WB_REQ_IDLE;
        endcase
    end

    // -------------------------------------------------------------
    // Address Decoding
    // -------------------------------------------------------------
    slave_id_e target_slave;
    always_comb begin
        if ((active_req.adr & 32'hFFFF_F000) == 32'h4000_0000) begin
            target_slave = SLV_UART;
        end else if ((active_req.adr & 32'hFFFF_F000) == 32'h4000_1000) begin
            target_slave = SLV_TIMER;
        end else if ((active_req.adr & 32'hFFFF_F000) == 32'h4000_2000) begin
            target_slave = SLV_DMA;
        end else begin
            target_slave = SLV_DMEM;
        end
    end

    // -------------------------------------------------------------
    // Route Request to Slaves
    // -------------------------------------------------------------
    always_comb begin
        s0_req_o = WB_REQ_IDLE;
        s1_req_o = WB_REQ_IDLE;
        s2_req_o = WB_REQ_IDLE;
        s3_req_o = WB_REQ_IDLE;

        if (active_req.cyc) begin
            case (target_slave)
                SLV_UART:  s1_req_o = active_req;
                SLV_TIMER: s2_req_o = active_req;
                SLV_DMA:   s3_req_o = active_req;
                default:   s0_req_o = active_req;
            endcase
        end
    end

    // -------------------------------------------------------------
    // Route Response back to Active Master
    // -------------------------------------------------------------
    wb_rsp_t active_rsp;
    always_comb begin
        case (target_slave)
            SLV_UART:  active_rsp = s1_rsp_i;
            SLV_TIMER: active_rsp = s2_rsp_i;
            SLV_DMA:   active_rsp = s3_rsp_i;
            default:   active_rsp = s0_rsp_i;
        endcase
    end

    always_comb begin
        m0_rsp_o = WB_RSP_IDLE;
        m1_rsp_o = WB_RSP_IDLE;

        case (active_master)
            M_M0:    m0_rsp_o = active_rsp;
            M_M1:    m1_rsp_o = active_rsp;
            default: ;
        endcase
    end

endmodule
