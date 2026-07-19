`timescale 1ns/1ps

module tb_rv32i_imm_gen;

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;

    insn_t    instruction;
    imm_sel_e imm_sel;
    xlen_t    immediate;

    int unsigned error_count;

    rv32i_imm_gen dut (
        .instruction_i (instruction),
        .imm_sel_i     (imm_sel),
        .immediate_o   (immediate)
    );

    function automatic insn_t make_i_imm(input logic [11:0] imm);
        make_i_imm         = '0;
        make_i_imm[31:20]  = imm;
    endfunction

    function automatic insn_t make_s_imm(input logic [11:0] imm);
        make_s_imm         = '0;
        make_s_imm[31:25]  = imm[11:5];
        make_s_imm[11:7]   = imm[4:0];
    endfunction

    function automatic insn_t make_b_imm(input logic [12:0] imm);
        make_b_imm         = '0;
        make_b_imm[31]     = imm[12];
        make_b_imm[7]      = imm[11];
        make_b_imm[30:25]  = imm[10:5];
        make_b_imm[11:8]   = imm[4:1];
    endfunction

    function automatic insn_t make_u_imm(input logic [19:0] imm);
        make_u_imm         = '0;
        make_u_imm[31:12]  = imm;
    endfunction

    function automatic insn_t make_j_imm(input logic [20:0] imm);
        make_j_imm         = '0;
        make_j_imm[31]     = imm[20];
        make_j_imm[19:12]  = imm[19:12];
        make_j_imm[20]     = imm[11];
        make_j_imm[30:21]  = imm[10:1];
    endfunction

    function automatic insn_t make_z_imm(input logic [4:0] imm);
        make_z_imm         = '0;
        make_z_imm[19:15]  = imm;
    endfunction

    task automatic check_immediate(
        input insn_t    test_instruction,
        input imm_sel_e test_selection,
        input xlen_t    expected,
        input string    test_name
    );
        begin
            instruction = test_instruction;
            imm_sel     = test_selection;

            #1;

            if (immediate !== expected) begin
                error_count++;

                $display(
                    "FAIL: %-20s instruction=%08h expected=%08h actual=%08h",
                    test_name,
                    test_instruction,
                    expected,
                    immediate
                );
            end
            else begin
                $display(
                    "PASS: %-20s immediate=%08h",
                    test_name,
                    immediate
                );
            end
        end
    endtask

    initial begin
        instruction = '0;
        imm_sel     = IMM_NONE;
        error_count = 0;

        check_immediate(
            make_i_imm(12'h7ff),
            IMM_I,
            32'h0000_07ff,
            "I positive"
        );

        check_immediate(
            make_i_imm(12'hfff),
            IMM_I,
            32'hffff_ffff,
            "I negative"
        );

        check_immediate(
            make_s_imm(12'hff0),
            IMM_S,
            32'hffff_fff0,
            "S negative"
        );

        check_immediate(
            make_b_imm(13'd16),
            IMM_B,
            32'h0000_0010,
            "B positive"
        );

        check_immediate(
            make_b_imm(13'h1ffc),
            IMM_B,
            32'hffff_fffc,
            "B negative"
        );

        check_immediate(
            make_u_imm(20'h12345),
            IMM_U,
            32'h1234_5000,
            "U immediate"
        );

        check_immediate(
            make_j_imm(21'd2048),
            IMM_J,
            32'h0000_0800,
            "J positive"
        );

        check_immediate(
            make_j_imm(21'h1ffffe),
            IMM_J,
            32'hffff_fffe,
            "J negative"
        );

        check_immediate(
            make_z_imm(5'd31),
            IMM_Z,
            32'h0000_001f,
            "CSR Z immediate"
        );

        check_immediate(
            32'hffff_ffff,
            IMM_NONE,
            32'h0000_0000,
            "No immediate"
        );

        $display("------------------------------------------");

        if (error_count != 0) begin
            $fatal(
                1,
                "RV32I immediate generator test: FAIL (%0d errors)",
                error_count
            );
        end

        $display("RV32I immediate generator test: PASS");
        $finish;
    end

endmodule
