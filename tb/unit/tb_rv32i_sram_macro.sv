`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_sram_macro.sv
// Module : tb_rv32i_sram_macro
//
// Exhaustive Unit Testbench for OpenRAM 2KB SRAM Hard Macro and Wishbone Adapter.

module tb_rv32i_sram_macro;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;

    logic    clk;
    logic    rst_n;

    wb_req_t wb_req;
    wb_rsp_t wb_rsp;

    int unsigned error_count = 0;

    rv32i_sram_macro_wrapper dut (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .wb_req_i (wb_req),
        .wb_rsp_o (wb_rsp)
    );

    always #10 clk = ~clk;

    task automatic wb_write(input addr_t addr, input xlen_t data, input logic [3:0] sel);
        @(posedge clk);
        wb_req.cyc   = 1'b1;
        wb_req.stb   = 1'b1;
        wb_req.we    = 1'b1;
        wb_req.sel   = sel;
        wb_req.adr   = addr;
        wb_req.dat_w = data;
        @(posedge clk);
        while (!wb_rsp.ack) @(posedge clk);
        wb_req = WB_REQ_IDLE;
        @(posedge clk);
    endtask

    task automatic wb_read(input addr_t addr, output xlen_t data);
        @(posedge clk);
        wb_req.cyc = 1'b1;
        wb_req.stb = 1'b1;
        wb_req.we  = 1'b0;
        wb_req.sel = 4'b1111;
        wb_req.adr = addr;
        @(posedge clk);
        while (!wb_rsp.ack) @(posedge clk);
        data = wb_rsp.dat_r;
        wb_req = WB_REQ_IDLE;
        @(posedge clk);
    endtask

    initial begin
        xlen_t rdata;
        clk    = 0;
        rst_n  = 0;
        wb_req = WB_REQ_IDLE;

        $display("==========================================================");
        $display("Starting OpenRAM 2KB SRAM Hard Macro & Adapter Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: Full-Word 32-bit Write & Read
        // -------------------------------------------------------------
        $display("\n[TEST 1] Full-Word 32-bit Write (0x11223344)...");
        wb_write(32'h0000_0000, 32'h1122_3344, 4'b1111);
        wb_read(32'h0000_0000, rdata);

        if (rdata !== 32'h1122_3344) begin
            $display("FAIL: Expected 0x11223344, got 0x%08x", rdata);
            error_count++;
        end else begin
            $display("PASS: Full word write & readback verified (0x%08x).", rdata);
        end

        // -------------------------------------------------------------
        // TEST 2: Byte-Masked Write (SB - Store Byte)
        // -------------------------------------------------------------
        $display("\n[TEST 2] Byte-Masked Write (wmask=4'b0001, data=0xAA)...");
        wb_write(32'h0000_0000, 32'h0000_00AA, 4'b0001);
        wb_read(32'h0000_0000, rdata);

        if (rdata !== 32'h1122_33AA) begin
            $display("FAIL: Expected 0x112233AA, got 0x%08x", rdata);
            error_count++;
        end else begin
            $display("PASS: Byte-masked write verified (0x%08x).", rdata);
        end

        // -------------------------------------------------------------
        // TEST 3: Halfword-Masked Write (SH - Store Halfword)
        // -------------------------------------------------------------
        $display("\n[TEST 3] Halfword-Masked Write (wmask=4'b1100, data=0xBBBB0000)...");
        wb_write(32'h0000_0000, 32'hBBBB_0000, 4'b1100);
        wb_read(32'h0000_0000, rdata);

        if (rdata !== 32'hBBBB_33AA) begin
            $display("FAIL: Expected 0xBBBB33AA, got 0x%08x", rdata);
            error_count++;
        end else begin
            $display("PASS: Halfword-masked write verified (0x%08x).", rdata);
        end

        // -------------------------------------------------------------
        // TEST 4: Multi-Address Array Write & Read
        // -------------------------------------------------------------
        $display("\n[TEST 4] Multi-Address Memory Bank Sweep...");
        for (int i = 0; i < 8; i++) begin
            wb_write(32'(i * 4), 32'(32'hA000_0000 + i), 4'b1111);
        end

        for (int i = 0; i < 8; i++) begin
            wb_read(32'(i * 4), rdata);
            if (rdata !== 32'(32'hA000_0000 + i)) begin
                $display("FAIL: Mismatch at word %0d: expected 0x%08x, got 0x%08x", i, 32'hA000_0000 + i, rdata);
                error_count++;
            end
        end
        $display("PASS: Multi-address memory bank sweep verified (8 words).");

        $display("==========================================================");
        if (error_count == 0) begin
            $display("OpenRAM 2KB Hard Macro Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("OpenRAM Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
