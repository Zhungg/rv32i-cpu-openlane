`timescale 1ns/1ps

module tb_rv32i_fetch_unit;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    logic           clk;
    logic           rst_n;

    logic           redirect_valid;
    addr_t          redirect_pc;

    logic           imem_req_valid;
    logic           imem_req_ready;
    imem_request_t  imem_req;

    logic           imem_rsp_valid;
    logic           imem_rsp_ready;
    imem_response_t imem_rsp;

    logic           fetch_valid;
    logic           fetch_ready;
    if_id_payload_t fetch_payload;

    imem_request_t  request_0;
    imem_request_t  request_1;
    imem_request_t  request_2;

    int unsigned error_count;

    rv32i_fetch_unit #(
        .RESET_VECTOR (32'h0000_0000)
    ) dut (
        .clk_i            (clk),
        .rst_ni           (rst_n),

        .redirect_valid_i (redirect_valid),
        .redirect_pc_i    (redirect_pc),

        .predictor_update_valid_i     (1'b0),
        .predictor_update_pc_i        ('0),
        .predictor_update_taken_i     (1'b0),
        .predictor_update_target_i    ('0),
        .predictor_update_pht_index_i ('0),

        .imem_req_valid_o (imem_req_valid),
        .imem_req_ready_i (imem_req_ready),
        .imem_req_o       (imem_req),

        .imem_rsp_valid_i (imem_rsp_valid),
        .imem_rsp_ready_o (imem_rsp_ready),
        .imem_rsp_i       (imem_rsp),

        .fetch_valid_o    (fetch_valid),
        .fetch_ready_i    (fetch_ready),
        .fetch_payload_o  (fetch_payload)
    );

    always #5 clk = ~clk;

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    task automatic check(
        input logic condition,
        input string message
    );
        begin
            if (condition !== 1'b1) begin
                fail(message);
            end
            else begin
                $display("PASS: %s", message);
            end
        end
    endtask

    task automatic accept_request(
        output imem_request_t captured_request
    );
        begin
            while (!imem_req_valid) begin
                @(negedge clk);
            end

            captured_request = imem_req;
            imem_req_ready   = 1'b1;

            @(posedge clk);
            #1;

            imem_req_ready = 1'b0;
        end
    endtask

    task automatic send_response(
        input imem_request_t source_request,
        input insn_t         instruction,
        input logic          error
    );
        begin
            @(negedge clk);

            imem_rsp_valid       = 1'b1;
            imem_rsp.instruction = instruction;
            imem_rsp.error       = error;
            imem_rsp.epoch       = source_request.epoch;

            while (!imem_rsp_ready) begin
                @(negedge clk);
            end

            @(posedge clk);
            #1;

            @(negedge clk);
            imem_rsp_valid = 1'b0;
            imem_rsp       = '0;
        end
    endtask

    initial begin
        clk            = 1'b0;
        rst_n          = 1'b0;

        redirect_valid = 1'b0;
        redirect_pc    = '0;

        imem_req_ready = 1'b0;

        imem_rsp_valid = 1'b0;
        imem_rsp       = '0;

        fetch_ready    = 1'b0;

        request_0      = '0;
        request_1      = '0;
        request_2      = '0;

        error_count    = 0;

        // --------------------------------------------------------------
        // Reset
        // --------------------------------------------------------------

        repeat (2) @(posedge clk);
        #1;

        check(
            !fetch_valid,
            "Reset leaves fetch buffer empty"
        );

        @(negedge clk);
        rst_n = 1'b1;

        #1;

        check(
            imem_req_valid,
            "Frontend requests reset vector"
        );

        check(
            imem_req.address == 32'h0000_0000,
            "First request address is reset vector"
        );

        // --------------------------------------------------------------
        // Request must remain stable while memory is not ready.
        // --------------------------------------------------------------

        request_0 = imem_req;

        repeat (2) begin
            @(posedge clk);
            #1;

            check(
                imem_req_valid,
                "Request valid remains asserted during backpressure"
            );

            check(
                imem_req == request_0,
                "Request payload remains stable during backpressure"
            );
        end

        // Accept the first request.
        accept_request(request_0);

        check(
            !imem_req_valid,
            "No second request while first is outstanding"
        );

        // Return a delayed instruction response.
        send_response(
            request_0,
            32'h0010_0093,
            1'b0
        );

        check(
            fetch_valid,
            "Current response enters fetch buffer"
        );

        check(
            fetch_payload.pc == 32'h0000_0000,
            "Fetched instruction retains request PC"
        );

        check(
            fetch_payload.instruction == 32'h0010_0093,
            "Fetched instruction data is preserved"
        );

        check(
            !fetch_payload.fetch_error,
            "Successful response has no fetch error"
        );

        check(
            fetch_payload.prediction.valid &&
            !fetch_payload.prediction.predicted_taken &&
            (fetch_payload.prediction.predicted_pc == 32'h0000_0004),
            "Baseline prediction metadata is sequential"
        );

        // --------------------------------------------------------------
        // Downstream stall must preserve buffered instruction.
        // --------------------------------------------------------------

        repeat (2) begin
            @(posedge clk);
            #1;

            check(
                fetch_valid &&
                (fetch_payload.instruction == 32'h0010_0093),
                "Fetch buffer holds payload during downstream stall"
            );
        end

        // Consume the first instruction and issue PC=4.
        @(negedge clk);
        fetch_ready = 1'b1;

        accept_request(request_1);

        check(
            request_1.address == 32'h0000_0004,
            "Second request uses sequential PC"
        );

        check(
            request_1.epoch == request_0.epoch,
            "Sequential request keeps current epoch"
        );

        check(
            !fetch_valid,
            "Consumed fetch entry leaves buffer empty"
        );

        // --------------------------------------------------------------
        // Redirect while request_1 remains outstanding.
        // --------------------------------------------------------------

        @(negedge clk);

        redirect_valid = 1'b1;
        redirect_pc    = 32'h0000_0100;

        @(posedge clk);
        #1;

        @(negedge clk);
        redirect_valid = 1'b0;

        check(
            !fetch_valid,
            "Redirect flushes buffered wrong-path instruction"
        );

        // Return the old request. It must be consumed and discarded.
        send_response(
            request_1,
            32'h0020_0113,
            1'b0
        );

        check(
            !fetch_valid,
            "Stale response is discarded after redirect"
        );

        // Frontend may now issue the redirected request.
        accept_request(request_2);

        check(
            request_2.address == 32'h0000_0100,
            "Redirected request uses redirect PC"
        );

        check(
            request_2.epoch != request_1.epoch,
            "Redirect increments fetch epoch"
        );

        // --------------------------------------------------------------
        // Fetch access error propagation.
        // --------------------------------------------------------------

        @(negedge clk);
        fetch_ready = 1'b0;

        send_response(
            request_2,
            32'h0000_0013,
            1'b1
        );

        check(
            fetch_valid,
            "Error response still creates a pipeline entry"
        );

        check(
            fetch_payload.pc == 32'h0000_0100,
            "Error response retains faulting PC"
        );

        check(
            fetch_payload.fetch_error,
            "Instruction access error is propagated"
        );

        check(
            fetch_payload.prediction.predicted_pc == 32'h0000_0104,
            "Redirect-path metadata has correct sequential next PC"
        );

        $display("------------------------------------------");
        $display(
            "Fetch epoch width:          %0d bits",
            FETCH_EPOCH_W
        );
        $display(
            "Outstanding IMEM requests:  1"
        );
        $display(
            "Fetch buffer depth:         1"
        );
        $display(
            "Fetch payload width:        %0d bits",
            $bits(if_id_payload_t)
        );

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I fetch unit test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I fetch unit test: PASS");
        $finish;
    end

endmodule
