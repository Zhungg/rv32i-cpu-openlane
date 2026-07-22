`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// File: rtl/pkg/rv32i_types_pkg.sv
//
// Shared control types, interfaces and pipeline payload structures.

package rv32i_types_pkg;
    parameter int unsigned GHR_WIDTH       = 8;
    parameter int unsigned PHT_INDEX_WIDTH = 8;
    parameter int unsigned FETCH_EPOCH_W   = 4;

    // ---------------------------------------------------------------------
    // Datapath control enumerations
    // ---------------------------------------------------------------------

    typedef enum logic [4:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_SLL,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_SRL,
        ALU_SRA,
        ALU_OR,
        ALU_AND,
        ALU_COPY_A,
        ALU_COPY_B
    } alu_op_e;

    typedef enum logic [2:0] {
        IMM_NONE,
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J,
        IMM_Z
    } imm_sel_e;

    typedef enum logic [1:0] {
        OP_A_RS1,
        OP_A_PC,
        OP_A_ZERO
    } operand_a_sel_e;

    typedef enum logic [1:0] {
        OP_B_RS2,
        OP_B_IMM,
        OP_B_CONST_4,
        OP_B_ZERO
    } operand_b_sel_e;

    typedef enum logic [3:0] {
        BR_NONE,
        BR_EQ,
        BR_NE,
        BR_LT,
        BR_GE,
        BR_LTU,
        BR_GEU,
        BR_JAL,
        BR_JALR
    } branch_op_e;

    typedef enum logic [2:0] {
        WB_NONE,
        WB_ALU,
        WB_MEMORY,
        WB_PC_PLUS_4,
        WB_CSR,
        WB_IMMEDIATE
    } wb_sel_e;

    typedef enum logic [1:0] {
        MEM_SIZE_BYTE,
        MEM_SIZE_HALF,
        MEM_SIZE_WORD
    } mem_size_e;

    typedef enum logic [2:0] {
        CSR_OP_NONE,
        CSR_OP_WRITE,
        CSR_OP_SET,
        CSR_OP_CLEAR
    } csr_op_e;

    typedef enum logic [3:0] {
        SYS_NONE,
        SYS_ECALL,
        SYS_EBREAK,
        SYS_MRET,
        SYS_WFI,
        SYS_FENCE,
        SYS_FENCE_I
    } system_op_e;

    typedef enum logic [1:0] {
        PRED_KIND_NONE,
        PRED_KIND_BRANCH,
        PRED_KIND_JUMP,
        PRED_KIND_RETURN
    } prediction_kind_e;

    // ---------------------------------------------------------------------
    // Decoder control packet
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic           use_rs1;
        logic           use_rs2;
        logic           gpr_write_enable;

        alu_op_e        alu_op;
        imm_sel_e       imm_sel;
        operand_a_sel_e operand_a_sel;
        operand_b_sel_e operand_b_sel;
        branch_op_e     branch_op;
        wb_sel_e        wb_sel;

        logic           memory_valid;
        logic           memory_write;
        mem_size_e      memory_size;
        logic           memory_unsigned;

        logic           csr_valid;
        csr_op_e        csr_op;
        logic           csr_use_immediate;

        system_op_e     system_op;
        logic           serializing;
        logic           illegal;
    } decoder_ctrl_t;

    // ---------------------------------------------------------------------
    // Prediction metadata
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic                         valid;
        logic                         predicted_taken;
        logic [31:0]                        predicted_pc;
        logic [PHT_INDEX_WIDTH-1:0]   pht_index;
        logic [GHR_WIDTH-1:0]         ghr;
        logic                         btb_hit;
        logic [31:0]                        btb_target;
    } prediction_meta_t;

    // ---------------------------------------------------------------------
    // Exception/trap metadata
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic             valid;
        logic             is_interrupt;
        logic [4:0] cause;
        logic [31:0]            epc;
        logic [31:0]            tval;
    } exception_t;

    // ---------------------------------------------------------------------
    // Instruction memory interface payloads
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic [31:0]                      address;
        logic [FETCH_EPOCH_W-1:0]   epoch;
    } imem_request_t;

    typedef struct packed {
        logic [31:0]                      instruction;
        logic                       error;
        logic [FETCH_EPOCH_W-1:0]   epoch;
    } imem_response_t;

    // ---------------------------------------------------------------------
    // Data memory interface payloads
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic [31:0]       address;
        logic        write;
        logic [3:0]  write_strobe;
        logic [31:0]       write_data;
        mem_size_e   size;
        logic        unsigned_load;
    } dmem_request_t;

    typedef struct packed {
        logic [31:0] read_data;
        logic  error;
    } dmem_response_t;

    // ---------------------------------------------------------------------
    // Pipeline payload structures
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic [31:0]            pc;
        logic [31:0]            instruction;
        prediction_meta_t prediction;
        logic             fetch_error;
    } if_id_payload_t;

    typedef struct packed {
        logic [31:0]            pc;
        logic [31:0]            instruction;

        logic [4:0]         rs1_index;
        logic [4:0]         rs2_index;
        logic [4:0]         rd_index;

        logic [31:0]            rs1_value;
        logic [31:0]            rs2_value;
        logic [31:0]            immediate;

        logic [11:0]        csr_address;
        decoder_ctrl_t    control;
        prediction_meta_t prediction;
        exception_t       exception;
    } id_ex_payload_t;

    typedef struct packed {
        logic [31:0]            pc;
        logic [31:0]            instruction;
        logic [4:0]         rd_index;

        logic [31:0]            alu_result;
        logic [31:0]            store_data;
        logic [31:0]            pc_plus_4;

        logic             branch_taken;
        logic [31:0]            branch_target;
        logic [31:0]            actual_next_pc;
        logic             branch_mispredict;

        logic [11:0]        csr_address;
        logic [31:0]            csr_write_operand;

        decoder_ctrl_t    control;
        prediction_meta_t prediction;
        exception_t       exception;
    } ex_mem_payload_t;

    typedef struct packed {
        logic [31:0]         pc;
        logic [31:0]         instruction;
        logic [4:0]      rd_index;

        // STEP 11AU: Register final writeback data in the MEM/WB payload.
        logic [31:0]         writeback_data;

        logic [31:0]         alu_result;
        logic [31:0]         memory_result;
        logic [31:0]         pc_plus_4;
        logic [31:0]         actual_next_pc;
        logic [31:0]         csr_read_data;

        logic [11:0] csr_address;
        logic [31:0]       csr_write_operand;
        decoder_ctrl_t control;
        exception_t    exception;
    } mem_wb_payload_t;

endpackage
