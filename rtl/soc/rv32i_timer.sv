`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_timer.sv
// Module : rv32i_timer
//
// 64-bit Memory-mapped Timer peripheral with interrupt generation for rv32i_soc.

module rv32i_timer
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
(
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // Bus Interface
    input  logic                             req_valid_i,
    output logic                             req_ready_o,
    input  dmem_request_t                    req_i,

    output logic                             rsp_valid_o,
    input  logic                             rsp_ready_i,
    output dmem_response_t                   rsp_o,

    output logic                             timer_irq_o
);

    // Register Offsets
    localparam logic [4:0] REG_MTIME_L    = 5'h00;
    localparam logic [4:0] REG_MTIME_H    = 5'h04;
    localparam logic [4:0] REG_MTIMECMP_L = 5'h08;
    localparam logic [4:0] REG_MTIMECMP_H = 5'h0C;
    localparam logic [4:0] REG_CTRL       = 5'h10;

    // Registers
    logic [63:0] mtime_q;
    logic [63:0] mtimecmp_q;
    logic        timer_en_q;
    logic        irq_en_q;

    // Bus tracking
    logic          response_pending_q;
    dmem_request_t pending_req_q;

    assign req_ready_o = !response_pending_q;
    assign rsp_valid_o = response_pending_q;

    // IRQ when mtime >= mtimecmp (RISC-V standard rule)
    assign timer_irq_o = irq_en_q && (mtime_q >= mtimecmp_q);

    // Bus Read Data
    always_comb begin
        rsp_o       = '0;
        rsp_o.error = 1'b0;

        case (pending_req_q.address[4:0])
            REG_MTIME_L:    rsp_o.read_data = mtime_q[31:0];
            REG_MTIME_H:    rsp_o.read_data = mtime_q[63:32];
            REG_MTIMECMP_L: rsp_o.read_data = mtimecmp_q[31:0];
            REG_MTIMECMP_H: rsp_o.read_data = mtimecmp_q[63:32];
            REG_CTRL:       rsp_o.read_data = {30'd0, irq_en_q, timer_en_q};
            default:        rsp_o.read_data = '0;
        endcase
    end

    // Updates & Counter
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            response_pending_q <= 1'b0;
            pending_req_q      <= '0;
            mtime_q            <= 64'd0;
            mtimecmp_q         <= 64'hFFFF_FFFF_FFFF_FFFF;
            timer_en_q         <= 1'b1;
            irq_en_q           <= 1'b0;
        end else begin
            // 64-bit Timer Increment
            if (timer_en_q) begin
                mtime_q <= mtime_q + 1'b1;
            end

            // Bus Handshake
            if (rsp_valid_o && rsp_ready_i) begin
                response_pending_q <= 1'b0;
            end

            if (req_valid_i && req_ready_o) begin
                response_pending_q <= 1'b1;
                pending_req_q      <= req_i;

                if (req_i.write) begin
                    case (req_i.address[4:0])
                        REG_MTIME_L:    mtime_q[31:0]     <= req_i.write_data;
                        REG_MTIME_H:    mtime_q[63:32]    <= req_i.write_data;
                        REG_MTIMECMP_L: mtimecmp_q[31:0]  <= req_i.write_data;
                        REG_MTIMECMP_H: mtimecmp_q[63:32] <= req_i.write_data;
                        REG_CTRL: begin
                            timer_en_q <= req_i.write_data[0];
                            irq_en_q   <= req_i.write_data[1];
                        end
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
