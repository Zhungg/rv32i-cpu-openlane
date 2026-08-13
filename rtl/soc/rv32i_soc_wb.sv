`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_soc_wb.sv
// Module : rv32i_soc_wb
//
// Phase 2 Wishbone-enabled System-on-Chip top level for RV32I CPU with DMA engine.

module rv32i_soc_wb
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
#(
    parameter int unsigned IMEM_SIZE_BYTES = 65536,
    parameter int unsigned DMEM_SIZE_BYTES = 65536,
    parameter              IMEM_HEX_FILE   = "",
    parameter              DMEM_HEX_FILE   = "",
    parameter logic [15:0] UART_DIVIDER    = 16'd434
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // UART Physical Interface
    input  logic        uart_rx_i,
    output logic        uart_tx_o,

    // Status / GPIO Outputs
    output logic [7:0]  gpio_o,

    // Instruction Commit Trace
    output logic        commit_valid_o,
    output logic        commit_trap_o,
    output addr_t       commit_pc_o,
    output addr_t       commit_next_pc_o,
    output insn_t       commit_instruction_o,
    output logic        commit_rd_write_o,
    output reg_idx_t    commit_rd_index_o,
    output xlen_t       commit_rd_data_o
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

    // IMEM Interface
    logic           imem_req_valid, imem_req_ready, imem_rsp_valid, imem_rsp_ready;
    imem_request_t  imem_req;
    imem_response_t imem_rsp;

    // Core LSU Native Interface
    logic           core_dmem_req_valid, core_dmem_req_ready;
    dmem_request_t  core_dmem_req;
    logic           core_dmem_rsp_valid, core_dmem_rsp_ready;
    dmem_response_t core_dmem_rsp;

    // Wishbone Masters
    wb_req_t m0_cpu_req, m1_dma_req;
    wb_rsp_t m0_cpu_rsp, m1_dma_rsp;

    // Wishbone Slaves
    wb_req_t s0_dmem_req, s1_uart_req, s2_timer_req, s3_dma_req;
    wb_rsp_t s0_dmem_rsp, s1_uart_rsp, s2_timer_rsp, s3_dma_rsp;

    // Interrupts
    logic uart_irq;
    logic timer_irq;
    logic dma_irq;

    // -------------------------------------------------------------
    // Core Instance
    // -------------------------------------------------------------
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

    // -------------------------------------------------------------
    // IMEM Wrapper
    // -------------------------------------------------------------
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

    // -------------------------------------------------------------
    // CPU Wishbone Master Adapter (Master 0)
    // -------------------------------------------------------------
    rv32i_wb_master_adapter u_cpu_wb_adapter (
        .clk_i            (clk_i),
        .rst_ni           (rst_sync_n),

        .core_req_valid_i (core_dmem_req_valid),
        .core_req_ready_o (core_dmem_req_ready),
        .core_req_i       (core_dmem_req),

        .core_rsp_valid_o (core_dmem_rsp_valid),
        .core_rsp_ready_i (core_dmem_rsp_ready),
        .core_rsp_o       (core_dmem_rsp),

        .wb_req_o         (m0_cpu_req),
        .wb_rsp_i         (m0_cpu_rsp)
    );

    // -------------------------------------------------------------
    // Wishbone Interconnect (2 Masters -> 4 Slaves)
    // -------------------------------------------------------------
    rv32i_wb_interconnect u_interconnect (
        .clk_i    (clk_i),
        .rst_ni   (rst_sync_n),

        // Masters
        .m0_req_i (m0_cpu_req),
        .m0_rsp_o (m0_cpu_rsp),

        .m1_req_i (m1_dma_req),
        .m1_rsp_o (m1_dma_rsp),

        // Slaves
        .s0_req_o (s0_dmem_req),
        .s0_rsp_i (s0_dmem_rsp),

        .s1_req_o (s1_uart_req),
        .s1_rsp_i (s1_uart_rsp),

        .s2_req_o (s2_timer_req),
        .s2_rsp_i (s2_timer_rsp),

        .s3_req_o (s3_dma_req),
        .s3_rsp_i (s3_dma_rsp)
    );

    // -------------------------------------------------------------
    // Slave 0: Wishbone DMEM RAM
    // -------------------------------------------------------------
    rv32i_dmem_wb #(
        .MEM_SIZE_BYTES (DMEM_SIZE_BYTES),
        .INIT_HEX_FILE  (DMEM_HEX_FILE)
    ) u_dmem_wb (
        .clk_i    (clk_i),
        .rst_ni   (rst_sync_n),
        .wb_req_i (s0_dmem_req),
        .wb_rsp_o (s0_dmem_rsp)
    );

    // -------------------------------------------------------------
    // Slave 1: Wishbone UART
    // -------------------------------------------------------------
    rv32i_uart_wb #(
        .DEFAULT_DIVIDER (UART_DIVIDER)
    ) u_uart_wb (
        .clk_i      (clk_i),
        .rst_ni     (rst_sync_n),
        .wb_req_i   (s1_uart_req),
        .wb_rsp_o   (s1_uart_rsp),
        .uart_rx_i  (uart_rx_i),
        .uart_tx_o  (uart_tx_o),
        .uart_irq_o (uart_irq)
    );

    // -------------------------------------------------------------
    // Slave 2: Wishbone Timer
    // -------------------------------------------------------------
    rv32i_timer_wb u_timer_wb (
        .clk_i       (clk_i),
        .rst_ni      (rst_sync_n),
        .wb_req_i    (s2_timer_req),
        .wb_rsp_o    (s2_timer_rsp),
        .timer_irq_o (timer_irq)
    );

    // -------------------------------------------------------------
    // Master 1 & Slave 3: DMA Controller
    // -------------------------------------------------------------
    rv32i_dma u_dma (
        .clk_i      (clk_i),
        .rst_ni     (rst_sync_n),
        .s_wb_req_i (s3_dma_req),
        .s_wb_rsp_o (s3_dma_rsp),
        .m_wb_req_o (m1_dma_req),
        .m_wb_rsp_i (m1_dma_rsp),
        .dma_irq_o  (dma_irq)
    );

    // GPIO outputs
    assign gpio_o = {commit_trap_o, commit_valid_o, dma_irq, timer_irq, uart_irq, 3'b000};

endmodule
