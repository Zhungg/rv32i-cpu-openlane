`timescale 1ns/1ps

module tb_rv32i_pipeline_registers;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    logic clk;
    logic rst_n;

    logic flush_all;
    logic kill_all;

    // ------------------------------------------------------------------
    // IF/ID
    // ------------------------------------------------------------------

    logic           if_valid_i;
    logic           if_ready_o;
    if_id_payload_t if_payload_i;

    logic           if_valid_o;
    logic           if_ready_i;
    if_id_payload_t if_payload_o;

    // ------------------------------------------------------------------
    // ID/EX
    // ------------------------------------------------------------------

    logic           id_valid_i;
    logic           id_ready_o;
    id_ex_payload_t id_payload_i;

    logic           id_valid_o;
    logic           id_ready_i;
    id_ex_payload_t id_payload_o;

    // ------------------------------------------------------------------
    // EX/MEM
    // ------------------------------------------------------------------

    logic            ex_valid_i;
    logic            ex_ready_o;
    ex_mem_payload_t ex_payload_i;

    logic            ex_valid_o;
    logic            ex_ready_i;
    ex_mem_payload_t ex_payload_o;

    // ------------------------------------------------------------------
    // MEM/WB
    // ------------------------------------------------------------------

    logic            mem_valid_i;
    logic            mem_ready_o;
    mem_wb_payload_t mem_payload_i;

    logic            mem_valid_o;
    logic            mem_ready_i;
    mem_wb_payload_t mem_payload_o;

    // Expected payload patterns.
    if_id_payload_t  if_pattern_a;
    if_id_payload_t  if_pattern_b;

    id_ex_payload_t  id_pattern_a;
    id_ex_payload_t  id_pattern_b;

    ex_mem_payload_t ex_pattern_a;
    ex_mem_payload_t ex_pattern_b;

    mem_wb_payload_t mem_pattern_a;
    mem_wb_payload_t mem_pattern_b;

    int unsigned error_count;

    rv32i_if_id u_if_id (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .flush_i   (flush_all),
        .kill_i    (kill_all),

        .valid_i   (if_valid_i),
        .ready_o   (if_ready_o),
        .payload_i (if_payload_i),

        .valid_o   (if_valid_o),
        .ready_i   (if_ready_i),
        .payload_o (if_payload_o)
    );

    rv32i_id_ex u_id_ex (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .flush_i   (flush_all),
        .kill_i    (kill_all),

        .valid_i   (id_valid_i),
        .ready_o   (id_ready_o),
        .payload_i (id_payload_i),

        .valid_o   (id_valid_o),
        .ready_i   (id_ready_i),
        .payload_o (id_payload_o)
    );

    rv32i_ex_mem u_ex_mem (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .flush_i   (flush_all),
        .kill_i    (kill_all),

        .valid_i   (ex_valid_i),
        .ready_o   (ex_ready_o),
        .payload_i (ex_payload_i),

        .valid_o   (ex_valid_o),
        .ready_i   (ex_ready_i),
        .payload_o (ex_payload_o)
    );

    rv32i_mem_wb u_mem_wb (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .flush_i   (flush_all),
        .kill_i    (kill_all),

        .valid_i   (mem_valid_i),
        .ready_o   (mem_ready_o),
        .payload_i (mem_payload_i),

        .valid_o   (mem_valid_o),
        .ready_i   (mem_ready_i),
        .payload_o (mem_payload_o)
    );

    always #5 clk = ~clk;

    task automatic record_failure(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    task automatic check_all_valid(
        input logic expected,
        input string test_name
    );
        begin
            if (
                (if_valid_o  !== expected) ||
                (id_valid_o  !== expected) ||
                (ex_valid_o  !== expected) ||
                (mem_valid_o !== expected)
            ) begin
                record_failure(test_name);
                $display(
                    "      valid IF/ID=%0b ID/EX=%0b EX/MEM=%0b MEM/WB=%0b",
                    if_valid_o,
                    id_valid_o,
                    ex_valid_o,
                    mem_valid_o
                );
            end
            else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask

    task automatic check_pattern_a(input string test_name);
        begin
            if (
                (if_payload_o  !== if_pattern_a)  ||
                (id_payload_o  !== id_pattern_a)  ||
                (ex_payload_o  !== ex_pattern_a)  ||
                (mem_payload_o !== mem_pattern_a)
            ) begin
                record_failure(test_name);
            end
            else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask

    task automatic check_pattern_b(input string test_name);
        begin
            if (
                (if_payload_o  !== if_pattern_b)  ||
                (id_payload_o  !== id_pattern_b)  ||
                (ex_payload_o  !== ex_pattern_b)  ||
                (mem_payload_o !== mem_pattern_b)
            ) begin
                record_failure(test_name);
            end
            else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        flush_all   = 1'b0;
        kill_all    = 1'b0;
        error_count = 0;

        if_valid_i  = 1'b0;
        id_valid_i  = 1'b0;
        ex_valid_i  = 1'b0;
        mem_valid_i = 1'b0;

        if_ready_i  = 1'b1;
        id_ready_i  = 1'b1;
        ex_ready_i  = 1'b1;
        mem_ready_i = 1'b1;

        if_payload_i  = '0;
        id_payload_i  = '0;
        ex_payload_i  = '0;
        mem_payload_i = '0;

        // --------------------------------------------------------------
        // Construct deterministic full-payload test patterns.
        // --------------------------------------------------------------

        if_pattern_a = '0;
        if_pattern_a.pc          = 32'h0000_1000;
        if_pattern_a.instruction = 32'h0010_0093;
        if_pattern_a.prediction.valid   = 1'b1;
        if_pattern_a.prediction.taken   = 1'b0;
        if_pattern_a.prediction.next_pc = 32'h0000_1004;

        if_pattern_b = '1;
        if_pattern_b.pc          = 32'h0000_2000;
        if_pattern_b.instruction = 32'h0020_0113;
        if_pattern_b.fetch_error = 1'b0;

        id_pattern_a = '0;
        id_pattern_a.pc          = 32'h0000_3000;
        id_pattern_a.instruction = 32'h0020_81b3;
        id_pattern_a.rs1_index   = 5'd1;
        id_pattern_a.rs2_index   = 5'd2;
        id_pattern_a.rd_index    = 5'd3;
        id_pattern_a.rs1_value   = 32'h1111_1111;
        id_pattern_a.rs2_value   = 32'h2222_2222;
        id_pattern_a.control.alu_op = ALU_ADD;

        id_pattern_b = '1;
        id_pattern_b.pc          = 32'h0000_4000;
        id_pattern_b.instruction = 32'h4020_81b3;
        id_pattern_b.exception.valid = 1'b0;

        ex_pattern_a = '0;
        ex_pattern_a.pc               = 32'h0000_5000;
        ex_pattern_a.instruction      = 32'h0020_81b3;
        ex_pattern_a.rd_index         = 5'd3;
        ex_pattern_a.alu_result       = 32'h3333_3333;
        ex_pattern_a.actual_next_pc   = 32'h0000_5004;
        ex_pattern_a.control.wb_sel   = WB_ALU;

        ex_pattern_b = '1;
        ex_pattern_b.pc               = 32'h0000_6000;
        ex_pattern_b.instruction      = 32'h0000_0063;
        ex_pattern_b.branch_mispredict = 1'b0;
        ex_pattern_b.exception.valid   = 1'b0;

        mem_pattern_a = '0;
        mem_pattern_a.pc               = 32'h0000_7000;
        mem_pattern_a.instruction      = 32'h0000_2283;
        mem_pattern_a.rd_index         = 5'd5;
        mem_pattern_a.memory_result    = 32'hdead_beef;
        mem_pattern_a.control.wb_sel   = WB_MEMORY;

        mem_pattern_b = '1;
        mem_pattern_b.pc               = 32'h0000_8000;
        mem_pattern_b.instruction      = 32'h0010_0073;
        mem_pattern_b.exception.valid  = 1'b0;

        // --------------------------------------------------------------
        // Asynchronous reset assertion.
        // --------------------------------------------------------------

        repeat (2) @(posedge clk);
        #1;

        check_all_valid(
            1'b0,
            "Reset clears all stage valid bits"
        );

        if (
            !if_ready_o ||
            !id_ready_o ||
            !ex_ready_o ||
            !mem_ready_o
        ) begin
            record_failure("Empty stages must report ready");
        end
        else begin
            $display("PASS: Empty stages report ready");
        end

        // Synchronously safe reset deassertion.
        @(negedge clk);
        rst_n = 1'b1;

        // --------------------------------------------------------------
        // Transfer pattern A.
        // --------------------------------------------------------------

        if_valid_i  = 1'b1;
        id_valid_i  = 1'b1;
        ex_valid_i  = 1'b1;
        mem_valid_i = 1'b1;

        if_payload_i  = if_pattern_a;
        id_payload_i  = id_pattern_a;
        ex_payload_i  = ex_pattern_a;
        mem_payload_i = mem_pattern_a;

        @(posedge clk);
        #1;

        check_all_valid(
            1'b1,
            "Valid inputs populate all stages"
        );

        check_pattern_a(
            "Pattern A transferred without corruption"
        );

        // --------------------------------------------------------------
        // Stall: downstream is not ready, pattern B must not overwrite A.
        // --------------------------------------------------------------

        @(negedge clk);

        if_ready_i  = 1'b0;
        id_ready_i  = 1'b0;
        ex_ready_i  = 1'b0;
        mem_ready_i = 1'b0;

        if_payload_i  = if_pattern_b;
        id_payload_i  = id_pattern_b;
        ex_payload_i  = ex_pattern_b;
        mem_payload_i = mem_pattern_b;

        #1;

        if (
            if_ready_o ||
            id_ready_o ||
            ex_ready_o ||
            mem_ready_o
        ) begin
            record_failure(
                "Full stalled stages must deassert upstream ready"
            );
        end
        else begin
            $display(
                "PASS: Full stalled stages deassert upstream ready"
            );
        end

        @(posedge clk);
        #1;

        check_all_valid(
            1'b1,
            "Stall preserves valid state"
        );

        check_pattern_a(
            "Stall preserves existing payload"
        );

        // --------------------------------------------------------------
        // Release stall and transfer pattern B.
        // --------------------------------------------------------------

        @(negedge clk);

        if_ready_i  = 1'b1;
        id_ready_i  = 1'b1;
        ex_ready_i  = 1'b1;
        mem_ready_i = 1'b1;

        @(posedge clk);
        #1;

        check_pattern_b(
            "Pattern B captured after stall release"
        );

        // --------------------------------------------------------------
        // Flush has priority over transfer and downstream stall.
        // --------------------------------------------------------------

        @(negedge clk);

        flush_all = 1'b1;

        if_ready_i  = 1'b0;
        id_ready_i  = 1'b0;
        ex_ready_i  = 1'b0;
        mem_ready_i = 1'b0;

        @(posedge clk);
        #1;

        check_all_valid(
            1'b0,
            "Flush invalidates all occupied stages"
        );

        @(negedge clk);
        flush_all = 1'b0;

        if_ready_i  = 1'b1;
        id_ready_i  = 1'b1;
        ex_ready_i  = 1'b1;
        mem_ready_i = 1'b1;

        // --------------------------------------------------------------
        // Refill, then verify kill behavior.
        // --------------------------------------------------------------

        if_payload_i  = if_pattern_a;
        id_payload_i  = id_pattern_a;
        ex_payload_i  = ex_pattern_a;
        mem_payload_i = mem_pattern_a;

        @(posedge clk);
        #1;

        check_all_valid(
            1'b1,
            "Stages refill after flush"
        );

        @(negedge clk);
        kill_all = 1'b1;

        @(posedge clk);
        #1;

        check_all_valid(
            1'b0,
            "Kill invalidates all occupied stages"
        );

        @(negedge clk);
        kill_all = 1'b0;

        // --------------------------------------------------------------
        // Bubble insertion.
        // --------------------------------------------------------------

        if_valid_i  = 1'b0;
        id_valid_i  = 1'b0;
        ex_valid_i  = 1'b0;
        mem_valid_i = 1'b0;

        @(posedge clk);
        #1;

        check_all_valid(
            1'b0,
            "Invalid input inserts bubble"
        );

        $display("------------------------------------------");
        $display(
            "IF/ID payload width:  %0d",
            $bits(if_id_payload_t)
        );
        $display(
            "ID/EX payload width:  %0d",
            $bits(id_ex_payload_t)
        );
        $display(
            "EX/MEM payload width: %0d",
            $bits(ex_mem_payload_t)
        );
        $display(
            "MEM/WB payload width: %0d",
            $bits(mem_wb_payload_t)
        );
        $display("Resettable pipeline state: 4 valid bits");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I pipeline register test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I pipeline register test: PASS");
        $finish;
    end

endmodule
