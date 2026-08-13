`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/trap/rv32i_priv_controller.sv
// Module : rv32i_priv_controller
//
// Multi-Privilege Mode Controller (Machine Mode & User Mode)
// compliant with RISC-V Privileged Architecture (v1.12).

module rv32i_priv_controller
    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_pmp_pkg::*;
(
    input  logic         clk_i,
    input  logic         rst_ni,

    // Trap / Return Events
    input  logic         trap_valid_i,
    input  logic         is_ecall_i,
    input  logic         is_mret_i,
    input  logic         is_wfi_i,
    input  xlen_t        trap_cause_in_i,

    // CSR Access Validation
    input  logic         csr_access_valid_i,
    input  logic [11:0]  csr_addr_i,
    input  logic [1:0]   mstatus_mpp_i,

    // Outputs
    output priv_mode_e   priv_mode_o,
    output xlen_t        trap_cause_out_o,
    output logic         illegal_priv_op_o,
    output logic [1:0]   mstatus_mpp_next_o,
    output logic         mstatus_mpp_we_o
);

    priv_mode_e current_priv_q;

    assign priv_mode_o = current_priv_q;

    // -------------------------------------------------------------
    // Privilege Validation for CSRs and Privileged Instructions
    // -------------------------------------------------------------
    // In RISC-V Privileged ISA, CSR address bits [9:8] specify minimum privilege level:
    // 2'b00 = User, 2'b01 = Supervisor, 2'b11 = Machine.
    wire [1:0] csr_min_priv = csr_addr_i[9:8];
    wire csr_priv_violation = csr_access_valid_i && (current_priv_q < priv_mode_e'(csr_min_priv));

    // MRET and WFI are illegal in User Mode
    wire priv_inst_violation = (current_priv_q == PRIV_USER) && (is_mret_i || is_wfi_i);

    assign illegal_priv_op_o = csr_priv_violation || priv_inst_violation;

    // -------------------------------------------------------------
    // Exception Cause Resolution
    // -------------------------------------------------------------
    always_comb begin
        if (illegal_priv_op_o) begin
            trap_cause_out_o = 32'd2; // Illegal Instruction Exception
        end else if (is_ecall_i) begin
            if (current_priv_q == PRIV_USER) trap_cause_out_o = 32'd8;  // Environment Call from U-mode
            else                             trap_cause_out_o = 32'd11; // Environment Call from M-mode
        end else begin
            trap_cause_out_o = trap_cause_in_i;
        end
    end

    // -------------------------------------------------------------
    // Privilege Level Transitions
    // -------------------------------------------------------------
    always_comb begin
        mstatus_mpp_next_o = 2'b00;
        mstatus_mpp_we_o   = 1'b0;

        if (trap_valid_i && !is_mret_i) begin
            // On trap entry: save current privilege mode to MPP, transition to Machine mode
            mstatus_mpp_next_o = (current_priv_q == PRIV_USER) ? 2'b00 : 2'b11;
            mstatus_mpp_we_o   = 1'b1;
        end else if (is_mret_i && !illegal_priv_op_o) begin
            // On MRET: reset MPP to User mode
            mstatus_mpp_next_o = 2'b00;
            mstatus_mpp_we_o   = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_priv_q <= PRIV_MACHINE; // Boot in Machine Mode
        end else begin
            if (trap_valid_i && !is_mret_i) begin
                // Any trap elevates to Machine mode
                current_priv_q <= PRIV_MACHINE;
            end else if (is_mret_i && !illegal_priv_op_o) begin
                // MRET restores privilege mode from MPP
                if (mstatus_mpp_i == 2'b00) current_priv_q <= PRIV_USER;
                else                        current_priv_q <= PRIV_MACHINE;
            end
        end
    end

endmodule
