`timescale 1ns/1ps

module tb_rv32i_lsu_controller;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    logic           clk;
    logic           rst_n;

    logic           valid;
    logic           ready;

    logic           memory_write;
    addr_t          address;
    xlen_t          store_data;
    mem_size_e      size;
    logic           unsigned_load;

    logic           complete;
    xlen_t          load_data;
    exception_t     exception;

    logic           dmem_req_valid;
    logic           dmem_req_ready;
    dmem_request_t  dmem_req;

    logic           dmem_rsp_valid;
    logic           dmem_rsp_ready;
    dmem_response_t dmem_rsp;

    int unsigned    error_count;

    rv32i_lsu dut (
        .clk_i             (clk),
        .rst_ni            (rst_n),

        .valid_i           (valid),
        .ready_o           (ready),

        .memory_write_i    (memory_write),
        .address_i         (address),
        .store_data_i      (store_data),
        .size_i            (size),
        .unsigned_load_i   (unsigned_load),

        .complete_o        (complete),
        .load_data_o       (load_data),
        .exception_o       (exception),

        .dmem_req_valid_o  (dmem_req_valid),
        .dmem_req_ready_i  (dmem_req_ready),
        .dmem_req_o        (dmem_req),

        .dmem_rsp_valid_i  (dmem_rsp_valid),
        .dmem_rsp_ready_o  (dmem_rsp_ready),
        .dmem_rsp_i        (dmem_rsp)
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

    task automatic drive_request(
        input logic      op_write,
        input addr_t     op_address,
        input xlen_t     op_store_data,
        input mem_size_e op_size,
        input logic      op_unsigned_load
    );
        begin
            @(negedge clk);

            valid         = 1'b1;
            memory_write  = op_write;
            address       = op_address;
            store_data    = op_store_data;
            size          = op_size;
            unsigned_load = op_unsigned_load;

            #1;
        end
    endtask

    task automatic accept_request();
        begin
            while (!ready) begin
                @(negedge clk);
                #1;
            end

            @(posedge clk);
            #1;

            @(negedge clk);

            valid         = 1'b0;
            memory_write  = 1'b0;
            address       = '0;
            store_data    = '0;
            size          = MEM_SIZE_BYTE;
            unsigned_load = 1'b0;

            #1;
        end
    endtask

    task automatic drive_response(
        input xlen_t rsp_data,
        input logic  rsp_error
    );
        begin
            @(negedge clk);

            dmem_rsp_valid     = 1'b1;
            dmem_rsp.read_data = rsp_data;
            dmem_rsp.error     = rsp_error;

            #1;

            while (!dmem_rsp_ready) begin
                @(negedge clk);
                #1;
            end

            // Caller checks complete/load_data/exception here, while the
            // response handshake is still active.
        end
    endtask

    task automatic clear_response();
        begin
            @(posedge clk);
            #1;

            @(negedge clk);

            dmem_rsp_valid = 1'b0;
            dmem_rsp       = '0;

            #1;
        end
    endtask

    task automatic check_load_transaction(
        input addr_t     op_address,
        input mem_size_e op_size,
        input logic      op_unsigned,
        input xlen_t     memory_word,
        input xlen_t     expected_data,
        input string     name
    );
        begin
            dmem_req_ready = 1'b1;

            drive_request(
                1'b0,
                op_address,
                32'h0000_0000,
                op_size,
                op_unsigned
            );

            check(dmem_req_valid, {name, ": request valid"});
            check(!dmem_req.write, {name, ": request is load"});
            check(dmem_req.address == op_address, {name, ": request address"});
            check(dmem_req.write_strobe == 4'b0000, {name, ": load strobe zero"});

            accept_request();

            check(!complete, {name, ": no complete before response"});

            drive_response(memory_word, 1'b0);

            check(complete, {name, ": complete on response"});
            check(!exception.valid, {name, ": no exception"});
            check(load_data == expected_data, {name, ": aligned load data"});

            clear_response();
        end
    endtask

    task automatic check_store_transaction(
        input addr_t      op_address,
        input xlen_t      op_store_data,
        input mem_size_e  op_size,
        input xlen_t      expected_wdata,
        input logic [3:0] expected_wstrb,
        input string      name
    );
        begin
            dmem_req_ready = 1'b1;

            drive_request(
                1'b1,
                op_address,
                op_store_data,
                op_size,
                1'b0
            );

            check(dmem_req_valid, {name, ": request valid"});
            check(dmem_req.write, {name, ": request is store"});
            check(dmem_req.address == op_address, {name, ": request address"});
            check(dmem_req.write_data == expected_wdata, {name, ": aligned write data"});
            check(dmem_req.write_strobe == expected_wstrb, {name, ": write strobe"});

            accept_request();

            check(!complete, {name, ": store waits for response"});

            drive_response(32'h0000_0000, 1'b0);

            check(complete, {name, ": store complete on response"});
            check(!exception.valid, {name, ": no exception"});
            check(load_data == 32'h0000_0000, {name, ": store load_data zero"});

            clear_response();
        end
    endtask

    task automatic check_request_backpressure();
        begin
            dmem_req_ready = 1'b0;

            drive_request(
                1'b0,
                32'h0000_1000,
                32'h0000_0000,
                MEM_SIZE_WORD,
                1'b0
            );

            check(dmem_req_valid, "Backpressure keeps request valid");
            check(!ready, "Backpressure deasserts LSU ready");
            check(dmem_req.address == 32'h0000_1000, "Backpressure keeps request address");

            repeat (3) begin
                @(posedge clk);
                #1;

                check(dmem_req_valid, "Request remains valid while stalled");
                check(!ready, "LSU ready remains low while stalled");
                check(dmem_req.address == 32'h0000_1000, "Request payload stable while stalled");
            end

            @(negedge clk);

            dmem_req_ready = 1'b1;

            #1;

            check(ready, "LSU ready returns when DMEM accepts request");

            accept_request();

            drive_response(32'h1234_5678, 1'b0);

            check(complete, "Backpressured load completes after response");
            check(load_data == 32'h1234_5678, "Backpressured load data");

            clear_response();
        end
    endtask

    task automatic check_misaligned(
        input logic             op_write,
        input addr_t            op_address,
        input mem_size_e        op_size,
        input trap_cause_code_t expected_cause,
        input string            name
    );
        begin
            dmem_req_ready = 1'b1;

            drive_request(
                op_write,
                op_address,
                32'hdead_beef,
                op_size,
                1'b0
            );

            check(ready, {name, ": LSU ready for immediate exception"});
            check(complete, {name, ": completes immediately"});
            check(exception.valid, {name, ": exception valid"});
            check(exception.cause == expected_cause, {name, ": exception cause"});
            check(exception.tval == op_address, {name, ": mtval address"});
            check(!dmem_req_valid, {name, ": no DMEM request"});

            @(posedge clk);
            #1;

            @(negedge clk);

            valid         = 1'b0;
            memory_write  = 1'b0;
            address       = '0;
            store_data    = '0;
            size          = MEM_SIZE_BYTE;
            unsigned_load = 1'b0;

            #1;
        end
    endtask

    task automatic check_access_fault(
        input logic             op_write,
        input trap_cause_code_t expected_cause,
        input string            name
    );
        begin
            dmem_req_ready = 1'b1;

            drive_request(
                op_write,
                32'h0000_2000,
                32'h1234_5678,
                MEM_SIZE_WORD,
                1'b0
            );

            check(dmem_req_valid, {name, ": request valid"});
            check(dmem_req.address == 32'h0000_2000, {name, ": request address"});

            accept_request();

            drive_response(32'h0000_0000, 1'b1);

            check(complete, {name, ": complete on error response"});
            check(exception.valid, {name, ": exception valid"});
            check(exception.cause == expected_cause, {name, ": exception cause"});
            check(exception.tval == 32'h0000_2000, {name, ": mtval address"});

            clear_response();
        end
    endtask

    initial begin
        clk            = 1'b0;
        rst_n          = 1'b0;

        valid          = 1'b0;
        memory_write   = 1'b0;
        address        = '0;
        store_data     = '0;
        size           = MEM_SIZE_BYTE;
        unsigned_load  = 1'b0;

        dmem_req_ready = 1'b0;
        dmem_rsp_valid = 1'b0;
        dmem_rsp       = '0;

        error_count    = 0;

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        // --------------------------------------------------------------
        // Load transactions
        // --------------------------------------------------------------

        check_load_transaction(
            32'h0000_0000,
            MEM_SIZE_WORD,
            1'b0,
            32'hdead_beef,
            32'hdead_beef,
            "LW"
        );

        check_load_transaction(
            32'h0000_0000,
            MEM_SIZE_BYTE,
            1'b0,
            32'h4433_2280,
            32'hffff_ff80,
            "LB sign extend"
        );

        check_load_transaction(
            32'h0000_0000,
            MEM_SIZE_BYTE,
            1'b1,
            32'h4433_2280,
            32'h0000_0080,
            "LBU zero extend"
        );

        check_load_transaction(
            32'h0000_0002,
            MEM_SIZE_HALF,
            1'b0,
            32'h8001_7fff,
            32'hffff_8001,
            "LH upper sign extend"
        );

        check_load_transaction(
            32'h0000_0002,
            MEM_SIZE_HALF,
            1'b1,
            32'h8001_7fff,
            32'h0000_8001,
            "LHU upper zero extend"
        );

        // --------------------------------------------------------------
        // Store transactions
        // --------------------------------------------------------------

        check_store_transaction(
            32'h0000_0001,
            32'haabb_ccdd,
            MEM_SIZE_BYTE,
            32'h0000_dd00,
            4'b0010,
            "SB lane 1"
        );

        check_store_transaction(
            32'h0000_0002,
            32'haabb_ccdd,
            MEM_SIZE_HALF,
            32'hccdd_0000,
            4'b1100,
            "SH upper"
        );

        check_store_transaction(
            32'h0000_0000,
            32'haabb_ccdd,
            MEM_SIZE_WORD,
            32'haabb_ccdd,
            4'b1111,
            "SW"
        );

        // --------------------------------------------------------------
        // Backpressure and exceptions
        // --------------------------------------------------------------

        check_request_backpressure();

        check_misaligned(
            1'b0,
            32'h0000_1002,
            MEM_SIZE_WORD,
            EXC_LOAD_ADDR_MISALIGNED,
            "Misaligned LW"
        );

        check_misaligned(
            1'b1,
            32'h0000_1001,
            MEM_SIZE_HALF,
            EXC_STORE_ADDR_MISALIGNED,
            "Misaligned SH"
        );

        check_access_fault(
            1'b0,
            EXC_LOAD_ACCESS_FAULT,
            "Load access fault"
        );

        check_access_fault(
            1'b1,
            EXC_STORE_ACCESS_FAULT,
            "Store access fault"
        );

        $display("------------------------------------------");
        $display("LSU request/response tests complete");
        $display("Outstanding DMEM requests supported: 1");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I LSU controller test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I LSU controller test: PASS");
        $finish;
    end

    initial begin
        repeat (3000) @(posedge clk);

        $fatal(
            1,
            "RV32I LSU controller test timeout"
        );
    end

endmodule
