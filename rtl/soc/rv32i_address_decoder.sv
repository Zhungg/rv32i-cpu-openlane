`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_address_decoder.sv
// Module : rv32i_address_decoder
//
// Memory-mapped address decoder routing core data-memory transactions
// to DMEM (RAM), UART, and Timer peripherals.

module rv32i_address_decoder
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
(
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // Core Data Memory Interface
    input  logic                             core_req_valid_i,
    output logic                             core_req_ready_o,
    input  dmem_request_t                    core_req_i,

    output logic                             core_rsp_valid_o,
    input  logic                             core_rsp_ready_i,
    output dmem_response_t                   core_rsp_o,

    // DMEM (RAM) Interface: Base 0x2000_0000, Size 64KB (or 0x0000_0000 - 0x2FFF_FFFF RAM region)
    output logic                             dmem_req_valid_o,
    input  logic                             dmem_req_ready_i,
    output dmem_request_t                    dmem_req_o,

    input  logic                             dmem_rsp_valid_i,
    output logic                             dmem_rsp_ready_o,
    input  dmem_response_t                   dmem_rsp_i,

    // UART Peripheral: Base 0x4000_0000, Size 4KB
    output logic                             uart_req_valid_o,
    input  logic                             uart_req_ready_i,
    output dmem_request_t                    uart_req_o,

    input  logic                             uart_rsp_valid_i,
    output logic                             uart_rsp_ready_o,
    input  dmem_response_t                   uart_rsp_i,

    // Timer Peripheral: Base 0x4000_1000, Size 4KB
    output logic                             timer_req_valid_o,
    input  logic                             timer_req_ready_i,
    output dmem_request_t                    timer_req_o,

    input  logic                             timer_rsp_valid_i,
    output logic                             timer_rsp_ready_o,
    input  dmem_response_t                   timer_rsp_i
);

    typedef enum logic [1:0] {
        SEL_NONE  = 2'd0,
        SEL_DMEM  = 2'd1,
        SEL_UART  = 2'd2,
        SEL_TIMER = 2'd3
    } slave_sel_e;

    slave_sel_e current_sel;
    slave_sel_e pending_sel_q;
    logic       response_pending_q;

    // Address range decode:
    // 0x4000_0000 - 0x4000_0FFF -> UART
    // 0x4000_1000 - 0x4000_1FFF -> Timer
    // All other addresses (including 0x0000_0000.. and 0x2000_0000..) -> DMEM (RAM)
    always_comb begin
        if ((core_req_i.address & 32'hFFFF_F000) == 32'h4000_0000) begin
            current_sel = SEL_UART;
        end else if ((core_req_i.address & 32'hFFFF_F000) == 32'h4000_1000) begin
            current_sel = SEL_TIMER;
        end else begin
            current_sel = SEL_DMEM;
        end
    end

    // Forward requests to targeted slave
    always_comb begin
        dmem_req_valid_o  = 1'b0;
        uart_req_valid_o  = 1'b0;
        timer_req_valid_o = 1'b0;

        dmem_req_o  = core_req_i;
        uart_req_o  = core_req_i;
        timer_req_o = core_req_i;

        if (core_req_valid_i) begin
            case (current_sel)
                SEL_UART: begin
                    uart_req_valid_o = 1'b1;
                    core_req_ready_o = uart_req_ready_i;
                end
                SEL_TIMER: begin
                    timer_req_valid_o = 1'b1;
                    core_req_ready_o  = timer_req_ready_i;
                end
                default: begin
                    dmem_req_valid_o = 1'b1;
                    core_req_ready_o = dmem_req_ready_i;
                end
            endcase
        end else begin
            core_req_ready_o = 1'b1;
        end
    end

    // Track pending slave for 1-cycle response routing
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pending_sel_q      <= SEL_NONE;
            response_pending_q <= 1'b0;
        end else begin
            if (core_rsp_valid_o && core_rsp_ready_i) begin
                response_pending_q <= 1'b0;
                pending_sel_q      <= SEL_NONE;
            end

            if (core_req_valid_i && core_req_ready_o) begin
                pending_sel_q      <= current_sel;
                response_pending_q <= 1'b1;
            end
        end
    end

    // Route response back to core
    always_comb begin
        dmem_rsp_ready_o  = 1'b0;
        uart_rsp_ready_o  = 1'b0;
        timer_rsp_ready_o = 1'b0;
        core_rsp_valid_o  = 1'b0;
        core_rsp_o        = '0;

        case (pending_sel_q)
            SEL_UART: begin
                core_rsp_valid_o = uart_rsp_valid_i;
                core_rsp_o       = uart_rsp_i;
                uart_rsp_ready_o = core_rsp_ready_i;
            end
            SEL_TIMER: begin
                core_rsp_valid_o  = timer_rsp_valid_i;
                core_rsp_o        = timer_rsp_i;
                timer_rsp_ready_o = core_rsp_ready_i;
            end
            SEL_DMEM: begin
                core_rsp_valid_o = dmem_rsp_valid_i;
                core_rsp_o       = dmem_rsp_i;
                dmem_rsp_ready_o = core_rsp_ready_i;
            end
            default: begin
                core_rsp_valid_o = 1'b0;
                core_rsp_o       = '0;
            end
        endcase
    end

endmodule
