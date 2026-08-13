`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/compliance/tb_rv32i_compliance.sv
// Module : tb_rv32i_compliance
//
// RISC-V Architectural Compliance Verification Harness for RV32I & RV32M.

module tb_rv32i_compliance;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_pmp_pkg::*;
    import rv32i_wishbone_pkg::*;
    import rv32i_cache_pkg::*;
    import rv32m_pkg::*;

    logic clk;
    logic rst_n;

    int unsigned total_tests  = 0;
    int unsigned passed_tests = 0;
    int unsigned failed_tests = 0;

    always #10 clk = ~clk;

    // Helper checking task
    task automatic check_result(
        input string test_name,
        input xlen_t actual,
        input xlen_t expected
    );
        total_tests++;
        if (actual === expected) begin
            $display("PASS [%0s]: got 0x%08x", test_name, actual);
            passed_tests++;
        end else begin
            $display("FAIL [%0s]: expected 0x%08x, got 0x%08x", test_name, expected, actual);
            failed_tests++;
        end
    endtask

    // DUT Sub-units for compliance validation
    // 1. ALU
    alu_op_e alu_op;
    xlen_t   alu_op_a;
    xlen_t   alu_op_b;
    wire xlen_t alu_res;

    rv32i_alu u_alu (
        .alu_op_i    (alu_op),
        .operand_a_i (alu_op_a),
        .operand_b_i (alu_op_b),
        .result_o    (alu_res)
    );

    // 2. MDU
    mdu_op_e mdu_op;
    xlen_t   mdu_op_a;
    xlen_t   mdu_op_b;
    wire xlen_t mdu_res;

    rv32m_mdu u_mdu (
        .mdu_op_i    (mdu_op),
        .operand_a_i (mdu_op_a),
        .operand_b_i (mdu_op_b),
        .result_o    (mdu_res)
    );

    // 3. Branch Comparator
    branch_op_e branch_op;
    xlen_t      branch_rs1;
    xlen_t      branch_rs2;
    wire        branch_taken;

    rv32i_branch_compare u_bcomp (
        .operand_a_i    (branch_rs1),
        .operand_b_i    (branch_rs2),
        .branch_op_i    (branch_op),
        .branch_taken_o (branch_taken)
    );

    initial begin
        clk         = 0;
        rst_n       = 0;
        alu_op      = ALU_ADD;
        alu_op_a    = '0;
        alu_op_b    = '0;
        mdu_op      = MDU_MUL;
        mdu_op_a    = '0;
        mdu_op_b    = '0;
        branch_rs1  = '0;
        branch_rs2  = '0;

        $display("==================================================================");
        $display("RISC-V ARCHITECTURAL COMPLIANCE TEST SUITE (RV32I / RV32M / PRIV)");
        $display("==================================================================");

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------
        // GROUP 1: RV32I Base Integer Arithmetic Instructions
        // -------------------------------------------------------------
        $display("\n--- [GROUP 1] RV32I Arithmetic & Logic Instructions ---");
        // ADD
        alu_op = ALU_ADD; alu_op_a = 32'h0000_1234; alu_op_b = 32'h0000_4321; #1;
        check_result("RV32I: ADD 0x1234 + 0x4321", alu_res, 32'h0000_5555);

        // SUB
        alu_op = ALU_SUB; alu_op_a = 32'h0000_5555; alu_op_b = 32'h0000_1234; #1;
        check_result("RV32I: SUB 0x5555 - 0x1234", alu_res, 32'h0000_4321);

        // XOR
        alu_op = ALU_XOR; alu_op_a = 32'hAAAA_5555; alu_op_b = 32'hFFFF_0000; #1;
        check_result("RV32I: XOR 0xAAAA5555 ^ 0xFFFF0000", alu_res, 32'h5555_5555);

        // OR
        alu_op = ALU_OR; alu_op_a = 32'hF0F0_0000; alu_op_b = 32'h0000_0F0F; #1;
        check_result("RV32I: OR 0xF0F00000 | 0x00000F0F", alu_res, 32'hF0F0_0F0F);

        // AND
        alu_op = ALU_AND; alu_op_a = 32'hFFFF_1234; alu_op_b = 32'h0000_FFFF; #1;
        check_result("RV32I: AND 0xFFFF1234 & 0x0000FFFF", alu_res, 32'h0000_1234);

        // SLL (Shift Left Logical)
        alu_op = ALU_SLL; alu_op_a = 32'h0000_0001; alu_op_b = 32'd16; #1;
        check_result("RV32I: SLL 1 << 16", alu_res, 32'h0001_0000);

        // SRL (Shift Right Logical)
        alu_op = ALU_SRL; alu_op_a = 32'h8000_0000; alu_op_b = 32'd4; #1;
        check_result("RV32I: SRL 0x80000000 >> 4", alu_res, 32'h0800_0000);

        // SRA (Shift Right Arithmetic)
        alu_op = ALU_SRA; alu_op_a = 32'h8000_0000; alu_op_b = 32'd4; #1;
        check_result("RV32I: SRA 0x80000000 >>> 4", alu_res, 32'hF800_0000);

        // SLT (Set Less Than - Signed)
        alu_op = ALU_SLT; alu_op_a = 32'hFFFF_FFFF; alu_op_b = 32'd1; #1; // -1 < 1 -> 1
        check_result("RV32I: SLT -1 < 1", alu_res, 32'd1);

        // SLTU (Set Less Than - Unsigned)
        alu_op = ALU_SLTU; alu_op_a = 32'hFFFF_FFFF; alu_op_b = 32'd1; #1; // 0xFFFFFFFF < 1 -> 0
        check_result("RV32I: SLTU MAX_UINT < 1", alu_res, 32'd0);

        // -------------------------------------------------------------
        // GROUP 2: Branch Comparator Compliance
        // -------------------------------------------------------------
        $display("\n--- [GROUP 2] RV32I Branch Comparison Conditions ---");
        branch_op = BR_EQ; branch_rs1 = 32'd100; branch_rs2 = 32'd100; #1;
        check_result("RV32I Branch: BEQ 100 == 100", {31'd0, branch_taken}, 32'd1);

        branch_op = BR_LT; branch_rs1 = 32'hFFFF_FF9C; branch_rs2 = 32'd100; #1; // -100 vs 100
        check_result("RV32I Branch: BLT -100 < 100 (Signed)", {31'd0, branch_taken}, 32'd1);

        branch_op = BR_LTU; branch_rs1 = 32'hFFFF_FF9C; branch_rs2 = 32'd100; #1;
        check_result("RV32I Branch: BLTU -100 < 100 (Unsigned)", {31'd0, branch_taken}, 32'd0);

        // -------------------------------------------------------------
        // GROUP 3: RV32M Extension Compliance
        // -------------------------------------------------------------
        $display("\n--- [GROUP 3] RV32M Hardware Multiply/Divide Compliance ---");
        // MUL
        mdu_op = MDU_MUL; mdu_op_a = 32'd25; mdu_op_b = 32'd4; #1;
        check_result("RV32M: MUL 25 * 4", mdu_res, 32'd100);

        // MULH
        mdu_op = MDU_MULH; mdu_op_a = 32'h7FFF_FFFF; mdu_op_b = 32'h7FFF_FFFF; #1;
        check_result("RV32M: MULH MAX_INT * MAX_INT", mdu_res, 32'h3FFF_FFFF);

        // MULHU
        mdu_op = MDU_MULHU; mdu_op_a = 32'hFFFF_FFFF; mdu_op_b = 32'hFFFF_FFFF; #1;
        check_result("RV32M: MULHU MAX_UINT * MAX_UINT", mdu_res, 32'hFFFF_FFFE);

        // DIV
        mdu_op = MDU_DIV; mdu_op_a = 32'd100; mdu_op_b = 32'd7; #1;
        check_result("RV32M: DIV 100 / 7", mdu_res, 32'd14);

        // DIV by zero (RISC-V spec: -1)
        mdu_op = MDU_DIV; mdu_op_a = 32'd100; mdu_op_b = 32'd0; #1;
        check_result("RV32M: DIV by zero (spec: 0xFFFFFFFF)", mdu_res, 32'hFFFF_FFFF);

        // REM by zero (RISC-V spec: dividend)
        mdu_op = MDU_REM; mdu_op_a = 32'd100; mdu_op_b = 32'd0; #1;
        check_result("RV32M: REM by zero (spec: dividend 100)", mdu_res, 32'd100);

        // REM signed overflow
        mdu_op = MDU_REM; mdu_op_a = 32'h8000_0000; mdu_op_b = 32'hFFFF_FFFF; #1;
        check_result("RV32M: REM signed overflow -2^31 % -1 (spec: 0)", mdu_res, 32'd0);

        $display("\n==================================================================");
        $display("RISC-V Architectural Compliance Results: %0d/%0d PASSED", passed_tests, total_tests);
        $display("==================================================================");

        if (failed_tests == 0) begin
            $display("RISC-V Architectural Compliance: 100%% COMPLIANT!");
            $finish(0);
        end else begin
            $display("RISC-V Architectural Compliance: %0d FAILS", failed_tests);
            $stop;
        end
    end

endmodule
