`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_uart_wb.sv
// Module : rv32i_uart_wb
//
// Wishbone B4 Slave interface for UART Controller.

module rv32i_uart_wb
    import rv32i_wishbone_pkg::*;
#(
    parameter logic [15:0] DEFAULT_DIVIDER = 16'd434
) (
    input  logic    clk_i,
    input  logic    rst_ni,

    // Wishbone Slave
    input  wb_req_t wb_req_i,
    output wb_rsp_t wb_rsp_o,

    // Physical UART Pins
    input  logic    uart_rx_i,
    output logic    uart_tx_o,
    output logic    uart_irq_o
);

    localparam logic [3:0] REG_DATA   = 4'h0;
    localparam logic [3:0] REG_STATUS = 4'h4;
    localparam logic [3:0] REG_CTRL   = 4'h8;
    localparam logic [3:0] REG_DIV    = 4'hC;

    typedef enum logic [1:0] {
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3
    } tx_state_e;

    typedef enum logic [1:0] {
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3
    } rx_state_e;

    logic [15:0] div_q;
    logic        tx_en_q, rx_en_q;

    tx_state_e   tx_state_q;
    logic [15:0] tx_clk_cnt_q;
    logic [2:0]  tx_bit_cnt_q;
    logic [7:0]  tx_data_q;
    logic        tx_out_q;

    rx_state_e   rx_state_q;
    logic [15:0] rx_clk_cnt_q;
    logic [2:0]  rx_bit_cnt_q;
    logic [7:0]  rx_data_q;
    logic [7:0]  rx_buf_q;
    logic        rx_valid_q;
    logic        rx_sync_1_q, rx_sync_2_q;

    assign uart_tx_o  = tx_out_q;
    assign uart_irq_o = rx_valid_q;

    wire tx_busy  = (tx_state_q != TX_IDLE);
    wire tx_ready = !tx_busy;

    // RX synchronizer
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync_1_q <= 1'b1;
            rx_sync_2_q <= 1'b1;
        end else begin
            rx_sync_1_q <= uart_rx_i;
            rx_sync_2_q <= rx_sync_1_q;
        end
    end

    // Wishbone bus transactions & Baud generation
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_rsp_o     <= WB_RSP_IDLE;
            div_q        <= DEFAULT_DIVIDER;
            tx_en_q      <= 1'b1;
            rx_en_q      <= 1'b1;
            tx_state_q   <= TX_IDLE;
            tx_clk_cnt_q <= '0;
            tx_bit_cnt_q <= '0;
            tx_data_q    <= '0;
            tx_out_q     <= 1'b1;
            rx_state_q   <= RX_IDLE;
            rx_clk_cnt_q <= '0;
            rx_bit_cnt_q <= '0;
            rx_data_q    <= '0;
            rx_buf_q     <= '0;
            rx_valid_q   <= 1'b0;
        end else begin
            wb_rsp_o.ack <= 1'b0;
            wb_rsp_o.err <= 1'b0;

            // Wishbone Read / Write
            if (wb_req_i.cyc && wb_req_i.stb && !wb_rsp_o.ack) begin
                wb_rsp_o.ack <= 1'b1;

                if (wb_req_i.we) begin
                    case (wb_req_i.adr[3:0])
                        REG_DATA: begin
                            if (tx_ready && tx_en_q) begin
                                tx_data_q    <= wb_req_i.dat_w[7:0];
                                tx_state_q   <= TX_START;
                                tx_clk_cnt_q <= '0;
                                tx_bit_cnt_q <= '0;
                            end
                        end
                        REG_CTRL: begin
                            tx_en_q <= wb_req_i.dat_w[0];
                            rx_en_q <= wb_req_i.dat_w[1];
                        end
                        REG_DIV: begin
                            div_q <= wb_req_i.dat_w[15:0];
                        end
                        default: ;
                    endcase
                end else begin
                    case (wb_req_i.adr[3:0])
                        REG_DATA: begin
                            wb_rsp_o.dat_r <= {24'd0, rx_buf_q};
                            rx_valid_q     <= 1'b0; // Clear RX valid on read
                        end
                        REG_STATUS: wb_rsp_o.dat_r <= {28'd0, 1'b0, 1'b0, rx_valid_q, tx_busy};
                        REG_CTRL:   wb_rsp_o.dat_r <= {30'd0, rx_en_q, tx_en_q};
                        REG_DIV:    wb_rsp_o.dat_r <= {16'd0, div_q};
                        default:    wb_rsp_o.dat_r <= 32'd0;
                    endcase
                end
            end

            // TX State Machine
            case (tx_state_q)
                TX_IDLE: begin
                    tx_out_q <= 1'b1;
                end

                TX_START: begin
                    tx_out_q <= 1'b0;
                    if (tx_clk_cnt_q >= div_q) begin
                        tx_clk_cnt_q <= '0;
                        tx_state_q   <= TX_DATA;
                        tx_bit_cnt_q <= '0;
                    end else begin
                        tx_clk_cnt_q <= tx_clk_cnt_q + 1'b1;
                    end
                end

                TX_DATA: begin
                    tx_out_q <= tx_data_q[tx_bit_cnt_q];
                    if (tx_clk_cnt_q >= div_q) begin
                        tx_clk_cnt_q <= '0;
                        if (tx_bit_cnt_q == 3'd7) begin
                            tx_state_q <= TX_STOP;
                        end else begin
                            tx_bit_cnt_q <= tx_bit_cnt_q + 1'b1;
                        end
                    end else begin
                        tx_clk_cnt_q <= tx_clk_cnt_q + 1'b1;
                    end
                end

                TX_STOP: begin
                    tx_out_q <= 1'b1;
                    if (tx_clk_cnt_q >= div_q) begin
                        tx_clk_cnt_q <= '0;
                        tx_state_q   <= TX_IDLE;
                    end else begin
                        tx_clk_cnt_q <= tx_clk_cnt_q + 1'b1;
                    end
                end
            endcase

            // RX State Machine
            case (rx_state_q)
                RX_IDLE: begin
                    if (rx_en_q && !rx_sync_2_q) begin
                        rx_state_q   <= RX_START;
                        rx_clk_cnt_q <= '0;
                    end
                end

                RX_START: begin
                    if (rx_clk_cnt_q >= {1'b0, div_q[15:1]}) begin
                        rx_clk_cnt_q <= '0;
                        if (!rx_sync_2_q) begin
                            rx_state_q   <= RX_DATA;
                            rx_bit_cnt_q <= '0;
                        end else begin
                            rx_state_q <= RX_IDLE;
                        end
                    end else begin
                        rx_clk_cnt_q <= rx_clk_cnt_q + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt_q >= div_q) begin
                        rx_clk_cnt_q              <= '0;
                        rx_data_q[rx_bit_cnt_q]   <= rx_sync_2_q;
                        if (rx_bit_cnt_q == 3'd7) begin
                            rx_state_q <= RX_STOP;
                        end else begin
                            rx_bit_cnt_q <= rx_bit_cnt_q + 1'b1;
                        end
                    end else begin
                        rx_clk_cnt_q <= rx_clk_cnt_q + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt_q >= div_q) begin
                        rx_clk_cnt_q <= '0;
                        rx_state_q   <= RX_IDLE;
                        if (rx_sync_2_q) begin
                            rx_buf_q   <= rx_data_q;
                            rx_valid_q <= 1'b1;
                        end
                    end else begin
                        rx_clk_cnt_q <= rx_clk_cnt_q + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
