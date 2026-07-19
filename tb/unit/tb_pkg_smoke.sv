`timescale 1ns/1ps

module tb_pkg_smoke;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_csr_pkg::*;
    import rv32i_types_pkg::*;

    xlen_t            test_word;
    decoder_ctrl_t    test_control;
    if_id_payload_t   test_if_id;
    id_ex_payload_t   test_id_ex;
    ex_mem_payload_t  test_ex_mem;
    mem_wb_payload_t  test_mem_wb;

    initial begin
        test_word    = '0;
        test_control = '0;
        test_if_id   = '0;
        test_id_ex   = '0;
        test_ex_mem  = '0;
        test_mem_wb  = '0;

        if ($bits(xlen_t) != 32)
            $fatal(1, "XLEN type is not 32 bits");

        if ($bits(reg_idx_t) != 5)
            $fatal(1, "Register index type is not 5 bits");

        if (RV32I_NOP !== 32'h0000_0013)
            $fatal(1, "RV32I NOP encoding mismatch");

        if (OPCODE_OP !== 7'b0110011)
            $fatal(1, "OP opcode mismatch");

        if (OPCODE_SYSTEM !== 7'b1110011)
            $fatal(1, "SYSTEM opcode mismatch");

        if (CSR_MSTATUS !== 12'h300)
            $fatal(1, "mstatus CSR address mismatch");

        if (CSR_MEPC !== 12'h341)
            $fatal(1, "mepc CSR address mismatch");

        if (make_mcause(1'b1, IRQ_MACHINE_TIMER)
            !== 32'h8000_0007)
            $fatal(1, "mcause construction mismatch");

        test_control.alu_op = ALU_ADD;
        test_if_id.pc       = DEFAULT_RESET_VECTOR;
        test_if_id.instruction = RV32I_NOP;

        $display("==========================================");
        $display("RV32I package smoke test: PASS");
        $display("XLEN:                 %0d", $bits(xlen_t));
        $display("Register index width: %0d", $bits(reg_idx_t));
        $display("IF/ID payload width:  %0d", $bits(if_id_payload_t));
        $display("ID/EX payload width:  %0d", $bits(id_ex_payload_t));
        $display("EX/MEM payload width: %0d", $bits(ex_mem_payload_t));
        $display("MEM/WB payload width: %0d", $bits(mem_wb_payload_t));
        $display("==========================================");

        $finish;
    end

endmodule
