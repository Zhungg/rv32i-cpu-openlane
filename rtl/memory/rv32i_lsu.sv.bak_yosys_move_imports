`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// RV32I Load/Store Unit.
//
// Step 6B scope:
// - Detect misaligned load/store.
// - Generate aligned D-memory requests.
// - Wait for D-memory responses.
// - Align/sign-extend load data.
// - Convert response errors into precise memory exceptions.
// - Support exactly one outstanding memory transaction.
//
// Stores are considered complete only after a D-memory response is accepted.
// This avoids retiring a store before the memory system confirms success.

module rv32i_lsu (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    input  logic                              valid_i,
    output logic                              ready_o,

    input  logic                              memory_write_i,
    input  rv32i_pkg::addr_t                  address_i,
    input  rv32i_pkg::xlen_t                  store_data_i,
    input  rv32i_types_pkg::mem_size_e        size_i,
    input  logic                              unsigned_load_i,

    output logic                              complete_o,
    output rv32i_pkg::xlen_t                  load_data_o,
    output rv32i_types_pkg::exception_t       exception_o,

    output logic                              dmem_req_valid_o,
    input  logic                              dmem_req_ready_i,
    output rv32i_types_pkg::dmem_request_t    dmem_req_o,

    input  logic                              dmem_rsp_valid_i,
    output logic                              dmem_rsp_ready_o,
    input  rv32i_types_pkg::dmem_response_t   dmem_rsp_i
);

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    logic           misaligned;
    xlen_t          aligned_store_data;
    logic [3:0]     aligned_write_strobe;

    dmem_request_t  controller_request;
    logic           controller_valid;
    logic           controller_ready;
    logic           controller_complete;
    dmem_response_t controller_response;

    logic           aligned_request_fire;
    logic           misaligned_complete;

    logic           op_write_q;
    addr_t          op_address_q;
    mem_size_e      op_size_q;
    logic           op_unsigned_load_q;

    xlen_t          aligned_load_data;

    // --------------------------------------------------------------
    // Alignment helpers
    // --------------------------------------------------------------

    rv32i_misaligned_detect u_misaligned_detect (
        .address_i    (address_i),
        .size_i       (size_i),
        .misaligned_o (misaligned)
    );

    rv32i_store_aligner u_store_aligner (
        .address_i             (address_i),
        .store_data_i          (store_data_i),
        .size_i                (size_i),
        .aligned_write_data_o  (aligned_store_data),
        .write_strobe_o        (aligned_write_strobe)
    );

    rv32i_load_aligner u_load_aligner (
        .address_i       (op_address_q),
        .read_data_i     (controller_response.read_data),
        .size_i          (op_size_q),
        .unsigned_load_i (op_unsigned_load_q),
        .load_data_o     (aligned_load_data)
    );

    // --------------------------------------------------------------
    // Request construction
    // --------------------------------------------------------------

    always @* begin
        controller_request = '0;

        controller_request.address       = address_i;
        controller_request.write         = memory_write_i;
        controller_request.size          = size_i;
        controller_request.unsigned_load = unsigned_load_i;

        if (memory_write_i) begin
            controller_request.write_data   = aligned_store_data;
            controller_request.write_strobe = aligned_write_strobe;
        end
        else begin
            controller_request.write_data   = '0;
            controller_request.write_strobe = 4'b0000;
        end
    end

    assign controller_valid =
        valid_i &&
        !misaligned;

    rv32i_memory_controller u_memory_controller (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),

        .valid_i          (controller_valid),
        .ready_o          (controller_ready),
        .request_i        (controller_request),

        .complete_o       (controller_complete),
        .response_o       (controller_response),

        .dmem_req_valid_o (dmem_req_valid_o),
        .dmem_req_ready_i (dmem_req_ready_i),
        .dmem_req_o       (dmem_req_o),

        .dmem_rsp_valid_i (dmem_rsp_valid_i),
        .dmem_rsp_ready_o (dmem_rsp_ready_o),
        .dmem_rsp_i       (dmem_rsp_i)
    );

    assign ready_o =
        misaligned ? 1'b1 : controller_ready;

    assign aligned_request_fire =
        valid_i &&
        !misaligned &&
        ready_o;

    assign misaligned_complete =
        valid_i &&
        misaligned &&
        ready_o;

    // --------------------------------------------------------------
    // Operation metadata
    // --------------------------------------------------------------

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            op_write_q         <= 1'b0;
            op_address_q       <= '0;
            op_size_q          <= MEM_SIZE_BYTE;
            op_unsigned_load_q <= 1'b0;
        end
        else if (aligned_request_fire) begin
            op_write_q         <= memory_write_i;
            op_address_q       <= address_i;
            op_size_q          <= size_i;
            op_unsigned_load_q <= unsigned_load_i;
        end
    end

    // --------------------------------------------------------------
    // Completion and exception classification
    // --------------------------------------------------------------

    always @* begin
        complete_o   = 1'b0;
        load_data_o  = '0;
        exception_o  = '0;

        if (misaligned_complete) begin
            complete_o          = 1'b1;
            exception_o.valid   = 1'b1;
            exception_o.tval    = address_i;

            if (memory_write_i) begin
                exception_o.cause = EXC_STORE_ADDR_MISALIGNED;
            end
            else begin
                exception_o.cause = EXC_LOAD_ADDR_MISALIGNED;
            end
        end
        else if (controller_complete) begin
            complete_o = 1'b1;

            if (controller_response.error) begin
                exception_o.valid = 1'b1;
                exception_o.tval  = op_address_q;

                if (op_write_q) begin
                    exception_o.cause = EXC_STORE_ACCESS_FAULT;
                end
                else begin
                    exception_o.cause = EXC_LOAD_ACCESS_FAULT;
                end
            end
            else if (!op_write_q) begin
                load_data_o = aligned_load_data;
            end
        end
    end

endmodule
