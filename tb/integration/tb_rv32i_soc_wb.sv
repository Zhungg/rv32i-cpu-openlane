`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/integration/tb_rv32i_soc_wb.sv
// Module : tb_rv32i_soc_wb
//
// Comprehensive self-checking testbench for Phase 2 Wishbone RV32I SoC with DMA.

module tb_rv32i_soc_wb;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;

    logic        clk;
    logic        rst_n;
    logic        uart_rx;
    wire         uart_tx;
    wire [7:0]   gpio;

    logic        commit_valid;
    logic        commit_trap;
    addr_t       commit_pc;
    addr_t       commit_next_pc;
    insn_t       commit_instruction;
    logic        commit_rd_write;
    reg_idx_t    commit_rd_index;
    xlen_t       commit_rd_data;

    int unsigned error_count;
    int unsigned uart_char_count;
    byte         received_chars [0:31];

    xlen_t       x12_val, x13_val, x15_val;
    logic        seen_x12_write, seen_x13_write, seen_x15_write;

    // DUT Instantiation
    rv32i_soc_wb #(
        .IMEM_SIZE_BYTES (65536),
        .DMEM_SIZE_BYTES (65536),
        .UART_DIVIDER    (16'd4) // Fast baud divider for simulation
    ) dut (
        .clk_i                (clk),
        .rst_ni               (rst_n),
        .uart_rx_i           (uart_rx),
        .uart_tx_o           (uart_tx),
        .gpio_o              (gpio),
        .commit_valid_o       (commit_valid),
        .commit_trap_o        (commit_trap),
        .commit_pc_o          (commit_pc),
        .commit_next_pc_o     (commit_next_pc),
        .commit_instruction_o (commit_instruction),
        .commit_rd_write_o    (commit_rd_write),
        .commit_rd_index_o    (commit_rd_index),
        .commit_rd_data_o     (commit_rd_data)
    );

    // 50MHz Clock (20ns period)
    always #10 clk = ~clk;

    // Helper functions for RISC-V instruction encoding
    function automatic insn_t make_u(input logic [19:0] imm, input logic [4:0] rd, input logic [6:0] op);
        make_u = {imm, rd, op};
    endfunction

    function automatic insn_t make_i(input logic [11:0] imm, input logic [4:0] rs1, input logic [2:0] f3, input logic [4:0] rd, input logic [6:0] op);
        make_i = {imm, rs1, f3, rd, op};
    endfunction

    function automatic insn_t make_s(input logic [11:0] imm, input logic [4:0] rs2, input logic [4:0] rs1, input logic [2:0] f3, input logic [6:0] op);
        make_s = {imm[11:5], rs2, rs1, f3, imm[4:0], op};
    endfunction

    function automatic insn_t make_b(input logic [12:0] imm, input logic [4:0] rs2, input logic [4:0] rs1, input logic [2:0] f3, input logic [6:0] op);
        make_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], op};
    endfunction

    // Track register writes from commit bus
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x12_val        <= '0;
            x13_val        <= '0;
            x15_val        <= '0;
            seen_x12_write <= 1'b0;
            seen_x13_write <= 1'b0;
            seen_x15_write <= 1'b0;
        end else begin
            if (commit_valid && commit_rd_write) begin
                $display("[CPU Commit] PC=0x%08h Inst=0x%08h Rd=%0d Data=0x%08h",
                         commit_pc, commit_instruction, commit_rd_index, commit_rd_data);
                $fflush();
                if (commit_rd_index == 5'd12) begin
                    x12_val        <= commit_rd_data;
                    seen_x12_write <= 1'b1;
                end
                if (commit_rd_index == 5'd13) begin
                    x13_val        <= commit_rd_data;
                    seen_x13_write <= 1'b1;
                end
                if (commit_rd_index == 5'd15) begin
                    x15_val        <= commit_rd_data;
                    seen_x15_write <= 1'b1;
                end
            end
        end
    end

    // Synchronous UART transmission monitor
    logic prev_tx_busy;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_tx_busy    <= 1'b0;
            uart_char_count <= 0;
        end else begin
            prev_tx_busy <= dut.u_uart_wb.tx_busy;

            if (prev_tx_busy && !dut.u_uart_wb.tx_busy) begin
                $display("[UART Monitor] Transmitted char: '%c' (0x%02h)",
                         dut.u_uart_wb.tx_data_q, dut.u_uart_wb.tx_data_q);
                $fflush();
                if (uart_char_count < 32) begin
                    received_chars[uart_char_count] <= dut.u_uart_wb.tx_data_q;
                    uart_char_count                 <= uart_char_count + 1;
                end
            end
        end
    end

    initial begin
        int i;
        clk         = 0;
        rst_n       = 0;
        uart_rx     = 1;
        error_count = 0;

        $display("==========================================================");
        $display("Starting Wishbone RV32I SoC with DMA Integration Test");
        $display("==========================================================");

        // Pre-populate Instruction ROM with test program
        for (i = 0; i < 16384; i++) begin
            dut.u_imem.mem[i] = 32'h0000_0013; // NOP
        end

        // -------------------------------------------------------------
        // Test Program Sequence:
        // -------------------------------------------------------------
        // 1. Setup UART: x1 = 0x4000_0000, Set DIV=4
        dut.u_imem.mem[0] = make_u(20'h40000, 5'd1, OPCODE_LUI);
        dut.u_imem.mem[1] = make_i(12'd4, 5'd0, FUNCT3_ADD_SUB, 5'd2, OPCODE_OP_IMM);
        dut.u_imem.mem[2] = make_s(12'h00C, 5'd2, 5'd1, FUNCT3_SW, OPCODE_STORE);

        // 2. Write test pattern to RAM Buffer A (0x2000_0100)
        // x10 = 0x2000_0000
        dut.u_imem.mem[3] = make_u(20'h20000, 5'd10, OPCODE_LUI);
        // x11 = 0x55AA_33CC (Test Pattern)
        dut.u_imem.mem[4] = make_u(20'h55AA3, 5'd11, OPCODE_LUI);
        dut.u_imem.mem[5] = make_i(12'h3CC, 5'd11, FUNCT3_ADD_SUB, 5'd11, OPCODE_OP_IMM);
        // SW x11, 0x100(x10) -> Store to 0x2000_0100
        dut.u_imem.mem[6] = make_s(12'h100, 5'd11, 5'd10, FUNCT3_SW, OPCODE_STORE);

        // 3. Configure DMA Controller at 0x4000_2000:
        // x3 = 0x4000_2000
        dut.u_imem.mem[7] = make_u(20'h40002, 5'd3, OPCODE_LUI);
        // DMA_SRC = 0x2000_0100 (x4)
        dut.u_imem.mem[8] = make_i(12'h100, 5'd10, FUNCT3_ADD_SUB, 5'd4, OPCODE_OP_IMM);
        dut.u_imem.mem[9] = make_s(12'h000, 5'd4, 5'd3, FUNCT3_SW, OPCODE_STORE);
        // DMA_DST = 0x2000_0200 (x5)
        dut.u_imem.mem[10] = make_i(12'h200, 5'd10, FUNCT3_ADD_SUB, 5'd5, OPCODE_OP_IMM);
        dut.u_imem.mem[11] = make_s(12'h004, 5'd5, 5'd3, FUNCT3_SW, OPCODE_STORE);
        // DMA_LEN = 4 bytes (x6)
        dut.u_imem.mem[12] = make_i(12'd4, 5'd0, FUNCT3_ADD_SUB, 5'd6, OPCODE_OP_IMM);
        dut.u_imem.mem[13] = make_s(12'h008, 5'd6, 5'd3, FUNCT3_SW, OPCODE_STORE);
        // DMA_CTRL = START (1) (x7)
        dut.u_imem.mem[14] = make_i(12'd1, 5'd0, FUNCT3_ADD_SUB, 5'd7, OPCODE_OP_IMM);
        dut.u_imem.mem[15] = make_s(12'h00C, 5'd7, 5'd3, FUNCT3_SW, OPCODE_STORE);

        // 4. Poll DMA busy: loop reading DMA_CTRL until busy bit is 0
        // LW x8, 12(x3)
        dut.u_imem.mem[16] = make_i(12'h00C, 5'd3, FUNCT3_LW, 5'd8, OPCODE_LOAD);
        // ANDI x8, x8, 2 (BUSY bit)
        dut.u_imem.mem[17] = make_i(12'd2, 5'd8, FUNCT3_AND, 5'd8, OPCODE_OP_IMM);
        // BNE x8, zero, -8 (back to LW at mem[16])
        dut.u_imem.mem[18] = make_b(13'h1ff8, 5'd0, 5'd8, FUNCT3_BNE, OPCODE_BRANCH);

        // 5. Read back Destination Buffer from RAM at 0x2000_0200 into x12
        dut.u_imem.mem[19] = make_i(12'h200, 5'd10, FUNCT3_LW, 5'd12, OPCODE_LOAD);

        // 6. Read 64-bit Timer into x13
        dut.u_imem.mem[20] = make_u(20'h40001, 5'd14, OPCODE_LUI);
        dut.u_imem.mem[21] = make_i(12'h000, 5'd14, FUNCT3_LW, 5'd13, OPCODE_LOAD);

        // 7. Write 'D' (0x44) to UART DATA 0x4000_0000
        dut.u_imem.mem[22] = make_i(12'h044, 5'd0, FUNCT3_ADD_SUB, 5'd9, OPCODE_OP_IMM);
        dut.u_imem.mem[23] = make_s(12'h000, 5'd9, 5'd1, FUNCT3_SW, OPCODE_STORE);

        // Infinite loop done
        dut.u_imem.mem[24] = make_b(13'd0, 5'd0, 5'd0, FUNCT3_BEQ, OPCODE_BRANCH);

        // Reset sequence
        repeat (5) @(posedge clk);
        rst_n = 1;
        $display("Reset released. Wishbone SoC CPU & DMA running...");

        // Wait for execution
        repeat (300) @(posedge clk);

        // -------------------------------------------------------------
        // Verifications
        // -------------------------------------------------------------
        // Verify DMA transferred 0x55AA33CC to destination address 0x2000_0200
        if (!seen_x12_write || x12_val !== 32'h55AA_33CC) begin
            $display("FAIL: DMA transfer verification in x12 mismatch: seen=%0d, Expected 0x55AA33CC, Got 0x%08x",
                     seen_x12_write, x12_val);
            error_count++;
        end else begin
            $display("PASS: DMA Autonomous Memory-to-Memory Transfer verified (0x%08x copied accurately).", x12_val);
        end

        // Verify Timer readback
        if (!seen_x13_write || x13_val === 32'd0) begin
            $display("FAIL: Wishbone Timer readback in x13 failed: seen=%0d, value=0x%08x",
                     seen_x13_write, x13_val);
            error_count++;
        end else begin
            $display("PASS: Wishbone Timer readback verified (mtime_l = %0d ticks).", x13_val);
        end

        // Verify UART output
        if (uart_char_count < 1 || received_chars[0] != 8'h44) begin
            $display("FAIL: Wishbone UART char mismatch: count=%0d, char[0]=0x%02x (Expected 'D' 0x44)",
                     uart_char_count, received_chars[0]);
            error_count++;
        end else begin
            $display("PASS: Wishbone UART transmitted expected character: '%c'", received_chars[0]);
        end

        $display("==========================================================");
        if (error_count == 0) begin
            $display("Wishbone RV32I SoC with DMA Regression: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("Wishbone RV32I SoC with DMA Regression: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
