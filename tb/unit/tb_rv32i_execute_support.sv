`timescale 1ns/1ps

module tb_rv32i_execute_support;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    xlen_t       compare_a;
    xlen_t       compare_b;
    branch_op_e  branch_op;
    logic        branch_taken;

    addr_t       pc;
    xlen_t       rs1_value;
    xlen_t       rs2_value;
    xlen_t       immediate;
    addr_t       target;
    logic        target_misaligned;

    operand_a_sel_e operand_a_sel;
    operand_b_sel_e operand_b_sel;
    xlen_t          operand_a;
    xlen_t          operand_b;

    int unsigned error_count;

    rv32i_branch_compare u_branch_compare (
        .operand_a_i    (compare_a),
        .operand_b_i    (compare_b),
        .branch_op_i    (branch_op),
        .branch_taken_o (branch_taken)
    );

    rv32i_target_generator u_target_generator (
        .pc_i                (pc),
        .rs1_value_i         (rs1_value),
        .immediate_i         (immediate),
        .branch_op_i         (branch_op),
        .target_o            (target),
        .target_misaligned_o (target_misaligned)
    );

    rv32i_operand_mux u_operand_mux (
        .rs1_value_i     (rs1_value),
        .rs2_value_i     (rs2_value),
        .pc_i            (pc),
        .immediate_i     (immediate),
        .operand_a_sel_i (operand_a_sel),
        .operand_b_sel_i (operand_b_sel),
        .operand_a_o     (operand_a),
        .operand_b_o     (operand_b)
    );

    task automatic check_branch(
        input xlen_t      test_a,
        input xlen_t      test_b,
        input branch_op_e test_op,
        input logic       expected,
        input string      test_name
    );
        begin
            compare_a = test_a;
            compare_b = test_b;
            branch_op = test_op;

            #1;

            if (branch_taken !== expected) begin
                error_count++;

                $display(
                    "FAIL branch: %-22s A=%08h B=%08h expected=%0b actual=%0b",
                    test_name,
                    test_a,
                    test_b,
                    expected,
                    branch_taken
                );
            end
            else begin
                $display(
                    "PASS branch: %-22s taken=%0b",
                    test_name,
                    branch_taken
                );
            end
        end
    endtask

    task automatic check_target(
        input addr_t      test_pc,
        input xlen_t      test_rs1,
        input xlen_t      test_immediate,
        input branch_op_e test_op,
        input addr_t      expected_target,
        input logic       expected_misaligned,
        input string      test_name
    );
        begin
            pc        = test_pc;
            rs1_value = test_rs1;
            immediate = test_immediate;
            branch_op = test_op;

            #1;

            if (
                (target !== expected_target) ||
                (target_misaligned !== expected_misaligned)
            ) begin
                error_count++;

                $display(
                    "FAIL target: %-22s target=%08h/%08h misaligned=%0b/%0b",
                    test_name,
                    target,
                    expected_target,
                    target_misaligned,
                    expected_misaligned
                );
            end
            else begin
                $display(
                    "PASS target: %-22s target=%08h misaligned=%0b",
                    test_name,
                    target,
                    target_misaligned
                );
            end
        end
    endtask

    task automatic check_operands(
        input xlen_t          test_rs1,
        input xlen_t          test_rs2,
        input addr_t          test_pc,
        input xlen_t          test_immediate,
        input operand_a_sel_e test_a_sel,
        input operand_b_sel_e test_b_sel,
        input xlen_t          expected_a,
        input xlen_t          expected_b,
        input string          test_name
    );
        begin
            rs1_value    = test_rs1;
            rs2_value    = test_rs2;
            pc           = test_pc;
            immediate    = test_immediate;
            operand_a_sel = test_a_sel;
            operand_b_sel = test_b_sel;

            #1;

            if (
                (operand_a !== expected_a) ||
                (operand_b !== expected_b)
            ) begin
                error_count++;

                $display(
                    "FAIL operand: %-20s A=%08h/%08h B=%08h/%08h",
                    test_name,
                    operand_a,
                    expected_a,
                    operand_b,
                    expected_b
                );
            end
            else begin
                $display(
                    "PASS operand: %-20s A=%08h B=%08h",
                    test_name,
                    operand_a,
                    operand_b
                );
            end
        end
    endtask

    initial begin
        compare_a       = '0;
        compare_b       = '0;
        branch_op       = BR_NONE;

        pc              = '0;
        rs1_value       = '0;
        rs2_value       = '0;
        immediate       = '0;

        operand_a_sel   = OP_A_ZERO;
        operand_b_sel   = OP_B_ZERO;

        error_count     = 0;

        // -------------------------------------------------------------
        // Branch comparison
        // -------------------------------------------------------------

        check_branch(32'd10, 32'd10, BR_EQ,  1'b1, "BEQ true");
        check_branch(32'd10, 32'd11, BR_EQ,  1'b0, "BEQ false");
        check_branch(32'd10, 32'd11, BR_NE,  1'b1, "BNE true");

        check_branch(
            32'hffff_ffff,
            32'd1,
            BR_LT,
            1'b1,
            "BLT signed negative"
        );

        check_branch(
            32'd1,
            32'hffff_ffff,
            BR_GE,
            1'b1,
            "BGE signed positive"
        );

        check_branch(
            32'hffff_ffff,
            32'd1,
            BR_LTU,
            1'b0,
            "BLTU unsigned false"
        );

        check_branch(
            32'hffff_ffff,
            32'd1,
            BR_GEU,
            1'b1,
            "BGEU unsigned true"
        );

        check_branch(32'd0, 32'd0, BR_JAL,  1'b1, "JAL unconditional");
        check_branch(32'd0, 32'd0, BR_JALR, 1'b1, "JALR unconditional");
        check_branch(32'd0, 32'd0, BR_NONE,  1'b0, "No branch");

        // -------------------------------------------------------------
        // Target generation
        // -------------------------------------------------------------

        check_target(
            32'h0000_1000,
            32'h0000_0000,
            32'h0000_0010,
            BR_EQ,
            32'h0000_1010,
            1'b0,
            "Branch positive"
        );

        check_target(
            32'h0000_1000,
            32'h0000_0000,
            32'hffff_fff8,
            BR_NE,
            32'h0000_0ff8,
            1'b0,
            "Branch negative"
        );

        check_target(
            32'h0000_2000,
            32'h0000_0000,
            32'h0000_0080,
            BR_JAL,
            32'h0000_2080,
            1'b0,
            "JAL target"
        );

        check_target(
            32'h0000_0000,
            32'h0000_1000,
            32'h0000_0004,
            BR_JALR,
            32'h0000_1004,
            1'b0,
            "JALR aligned"
        );

        check_target(
            32'h0000_0000,
            32'h0000_1003,
            32'h0000_0004,
            BR_JALR,
            32'h0000_1006,
            1'b1,
            "JALR clear bit zero"
        );

        check_target(
            32'h0000_3000,
            32'hdead_beef,
            32'h1234_5678,
            BR_NONE,
            32'h0000_3004,
            1'b0,
            "Sequential PC"
        );

        // -------------------------------------------------------------
        // Operand selection
        // -------------------------------------------------------------

        check_operands(
            32'h1111_1111,
            32'h2222_2222,
            32'h0000_1000,
            32'hffff_fff0,
            OP_A_RS1,
            OP_B_RS2,
            32'h1111_1111,
            32'h2222_2222,
            "Register operands"
        );

        check_operands(
            32'h1111_1111,
            32'h2222_2222,
            32'h0000_1000,
            32'hffff_fff0,
            OP_A_PC,
            OP_B_IMM,
            32'h0000_1000,
            32'hffff_fff0,
            "PC and immediate"
        );

        check_operands(
            32'h1111_1111,
            32'h2222_2222,
            32'h0000_1000,
            32'hffff_fff0,
            OP_A_ZERO,
            OP_B_CONST_4,
            32'h0000_0000,
            32'h0000_0004,
            "Zero and constant four"
        );

        check_operands(
            32'h1111_1111,
            32'h2222_2222,
            32'h0000_1000,
            32'hffff_fff0,
            OP_A_RS1,
            OP_B_ZERO,
            32'h1111_1111,
            32'h0000_0000,
            "RS1 and zero"
        );

        $display("------------------------------------------");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I execute support test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I execute support test: PASS");
        $finish;
    end

endmodule
