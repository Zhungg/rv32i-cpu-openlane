`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_uart.sv
// Module : rv32i_uart
//
// Synthesizable memory-mapped UART peripheral for rv32i_soc.
// Supports 8-N-1 serial communication with configurable baudrate divider.

module rv32i_uart
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
#(
    parameter logic [15:0] DEFAULT_DIVIDER = 16'd16 // Fast default for sim
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // Bus Interface
    input  logic                             req_valid_i,
    output logic                             req_ready_o,
    input  dmem_request_t                    req_i,

    output logic                             rsp_valid_o,
    input  logic                             rsp_ready_i,
    output dmem_response_t                   rsp_o,

    // Serial Pins
    input  logic                             uart_rx_i,
    output logic                             uart_tx_o,
    output logic                             uart_irq_o
);

    // Register Offsets
    localparam logic [3:0] REG_DATA   = 4'h0;
    localparam logic [3:0] REG_STATUS = 4'h4;
    localparam logic [3:0] REG_CTRL   = 4'h8;
    localparam logic [3:0] REG_DIV    = 4'hC;

    // Registers
    logic [15:0] div_q;
    logic        tx_en_q, rx_en_q;

    // TX State Machine
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_e;

    tx_state_e tx_state_q;
    logic [15:0] tx_clk_cnt_q;
    logic [2:0]  tx_bit_cnt_q;
    logic [7:0]  tx_data_q;
    logic        tx_out_q;

    // RX State Machine
    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_e;

    rx_state_e rx_state_q;
    logic [15:0] rx_clk_cnt_q;
    logic [2:0]  rx_bit_cnt_q;
    logic [7:0]  rx_data_q;
    logic [7:0]  rx_buf_q;
    logic        rx_valid_q;
    logic        rx_sync_1_q, rx_sync_2_q;

    // Bus Response Tracking
    logic          response_pending_q;
    dmem_request_t pending_req_q;

    assign req_ready_o = !response_pending_q;
    assign rsp_valid_o = response_pending_q;
    assign uart_tx_o   = tx_out_q;
    assign uart_irq_o  = rx_valid_q;

    wire tx_busy = (tx_state_q != TX_IDLE);
    wire tx_ready = !tx_busy;

    // Bus Read Data
    always_comb begin
        rsp_o       = '0;
        rsp_o.error = 1'b0;

        case (pending_req_q.address[3:0])
            REG_DATA:   rsp_o.read_data = {24'd0, rx_buf_q};
            REG_STATUS: rsp_o.read_data = {28'd0, 1'b0, 1'b0, rx_valid_q, tx_busy};
            REG_CTRL:   rsp_o.read_data = {30'd0, rx_en_q, tx_en_q};
            REG_DIV:    rsp_o.read_data = {16'd0, div_q};
            default:    rsp_o.read_data = '0;
        endcase
    end

    // RX Synchronizer
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync_1_q <= 1'b1;
            rx_sync_2_q <= 1'b1;
        end else begin
            rx_sync_1_q <= uart_rx_i;
            rx_sync_2_q <= rx_sync_1_q;
        end
    end

    // Bus Writes & State Update
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            response_pending_q <= 1'b0;
            pending_req_q      <= '0;
            div_q              <= DEFAULT_DIVIDER;
            tx_en_q            <= 1'b1;
            rx_en_q            <= 1'b1;
            tx_state_q         <= TX_IDLE;
            tx_clk_cnt_q       <= '0;
            tx_bit_cnt_q       <= '0;
            tx_data_q          <= '0;
            tx_out_q           <= 1'b1;
            rx_state_q         <= RX_IDLE;
            rx_clk_cnt_q       <= '0;
            rx_bit_cnt_q       <= '0;
            rx_data_q          <= '0;
            rx_buf_q           <= '0;
            rx_valid_q         <= 1'b0;
        end else begin
            // Bus Handshake
            if (rsp_valid_o && rsp_ready_i) begin
                response_pending_q <= 1'b0;
            end

            if (req_valid_i && req_ready_o) begin
                response_pending_q <= 1'b1;
                pending_req_q      <= req_i;

                if (req_i.write) begin
                    case (req_i.address[3:0])
                        REG_DATA: begin
                            if (tx_state_q == TX_IDLE && tx_en_q) begin
                                tx_data_q    <= req_i.write_data[7:0];
                                tx_state_q   <= TX_START;
                                tx_clk_cnt_q <= '0;
                                tx_out_q     <= 1'b0; // Start bit
                            end
                        end
                        REG_CTRL: begin
                            tx_en_q <= req_i.write_data[0];
                            rx_en_q <= req_i.write_data[1];
                        end
                        REG_DIV: begin
                            div_q <= req_i.write_data[15:0];
                        end
                        default: ;
                    endcase
                end else begin
                    // Clear rx_valid on reading data register
                    if (req_i.address[3:0] == REG_DATA) begin
                        rx_valid_q <= 1'b0;
                    end
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
                    if (rx_en_q && !rx_sync_2_q) begin // Falling edge start bit
                        rx_state_q   <= RX_START;
                        rx_clk_cnt_q <= '0;
                    end
                end

                RX_START: begin
                    // Sample at mid-bit: div_q / 2
                    if (rx_clk_cnt_q >= {1'b0, div_q[15:1]}) begin
                        rx_clk_cnt_q <= '0;
                        if (!rx_sync_2_q) begin
                            rx_state_q   <= RX_DATA;
                            rx_bit_cnt_q <= '0;
                        end else begin
                            rx_state_q <= RX_IDLE; // False start
                        end
                    end else begin
                        rx_clk_cnt_q <= rx_clk_cnt_q + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt_q >= div_q) begin
                        rx_clk_cnt_q <= '0;
                        rx_data_q[rx_bit_cnt_q] <= rx_sync_2_q;
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
                        if (rx_sync_2_q) begin // Valid stop bit
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
