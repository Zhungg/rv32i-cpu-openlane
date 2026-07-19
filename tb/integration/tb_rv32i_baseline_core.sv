`timescale 1ns/1ps

module tb_rv32i_baseline_core;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;

    localparam int unsigned EXPECTED_WRITES = 10;

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

    logic           response_pending_q;
    imem_request_t  response_request_q;

    int unsigned    error_count;
    int unsigned    write_count;
    int unsigned    redirect_count;
    logic           test_done;

    rv32i_core #(
        .RESET_VECTOR (32'h0000_0000)
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

    function automatic insn_t make_r(
        input logic [6:0] f7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] f3,
        input logic [4:0] rd,
        input opcode_t    opcode
    );
        begin
            make_r = {f7, rs2, rs1, f3, rd, opcode};
        end
    endfunction

    function automatic insn_t make_i(
        input logic [11:0] immediate,
        input logic [4:0]  rs1,
        input logic [2:0]  f3,
        input logic [4:0]  rd,
        input opcode_t     opcode
    );
        begin
            make_i = {immediate, rs1, f3, rd, opcode};
        end
    endfunction

    function automatic insn_t make_u(
        input logic [19:0] immediate,
        input logic [4:0]  rd,
        input opcode_t     opcode
    );
        begin
            make_u = {immediate, rd, opcode};
        end
    endfunction

    function automatic insn_t make_j(
        input logic [20:0] immediate,
        input logic [4:0]  rd,
        input opcode_t     opcode
    );
        begin
            make_j = {
                immediate[20],
                immediate[10:1],
                immediate[11],
                immediate[19:12],
                rd,
                opcode
            };
        end
    endfunction

    function automatic insn_t make_b(
        input logic [12:0] immediate,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  f3,
        input opcode_t     opcode
    );
        begin
            make_b = {
                immediate[12],
                immediate[10:5],
                rs2,
                rs1,
                f3,
                immediate[4:1],
                immediate[11],
                opcode
            };
        end
    endfunction

    function automatic insn_t program_word(input addr_t address);
        begin
            case (address[8:2])
                // x1 = 0x12345000
                7'd0:
                    program_word =
                        make_u(20'h12345, 5'd1, OPCODE_LUI);

                7'd1,
                7'd2,
                7'd3:
                    program_word = RV32I_NOP;

                // x2 = 7
                7'd4:
                    program_word =
                        make_i(
                            12'd7,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd2,
                            OPCODE_OP_IMM
                        );

                7'd5,
                7'd6,
                7'd7:
                    program_word = RV32I_NOP;

                // x3 = 5
                7'd8:
                    program_word =
                        make_i(
                            12'd5,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd3,
                            OPCODE_OP_IMM
                        );

                7'd9,
                7'd10,
                7'd11:
                    program_word = RV32I_NOP;

                // x4 = x2 + x3 = 12
                7'd12:
                    program_word =
                        make_r(
                            FUNCT7_BASE,
                            5'd3,
                            5'd2,
                            FUNCT3_ADD_SUB,
                            5'd4,
                            OPCODE_OP
                        );

                7'd13,
                7'd14,
                7'd15:
                    program_word = RV32I_NOP;

                // x5 = x4 - x3 = 7
                7'd16:
                    program_word =
                        make_r(
                            FUNCT7_SUB_SRA,
                            5'd3,
                            5'd4,
                            FUNCT3_ADD_SUB,
                            5'd5,
                            OPCODE_OP
                        );

                7'd17,
                7'd18,
                7'd19:
                    program_word = RV32I_NOP;

                // x6 = x4 & x5 = 4
                7'd20:
                    program_word =
                        make_r(
                            FUNCT7_BASE,
                            5'd5,
                            5'd4,
                            FUNCT3_AND,
                            5'd6,
                            OPCODE_OP
                        );

                7'd21,
                7'd22,
                7'd23:
                    program_word = RV32I_NOP;

                // x7 = x6 | x3 = 5
                7'd24:
                    program_word =
                        make_r(
                            FUNCT7_BASE,
                            5'd3,
                            5'd6,
                            FUNCT3_OR,
                            5'd7,
                            OPCODE_OP
                        );

                7'd25,
                7'd26,
                7'd27:
                    program_word = RV32I_NOP;

                // JAL x8, +8. Link should be 0x74.
                7'd28:
                    program_word =
                        make_j(21'd8, 5'd8, OPCODE_JAL);

                // Wrong path: must be killed.
                7'd29:
                    program_word =
                        make_i(
                            12'd1,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd9,
                            OPCODE_OP_IMM
                        );

                // Redirect target: x10 = 9.
                7'd30:
                    program_word =
                        make_i(
                            12'd9,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd10,
                            OPCODE_OP_IMM
                        );

                7'd31,
                7'd32,
                7'd33:
                    program_word = RV32I_NOP;

                // BEQ x0, x0, +8.
                7'd34:
                    program_word =
                        make_b(
                            13'd8,
                            5'd0,
                            5'd0,
                            FUNCT3_BEQ,
                            OPCODE_BRANCH
                        );

                // Wrong path: must be killed.
                7'd35:
                    program_word =
                        make_i(
                            12'd1,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd11,
                            OPCODE_OP_IMM
                        );

                // Redirect target: x12 = 12.
                7'd36:
                    program_word =
                        make_i(
                            12'd12,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd12,
                            OPCODE_OP_IMM
                        );

                default:
                    program_word = RV32I_NOP;
            endcase
        end
    endfunction

    function automatic reg_idx_t expected_rd(
        input int unsigned index
    );
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
                8: expected_rd = 5'd10;
                9: expected_rd = 5'd12;
                default: expected_rd = REG_X0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_data(
        input int unsigned index
    );
        begin
            case (index)
                0: expected_data = 32'h1234_5000;
                1: expected_data = 32'd7;
                2: expected_data = 32'd5;
                3: expected_data = 32'd12;
                4: expected_data = 32'd7;
                5: expected_data = 32'd4;
                6: expected_data = 32'd5;
                7: expected_data = 32'h0000_0074;
                8: expected_data = 32'd9;
                9: expected_data = 32'd12;
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
    // One-cycle-latency instruction memory.
    // ------------------------------------------------------------------

    assign imem_req_ready = !response_pending_q;
    assign imem_rsp_valid = response_pending_q;

    always_comb begin
        imem_rsp = '0;

        imem_rsp.instruction =
            program_word(response_request_q.address);

        imem_rsp.error = 1'b0;
        imem_rsp.epoch = response_request_q.epoch;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            response_pending_q <= 1'b0;
        end
        else begin
            if (imem_rsp_valid && imem_rsp_ready) begin
                response_pending_q <= 1'b0;
            end

            if (imem_req_valid && imem_req_ready) begin
                response_pending_q <= 1'b1;
                response_request_q <= imem_req;
            end
        end
    end

    // ------------------------------------------------------------------
    // Redirect monitor.
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n && debug_redirect_valid) begin
            redirect_count++;

            $display(
                "REDIRECT: target=%08h",
                debug_redirect_pc
            );
        end
    end

    // ------------------------------------------------------------------
    // Retirement scoreboard.
    //
    // Commit signals are sampled at the active edge before pipeline
    // registers update through nonblocking assignments.
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail(
                    "Baseline program reached an unsupported instruction"
                );
            end

            if (dmem_req_valid) begin
                fail(
                    "Step 5 baseline ALU/branch program generated a DMEM request"
                );
            end

            if (dmem_rsp_ready) begin
                fail(
                    "Step 5 shell must not consume DMEM responses"
                );
            end

            if (commit_valid) begin
                if (commit_trap) begin
                    fail("Unexpected trap completion");
                end

                if (
                    (commit_pc == 32'h0000_0070) &&
                    (commit_next_pc != 32'h0000_0078)
                ) begin
                    fail("JAL actual_next_pc mismatch");
                end

                if (
                    (commit_pc == 32'h0000_0088) &&
                    (commit_next_pc != 32'h0000_0090)
                ) begin
                    fail("BEQ actual_next_pc mismatch");
                end

                if (commit_rd_write) begin
                    $display(
                        "WRITEBACK[%0d]: pc=%08h x%0d=%08h",
                        write_count,
                        commit_pc,
                        commit_rd_index,
                        commit_rd_data
                    );

                    if (
                        (commit_rd_index == 5'd9) ||
                        (commit_rd_index == 5'd11)
                    ) begin
                        fail(
                            "Wrong-path instruction wrote a register"
                        );
                    end
                    else if (write_count >= EXPECTED_WRITES) begin
                        fail("Unexpected extra register write");
                    end
                    else begin
                        if (
                            commit_rd_index !==
                            expected_rd(write_count)
                        ) begin
                            fail("Register write order mismatch");
                        end

                        if (
                            commit_rd_data !==
                            expected_data(write_count)
                        ) begin
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
    end

    initial begin
        clk            = 1'b0;
        rst_n          = 1'b0;

        dmem_req_ready = 1'b1;
        dmem_rsp_valid = 1'b0;
        dmem_rsp       = '0;

        error_count    = 0;
        write_count    = 0;
        redirect_count = 0;
        test_done      = 1'b0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (test_done);

        repeat (4) @(posedge clk);

        if (redirect_count != 2) begin
            fail("Expected exactly two branch redirects");
        end

        if (write_count != EXPECTED_WRITES) begin
            fail("Architectural write count mismatch");
        end

        $display("------------------------------------------");
        $display(
            "Architectural writes checked: %0d",
            write_count
        );
        $display(
            "Branch redirects checked:     %0d",
            redirect_count
        );
        $display(
            "Wrong-path writes observed:   0"
        );
        $display(
            "MEM/WB payload width:         %0d bits",
            $bits(mem_wb_payload_t)
        );

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I baseline core test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I baseline core test: PASS");
        $finish;
    end

    initial begin
        repeat (2000) @(posedge clk);

        if (!test_done) begin
            $fatal(
                1,
                "RV32I baseline core test timeout"
            );
        end
    end

endmodule
