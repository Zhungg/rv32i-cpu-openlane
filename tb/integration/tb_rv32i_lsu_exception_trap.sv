`timescale 1ns/1ps

module tb_rv32i_lsu_exception_trap;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    logic           clk;
    logic           rst_n;

    int unsigned    phase;

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

    logic           dmem_response_pending_q;
    dmem_request_t  dmem_response_request_q;

    int unsigned    error_count;
    int unsigned    write_count;
    int unsigned    trap_count;
    int unsigned    redirect_count;
    int unsigned    dmem_request_count;
    logic           phase_done;

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

    function automatic insn_t make_s(
        input logic [11:0] immediate,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input opcode_t     opcode
    );
        begin
            make_s = {
                immediate[11:5],
                rs2,
                rs1,
                funct3,
                immediate[4:0],
                opcode
            };
        end
    endfunction

    function automatic insn_t program_word(input addr_t address);
        begin
            program_word = RV32I_NOP;

            case (phase)
                // ------------------------------------------------------
                // Phase 0:
                //   lw x2, 0(x1), where x1 = 0x41.
                //   Word load from unaligned address must trap.
                // ------------------------------------------------------
                0: begin
                    case (address[9:2])
                        // x1 = 0x41
                        8'd0:
                            program_word =
                                make_i(
                                    12'h041,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1,
                        8'd2,
                        8'd3:
                            program_word = RV32I_NOP;

                        // lw x2, 0(x1), misaligned
                        8'd4:
                            program_word =
                                make_i(
                                    12'h000,
                                    5'd1,
                                    FUNCT3_LW,
                                    5'd2,
                                    OPCODE_LOAD
                                );

                        // wrong-path, must not commit
                        8'd5:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd3,
                                    OPCODE_OP_IMM
                                );

                        // trap handler
                        8'd64:
                            program_word =
                                make_i(
                                    12'd7,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd4,
                                    OPCODE_OP_IMM
                                );

                        default:
                            program_word = RV32I_NOP;
                    endcase
                end

                // ------------------------------------------------------
                // Phase 1:
                //   sw x2, 0(x1), where x1 = 0x41.
                //   Word store to unaligned address must trap.
                // ------------------------------------------------------
                1: begin
                    case (address[9:2])
                        // x1 = 0x41
                        8'd0:
                            program_word =
                                make_i(
                                    12'h041,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1,
                        8'd2,
                        8'd3:
                            program_word = RV32I_NOP;

                        // x2 = 0x55
                        8'd4:
                            program_word =
                                make_i(
                                    12'h055,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd2,
                                    OPCODE_OP_IMM
                                );

                        8'd5,
                        8'd6,
                        8'd7:
                            program_word = RV32I_NOP;

                        // sw x2, 0(x1), misaligned
                        8'd8:
                            program_word =
                                make_s(
                                    12'h000,
                                    5'd2,
                                    5'd1,
                                    FUNCT3_SW,
                                    OPCODE_STORE
                                );

                        // wrong-path, must not commit
                        8'd9:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd3,
                                    OPCODE_OP_IMM
                                );

                        // trap handler
                        8'd64:
                            program_word =
                                make_i(
                                    12'd8,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd4,
                                    OPCODE_OP_IMM
                                );

                        default:
                            program_word = RV32I_NOP;
                    endcase
                end

                // ------------------------------------------------------
                // Phase 2:
                //   lw x2, 0(x1), where x1 = 0x50.
                //   Address is aligned, but DMEM response returns error.
                // ------------------------------------------------------
                2: begin
                    case (address[9:2])
                        // x1 = 0x50
                        8'd0:
                            program_word =
                                make_i(
                                    12'h050,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1,
                        8'd2,
                        8'd3:
                            program_word = RV32I_NOP;

                        // lw x2, 0(x1), access fault via dmem_rsp.error
                        8'd4:
                            program_word =
                                make_i(
                                    12'h000,
                                    5'd1,
                                    FUNCT3_LW,
                                    5'd2,
                                    OPCODE_LOAD
                                );

                        // wrong-path, must not commit
                        8'd5:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd3,
                                    OPCODE_OP_IMM
                                );

                        // trap handler
                        8'd64:
                            program_word =
                                make_i(
                                    12'd9,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd4,
                                    OPCODE_OP_IMM
                                );

                        default:
                            program_word = RV32I_NOP;
                    endcase
                end

                default: begin
                    program_word = RV32I_NOP;
                end
            endcase
        end
    endfunction

    function automatic trap_cause_code_t expected_cause();
        begin
            case (phase)
                0: expected_cause = EXC_LOAD_ADDR_MISALIGNED;
                1: expected_cause = EXC_STORE_ADDR_MISALIGNED;
                2: expected_cause = EXC_LOAD_ACCESS_FAULT;
                default: expected_cause = EXC_ILLEGAL_INSTRUCTION;
            endcase
        end
    endfunction

    function automatic addr_t expected_trap_pc();
        begin
            case (phase)
                0: expected_trap_pc = 32'h0000_0010;
                1: expected_trap_pc = 32'h0000_0020;
                2: expected_trap_pc = 32'h0000_0010;
                default: expected_trap_pc = '0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_tval();
        begin
            case (phase)
                0: expected_tval = 32'h0000_0041;
                1: expected_tval = 32'h0000_0041;
                2: expected_tval = 32'h0000_0050;
                default: expected_tval = '0;
            endcase
        end
    endfunction

    function automatic int unsigned expected_writes();
        begin
            case (phase)
                0: expected_writes = 2; // x1, x4
                1: expected_writes = 3; // x1, x2, x4
                2: expected_writes = 2; // x1, x4
                default: expected_writes = 0;
            endcase
        end
    endfunction

    function automatic int unsigned expected_dmem_requests();
        begin
            case (phase)
                0: expected_dmem_requests = 0;
                1: expected_dmem_requests = 0;
                2: expected_dmem_requests = 1;
                default: expected_dmem_requests = 0;
            endcase
        end
    endfunction

    function automatic reg_idx_t expected_rd(input int unsigned index);
        begin
            case (phase)
                0: begin
                    case (index)
                        0: expected_rd = 5'd1;
                        1: expected_rd = 5'd4;
                        default: expected_rd = REG_X0;
                    endcase
                end

                1: begin
                    case (index)
                        0: expected_rd = 5'd1;
                        1: expected_rd = 5'd2;
                        2: expected_rd = 5'd4;
                        default: expected_rd = REG_X0;
                    endcase
                end

                2: begin
                    case (index)
                        0: expected_rd = 5'd1;
                        1: expected_rd = 5'd4;
                        default: expected_rd = REG_X0;
                    endcase
                end

                default: expected_rd = REG_X0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_data(input int unsigned index);
        begin
            case (phase)
                0: begin
                    case (index)
                        0: expected_data = 32'h0000_0041;
                        1: expected_data = 32'h0000_0007;
                        default: expected_data = '0;
                    endcase
                end

                1: begin
                    case (index)
                        0: expected_data = 32'h0000_0041;
                        1: expected_data = 32'h0000_0055;
                        2: expected_data = 32'h0000_0008;
                        default: expected_data = '0;
                    endcase
                end

                2: begin
                    case (index)
                        0: expected_data = 32'h0000_0050;
                        1: expected_data = 32'h0000_0009;
                        default: expected_data = '0;
                    endcase
                end

                default: expected_data = '0;
            endcase
        end
    endfunction

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: phase=%0d %s", phase, message);
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

    // ------------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------------

    assign dmem_req_ready = !dmem_response_pending_q;
    assign dmem_rsp_valid = dmem_response_pending_q;

    always @* begin
        dmem_rsp           = '0;
        dmem_rsp.read_data = 32'hdead_beef;

        // Phase 2 intentionally injects load access fault.
        dmem_rsp.error =
            (phase == 2) &&
            (dmem_response_request_q.address == 32'h0000_0050);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_response_pending_q <= 1'b0;
        end
        else begin
            if (dmem_rsp_valid && dmem_rsp_ready) begin
                dmem_response_pending_q <= 1'b0;
            end

            if (dmem_req_valid && dmem_req_ready) begin
                dmem_response_pending_q <= 1'b1;
                dmem_response_request_q <= dmem_req;
                dmem_request_count++;

                $display(
                    "PHASE[%0d] DMEM_REQ[%0d]: addr=%08h write=%0b wstrb=%04b",
                    phase,
                    dmem_request_count,
                    dmem_req.address,
                    dmem_req.write,
                    dmem_req.write_strobe
                );

                if ((phase == 0) || (phase == 1)) begin
                    fail("Misaligned access unexpectedly issued DMEM request");
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Redirect monitor
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n && debug_redirect_valid) begin
            redirect_count++;

            $display(
                "PHASE[%0d] REDIRECT[%0d]: pc=%08h",
                phase,
                redirect_count,
                debug_redirect_pc
            );

            if (debug_redirect_pc != 32'h0000_0100) begin
                fail("Trap redirect PC mismatch");
            end
        end
    end

    // ------------------------------------------------------------------
    // Retirement scoreboard
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail("Unexpected baseline stall");
            end

            if (commit_valid && commit_trap) begin
                trap_count++;

                $display(
                    "PHASE[%0d] TRAP[%0d]: pc=%08h insn=%08h",
                    phase,
                    trap_count,
                    commit_pc,
                    commit_instruction
                );

                if (commit_pc != expected_trap_pc()) begin
                    fail("Trap PC mismatch");
                end
            end

            if (commit_valid && commit_rd_write) begin
                $display(
                    "PHASE[%0d] WRITEBACK[%0d]: pc=%08h x%0d=%08h",
                    phase,
                    write_count,
                    commit_pc,
                    commit_rd_index,
                    commit_rd_data
                );

                if (commit_rd_index == 5'd3) begin
                    fail("Wrong-path x3 committed");
                end

                if (((phase == 0) || (phase == 2)) && commit_rd_index == 5'd2) begin
                    fail("Faulting load wrote x2");
                end

                if (write_count >= expected_writes()) begin
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
                end
            end

            if (
                (write_count == expected_writes()) &&
                (trap_count == 1) &&
                (redirect_count == 1)
            ) begin
                phase_done = 1'b1;
            end
        end
    end

    task automatic run_phase(input int unsigned phase_id);
        begin
            phase = phase_id;

            write_count        = 0;
            trap_count         = 0;
            redirect_count     = 0;
            dmem_request_count = 0;
            phase_done         = 1'b0;

            rst_n = 1'b0;
            repeat (4) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            wait (phase_done);

            repeat (6) @(posedge clk);

            if (dmem_request_count != expected_dmem_requests()) begin
                fail("DMEM request count mismatch");
            end

            if (dut.u_datapath.csr_mepc !== expected_trap_pc()) begin
                fail("CSR mepc mismatch");
            end

            if (dut.u_datapath.csr_mcause[4:0] !== expected_cause()) begin
                fail("CSR mcause mismatch");
            end

            if (dut.u_datapath.csr_mcause[31] !== 1'b0) begin
                fail("CSR mcause interrupt bit mismatch");
            end

            if (dut.u_datapath.csr_mtval !== expected_tval()) begin
                fail("CSR mtval mismatch");
            end

            $display("------------------------------------------");
            $display("Phase %0d complete", phase_id);
            $display("Writes:        %0d", write_count);
            $display("Traps:         %0d", trap_count);
            $display("Redirects:     %0d", redirect_count);
            $display("DMEM requests: %0d", dmem_request_count);
            $display("mepc:          %08h", dut.u_datapath.csr_mepc);
            $display("mcause:        %08h", dut.u_datapath.csr_mcause);
            $display("mtval:         %08h", dut.u_datapath.csr_mtval);
        end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        phase       = 0;
        error_count = 0;

        run_phase(0); // load address misaligned
        run_phase(1); // store address misaligned
        run_phase(2); // load access fault

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I LSU exception trap test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("==========================================");
        $display("RV32I LSU exception trap test: PASS");
        $display("Load misaligned precise trap:  PASS");
        $display("Store misaligned precise trap: PASS");
        $display("Load access fault trap:        PASS");
        $finish;
    end

    initial begin
        repeat (12000) @(posedge clk);

        $fatal(
            1,
            "RV32I LSU exception trap test timeout"
        );
    end

endmodule
