`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File   : tb/unit/tb_rv32m_mdu.sv
// Module : tb_rv32m_mdu
//
// Exhaustive Unit Testbench for RV32M Multiply-Divide Unit (MDU).

module tb_rv32m_mdu;

    import rv32i_pkg::*;
    import rv32m_pkg::*;

    mdu_op_e mdu_op;
    xlen_t   op_a;
    xlen_t   op_b;
    xlen_t   result;

    int unsigned error_count = 0;
    int unsigned test_count  = 0;

    rv32m_mdu dut (
        .mdu_op_i   (mdu_op),
        .operand_a_i(op_a),
        .operand_b_i(op_b),
        .result_o   (result)
    );

    task automatic check_mdu(
        input mdu_op_e op,
        input xlen_t a,
        input xlen_t b,
        input xlen_t expected,
        input string name
    );
        test_count++;
        mdu_op = op;
        op_a   = a;
        op_b   = b;
        #1;

        if (result !== expected) begin
            $display("FAIL [%s]: op=%0d a=0x%08x b=0x%08x | Expected 0x%08x, Got 0x%08x",
                     name, op, a, b, expected, result);
            error_count++;
        end else begin
            $display("PASS [%s]: a=0x%08x b=0x%08x => 0x%08x", name, a, b, result);
        end
    endtask

    initial begin
        $display("==========================================================");
        $display("Starting RV32M Hardware Multiplier/Divider Unit Tests");
        $display("==========================================================");

        // 1. MUL (Low 32-bit signed/unsigned product)
        check_mdu(MDU_MUL, 32'd12, 32'd34, 32'd408, "MUL positive");
        check_mdu(MDU_MUL, -32'd15, 32'd20, -32'd300, "MUL negative x positive");
        check_mdu(MDU_MUL, -32'd50, -32'd4, 32'd200, "MUL negative x negative");
        check_mdu(MDU_MUL, 32'h12345678, 32'h00000000, 32'd0, "MUL zero");

        // 2. MULH (High 32-bit signed x signed)
        check_mdu(MDU_MULH, 32'h7FFFFFFF, 32'h7FFFFFFF, 32'h3FFFFFFF, "MULH max signed square");
        check_mdu(MDU_MULH, 32'h80000000, 32'h80000000, 32'h40000000, "MULH min signed square");
        check_mdu(MDU_MULH, -32'd1, 32'd1, -32'd1, "MULH -1 x 1");

        // 3. MULHU (High 32-bit unsigned x unsigned)
        check_mdu(MDU_MULHU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, "MULHU max unsigned square");
        check_mdu(MDU_MULHU, 32'd2, 32'd3, 32'd0, "MULHU small product");

        // 4. MULHSU (High 32-bit signed x unsigned)
        check_mdu(MDU_MULHSU, -32'd1, 32'hFFFFFFFF, -32'd1, "MULHSU -1 x max unsigned");

        // 5. DIV (Signed division)
        check_mdu(MDU_DIV, 32'd100, 32'd7, 32'd14, "DIV 100 / 7");
        check_mdu(MDU_DIV, -32'd100, 32'd7, -32'd14, "DIV -100 / 7");
        check_mdu(MDU_DIV, 32'd100, -32'd7, -32'd14, "DIV 100 / -7");
        check_mdu(MDU_DIV, -32'd100, -32'd7, 32'd14, "DIV -100 / -7");
        check_mdu(MDU_DIV, 32'd100, 32'd0, 32'hFFFFFFFF, "DIV by zero (RISC-V spec: -1)");
        check_mdu(MDU_DIV, 32'h80000000, 32'hFFFFFFFF, 32'h80000000, "DIV signed overflow (-2^31 / -1)");

        // 6. DIVU (Unsigned division)
        check_mdu(MDU_DIVU, 32'd100, 32'd7, 32'd14, "DIVU 100 / 7");
        check_mdu(MDU_DIVU, 32'hFFFFFFFF, 32'd2, 32'h7FFFFFFF, "DIVU max / 2");
        check_mdu(MDU_DIVU, 32'd50, 32'd0, 32'hFFFFFFFF, "DIVU by zero (RISC-V spec: 0xFFFFFFFF)");

        // 7. REM (Signed remainder)
        check_mdu(MDU_REM, 32'd100, 32'd7, 32'd2, "REM 100 % 7");
        check_mdu(MDU_REM, -32'd100, 32'd7, -32'd2, "REM -100 % 7");
        check_mdu(MDU_REM, 32'd100, -32'd7, 32'd2, "REM 100 % -7");
        check_mdu(MDU_REM, -32'd100, -32'd7, -32'd2, "REM -100 % -7");
        check_mdu(MDU_REM, 32'd100, 32'd0, 32'd100, "REM by zero (RISC-V spec: dividend)");
        check_mdu(MDU_REM, 32'h80000000, 32'hFFFFFFFF, 32'd0, "REM signed overflow (RISC-V spec: 0)");

        // 8. REMU (Unsigned remainder)
        check_mdu(MDU_REMU, 32'd100, 32'd7, 32'd2, "REMU 100 % 7");
        check_mdu(MDU_REMU, 32'hFFFFFFFF, 32'd10, 32'd5, "REMU max % 10");
        check_mdu(MDU_REMU, 32'd75, 32'd0, 32'd75, "REMU by zero (RISC-V spec: dividend)");

        $display("==========================================================");
        if (error_count == 0) begin
            $display("RV32M MDU Unit Tests: ALL %0d CHECKS PASSED!", test_count);
            $display("==========================================================");
            $finish(0);
        end else begin
            $display("RV32M MDU Unit Tests: FAILED with %0d errors out of %0d tests",
                     error_count, test_count);
            $display("==========================================================");
            $stop;
        end
    end

endmodule
