`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Minimal machine-mode CSR file.
//
// Step 6I scope:
// - Trap state CSRs:
//   mstatus, mtvec, mepc, mcause, mtval
// - Trap entry update
// - MRET status update
// - CSR instruction read/write baseline:
//   CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
//
// Unsupported CSR addresses return illegal access indication.
// Full privilege checking is intentionally deferred.

module rv32i_csr_file #(
    parameter logic [31:0] MTVEC_RESET = 32'h0000_0100
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // Trap/MRET side effects.
    input  logic                          trap_valid_i,
    input  rv32i_types_pkg::exception_t   trap_exception_i,

    input  logic                          mret_valid_i,

    // CSR read path. This is used while the CSR instruction is in MEM.
    input  logic                          csr_read_valid_i,
    input  logic [11:0]                   csr_read_address_i,
    output rv32i_pkg::xlen_t              csr_read_data_o,
    output logic                          csr_read_illegal_o,

    // CSR write path. This is applied at architectural commit.
    input  logic                          csr_write_valid_i,
    input  logic [11:0]                   csr_write_address_i,
    input  logic [2:0]                    csr_write_funct3_i,
    input  rv32i_pkg::xlen_t              csr_write_data_i,
    output logic                          csr_write_illegal_o,

    output rv32i_pkg::addr_t              mtvec_o,
    output rv32i_pkg::addr_t              mepc_o,
    output rv32i_pkg::xlen_t              mcause_o,
    output rv32i_pkg::xlen_t              mtval_o,
    output rv32i_pkg::xlen_t              mstatus_o,

    output logic                          mret_redirect_valid_o,
    output rv32i_pkg::addr_t              mret_redirect_pc_o
);

    import rv32i_pkg::*;
    import rv32i_csr_pkg::*;

    localparam logic [11:0] CSR_ADDR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_ADDR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_ADDR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_ADDR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_ADDR_MTVAL   = 12'h343;

    localparam logic [2:0] CSR_FUNCT3_CSRRW  = 3'b001;
    localparam logic [2:0] CSR_FUNCT3_CSRRS  = 3'b010;
    localparam logic [2:0] CSR_FUNCT3_CSRRC  = 3'b011;
    localparam logic [2:0] CSR_FUNCT3_CSRRWI = 3'b101;
    localparam logic [2:0] CSR_FUNCT3_CSRRSI = 3'b110;
    localparam logic [2:0] CSR_FUNCT3_CSRRCI = 3'b111;

    addr_t mtvec_q;
    addr_t mepc_q;
    xlen_t mcause_q;
    xlen_t mtval_q;
    xlen_t mstatus_q;

    xlen_t csr_write_old_value;
    xlen_t csr_write_next_value;
    logic  csr_write_enable_effective;

    assign mtvec_o   = mtvec_q;
    assign mepc_o    = mepc_q;
    assign mcause_o  = mcause_q;
    assign mtval_o   = mtval_q;
    assign mstatus_o = mstatus_q;

    assign mret_redirect_valid_o = mret_valid_i;
    assign mret_redirect_pc_o    = mepc_q;

    function automatic logic csr_address_supported(
        input logic [11:0] address
    );
        begin
            case (address)
                CSR_ADDR_MSTATUS,
                CSR_ADDR_MTVEC,
                CSR_ADDR_MEPC,
                CSR_ADDR_MCAUSE,
                CSR_ADDR_MTVAL: begin
                    csr_address_supported = 1'b1;
                end

                default: begin
                    csr_address_supported = 1'b0;
                end
            endcase
        end
    endfunction

    function automatic xlen_t csr_read_value(
        input logic [11:0] address
    );
        begin
            case (address)
                CSR_ADDR_MSTATUS: csr_read_value = mstatus_q;
                CSR_ADDR_MTVEC:   csr_read_value = mtvec_q;
                CSR_ADDR_MEPC:    csr_read_value = mepc_q;
                CSR_ADDR_MCAUSE:  csr_read_value = mcause_q;
                CSR_ADDR_MTVAL:   csr_read_value = mtval_q;
                default:          csr_read_value = '0;
            endcase
        end
    endfunction

    function automatic logic csr_funct3_supported(
        input logic [2:0] funct3
    );
        begin
            case (funct3)
                CSR_FUNCT3_CSRRW,
                CSR_FUNCT3_CSRRS,
                CSR_FUNCT3_CSRRC,
                CSR_FUNCT3_CSRRWI,
                CSR_FUNCT3_CSRRSI,
                CSR_FUNCT3_CSRRCI: begin
                    csr_funct3_supported = 1'b1;
                end

                default: begin
                    csr_funct3_supported = 1'b0;
                end
            endcase
        end
    endfunction

    always @* begin
        csr_read_data_o    = csr_read_value(csr_read_address_i);
        csr_read_illegal_o =
            csr_read_valid_i &&
            !csr_address_supported(csr_read_address_i);
    end

    always @* begin
        csr_write_old_value        = csr_read_value(csr_write_address_i);
        csr_write_next_value       = csr_write_old_value;
        csr_write_enable_effective = 1'b0;

        csr_write_illegal_o =
            csr_write_valid_i &&
            (
                !csr_address_supported(csr_write_address_i) ||
                !csr_funct3_supported(csr_write_funct3_i)
            );

        if (csr_write_valid_i && !csr_write_illegal_o) begin
            case (csr_write_funct3_i)
                CSR_FUNCT3_CSRRW,
                CSR_FUNCT3_CSRRWI: begin
                    csr_write_next_value       = csr_write_data_i;
                    csr_write_enable_effective = 1'b1;
                end

                CSR_FUNCT3_CSRRS,
                CSR_FUNCT3_CSRRSI: begin
                    csr_write_next_value = csr_write_old_value |
                                           csr_write_data_i;

                    csr_write_enable_effective =
                        (csr_write_data_i != '0);
                end

                CSR_FUNCT3_CSRRC,
                CSR_FUNCT3_CSRRCI: begin
                    csr_write_next_value = csr_write_old_value &
                                           ~csr_write_data_i;

                    csr_write_enable_effective =
                        (csr_write_data_i != '0);
                end

                default: begin
                    csr_write_next_value       = csr_write_old_value;
                    csr_write_enable_effective = 1'b0;
                end
            endcase
        end
    end

    task automatic write_csr_value(
        input logic [11:0] address,
        input xlen_t       value
    );
        begin
            case (address)
                CSR_ADDR_MSTATUS: begin
                    mstatus_q <= value;
                end

                CSR_ADDR_MTVEC: begin
                    // Only direct mode baseline. Force lower 2 bits to 0.
                    mtvec_q <= {value[31:2], 2'b00};
                end

                CSR_ADDR_MEPC: begin
                    mepc_q <= {value[31:2], 2'b00};
                end

                CSR_ADDR_MCAUSE: begin
                    mcause_q <= value;
                end

                CSR_ADDR_MTVAL: begin
                    mtval_q <= value;
                end

                default: begin
                    // Unsupported CSR is filtered by csr_write_illegal_o.
                end
            endcase
        end
    endtask

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mtvec_q   <= addr_t'(MTVEC_RESET);
            mepc_q    <= '0;
            mcause_q  <= '0;
            mtval_q   <= '0;
            mstatus_q <= '0;
        end
        else begin
            if (trap_valid_i) begin
                mepc_q   <= trap_exception_i.epc;
                mtval_q  <= trap_exception_i.tval;

                mcause_q <= '0;
                mcause_q[31]  <= trap_exception_i.is_interrupt;
                mcause_q[4:0] <= trap_exception_i.cause;

                // Machine-mode trap entry:
                // MPIE <= MIE
                // MIE  <= 0
                // MPP  <= M-mode
                mstatus_q[MSTATUS_MPIE_BIT] <=
                    mstatus_q[MSTATUS_MIE_BIT];

                mstatus_q[MSTATUS_MIE_BIT] <= 1'b0;

                mstatus_q[MSTATUS_MPP_MSB:MSTATUS_MPP_LSB] <= 2'b11;
            end
            else if (mret_valid_i) begin
                // Minimal machine-mode MRET behavior.
                mstatus_q[MSTATUS_MIE_BIT] <=
                    mstatus_q[MSTATUS_MPIE_BIT];

                mstatus_q[MSTATUS_MPIE_BIT] <= 1'b1;

                mstatus_q[MSTATUS_MPP_MSB:MSTATUS_MPP_LSB] <= 2'b11;
            end
            else if (
                csr_write_valid_i &&
                !csr_write_illegal_o &&
                csr_write_enable_effective
            ) begin
                write_csr_value(
                    csr_write_address_i,
                    csr_write_next_value
                );
            end
        end
    end

endmodule
