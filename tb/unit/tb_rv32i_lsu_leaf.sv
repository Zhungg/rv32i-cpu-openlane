`timescale 1ns/1ps

module tb_rv32i_lsu_leaf;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    addr_t     address;
    xlen_t     store_data;
    xlen_t     read_data;
    mem_size_e mem_size;
    logic      unsigned_load;

    logic      misaligned;

    xlen_t     aligned_write_data;
    logic [3:0] write_strobe;

    xlen_t     load_data;

    int unsigned error_count;

    rv32i_misaligned_detect u_misaligned_detect (
        .address_i    (address),
        .size_i       (mem_size),
        .misaligned_o (misaligned)
    );

    rv32i_store_aligner u_store_aligner (
        .address_i             (address),
        .store_data_i          (store_data),
        .size_i                (mem_size),
        .aligned_write_data_o  (aligned_write_data),
        .write_strobe_o        (write_strobe)
    );

    rv32i_load_aligner u_load_aligner (
        .address_i       (address),
        .read_data_i     (read_data),
        .size_i          (mem_size),
        .unsigned_load_i (unsigned_load),
        .load_data_o     (load_data)
    );

    task automatic fail(input string message);
        begin
            error_count++;
            $display("FAIL: %s", message);
        end
    endtask

    task automatic check_misaligned(
        input addr_t     test_address,
        input mem_size_e test_size,
        input logic      expected,
        input string     name
    );
        begin
            address  = test_address;
            mem_size = test_size;

            #1;

            if (misaligned !== expected) begin
                $display(
                    "      address=%08h size=%0d expected=%0b actual=%0b",
                    test_address,
                    test_size,
                    expected,
                    misaligned
                );
                fail(name);
            end
            else begin
                $display("PASS misalign: %-24s", name);
            end
        end
    endtask

    task automatic check_store(
        input addr_t     test_address,
        input xlen_t     test_store_data,
        input mem_size_e test_size,
        input xlen_t     expected_write_data,
        input logic [3:0] expected_strobe,
        input string     name
    );
        begin
            address    = test_address;
            store_data = test_store_data;
            mem_size   = test_size;

            #1;

            if (
                (aligned_write_data !== expected_write_data) ||
                (write_strobe !== expected_strobe)
            ) begin
                $display(
                    "      address=%08h data=%08h size=%0d",
                    test_address,
                    test_store_data,
                    test_size
                );
                $display(
                    "      write_data expected=%08h actual=%08h",
                    expected_write_data,
                    aligned_write_data
                );
                $display(
                    "      strobe     expected=%04b actual=%04b",
                    expected_strobe,
                    write_strobe
                );
                fail(name);
            end
            else begin
                $display(
                    "PASS store:    %-24s wdata=%08h wstrb=%04b",
                    name,
                    aligned_write_data,
                    write_strobe
                );
            end
        end
    endtask

    task automatic check_load(
        input addr_t     test_address,
        input xlen_t     test_read_data,
        input mem_size_e test_size,
        input logic      test_unsigned,
        input xlen_t     expected_load_data,
        input string     name
    );
        begin
            address       = test_address;
            read_data     = test_read_data;
            mem_size      = test_size;
            unsigned_load = test_unsigned;

            #1;

            if (load_data !== expected_load_data) begin
                $display(
                    "      address=%08h read_data=%08h size=%0d unsigned=%0b",
                    test_address,
                    test_read_data,
                    test_size,
                    test_unsigned
                );
                $display(
                    "      expected=%08h actual=%08h",
                    expected_load_data,
                    load_data
                );
                fail(name);
            end
            else begin
                $display(
                    "PASS load:     %-24s result=%08h",
                    name,
                    load_data
                );
            end
        end
    endtask

    initial begin
        address       = '0;
        store_data    = '0;
        read_data     = '0;
        mem_size      = MEM_SIZE_BYTE;
        unsigned_load = 1'b0;
        error_count   = 0;

        // --------------------------------------------------------------
        // Misalignment detection
        // --------------------------------------------------------------

        check_misaligned(32'h0000_1000, MEM_SIZE_BYTE, 1'b0, "byte addr 0");
        check_misaligned(32'h0000_1001, MEM_SIZE_BYTE, 1'b0, "byte addr 1");
        check_misaligned(32'h0000_1001, MEM_SIZE_HALF, 1'b1, "half odd");
        check_misaligned(32'h0000_1002, MEM_SIZE_HALF, 1'b0, "half even");
        check_misaligned(32'h0000_1000, MEM_SIZE_WORD, 1'b0, "word aligned");
        check_misaligned(32'h0000_1002, MEM_SIZE_WORD, 1'b1, "word half-aligned");
        check_misaligned(32'h0000_1003, MEM_SIZE_WORD, 1'b1, "word byte-aligned");

        // --------------------------------------------------------------
        // Store alignment
        // --------------------------------------------------------------

        check_store(
            32'h0000_0000,
            32'haabb_ccdd,
            MEM_SIZE_BYTE,
            32'h0000_00dd,
            4'b0001,
            "SB lane 0"
        );

        check_store(
            32'h0000_0001,
            32'haabb_ccdd,
            MEM_SIZE_BYTE,
            32'h0000_dd00,
            4'b0010,
            "SB lane 1"
        );

        check_store(
            32'h0000_0002,
            32'haabb_ccdd,
            MEM_SIZE_BYTE,
            32'h00dd_0000,
            4'b0100,
            "SB lane 2"
        );

        check_store(
            32'h0000_0003,
            32'haabb_ccdd,
            MEM_SIZE_BYTE,
            32'hdd00_0000,
            4'b1000,
            "SB lane 3"
        );

        check_store(
            32'h0000_0000,
            32'haabb_ccdd,
            MEM_SIZE_HALF,
            32'h0000_ccdd,
            4'b0011,
            "SH lower half"
        );

        check_store(
            32'h0000_0002,
            32'haabb_ccdd,
            MEM_SIZE_HALF,
            32'hccdd_0000,
            4'b1100,
            "SH upper half"
        );

        check_store(
            32'h0000_0000,
            32'haabb_ccdd,
            MEM_SIZE_WORD,
            32'haabb_ccdd,
            4'b1111,
            "SW full word"
        );

        // --------------------------------------------------------------
        // Load alignment and extension
        // read_data = 0x44_33_22_80
        // byte lane0=0x80, lane1=0x22, lane2=0x33, lane3=0x44
        // --------------------------------------------------------------

        check_load(
            32'h0000_0000,
            32'h4433_2280,
            MEM_SIZE_BYTE,
            1'b0,
            32'hffff_ff80,
            "LB lane 0 signed"
        );

        check_load(
            32'h0000_0000,
            32'h4433_2280,
            MEM_SIZE_BYTE,
            1'b1,
            32'h0000_0080,
            "LBU lane 0 unsigned"
        );

        check_load(
            32'h0000_0001,
            32'h4433_2280,
            MEM_SIZE_BYTE,
            1'b0,
            32'h0000_0022,
            "LB lane 1 positive"
        );

        check_load(
            32'h0000_0003,
            32'h8433_2280,
            MEM_SIZE_BYTE,
            1'b0,
            32'hffff_ff84,
            "LB lane 3 signed"
        );

        check_load(
            32'h0000_0000,
            32'h8001_7fff,
            MEM_SIZE_HALF,
            1'b0,
            32'h0000_7fff,
            "LH lower positive"
        );

        check_load(
            32'h0000_0002,
            32'h8001_7fff,
            MEM_SIZE_HALF,
            1'b0,
            32'hffff_8001,
            "LH upper signed"
        );

        check_load(
            32'h0000_0002,
            32'h8001_7fff,
            MEM_SIZE_HALF,
            1'b1,
            32'h0000_8001,
            "LHU upper unsigned"
        );

        check_load(
            32'h0000_0000,
            32'hdead_beef,
            MEM_SIZE_WORD,
            1'b0,
            32'hdead_beef,
            "LW full word"
        );

        $display("------------------------------------------");
        $display("LSU leaf alignment tests complete");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I LSU leaf test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I LSU leaf test: PASS");
        $finish;
    end

endmodule
