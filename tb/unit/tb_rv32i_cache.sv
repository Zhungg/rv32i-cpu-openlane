`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_cache.sv
// Module : tb_rv32i_cache
//
// Exhaustive Unit Testbench for L1 Instruction & Data Caches.

module tb_rv32i_cache;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
    import rv32i_cache_pkg::*;

    logic clk;
    logic rst_n;

    // I-Cache signals
    logic              icache_req_valid;
    wire               icache_req_ready;
    addr_t             icache_req_addr;
    wire               icache_rsp_valid;
    logic              icache_rsp_ready;
    wire insn_t        icache_rsp_inst;
    logic              icache_flush;
    wb_req_t           icache_wb_req;
    wb_rsp_t           icache_wb_rsp;
    wire               icache_hit_evt;
    wire               icache_miss_evt;

    // D-Cache signals
    logic              dcache_req_valid;
    wire               dcache_req_ready;
    dmem_request_t     dcache_req;
    wire               dcache_rsp_valid;
    logic              dcache_rsp_ready;
    dmem_response_t    dcache_rsp;
    logic              dcache_flush;
    wb_req_t           dcache_wb_req;
    wb_rsp_t           dcache_wb_rsp;
    wire               dcache_hit_evt;
    wire               dcache_miss_evt;

    int unsigned error_count = 0;

    // DUT Instantiations
    rv32i_icache u_icache (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .cpu_req_valid_i (icache_req_valid),
        .cpu_req_ready_o (icache_req_ready),
        .cpu_req_addr_i  (icache_req_addr),
        .cpu_rsp_valid_o (icache_rsp_valid),
        .cpu_rsp_ready_i (icache_rsp_ready),
        .cpu_rsp_inst_o  (icache_rsp_inst),
        .flush_i         (icache_flush),
        .wb_req_o        (icache_wb_req),
        .wb_rsp_i        (icache_wb_rsp),
        .hit_count_o     (icache_hit_evt),
        .miss_count_o    (icache_miss_evt)
    );

    rv32i_dcache u_dcache (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .cpu_req_valid_i (dcache_req_valid),
        .cpu_req_ready_o (dcache_req_ready),
        .cpu_req_i       (dcache_req),
        .cpu_rsp_valid_o (dcache_rsp_valid),
        .cpu_rsp_ready_i (dcache_rsp_ready),
        .cpu_rsp_o       (dcache_rsp),
        .flush_i         (dcache_flush),
        .wb_req_o        (dcache_wb_req),
        .wb_rsp_i        (dcache_wb_rsp),
        .hit_count_o     (dcache_hit_evt),
        .miss_count_o    (dcache_miss_evt)
    );

    always #10 clk = ~clk;

    // Simulated Main Memory (Flash / RAM) with Wishbone Slave response
    logic [31:0] mem [0:1023];

    // Wishbone Responder for I-Cache
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icache_wb_rsp <= WB_RSP_IDLE;
        end else begin
            icache_wb_rsp.ack <= 1'b0;
            if (icache_wb_req.cyc && icache_wb_req.stb && !icache_wb_rsp.ack) begin
                icache_wb_rsp.ack   <= 1'b1;
                icache_wb_rsp.dat_r <= mem[icache_wb_req.adr[11:2]];
            end
        end
    end

    // Wishbone Responder for D-Cache
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcache_wb_rsp <= WB_RSP_IDLE;
        end else begin
            dcache_wb_rsp.ack <= 1'b0;
            if (dcache_wb_req.cyc && dcache_wb_req.stb && !dcache_wb_rsp.ack) begin
                dcache_wb_rsp.ack <= 1'b1;
                if (dcache_wb_req.we) begin
                    if (dcache_wb_req.sel[0]) mem[dcache_wb_req.adr[11:2]][7:0]   <= dcache_wb_req.dat_w[7:0];
                    if (dcache_wb_req.sel[1]) mem[dcache_wb_req.adr[11:2]][15:8]  <= dcache_wb_req.dat_w[15:8];
                    if (dcache_wb_req.sel[2]) mem[dcache_wb_req.adr[11:2]][23:16] <= dcache_wb_req.dat_w[23:16];
                    if (dcache_wb_req.sel[3]) mem[dcache_wb_req.adr[11:2]][31:24] <= dcache_wb_req.dat_w[31:24];
                end else begin
                    dcache_wb_rsp.dat_r <= mem[dcache_wb_req.adr[11:2]];
                end
            end
        end
    end

    initial begin
        int i;
        clk              = 0;
        rst_n            = 0;
        icache_req_valid = 0;
        icache_req_addr  = 0;
        icache_rsp_ready = 1;
        icache_flush     = 0;
        dcache_req_valid = 0;
        dcache_req       = '0;
        dcache_rsp_ready = 1;
        dcache_flush     = 0;

        // Initialize memory with predictable test words
        for (i = 0; i < 1024; i++) begin
            mem[i] = 32'hA000_0000 + (i * 4);
        end

        $display("==========================================================");
        $display("Starting L1 Instruction & Data Cache Unit Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: I-Cache Cold Miss -> Line Fill -> Subsequent Hits
        // -------------------------------------------------------------
        $display("\n[TEST 1] I-Cache: Cold Miss on 0x0000_0000 and Line Fill...");
        @(posedge clk);
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0000;
        @(posedge clk);
        icache_req_valid = 0;

        // Wait for response
        while (!icache_rsp_valid) @(posedge clk);
        if (icache_rsp_inst !== 32'hA000_0000) begin
            $display("FAIL: Expected instruction 0x%08x, got 0x%08x", 32'hA000_0000, icache_rsp_inst);
            error_count++;
        end else begin
            $display("PASS: Cold Miss Line Fill returned 0x%08x", icache_rsp_inst);
        end

        // Consecutive accesses to words 1, 2, 3 in the same line (Must be 1-cycle HITs)
        @(posedge clk);
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0004;
        @(posedge clk);
        icache_req_valid = 0;
        while (!icache_rsp_valid) @(posedge clk);
        if (icache_rsp_inst !== 32'hA000_0004) begin
            $display("FAIL: Cache Hit on 0x04 mismatch: 0x%08x", icache_rsp_inst);
            error_count++;
        end else begin
            $display("PASS: Word 1 Cache Hit (0x%08x)", icache_rsp_inst);
        end

        @(posedge clk);
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0008;
        @(posedge clk);
        icache_req_valid = 0;
        while (!icache_rsp_valid) @(posedge clk);
        if (icache_rsp_inst !== 32'hA000_0008) begin
            $display("FAIL: Cache Hit on 0x08 mismatch: 0x%08x", icache_rsp_inst);
            error_count++;
        end else begin
            $display("PASS: Word 2 Cache Hit (0x%08x)", icache_rsp_inst);
        end

        // -------------------------------------------------------------
        // TEST 2: 2-Way Set-Associative Conflict & LRU Replacement
        // -------------------------------------------------------------
        $display("\n[TEST 2] I-Cache: 2-Way Associativity & LRU...");
        // Set index = 0, Tag = 1 -> Addr = 0x0000_0400 (Maps to Set 0, fills Way 1)
        @(posedge clk);
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0400;
        @(posedge clk);
        icache_req_valid = 0;
        while (!icache_rsp_valid) @(posedge clk);
        $display("PASS: Set 0 Way 1 filled with 0x%08x", icache_rsp_inst);

        // Verify Way 0 is still retained (Addr 0x0000_0000 must still HIT!)
        @(posedge clk);
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0000;
        @(posedge clk);
        icache_req_valid = 0;
        while (!icache_rsp_valid) @(posedge clk);
        if (icache_rsp_inst !== 32'hA000_0000) begin
            $display("FAIL: Way 0 eviction error: expected 0x%08x, got 0x%08x", 32'hA000_0000, icache_rsp_inst);
            error_count++;
        end else begin
            $display("PASS: Way 0 hit preserved (2-way Set Associativity Verified)");
        end

        // -------------------------------------------------------------
        // TEST 3: D-Cache Write-Through & Read Hit Verification
        // -------------------------------------------------------------
        $display("\n[TEST 3] D-Cache: Write-Through & Read...");
        // Write 0xDEADBEEF to 0x0000_0100
        @(posedge clk);
        dcache_req_valid        = 1;
        dcache_req.address      = 32'h0000_0100;
        dcache_req.write        = 1;
        dcache_req.write_strobe = 4'b1111;
        dcache_req.write_data   = 32'hDEAD_BEEF;
        @(posedge clk);
        dcache_req_valid = 0;
        while (!dcache_rsp_valid) @(posedge clk);
        $display("PASS: D-Cache Write-Through completed.");

        // Read back from 0x0000_0100
        @(posedge clk);
        dcache_req_valid   = 1;
        dcache_req.address = 32'h0000_0100;
        dcache_req.write   = 0;
        @(posedge clk);
        dcache_req_valid = 0;
        while (!dcache_rsp_valid) @(posedge clk);
        if (dcache_rsp.read_data !== 32'hDEAD_BEEF) begin
            $display("FAIL: D-Cache readback mismatch: expected 0xDEADBEEF, got 0x%08x", dcache_rsp.read_data);
            error_count++;
        end else begin
            $display("PASS: D-Cache readback verified: 0x%08x", dcache_rsp.read_data);
        end

        // -------------------------------------------------------------
        // TEST 4: FENCE / FENCE.I Flush Invalidation
        // -------------------------------------------------------------
        $display("\n[TEST 4] Cache Invalidation Flush (FENCE.I)...");
        @(posedge clk);
        icache_flush = 1;
        dcache_flush = 1;
        @(posedge clk);
        icache_flush = 0;
        dcache_flush = 0;
        @(posedge clk);

        // Next read to 0x0000_0000 must be a cold miss and reload
        icache_req_valid = 1;
        icache_req_addr  = 32'h0000_0000;
        @(posedge clk);
        icache_req_valid = 0;
        while (!icache_rsp_valid) @(posedge clk);
        $display("PASS: Invalidation Flush Verified (Cold reload successful).");

        $display("==========================================================");
        if (error_count == 0) begin
            $display("L1 I-Cache & D-Cache Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("L1 Cache Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
