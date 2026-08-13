`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32i_power_controller.sv
// Module : tb_rv32i_power_controller
//
// Exhaustive Unit Testbench for Low-Power Clock Gating & Wakeup Controller.

module tb_rv32i_power_controller;

    logic       clk;
    logic       rst_n;
    logic       wfi_pulse;
    logic [7:0] irq_sources;
    logic       test_mode;

    wire        cpu_sleep;
    wire        gated_clk;
    wire        wakeup_event;

    int unsigned error_count = 0;
    int unsigned gated_clock_toggles = 0;

    rv32i_power_controller dut (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .wfi_pulse_i    (wfi_pulse),
        .irq_sources_i  (irq_sources),
        .test_mode_i    (test_mode),
        .cpu_sleep_o    (cpu_sleep),
        .gated_clk_o    (gated_clk),
        .wakeup_event_o (wakeup_event)
    );

    always #10 clk = ~clk;

    // Track gated clock toggles
    always @(posedge gated_clk) begin
        gated_clock_toggles++;
    end

    initial begin
        clk         = 0;
        rst_n       = 0;
        wfi_pulse   = 0;
        irq_sources = 8'd0;
        test_mode   = 0;

        $display("==========================================================");
        $display("Starting RV32I Low-Power & Clock Gating Unit Tests");
        $display("==========================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // TEST 1: Running State (Clock Active)
        // -------------------------------------------------------------
        $display("\n[TEST 1] Running Mode (Clock Free-Running)...");
        gated_clock_toggles = 0;
        repeat (5) @(posedge clk);
        if (cpu_sleep !== 1'b0 || gated_clock_toggles == 0) begin
            $display("FAIL: Pipeline clock not active during running mode!");
            error_count++;
        end else begin
            $display("PASS: Pipeline clock active (%0d toggles in 5 cycles).", gated_clock_toggles);
        end

        // -------------------------------------------------------------
        // TEST 2: WFI Instruction -> Clock Gated Sleep Mode
        // -------------------------------------------------------------
        $display("\n[TEST 2] WFI Execution -> Entering Sleep Mode...");
        @(posedge clk);
        wfi_pulse = 1;
        @(posedge clk);
        wfi_pulse = 0;
        #1;

        if (cpu_sleep !== 1'b1) begin
            $display("FAIL: CPU failed to enter sleep mode!");
            error_count++;
        end else begin
            $display("PASS: CPU successfully entered Sleep mode (cpu_sleep=1).");
        end

        // Verify clock is completely stopped during sleep
        gated_clock_toggles = 0;
        repeat (10) @(posedge clk);
        if (gated_clock_toggles !== 0) begin
            $display("FAIL: Gated clock toggled %0d times while in sleep!", gated_clock_toggles);
            error_count++;
        end else begin
            $display("PASS: Clock gating verified (0 toggles during 10 sleep cycles).");
        end

        // -------------------------------------------------------------
        // TEST 3: Interrupt Wakeup Verification
        // -------------------------------------------------------------
        $display("\n[TEST 3] Interrupt Wakeup (Timer / UART IRQ)...");
        @(posedge clk);
        irq_sources[1] = 1; // Timer IRQ pulse
        @(posedge clk);
        irq_sources[1] = 0;
        #1;

        if (cpu_sleep !== 1'b0) begin
            $display("FAIL: CPU failed to wake up on interrupt!");
            error_count++;
        end else begin
            $display("PASS: CPU woke up instantly on IRQ (cpu_sleep=0).");
        end

        // Verify clock resumed
        gated_clock_toggles = 0;
        repeat (5) @(posedge clk);
        if (gated_clock_toggles == 0) begin
            $display("FAIL: Pipeline clock did not resume after wakeup!");
            error_count++;
        end else begin
            $display("PASS: Pipeline clock resumed (%0d toggles after wakeup).", gated_clock_toggles);
        end

        // -------------------------------------------------------------
        // TEST 4: WFI with IRQ Already Pending (No Sleep)
        // -------------------------------------------------------------
        $display("\n[TEST 4] WFI with IRQ Already Pending (Zero-latency continuation)...");
        irq_sources[0] = 1;
        @(posedge clk);
        wfi_pulse = 1;
        @(posedge clk);
        wfi_pulse = 0;
        #1;
        if (cpu_sleep !== 1'b0) begin
            $display("FAIL: CPU entered sleep when IRQ was pending!");
            error_count++;
        end else begin
            $display("PASS: CPU bypassed sleep correctly due to pending IRQ.");
        end

        $display("==========================================================");
        if (error_count == 0) begin
            $display("Low-Power Clock Gating Tests: ALL CHECKS PASSED!");
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("Low-Power Clock Gating Tests: FAILED with %0d errors", error_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
