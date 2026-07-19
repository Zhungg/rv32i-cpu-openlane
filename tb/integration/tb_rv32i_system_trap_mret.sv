`timescale 1ns/1ps

module tb_rv32i_system_trap_mret;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    localparam insn_t INSN_ECALL  = 32'h0000_0073;
    localparam insn_t INSN_EBREAK = 32'h0010_0073;
    localparam insn_t INSN_MRET   = 32'h3020_0073;

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

    int unsigned    error_count;
    int unsigned    write_count;
    int unsigned    trap_count;
    int unsigned    redirect_count;
    int unsigned    mret_count;
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

    function automatic insn_t program_word(input addr_t address);
        begin
            program_word = RV32I_NOP;

            case (phase)
                0: begin
                    case (address[9:2])
                        8'd0:
                            program_word =
                                make_i(
                                    12'd5,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1:
                            program_word = INSN_ECALL;

                        // Wrong path. Must not commit.
                        8'd2:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd2,
                                    OPCODE_OP_IMM
                                );

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

                1: begin
                    case (address[9:2])
                        8'd0:
                            program_word =
                                make_i(
                                    12'd6,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1:
                            program_word = INSN_EBREAK;

                        // Wrong path. Must not commit.
                        8'd2:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd2,
                                    OPCODE_OP_IMM
                                );

                        8'd64:
                            program_word =
                                make_i(
                                    12'd8,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd3,
                                    OPCODE_OP_IMM
                                );

                        default:
                            program_word = RV32I_NOP;
                    endcase
                end

                2: begin
                    case (address[9:2])
                        8'd0:
                            program_word =
                                make_i(
                                    12'd1,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd1,
                                    OPCODE_OP_IMM
                                );

                        8'd1:
                            program_word = INSN_ECALL;

                        // Wrong path after trap. Must not commit.
                        8'd2:
                            program_word =
                                make_i(
                                    12'd99,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd2,
                                    OPCODE_OP_IMM
                                );

                        // Trap handler executes MRET.
                        8'd64:
                            program_word = INSN_MRET;

                        // Wrong path after MRET. Must be flushed.
                        8'd65:
                            program_word =
                                make_i(
                                    12'd9,
                                    5'd0,
                                    FUNCT3_ADD_SUB,
                                    5'd3,
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
                0: expected_cause = EXC_ECALL_FROM_M;
                1: expected_cause = EXC_BREAKPOINT;
                2: expected_cause = EXC_ECALL_FROM_M;
                default: expected_cause = EXC_ILLEGAL_INSTRUCTION;
            endcase
        end
    endfunction

    function automatic reg_idx_t expected_rd(input int unsigned index);
        begin
            case (phase)
                0: begin
                    case (index)
                        0: expected_rd = 5'd1;
                        1: expected_rd = 5'd3;
                        default: expected_rd = REG_X0;
                    endcase
                end

                1: begin
                    case (index)
                        0: expected_rd = 5'd1;
                        1: expected_rd = 5'd3;
                        default: expected_rd = REG_X0;
                    endcase
                end

                2: begin
                    case (index)
                        0: expected_rd = 5'd1;
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
                        0: expected_data = 32'h0000_0005;
                        1: expected_data = 32'h0000_0007;
                        default: expected_data = '0;
                    endcase
                end

                1: begin
                    case (index)
                        0: expected_data = 32'h0000_0006;
                        1: expected_data = 32'h0000_0008;
                        default: expected_data = '0;
                    endcase
                end

                2: begin
                    case (index)
                        0: expected_data = 32'h0000_0001;
                        default: expected_data = '0;
                    endcase
                end

                default: expected_data = '0;
            endcase
        end
    endfunction

    function automatic int unsigned expected_writes();
        begin
            case (phase)
                0: expected_writes = 2;
                1: expected_writes = 2;
                2: expected_writes = 1;
                default: expected_writes = 0;
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

    // No data memory expected.
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
                "PHASE[%0d] REDIRECT[%0d]: pc=%08h",
                phase,
                redirect_count,
                debug_redirect_pc
            );

            if ((phase == 0) || (phase == 1)) begin
                if (debug_redirect_pc != 32'h0000_0100) begin
                    fail("trap redirect PC mismatch");
                end
            end
            else if (phase == 2) begin
                if (
                    (redirect_count == 1) &&
                    (debug_redirect_pc != 32'h0000_0100)
                ) begin
                    fail("phase2 trap redirect PC mismatch");
                end

                if (
                    (redirect_count == 2) &&
                    (debug_redirect_pc != 32'h0000_0004)
                ) begin
                    fail("phase2 MRET redirect PC mismatch");
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Retirement scoreboard
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail("unexpected baseline stall");
            end

            if (dmem_req_valid) begin
                fail("unexpected DMEM request");
            end

            if (
                commit_valid &&
                !commit_trap &&
                (commit_instruction == INSN_MRET)
            ) begin
                mret_count++;

                $display(
                    "PHASE[%0d] MRET[%0d]: pc=%08h",
                    phase,
                    mret_count,
                    commit_pc
                );
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

                if (commit_pc != 32'h0000_0004) begin
                    fail("trap PC mismatch");
                end

                // CSR state is updated in rv32i_csr_file with
                // nonblocking assignments on the same clock edge as
                // trap commit. Do not sample CSR state here because this
                // scoreboard block may observe the old value.
                //
                // CSR state is checked after the phase is complete.
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

                if (commit_rd_index == 5'd2) begin
                    fail("wrong-path x2 committed");
                end

                if ((phase == 2) && (commit_rd_index == 5'd3)) begin
                    fail("wrong-path x3 after MRET committed");
                end

                if (write_count >= expected_writes()) begin
                    fail("unexpected extra register write");
                end
                else begin
                    if (commit_rd_index !== expected_rd(write_count)) begin
                        fail("register write order mismatch");
                    end

                    if (commit_rd_data !== expected_data(write_count)) begin
                        fail("register write data mismatch");
                    end

                    write_count++;
                end
            end

            if ((phase == 0) || (phase == 1)) begin
                if (
                    (write_count == expected_writes()) &&
                    (trap_count == 1) &&
                    (redirect_count == 1)
                ) begin
                    phase_done = 1'b1;
                end
            end
            else if (phase == 2) begin
                if (
                    (write_count == expected_writes()) &&
                    (trap_count == 1) &&
                    (redirect_count == 2) &&
                    (mret_count == 1)
                ) begin
                    phase_done = 1'b1;
                end
            end
        end
    end

    task automatic run_phase(input int unsigned phase_id);
        begin
            phase = phase_id;

            write_count    = 0;
            trap_count     = 0;
            redirect_count = 0;
            mret_count     = 0;
            phase_done     = 1'b0;

            rst_n = 1'b0;
            repeat (4) @(posedge clk);

            @(negedge clk);
            rst_n = 1'b1;

            wait (phase_done);

            if (phase_id == 2) begin
                // Small window to catch an unflushed wrong-path handler
                // instruction after MRET.
                repeat (3) @(posedge clk);
            end
            else begin
                repeat (4) @(posedge clk);
            end

            if (dut.u_datapath.csr_mepc !== 32'h0000_0004) begin
                fail("CSR mepc mismatch after phase completion");
            end

            if (dut.u_datapath.csr_mcause[4:0] !== expected_cause()) begin
                fail("CSR mcause mismatch after phase completion");
            end

            if (dut.u_datapath.csr_mcause[31] !== 1'b0) begin
                fail("CSR mcause interrupt bit mismatch after phase completion");
            end

            if (phase_id == 1) begin
                if (dut.u_datapath.csr_mtval !== 32'h0000_0004) begin
                    fail("EBREAK mtval mismatch after phase completion");
                end
            end
            else begin
                if (dut.u_datapath.csr_mtval !== 32'h0000_0000) begin
                    fail("ECALL mtval mismatch after phase completion");
                end
            end

            if (
                dut.u_datapath.csr_mstatus[
                    MSTATUS_MPP_MSB:MSTATUS_MPP_LSB
                ] !== 2'b11
            ) begin
                fail("CSR mstatus.MPP mismatch after phase completion");
            end

            $display("------------------------------------------");
            $display("Phase %0d complete", phase_id);
            $display("Writes:    %0d", write_count);
            $display("Traps:     %0d", trap_count);
            $display("Redirects: %0d", redirect_count);
            $display("MRETs:     %0d", mret_count);
            $display("mepc:      %08h", dut.u_datapath.csr_mepc);
            $display("mcause:    %08h", dut.u_datapath.csr_mcause);
            $display("mtval:     %08h", dut.u_datapath.csr_mtval);
            $display("mstatus:   %08h", dut.u_datapath.csr_mstatus);
        end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        phase       = 0;
        error_count = 0;

        run_phase(0); // ECALL
        run_phase(1); // EBREAK
        run_phase(2); // MRET

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I system trap/MRET test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("==========================================");
        $display("RV32I system trap/MRET test: PASS");
        $display("ECALL precise trap: PASS");
        $display("EBREAK precise trap: PASS");
        $display("MRET redirect:      PASS");
        $finish;
    end

    initial begin
        repeat (10000) @(posedge clk);

        $fatal(
            1,
            "RV32I system trap/MRET test timeout"
        );
    end

endmodule
