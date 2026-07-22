`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Baseline five-stage RV32I datapath.
//
// Current implementation scope:
// - LUI/AUIPC
// - JAL/JALR
// - Conditional branches
// - OP-IMM
// - OP
//
// Deferred to Step 6:
// - Load/store execution
// - CSR execution
// - FENCE/FENCE.I
// - Trap and interrupt redirect
// - Forwarding and hazard handling
//
// Unsupported Step-6 instructions are held in IF/ID. They are not allowed
// to retire with an incorrect result.

module rv32i_datapath #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000,
    parameter logic [31:0] TRAP_VECTOR  = 32'h0000_0100
) (
    input  logic                              clk_i,
    input  logic                              rst_ni,

    // Instruction-memory interface.
    output logic                              imem_req_valid_o,
    input  logic                              imem_req_ready_i,
    output rv32i_types_pkg::imem_request_t    imem_req_o,

    input  logic                              imem_rsp_valid_i,
    output logic                              imem_rsp_ready_o,
    input  rv32i_types_pkg::imem_response_t   imem_rsp_i,

    // Data-memory interface shell.
    //
    // Step 5H locks the top-level contract only. The LSU in Step 6 will
    // become the only block allowed to drive dmem_req_valid_o.
    output logic                              dmem_req_valid_o,
    input  logic                              dmem_req_ready_i,
    output rv32i_types_pkg::dmem_request_t    dmem_req_o,

    input  logic                              dmem_rsp_valid_i,
    output logic                              dmem_rsp_ready_o,
    input  rv32i_types_pkg::dmem_response_t   dmem_rsp_i,

    // Baseline retirement interface.
    output logic                              commit_valid_o,
    output logic                              commit_trap_o,
    output rv32i_pkg::addr_t                  commit_pc_o,
    output rv32i_pkg::addr_t                  commit_next_pc_o,
    output rv32i_pkg::insn_t                  commit_instruction_o,
    output logic                              commit_rd_write_o,
    output rv32i_pkg::reg_idx_t               commit_rd_index_o,
    output rv32i_pkg::xlen_t                  commit_rd_data_o,

    // Integration diagnostics.
    output logic                              baseline_stall_o,
    output logic                              debug_redirect_valid_o,
    output rv32i_pkg::addr_t                  debug_redirect_pc_o
);

    import rv32i_pkg::*;
    import rv32i_types_pkg::*;
    import rv32i_csr_pkg::*;

    // ==================================================================
    // Frontend → IF/ID
    // ==================================================================

    logic           fetch_valid;
    logic           fetch_ready;
    if_id_payload_t fetch_payload;

    logic           if_id_valid;
    logic           if_id_downstream_ready;
    if_id_payload_t if_id_payload;

    // ==================================================================
    // ID stage
    // ==================================================================

    reg_idx_t       decoded_rs1_index;
    reg_idx_t       decoded_rs2_index;
    reg_idx_t       decoded_rd_index;
    csr_addr_t      decoded_csr_address;
    decoder_ctrl_t  decoded_control;

    xlen_t          decoded_immediate;
    xlen_t          register_rs1_data;
    xlen_t          register_rs2_data;

    exception_t     id_exception;
    id_ex_payload_t id_ex_payload_d;

    logic           id_instruction_supported;
    logic           id_load_use_stall;
    logic           id_ex_input_ready;

    // ==================================================================
    // ID/EX → EX stage
    // ==================================================================

    logic           id_ex_valid;
    id_ex_payload_t id_ex_payload;

    xlen_t          ex_rs1_value_forwarded;
    xlen_t          ex_rs2_value_forwarded;
    logic           ex_rs1_forwarded;
    logic           ex_rs2_forwarded;

    xlen_t          alu_operand_a;
    xlen_t          alu_operand_b;
    xlen_t          alu_result_raw;
    xlen_t          alu_result_final;

    logic           branch_taken;
    addr_t          branch_target;
    logic           branch_target_misaligned;

    logic           branch_active;
    addr_t          actual_next_pc;
    logic           branch_mispredict;
    logic           branch_redirect;
    logic           ex_fire;

    logic           predictor_update_valid;
    addr_t          predictor_update_pc;
    logic           predictor_update_taken;
    addr_t          predictor_update_target;
    logic [PHT_INDEX_WIDTH-1:0]
                    predictor_update_pht_index;

    logic [31:0]    bpu_branch_count_q;
    logic [31:0]    bpu_mispredict_count_q;
    logic [31:0]    bpu_correct_count_q;
    logic [31:0]    bpu_predicted_taken_count_q;
    logic [31:0]    bpu_actual_taken_count_q;


    logic           trap_taken;
    logic           trap_redirect_valid;
    addr_t          trap_redirect_pc;

    logic           mret_commit;
    logic           mret_redirect_valid;
    addr_t          mret_redirect_pc;

    logic           commit_redirect_valid;

    addr_t          csr_mtvec;
    addr_t          csr_mepc;
    xlen_t          csr_mcause;
    xlen_t          csr_mtval;
    xlen_t          csr_mstatus;

    xlen_t          csr_read_data;
    logic           csr_read_illegal;
    logic           csr_write_illegal;
    xlen_t          ex_csr_write_operand;

    logic           csr_commit_write_valid;

    logic           frontend_redirect_valid;
    addr_t          frontend_redirect_pc;

    exception_t      ex_exception;
    ex_mem_payload_t ex_mem_payload_d;

    // ==================================================================
    // EX/MEM → MEM stage
    // ==================================================================

    logic            ex_mem_valid;
    logic            ex_mem_input_ready;
    ex_mem_payload_t ex_mem_payload;

    mem_wb_payload_t mem_wb_payload_d;

    // ==================================================================
    // MEM/WB → commit stage
    // ==================================================================

    logic            mem_wb_valid;
    logic            mem_wb_input_ready;
    mem_wb_payload_t mem_wb_payload;

    xlen_t           writeback_data;
    logic            register_write_enable;

    // ==================================================================
    // MEM-stage LSU integration
    // ==================================================================

    logic            mem_stage_is_memory;
    logic            mem_stage_lsu_valid;
    logic            mem_stage_complete;
    logic            mem_stage_ready;

    logic            lsu_ready;
    logic            lsu_complete;
    xlen_t           lsu_load_data;
    exception_t      lsu_exception;

    exception_t      mem_exception;

    // ==================================================================
    // Commit-time CSR/trap state and redirect
    //
    // Priority:
    //   1. Trap/exception at commit
    //   2. MRET at commit
    //   3. EX-stage branch/jump redirect
    //
    // Full CSR instruction read/write behavior is intentionally deferred.
    // ==================================================================

    assign mret_commit =
        mem_wb_valid &&
        !mem_wb_payload.exception.valid &&
        (mem_wb_payload.control.system_op == SYS_MRET);

    assign csr_commit_write_valid =
        mem_wb_valid &&
        mem_wb_payload.control.csr_valid &&
        !mem_wb_payload.exception.valid &&
        !commit_redirect_valid;

    rv32i_csr_file #(
        .MTVEC_RESET (TRAP_VECTOR)
    ) u_csr_file (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),

        .trap_valid_i          (
            mem_wb_valid &&
            mem_wb_payload.exception.valid
        ),
        .trap_exception_i      (mem_wb_payload.exception),

        .mret_valid_i          (mret_commit),

        .csr_read_valid_i      (
            ex_mem_valid &&
            ex_mem_payload.control.csr_valid
        ),
        .csr_read_address_i    (ex_mem_payload.csr_address),
        .csr_read_data_o       (csr_read_data),
        .csr_read_illegal_o    (csr_read_illegal),

        .csr_write_valid_i     (csr_commit_write_valid),
        .csr_write_address_i   (mem_wb_payload.csr_address),
        .csr_write_funct3_i    (mem_wb_payload.instruction[14:12]),
        .csr_write_data_i      (mem_wb_payload.csr_write_operand),
        .csr_write_illegal_o   (csr_write_illegal),

        .mtvec_o               (csr_mtvec),
        .mepc_o                (csr_mepc),
        .mcause_o              (csr_mcause),
        .mtval_o               (csr_mtval),
        .mstatus_o             (csr_mstatus),

        .mret_redirect_valid_o (mret_redirect_valid),
        .mret_redirect_pc_o    (mret_redirect_pc)
    );

    rv32i_trap_redirect u_trap_redirect (
        .commit_valid_i        (mem_wb_valid),
        .exception_i           (mem_wb_payload.exception),
        .trap_vector_i         (csr_mtvec),

        .trap_taken_o          (trap_taken),
        .trap_redirect_valid_o (trap_redirect_valid),
        .trap_redirect_pc_o    (trap_redirect_pc)
    );

    assign commit_redirect_valid =
        trap_redirect_valid ||
        mret_redirect_valid;

    // STEP 11AH: Redirect valid/data decoupling.
    //
    // Trap, MRET and EX branch targets are continuously available.
    // Keep redirect qualification separate from the 32-bit target cone.
    assign frontend_redirect_valid =
        commit_redirect_valid ||
        branch_redirect;

    always_comb begin
        if (trap_redirect_valid) begin
            frontend_redirect_pc = trap_redirect_pc;
        end
        else if (mret_redirect_valid) begin
            frontend_redirect_pc = mret_redirect_pc;
        end
        else begin
            frontend_redirect_pc = actual_next_pc;
        end
    end

    // ==================================================================
    // Frontend
    // ==================================================================

    rv32i_fetch_unit #(
        .RESET_VECTOR (RESET_VECTOR)
    ) u_fetch_unit (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),

        .redirect_valid_i (frontend_redirect_valid),
        .redirect_pc_i    (frontend_redirect_pc),

        .predictor_update_valid_i     (predictor_update_valid),
        .predictor_update_pc_i        (predictor_update_pc),
        .predictor_update_taken_i     (predictor_update_taken),
        .predictor_update_target_i    (predictor_update_target),
        .predictor_update_pht_index_i (predictor_update_pht_index),

        .imem_req_valid_o (imem_req_valid_o),
        .imem_req_ready_i (imem_req_ready_i),
        .imem_req_o       (imem_req_o),

        .imem_rsp_valid_i (imem_rsp_valid_i),
        .imem_rsp_ready_o (imem_rsp_ready_o),
        .imem_rsp_i       (imem_rsp_i),

        .fetch_valid_o    (fetch_valid),
        .fetch_ready_i    (fetch_ready),
        .fetch_payload_o  (fetch_payload)
    );

    // ==================================================================
    // IF/ID pipeline register
    // ==================================================================

    rv32i_if_id u_if_id (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),

        .flush_i   (frontend_redirect_valid),
        .kill_i    (1'b0),

        .valid_i   (fetch_valid),
        .ready_o   (fetch_ready),
        .payload_i (fetch_payload),

        .valid_o   (if_id_valid),
        .ready_i   (if_id_downstream_ready),
        .payload_o (if_id_payload)
    );

    // ==================================================================
    // Decode
    // ==================================================================

    rv32i_decoder u_decoder (
        .instruction_i (if_id_payload.instruction),

        .rs1_index_o   (decoded_rs1_index),
        .rs2_index_o   (decoded_rs2_index),
        .rd_index_o    (decoded_rd_index),
        .csr_address_o (decoded_csr_address),
        .control_o     (decoded_control)
    );

    rv32i_imm_gen u_imm_gen (
        .instruction_i (if_id_payload.instruction),
        .imm_sel_i     (decoded_control.imm_sel),
        .immediate_o   (decoded_immediate)
    );

    rv32i_hazard_unit u_hazard_unit (
        .id_valid_i          (if_id_valid),
        .id_rs1_index_i      (decoded_rs1_index),
        .id_rs2_index_i      (decoded_rs2_index),
        .id_use_rs1_i        (decoded_control.use_rs1),
        .id_use_rs2_i        (decoded_control.use_rs2),

        .ex_valid_i          (id_ex_valid),
        .ex_rd_index_i       (id_ex_payload.rd_index),
        .ex_gpr_write_i      (id_ex_payload.control.gpr_write_enable),
        .ex_memory_valid_i   (id_ex_payload.control.memory_valid),
        .ex_memory_write_i   (id_ex_payload.control.memory_write),

        .mem_valid_i         (ex_mem_valid),
        .mem_rd_index_i      (ex_mem_payload.rd_index),
        .mem_gpr_write_i     (ex_mem_payload.control.gpr_write_enable),
        .mem_memory_valid_i  (ex_mem_payload.control.memory_valid),
        .mem_memory_write_i  (ex_mem_payload.control.memory_write),

        .load_use_stall_o    (id_load_use_stall)
    );

    // ==================================================================
    // Writeback selection
    // ==================================================================

    // STEP 11AU: Register final writeback data in the MEM/WB payload.
    //
    // Source selection is performed before the MEM/WB register so that
    // wb_sel decoding is removed from the WB-forwarding-to-EX path.
    assign writeback_data =
        mem_wb_payload.writeback_data;

    assign register_write_enable =
        mem_wb_valid &&
        mem_wb_payload.control.gpr_write_enable &&
        !mem_wb_payload.exception.valid &&
        !commit_redirect_valid &&
        (mem_wb_payload.rd_index != REG_X0);

    // ==================================================================
    // Register file
    // ==================================================================

    rv32i_regfile u_regfile (
        .clk_i          (clk_i),

        .rs1_index_i    (decoded_rs1_index),
        .rs2_index_i    (decoded_rs2_index),

        .rs1_data_o     (register_rs1_data),
        .rs2_data_o     (register_rs2_data),

        .write_enable_i (register_write_enable),
        .write_index_i  (mem_wb_payload.rd_index),
        .write_data_i   (writeback_data)
    );

    // ==================================================================
    // ID-stage exception metadata
    // ==================================================================

    always_comb begin
        id_exception = '0;

        id_exception.epc  = if_id_payload.pc;
        id_exception.tval = '0;

        if (if_id_payload.fetch_error) begin
            id_exception.valid        = 1'b1;
            id_exception.is_interrupt = 1'b0;
            id_exception.cause        = EXC_INSN_ACCESS_FAULT;
            id_exception.tval         = if_id_payload.pc;
        end
        else if (decoded_control.illegal) begin
            id_exception.valid        = 1'b1;
            id_exception.is_interrupt = 1'b0;
            id_exception.cause        = EXC_ILLEGAL_INSTRUCTION;
            id_exception.tval         = if_id_payload.instruction;
        end
        else if (decoded_control.system_op == SYS_ECALL) begin
            id_exception.valid        = 1'b1;
            id_exception.is_interrupt = 1'b0;
            id_exception.cause        = EXC_ECALL_FROM_M;
            id_exception.tval         = '0;
        end
        else if (decoded_control.system_op == SYS_EBREAK) begin
            id_exception.valid        = 1'b1;
            id_exception.is_interrupt = 1'b0;
            id_exception.cause        = EXC_BREAKPOINT;
            id_exception.tval         = if_id_payload.pc;
        end
    end

    // ==================================================================
    // ID-stage payload assembly
    // ==================================================================

    always_comb begin
        id_ex_payload_d = '0;

        id_ex_payload_d.pc          = if_id_payload.pc;
        id_ex_payload_d.instruction = if_id_payload.instruction;

        id_ex_payload_d.rs1_index = decoded_rs1_index;
        id_ex_payload_d.rs2_index = decoded_rs2_index;
        id_ex_payload_d.rd_index  = decoded_rd_index;

        // Mask unused register operands to avoid propagating unknown
        // uninitialized GPR values into combinational datapath logic.
        if (decoded_control.use_rs1) begin
            id_ex_payload_d.rs1_value = register_rs1_data;
        end
        else begin
            id_ex_payload_d.rs1_value = '0;
        end

        if (decoded_control.use_rs2) begin
            id_ex_payload_d.rs2_value = register_rs2_data;
        end
        else begin
            id_ex_payload_d.rs2_value = '0;
        end

        id_ex_payload_d.immediate   = decoded_immediate;
        id_ex_payload_d.csr_address = decoded_csr_address;
        id_ex_payload_d.control     = decoded_control;
        id_ex_payload_d.prediction  = if_id_payload.prediction;
        id_ex_payload_d.exception   = id_exception;
    end

    // Memory, CSR and privileged instructions are intentionally held until
    // their Step-6 execution units are implemented.
    always_comb begin
        id_instruction_supported =
            (
                decoded_control.csr_valid ||
                (decoded_control.system_op == SYS_NONE)   ||
                (decoded_control.system_op == SYS_ECALL)  ||
                (decoded_control.system_op == SYS_EBREAK) ||
                (decoded_control.system_op == SYS_MRET)
            );
    end

    assign baseline_stall_o =
        if_id_valid &&
        !id_instruction_supported;

    assign if_id_downstream_ready =
        id_ex_input_ready &&
        id_instruction_supported &&
        !id_load_use_stall;

    // ==================================================================
    // ID/EX pipeline register
    // ==================================================================

    rv32i_id_ex u_id_ex (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),

        // A resolved branch kills the younger instruction that may be
        // entering ID/EX in the same cycle.
        .flush_i   (frontend_redirect_valid),
        .kill_i    (1'b0),

        .valid_i   (
            if_id_valid &&
            id_instruction_supported &&
            !id_load_use_stall
        ),
        .ready_o   (id_ex_input_ready),
        .payload_i (id_ex_payload_d),

        .valid_o   (id_ex_valid),
        .ready_i   (ex_mem_input_ready),
        .payload_o (id_ex_payload)
    );

    // ==================================================================
    // EX-stage operand forwarding
    //
    // Raw register values captured in ID/EX may be stale when back-to-back
    // dependent ALU instructions are in flight. Forwarding repairs the
    // operand values just before EX operand selection.
    // ==================================================================

    always @* begin
        if (id_ex_payload.instruction[14]) begin
            ex_csr_write_operand = {
                27'b0,
                id_ex_payload.instruction[19:15]
            };
        end
        else begin
            ex_csr_write_operand = ex_rs1_value_forwarded;
        end
    end

    rv32i_forwarding_unit u_forwarding_unit (
        .ex_valid_i              (id_ex_valid),

        .ex_use_rs1_i            (id_ex_payload.control.use_rs1),
        .ex_rs1_index_i          (id_ex_payload.rs1_index),
        .ex_rs1_value_i          (id_ex_payload.rs1_value),

        .ex_use_rs2_i            (id_ex_payload.control.use_rs2),
        .ex_rs2_index_i          (id_ex_payload.rs2_index),
        .ex_rs2_value_i          (id_ex_payload.rs2_value),

        .mem_valid_i             (ex_mem_valid),
        .mem_exception_valid_i   (ex_mem_payload.exception.valid),
        .mem_gpr_write_i         (ex_mem_payload.control.gpr_write_enable),
        .mem_rd_index_i          (ex_mem_payload.rd_index),
        .mem_wb_sel_i            (ex_mem_payload.control.wb_sel),
        .mem_alu_result_i        (ex_mem_payload.alu_result),
        .mem_pc_plus_4_i         (ex_mem_payload.pc_plus_4),

        .wb_valid_i              (mem_wb_valid),
        .wb_exception_valid_i    (mem_wb_payload.exception.valid),
        .wb_gpr_write_i          (mem_wb_payload.control.gpr_write_enable),
        .wb_rd_index_i           (mem_wb_payload.rd_index),
        .wb_writeback_data_i     (writeback_data),

        .rs1_value_o             (ex_rs1_value_forwarded),
        .rs2_value_o             (ex_rs2_value_forwarded),

        .rs1_forwarded_o         (ex_rs1_forwarded),
        .rs2_forwarded_o         (ex_rs2_forwarded)
    );

    // ==================================================================
    // EX-stage operand selection and ALU
    // ==================================================================

    rv32i_operand_mux u_operand_mux (
        .rs1_value_i     (ex_rs1_value_forwarded),
        .rs2_value_i     (ex_rs2_value_forwarded),
        .pc_i            (id_ex_payload.pc),
        .immediate_i     (id_ex_payload.immediate),

        .operand_a_sel_i (id_ex_payload.control.operand_a_sel),
        .operand_b_sel_i (id_ex_payload.control.operand_b_sel),

        .operand_a_o     (alu_operand_a),
        .operand_b_o     (alu_operand_b)
    );

    rv32i_alu u_alu (
        .operand_a_i (alu_operand_a),
        .operand_b_i (alu_operand_b),
        .alu_op_i    (id_ex_payload.control.alu_op),
        .result_o    (alu_result_raw)
    );

    // LUI currently uses the explicit WB_IMMEDIATE selection. Store its
    // immediate value in the common ALU-result channel to avoid carrying
    // another 32-bit datapath field through EX/MEM and MEM/WB.
    always_comb begin
        if (id_ex_payload.control.wb_sel == WB_IMMEDIATE) begin
            alu_result_final = id_ex_payload.immediate;
        end
        else begin
            alu_result_final = alu_result_raw;
        end
    end

    // ==================================================================
    // Branch resolution
    // ==================================================================

    rv32i_branch_compare u_branch_compare (
        .operand_a_i    (ex_rs1_value_forwarded),
        .operand_b_i    (ex_rs2_value_forwarded),
        .branch_op_i    (id_ex_payload.control.branch_op),
        .branch_taken_o (branch_taken)
    );

    rv32i_target_generator u_target_generator (
        .pc_i                (id_ex_payload.pc),
        .rs1_value_i         (ex_rs1_value_forwarded),
        .immediate_i         (id_ex_payload.immediate),
        .branch_op_i         (id_ex_payload.control.branch_op),

        .target_o            (branch_target),
        .target_misaligned_o (branch_target_misaligned)
    );

    always_comb begin
        branch_active =
            (id_ex_payload.control.branch_op != BR_NONE);

        if (branch_active && branch_taken) begin
            actual_next_pc = branch_target;
        end
        else begin
            actual_next_pc = id_ex_payload.pc + 32'd4;
        end

        branch_mispredict =
            branch_active &&
            (actual_next_pc != id_ex_payload.prediction.predicted_pc);
    end

    always_comb begin
        ex_exception = id_ex_payload.exception;

        if (
            !ex_exception.valid &&
            branch_active &&
            branch_taken &&
            branch_target_misaligned
        ) begin
            ex_exception.valid        = 1'b1;
            ex_exception.is_interrupt = 1'b0;
            ex_exception.cause        = EXC_INSN_ADDR_MISALIGNED;
            ex_exception.epc          = id_ex_payload.pc;
            ex_exception.tval         = branch_target;
        end
    end

    assign ex_fire =
        id_ex_valid &&
        ex_mem_input_ready;

    assign branch_redirect =
        ex_fire &&
        branch_mispredict &&
        !ex_exception.valid;


    // STEP 11AR: Train the branch predictor from registered EX/MEM state.
    //
    // Redirect resolution remains in EX.  Predictor training occurs when
    // the corresponding EX/MEM transaction advances, removing the BTB
    // update network from the combinational EX-to-fetch redirect cone.
    //
    // commit_redirect_valid suppresses training for an EX/MEM instruction
    // that is being invalidated by an older trap or MRET redirect.
    assign predictor_update_valid =
        ex_mem_valid &&
        mem_stage_ready &&
        (ex_mem_payload.control.branch_op != BR_NONE) &&
        !ex_mem_payload.exception.valid &&
        !commit_redirect_valid;

    assign predictor_update_pc =
        ex_mem_payload.pc;

    assign predictor_update_taken =
        ex_mem_payload.branch_taken;

    assign predictor_update_target =
        ex_mem_payload.actual_next_pc;

    assign predictor_update_pht_index =
        ex_mem_payload.prediction.pht_index;


    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            bpu_branch_count_q          <= 32'd0;
            bpu_mispredict_count_q      <= 32'd0;
            bpu_correct_count_q         <= 32'd0;
            bpu_predicted_taken_count_q <= 32'd0;
            bpu_actual_taken_count_q    <= 32'd0;
        end
        else if (predictor_update_valid) begin
            bpu_branch_count_q <=
                bpu_branch_count_q + 32'd1;

            if (ex_mem_payload.branch_mispredict) begin
                bpu_mispredict_count_q <=
                    bpu_mispredict_count_q + 32'd1;
            end
            else begin
                bpu_correct_count_q <=
                    bpu_correct_count_q + 32'd1;
            end

            if (ex_mem_payload.prediction.predicted_taken) begin
                bpu_predicted_taken_count_q <=
                    bpu_predicted_taken_count_q + 32'd1;
            end

            if (ex_mem_payload.branch_taken) begin
                bpu_actual_taken_count_q <=
                    bpu_actual_taken_count_q + 32'd1;
            end
        end
    end

    assign debug_redirect_valid_o = frontend_redirect_valid;
    assign debug_redirect_pc_o    = frontend_redirect_pc;

    // ==================================================================
    // EX/MEM payload assembly
    // ==================================================================

    always_comb begin
        ex_mem_payload_d = '0;

        ex_mem_payload_d.pc          = id_ex_payload.pc;
        ex_mem_payload_d.instruction = id_ex_payload.instruction;
        ex_mem_payload_d.rd_index    = id_ex_payload.rd_index;

        ex_mem_payload_d.alu_result = alu_result_final;
        ex_mem_payload_d.store_data = ex_rs2_value_forwarded;
        ex_mem_payload_d.pc_plus_4  = id_ex_payload.pc + 32'd4;

        ex_mem_payload_d.branch_taken      = branch_taken;
        ex_mem_payload_d.branch_target     = branch_target;
        ex_mem_payload_d.actual_next_pc    = actual_next_pc;
        ex_mem_payload_d.branch_mispredict = branch_mispredict;

        ex_mem_payload_d.csr_address =
            id_ex_payload.csr_address;

        if (id_ex_payload.control.csr_use_immediate) begin
            ex_mem_payload_d.csr_write_operand =
                id_ex_payload.immediate;
        end
        else begin
            ex_mem_payload_d.csr_write_operand =
                ex_csr_write_operand;
        end

        ex_mem_payload_d.control    = id_ex_payload.control;
        ex_mem_payload_d.prediction = id_ex_payload.prediction;
        ex_mem_payload_d.exception  = ex_exception;
    end

    // ==================================================================
    // EX/MEM pipeline register
    // ==================================================================

    rv32i_ex_mem u_ex_mem (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),

        .flush_i   (commit_redirect_valid),
        .kill_i    (1'b0),

        .valid_i   (id_ex_valid),
        .ready_o   (ex_mem_input_ready),
        .payload_i (ex_mem_payload_d),

        .valid_o   (ex_mem_valid),
        .ready_i   (mem_stage_ready),
        .payload_o (ex_mem_payload)
    );

    // ==================================================================
    // MEM stage with LSU
    //
    // Non-memory instructions pass through in one cycle.
    // Memory instructions hold EX/MEM until the LSU completes.
    // Stores are allowed to retire only after the D-memory response.
    // ==================================================================

    assign mem_stage_is_memory =
        ex_mem_valid &&
        ex_mem_payload.control.memory_valid;

    assign mem_stage_lsu_valid =
        mem_stage_is_memory &&
        !ex_mem_payload.exception.valid;

    rv32i_lsu u_lsu (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),

        .valid_i           (mem_stage_lsu_valid),
        .ready_o           (lsu_ready),

        .memory_write_i    (ex_mem_payload.control.memory_write),
        .address_i         (ex_mem_payload.alu_result),
        .store_data_i      (ex_mem_payload.store_data),
        .size_i            (ex_mem_payload.control.memory_size),
        .unsigned_load_i   (ex_mem_payload.control.memory_unsigned),

        .complete_o        (lsu_complete),
        .load_data_o       (lsu_load_data),
        .exception_o       (lsu_exception),

        .dmem_req_valid_o  (dmem_req_valid_o),
        .dmem_req_ready_i  (dmem_req_ready_i),
        .dmem_req_o        (dmem_req_o),

        .dmem_rsp_valid_i  (dmem_rsp_valid_i),
        .dmem_rsp_ready_o  (dmem_rsp_ready_o),
        .dmem_rsp_i        (dmem_rsp_i)
    );

    always_comb begin
        mem_exception = ex_mem_payload.exception;

        if (lsu_exception.valid) begin
            mem_exception     = lsu_exception;
            mem_exception.epc = ex_mem_payload.pc;
        end
    end

    always_comb begin
        mem_stage_complete = 1'b0;

        if (ex_mem_valid) begin
            if (ex_mem_payload.exception.valid) begin
                mem_stage_complete = 1'b1;
            end
            else if (ex_mem_payload.control.memory_valid) begin
                mem_stage_complete = lsu_complete;
            end
            else begin
                mem_stage_complete = 1'b1;
            end
        end
    end

    assign mem_stage_ready =
        mem_wb_input_ready &&
        mem_stage_complete;

    always_comb begin
        mem_wb_payload_d = '0;

        mem_wb_payload_d.pc =
            ex_mem_payload.pc;

        mem_wb_payload_d.instruction =
            ex_mem_payload.instruction;

        mem_wb_payload_d.rd_index =
            ex_mem_payload.rd_index;


        // STEP 11AU: Select final writeback data before MEM/WB capture.
        case (ex_mem_payload.control.wb_sel)
            WB_ALU,
            WB_IMMEDIATE: begin
                mem_wb_payload_d.writeback_data =
                    ex_mem_payload.alu_result;
            end

            WB_MEMORY: begin
                mem_wb_payload_d.writeback_data =
                    lsu_load_data;
            end

            WB_PC_PLUS_4: begin
                mem_wb_payload_d.writeback_data =
                    ex_mem_payload.pc_plus_4;
            end

            WB_CSR: begin
                mem_wb_payload_d.writeback_data =
                    csr_read_data;
            end

            WB_NONE: begin
                mem_wb_payload_d.writeback_data = '0;
            end

            default: begin
                mem_wb_payload_d.writeback_data = '0;
            end
        endcase

        mem_wb_payload_d.alu_result =
            ex_mem_payload.alu_result;

        mem_wb_payload_d.memory_result =
            lsu_load_data;

        mem_wb_payload_d.pc_plus_4 =
            ex_mem_payload.pc_plus_4;

        mem_wb_payload_d.actual_next_pc =
            ex_mem_payload.actual_next_pc;

        mem_wb_payload_d.csr_address =
            ex_mem_payload.csr_address;

        mem_wb_payload_d.csr_write_operand =
            ex_mem_payload.csr_write_operand;

        mem_wb_payload_d.csr_read_data =
            csr_read_data;

        mem_wb_payload_d.control =
            ex_mem_payload.control;

        mem_wb_payload_d.exception =
            mem_exception;
    end

    // Keep currently unused ready output visible to lint/formal without
    // affecting functionality. The MEM-stage advance condition uses
    // lsu_complete because the instruction may only leave MEM after the
    // request/response transaction has completed.
    logic unused_lsu_ready;

    assign unused_lsu_ready = lsu_ready;

    // ==================================================================
    // MEM/WB pipeline register
    // ==================================================================

    rv32i_mem_wb u_mem_wb (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),

        .flush_i   (1'b0),
        .kill_i    (1'b0),

        .valid_i   (
            ex_mem_valid &&
            mem_stage_complete &&
            !commit_redirect_valid
        ),
        .ready_o   (mem_wb_input_ready),
        .payload_i (mem_wb_payload_d),

        .valid_o   (mem_wb_valid),
        .ready_i   (1'b1),
        .payload_o (mem_wb_payload)
    );

    // ==================================================================
    // Baseline commit interface
    //
    // Signals describe the current MEM/WB transaction. Architectural state
    // is updated on the active clock edge while commit_valid_o is asserted.
    // ==================================================================

    assign commit_valid_o       = mem_wb_valid;
    assign commit_trap_o        = mem_wb_payload.exception.valid;
    assign commit_pc_o          = mem_wb_payload.pc;
    assign commit_next_pc_o     = mem_wb_payload.actual_next_pc;
    assign commit_instruction_o = mem_wb_payload.instruction;

    assign commit_rd_write_o = register_write_enable;
    assign commit_rd_index_o = mem_wb_payload.rd_index;
    assign commit_rd_data_o  = writeback_data;

endmodule
