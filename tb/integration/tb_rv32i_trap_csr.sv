`timescale 1ns/1ps

module tb_rv32i_trap_csr;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    localparam int unsigned EXPECTED_WRITES = 2;

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
    int unsigned    trap_count;
    int unsigned    redirect_count;
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

    function automatic insn_t program_word(input addr_t address);
        begin
            case (address[9:2])
                // 0x00000000: x1 = 5
                8'd0:
                    program_word =
                        make_i(
                            12'd5,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd1,
                            OPCODE_OP_IMM
                        );

                // 0x00000004: illegal instruction
                8'd1:
                    program_word = 32'h0000_0000;

                // 0x00000008: wrong-path instruction.
                // Must be flushed after trap.
                8'd2:
                    program_word =
                        make_i(
                            12'd99,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd2,
                            OPCODE_OP_IMM
                        );

                // 0x00000100: trap handler baseline instruction
                8'd64:
                    program_word =
                        make_i(
                            12'd7,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd3,
                            OPCODE_OP_IMM
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
                1: expected_rd = 5'd3;
                default: expected_rd = REG_X0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_data(input int unsigned index);
        begin
            case (index)
                0: expected_data = 32'h0000_0005;
                1: expected_data = 32'h0000_0007;
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

    // No data memory activity expected.
    assign dmem_req_ready = 1'b1;
    assign dmem_rsp_valid = 1'b0;

    always @* begin
        dmem_rsp = '0;
    end

    // ------------------------------------------------------------------
    // Redirect monitor
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n && debug_redirect_valid) begin
            redirect_count++;

            $display(
                "REDIRECT[%0d]: pc=%08h",
                redirect_count,
                debug_redirect_pc
            );

            if (debug_redirect_pc != 32'h0000_0100) begin
                fail("Trap redirect did not use mtvec");
            end
        end
    end

    // ------------------------------------------------------------------
    // Retirement scoreboard
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail("Unexpected baseline stall during CSR trap test");
            end

            if (dmem_req_valid) begin
                fail("CSR trap test unexpectedly issued DMEM request");
            end

            if (commit_valid && commit_trap) begin
                trap_count++;

                $display(
                    "TRAP[%0d]: pc=%08h instruction=%08h",
                    trap_count,
                    commit_pc,
                    commit_instruction
                );

                if (commit_pc != 32'h0000_0004) begin
                    fail("Trap PC mismatch");
                end

                if (commit_instruction != 32'h0000_0000) begin
                    fail("Trap instruction mismatch");
                end
            end

            if (commit_valid && commit_rd_write) begin
                $display(
                    "WRITEBACK[%0d]: pc=%08h x%0d=%08h",
                    write_count,
                    commit_pc,
                    commit_rd_index,
                    commit_rd_data
                );

                if (commit_rd_index == 5'd2) begin
                    fail("Wrong-path x2 instruction committed");
                end

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

                    if (
                        (write_count == EXPECTED_WRITES) &&
                        (trap_count == 1) &&
                        (redirect_count == 1)
                    ) begin
                        test_done = 1'b1;
                    end
                end
            end
        end
    end

    initial begin
        clk            = 1'b0;
        rst_n          = 1'b0;

        error_count    = 0;
        write_count    = 0;
        trap_count     = 0;
        redirect_count = 0;
        test_done      = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (test_done);

        repeat (8) @(posedge clk);

        if (trap_count != 1) begin
            fail("Expected exactly one trap");
        end

        if (redirect_count != 1) begin
            fail("Expected exactly one trap redirect");
        end

        if (write_count != EXPECTED_WRITES) begin
            fail("Architectural write count mismatch");
        end

        if (dut.u_datapath.csr_mtvec !== 32'h0000_0100) begin
            fail("CSR mtvec mismatch");
        end

        if (dut.u_datapath.csr_mepc !== 32'h0000_0004) begin
            fail("CSR mepc mismatch");
        end

        if (
            dut.u_datapath.csr_mcause[4:0] !==
            EXC_ILLEGAL_INSTRUCTION
        ) begin
            fail("CSR mcause mismatch");
        end

        if (dut.u_datapath.csr_mcause[31] !== 1'b0) begin
            fail("CSR mcause interrupt bit mismatch");
        end

        if (dut.u_datapath.csr_mtval !== 32'h0000_0000) begin
            fail("CSR mtval mismatch");
        end

        if (
            dut.u_datapath.csr_mstatus[
                MSTATUS_MPP_MSB:MSTATUS_MPP_LSB
            ] !== 2'b11
        ) begin
            fail("CSR mstatus.MPP mismatch");
        end

        if (
            dut.u_datapath.csr_mstatus[MSTATUS_MIE_BIT] !== 1'b0
        ) begin
            fail("CSR mstatus.MIE mismatch");
        end

        $display("------------------------------------------");
        $display("Architectural writes checked: %0d", write_count);
        $display("Traps checked:                 %0d", trap_count);
        $display("Trap redirects checked:        %0d", redirect_count);
        $display("CSR mtvec:                     %08h", dut.u_datapath.csr_mtvec);
        $display("CSR mepc:                      %08h", dut.u_datapath.csr_mepc);
        $display("CSR mcause:                    %08h", dut.u_datapath.csr_mcause);
        $display("CSR mtval:                     %08h", dut.u_datapath.csr_mtval);
        $display("CSR mstatus:                   %08h", dut.u_datapath.csr_mstatus);

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I CSR trap-state test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I CSR trap-state test: PASS");
        $finish;
    end

    initial begin
        repeat (5000) @(posedge clk);

        $fatal(
            1,
            "RV32I CSR trap-state test timeout"
        );
    end

endmodule
