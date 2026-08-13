`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/integration/tb_rv32i_soc.sv
// Module : tb_rv32i_soc
//
// Self-checking integration testbench for rv32i_soc.

module tb_rv32i_soc;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;

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
    logic [7:0]  received_chars [0:31];

    logic [31:0] x12_val;
    logic [31:0] x13_val;
    logic        seen_x12_write;
    logic        seen_x13_write;

    // Clock generation (50MHz = 20ns period)
    always #10 clk = ~clk;

    // Instantiate SoC
    rv32i_soc #(
        .IMEM_SIZE_BYTES (65536),
        .DMEM_SIZE_BYTES (65536),
        .UART_DIVIDER    (16'd4)
    ) dut (
        .clk_i                (clk),
        .rst_ni               (rst_n),

        .uart_rx_i            (uart_rx),
        .uart_tx_o            (uart_tx),
        .gpio_o               (gpio),

        .commit_valid_o       (commit_valid),
        .commit_trap_o        (commit_trap),
        .commit_pc_o          (commit_pc),
        .commit_next_pc_o     (commit_next_pc),
        .commit_instruction_o (commit_instruction),
        .commit_rd_write_o    (commit_rd_write),
        .commit_rd_index_o    (commit_rd_index),
        .commit_rd_data_o     (commit_rd_data)
    );

    // Helpers to assemble RV32I instructions for test
    function automatic insn_t make_u(input logic [19:0] imm, input logic [4:0] rd, input opcode_t op);
        make_u = {imm, rd, op};
    endfunction

    function automatic insn_t make_i(input logic [11:0] imm, input logic [4:0] rs1, input logic [2:0] f3, input logic [4:0] rd, input opcode_t op);
        make_i = {imm, rs1, f3, rd, op};
    endfunction

    function automatic insn_t make_s(input logic [11:0] imm, input logic [4:0] rs2, input logic [4:0] rs1, input logic [2:0] f3, input opcode_t op);
        make_s = {imm[11:5], rs2, rs1, f3, imm[4:0], op};
    endfunction

    function automatic insn_t make_b(input logic [12:0] imm, input logic [4:0] rs2, input logic [4:0] rs1, input logic [2:0] f3, input opcode_t op);
        make_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], op};
    endfunction

    // Track architectural writebacks from commit bus
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x12_val        <= '0;
            x13_val        <= '0;
            seen_x12_write <= 1'b0;
            seen_x13_write <= 1'b0;
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
            prev_tx_busy <= dut.u_uart.tx_busy;

            // Trigger when UART finishes transmitting a byte (falling edge of tx_busy)
            if (prev_tx_busy && !dut.u_uart.tx_busy) begin
                $display("[UART Monitor] Transmitted char: '%c' (0x%02h)",
                         dut.u_uart.tx_data_q, dut.u_uart.tx_data_q);
                $fflush();
                if (uart_char_count < 32) begin
                    received_chars[uart_char_count] <= dut.u_uart.tx_data_q;
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

        $display("=================================================");
        $display("Starting RV32I SoC Integration Verification Test");
        $display("=================================================");

        // Pre-populate Instruction ROM with test program
        for (i = 0; i < 16384; i++) begin
            dut.u_imem.mem[i] = 32'h0000_0013; // NOP
        end

        // Program sequence:
        // 1. Setup UART base x1 = 0x4000_0000
        dut.u_imem.mem[0] = make_u(20'h40000, 5'd1, OPCODE_LUI);

        // 2. Set UART divider x2 = 4 -> store to 0x4000_000C
        dut.u_imem.mem[1] = make_i(12'd4, 5'd0, FUNCT3_ADD_SUB, 5'd2, OPCODE_OP_IMM);
        dut.u_imem.mem[2] = make_s(12'h00C, 5'd2, 5'd1, FUNCT3_SW, OPCODE_STORE);

        // 3. Write 'H' (0x48) to UART DATA 0x4000_0000
        dut.u_imem.mem[3] = make_i(12'h048, 5'd0, FUNCT3_ADD_SUB, 5'd3, OPCODE_OP_IMM);
        dut.u_imem.mem[4] = make_s(12'h000, 5'd3, 5'd1, FUNCT3_SW, OPCODE_STORE);

        // 4. Wait for UART TX ready: loop reading 0x4000_0004
        // LW x4, 4(x1)
        dut.u_imem.mem[5] = make_i(12'h004, 5'd1, FUNCT3_LW, 5'd4, OPCODE_LOAD);
        // ANDI x4, x4, 1
        dut.u_imem.mem[6] = make_i(12'd1, 5'd4, FUNCT3_AND, 5'd4, OPCODE_OP_IMM);
        // BNE x4, zero, -8 (back to LW at mem[5])
        dut.u_imem.mem[7] = make_b(13'h1ff8, 5'd0, 5'd4, FUNCT3_BNE, OPCODE_BRANCH);

        // 5. Write 'I' (0x49) to UART DATA 0x4000_0000
        dut.u_imem.mem[8] = make_i(12'h049, 5'd0, FUNCT3_ADD_SUB, 5'd3, OPCODE_OP_IMM);
        dut.u_imem.mem[9] = make_s(12'h000, 5'd3, 5'd1, FUNCT3_SW, OPCODE_STORE);

        // 6. RAM test: Base RAM x10 = 0x2000_0000
        dut.u_imem.mem[10] = make_u(20'h20000, 5'd10, OPCODE_LUI);
        // x11 = 0x1234_5678 (LUI + ADDI)
        dut.u_imem.mem[11] = make_u(20'h12345, 5'd11, OPCODE_LUI);
        dut.u_imem.mem[12] = make_i(12'h678, 5'd11, FUNCT3_ADD_SUB, 5'd11, OPCODE_OP_IMM);
        // SW x11, 0(x10)
        dut.u_imem.mem[13] = make_s(12'h000, 5'd11, 5'd10, FUNCT3_SW, OPCODE_STORE);
        // LW x12, 0(x10)
        dut.u_imem.mem[14] = make_i(12'h000, 5'd10, FUNCT3_LW, 5'd12, OPCODE_LOAD);

        // 7. Timer test: Read mtime_l from 0x4000_1000 into x13
        dut.u_imem.mem[15] = make_u(20'h40001, 5'd14, OPCODE_LUI);
        dut.u_imem.mem[16] = make_i(12'h000, 5'd14, FUNCT3_LW, 5'd13, OPCODE_LOAD);

        // Infinite loop done
        dut.u_imem.mem[17] = make_b(13'd0, 5'd0, 5'd0, FUNCT3_BEQ, OPCODE_BRANCH);

        // Hold reset for 5 cycles
        repeat (5) @(posedge clk);
        rst_n = 1;

        $display("Reset released. SoC CPU running...");

        // Wait for CPU to execute instructions and UART characters
        repeat (220) @(posedge clk);

        // Check RAM readback in x12
        if (!seen_x12_write || x12_val !== 32'h1234_5678) begin
            $display("FAIL: RAM readback in x12 mismatch: seen=%0d, Expected 0x12345678, Got 0x%08x",
                     seen_x12_write, x12_val);
            error_count++;
        end else begin
            $display("PASS: RAM Store and Load verification succeeded (0x12345678).");
        end

        // Check Timer readback in x13
        if (!seen_x13_write || x13_val === 32'd0) begin
            $display("FAIL: Timer readback in x13 failed: seen=%0d, value=0x%08x",
                     seen_x13_write, x13_val);
            error_count++;
        end else begin
            $display("PASS: Timer readback succeeded (mtime_l = %0d ticks).", x13_val);
        end

        // Check UART chars
        if (uart_char_count >= 2 && received_chars[0] == 8'h48 && received_chars[1] == 8'h49) begin
            $display("PASS: UART transmitted expected characters: 'HI'");
        end else begin
            $display("FAIL: UART chars count=%0d (Expected at least 2: 'H', 'I')", uart_char_count);
            error_count++;
        end

        $display("=================================================");
        if (error_count == 0) begin
            $display("RV32I SoC Integration Test: ALL CHECKS PASSED!");
            $display("=================================================");
            $finish;
        end else begin
            $display("RV32I SoC Integration Test: FAILED with %0d errors", error_count);
            $display("=================================================");
            $fatal(1, "SoC Integration Regression Failed.");
        end
    end

endmodule
