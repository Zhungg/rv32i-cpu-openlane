`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_soc.sv
// Module : rv32i_soc
//
// Synthesizable top-level SoC integrating rv32i_core, Instruction ROM,
// Data RAM, Address Decoder, UART, and Timer peripherals.

module rv32i_soc
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
#(
    parameter int unsigned IMEM_SIZE_BYTES = 65536,
    parameter int unsigned DMEM_SIZE_BYTES = 65536,
    parameter              IMEM_HEX_FILE   = "",
    parameter              DMEM_HEX_FILE   = "",
    parameter logic [15:0] UART_DIVIDER    = 16'd16
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,

    // UART Serial Interface
    input  logic                             uart_rx_i,
    output logic                             uart_tx_o,

    // General Purpose Outputs / Status
    output logic [7:0]                       gpio_o,

    // Debug / Commit Verification Interface
    output logic                             commit_valid_o,
    output logic                             commit_trap_o,
    output addr_t                            commit_pc_o,
    output addr_t                            commit_next_pc_o,
    output insn_t                            commit_instruction_o,
    output logic                             commit_rd_write_o,
    output reg_idx_t                         commit_rd_index_o,
    output xlen_t                            commit_rd_data_o
);

    // Synchronized Reset
    logic        rst_sync_n;
    logic [31:0] boot_vector;

    rv32i_boot_controller u_boot (
        .clk_i         (clk_i),
        .rst_async_ni  (rst_ni),
        .rst_sync_no   (rst_sync_n),
        .boot_vector_o (boot_vector)
    );

    // IMEM Interconnect
    logic           imem_req_valid;
    logic           imem_req_ready;
    imem_request_t  imem_req;

    logic           imem_rsp_valid;
    logic           imem_rsp_ready;
    imem_response_t imem_rsp;

    // Core DMEM Interconnect
    logic           core_dmem_req_valid;
    logic           core_dmem_req_ready;
    dmem_request_t  core_dmem_req;

    logic           core_dmem_rsp_valid;
    logic           core_dmem_rsp_ready;
    dmem_response_t core_dmem_rsp;

    // Peripherals DMEM Interconnects
    logic           dmem_req_valid, dmem_req_ready, dmem_rsp_valid, dmem_rsp_ready;
    dmem_request_t  dmem_req;
    dmem_response_t dmem_rsp;

    logic           uart_req_valid, uart_req_ready, uart_rsp_valid, uart_rsp_ready;
    dmem_request_t  uart_req;
    dmem_response_t uart_rsp;
    logic           uart_irq;

    logic           timer_req_valid, timer_req_ready, timer_rsp_valid, timer_rsp_ready;
    dmem_request_t  timer_req;
    dmem_response_t timer_rsp;
    logic           timer_irq;

    // Instantiate RV32I Core
    rv32i_core #(
        .RESET_VECTOR (32'h0000_0000),
        .TRAP_VECTOR  (32'h0000_0100)
    ) u_core (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_sync_n),

        .imem_req_valid_o        (imem_req_valid),
        .imem_req_ready_i        (imem_req_ready),
        .imem_req_o              (imem_req),

        .imem_rsp_valid_i        (imem_rsp_valid),
        .imem_rsp_ready_o        (imem_rsp_ready),
        .imem_rsp_i              (imem_rsp),

        .dmem_req_valid_o        (core_dmem_req_valid),
        .dmem_req_ready_i        (core_dmem_req_ready),
        .dmem_req_o              (core_dmem_req),

        .dmem_rsp_valid_i        (core_dmem_rsp_valid),
        .dmem_rsp_ready_o        (core_dmem_rsp_ready),
        .dmem_rsp_i              (core_dmem_rsp),

        .commit_valid_o          (commit_valid_o),
        .commit_trap_o           (commit_trap_o),
        .commit_pc_o             (commit_pc_o),
        .commit_next_pc_o        (commit_next_pc_o),
        .commit_instruction_o    (commit_instruction_o),
        .commit_rd_write_o       (commit_rd_write_o),
        .commit_rd_index_o       (commit_rd_index_o),
        .commit_rd_data_o        (commit_rd_data_o),

        .baseline_stall_o        (),
        .debug_redirect_valid_o  (),
        .debug_redirect_pc_o     ()
    );

    // Instruction Memory Wrapper
    rv32i_imem_wrapper #(
        .MEM_SIZE_BYTES (IMEM_SIZE_BYTES),
        .INIT_HEX_FILE  (IMEM_HEX_FILE)
    ) u_imem (
        .clk_i            (clk_i),
        .rst_ni           (rst_sync_n),

        .imem_req_valid_i (imem_req_valid),
        .imem_req_ready_o (imem_req_ready),
        .imem_req_i       (imem_req),

        .imem_rsp_valid_o (imem_rsp_valid),
        .imem_rsp_ready_i (imem_rsp_ready),
        .imem_rsp_o       (imem_rsp)
    );

    // Address Decoder & Crossbar
    rv32i_address_decoder u_address_decoder (
        .clk_i             (clk_i),
        .rst_ni            (rst_sync_n),

        .core_req_valid_i  (core_dmem_req_valid),
        .core_req_ready_o  (core_dmem_req_ready),
        .core_req_i        (core_dmem_req),

        .core_rsp_valid_o  (core_dmem_rsp_valid),
        .core_rsp_ready_i  (core_dmem_rsp_ready),
        .core_rsp_o        (core_dmem_rsp),

        .dmem_req_valid_o  (dmem_req_valid),
        .dmem_req_ready_i  (dmem_req_ready),
        .dmem_req_o        (dmem_req),

        .dmem_rsp_valid_i  (dmem_rsp_valid),
        .dmem_rsp_ready_o  (dmem_rsp_ready),
        .dmem_rsp_i        (dmem_rsp),

        .uart_req_valid_o  (uart_req_valid),
        .uart_req_ready_i  (uart_req_ready),
        .uart_req_o        (uart_req),

        .uart_rsp_valid_i  (uart_rsp_valid),
        .uart_rsp_ready_o  (uart_rsp_ready),
        .uart_rsp_i        (uart_rsp),

        .timer_req_valid_o (timer_req_valid),
        .timer_req_ready_i (timer_req_ready),
        .timer_req_o       (timer_req),

        .timer_rsp_valid_i (timer_rsp_valid),
        .timer_rsp_ready_o (timer_rsp_ready),
        .timer_rsp_i       (timer_rsp)
    );

    // Data Memory Wrapper (RAM)
    rv32i_dmem_wrapper #(
        .MEM_SIZE_BYTES (DMEM_SIZE_BYTES),
        .INIT_HEX_FILE  (DMEM_HEX_FILE)
    ) u_dmem (
        .clk_i            (clk_i),
        .rst_ni           (rst_sync_n),

        .dmem_req_valid_i (dmem_req_valid),
        .dmem_req_ready_o (dmem_req_ready),
        .dmem_req_i       (dmem_req),

        .dmem_rsp_valid_o (dmem_rsp_valid),
        .dmem_rsp_ready_i (dmem_rsp_ready),
        .dmem_rsp_o       (dmem_rsp)
    );

    // UART Peripheral
    rv32i_uart #(
        .DEFAULT_DIVIDER (UART_DIVIDER)
    ) u_uart (
        .clk_i       (clk_i),
        .rst_ni      (rst_sync_n),

        .req_valid_i (uart_req_valid),
        .req_ready_o (uart_req_ready),
        .req_i       (uart_req),

        .rsp_valid_o (uart_rsp_valid),
        .rsp_ready_i (uart_rsp_ready),
        .rsp_o       (uart_rsp),

        .uart_rx_i  (uart_rx_i),
        .uart_tx_o  (uart_tx_o),
        .uart_irq_o (uart_irq)
    );

    // Timer Peripheral
    rv32i_timer u_timer (
        .clk_i       (clk_i),
        .rst_ni      (rst_sync_n),

        .req_valid_i (timer_req_valid),
        .req_ready_o (timer_req_ready),
        .req_i       (timer_req),

        .rsp_valid_o (timer_rsp_valid),
        .rsp_ready_i (timer_rsp_ready),
        .rsp_o       (timer_rsp),

        .timer_irq_o (timer_irq)
    );

    // Status GPIO assignment
    assign gpio_o = {commit_trap_o, commit_valid_o, timer_irq, uart_irq, 4'b0000};

endmodule
