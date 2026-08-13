`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : rtl/trap/rv32i_pmp.sv
// Module : rv32i_pmp
//
// Physical Memory Protection (PMP) unit compliant with RISC-V Privileged Architecture (v1.12).
// Supports 4 PMP entries with TOR, NA4, and NAPOT address matching modes and Lock bits.

module rv32i_pmp
    import rv32i_pkg::*;
    import rv32i_pmp_pkg::*;
(
    input  logic              clk_i,
    input  logic              rst_ni,

    // CSR Interface (pmpcfg0 @ 0x3A0, pmpaddr0..3 @ 0x3B0..0x3B3)
    input  logic              csr_we_i,
    input  logic [11:0]       csr_addr_i,
    input  xlen_t             csr_wdata_i,
    output xlen_t             csr_rdata_o,

    // Permission Checking Interface
    input  priv_mode_e        priv_mode_i,
    input  addr_t             check_addr_i,
    input  pmp_access_type_e  check_acc_type_i,
    output logic              fault_o
);

    // 4 PMP Configuration & Address Registers
    pmp_cfg_t pmp_cfg_q [0:PMP_ENTRIES-1];
    logic [31:0] pmp_addr_q [0:PMP_ENTRIES-1];

    // CSR Address mapping
    localparam logic [11:0] CSR_PMPCFG0  = 12'h3A0;
    localparam logic [11:0] CSR_PMPADDR0 = 12'h3B0;
    localparam logic [11:0] CSR_PMPADDR1 = 12'h3B1;
    localparam logic [11:0] CSR_PMPADDR2 = 12'h3B2;
    localparam logic [11:0] CSR_PMPADDR3 = 12'h3B3;

    // -------------------------------------------------------------
    // CSR Read Multiplexer
    // -------------------------------------------------------------
    always_comb begin
        case (csr_addr_i)
            CSR_PMPCFG0:  csr_rdata_o = {pmp_cfg_q[3], pmp_cfg_q[2], pmp_cfg_q[1], pmp_cfg_q[0]};
            CSR_PMPADDR0: csr_rdata_o = pmp_addr_q[0];
            CSR_PMPADDR1: csr_rdata_o = pmp_addr_q[1];
            CSR_PMPADDR2: csr_rdata_o = pmp_addr_q[2];
            CSR_PMPADDR3: csr_rdata_o = pmp_addr_q[3];
            default:      csr_rdata_o = 32'd0;
        endcase
    end

    // -------------------------------------------------------------
    // CSR Write Logic (Locked entries cannot be modified until reset)
    // -------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < PMP_ENTRIES; i++) begin
                pmp_cfg_q[i]  <= '0;
                pmp_addr_q[i] <= '0;
            end
        end else if (csr_we_i) begin
            case (csr_addr_i)
                CSR_PMPCFG0: begin
                    if (!pmp_cfg_q[0].l) pmp_cfg_q[0] <= csr_wdata_i[7:0];
                    if (!pmp_cfg_q[1].l) pmp_cfg_q[1] <= csr_wdata_i[15:8];
                    if (!pmp_cfg_q[2].l) pmp_cfg_q[2] <= csr_wdata_i[23:16];
                    if (!pmp_cfg_q[3].l) pmp_cfg_q[3] <= csr_wdata_i[31:24];
                end

                CSR_PMPADDR0: if (!pmp_cfg_q[0].l) pmp_addr_q[0] <= csr_wdata_i;
                CSR_PMPADDR1: if (!pmp_cfg_q[1].l) pmp_addr_q[1] <= csr_wdata_i;
                CSR_PMPADDR2: if (!pmp_cfg_q[2].l) pmp_addr_q[2] <= csr_wdata_i;
                CSR_PMPADDR3: if (!pmp_cfg_q[3].l) pmp_addr_q[3] <= csr_wdata_i;
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------
    // Address Matching Engine for all 4 PMP entries
    // -------------------------------------------------------------
    logic [PMP_ENTRIES-1:0] match;

    function automatic logic check_napot_match(input logic [31:0] addr, input logic [31:0] pmp_addr);
        logic [31:0] mask;
        logic [31:0] base;
        // Count trailing ones
        int k;
        k = 0;
        for (int b = 0; b < 30; b++) begin
            if (pmp_addr[b]) k = b + 1;
            else break;
        end

        mask = ~((32'd1 << (k + 2)) - 1);
        base = (pmp_addr << 2) & mask;
        check_napot_match = ((addr & mask) == base);
    endfunction

    always_comb begin
        for (int i = 0; i < PMP_ENTRIES; i++) begin
            match[i] = 1'b0;
            case (pmp_cfg_q[i].a)
                PMP_A_OFF: match[i] = 1'b0;

                PMP_A_TOR: begin
                    if (i == 0) begin
                        match[0] = (check_addr_i < (pmp_addr_q[0] << 2));
                    end else begin
                        match[i] = (check_addr_i >= (pmp_addr_q[i-1] << 2)) &&
                                   (check_addr_i < (pmp_addr_q[i] << 2));
                    end
                end

                PMP_A_NA4: begin
                    match[i] = (check_addr_i >= (pmp_addr_q[i] << 2)) &&
                               (check_addr_i < ((pmp_addr_q[i] << 2) + 32'd4));
                end

                PMP_A_NAPOT: begin
                    match[i] = check_napot_match(check_addr_i, pmp_addr_q[i]);
                end

                default: match[i] = 1'b0;
            endcase
        end
    end

    // -------------------------------------------------------------
    // Priority Resolution & Permission Check (Lowest matching entry wins)
    // -------------------------------------------------------------
    always_comb begin
        fault_o = 1'b0;

        if (match[0]) begin
            if (priv_mode_i == PRIV_MACHINE && !pmp_cfg_q[0].l) begin
                fault_o = 1'b0; // M-mode bypass unlocked
            end else begin
                case (check_acc_type_i)
                    PMP_ACC_READ:    fault_o = !pmp_cfg_q[0].r;
                    PMP_ACC_WRITE:   fault_o = !pmp_cfg_q[0].w;
                    PMP_ACC_EXECUTE: fault_o = !pmp_cfg_q[0].x;
                    default:         fault_o = 1'b1;
                endcase
            end
        end else if (match[1]) begin
            if (priv_mode_i == PRIV_MACHINE && !pmp_cfg_q[1].l) begin
                fault_o = 1'b0;
            end else begin
                case (check_acc_type_i)
                    PMP_ACC_READ:    fault_o = !pmp_cfg_q[1].r;
                    PMP_ACC_WRITE:   fault_o = !pmp_cfg_q[1].w;
                    PMP_ACC_EXECUTE: fault_o = !pmp_cfg_q[1].x;
                    default:         fault_o = 1'b1;
                endcase
            end
        end else if (match[2]) begin
            if (priv_mode_i == PRIV_MACHINE && !pmp_cfg_q[2].l) begin
                fault_o = 1'b0;
            end else begin
                case (check_acc_type_i)
                    PMP_ACC_READ:    fault_o = !pmp_cfg_q[2].r;
                    PMP_ACC_WRITE:   fault_o = !pmp_cfg_q[2].w;
                    PMP_ACC_EXECUTE: fault_o = !pmp_cfg_q[2].x;
                    default:         fault_o = 1'b1;
                endcase
            end
        end else if (match[3]) begin
            if (priv_mode_i == PRIV_MACHINE && !pmp_cfg_q[3].l) begin
                fault_o = 1'b0;
            end else begin
                case (check_acc_type_i)
                    PMP_ACC_READ:    fault_o = !pmp_cfg_q[3].r;
                    PMP_ACC_WRITE:   fault_o = !pmp_cfg_q[3].w;
                    PMP_ACC_EXECUTE: fault_o = !pmp_cfg_q[3].x;
                    default:         fault_o = 1'b1;
                endcase
            end
        end else begin
            // No matching PMP entry:
            // M-mode allows all accesses; U-mode denies all accesses.
            if (priv_mode_i == PRIV_USER) fault_o = 1'b1;
            else fault_o = 1'b0;
        end
    end

endmodule
