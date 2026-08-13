`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/control/rv32i_power_controller.sv
// Module : rv32i_power_controller
//
// Power Management & Clock Gating Controller for RV32I Low-Power WFI sleep mode.

module rv32i_power_controller (
    input  logic        clk_i,
    input  logic        rst_ni,

    // CPU WFI instruction signal
    input  logic        wfi_pulse_i,

    // Interrupt wake-up sources
    input  logic [7:0]  irq_sources_i,

    // Test mode bypass
    input  logic        test_mode_i,

    // Sleep status & gated clock outputs
    output logic        cpu_sleep_o,
    output logic        gated_clk_o,
    output logic        wakeup_event_o
);

    logic sleep_q;
    wire  wakeup_condition = |irq_sources_i;

    assign cpu_sleep_o    = sleep_q;
    assign wakeup_event_o = sleep_q && wakeup_condition;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sleep_q <= 1'b0;
        end else begin
            if (sleep_q) begin
                // Wake up if any interrupt becomes pending
                if (wakeup_condition) begin
                    sleep_q <= 1'b0;
                end
            end else if (wfi_pulse_i) begin
                // Enter sleep unless an interrupt is already pending
                if (!wakeup_condition) begin
                    sleep_q <= 1'b1;
                end
            end
        end
    end

    // Integrated Clock Gating Cell
    wire clock_enable = !sleep_q;

    rv32i_clock_gate u_clock_gate (
        .clk_i       (clk_i),
        .enable_i    (clock_enable),
        .test_mode_i (test_mode_i),
        .gated_clk_o (gated_clk_o)
    );

endmodule
