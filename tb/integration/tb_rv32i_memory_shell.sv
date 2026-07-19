`timescale 1ns/1ps

module tb_rv32i_memory_shell;

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

    logic           response_pending_q;
    imem_request_t  response_request_q;

    logic           seen_memory_stall;
    int unsigned    error_count;

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
            case (address[7:2])
                6'd0: begin
                    // LW x1, 0(x0)
                    program_word =
                        make_i(
                            12'd0,
                            5'd0,
                            FUNCT3_LW,
                            5'd1,
                            OPCODE_LOAD
                        );
                end

                default: begin
                    program_word = RV32I_NOP;
                end
            endcase
        end
    endfunction

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    assign imem_req_ready = !response_pending_q;

    assign imem_rsp_valid = response_pending_q;

    always_comb begin
        imem_rsp             = '0;
        imem_rsp.instruction = program_word(response_request_q.address);
        imem_rsp.error       = 1'b0;
        imem_rsp.epoch       = response_request_q.epoch;
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

    always @(posedge clk) begin
        if (rst_n) begin
            if (baseline_stall) begin
                seen_memory_stall <= 1'b1;
            end

            if (dmem_req_valid) begin
                fail(
                    "Memory shell must not issue DMEM request before LSU Step 6"
                );
            end

            if (dmem_rsp_ready) begin
                fail(
                    "Memory shell must not consume DMEM response before LSU Step 6"
                );
            end

            if (commit_valid) begin
                fail(
                    "Unsupported memory instruction must not retire in Step 5H"
                );
            end

            if (commit_rd_write) begin
                fail(
                    "Unsupported memory instruction must not write GPR"
                );
            end
        end
    end

    initial begin
        clk               = 1'b0;
        rst_n             = 1'b0;

        dmem_req_ready    = 1'b1;
        dmem_rsp_valid    = 1'b0;
        dmem_rsp          = '0;

        seen_memory_stall = 1'b0;
        error_count       = 0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        repeat (80) @(posedge clk);

        if (!seen_memory_stall) begin
            fail("LW did not trigger baseline memory stall");
        end

        $display("------------------------------------------");
        $display("Memory instruction stall observed: %0b", seen_memory_stall);
        $display("DMEM requests observed:             0");
        $display("DMEM responses consumed:            0");
        $display("Unsupported memory retires:         0");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I memory shell test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I memory shell test: PASS");
        $finish;
    end

endmodule
