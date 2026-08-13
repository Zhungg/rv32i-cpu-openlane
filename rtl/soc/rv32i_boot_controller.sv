`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_boot_controller.sv
// Module : rv32i_boot_controller
//
// Reset synchronizer and boot control for rv32i_soc.

module rv32i_boot_controller (
    input  logic clk_i,
    input  logic rst_async_ni,

    output logic rst_sync_no,
    output logic [31:0] boot_vector_o
);

    logic [1:0] rst_sync_q;

    // Asynchronous assert, synchronous de-assert
    always_ff @(posedge clk_i or negedge rst_async_ni) begin
        if (!rst_async_ni) begin
            rst_sync_q <= 2'b00;
        end else begin
            rst_sync_q <= {rst_sync_q[0], 1'b1};
        end
    end

    assign rst_sync_no   = rst_sync_q[1];
    assign boot_vector_o = 32'h0000_0000; // Reset PC vector

endmodule
