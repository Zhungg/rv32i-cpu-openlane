`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_plic.sv
// Module : tb_rv32i_plic
//
// Exhaustive Unit Testbench for PLIC (Platform-Level Interrupt Controller) & UART FIFO.

module tb_rv32i_plic;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;

    logic        clk;
    logic        rst_n;

    wb_req_t     wb_req;
    wb_rsp_t     wb_rsp;

    logic [31:1] irq_sources;
    wire         hart_irq;

    // FIFO signals
    logic        fifo_push;
    logic [7:0]  fifo_din;
    logic        fifo_pop;
    wire [7:0]   fifo_dout;
    logic        fifo_flush;
    wire         fifo_full;
    wire         fifo_empty;
    wire [4:0]   fifo_count;

    int unsigned error_count = 0;

    rv32i_plic dut_plic (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .wb_req_i      (wb_req),
        .wb_rsp_o      (wb_rsp),
        .irq_sources_i (irq_sources),
        .hart_irq_o    (hart_irq)
    );

    rv32i_uart_fifo #(
        .DEPTH(16),
        .DATA_WIDTH(8)
    ) dut_fifo (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .push_i     (fifo_push),
        .data_in_i  (fifo_din),
        .pop_i      (fifo_pop),
        .data_out_o (fifo_dout),
        .flush_i    (fifo_flush),
        .full_o     (fifo_full),
        .empty_o    (fifo_empty),
        .count_o    (fifo_count)
    );

    always #10 clk = ~clk;

    task automatic wb_write(input addr_t addr, input xlen_t data);
        @(posedge clk);
        wb_req.cyc   = 1'b1;
        wb_req.stb   = 1'b1;
        wb_req.we    = 1'b1;
        wb_req.sel   = 4'b1111;
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
        clk         = 0;
        rst_n       = 0;
        wb_req      = WB_REQ_IDLE;
        irq_sources = '0;
        fifo_push   = 0;
        fifo_din    = '0;
        fifo_pop    = 0;
        fifo_flush  = 0;

        $display("==========================================================");
        $display("Starting RISC-V PLIC & UART FIFO Unit Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: Configure PLIC Priorities, Enable & Threshold
        // -------------------------------------------------------------
        $display("\n[TEST 1] Configuring PLIC (Source 1=Prio 3, Source 2=Prio 6, Threshold=2)...");
        wb_write(32'h0000_0004, 32'd3); // Source 1 priority = 3
        wb_write(32'h0000_0008, 32'd6); // Source 2 priority = 6
        wb_write(32'h0000_2000, 32'h0000_0006); // Enable Source 1 & 2
        wb_write(32'h0020_0000, 32'd2); // Threshold = 2

        // -------------------------------------------------------------
        // TEST 2: Concurrent Interrupt Arbitration & Priority Ordering
        // -------------------------------------------------------------
        $display("\n[TEST 2] Firing Source 1 & 2 Simultaneously -> Verify Priority Arbitration...");
        @(posedge clk);
        irq_sources[1] = 1;
        irq_sources[2] = 1;
        @(posedge clk);
        irq_sources[1] = 0;
        irq_sources[2] = 0;
        repeat (2) @(posedge clk);

        if (hart_irq !== 1'b1) begin
            $display("FAIL: hart_irq was not asserted!");
            error_count++;
        end else begin
            $display("PASS: hart_irq asserted to CPU.");
        end

        // Claim highest priority interrupt (Should be Source 2)
        wb_read(32'h0020_0004, rdata);
        if (rdata[4:0] !== 5'd2) begin
            $display("FAIL: Expected Claim ID 2, got %0d", rdata[4:0]);
            error_count++;
        end else begin
            $display("PASS: Claim 1 correctly returned highest priority Source %0d.", rdata[4:0]);
        end

        // Complete Source 2
        wb_write(32'h0020_0004, 32'd2);

        // Next Claim (Should be Source 1)
        wb_read(32'h0020_0004, rdata);
        if (rdata[4:0] !== 5'd1) begin
            $display("FAIL: Expected Claim ID 1, got %0d", rdata[4:0]);
            error_count++;
        end else begin
            $display("PASS: Claim 2 correctly returned Source %0d.", rdata[4:0]);
        end

        // Complete Source 1
        wb_write(32'h0020_0004, 32'd1);
        repeat (2) @(posedge clk);

        if (hart_irq !== 1'b0) begin
            $display("FAIL: hart_irq remained asserted after all completes!");
            error_count++;
        end else begin
            $display("PASS: hart_irq successfully cleared after all interrupts completed.");
        end

        // -------------------------------------------------------------
        // TEST 3: Threshold Filtering
        // -------------------------------------------------------------
        $display("\n[TEST 3] Threshold Filtering (Threshold=5 vs Source 1 Prio 3)...");
        wb_write(32'h0020_0000, 32'd5); // Threshold = 5
        @(posedge clk);
        irq_sources[1] = 1;
        @(posedge clk);
        irq_sources[1] = 0;
        repeat (2) @(posedge clk);

        if (hart_irq !== 1'b0) begin
            $display("FAIL: Interrupt passed threshold when it should have been blocked!");
            error_count++;
        end else begin
            $display("PASS: Low-priority interrupt accurately filtered out by threshold.");
        end

        // Clean up pending for next test
        wb_write(32'h0020_0000, 32'd0); // Lower threshold
        wb_read(32'h0020_0004, rdata);
        wb_write(32'h0020_0004, rdata);

        // -------------------------------------------------------------
        // TEST 4: 16-Byte UART FIFO Verification
        // -------------------------------------------------------------
        $display("\n[TEST 4] UART 16-Byte Hardware FIFO Push / Pop...");
        for (int i = 0; i < 16; i++) begin
            @(posedge clk);
            fifo_push = 1;
            fifo_din  = 8'(i + 8'hA0);
        end
        @(posedge clk);
        fifo_push = 0;
        #1;

        if (fifo_full !== 1'b1 || fifo_count !== 5'd16) begin
            $display("FAIL: FIFO not full after 16 pushes! (full=%0d, count=%0d)", fifo_full, fifo_count);
            error_count++;
        end else begin
            $display("PASS: FIFO Full condition verified (count = 16).");
        end

        // Pop all 16 elements and verify order
        for (int i = 0; i < 16; i++) begin
            #1;
            if (fifo_dout !== 8'(i + 8'hA0)) begin
                $display("FAIL: FIFO data mismatch at %0d: expected 0x%02x, got 0x%02x", i, 8'(i + 8'hA0), fifo_dout);
                error_count++;
            end
            @(posedge clk);
            fifo_pop = 1;
        end
        @(posedge clk);
        fifo_pop = 0;
        #1;

        if (fifo_empty !== 1'b1) begin
            $display("FAIL: FIFO not empty after 16 pops!");
            error_count++;
        end else begin
            $display("PASS: FIFO Empty condition & FIFO order verified.");
        end

        $display("==========================================================");
        if (error_count == 0) begin
            $display("PLIC & UART FIFO Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("PLIC Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
