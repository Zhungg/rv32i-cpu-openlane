`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_timer_wb.sv
// Module : rv32i_timer_wb
//
// Wishbone B4 Slave interface for 64-bit Real-time Timer with interrupt support.

module rv32i_timer_wb
    import rv32i_wishbone_pkg::*;
(
    input  logic    clk_i,
    input  logic    rst_ni,

    // Wishbone Slave
    input  wb_req_t wb_req_i,
    output wb_rsp_t wb_rsp_o,

    output logic    timer_irq_o
);

    localparam logic [4:0] REG_MTIME_L    = 5'h00;
    localparam logic [4:0] REG_MTIME_H    = 5'h04;
    localparam logic [4:0] REG_MTIMECMP_L = 5'h08;
    localparam logic [4:0] REG_MTIMECMP_H = 5'h0C;
    localparam logic [4:0] REG_CTRL       = 5'h10;

    logic [63:0] mtime_q;
    logic [63:0] mtimecmp_q;
    logic        timer_en_q;
    logic        irq_en_q;

    assign timer_irq_o = irq_en_q && (mtime_q >= mtimecmp_q);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_rsp_o   <= WB_RSP_IDLE;
            mtime_q    <= 64'd0;
            mtimecmp_q <= 64'hFFFF_FFFF_FFFF_FFFF;
            timer_en_q <= 1'b1;
            irq_en_q   <= 1'b0;
        end else begin
            wb_rsp_o.ack <= 1'b0;
            wb_rsp_o.err <= 1'b0;

            if (timer_en_q) begin
                mtime_q <= mtime_q + 1'b1;
            end

            if (wb_req_i.cyc && wb_req_i.stb && !wb_rsp_o.ack) begin
                wb_rsp_o.ack <= 1'b1;

                if (wb_req_i.we) begin
                    case (wb_req_i.adr[4:0])
                        REG_MTIME_L:    mtime_q[31:0]     <= wb_req_i.dat_w;
                        REG_MTIME_H:    mtime_q[63:32]    <= wb_req_i.dat_w;
                        REG_MTIMECMP_L: mtimecmp_q[31:0]  <= wb_req_i.dat_w;
                        REG_MTIMECMP_H: mtimecmp_q[63:32] <= wb_req_i.dat_w;
                        REG_CTRL: begin
                            timer_en_q <= wb_req_i.dat_w[0];
                            irq_en_q   <= wb_req_i.dat_w[1];
                        end
                        default: ;
                    endcase
                end else begin
                    case (wb_req_i.adr[4:0])
                        REG_MTIME_L:    wb_rsp_o.dat_r <= mtime_q[31:0];
                        REG_MTIME_H:    wb_rsp_o.dat_r <= mtime_q[63:32];
                        REG_MTIMECMP_L: wb_rsp_o.dat_r <= mtimecmp_q[31:0];
                        REG_MTIMECMP_H: wb_rsp_o.dat_r <= mtimecmp_q[63:32];
                        REG_CTRL:       wb_rsp_o.dat_r <= {30'd0, irq_en_q, timer_en_q};
                        default:        wb_rsp_o.dat_r <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
