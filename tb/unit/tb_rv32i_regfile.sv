`timescale 1ns/1ps

module tb_rv32i_regfile;

    import rv32i_pkg::*;

    logic     clk;

    reg_idx_t rs1_index;
    reg_idx_t rs2_index;
    xlen_t    rs1_data;
    xlen_t    rs2_data;

    logic     write_enable;
    reg_idx_t write_index;
    xlen_t    write_data;

    int unsigned error_count;

    rv32i_regfile dut (
        .clk_i          (clk),

        .rs1_index_i    (rs1_index),
        .rs2_index_i    (rs2_index),
        .rs1_data_o     (rs1_data),
        .rs2_data_o     (rs2_data),

        .write_enable_i (write_enable),
        .write_index_i  (write_index),
        .write_data_i   (write_data)
    );

    always #5 clk = ~clk;

    task automatic write_register(
        input reg_idx_t index,
        input xlen_t    value
    );
        begin
            @(negedge clk);

            write_enable = 1'b1;
            write_index  = index;
            write_data   = value;

            @(posedge clk);
            #1;

            write_enable = 1'b0;
            write_index  = REG_X0;
            write_data   = '0;
        end
    endtask

    task automatic check_read(
        input reg_idx_t test_rs1,
        input reg_idx_t test_rs2,
        input xlen_t    expected_rs1,
        input xlen_t    expected_rs2,
        input string    test_name
    );
        begin
            rs1_index = test_rs1;
            rs2_index = test_rs2;

            #1;

            if (
                (rs1_data !== expected_rs1) ||
                (rs2_data !== expected_rs2)
            ) begin
                error_count++;

                $display(
                    "FAIL: %-22s rs1=%08h/%08h rs2=%08h/%08h",
                    test_name,
                    rs1_data,
                    expected_rs1,
                    rs2_data,
                    expected_rs2
                );
            end
            else begin
                $display(
                    "PASS: %-22s rs1=%08h rs2=%08h",
                    test_name,
                    rs1_data,
                    rs2_data
                );
            end
        end
    endtask

    initial begin
        clk          = 1'b0;
        rs1_index    = REG_X0;
        rs2_index    = REG_X0;
        write_enable = 1'b0;
        write_index  = REG_X0;
        write_data   = '0;
        error_count  = 0;

        #1;

        check_read(
            REG_X0,
            REG_X0,
            32'h0000_0000,
            32'h0000_0000,
            "x0 hardwired zero"
        );

        write_register(5'd5, 32'hdead_beef);

        check_read(
            5'd5,
            REG_X0,
            32'hdead_beef,
            32'h0000_0000,
            "write and read x5"
        );

        write_register(5'd10, 32'h1234_5678);

        check_read(
            5'd5,
            5'd10,
            32'hdead_beef,
            32'h1234_5678,
            "dual asynchronous read"
        );

        write_register(REG_X0, 32'hffff_ffff);

        check_read(
            REG_X0,
            REG_X0,
            32'h0000_0000,
            32'h0000_0000,
            "write x0 ignored"
        );

        // Check same-cycle WB-to-ID bypass before the active clock edge.
        @(negedge clk);

        rs1_index    = 5'd7;
        rs2_index    = 5'd7;
        write_enable = 1'b1;
        write_index  = 5'd7;
        write_data   = 32'hcafe_babe;

        #1;

        if (
            (rs1_data !== 32'hcafe_babe) ||
            (rs2_data !== 32'hcafe_babe)
        ) begin
            error_count++;
            $display("FAIL: same-cycle write-through bypass");
        end
        else begin
            $display("PASS: same-cycle write-through bypass");
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        write_index  = REG_X0;
        write_data   = '0;

        check_read(
            5'd7,
            5'd7,
            32'hcafe_babe,
            32'hcafe_babe,
            "stored bypassed value"
        );

        $display("------------------------------------------");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I register file test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I register file test: PASS");
        $finish;
    end

endmodule
