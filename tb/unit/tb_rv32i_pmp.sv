`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_pmp.sv
// Module : tb_rv32i_pmp
//
// Exhaustive Unit Testbench for Physical Memory Protection (PMP).

module tb_rv32i_pmp;

    import rv32i_pkg::*;
    import rv32i_pmp_pkg::*;

    logic             clk;
    logic             rst_n;

    logic             csr_we;
    logic [11:0]      csr_addr;
    xlen_t            csr_wdata;
    wire xlen_t       csr_rdata;

    priv_mode_e       priv_mode;
    addr_t            check_addr;
    pmp_access_type_e check_acc_type;
    wire              fault;

    int unsigned error_count = 0;

    rv32i_pmp dut (
        .clk_i            (clk),
        .rst_ni           (rst_n),
        .csr_we_i         (csr_we),
        .csr_addr_i       (csr_addr),
        .csr_wdata_i      (csr_wdata),
        .csr_rdata_o      (csr_rdata),
        .priv_mode_i      (priv_mode),
        .check_addr_i     (check_addr),
        .check_acc_type_i (check_acc_type),
        .fault_o          (fault)
    );

    always #10 clk = ~clk;

    task automatic write_csr(input logic [11:0] addr, input xlen_t data);
        @(posedge clk);
        csr_we    = 1;
        csr_addr  = addr;
        csr_wdata = data;
        @(posedge clk);
        csr_we    = 0;
    endtask

    initial begin
        clk            = 0;
        rst_n          = 0;
        csr_we         = 0;
        csr_addr       = '0;
        csr_wdata      = '0;
        priv_mode      = PRIV_MACHINE;
        check_addr     = '0;
        check_acc_type = PMP_ACC_READ;

        $display("==========================================================");
        $display("Starting RISC-V Physical Memory Protection (PMP) Unit Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: Default State (Unconfigured PMP)
        // -------------------------------------------------------------
        $display("\n[TEST 1] Default Permissions (M-mode Allow, U-mode Deny)...");
        priv_mode      = PRIV_MACHINE;
        check_addr     = 32'h0000_1000;
        check_acc_type = PMP_ACC_READ;
        #1;
        if (fault !== 1'b0) begin
            $display("FAIL: M-mode default read was blocked!");
            error_count++;
        end else begin
            $display("PASS: M-mode default access allowed.");
        end

        priv_mode = PRIV_USER;
        #1;
        if (fault !== 1'b1) begin
            $display("FAIL: U-mode default read was allowed without PMP rule!");
            error_count++;
        end else begin
            $display("PASS: U-mode default access denied.");
        end

        // -------------------------------------------------------------
        // TEST 2: TOR Mode (Top of Range) Flash/ROM Protection
        // -------------------------------------------------------------
        $display("\n[TEST 2] TOR Rule: ROM 0x0000_0000 - 0x0000_FFFF Read/Exec Only (Locked)...");
        // pmpaddr0 = 0x0001_0000 >> 2 = 0x0000_4000
        write_csr(12'h3B0, 32'h0000_4000);
        // pmp0cfg = L=1, A=TOR(01), X=1, W=0, R=1 -> 8'b1000_1101 = 0x8D
        write_csr(12'h3A0, 32'h0000_008D);

        priv_mode  = PRIV_MACHINE;
        check_addr = 32'h0000_1000;

        // Read check (Allowed)
        check_acc_type = PMP_ACC_READ;
        #1;
        if (fault !== 1'b0) begin
            $display("FAIL: ROM Read blocked unexpectedly!");
            error_count++;
        end else begin
            $display("PASS: ROM Read Allowed.");
        end

        // Execute check (Allowed)
        check_acc_type = PMP_ACC_EXECUTE;
        #1;
        if (fault !== 1'b0) begin
            $display("FAIL: ROM Execute blocked unexpectedly!");
            error_count++;
        end else begin
            $display("PASS: ROM Execute Allowed.");
        end

        // Write check (Must FAULT because W=0 and L=1)
        check_acc_type = PMP_ACC_WRITE;
        #1;
        if (fault !== 1'b1) begin
            $display("FAIL: ROM Write allowed on Read-Only locked region!");
            error_count++;
        end else begin
            $display("PASS: ROM Write accurately FAULTED (Access Fault Generated).");
        end

        // -------------------------------------------------------------
        // TEST 3: Lock Bit Enforcement (L=1 cannot be overwritten)
        // -------------------------------------------------------------
        $display("\n[TEST 3] Lock Bit Protection (Overwrite Attempt)...");
        // Try to clear Lock bit and enable Write: write 0x0F
        write_csr(12'h3A0, 32'h0000_000F);
        #1;
        if (dut.pmp_cfg_q[0].l !== 1'b1) begin
            $display("FAIL: Lock bit was overwritten!");
            error_count++;
        end else begin
            $display("PASS: Lock bit preserved (Register write-protected).");
        end

        $display("==========================================================");
        if (error_count == 0) begin
            $display("PMP Unit Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("PMP Unit Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
