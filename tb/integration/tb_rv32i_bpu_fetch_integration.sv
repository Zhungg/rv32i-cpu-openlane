`timescale 1ns/1ps

module tb_rv32i_bpu_fetch_integration;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;

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
    int unsigned    branch_commit_count;
    int unsigned    redirect_count;
    int unsigned    predicted_taken_seen;
    int unsigned    request_count;
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

    function automatic insn_t make_b(
        input logic [12:0] immediate,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input opcode_t     opcode
    );
        begin
            make_b = {
                immediate[12],
                immediate[10:5],
                rs2,
                rs1,
                funct3,
                immediate[4:1],
                immediate[11],
                opcode
            };
        end
    endfunction

    function automatic insn_t program_word(input addr_t address);
        begin
            case (address[9:2])
                // 0x00: x1 = 0
                8'd0:
                    program_word =
                        make_i(
                            12'd0,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd1,
                            OPCODE_OP_IMM
                        );

                // 0x04: x2 = 0
                8'd1:
                    program_word =
                        make_i(
                            12'd0,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd2,
                            OPCODE_OP_IMM
                        );

                // 0x08: beq x1, x2, +8 => target 0x10
                // Always taken.
                8'd2:
                    program_word =
                        make_b(
                            13'd8,
                            5'd2,
                            5'd1,
                            FUNCT3_BEQ,
                            OPCODE_BRANCH
                        );

                // 0x0c: wrong-path filler. Should usually be flushed
                // after branch redirect.
                8'd3:
                    program_word =
                        make_i(
                            12'd99,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd3,
                            OPCODE_OP_IMM
                        );

                // 0x10: addi x4, x4, 1
                8'd4:
                    program_word =
                        make_i(
                            12'd1,
                            5'd4,
                            FUNCT3_ADD_SUB,
                            5'd4,
                            OPCODE_OP_IMM
                        );

                // 0x14: beq x1, x2, -12 => target 0x08
                // Always taken loop branch.
                8'd5:
                    program_word =
                        make_b(
                            13'h1ff4,
                            5'd2,
                            5'd1,
                            FUNCT3_BEQ,
                            OPCODE_BRANCH
                        );

                default:
                    program_word = RV32I_NOP;
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
                request_count++;
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
    // Monitors
    // ------------------------------------------------------------------

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

            if (debug_redirect_valid) begin
                redirect_count++;

                $display(
                    "REDIRECT[%0d]: pc=%08h",
                    redirect_count,
                    debug_redirect_pc
                );
            end

            if (
                dut.u_datapath.if_id_valid &&
                dut.u_datapath.if_id_payload.prediction.predicted_taken
            ) begin
                predicted_taken_seen++;

                $display(
                    "PRED_TAKEN[%0d]: pc=%08h predicted_pc=%08h",
                    predicted_taken_seen,
                    dut.u_datapath.if_id_payload.pc,
                    dut.u_datapath.if_id_payload.prediction.predicted_pc
                );
            end

            if (
                commit_valid &&
                (commit_instruction[6:0] == OPCODE_BRANCH)
            ) begin
                branch_commit_count++;

                $display(
                    "BRANCH_COMMIT[%0d]: pc=%08h next=%08h",
                    branch_commit_count,
                    commit_pc,
                    commit_next_pc
                );
            end

            if (
                (branch_commit_count >= 8) &&
                (predicted_taken_seen >= 1)
            ) begin
                test_done = 1'b1;
            end
        end
    end

    initial begin
        clk                  = 1'b0;
        rst_n                = 1'b0;

        error_count          = 0;
        branch_commit_count  = 0;
        redirect_count       = 0;
        predicted_taken_seen = 0;
        request_count        = 0;
        test_done            = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (test_done);

        repeat (10) @(posedge clk);

        $display("------------------------------------------");
        $display("IMEM requests:              %0d", request_count);
        $display("Branch commits:             %0d", branch_commit_count);
        $display("Redirects observed:          %0d", redirect_count);
        $display("Predicted-taken observations:%0d", predicted_taken_seen);

        if (branch_commit_count < 8) begin
            fail("Not enough branch commits observed");
        end

        if (predicted_taken_seen == 0) begin
            fail("No predicted-taken instruction observed");
        end

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I BPU fetch integration test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I BPU fetch integration test: PASS");
        $finish;
    end

    initial begin
        repeat (8000) @(posedge clk);

        $fatal(
            1,
            "RV32I BPU fetch integration test timeout"
        );
    end

endmodule
