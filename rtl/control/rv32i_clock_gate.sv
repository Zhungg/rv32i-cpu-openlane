`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/control/rv32i_clock_gate.sv
// Module : rv32i_clock_gate
//
// Glitch-Free Integrated Clock Gating (ICG) cell for dynamic power reduction.
// Compatible with SkyWater 130nm standard-cell ASIC library (sky130_fd_sc_hd__dlclkp).

module rv32i_clock_gate (
    input  logic clk_i,
    input  logic enable_i,
    input  logic test_mode_i,
    output logic gated_clk_o
);

    logic enable_latched;

    // Glitch-free negative-level latch
    always_latch begin
        if (!clk_i) begin
            enable_latched = enable_i || test_mode_i;
        end
    end

    // Clock gating AND gate
    assign gated_clk_o = clk_i && enable_latched;

endmodule
