`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/soc/rv32i_plic.sv
// Module : rv32i_plic
//
// Platform-Level Interrupt Controller (PLIC) compliant with RISC-V PLIC specification.
// Supports 31 external interrupt sources with 3-bit programmable priorities,
// threshold filtering, and atomic claim/complete arbitration.

module rv32i_plic
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_wishbone_pkg::*;
(
    input  logic         clk_i,
    input  logic         rst_ni,

    // Wishbone Slave Interface
    input  wb_req_t      wb_req_i,
    output wb_rsp_t      wb_rsp_o,

    // External Interrupt Input Sources [31:1] (0 is reserved / no interrupt)
    input  logic [31:1]  irq_sources_i,

    // External Interrupt Line to Target CPU Hart (Machine External Interrupt - MEIP)
    output logic         hart_irq_o
);

    // PLIC Registers
    logic [2:0]  priority_q [1:31];
    logic [31:1] enable_q;
    logic [31:1] pending_q;
    logic [31:1] claimed_q;
    logic [2:0]  threshold_q;

    // Edge / Level detection for incoming interrupts
    logic [31:1] irq_sync_q;
    logic [31:1] irq_prev_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            irq_sync_q <= '0;
            irq_prev_q <= '0;
        end else begin
            irq_sync_q <= irq_sources_i;
            irq_prev_q <= irq_sync_q;
        end
    end

    // Detect rising edges and set pending bits
    wire [31:1] irq_rise = irq_sync_q & ~irq_prev_q;

    // -------------------------------------------------------------
    // Priority Arbitration Engine
    // -------------------------------------------------------------
    logic [4:0] max_id;
    logic [2:0] max_prio;

    always_comb begin
        max_id   = 5'd0;
        max_prio = 3'd0;

        for (int i = 1; i <= 31; i++) begin
            if (pending_q[i] && enable_q[i] && !claimed_q[i]) begin
                if (priority_q[i] > max_prio) begin
                    max_prio = priority_q[i];
                    max_id   = 5'(i);
                end
            end
        end
    end

    // Signal external interrupt to CPU if highest pending priority strictly exceeds threshold
    assign hart_irq_o = (max_prio > threshold_q) && (max_id != 5'd0);

    // -------------------------------------------------------------
    // Wishbone Register Access & Claim / Complete Logic
    // -------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_rsp_o.ack   <= 1'b0;
            wb_rsp_o.dat_r <= 32'd0;
            enable_q       <= '0;
            pending_q      <= '0;
            claimed_q      <= '0;
            threshold_q    <= 3'd0;

            for (int i = 1; i <= 31; i++) begin
                priority_q[i] <= 3'd0;
            end
        end else begin
            wb_rsp_o.ack <= 1'b0;

            // Latch pending interrupts
            for (int i = 1; i <= 31; i++) begin
                if (irq_rise[i]) begin
                    pending_q[i] <= 1'b1;
                end
            end

            // Handle Wishbone bus transactions
            if (wb_req_i.cyc && wb_req_i.stb && !wb_rsp_o.ack) begin
                wb_rsp_o.ack <= 1'b1;

                if (wb_req_i.we) begin
                    // Write transactions
                    if (wb_req_i.adr[21]) begin
                        // Context / Target registers (0x0020_0000+)
                        if (wb_req_i.adr[3:2] == 2'b00) begin
                            // Threshold register (0x200000)
                            threshold_q <= wb_req_i.dat_w[2:0];
                        end else if (wb_req_i.adr[3:2] == 2'b01) begin
                            // Complete register (0x200004)
                            if (wb_req_i.dat_w[4:0] >= 5'd1) begin
                                claimed_q[wb_req_i.dat_w[4:0]] <= 1'b0;
                                pending_q[wb_req_i.dat_w[4:0]] <= 1'b0;
                            end
                        end
                    end else if (wb_req_i.adr[15:12] == 4'h2) begin
                        // Enable register (0x2000)
                        enable_q <= wb_req_i.dat_w[31:1];
                    end else if (wb_req_i.adr[21:12] == 10'd0) begin
                        // Priority registers (0x0000 - 0x007C)
                        if (wb_req_i.adr[6:2] >= 5'd1) begin
                            priority_q[wb_req_i.adr[6:2]] <= wb_req_i.dat_w[2:0];
                        end
                    end
                end else begin
                    // Read transactions
                    wb_rsp_o.dat_r <= 32'd0;
                    if (wb_req_i.adr[21]) begin
                        if (wb_req_i.adr[3:2] == 2'b00) begin
                            // Threshold register (0x200000)
                            wb_rsp_o.dat_r <= {29'd0, threshold_q};
                        end else if (wb_req_i.adr[3:2] == 2'b01) begin
                            // Claim register (0x200004): Atomically claim highest priority ID
                            wb_rsp_o.dat_r <= {27'd0, max_id};
                            if (max_id != 5'd0) begin
                                claimed_q[max_id] <= 1'b1;
                            end
                        end
                    end else if (wb_req_i.adr[15:12] == 4'h1) begin
                        // Pending register (0x1000)
                        wb_rsp_o.dat_r <= {pending_q, 1'b0};
                    end else if (wb_req_i.adr[15:12] == 4'h2) begin
                        // Enable register (0x2000)
                        wb_rsp_o.dat_r <= {enable_q, 1'b0};
                    end else if (wb_req_i.adr[21:12] == 10'd0) begin
                        if (wb_req_i.adr[6:2] >= 5'd1) begin
                            wb_rsp_o.dat_r <= {29'd0, priority_q[wb_req_i.adr[6:2]]};
                        end
                    end
                end
            end
        end
    end

endmodule
