`timescale 1ns/1ps

module tb_rv32i_csr_instructions;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    localparam logic [11:0] CSR_ADDR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_ADDR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_ADDR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_ADDR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_ADDR_MTVAL   = 12'h343;

    localparam int unsigned EXPECTED_WRITES = 9;

    logic           clk;
    logic           rst_n;

    logic           imem_req_valid;
    logic           imem_req_ready;
    imem_request_t  imem_req;

    logic           imem_rsp_valid;
    logic           imem_rsp_ready;
    imem_response_t imem_rsp;

    logic           dmem_req_valid;
    logic           dmem_req_ready;
    dmem_request_t  dmem_req;

    logic           dmem_rsp_valid;
    logic           dmem_rsp_ready;
    dmem_response_t dmem_rsp;

    logic           commit_valid;
    logic           commit_trap;
    addr_t          commit_pc;
    addr_t          commit_next_pc;
    insn_t          commit_instruction;
    logic           commit_rd_write;
    reg_idx_t       commit_rd_index;
    xlen_t          commit_rd_data;

    logic           baseline_stall;
    logic           debug_redirect_valid;
    addr_t          debug_redirect_pc;

    logic           imem_response_pending_q;
    imem_request_t  imem_response_request_q;

    int unsigned    error_count;
    int unsigned    write_count;
    logic           test_done;

    rv32i_core #(
        .RESET_VECTOR (32'h0000_0000),
        .TRAP_VECTOR  (32'h0000_0100)
    ) dut (
        .clk_i                    (clk),
        .rst_ni                   (rst_n),

        .imem_req_valid_o         (imem_req_valid),
        .imem_req_ready_i         (imem_req_ready),
        .imem_req_o               (imem_req),

        .imem_rsp_valid_i         (imem_rsp_valid),
        .imem_rsp_ready_o         (imem_rsp_ready),
        .imem_rsp_i               (imem_rsp),

        .dmem_req_valid_o         (dmem_req_valid),
        .dmem_req_ready_i         (dmem_req_ready),
        .dmem_req_o               (dmem_req),

        .dmem_rsp_valid_i         (dmem_rsp_valid),
        .dmem_rsp_ready_o         (dmem_rsp_ready),
        .dmem_rsp_i               (dmem_rsp),

        .commit_valid_o           (commit_valid),
        .commit_trap_o            (commit_trap),
        .commit_pc_o              (commit_pc),
        .commit_next_pc_o         (commit_next_pc),
        .commit_instruction_o     (commit_instruction),
        .commit_rd_write_o        (commit_rd_write),
        .commit_rd_index_o        (commit_rd_index),
        .commit_rd_data_o         (commit_rd_data),

        .baseline_stall_o         (baseline_stall),
        .debug_redirect_valid_o   (debug_redirect_valid),
        .debug_redirect_pc_o      (debug_redirect_pc)
    );

    always #5 clk = ~clk;

    function automatic insn_t make_i(
        input logic [11:0] immediate,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd,
        input opcode_t     opcode
    );
        begin
            make_i = {immediate, rs1, funct3, rd, opcode};
        end
    endfunction

    function automatic insn_t make_csr(
        input logic [11:0] csr,
        input logic [4:0]  rs1_or_zimm,
        input logic [2:0]  funct3,
        input logic [4:0]  rd
    );
        begin
            make_csr = {
                csr,
                rs1_or_zimm,
                funct3,
                rd,
                OPCODE_SYSTEM
            };
        end
    endfunction

    function automatic insn_t program_word(input addr_t address);
        begin
            case (address[8:2])
                // x1 = 0x100
                7'd0:
                    program_word =
                        make_i(
                            12'h100,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd1,
                            OPCODE_OP_IMM
                        );

                7'd1,
                7'd2,
                7'd3:
                    program_word = RV32I_NOP;

                // csrrw x2, mtvec, x1
                // x2 gets old mtvec = 0x100, mtvec remains 0x100.
                7'd4:
                    program_word =
                        make_csr(
                            CSR_ADDR_MTVEC,
                            5'd1,
                            3'b001,
                            5'd2
                        );

                7'd5,
                7'd6,
                7'd7:
                    program_word = RV32I_NOP;

                // csrrs x3, mtvec, x0
                // Pure read. x3 = 0x100.
                7'd8:
                    program_word =
                        make_csr(
                            CSR_ADDR_MTVEC,
                            5'd0,
                            3'b010,
                            5'd3
                        );

                // csrrwi x4, mtval, 5
                // x4 gets old mtval = 0, mtval = 5.
                7'd9:
                    program_word =
                        make_csr(
                            CSR_ADDR_MTVAL,
                            5'd5,
                            3'b101,
                            5'd4
                        );

                7'd10,
                7'd11,
                7'd12:
                    program_word = RV32I_NOP;

                // csrrs x5, mtval, x0
                // x5 = 5.
                7'd13:
                    program_word =
                        make_csr(
                            CSR_ADDR_MTVAL,
                            5'd0,
                            3'b010,
                            5'd5
                        );

                // csrrsi x6, mstatus, 8
                // old mstatus = 0, set bit 3, x6 = 0.
                7'd14:
                    program_word =
                        make_csr(
                            CSR_ADDR_MSTATUS,
                            5'd8,
                            3'b110,
                            5'd6
                        );

                7'd15,
                7'd16,
                7'd17:
                    program_word = RV32I_NOP;

                // csrrs x7, mstatus, x0
                // x7 = 0x8.
                7'd18:
                    program_word =
                        make_csr(
                            CSR_ADDR_MSTATUS,
                            5'd0,
                            3'b010,
                            5'd7
                        );

                // csrrci x8, mstatus, 8
                // x8 gets old 0x8, then clears bit 3.
                7'd19:
                    program_word =
                        make_csr(
                            CSR_ADDR_MSTATUS,
                            5'd8,
                            3'b111,
                            5'd8
                        );

                7'd20,
                7'd21,
                7'd22:
                    program_word = RV32I_NOP;

                // csrrs x9, mstatus, x0
                // x9 = 0.
                7'd23:
                    program_word =
                        make_csr(
                            CSR_ADDR_MSTATUS,
                            5'd0,
                            3'b010,
                            5'd9
                        );

                default:
                    program_word = RV32I_NOP;
            endcase
        end
    endfunction

    function automatic reg_idx_t expected_rd(input int unsigned index);
        begin
            case (index)
                0: expected_rd = 5'd1;
                1: expected_rd = 5'd2;
                2: expected_rd = 5'd3;
                3: expected_rd = 5'd4;
                4: expected_rd = 5'd5;
                5: expected_rd = 5'd6;
                6: expected_rd = 5'd7;
                7: expected_rd = 5'd8;
                8: expected_rd = 5'd9;
                default: expected_rd = REG_X0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_data(input int unsigned index);
        begin
            case (index)
                0: expected_data = 32'h0000_0100;
                1: expected_data = 32'h0000_0100;
                2: expected_data = 32'h0000_0100;
                3: expected_data = 32'h0000_0000;
                4: expected_data = 32'h0000_0005;
                5: expected_data = 32'h0000_0000;
                6: expected_data = 32'h0000_0008;
                7: expected_data = 32'h0000_0008;
                8: expected_data = 32'h0000_0000;
                default: expected_data = '0;
            endcase
        end
    endfunction

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    // ------------------------------------------------------------------
    // Instruction memory
    // ------------------------------------------------------------------

    assign imem_req_ready = !imem_response_pending_q;
    assign imem_rsp_valid = imem_response_pending_q;

    always @* begin
        imem_rsp             = '0;
        imem_rsp.instruction = program_word(imem_response_request_q.address);
        imem_rsp.error       = 1'b0;
        imem_rsp.epoch       = imem_response_request_q.epoch;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_response_pending_q <= 1'b0;
        end
        else begin
            if (imem_rsp_valid && imem_rsp_ready) begin
                imem_response_pending_q <= 1'b0;
            end

            if (imem_req_valid && imem_req_ready) begin
                imem_response_pending_q <= 1'b1;
                imem_response_request_q <= imem_req;
            end
        end
    end

    assign dmem_req_ready = 1'b1;
    assign dmem_rsp_valid = 1'b0;

    always @* begin
        dmem_rsp = '0;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail("Unexpected baseline stall");
            end

            if (commit_valid && commit_trap) begin
                fail("Unexpected trap");
            end

            if (dmem_req_valid) begin
                fail("Unexpected DMEM request");
            end

            if (commit_valid && commit_rd_write) begin
                $display(
                    "WRITEBACK[%0d]: pc=%08h x%0d=%08h",
                    write_count,
                    commit_pc,
                    commit_rd_index,
                    commit_rd_data
                );

                if (write_count >= EXPECTED_WRITES) begin
                    fail("Unexpected extra register write");
                end
                else begin
                    if (commit_rd_index !== expected_rd(write_count)) begin
                        fail("Register write order mismatch");
                    end

                    if (commit_rd_data !== expected_data(write_count)) begin
                        fail("Register write data mismatch");
                    end

                    write_count++;

                    if (write_count == EXPECTED_WRITES) begin
                        test_done = 1'b1;
                    end
                end
            end
        end
    end

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        error_count = 0;
        write_count = 0;
        test_done   = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (test_done);

        repeat (8) @(posedge clk);

        if (dut.u_datapath.csr_mtvec !== 32'h0000_0100) begin
            fail("Final mtvec mismatch");
        end

        if (dut.u_datapath.csr_mtval !== 32'h0000_0005) begin
            fail("Final mtval mismatch");
        end

        if (dut.u_datapath.csr_mstatus !== 32'h0000_0000) begin
            fail("Final mstatus mismatch");
        end

        $display("------------------------------------------");
        $display("Architectural writes checked: %0d", write_count);
        $display("CSR mtvec:                     %08h", dut.u_datapath.csr_mtvec);
        $display("CSR mtval:                     %08h", dut.u_datapath.csr_mtval);
        $display("CSR mstatus:                   %08h", dut.u_datapath.csr_mstatus);

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I CSR instruction test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I CSR instruction test: PASS");
        $finish;
    end

    initial begin
        repeat (8000) @(posedge clk);

        $fatal(
            1,
            "RV32I CSR instruction test timeout"
        );
    end

endmodule
