`timescale 1ns/1ps

module tb_rv32i_load_use_hazard;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_types_pkg::*;

    localparam int unsigned EXPECTED_WRITES = 4;
    localparam int unsigned EXPECTED_DMEM_REQUESTS = 2;

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

    logic           dmem_response_pending_q;
    dmem_request_t  dmem_response_request_q;

    xlen_t          data_memory [0:63];

    int unsigned    error_count;
    int unsigned    write_count;
    int unsigned    dmem_request_count;
    int unsigned    load_use_stall_count;
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
            case (address[8:2])
                // x1 = 0x40
                7'd0:
                    program_word =
                        make_i(
                            12'h040,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd1,
                            OPCODE_OP_IMM
                        );

                7'd1,
                7'd2,
                7'd3:
                    program_word = RV32I_NOP;

                // x2 = 21
                7'd4:
                    program_word =
                        make_i(
                            12'd21,
                            5'd0,
                            FUNCT3_ADD_SUB,
                            5'd2,
                            OPCODE_OP_IMM
                        );

                7'd5,
                7'd6,
                7'd7:
                    program_word = RV32I_NOP;

                // sw x2, 0(x1)
                7'd8:
                    program_word =
                        make_s(
                            12'h000,
                            5'd2,
                            5'd1,
                            FUNCT3_SW,
                            OPCODE_STORE
                        );

                7'd9,
                7'd10,
                7'd11:
                    program_word = RV32I_NOP;

                // lw x3, 0(x1)
                7'd12:
                    program_word =
                        make_i(
                            12'h000,
                            5'd1,
                            FUNCT3_LW,
                            5'd3,
                            OPCODE_LOAD
                        );

                // Immediate load-use dependency.
                // No NOP is inserted here on purpose.
                // Hazard unit must stall this ADD until x3 is available.
                7'd13:
                    program_word =
                        make_r(
                            FUNCT7_BASE,
                            5'd3,
                            5'd3,
                            FUNCT3_ADD_SUB,
                            5'd4,
                            OPCODE_OP
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
                default: expected_rd = REG_X0;
            endcase
        end
    endfunction

    function automatic xlen_t expected_data(input int unsigned index);
        begin
            case (index)
                0: expected_data = 32'h0000_0040;
                1: expected_data = 32'h0000_0015;
                2: expected_data = 32'h0000_0015;
                3: expected_data = 32'h0000_002a;
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

    // ------------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------------

    assign dmem_req_ready = !dmem_response_pending_q;
    assign dmem_rsp_valid = dmem_response_pending_q;

    always @* begin
        dmem_rsp           = '0;
        dmem_rsp.read_data =
            data_memory[dmem_response_request_q.address[7:2]];
        dmem_rsp.error     = 1'b0;
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
                    "DMEM_REQ[%0d]: addr=%08h write=%0b wdata=%08h wstrb=%04b",
                    dmem_request_count,
                    dmem_req.address,
                    dmem_req.write,
                    dmem_req.write_data,
                    dmem_req.write_strobe
                );

                if (dmem_req.write) begin
                    if (dmem_req.write_strobe[0]) begin
                        data_memory[dmem_req.address[7:2]][7:0]
                            <= dmem_req.write_data[7:0];
                    end

                    if (dmem_req.write_strobe[1]) begin
                        data_memory[dmem_req.address[7:2]][15:8]
                            <= dmem_req.write_data[15:8];
                    end

                    if (dmem_req.write_strobe[2]) begin
                        data_memory[dmem_req.address[7:2]][23:16]
                            <= dmem_req.write_data[23:16];
                    end

                    if (dmem_req.write_strobe[3]) begin
                        data_memory[dmem_req.address[7:2]][31:24]
                            <= dmem_req.write_data[31:24];
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Hazard monitor
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n && dut.u_datapath.id_load_use_stall) begin
            load_use_stall_count++;

            $display(
                "LOAD_USE_STALL[%0d]",
                load_use_stall_count
            );
        end
    end

    // ------------------------------------------------------------------
    // Retirement scoreboard
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                fail("Unexpected unsupported-instruction stall");
            end

            if (commit_valid && commit_trap) begin
                fail("Unexpected trap");
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

    integer init_index;

    initial begin
        clk                   = 1'b0;
        rst_n                 = 1'b0;

        error_count           = 0;
        write_count           = 0;
        dmem_request_count    = 0;
        load_use_stall_count  = 0;
        test_done             = 1'b0;

        for (init_index = 0; init_index < 64; init_index++) begin
            data_memory[init_index] = 32'h0000_0000;
        end

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (test_done);

        repeat (8) @(posedge clk);

        if (dmem_request_count != EXPECTED_DMEM_REQUESTS) begin
            fail("DMEM request count mismatch");
        end

        if (load_use_stall_count == 0) begin
            fail("Load-use hazard stall was not observed");
        end

        if (data_memory[32'h40 >> 2] !== 32'h0000_0015) begin
            fail("Final memory word mismatch");
        end

        $display("------------------------------------------");
        $display("Architectural writes checked: %0d", write_count);
        $display("DMEM requests checked:        %0d", dmem_request_count);
        $display("Load-use stalls observed:     %0d", load_use_stall_count);
        $display("Final memory word @0x40:      %08h", data_memory[32'h40 >> 2]);

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I load-use hazard test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I load-use hazard test: PASS");
        $finish;
    end

    initial begin
        repeat (5000) @(posedge clk);

        $fatal(
            1,
            "RV32I load-use hazard test timeout"
        );
    end

endmodule
