`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_wb_master_adapter.sv
// Module : rv32i_wb_master_adapter
//
// Bridges CPU native LSU request/response handshake to standard Wishbone B4 Master interface.

module rv32i_wb_master_adapter
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
(
    input  logic             clk_i,
    input  logic             rst_ni,

    // Core LSU interface
    input  logic             core_req_valid_i,
    output logic             core_req_ready_o,
    input  dmem_request_t    core_req_i,

    output logic             core_rsp_valid_o,
    input  logic             core_rsp_ready_i,
    output dmem_response_t   core_rsp_o,

    // Wishbone Master Interface
    output wb_req_t          wb_req_o,
    input  wb_rsp_t          wb_rsp_i
);

    typedef enum logic [1:0] {
        ST_IDLE     = 2'd0,
        ST_WAIT_ACK = 2'd1
    } state_e;

    state_e state_q;
    dmem_request_t pending_req_q;

    // Combinational outputs
    always_comb begin
        wb_req_o         = WB_REQ_IDLE;
        core_req_ready_o = 1'b0;
        core_rsp_valid_o = 1'b0;
        core_rsp_o       = '0;

        case (state_q)
            ST_IDLE: begin
                core_req_ready_o = 1'b1;
                if (core_req_valid_i) begin
                    wb_req_o.cyc   = 1'b1;
                    wb_req_o.stb   = 1'b1;
                    wb_req_o.adr   = core_req_i.address;
                    wb_req_o.we    = core_req_i.write;
                    wb_req_o.dat_w = core_req_i.write_data;
                    wb_req_o.sel   = core_req_i.write ? core_req_i.write_strobe : 4'b1111;
                end
            end

            ST_WAIT_ACK: begin
                wb_req_o.cyc   = 1'b1;
                wb_req_o.stb   = 1'b1;
                wb_req_o.adr   = pending_req_q.address;
                wb_req_o.we    = pending_req_q.write;
                wb_req_o.dat_w = pending_req_q.write_data;
                wb_req_o.sel   = pending_req_q.write ? pending_req_q.write_strobe : 4'b1111;

                if (wb_rsp_i.ack || wb_rsp_i.err) begin
                    core_rsp_valid_o     = 1'b1;
                    core_rsp_o.read_data = wb_rsp_i.dat_r;
                    core_rsp_o.error     = wb_rsp_i.err;
                end
            end

            default: ;
        endcase
    end

    // State machine
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q        <= ST_IDLE;
            pending_req_q  <= '0;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (core_req_valid_i && core_req_ready_o) begin
                        pending_req_q <= core_req_i;
                        if (wb_rsp_i.ack || wb_rsp_i.err) begin
                            // 0-wait state transaction completed immediately
                            state_q <= ST_IDLE;
                        end else begin
                            state_q <= ST_WAIT_ACK;
                        end
                    end
                end

                ST_WAIT_ACK: begin
                    if ((wb_rsp_i.ack || wb_rsp_i.err) && core_rsp_ready_i) begin
                        state_q <= ST_IDLE;
                    end
                end

                default: state_q <= ST_IDLE;
            endcase
        end
    end

endmodule
