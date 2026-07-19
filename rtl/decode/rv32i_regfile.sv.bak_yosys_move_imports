`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I 32 x 32-bit integer register file.
//
// Ports:
// - Two asynchronous read ports.
// - One synchronous write port.
// - x0 is hardwired to zero.
// - Same-cycle writeback-to-decode bypass is supported.
//
// There is intentionally no reset port. Architectural software must not
// assume a reset value for x1 through x31.

module rv32i_regfile (
    input  logic                      clk_i,

    input  rv32i_pkg::reg_idx_t       rs1_index_i,
    input  rv32i_pkg::reg_idx_t       rs2_index_i,

    output rv32i_pkg::xlen_t          rs1_data_o,
    output rv32i_pkg::xlen_t          rs2_data_o,

    input  logic                      write_enable_i,
    input  rv32i_pkg::reg_idx_t       write_index_i,
    input  rv32i_pkg::xlen_t          write_data_i
);

    import rv32i_pkg::*;

    xlen_t registers_q [REG_COUNT-1:0];

    // Synchronous architectural write.
    always_ff @(posedge clk_i) begin
        if (write_enable_i && (write_index_i != REG_X0)) begin
            registers_q[write_index_i] <= write_data_i;
        end
    end

    // Asynchronous read port 1 with WB-to-ID write-through bypass.
    always_comb begin
        rs1_data_o = '0;

        if (rs1_index_i != REG_X0) begin
            if (
                write_enable_i &&
                (write_index_i != REG_X0) &&
                (write_index_i == rs1_index_i)
            ) begin
                rs1_data_o = write_data_i;
            end
            else begin
                rs1_data_o = registers_q[rs1_index_i];
            end
        end
    end

    // Asynchronous read port 2 with WB-to-ID write-through bypass.
    always_comb begin
        rs2_data_o = '0;

        if (rs2_index_i != REG_X0) begin
            if (
                write_enable_i &&
                (write_index_i != REG_X0) &&
                (write_index_i == rs2_index_i)
            ) begin
                rs2_data_o = write_data_i;
            end
            else begin
                rs2_data_o = registers_q[rs2_index_i];
            end
        end
    end

endmodule
