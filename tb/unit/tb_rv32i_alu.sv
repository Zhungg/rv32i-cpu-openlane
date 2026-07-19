`timescale 1ns/1ps

module tb_rv32i_alu;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    xlen_t  operand_a;
    xlen_t  operand_b;
    alu_op_e alu_op;
    xlen_t  result;

    int unsigned error_count;

    rv32i_alu dut (
        .operand_a_i (operand_a),
        .operand_b_i (operand_b),
        .alu_op_i    (alu_op),
        .result_o    (result)
    );

    task automatic check_alu(
        input xlen_t   test_a,
        input xlen_t   test_b,
        input alu_op_e test_op,
        input xlen_t   expected,
        input string   test_name
    );
        begin
            operand_a = test_a;
            operand_b = test_b;
            alu_op    = test_op;

            #1;

            if (result !== expected) begin
                error_count++;

                $display(
                    "FAIL: %-24s A=%08h B=%08h expected=%08h actual=%08h",
                    test_name,
                    test_a,
                    test_b,
                    expected,
                    result
                );
            end
            else begin
                $display(
                    "PASS: %-24s result=%08h",
                    test_name,
                    result
                );
            end
        end
    endtask

    initial begin
        operand_a   = '0;
        operand_b   = '0;
        alu_op      = ALU_ADD;
        error_count = 0;

        check_alu(32'd10,        32'd20,        ALU_ADD,    32'd30,        "ADD");
        check_alu(32'hffff_ffff, 32'd1,         ALU_ADD,    32'h0000_0000, "ADD wraparound");
        check_alu(32'd10,        32'd3,         ALU_SUB,    32'd7,         "SUB");
        check_alu(32'd0,         32'd1,         ALU_SUB,    32'hffff_ffff, "SUB wraparound");

        check_alu(32'h0000_0001, 32'd31,        ALU_SLL,    32'h8000_0000, "SLL");
        check_alu(32'h8000_0000, 32'd1,         ALU_SRL,    32'h4000_0000, "SRL");
        check_alu(32'h8000_0000, 32'd1,         ALU_SRA,    32'hc000_0000, "SRA signed");

        check_alu(32'hffff_ffff, 32'd1,         ALU_SLT,    32'd1,         "SLT signed");
        check_alu(32'hffff_ffff, 32'd1,         ALU_SLTU,   32'd0,         "SLTU unsigned");
        check_alu(32'd1,         32'hffff_ffff, ALU_SLTU,   32'd1,         "SLTU true");

        check_alu(32'h55aa_00ff, 32'h0f0f_f0f0, ALU_XOR,    32'h5aa5_f00f, "XOR");
        check_alu(32'h55aa_00ff, 32'h0f0f_f0f0, ALU_OR,     32'h5faf_f0ff, "OR");
        check_alu(32'h55aa_00ff, 32'h0f0f_f0f0, ALU_AND,    32'h050a_00f0, "AND");

        check_alu(32'h1234_5678, 32'hdead_beef, ALU_COPY_A, 32'h1234_5678, "COPY A");
        check_alu(32'h1234_5678, 32'hdead_beef, ALU_COPY_B, 32'hdead_beef, "COPY B");

        $display("------------------------------------------");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I ALU test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I ALU test: PASS");
        $finish;
    end

endmodule
