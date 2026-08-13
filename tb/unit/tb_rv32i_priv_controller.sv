`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_priv_controller.sv
// Module : tb_rv32i_priv_controller
//
// Exhaustive Unit Testbench for Multi-Privilege Mode Controller (M-Mode & U-Mode).

module tb_rv32i_priv_controller;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_pmp_pkg::*;

    logic        clk;
    logic        rst_n;

    logic        trap_valid;
    logic        is_ecall;
    logic        is_mret;
    logic        is_wfi;
    xlen_t       trap_cause_in;

    logic        csr_access_valid;
    logic [11:0] csr_addr;
    logic [1:0]  mstatus_mpp;

    wire priv_mode_e priv_mode;
    wire xlen_t      trap_cause_out;
    wire             illegal_priv_op;
    wire [1:0]       mstatus_mpp_next;
    wire             mstatus_mpp_we;

    int unsigned error_count = 0;

    rv32i_priv_controller dut (
        .clk_i              (clk),
        .rst_ni             (rst_n),
        .trap_valid_i       (trap_valid),
        .is_ecall_i         (is_ecall),
        .is_mret_i          (is_mret),
        .is_wfi_i           (is_wfi),
        .trap_cause_in_i    (trap_cause_in),
        .csr_access_valid_i (csr_access_valid),
        .csr_addr_i         (csr_addr),
        .mstatus_mpp_i      (mstatus_mpp),
        .priv_mode_o        (priv_mode),
        .trap_cause_out_o   (trap_cause_out),
        .illegal_priv_op_o  (illegal_priv_op),
        .mstatus_mpp_next_o (mstatus_mpp_next),
        .mstatus_mpp_we_o   (mstatus_mpp_we)
    );

    always #10 clk = ~clk;

    initial begin
        clk              = 0;
        rst_n            = 0;
        trap_valid       = 0;
        is_ecall         = 0;
        is_mret          = 0;
        is_wfi           = 0;
        trap_cause_in    = '0;
        csr_access_valid = 0;
        csr_addr         = '0;
        mstatus_mpp      = 2'b11;

        $display("==========================================================");
        $display("Starting Multi-Privilege Controller (M & U Mode) Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: Boot into Machine Mode (PRIV_MACHINE)
        // -------------------------------------------------------------
        $display("\n[TEST 1] Boot State Verification...");
        if (priv_mode !== PRIV_MACHINE) begin
            $display("FAIL: CPU did not boot into Machine Mode! (got %0d)", priv_mode);
            error_count++;
        end else begin
            $display("PASS: Booted into Machine Mode (priv_mode = PRIV_MACHINE).");
        end

        // -------------------------------------------------------------
        // TEST 2: Transition from M-Mode to U-Mode via MRET
        // -------------------------------------------------------------
        $display("\n[TEST 2] MRET Transition to User Mode...");
        mstatus_mpp = 2'b00; // Next mode: User mode
        @(posedge clk);
        is_mret = 1;
        @(posedge clk);
        is_mret = 0;
        #1;

        if (priv_mode !== PRIV_USER) begin
            $display("FAIL: Failed to enter User Mode via MRET! (got %0d)", priv_mode);
            error_count++;
        end else begin
            $display("PASS: Successfully switched to User Mode (priv_mode = PRIV_USER).");
        end

        // -------------------------------------------------------------
        // TEST 3: User Mode ECALL (System Call cause = 8)
        // -------------------------------------------------------------
        $display("\n[TEST 3] User Mode ECALL System Call...");
        is_ecall = 1;
        #1;
        if (trap_cause_out !== 32'd8) begin
            $display("FAIL: U-mode ECALL did not produce cause=8! (got %0d)", trap_cause_out);
            error_count++;
        end else begin
            $display("PASS: U-mode ECALL generated cause=8 (Environment Call from U-mode).");
        end

        // Execute trap entry
        @(posedge clk);
        trap_valid = 1;
        @(posedge clk);
        trap_valid = 0;
        is_ecall   = 0;
        #1;

        if (priv_mode !== PRIV_MACHINE || mstatus_mpp_next !== 2'b00) begin
            $display("FAIL: Trap did not elevate to M-mode or save MPP=0! (priv=%0d, mpp=%b)",
                     priv_mode, mstatus_mpp_next);
            error_count++;
        end else begin
            $display("PASS: Trap elevated to M-mode and preserved MPP=2'b00 (User mode).");
        end

        // -------------------------------------------------------------
        // TEST 4: User Mode CSR Access Violation
        // -------------------------------------------------------------
        $display("\n[TEST 4] User Mode Unauthorized CSR Access Check...");
        // Switch back to U-mode
        mstatus_mpp = 2'b00;
        @(posedge clk);
        is_mret = 1;
        @(posedge clk);
        is_mret = 0;
        #1;

        // Try accessing M-mode CSR (mstatus @ 0x300) while in U-mode
        csr_access_valid = 1;
        csr_addr         = 12'h300; // bits[9:8] = 2'b11 (Machine)
        #1;

        if (illegal_priv_op !== 1'b1 || trap_cause_out !== 32'd2) begin
            $display("FAIL: M-mode CSR access in U-mode was not blocked as Illegal Instruction!");
            error_count++;
        end else begin
            $display("PASS: Unauthorized CSR access accurately trapped as Illegal Instruction (cause=2).");
        end

        // -------------------------------------------------------------
        // TEST 5: User Mode MRET Execution Violation
        // -------------------------------------------------------------
        $display("\n[TEST 5] User Mode MRET Illegal Instruction Check...");
        csr_access_valid = 0;
        is_mret          = 1;
        #1;

        if (illegal_priv_op !== 1'b1 || trap_cause_out !== 32'd2) begin
            $display("FAIL: MRET in U-mode was not blocked as Illegal Instruction!");
            error_count++;
        end else begin
            $display("PASS: MRET in U-mode trapped as Illegal Instruction (cause=2).");
        end
        is_mret = 0;

        $display("==========================================================");
        if (error_count == 0) begin
            $display("Multi-Privilege Mode Controller Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("Multi-Privilege Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
