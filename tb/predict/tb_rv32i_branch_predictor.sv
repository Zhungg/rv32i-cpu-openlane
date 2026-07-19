`timescale 1ns/1ps

module tb_rv32i_branch_predictor;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    localparam int unsigned GHR_W = 4;
    localparam int unsigned PHT_W = 6;
    localparam int unsigned BTB_W = 4;

    logic               clk;
    logic               rst_n;
    logic               clear;

    addr_t              fetch_pc;
    logic               predict_taken;
    addr_t              predict_pc;
    logic [PHT_W-1:0]   predict_pht_index;
    logic [GHR_W-1:0]   predict_ghr;
    logic               predict_btb_hit;
    addr_t              predict_btb_target;

    logic               update_valid;
    addr_t              update_pc;
    logic               update_taken;
    addr_t              update_target;
    logic [PHT_W-1:0]   update_pht_index;

    int unsigned        error_count;
    int unsigned        train_count;

    rv32i_branch_predictor #(
        .GHR_WIDTH       (GHR_W),
        .PHT_INDEX_WIDTH (PHT_W),
        .BTB_INDEX_WIDTH (BTB_W)
    ) dut (
        .clk_i                  (clk),
        .rst_ni                 (rst_n),

        .clear_i                (clear),

        .fetch_pc_i             (fetch_pc),
        .predict_taken_o        (predict_taken),
        .predict_pc_o           (predict_pc),
        .predict_pht_index_o    (predict_pht_index),
        .predict_ghr_o          (predict_ghr),
        .predict_btb_hit_o      (predict_btb_hit),
        .predict_btb_target_o   (predict_btb_target),

        .update_valid_i         (update_valid),
        .update_pc_i            (update_pc),
        .update_taken_i         (update_taken),
        .update_target_i        (update_target),
        .update_pht_index_i     (update_pht_index)
    );

    always #5 clk = ~clk;

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    task automatic apply_update(
        input addr_t              pc,
        input logic               taken,
        input addr_t              target,
        input logic [PHT_W-1:0]   pht_index
    );
        begin
            @(negedge clk);
            update_valid     = 1'b1;
            update_pc        = pc;
            update_taken     = taken;
            update_target    = target;
            update_pht_index = pht_index;

            @(negedge clk);
            update_valid     = 1'b0;
            update_pc        = '0;
            update_taken     = 1'b0;
            update_target    = '0;
            update_pht_index = '0;
        end
    endtask

    task automatic train_current_context_taken(
        input addr_t pc,
        input addr_t target
    );
        begin
            fetch_pc = pc;
            #1;

            $display(
                "TRAIN[%0d]: pc=%08h ghr=%0h pht_index=%0h target=%08h",
                train_count,
                pc,
                predict_ghr,
                predict_pht_index,
                target
            );

            apply_update(
                pc,
                1'b1,
                target,
                predict_pht_index
            );

            train_count++;
        end
    endtask

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        clear            = 1'b0;

        fetch_pc         = 32'h0000_0020;
        update_valid     = 1'b0;
        update_pc        = '0;
        update_taken     = 1'b0;
        update_target    = '0;
        update_pht_index = '0;

        error_count      = 0;
        train_count      = 0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(posedge clk);

        // --------------------------------------------------------------
        // Reset behavior
        // --------------------------------------------------------------

        fetch_pc = 32'h0000_0020;
        #1;

        if (predict_taken !== 1'b0) begin
            fail("Initial prediction should be not taken");
        end

        if (predict_pc !== 32'h0000_0024) begin
            fail("Initial predicted PC should be PC+4");
        end

        if (predict_btb_hit !== 1'b0) begin
            fail("Initial BTB should miss");
        end

        if (predict_ghr !== '0) begin
            fail("Initial GHR should be zero");
        end

        // --------------------------------------------------------------
        // Gshare-aware training
        //
        // Because index = PC index XOR GHR, every branch update changes
        // the next PHT index. Therefore we train the current context
        // several times until GHR reaches a stable all-taken pattern.
        // --------------------------------------------------------------

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        train_current_context_taken(
            32'h0000_0020,
            32'h0000_0120
        );

        fetch_pc = 32'h0000_0020;
        #1;

        if (predict_btb_hit !== 1'b1) begin
            fail("BTB should hit after taken training");
        end

        if (predict_taken !== 1'b1) begin
            fail("Predictor should predict taken after gshare-aware training");
        end

        if (predict_pc !== 32'h0000_0120) begin
            fail("Taken predicted PC should be BTB target");
        end

        if (predict_btb_target !== 32'h0000_0120) begin
            fail("BTB target should be latest trained target");
        end

        // --------------------------------------------------------------
        // Not-taken update
        //
        // After a not-taken update, GHR changes again. The next gshare
        // context may map to a different PHT entry. Therefore we check
        // architectural predictor output, not a fixed old counter.
        // --------------------------------------------------------------

        fetch_pc = 32'h0000_0020;
        #1;

        apply_update(
            32'h0000_0020,
            1'b0,
            32'h0000_0120,
            predict_pht_index
        );

        fetch_pc = 32'h0000_0020;
        #1;

        if (predict_taken !== 1'b0) begin
            fail("Predictor should produce not-taken after not-taken context update");
        end

        if (predict_pc !== 32'h0000_0024) begin
            fail("Not-taken predicted PC should be PC+4");
        end

        // --------------------------------------------------------------
        // Direct-mapped BTB alias test
        //
        // 0x20 and 0x60 intentionally share the same low BTB index when
        // BTB_W = 4. The newer taken update should replace the entry.
        // Prediction may still be not-taken depending on current PHT/GHR,
        // so this section checks BTB hit and target only.
        // --------------------------------------------------------------

        fetch_pc = 32'h0000_0060;
        #1;

        apply_update(
            32'h0000_0060,
            1'b1,
            32'h0000_0200,
            predict_pht_index
        );

        fetch_pc = 32'h0000_0060;
        #1;

        if (predict_btb_hit !== 1'b1) begin
            fail("Aliased new PC should hit after BTB update");
        end

        if (predict_btb_target !== 32'h0000_0200) begin
            fail("Aliased BTB target mismatch");
        end

        // --------------------------------------------------------------
        // Clear GHR only
        // --------------------------------------------------------------

        @(negedge clk);
        clear = 1'b1;

        @(negedge clk);
        clear = 1'b0;

        fetch_pc = 32'h0000_0060;
        #1;

        if (predict_ghr !== '0) begin
            fail("GHR clear failed");
        end

        $display("------------------------------------------");
        $display("Predict taken:      %0b", predict_taken);
        $display("Predict PC:         %08h", predict_pc);
        $display("Predict PHT index:  %0h", predict_pht_index);
        $display("Predict GHR:        %0h", predict_ghr);
        $display("Predict BTB hit:    %0b", predict_btb_hit);
        $display("Predict BTB target: %08h", predict_btb_target);
        $display("Training updates:   %0d", train_count);

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I branch predictor foundation test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I branch predictor foundation test: PASS");
        $finish;
    end

    initial begin
        repeat (2000) @(posedge clk);

        $fatal(
            1,
            "RV32I branch predictor foundation test timeout"
        );
    end

endmodule
