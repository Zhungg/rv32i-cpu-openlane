`timescale 1ns/1ps

module tb_rv32i_decoder;

    import rv32i_pkg::*;
    import rv32i_encoding_pkg::*;
    import rv32i_csr_pkg::*;
    import rv32i_types_pkg::*;

    insn_t         instruction;
    reg_idx_t      rs1_index;
    reg_idx_t      rs2_index;
    reg_idx_t      rd_index;
    csr_addr_t     csr_address;
    decoder_ctrl_t control;

    int unsigned error_count;
    int unsigned legal_count;

    rv32i_decoder dut (
        .instruction_i (instruction),
        .rs1_index_o   (rs1_index),
        .rs2_index_o   (rs2_index),
        .rd_index_o    (rd_index),
        .csr_address_o (csr_address),
        .control_o     (control)
    );

    function automatic insn_t make_r(
        input logic [6:0] f7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] f3,
        input logic [4:0] rd,
        input opcode_t    op
    );
        return {f7, rs2, rs1, f3, rd, op};
    endfunction

    function automatic insn_t make_i(
        input logic [11:0] imm,
        input logic [4:0]  rs1,
        input logic [2:0]  f3,
        input logic [4:0]  rd,
        input opcode_t     op
    );
        return {imm, rs1, f3, rd, op};
    endfunction

    function automatic insn_t make_s(
        input logic [11:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  f3,
        input opcode_t     op
    );
        return {imm[11:5], rs2, rs1, f3, imm[4:0], op};
    endfunction

    function automatic insn_t make_b(
        input logic [12:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  f3,
        input opcode_t     op
    );
        return {
            imm[12],
            imm[10:5],
            rs2,
            rs1,
            f3,
            imm[4:1],
            imm[11],
            op
        };
    endfunction

    function automatic insn_t make_u(
        input logic [19:0] imm,
        input logic [4:0]  rd,
        input opcode_t     op
    );
        return {imm, rd, op};
    endfunction

    function automatic insn_t make_j(
        input logic [20:0] imm,
        input logic [4:0]  rd,
        input opcode_t     op
    );
        return {
            imm[20],
            imm[10:1],
            imm[11],
            imm[19:12],
            rd,
            op
        };
    endfunction

    task automatic check_legal(
        input string name,
        input insn_t test_instruction
    );
        begin
            instruction = test_instruction;
            #1;

            if (control.illegal !== 1'b0) begin
                error_count++;
                $display(
                    "FAIL legal: %-10s instruction=%08h",
                    name,
                    test_instruction
                );
            end
            else begin
                legal_count++;
                $display(
                    "PASS legal: %-10s instruction=%08h",
                    name,
                    test_instruction
                );
            end
        end
    endtask

    task automatic check_illegal(
        input string name,
        input insn_t test_instruction
    );
        begin
            instruction = test_instruction;
            #1;

            if (control.illegal !== 1'b1) begin
                error_count++;
                $display(
                    "FAIL illegal: %-18s instruction=%08h",
                    name,
                    test_instruction
                );
            end
            else if (
                control.gpr_write_enable ||
                control.memory_valid ||
                control.csr_valid
            ) begin
                error_count++;
                $display(
                    "FAIL side effect: %-14s instruction=%08h",
                    name,
                    test_instruction
                );
            end
            else begin
                $display(
                    "PASS illegal: %-18s instruction=%08h",
                    name,
                    test_instruction
                );
            end
        end
    endtask

    task automatic expect_true(
        input logic condition,
        input string message
    );
        begin
            if (condition !== 1'b1) begin
                error_count++;
                $display("FAIL control: %s", message);
            end
            else begin
                $display("PASS control: %s", message);
            end
        end
    endtask

    initial begin
        instruction = RV32I_NOP;
        error_count = 0;
        legal_count = 0;

        // U/J instructions.
        check_legal("LUI",   make_u(20'h12345, 5'd1, OPCODE_LUI));
        check_legal("AUIPC", make_u(20'h12345, 5'd1, OPCODE_AUIPC));
        check_legal("JAL",   make_j(21'd8, 5'd1, OPCODE_JAL));
        check_legal("JALR",  make_i(12'd4, 5'd2, 3'b000, 5'd1, OPCODE_JALR));

        // Conditional branches.
        check_legal("BEQ",  make_b(13'd8, 5'd2, 5'd1, FUNCT3_BEQ,  OPCODE_BRANCH));
        check_legal("BNE",  make_b(13'd8, 5'd2, 5'd1, FUNCT3_BNE,  OPCODE_BRANCH));
        check_legal("BLT",  make_b(13'd8, 5'd2, 5'd1, FUNCT3_BLT,  OPCODE_BRANCH));
        check_legal("BGE",  make_b(13'd8, 5'd2, 5'd1, FUNCT3_BGE,  OPCODE_BRANCH));
        check_legal("BLTU", make_b(13'd8, 5'd2, 5'd1, FUNCT3_BLTU, OPCODE_BRANCH));
        check_legal("BGEU", make_b(13'd8, 5'd2, 5'd1, FUNCT3_BGEU, OPCODE_BRANCH));

        // Loads.
        check_legal("LB",  make_i(12'd0, 5'd1, FUNCT3_LB,  5'd2, OPCODE_LOAD));
        check_legal("LH",  make_i(12'd0, 5'd1, FUNCT3_LH,  5'd2, OPCODE_LOAD));
        check_legal("LW",  make_i(12'd0, 5'd1, FUNCT3_LW,  5'd2, OPCODE_LOAD));
        check_legal("LBU", make_i(12'd0, 5'd1, FUNCT3_LBU, 5'd2, OPCODE_LOAD));
        check_legal("LHU", make_i(12'd0, 5'd1, FUNCT3_LHU, 5'd2, OPCODE_LOAD));

        // Stores.
        check_legal("SB", make_s(12'd0, 5'd2, 5'd1, FUNCT3_SB, OPCODE_STORE));
        check_legal("SH", make_s(12'd0, 5'd2, 5'd1, FUNCT3_SH, OPCODE_STORE));
        check_legal("SW", make_s(12'd0, 5'd2, 5'd1, FUNCT3_SW, OPCODE_STORE));

        // OP-IMM.
        check_legal("ADDI",  make_i(12'd1, 5'd1, FUNCT3_ADD_SUB, 5'd2, OPCODE_OP_IMM));
        check_legal("SLTI",  make_i(12'd1, 5'd1, FUNCT3_SLT,     5'd2, OPCODE_OP_IMM));
        check_legal("SLTIU", make_i(12'd1, 5'd1, FUNCT3_SLTU,    5'd2, OPCODE_OP_IMM));
        check_legal("XORI",  make_i(12'd1, 5'd1, FUNCT3_XOR,     5'd2, OPCODE_OP_IMM));
        check_legal("ORI",   make_i(12'd1, 5'd1, FUNCT3_OR,      5'd2, OPCODE_OP_IMM));
        check_legal("ANDI",  make_i(12'd1, 5'd1, FUNCT3_AND,     5'd2, OPCODE_OP_IMM));
        check_legal("SLLI",  make_i(12'h003, 5'd1, FUNCT3_SLL, 5'd2, OPCODE_OP_IMM));
        check_legal("SRLI",  make_i(12'h003, 5'd1, FUNCT3_SRL_SRA, 5'd2, OPCODE_OP_IMM));
        check_legal("SRAI",  make_i(12'h403, 5'd1, FUNCT3_SRL_SRA, 5'd2, OPCODE_OP_IMM));

        // OP.
        check_legal("ADD",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_ADD_SUB, 5'd3, OPCODE_OP));
        check_legal("SUB",  make_r(FUNCT7_SUB_SRA, 5'd2, 5'd1, FUNCT3_ADD_SUB, 5'd3, OPCODE_OP));
        check_legal("SLL",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_SLL,     5'd3, OPCODE_OP));
        check_legal("SLT",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_SLT,     5'd3, OPCODE_OP));
        check_legal("SLTU", make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_SLTU,    5'd3, OPCODE_OP));
        check_legal("XOR",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_XOR,     5'd3, OPCODE_OP));
        check_legal("SRL",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_SRL_SRA, 5'd3, OPCODE_OP));
        check_legal("SRA",  make_r(FUNCT7_SUB_SRA, 5'd2, 5'd1, FUNCT3_SRL_SRA, 5'd3, OPCODE_OP));
        check_legal("OR",   make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_OR,      5'd3, OPCODE_OP));
        check_legal("AND",  make_r(FUNCT7_BASE,    5'd2, 5'd1, FUNCT3_AND,     5'd3, OPCODE_OP));

        // Memory ordering and environment.
        check_legal("FENCE",   32'h0000_000f);
        check_legal("ECALL",   32'h0000_0073);
        check_legal("EBREAK",  32'h0010_0073);

        // Zicsr.
        check_legal("CSRRW",  make_i(12'h300, 5'd1, FUNCT3_CSRRW,  5'd2, OPCODE_SYSTEM));
        check_legal("CSRRS",  make_i(12'h300, 5'd1, FUNCT3_CSRRS,  5'd2, OPCODE_SYSTEM));
        check_legal("CSRRC",  make_i(12'h300, 5'd1, FUNCT3_CSRRC,  5'd2, OPCODE_SYSTEM));
        check_legal("CSRRWI", make_i(12'h300, 5'd3, FUNCT3_CSRRWI, 5'd2, OPCODE_SYSTEM));
        check_legal("CSRRSI", make_i(12'h300, 5'd3, FUNCT3_CSRRSI, 5'd2, OPCODE_SYSTEM));
        check_legal("CSRRCI", make_i(12'h300, 5'd3, FUNCT3_CSRRCI, 5'd2, OPCODE_SYSTEM));

        check_legal("FENCE.I", 32'h0000_100f);
        check_legal("MRET",    32'h3020_0073);
        check_legal("WFI",     32'h1050_0073);

        // Illegal encodings.
        check_illegal("unknown opcode", 32'hffff_ffff);
        check_illegal(
            "invalid branch funct3",
            make_b(13'd8, 5'd2, 5'd1, 3'b010, OPCODE_BRANCH)
        );
        check_illegal(
            "invalid SLLI funct7",
            make_i(12'h203, 5'd1, FUNCT3_SLL, 5'd2, OPCODE_OP_IMM)
        );
        check_illegal(
            "invalid OP funct7",
            make_r(7'b0000001, 5'd2, 5'd1, FUNCT3_ADD_SUB, 5'd3, OPCODE_OP)
        );
        check_illegal("invalid SYSTEM", 32'h0020_0073);

        // Representative control checks.
        instruction = make_i(
            12'd0,
            5'd1,
            FUNCT3_LW,
            5'd2,
            OPCODE_LOAD
        );
        #1;
        expect_true(control.memory_valid, "LW memory valid");
        expect_true(!control.memory_write, "LW is read");
        expect_true(control.memory_size == MEM_SIZE_WORD, "LW word size");
        expect_true(control.wb_sel == WB_MEMORY, "LW memory writeback");

        instruction = make_r(
            FUNCT7_SUB_SRA,
            5'd2,
            5'd1,
            FUNCT3_SRL_SRA,
            5'd3,
            OPCODE_OP
        );
        #1;
        expect_true(control.alu_op == ALU_SRA, "SRA ALU decode");

        instruction = make_i(
            12'h300,
            5'd3,
            FUNCT3_CSRRWI,
            5'd2,
            OPCODE_SYSTEM
        );
        #1;
        expect_true(control.csr_valid, "CSRRWI CSR valid");
        expect_true(control.csr_use_immediate, "CSRRWI zimm source");
        expect_true(control.csr_op == CSR_OP_WRITE, "CSRRWI write operation");
        expect_true(control.serializing, "CSR serialization");

        instruction = 32'h3020_0073;
        #1;
        expect_true(control.system_op == SYS_MRET, "MRET system decode");
        expect_true(control.serializing, "MRET serialization");

        $display("------------------------------------------");
        $display("Legal instruction encodings tested: %0d", legal_count);

        if (legal_count != 49) begin
            error_count++;
            $display(
                "FAIL: Expected 49 legal encodings, tested %0d",
                legal_count
            );
        end

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I decoder test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I decoder test: PASS");
        $finish;
    end

endmodule
