`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_dma.sv
// Module : rv32i_dma
//
// Direct Memory Access (DMA) Controller with Wishbone Master & Slave interfaces.
// Supports 32-bit aligned block transfers between memory and memory-mapped peripherals.

module rv32i_dma
    import rv32i_wishbone_pkg::*;
(
    input  logic    clk_i,
    input  logic    rst_ni,

    // Wishbone Slave Interface (Programming by CPU)
    input  wb_req_t s_wb_req_i,
    output wb_rsp_t s_wb_rsp_o,

    // Wishbone Master Interface (Autonomous Bus Transfers)
    output wb_req_t m_wb_req_o,
    input  wb_rsp_t m_wb_rsp_i,

    // Interrupt output
    output logic    dma_irq_o
);

    // Register Offsets
    localparam logic [3:0] REG_SRC  = 4'h0;
    localparam logic [3:0] REG_DST  = 4'h4;
    localparam logic [3:0] REG_LEN  = 4'h8;
    localparam logic [3:0] REG_CTRL = 4'hC;

    // Registers
    logic [31:0] src_addr_q;
    logic [31:0] dst_addr_q;
    logic [31:0] byte_len_q;
    logic [31:0] cur_src_q;
    logic [31:0] cur_dst_q;
    logic [31:0] bytes_rem_q;

    logic        busy_q;
    logic        done_q;
    logic        irq_en_q;
    logic        err_q;

    logic [31:0] data_buf_q;

    typedef enum logic [2:0] {
        ST_IDLE      = 3'd0,
        ST_READ_REQ  = 3'd1,
        ST_READ_ACK  = 3'd2,
        ST_WRITE_REQ = 3'd3,
        ST_WRITE_ACK = 3'd4,
        ST_DONE      = 3'd5
    } dma_state_e;

    dma_state_e state_q;

    assign dma_irq_o = irq_en_q && done_q;

    // -------------------------------------------------------------
    // Wishbone Slave: Configuration Registers
    // -------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            s_wb_rsp_o <= WB_RSP_IDLE;
            src_addr_q <= 32'd0;
            dst_addr_q <= 32'd0;
            byte_len_q <= 32'd0;
            irq_en_q   <= 1'b0;
        end else begin
            s_wb_rsp_o.ack <= 1'b0;
            s_wb_rsp_o.err <= 1'b0;

            if (s_wb_req_i.cyc && s_wb_req_i.stb && !s_wb_rsp_o.ack) begin
                s_wb_rsp_o.ack <= 1'b1;

                if (s_wb_req_i.we) begin
                    case (s_wb_req_i.adr[3:0])
                        REG_SRC:  src_addr_q <= s_wb_req_i.dat_w;
                        REG_DST:  dst_addr_q <= s_wb_req_i.dat_w;
                        REG_LEN:  byte_len_q <= s_wb_req_i.dat_w;
                        REG_CTRL: begin
                            irq_en_q <= s_wb_req_i.dat_w[3];
                        end
                        default: ;
                    endcase
                end else begin
                    case (s_wb_req_i.adr[3:0])
                        REG_SRC:  s_wb_rsp_o.dat_r <= src_addr_q;
                        REG_DST:  s_wb_rsp_o.dat_r <= dst_addr_q;
                        REG_LEN:  s_wb_rsp_o.dat_r <= bytes_rem_q;
                        REG_CTRL: s_wb_rsp_o.dat_r <= {27'd0, err_q, irq_en_q, done_q, busy_q, 1'b0};
                        default:  s_wb_rsp_o.dat_r <= 32'd0;
                    endcase
                end
            end
        end
    end

    // Detect START strobe from CPU write
    wire dma_start_pulse = (s_wb_req_i.cyc && s_wb_req_i.stb && s_wb_req_i.we &&
                           (s_wb_req_i.adr[3:0] == REG_CTRL) && s_wb_req_i.dat_w[0] &&
                           (state_q == ST_IDLE));

    // -------------------------------------------------------------
    // Wishbone Master: DMA Transfer Engine
    // -------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q     <= ST_IDLE;
            m_wb_req_o  <= WB_REQ_IDLE;
            cur_src_q   <= 32'd0;
            cur_dst_q   <= 32'd0;
            bytes_rem_q <= 32'd0;
            data_buf_q  <= 32'd0;
            busy_q      <= 1'b0;
            done_q      <= 1'b0;
            err_q       <= 1'b0;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    m_wb_req_o <= WB_REQ_IDLE;
                    if (dma_start_pulse && (byte_len_q != 32'd0)) begin
                        cur_src_q   <= src_addr_q;
                        cur_dst_q   <= dst_addr_q;
                        bytes_rem_q <= byte_len_q;
                        busy_q      <= 1'b1;
                        done_q      <= 1'b0;
                        err_q       <= 1'b0;
                        state_q     <= ST_READ_REQ;
                    end
                end

                ST_READ_REQ: begin
                    m_wb_req_o.cyc   <= 1'b1;
                    m_wb_req_o.stb   <= 1'b1;
                    m_wb_req_o.we    <= 1'b0;
                    m_wb_req_o.adr   <= cur_src_q;
                    m_wb_req_o.sel   <= 4'b1111;
                    m_wb_req_o.dat_w <= 32'd0;
                    state_q          <= ST_READ_ACK;
                end

                ST_READ_ACK: begin
                    if (m_wb_rsp_i.err) begin
                        m_wb_req_o <= WB_REQ_IDLE;
                        err_q      <= 1'b1;
                        busy_q     <= 1'b0;
                        state_q    <= ST_IDLE;
                    end else if (m_wb_rsp_i.ack) begin
                        data_buf_q <= m_wb_rsp_i.dat_r;
                        m_wb_req_o <= WB_REQ_IDLE;
                        state_q    <= ST_WRITE_REQ;
                    end
                end

                ST_WRITE_REQ: begin
                    m_wb_req_o.cyc   <= 1'b1;
                    m_wb_req_o.stb   <= 1'b1;
                    m_wb_req_o.we    <= 1'b1;
                    m_wb_req_o.adr   <= cur_dst_q;
                    m_wb_req_o.sel   <= 4'b1111;
                    m_wb_req_o.dat_w <= data_buf_q;
                    state_q          <= ST_WRITE_ACK;
                end

                ST_WRITE_ACK: begin
                    if (m_wb_rsp_i.err) begin
                        m_wb_req_o <= WB_REQ_IDLE;
                        err_q      <= 1'b1;
                        busy_q     <= 1'b0;
                        state_q    <= ST_IDLE;
                    end else if (m_wb_rsp_i.ack) begin
                        m_wb_req_o <= WB_REQ_IDLE;
                        cur_src_q  <= cur_src_q + 32'd4;
                        cur_dst_q  <= cur_dst_q + 32'd4;

                        if (bytes_rem_q <= 32'd4) begin
                            bytes_rem_q <= 32'd0;
                            busy_q      <= 1'b0;
                            done_q      <= 1'b1;
                            state_q     <= ST_DONE;
                        end else begin
                            bytes_rem_q <= bytes_rem_q - 32'd4;
                            state_q     <= ST_READ_REQ;
                        end
                    end
                end

                ST_DONE: begin
                    state_q <= ST_IDLE;
                end

                default: state_q <= ST_IDLE;
            endcase
        end
    end

endmodule
