module rv32i_ghr (
	clk_i,
	rst_ni,
	clear_i,
	update_valid_i,
	update_taken_i,
	history_o
);
	parameter [31:0] WIDTH = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire clear_i;
	input wire update_valid_i;
	input wire update_taken_i;
	output wire [WIDTH - 1:0] history_o;
	reg [WIDTH - 1:0] history_q;
	assign history_o = history_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			history_q <= 1'sb0;
		else if (clear_i)
			history_q <= 1'sb0;
		else if (update_valid_i)
			history_q <= {history_q[WIDTH - 2:0], update_taken_i};
endmodule
module rv32i_pht (
	clk_i,
	rst_ni,
	read_index_i,
	predict_taken_o,
	read_counter_o,
	update_valid_i,
	update_index_i,
	update_taken_i
);
	parameter [31:0] INDEX_WIDTH = 8;
	input wire clk_i;
	input wire rst_ni;
	input wire [INDEX_WIDTH - 1:0] read_index_i;
	output reg predict_taken_o;
	output reg [1:0] read_counter_o;
	input wire update_valid_i;
	input wire [INDEX_WIDTH - 1:0] update_index_i;
	input wire update_taken_i;
	localparam [31:0] ENTRY_COUNT = 1 << INDEX_WIDTH;
	reg [1:0] table_q [0:ENTRY_COUNT - 1];
	integer reset_index;
	always @(*) begin
		read_counter_o = table_q[read_index_i];
		predict_taken_o = table_q[read_index_i][1];
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			for (reset_index = 0; reset_index < ENTRY_COUNT; reset_index = reset_index + 1)
				table_q[reset_index] <= 2'b01;
		else if (update_valid_i) begin
			if (update_taken_i) begin
				if (table_q[update_index_i] != 2'b11)
					table_q[update_index_i] <= table_q[update_index_i] + 2'b01;
			end
			else if (table_q[update_index_i] != 2'b00)
				table_q[update_index_i] <= table_q[update_index_i] - 2'b01;
		end
endmodule
module rv32i_btb (
	clk_i,
	rst_ni,
	read_pc_i,
	hit_o,
	target_o,
	update_valid_i,
	update_pc_i,
	update_target_i
);
	parameter [31:0] INDEX_WIDTH = 6;
	input wire clk_i;
	input wire rst_ni;
	input wire [31:0] read_pc_i;
	output reg hit_o;
	output reg [31:0] target_o;
	input wire update_valid_i;
	input wire [31:0] update_pc_i;
	input wire [31:0] update_target_i;
	localparam [31:0] ENTRY_COUNT = 1 << INDEX_WIDTH;
	localparam [31:0] INDEX_LSB = 2;
	localparam [31:0] INDEX_MSB = (INDEX_LSB + INDEX_WIDTH) - 1;
	localparam [31:0] TAG_WIDTH = (32 - INDEX_WIDTH) - INDEX_LSB;
	reg valid_q [0:ENTRY_COUNT - 1];
	reg [TAG_WIDTH - 1:0] tag_q [0:ENTRY_COUNT - 1];
	reg [31:0] target_q [0:ENTRY_COUNT - 1];
	wire [INDEX_WIDTH - 1:0] read_index;
	wire [TAG_WIDTH - 1:0] read_tag;
	wire [INDEX_WIDTH - 1:0] update_index;
	wire [TAG_WIDTH - 1:0] update_tag;
	integer reset_index;
	assign read_index = read_pc_i[INDEX_MSB:INDEX_LSB];
	assign read_tag = read_pc_i[31:INDEX_MSB + 1];
	assign update_index = update_pc_i[INDEX_MSB:INDEX_LSB];
	assign update_tag = update_pc_i[31:INDEX_MSB + 1];
	always @(*) begin
		hit_o = valid_q[read_index] && (tag_q[read_index] == read_tag);
		target_o = target_q[read_index];
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			for (reset_index = 0; reset_index < ENTRY_COUNT; reset_index = reset_index + 1)
				begin
					valid_q[reset_index] <= 1'b0;
					tag_q[reset_index] <= 1'sb0;
					target_q[reset_index] <= 1'sb0;
				end
		else if (update_valid_i) begin
			valid_q[update_index] <= 1'b1;
			tag_q[update_index] <= update_tag;
			target_q[update_index] <= update_target_i;
		end
endmodule
module rv32i_branch_predictor (
	clk_i,
	rst_ni,
	clear_i,
	fetch_pc_i,
	predict_taken_o,
	predict_pc_o,
	predict_pht_index_o,
	predict_ghr_o,
	predict_btb_hit_o,
	predict_btb_target_o,
	update_valid_i,
	update_pc_i,
	update_taken_i,
	update_target_i,
	update_pht_index_i
);
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	parameter [31:0] GHR_WIDTH = rv32i_types_pkg_GHR_WIDTH;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	parameter [31:0] PHT_INDEX_WIDTH = rv32i_types_pkg_PHT_INDEX_WIDTH;
	parameter [31:0] BTB_INDEX_WIDTH = 6;
	input wire clk_i;
	input wire rst_ni;
	input wire clear_i;
	input wire [31:0] fetch_pc_i;
	output reg predict_taken_o;
	output reg [31:0] predict_pc_o;
	output reg [PHT_INDEX_WIDTH - 1:0] predict_pht_index_o;
	output reg [GHR_WIDTH - 1:0] predict_ghr_o;
	output reg predict_btb_hit_o;
	output reg [31:0] predict_btb_target_o;
	input wire update_valid_i;
	input wire [31:0] update_pc_i;
	input wire update_taken_i;
	input wire [31:0] update_target_i;
	input wire [PHT_INDEX_WIDTH - 1:0] update_pht_index_i;
	wire [GHR_WIDTH - 1:0] ghr_history;
	reg [PHT_INDEX_WIDTH - 1:0] pc_index;
	reg [PHT_INDEX_WIDTH - 1:0] gshare_index;
	wire pht_predict_taken;
	wire [1:0] pht_counter;
	wire btb_hit;
	wire [31:0] btb_target;
	rv32i_ghr #(.WIDTH(GHR_WIDTH)) u_ghr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.clear_i(clear_i),
		.update_valid_i(update_valid_i),
		.update_taken_i(update_taken_i),
		.history_o(ghr_history)
	);
	always @(*) begin
		pc_index = fetch_pc_i[PHT_INDEX_WIDTH + 1:2];
		gshare_index = pc_index ^ {{PHT_INDEX_WIDTH - GHR_WIDTH {1'b0}}, ghr_history};
	end
	rv32i_pht #(.INDEX_WIDTH(PHT_INDEX_WIDTH)) u_pht(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.read_index_i(gshare_index),
		.predict_taken_o(pht_predict_taken),
		.read_counter_o(pht_counter),
		.update_valid_i(update_valid_i),
		.update_index_i(update_pht_index_i),
		.update_taken_i(update_taken_i)
	);
	rv32i_btb #(.INDEX_WIDTH(BTB_INDEX_WIDTH)) u_btb(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.read_pc_i(fetch_pc_i),
		.hit_o(btb_hit),
		.target_o(btb_target),
		.update_valid_i(update_valid_i && update_taken_i),
		.update_pc_i(update_pc_i),
		.update_target_i(update_target_i)
	);
	always @(*) begin
		predict_taken_o = pht_predict_taken && btb_hit;
		predict_pc_o = fetch_pc_i + 32'd4;
		predict_pht_index_o = gshare_index;
		predict_ghr_o = ghr_history;
		predict_btb_hit_o = btb_hit;
		predict_btb_target_o = btb_target;
		if (predict_taken_o)
			predict_pc_o = btb_target;
	end
	wire unused_pht_counter;
	assign unused_pht_counter = ^pht_counter;
endmodule
module rv32i_pc (
	clk_i,
	rst_ni,
	next_valid_i,
	next_pc_i,
	redirect_valid_i,
	redirect_pc_i,
	pc_o
);
	parameter [31:0] RESET_VECTOR = 32'h00000000;
	input wire clk_i;
	input wire rst_ni;
	input wire next_valid_i;
	input wire [31:0] next_pc_i;
	input wire redirect_valid_i;
	input wire [31:0] redirect_pc_i;
	output wire [31:0] pc_o;
	reg [31:0] pc_q;
	assign pc_o = pc_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			pc_q <= RESET_VECTOR;
		else if (redirect_valid_i)
			pc_q <= redirect_pc_i;
		else if (next_valid_i)
			pc_q <= next_pc_i;
endmodule
module rv32i_fetch_buffer (
	clk_i,
	rst_ni,
	flush_i,
	valid_i,
	ready_o,
	payload_i,
	valid_o,
	ready_i,
	payload_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire valid_i;
	output reg ready_o;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	input wire [147:0] payload_i;
	output wire valid_o;
	input wire ready_i;
	output wire [147:0] payload_o;
	reg valid_q;
	reg [147:0] payload_q;
	always @(*) begin
		if (_sv2v_0)
			;
		ready_o = !valid_q || ready_i;
	end
	assign valid_o = valid_q;
	assign payload_o = payload_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'b0;
		else if (flush_i)
			valid_q <= 1'b0;
		else if (ready_o) begin
			valid_q <= valid_i;
			if (valid_i)
				payload_q <= payload_i;
		end
	initial _sv2v_0 = 0;
endmodule
module rv32i_fetch_unit (
	clk_i,
	rst_ni,
	redirect_valid_i,
	redirect_pc_i,
	predictor_update_valid_i,
	predictor_update_pc_i,
	predictor_update_taken_i,
	predictor_update_target_i,
	predictor_update_pht_index_i,
	imem_req_valid_o,
	imem_req_ready_i,
	imem_req_o,
	imem_rsp_valid_i,
	imem_rsp_ready_o,
	imem_rsp_i,
	fetch_valid_o,
	fetch_ready_i,
	fetch_payload_o
);
	parameter [31:0] RESET_VECTOR = 32'h00000000;
	parameter [31:0] BTB_INDEX_WIDTH = 6;
	input wire clk_i;
	input wire rst_ni;
	input wire redirect_valid_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] redirect_pc_i;
	input wire predictor_update_valid_i;
	input wire [31:0] predictor_update_pc_i;
	input wire predictor_update_taken_i;
	input wire [31:0] predictor_update_target_i;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	input wire [7:0] predictor_update_pht_index_i;
	output wire imem_req_valid_o;
	input wire imem_req_ready_i;
	localparam [31:0] rv32i_types_pkg_FETCH_EPOCH_W = 4;
	output reg [35:0] imem_req_o;
	input wire imem_rsp_valid_i;
	output wire imem_rsp_ready_o;
	input wire [36:0] imem_rsp_i;
	output wire fetch_valid_o;
	input wire fetch_ready_i;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	output wire [147:0] fetch_payload_o;
	reg [31:0] pc_q;
	reg [31:0] pc_next;
	wire request_fire;
	wire response_fire;
	wire can_issue_request;
	reg [3:0] epoch_q;
	wire [3:0] request_epoch;
	reg pending_valid_q;
	reg [31:0] pending_pc_q;
	reg [31:0] pending_pc_plus_4_q;
	reg [82:0] pending_prediction_q;
	reg buffer_valid_q;
	reg [147:0] buffer_payload_q;
	wire predict_taken;
	wire [31:0] predict_pc;
	wire [7:0] predict_pht_index;
	wire [7:0] predict_ghr;
	wire predict_btb_hit;
	wire [31:0] predict_btb_target;
	reg [82:0] current_prediction;
	rv32i_branch_predictor #(
		.GHR_WIDTH(rv32i_types_pkg_GHR_WIDTH),
		.PHT_INDEX_WIDTH(rv32i_types_pkg_PHT_INDEX_WIDTH),
		.BTB_INDEX_WIDTH(BTB_INDEX_WIDTH)
	) u_branch_predictor(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.clear_i(1'b0),
		.fetch_pc_i(pc_q),
		.predict_taken_o(predict_taken),
		.predict_pc_o(predict_pc),
		.predict_pht_index_o(predict_pht_index),
		.predict_ghr_o(predict_ghr),
		.predict_btb_hit_o(predict_btb_hit),
		.predict_btb_target_o(predict_btb_target),
		.update_valid_i(predictor_update_valid_i),
		.update_pc_i(predictor_update_pc_i),
		.update_taken_i(predictor_update_taken_i),
		.update_target_i(predictor_update_target_i),
		.update_pht_index_i(predictor_update_pht_index_i)
	);
	always @(*) begin
		current_prediction = 1'sb0;
		current_prediction[82] = 1'b1;
		current_prediction[81] = predict_taken;
		current_prediction[80-:32] = predict_pc;
		current_prediction[48-:8] = predict_pht_index;
		current_prediction[40-:8] = predict_ghr;
		current_prediction[32] = predict_btb_hit;
		current_prediction[31-:32] = predict_btb_target;
	end
	assign can_issue_request = (!pending_valid_q || response_fire) && (!buffer_valid_q || fetch_ready_i);
	assign imem_req_valid_o = can_issue_request;
	assign request_fire = imem_req_valid_o && imem_req_ready_i;
	assign response_fire = imem_rsp_valid_i && imem_rsp_ready_o;
	assign request_epoch = epoch_q;
	always @(*) begin
		imem_req_o = 1'sb0;
		imem_req_o[35-:32] = pc_q;
		imem_req_o[3-:rv32i_types_pkg_FETCH_EPOCH_W] = request_epoch;
	end
	assign imem_rsp_ready_o = !buffer_valid_q || fetch_ready_i;
	assign fetch_valid_o = buffer_valid_q;
	assign fetch_payload_o = buffer_payload_q;
	always @(*) begin
		pc_next = pc_q;
		if (redirect_valid_i)
			pc_next = redirect_pc_i;
		else if (request_fire)
			pc_next = predict_pc;
	end
	function automatic [31:0] sv2v_cast_4E913;
		input reg [31:0] inp;
		sv2v_cast_4E913 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			pc_q <= sv2v_cast_4E913(RESET_VECTOR);
			epoch_q <= 1'sb0;
			pending_valid_q <= 1'b0;
			buffer_valid_q <= 1'b0;
		end
		else if (redirect_valid_i) begin
			pc_q <= redirect_pc_i;
			epoch_q <= epoch_q + {{3 {1'b0}}, 1'b1};
			pending_valid_q <= 1'b0;
			buffer_valid_q <= 1'b0;
		end
		else begin
			pc_q <= pc_next;
			if (fetch_ready_i)
				buffer_valid_q <= 1'b0;
			if (response_fire) begin
				pending_valid_q <= 1'b0;
				if (pending_valid_q && (imem_rsp_i[3-:rv32i_types_pkg_FETCH_EPOCH_W] == epoch_q))
					buffer_valid_q <= 1'b1;
			end
			if (request_fire)
				pending_valid_q <= 1'b1;
		end
	always @(posedge clk_i)
		if (request_fire) begin
			pending_pc_q <= pc_q;
			pending_pc_plus_4_q <= pc_q + 32'd4;
			pending_prediction_q <= current_prediction;
		end
	always @(posedge clk_i)
		if ((response_fire && pending_valid_q) && (imem_rsp_i[3-:rv32i_types_pkg_FETCH_EPOCH_W] == epoch_q)) begin
			buffer_payload_q[147-:32] <= pending_pc_q;
			buffer_payload_q[115-:32] <= imem_rsp_i[36-:32];
			buffer_payload_q[83-:83] <= pending_prediction_q;
			buffer_payload_q[0] <= imem_rsp_i[4];
		end
endmodule
module rv32i_alu_decoder (
	opcode_i,
	funct3_i,
	funct7_i,
	alu_op_o,
	illegal_o
);
	reg _sv2v_0;
	input wire [6:0] opcode_i;
	input wire [2:0] funct3_i;
	input wire [6:0] funct7_i;
	output reg [4:0] alu_op_o;
	output reg illegal_o;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_ADD_SUB = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_AND = 3'b111;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_OR = 3'b110;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SLL = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SLT = 3'b010;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SLTU = 3'b011;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SRL_SRA = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_XOR = 3'b100;
	localparam [6:0] rv32i_encoding_pkg_FUNCT7_BASE = 7'b0000000;
	localparam [6:0] rv32i_encoding_pkg_FUNCT7_SUB_SRA = 7'b0100000;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP = 7'b0110011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP_IMM = 7'b0010011;
	always @(*) begin
		if (_sv2v_0)
			;
		alu_op_o = 5'd0;
		illegal_o = 1'b0;
		case (opcode_i)
			rv32i_encoding_pkg_OPCODE_OP:
				case (funct3_i)
					rv32i_encoding_pkg_FUNCT3_ADD_SUB:
						case (funct7_i)
							rv32i_encoding_pkg_FUNCT7_BASE: alu_op_o = 5'd0;
							rv32i_encoding_pkg_FUNCT7_SUB_SRA: alu_op_o = 5'd1;
							default: illegal_o = 1'b1;
						endcase
					rv32i_encoding_pkg_FUNCT3_SLL:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd2;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_SLT:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd3;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_SLTU:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd4;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_XOR:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd5;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_SRL_SRA:
						case (funct7_i)
							rv32i_encoding_pkg_FUNCT7_BASE: alu_op_o = 5'd6;
							rv32i_encoding_pkg_FUNCT7_SUB_SRA: alu_op_o = 5'd7;
							default: illegal_o = 1'b1;
						endcase
					rv32i_encoding_pkg_FUNCT3_OR:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd8;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_AND:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd9;
						else
							illegal_o = 1'b1;
					default: illegal_o = 1'b1;
				endcase
			rv32i_encoding_pkg_OPCODE_OP_IMM:
				case (funct3_i)
					rv32i_encoding_pkg_FUNCT3_ADD_SUB: alu_op_o = 5'd0;
					rv32i_encoding_pkg_FUNCT3_SLT: alu_op_o = 5'd3;
					rv32i_encoding_pkg_FUNCT3_SLTU: alu_op_o = 5'd4;
					rv32i_encoding_pkg_FUNCT3_XOR: alu_op_o = 5'd5;
					rv32i_encoding_pkg_FUNCT3_OR: alu_op_o = 5'd8;
					rv32i_encoding_pkg_FUNCT3_AND: alu_op_o = 5'd9;
					rv32i_encoding_pkg_FUNCT3_SLL:
						if (funct7_i == rv32i_encoding_pkg_FUNCT7_BASE)
							alu_op_o = 5'd2;
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_SRL_SRA:
						case (funct7_i)
							rv32i_encoding_pkg_FUNCT7_BASE: alu_op_o = 5'd6;
							rv32i_encoding_pkg_FUNCT7_SUB_SRA: alu_op_o = 5'd7;
							default: illegal_o = 1'b1;
						endcase
					default: illegal_o = 1'b1;
				endcase
			default: begin
				alu_op_o = 5'd0;
				illegal_o = 1'b1;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_illegal_detect (
	instruction_i,
	illegal_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_INSN_WIDTH = 32;
	input wire [31:0] instruction_i;
	output reg illegal_o;
	wire [6:0] opcode;
	wire [2:0] funct3;
	wire [6:0] funct7;
	wire [4:0] rs1;
	wire [4:0] rd;
	wire [11:0] system_code;
	wire [4:0] unused_alu_op;
	wire alu_illegal;
	assign opcode = instruction_i[6:0];
	assign rd = instruction_i[11:7];
	assign funct3 = instruction_i[14:12];
	assign rs1 = instruction_i[19:15];
	assign funct7 = instruction_i[31:25];
	assign system_code = instruction_i[31:20];
	rv32i_alu_decoder u_alu_decoder(
		.opcode_i(opcode),
		.funct3_i(funct3),
		.funct7_i(funct7),
		.alu_op_o(unused_alu_op),
		.illegal_o(alu_illegal)
	);
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BEQ = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BGE = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BGEU = 3'b111;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BLT = 3'b100;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BLTU = 3'b110;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BNE = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRC = 3'b011;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRCI = 3'b111;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRS = 3'b010;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRSI = 3'b110;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRW = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRWI = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_FENCE = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_FENCE_I = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LB = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LBU = 3'b100;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LH = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LHU = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LW = 3'b010;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_PRIV = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SB = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SH = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SW = 3'b010;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_AUIPC = 7'b0010111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_BRANCH = 7'b1100011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_JALR = 7'b1100111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_LOAD = 7'b0000011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_LUI = 7'b0110111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_MISC_MEM = 7'b0001111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP = 7'b0110011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP_IMM = 7'b0010011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_STORE = 7'b0100011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_SYSTEM = 7'b1110011;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_EBREAK = 12'h001;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_ECALL = 12'h000;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_MRET = 12'h302;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_WFI = 12'h105;
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_o = 1'b1;
		case (opcode)
			rv32i_encoding_pkg_OPCODE_LUI, rv32i_encoding_pkg_OPCODE_AUIPC, rv32i_encoding_pkg_OPCODE_JAL: illegal_o = 1'b0;
			rv32i_encoding_pkg_OPCODE_JALR: illegal_o = funct3 != 3'b000;
			rv32i_encoding_pkg_OPCODE_BRANCH:
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_BEQ, rv32i_encoding_pkg_FUNCT3_BNE, rv32i_encoding_pkg_FUNCT3_BLT, rv32i_encoding_pkg_FUNCT3_BGE, rv32i_encoding_pkg_FUNCT3_BLTU, rv32i_encoding_pkg_FUNCT3_BGEU: illegal_o = 1'b0;
					default: illegal_o = 1'b1;
				endcase
			rv32i_encoding_pkg_OPCODE_LOAD:
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_LB, rv32i_encoding_pkg_FUNCT3_LH, rv32i_encoding_pkg_FUNCT3_LW, rv32i_encoding_pkg_FUNCT3_LBU, rv32i_encoding_pkg_FUNCT3_LHU: illegal_o = 1'b0;
					default: illegal_o = 1'b1;
				endcase
			rv32i_encoding_pkg_OPCODE_STORE:
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_SB, rv32i_encoding_pkg_FUNCT3_SH, rv32i_encoding_pkg_FUNCT3_SW: illegal_o = 1'b0;
					default: illegal_o = 1'b1;
				endcase
			rv32i_encoding_pkg_OPCODE_OP, rv32i_encoding_pkg_OPCODE_OP_IMM: illegal_o = alu_illegal;
			rv32i_encoding_pkg_OPCODE_MISC_MEM:
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_FENCE, rv32i_encoding_pkg_FUNCT3_FENCE_I: illegal_o = 1'b0;
					default: illegal_o = 1'b1;
				endcase
			rv32i_encoding_pkg_OPCODE_SYSTEM:
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_PRIV:
						if ((rs1 == 5'd0) && (rd == 5'd0))
							case (system_code)
								rv32i_encoding_pkg_SYSTEM_ECALL, rv32i_encoding_pkg_SYSTEM_EBREAK, rv32i_encoding_pkg_SYSTEM_WFI, rv32i_encoding_pkg_SYSTEM_MRET: illegal_o = 1'b0;
								default: illegal_o = 1'b1;
							endcase
						else
							illegal_o = 1'b1;
					rv32i_encoding_pkg_FUNCT3_CSRRW, rv32i_encoding_pkg_FUNCT3_CSRRS, rv32i_encoding_pkg_FUNCT3_CSRRC, rv32i_encoding_pkg_FUNCT3_CSRRWI, rv32i_encoding_pkg_FUNCT3_CSRRSI, rv32i_encoding_pkg_FUNCT3_CSRRCI: illegal_o = 1'b0;
					default: illegal_o = 1'b1;
				endcase
			default: illegal_o = 1'b1;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_decoder (
	instruction_i,
	control_o,
	rs1_index_o,
	rs2_index_o,
	rd_index_o,
	csr_address_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_INSN_WIDTH = 32;
	input wire [31:0] instruction_i;
	output reg [37:0] control_o;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	output wire [4:0] rs1_index_o;
	output wire [4:0] rs2_index_o;
	output wire [4:0] rd_index_o;
	output wire [11:0] csr_address_o;
	wire [6:0] opcode;
	wire [2:0] funct3;
	wire [6:0] funct7;
	wire [4:0] decoded_alu_op;
	wire unused_alu_illegal;
	wire illegal_encoding;
	assign opcode = instruction_i[6:0];
	assign rd_index_o = instruction_i[11:7];
	assign funct3 = instruction_i[14:12];
	assign rs1_index_o = instruction_i[19:15];
	assign rs2_index_o = instruction_i[24:20];
	assign funct7 = instruction_i[31:25];
	assign csr_address_o = instruction_i[31:20];
	rv32i_alu_decoder u_alu_decoder(
		.opcode_i(opcode),
		.funct3_i(funct3),
		.funct7_i(funct7),
		.alu_op_o(decoded_alu_op),
		.illegal_o(unused_alu_illegal)
	);
	rv32i_illegal_detect u_illegal_detect(
		.instruction_i(instruction_i),
		.illegal_o(illegal_encoding)
	);
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BEQ = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BGE = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BGEU = 3'b111;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BLT = 3'b100;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BLTU = 3'b110;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_BNE = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRC = 3'b011;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRCI = 3'b111;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRS = 3'b010;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRSI = 3'b110;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRW = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_CSRRWI = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_FENCE = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_FENCE_I = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LB = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LBU = 3'b100;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LH = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LHU = 3'b101;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_LW = 3'b010;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_PRIV = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SB = 3'b000;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SH = 3'b001;
	localparam [2:0] rv32i_encoding_pkg_FUNCT3_SW = 3'b010;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_AUIPC = 7'b0010111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_BRANCH = 7'b1100011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_JAL = 7'b1101111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_JALR = 7'b1100111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_LOAD = 7'b0000011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_LUI = 7'b0110111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_MISC_MEM = 7'b0001111;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP = 7'b0110011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_OP_IMM = 7'b0010011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_STORE = 7'b0100011;
	localparam [6:0] rv32i_encoding_pkg_OPCODE_SYSTEM = 7'b1110011;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_EBREAK = 12'h001;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_ECALL = 12'h000;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_MRET = 12'h302;
	localparam [11:0] rv32i_encoding_pkg_SYSTEM_WFI = 12'h105;
	always @(*) begin
		if (_sv2v_0)
			;
		control_o = 1'sb0;
		case (opcode)
			rv32i_encoding_pkg_OPCODE_LUI: begin
				control_o[35] = 1'b1;
				control_o[29-:3] = 3'd4;
				control_o[24-:2] = 2'd1;
				control_o[18-:3] = 3'd5;
			end
			rv32i_encoding_pkg_OPCODE_AUIPC: begin
				control_o[35] = 1'b1;
				control_o[34-:5] = 5'd0;
				control_o[29-:3] = 3'd4;
				control_o[26-:2] = 2'd1;
				control_o[24-:2] = 2'd1;
				control_o[18-:3] = 3'd1;
			end
			rv32i_encoding_pkg_OPCODE_JAL: begin
				control_o[35] = 1'b1;
				control_o[29-:3] = 3'd5;
				control_o[22-:4] = 4'd7;
				control_o[18-:3] = 3'd3;
			end
			rv32i_encoding_pkg_OPCODE_JALR: begin
				control_o[37] = 1'b1;
				control_o[35] = 1'b1;
				control_o[29-:3] = 3'd1;
				control_o[22-:4] = 4'd8;
				control_o[18-:3] = 3'd3;
			end
			rv32i_encoding_pkg_OPCODE_BRANCH: begin
				control_o[37] = 1'b1;
				control_o[36] = 1'b1;
				control_o[29-:3] = 3'd3;
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_BEQ: control_o[22-:4] = 4'd1;
					rv32i_encoding_pkg_FUNCT3_BNE: control_o[22-:4] = 4'd2;
					rv32i_encoding_pkg_FUNCT3_BLT: control_o[22-:4] = 4'd3;
					rv32i_encoding_pkg_FUNCT3_BGE: control_o[22-:4] = 4'd4;
					rv32i_encoding_pkg_FUNCT3_BLTU: control_o[22-:4] = 4'd5;
					rv32i_encoding_pkg_FUNCT3_BGEU: control_o[22-:4] = 4'd6;
					default: control_o[22-:4] = 4'd0;
				endcase
			end
			rv32i_encoding_pkg_OPCODE_LOAD: begin
				control_o[37] = 1'b1;
				control_o[35] = 1'b1;
				control_o[34-:5] = 5'd0;
				control_o[29-:3] = 3'd1;
				control_o[26-:2] = 2'd0;
				control_o[24-:2] = 2'd1;
				control_o[18-:3] = 3'd2;
				control_o[15] = 1'b1;
				control_o[14] = 1'b0;
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_LB: begin
						control_o[13-:2] = 2'd0;
						control_o[11] = 1'b0;
					end
					rv32i_encoding_pkg_FUNCT3_LH: begin
						control_o[13-:2] = 2'd1;
						control_o[11] = 1'b0;
					end
					rv32i_encoding_pkg_FUNCT3_LW: begin
						control_o[13-:2] = 2'd2;
						control_o[11] = 1'b0;
					end
					rv32i_encoding_pkg_FUNCT3_LBU: begin
						control_o[13-:2] = 2'd0;
						control_o[11] = 1'b1;
					end
					rv32i_encoding_pkg_FUNCT3_LHU: begin
						control_o[13-:2] = 2'd1;
						control_o[11] = 1'b1;
					end
					default: begin
						control_o[13-:2] = 2'd0;
						control_o[11] = 1'b0;
					end
				endcase
			end
			rv32i_encoding_pkg_OPCODE_STORE: begin
				control_o[37] = 1'b1;
				control_o[36] = 1'b1;
				control_o[34-:5] = 5'd0;
				control_o[29-:3] = 3'd2;
				control_o[26-:2] = 2'd0;
				control_o[24-:2] = 2'd1;
				control_o[15] = 1'b1;
				control_o[14] = 1'b1;
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_SB: control_o[13-:2] = 2'd0;
					rv32i_encoding_pkg_FUNCT3_SH: control_o[13-:2] = 2'd1;
					rv32i_encoding_pkg_FUNCT3_SW: control_o[13-:2] = 2'd2;
					default: control_o[13-:2] = 2'd0;
				endcase
			end
			rv32i_encoding_pkg_OPCODE_OP_IMM: begin
				control_o[37] = 1'b1;
				control_o[35] = 1'b1;
				control_o[34-:5] = decoded_alu_op;
				control_o[29-:3] = 3'd1;
				control_o[26-:2] = 2'd0;
				control_o[24-:2] = 2'd1;
				control_o[18-:3] = 3'd1;
			end
			rv32i_encoding_pkg_OPCODE_OP: begin
				control_o[37] = 1'b1;
				control_o[36] = 1'b1;
				control_o[35] = 1'b1;
				control_o[34-:5] = decoded_alu_op;
				control_o[26-:2] = 2'd0;
				control_o[24-:2] = 2'd0;
				control_o[18-:3] = 3'd1;
			end
			rv32i_encoding_pkg_OPCODE_MISC_MEM: begin
				control_o[1] = 1'b1;
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_FENCE: control_o[5-:4] = 4'd5;
					rv32i_encoding_pkg_FUNCT3_FENCE_I: control_o[5-:4] = 4'd6;
					default: control_o[5-:4] = 4'd0;
				endcase
			end
			rv32i_encoding_pkg_OPCODE_SYSTEM: begin
				control_o[1] = 1'b1;
				case (funct3)
					rv32i_encoding_pkg_FUNCT3_PRIV:
						case (instruction_i[31:20])
							rv32i_encoding_pkg_SYSTEM_ECALL: control_o[5-:4] = 4'd1;
							rv32i_encoding_pkg_SYSTEM_EBREAK: control_o[5-:4] = 4'd2;
							rv32i_encoding_pkg_SYSTEM_MRET: control_o[5-:4] = 4'd3;
							rv32i_encoding_pkg_SYSTEM_WFI: control_o[5-:4] = 4'd4;
							default: control_o[5-:4] = 4'd0;
						endcase
					rv32i_encoding_pkg_FUNCT3_CSRRW, rv32i_encoding_pkg_FUNCT3_CSRRS, rv32i_encoding_pkg_FUNCT3_CSRRC, rv32i_encoding_pkg_FUNCT3_CSRRWI, rv32i_encoding_pkg_FUNCT3_CSRRSI, rv32i_encoding_pkg_FUNCT3_CSRRCI: begin
						control_o[10] = 1'b1;
						control_o[35] = 1'b1;
						control_o[18-:3] = 3'd4;
						case (funct3)
							rv32i_encoding_pkg_FUNCT3_CSRRW: begin
								control_o[37] = 1'b1;
								control_o[9-:3] = 3'd1;
							end
							rv32i_encoding_pkg_FUNCT3_CSRRS: begin
								control_o[37] = 1'b1;
								control_o[9-:3] = 3'd2;
							end
							rv32i_encoding_pkg_FUNCT3_CSRRC: begin
								control_o[37] = 1'b1;
								control_o[9-:3] = 3'd3;
							end
							rv32i_encoding_pkg_FUNCT3_CSRRWI: begin
								control_o[6] = 1'b1;
								control_o[29-:3] = 3'd6;
								control_o[9-:3] = 3'd1;
							end
							rv32i_encoding_pkg_FUNCT3_CSRRSI: begin
								control_o[6] = 1'b1;
								control_o[29-:3] = 3'd6;
								control_o[9-:3] = 3'd2;
							end
							rv32i_encoding_pkg_FUNCT3_CSRRCI: begin
								control_o[6] = 1'b1;
								control_o[29-:3] = 3'd6;
								control_o[9-:3] = 3'd3;
							end
							default: control_o[9-:3] = 3'd0;
						endcase
					end
					default: control_o[5-:4] = 4'd0;
				endcase
			end
			default: control_o = 1'sb0;
		endcase
		if (illegal_encoding) begin
			control_o = 1'sb0;
			control_o[0] = 1'b1;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_imm_gen (
	instruction_i,
	imm_sel_i,
	immediate_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_INSN_WIDTH = 32;
	input wire [31:0] instruction_i;
	input wire [2:0] imm_sel_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	output reg [31:0] immediate_o;
	always @(*) begin
		if (_sv2v_0)
			;
		immediate_o = 1'sb0;
		case (imm_sel_i)
			3'd1: immediate_o = {{20 {instruction_i[31]}}, instruction_i[31:20]};
			3'd2: immediate_o = {{20 {instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
			3'd3: immediate_o = {{19 {instruction_i[31]}}, instruction_i[31], instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
			3'd4: immediate_o = {instruction_i[31:12], 12'b000000000000};
			3'd5: immediate_o = {{11 {instruction_i[31]}}, instruction_i[31], instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
			3'd6: immediate_o = {27'b000000000000000000000000000, instruction_i[19:15]};
			3'd0: immediate_o = 1'sb0;
			default: immediate_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_regfile (
	clk_i,
	rs1_index_i,
	rs2_index_i,
	rs1_data_o,
	rs2_data_o,
	write_enable_i,
	write_index_i,
	write_data_i
);
	reg _sv2v_0;
	input wire clk_i;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	input wire [4:0] rs1_index_i;
	input wire [4:0] rs2_index_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	output reg [31:0] rs1_data_o;
	output reg [31:0] rs2_data_o;
	input wire write_enable_i;
	input wire [4:0] write_index_i;
	input wire [31:0] write_data_i;
	reg [31:0] registers_q [31:0];
	localparam [4:0] rv32i_pkg_REG_X0 = 5'd0;
	always @(posedge clk_i)
		if (write_enable_i && (write_index_i != rv32i_pkg_REG_X0))
			registers_q[write_index_i] <= write_data_i;
	always @(*) begin
		if (_sv2v_0)
			;
		rs1_data_o = 1'sb0;
		if (rs1_index_i != rv32i_pkg_REG_X0) begin
			if ((write_enable_i && (write_index_i != rv32i_pkg_REG_X0)) && (write_index_i == rs1_index_i))
				rs1_data_o = write_data_i;
			else
				rs1_data_o = registers_q[rs1_index_i];
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		rs2_data_o = 1'sb0;
		if (rs2_index_i != rv32i_pkg_REG_X0) begin
			if ((write_enable_i && (write_index_i != rv32i_pkg_REG_X0)) && (write_index_i == rs2_index_i))
				rs2_data_o = write_data_i;
			else
				rs2_data_o = registers_q[rs2_index_i];
		end
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_operand_mux (
	rs1_value_i,
	rs2_value_i,
	pc_i,
	immediate_i,
	operand_a_sel_i,
	operand_b_sel_i,
	operand_a_o,
	operand_b_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] rs1_value_i;
	input wire [31:0] rs2_value_i;
	input wire [31:0] pc_i;
	input wire [31:0] immediate_i;
	input wire [1:0] operand_a_sel_i;
	input wire [1:0] operand_b_sel_i;
	output reg [31:0] operand_a_o;
	output reg [31:0] operand_b_o;
	always @(*) begin
		if (_sv2v_0)
			;
		operand_a_o = 1'sb0;
		case (operand_a_sel_i)
			2'd0: operand_a_o = rs1_value_i;
			2'd1: operand_a_o = pc_i;
			2'd2: operand_a_o = 1'sb0;
			default: operand_a_o = 1'sb0;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		operand_b_o = 1'sb0;
		case (operand_b_sel_i)
			2'd0: operand_b_o = rs2_value_i;
			2'd1: operand_b_o = immediate_i;
			2'd2: operand_b_o = 32'd4;
			2'd3: operand_b_o = 1'sb0;
			default: operand_b_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_alu (
	operand_a_i,
	operand_b_i,
	alu_op_i,
	result_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] operand_a_i;
	input wire [31:0] operand_b_i;
	input wire [4:0] alu_op_i;
	output reg [31:0] result_o;
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = 1'sb0;
		case (alu_op_i)
			5'd0: result_o = operand_a_i + operand_b_i;
			5'd1: result_o = operand_a_i - operand_b_i;
			5'd2: result_o = operand_a_i << operand_b_i[4:0];
			5'd3: result_o = {{31 {1'b0}}, $signed(operand_a_i) < $signed(operand_b_i)};
			5'd4: result_o = {{31 {1'b0}}, operand_a_i < operand_b_i};
			5'd5: result_o = operand_a_i ^ operand_b_i;
			5'd6: result_o = operand_a_i >> operand_b_i[4:0];
			5'd7: result_o = $signed(operand_a_i) >>> operand_b_i[4:0];
			5'd8: result_o = operand_a_i | operand_b_i;
			5'd9: result_o = operand_a_i & operand_b_i;
			5'd10: result_o = operand_a_i;
			5'd11: result_o = operand_b_i;
			default: result_o = 1'sb0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_branch_compare (
	operand_a_i,
	operand_b_i,
	branch_op_i,
	branch_taken_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] operand_a_i;
	input wire [31:0] operand_b_i;
	input wire [3:0] branch_op_i;
	output reg branch_taken_o;
	always @(*) begin
		if (_sv2v_0)
			;
		branch_taken_o = 1'b0;
		case (branch_op_i)
			4'd1: branch_taken_o = operand_a_i == operand_b_i;
			4'd2: branch_taken_o = operand_a_i != operand_b_i;
			4'd3: branch_taken_o = $signed(operand_a_i) < $signed(operand_b_i);
			4'd4: branch_taken_o = $signed(operand_a_i) >= $signed(operand_b_i);
			4'd5: branch_taken_o = operand_a_i < operand_b_i;
			4'd6: branch_taken_o = operand_a_i >= operand_b_i;
			4'd7, 4'd8: branch_taken_o = 1'b1;
			4'd0: branch_taken_o = 1'b0;
			default: branch_taken_o = 1'b0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_target_generator (
	pc_i,
	rs1_value_i,
	immediate_i,
	branch_op_i,
	target_o,
	target_misaligned_o
);
	reg _sv2v_0;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] pc_i;
	input wire [31:0] rs1_value_i;
	input wire [31:0] immediate_i;
	input wire [3:0] branch_op_i;
	output reg [31:0] target_o;
	output reg target_misaligned_o;
	reg [31:0] jalr_raw_target;
	function automatic rv32i_pkg_is_instruction_aligned;
		input reg [31:0] address;
		rv32i_pkg_is_instruction_aligned = address[1:0] == 2'b00;
	endfunction
	function automatic [31:0] sv2v_cast_4E913;
		input reg [31:0] inp;
		sv2v_cast_4E913 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		target_o = pc_i + sv2v_cast_4E913(32'd4);
		jalr_raw_target = rs1_value_i + immediate_i;
		target_misaligned_o = 1'b0;
		case (branch_op_i)
			4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7: target_o = pc_i + immediate_i;
			4'd8: target_o = {jalr_raw_target[31:1], 1'b0};
			4'd0: target_o = pc_i + sv2v_cast_4E913(32'd4);
			default: target_o = pc_i + sv2v_cast_4E913(32'd4);
		endcase
		if (branch_op_i != 4'd0)
			target_misaligned_o = !rv32i_pkg_is_instruction_aligned(target_o);
	end
	initial _sv2v_0 = 0;
endmodule
module rv32i_misaligned_detect (
	address_i,
	size_i,
	misaligned_o
);
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] address_i;
	input wire [1:0] size_i;
	output reg misaligned_o;
	always @(*) begin
		misaligned_o = 1'b0;
		case (size_i)
			2'd0: misaligned_o = 1'b0;
			2'd1: misaligned_o = address_i[0];
			2'd2: misaligned_o = |address_i[1:0];
			default: misaligned_o = 1'b1;
		endcase
	end
endmodule
module rv32i_store_aligner (
	address_i,
	store_data_i,
	size_i,
	aligned_write_data_o,
	write_strobe_o
);
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] address_i;
	input wire [31:0] store_data_i;
	input wire [1:0] size_i;
	output reg [31:0] aligned_write_data_o;
	output reg [3:0] write_strobe_o;
	always @(*) begin
		aligned_write_data_o = 1'sb0;
		write_strobe_o = 4'b0000;
		case (size_i)
			2'd0:
				case (address_i[1:0])
					2'b00: begin
						aligned_write_data_o = {24'b000000000000000000000000, store_data_i[7:0]};
						write_strobe_o = 4'b0001;
					end
					2'b01: begin
						aligned_write_data_o = {16'b0000000000000000, store_data_i[7:0], 8'b00000000};
						write_strobe_o = 4'b0010;
					end
					2'b10: begin
						aligned_write_data_o = {8'b00000000, store_data_i[7:0], 16'b0000000000000000};
						write_strobe_o = 4'b0100;
					end
					2'b11: begin
						aligned_write_data_o = {store_data_i[7:0], 24'b000000000000000000000000};
						write_strobe_o = 4'b1000;
					end
					default: begin
						aligned_write_data_o = 1'sb0;
						write_strobe_o = 4'b0000;
					end
				endcase
			2'd1:
				if (address_i[1]) begin
					aligned_write_data_o = {store_data_i[15:0], 16'b0000000000000000};
					write_strobe_o = 4'b1100;
				end
				else begin
					aligned_write_data_o = {16'b0000000000000000, store_data_i[15:0]};
					write_strobe_o = 4'b0011;
				end
			2'd2: begin
				aligned_write_data_o = store_data_i;
				write_strobe_o = 4'b1111;
			end
			default: begin
				aligned_write_data_o = 1'sb0;
				write_strobe_o = 4'b0000;
			end
		endcase
	end
endmodule
module rv32i_load_aligner (
	address_i,
	read_data_i,
	size_i,
	unsigned_load_i,
	load_data_o
);
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] address_i;
	input wire [31:0] read_data_i;
	input wire [1:0] size_i;
	input wire unsigned_load_i;
	output reg [31:0] load_data_o;
	reg [7:0] selected_byte;
	reg [15:0] selected_halfword;
	always @(*) begin
		selected_byte = 8'b00000000;
		case (address_i[1:0])
			2'b00: selected_byte = read_data_i[7:0];
			2'b01: selected_byte = read_data_i[15:8];
			2'b10: selected_byte = read_data_i[23:16];
			2'b11: selected_byte = read_data_i[31:24];
			default: selected_byte = 8'b00000000;
		endcase
	end
	always @(*) begin
		selected_halfword = 16'b0000000000000000;
		if (address_i[1])
			selected_halfword = read_data_i[31:16];
		else
			selected_halfword = read_data_i[15:0];
	end
	always @(*) begin
		load_data_o = 1'sb0;
		case (size_i)
			2'd0:
				if (unsigned_load_i)
					load_data_o = {24'b000000000000000000000000, selected_byte};
				else
					load_data_o = {{24 {selected_byte[7]}}, selected_byte};
			2'd1:
				if (unsigned_load_i)
					load_data_o = {16'b0000000000000000, selected_halfword};
				else
					load_data_o = {{16 {selected_halfword[15]}}, selected_halfword};
			2'd2: load_data_o = read_data_i;
			default: load_data_o = 1'sb0;
		endcase
	end
endmodule
module rv32i_memory_controller (
	clk_i,
	rst_ni,
	valid_i,
	ready_o,
	request_i,
	complete_o,
	response_o,
	dmem_req_valid_o,
	dmem_req_ready_i,
	dmem_req_o,
	dmem_rsp_valid_i,
	dmem_rsp_ready_o,
	dmem_rsp_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire valid_i;
	output reg ready_o;
	input wire [71:0] request_i;
	output reg complete_o;
	output reg [32:0] response_o;
	output reg dmem_req_valid_o;
	input wire dmem_req_ready_i;
	output reg [71:0] dmem_req_o;
	input wire dmem_rsp_valid_i;
	output reg dmem_rsp_ready_o;
	input wire [32:0] dmem_rsp_i;
	reg [0:0] state_q;
	reg [0:0] state_d;
	wire request_fire;
	wire response_fire;
	assign request_fire = dmem_req_valid_o && dmem_req_ready_i;
	assign response_fire = dmem_rsp_valid_i && dmem_rsp_ready_o;
	always @(*) begin
		if (_sv2v_0)
			;
		state_d = state_q;
		case (state_q)
			1'd0:
				if (request_fire)
					state_d = 1'd1;
			1'd1:
				if (response_fire)
					state_d = 1'd0;
			default: state_d = 1'd0;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		dmem_req_valid_o = 1'b0;
		dmem_req_o = request_i;
		dmem_rsp_ready_o = 1'b0;
		complete_o = 1'b0;
		response_o = dmem_rsp_i;
		ready_o = 1'b0;
		case (state_q)
			1'd0: begin
				dmem_req_valid_o = valid_i;
				ready_o = !valid_i || dmem_req_ready_i;
			end
			1'd1: begin
				dmem_rsp_ready_o = 1'b1;
				complete_o = response_fire;
				response_o = dmem_rsp_i;
				ready_o = 1'b0;
			end
			default: ready_o = 1'b0;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			state_q <= 1'd0;
		else
			state_q <= state_d;
	initial _sv2v_0 = 0;
endmodule
module rv32i_lsu (
	clk_i,
	rst_ni,
	valid_i,
	ready_o,
	memory_write_i,
	address_i,
	store_data_i,
	size_i,
	unsigned_load_i,
	complete_o,
	load_data_o,
	exception_o,
	dmem_req_valid_o,
	dmem_req_ready_i,
	dmem_req_o,
	dmem_rsp_valid_i,
	dmem_rsp_ready_o,
	dmem_rsp_i
);
	input wire clk_i;
	input wire rst_ni;
	input wire valid_i;
	output wire ready_o;
	input wire memory_write_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] address_i;
	input wire [31:0] store_data_i;
	input wire [1:0] size_i;
	input wire unsigned_load_i;
	output reg complete_o;
	output reg [31:0] load_data_o;
	output reg [70:0] exception_o;
	output wire dmem_req_valid_o;
	input wire dmem_req_ready_i;
	output wire [71:0] dmem_req_o;
	input wire dmem_rsp_valid_i;
	output wire dmem_rsp_ready_o;
	input wire [32:0] dmem_rsp_i;
	wire misaligned;
	wire [31:0] aligned_store_data;
	wire [3:0] aligned_write_strobe;
	reg [71:0] controller_request;
	wire controller_valid;
	wire controller_ready;
	wire controller_complete;
	wire [32:0] controller_response;
	wire aligned_request_fire;
	wire misaligned_complete;
	reg op_write_q;
	reg [31:0] op_address_q;
	reg [1:0] op_size_q;
	reg op_unsigned_load_q;
	wire [31:0] aligned_load_data;
	rv32i_misaligned_detect u_misaligned_detect(
		.address_i(address_i),
		.size_i(size_i),
		.misaligned_o(misaligned)
	);
	rv32i_store_aligner u_store_aligner(
		.address_i(address_i),
		.store_data_i(store_data_i),
		.size_i(size_i),
		.aligned_write_data_o(aligned_store_data),
		.write_strobe_o(aligned_write_strobe)
	);
	rv32i_load_aligner u_load_aligner(
		.address_i(op_address_q),
		.read_data_i(controller_response[32-:32]),
		.size_i(op_size_q),
		.unsigned_load_i(op_unsigned_load_q),
		.load_data_o(aligned_load_data)
	);
	always @(*) begin
		controller_request = 1'sb0;
		controller_request[71-:32] = address_i;
		controller_request[39] = memory_write_i;
		controller_request[2-:2] = size_i;
		controller_request[0] = unsigned_load_i;
		if (memory_write_i) begin
			controller_request[34-:32] = aligned_store_data;
			controller_request[38-:4] = aligned_write_strobe;
		end
		else begin
			controller_request[34-:32] = 1'sb0;
			controller_request[38-:4] = 4'b0000;
		end
	end
	assign controller_valid = valid_i && !misaligned;
	rv32i_memory_controller u_memory_controller(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.valid_i(controller_valid),
		.ready_o(controller_ready),
		.request_i(controller_request),
		.complete_o(controller_complete),
		.response_o(controller_response),
		.dmem_req_valid_o(dmem_req_valid_o),
		.dmem_req_ready_i(dmem_req_ready_i),
		.dmem_req_o(dmem_req_o),
		.dmem_rsp_valid_i(dmem_rsp_valid_i),
		.dmem_rsp_ready_o(dmem_rsp_ready_o),
		.dmem_rsp_i(dmem_rsp_i)
	);
	assign ready_o = (misaligned ? 1'b1 : controller_ready);
	assign aligned_request_fire = (valid_i && !misaligned) && ready_o;
	assign misaligned_complete = (valid_i && misaligned) && ready_o;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			op_write_q <= 1'b0;
			op_address_q <= 1'sb0;
			op_size_q <= 2'd0;
			op_unsigned_load_q <= 1'b0;
		end
		else if (aligned_request_fire) begin
			op_write_q <= memory_write_i;
			op_address_q <= address_i;
			op_size_q <= size_i;
			op_unsigned_load_q <= unsigned_load_i;
		end
	localparam [4:0] rv32i_csr_pkg_EXC_LOAD_ACCESS_FAULT = 5'd5;
	localparam [4:0] rv32i_csr_pkg_EXC_LOAD_ADDR_MISALIGNED = 5'd4;
	localparam [4:0] rv32i_csr_pkg_EXC_STORE_ACCESS_FAULT = 5'd7;
	localparam [4:0] rv32i_csr_pkg_EXC_STORE_ADDR_MISALIGNED = 5'd6;
	always @(*) begin
		complete_o = 1'b0;
		load_data_o = 1'sb0;
		exception_o = 1'sb0;
		if (misaligned_complete) begin
			complete_o = 1'b1;
			exception_o[70] = 1'b1;
			exception_o[31-:32] = address_i;
			if (memory_write_i)
				exception_o[68-:5] = rv32i_csr_pkg_EXC_STORE_ADDR_MISALIGNED;
			else
				exception_o[68-:5] = rv32i_csr_pkg_EXC_LOAD_ADDR_MISALIGNED;
		end
		else if (controller_complete) begin
			complete_o = 1'b1;
			if (controller_response[0]) begin
				exception_o[70] = 1'b1;
				exception_o[31-:32] = op_address_q;
				if (op_write_q)
					exception_o[68-:5] = rv32i_csr_pkg_EXC_STORE_ACCESS_FAULT;
				else
					exception_o[68-:5] = rv32i_csr_pkg_EXC_LOAD_ACCESS_FAULT;
			end
			else if (!op_write_q)
				load_data_o = aligned_load_data;
		end
	end
endmodule
module rv32i_hazard_unit (
	id_valid_i,
	id_rs1_index_i,
	id_rs2_index_i,
	id_use_rs1_i,
	id_use_rs2_i,
	ex_valid_i,
	ex_rd_index_i,
	ex_gpr_write_i,
	ex_memory_valid_i,
	ex_memory_write_i,
	mem_valid_i,
	mem_rd_index_i,
	mem_gpr_write_i,
	mem_memory_valid_i,
	mem_memory_write_i,
	load_use_stall_o
);
	input wire id_valid_i;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	input wire [4:0] id_rs1_index_i;
	input wire [4:0] id_rs2_index_i;
	input wire id_use_rs1_i;
	input wire id_use_rs2_i;
	input wire ex_valid_i;
	input wire [4:0] ex_rd_index_i;
	input wire ex_gpr_write_i;
	input wire ex_memory_valid_i;
	input wire ex_memory_write_i;
	input wire mem_valid_i;
	input wire [4:0] mem_rd_index_i;
	input wire mem_gpr_write_i;
	input wire mem_memory_valid_i;
	input wire mem_memory_write_i;
	output reg load_use_stall_o;
	reg ex_is_load;
	reg mem_is_load;
	reg rs1_depends_on_ex_load;
	reg rs2_depends_on_ex_load;
	reg rs1_depends_on_mem_load;
	reg rs2_depends_on_mem_load;
	localparam [4:0] rv32i_pkg_REG_X0 = 5'd0;
	always @(*) begin
		ex_is_load = (((ex_valid_i && ex_gpr_write_i) && ex_memory_valid_i) && !ex_memory_write_i) && (ex_rd_index_i != rv32i_pkg_REG_X0);
		mem_is_load = (((mem_valid_i && mem_gpr_write_i) && mem_memory_valid_i) && !mem_memory_write_i) && (mem_rd_index_i != rv32i_pkg_REG_X0);
		rs1_depends_on_ex_load = (id_use_rs1_i && (id_rs1_index_i == ex_rd_index_i)) && ex_is_load;
		rs2_depends_on_ex_load = (id_use_rs2_i && (id_rs2_index_i == ex_rd_index_i)) && ex_is_load;
		rs1_depends_on_mem_load = (id_use_rs1_i && (id_rs1_index_i == mem_rd_index_i)) && mem_is_load;
		rs2_depends_on_mem_load = (id_use_rs2_i && (id_rs2_index_i == mem_rd_index_i)) && mem_is_load;
		load_use_stall_o = id_valid_i && (((rs1_depends_on_ex_load || rs2_depends_on_ex_load) || rs1_depends_on_mem_load) || rs2_depends_on_mem_load);
	end
endmodule
module rv32i_forwarding_unit (
	ex_valid_i,
	ex_use_rs1_i,
	ex_rs1_index_i,
	ex_rs1_value_i,
	ex_use_rs2_i,
	ex_rs2_index_i,
	ex_rs2_value_i,
	mem_valid_i,
	mem_exception_valid_i,
	mem_gpr_write_i,
	mem_rd_index_i,
	mem_wb_sel_i,
	mem_alu_result_i,
	mem_pc_plus_4_i,
	wb_valid_i,
	wb_exception_valid_i,
	wb_gpr_write_i,
	wb_rd_index_i,
	wb_writeback_data_i,
	rs1_value_o,
	rs2_value_o,
	rs1_forwarded_o,
	rs2_forwarded_o
);
	input wire ex_valid_i;
	input wire ex_use_rs1_i;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	input wire [4:0] ex_rs1_index_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] ex_rs1_value_i;
	input wire ex_use_rs2_i;
	input wire [4:0] ex_rs2_index_i;
	input wire [31:0] ex_rs2_value_i;
	input wire mem_valid_i;
	input wire mem_exception_valid_i;
	input wire mem_gpr_write_i;
	input wire [4:0] mem_rd_index_i;
	input wire [2:0] mem_wb_sel_i;
	input wire [31:0] mem_alu_result_i;
	input wire [31:0] mem_pc_plus_4_i;
	input wire wb_valid_i;
	input wire wb_exception_valid_i;
	input wire wb_gpr_write_i;
	input wire [4:0] wb_rd_index_i;
	input wire [31:0] wb_writeback_data_i;
	output reg [31:0] rs1_value_o;
	output reg [31:0] rs2_value_o;
	output reg rs1_forwarded_o;
	output reg rs2_forwarded_o;
	reg mem_forward_allowed;
	reg wb_forward_allowed;
	reg [31:0] mem_forward_data;
	reg rs1_match_mem;
	reg rs2_match_mem;
	reg rs1_match_wb;
	reg rs2_match_wb;
	always @(*) begin
		mem_forward_data = 1'sb0;
		case (mem_wb_sel_i)
			3'd1, 3'd5: mem_forward_data = mem_alu_result_i;
			3'd3: mem_forward_data = mem_pc_plus_4_i;
			default: mem_forward_data = 1'sb0;
		endcase
	end
	localparam [4:0] rv32i_pkg_REG_X0 = 5'd0;
	always @(*) begin
		mem_forward_allowed = (((mem_valid_i && mem_gpr_write_i) && !mem_exception_valid_i) && (mem_rd_index_i != rv32i_pkg_REG_X0)) && (((mem_wb_sel_i == 3'd1) || (mem_wb_sel_i == 3'd5)) || (mem_wb_sel_i == 3'd3));
		wb_forward_allowed = ((wb_valid_i && wb_gpr_write_i) && !wb_exception_valid_i) && (wb_rd_index_i != rv32i_pkg_REG_X0);
		rs1_match_mem = ((ex_valid_i && ex_use_rs1_i) && mem_forward_allowed) && (ex_rs1_index_i == mem_rd_index_i);
		rs2_match_mem = ((ex_valid_i && ex_use_rs2_i) && mem_forward_allowed) && (ex_rs2_index_i == mem_rd_index_i);
		rs1_match_wb = ((ex_valid_i && ex_use_rs1_i) && wb_forward_allowed) && (ex_rs1_index_i == wb_rd_index_i);
		rs2_match_wb = ((ex_valid_i && ex_use_rs2_i) && wb_forward_allowed) && (ex_rs2_index_i == wb_rd_index_i);
		rs1_value_o = ex_rs1_value_i;
		rs2_value_o = ex_rs2_value_i;
		rs1_forwarded_o = 1'b0;
		rs2_forwarded_o = 1'b0;
		if (rs1_match_mem) begin
			rs1_value_o = mem_forward_data;
			rs1_forwarded_o = 1'b1;
		end
		else if (rs1_match_wb) begin
			rs1_value_o = wb_writeback_data_i;
			rs1_forwarded_o = 1'b1;
		end
		if (rs2_match_mem) begin
			rs2_value_o = mem_forward_data;
			rs2_forwarded_o = 1'b1;
		end
		else if (rs2_match_wb) begin
			rs2_value_o = wb_writeback_data_i;
			rs2_forwarded_o = 1'b1;
		end
	end
endmodule
module rv32i_csr_file (
	clk_i,
	rst_ni,
	trap_valid_i,
	trap_exception_i,
	mret_valid_i,
	csr_read_valid_i,
	csr_read_address_i,
	csr_read_data_o,
	csr_read_illegal_o,
	csr_write_valid_i,
	csr_write_address_i,
	csr_write_funct3_i,
	csr_write_data_i,
	csr_write_illegal_o,
	mtvec_o,
	mepc_o,
	mcause_o,
	mtval_o,
	mstatus_o,
	mret_redirect_valid_o,
	mret_redirect_pc_o
);
	reg _sv2v_0;
	parameter [31:0] MTVEC_RESET = 32'h00000100;
	input wire clk_i;
	input wire rst_ni;
	input wire trap_valid_i;
	input wire [70:0] trap_exception_i;
	input wire mret_valid_i;
	input wire csr_read_valid_i;
	input wire [11:0] csr_read_address_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	output reg [31:0] csr_read_data_o;
	output reg csr_read_illegal_o;
	input wire csr_write_valid_i;
	input wire [11:0] csr_write_address_i;
	input wire [2:0] csr_write_funct3_i;
	input wire [31:0] csr_write_data_i;
	output reg csr_write_illegal_o;
	output wire [31:0] mtvec_o;
	output wire [31:0] mepc_o;
	output wire [31:0] mcause_o;
	output wire [31:0] mtval_o;
	output wire [31:0] mstatus_o;
	output wire mret_redirect_valid_o;
	output wire [31:0] mret_redirect_pc_o;
	localparam [11:0] CSR_ADDR_MSTATUS = 12'h300;
	localparam [11:0] CSR_ADDR_MTVEC = 12'h305;
	localparam [11:0] CSR_ADDR_MEPC = 12'h341;
	localparam [11:0] CSR_ADDR_MCAUSE = 12'h342;
	localparam [11:0] CSR_ADDR_MTVAL = 12'h343;
	localparam [2:0] CSR_FUNCT3_CSRRW = 3'b001;
	localparam [2:0] CSR_FUNCT3_CSRRS = 3'b010;
	localparam [2:0] CSR_FUNCT3_CSRRC = 3'b011;
	localparam [2:0] CSR_FUNCT3_CSRRWI = 3'b101;
	localparam [2:0] CSR_FUNCT3_CSRRSI = 3'b110;
	localparam [2:0] CSR_FUNCT3_CSRRCI = 3'b111;
	reg [31:0] mtvec_q;
	reg [31:0] mepc_q;
	reg [31:0] mcause_q;
	reg [31:0] mtval_q;
	reg [31:0] mstatus_q;
	reg [31:0] csr_write_old_value;
	reg [31:0] csr_write_next_value;
	reg csr_write_enable_effective;
	assign mtvec_o = mtvec_q;
	assign mepc_o = mepc_q;
	assign mcause_o = mcause_q;
	assign mtval_o = mtval_q;
	assign mstatus_o = mstatus_q;
	assign mret_redirect_valid_o = mret_valid_i;
	assign mret_redirect_pc_o = mepc_q;
	function automatic csr_address_supported;
		input reg [11:0] address;
		case (address)
			CSR_ADDR_MSTATUS, CSR_ADDR_MTVEC, CSR_ADDR_MEPC, CSR_ADDR_MCAUSE, CSR_ADDR_MTVAL: csr_address_supported = 1'b1;
			default: csr_address_supported = 1'b0;
		endcase
	endfunction
	function automatic [31:0] csr_read_value;
		input reg [11:0] address;
		case (address)
			CSR_ADDR_MSTATUS: csr_read_value = mstatus_q;
			CSR_ADDR_MTVEC: csr_read_value = mtvec_q;
			CSR_ADDR_MEPC: csr_read_value = mepc_q;
			CSR_ADDR_MCAUSE: csr_read_value = mcause_q;
			CSR_ADDR_MTVAL: csr_read_value = mtval_q;
			default: csr_read_value = 1'sb0;
		endcase
	endfunction
	function automatic csr_funct3_supported;
		input reg [2:0] funct3;
		case (funct3)
			CSR_FUNCT3_CSRRW, CSR_FUNCT3_CSRRS, CSR_FUNCT3_CSRRC, CSR_FUNCT3_CSRRWI, CSR_FUNCT3_CSRRSI, CSR_FUNCT3_CSRRCI: csr_funct3_supported = 1'b1;
			default: csr_funct3_supported = 1'b0;
		endcase
	endfunction
	always @(*) begin
		csr_read_data_o = csr_read_value(csr_read_address_i);
		csr_read_illegal_o = csr_read_valid_i && !csr_address_supported(csr_read_address_i);
	end
	always @(*) begin
		csr_write_old_value = csr_read_value(csr_write_address_i);
		csr_write_next_value = csr_write_old_value;
		csr_write_enable_effective = 1'b0;
		csr_write_illegal_o = csr_write_valid_i && (!csr_address_supported(csr_write_address_i) || !csr_funct3_supported(csr_write_funct3_i));
		if (csr_write_valid_i && !csr_write_illegal_o)
			case (csr_write_funct3_i)
				CSR_FUNCT3_CSRRW, CSR_FUNCT3_CSRRWI: begin
					csr_write_next_value = csr_write_data_i;
					csr_write_enable_effective = 1'b1;
				end
				CSR_FUNCT3_CSRRS, CSR_FUNCT3_CSRRSI: begin
					csr_write_next_value = csr_write_old_value | csr_write_data_i;
					csr_write_enable_effective = csr_write_data_i != {32 {1'sb0}};
				end
				CSR_FUNCT3_CSRRC, CSR_FUNCT3_CSRRCI: begin
					csr_write_next_value = csr_write_old_value & ~csr_write_data_i;
					csr_write_enable_effective = csr_write_data_i != {32 {1'sb0}};
				end
				default: begin
					csr_write_next_value = csr_write_old_value;
					csr_write_enable_effective = 1'b0;
				end
			endcase
	end
	task automatic write_csr_value;
		input reg [11:0] address;
		input reg [31:0] value;
		case (address)
			CSR_ADDR_MSTATUS: mstatus_q <= value;
			CSR_ADDR_MTVEC: mtvec_q <= {value[31:2], 2'b00};
			CSR_ADDR_MEPC: mepc_q <= {value[31:2], 2'b00};
			CSR_ADDR_MCAUSE: mcause_q <= value;
			CSR_ADDR_MTVAL: mtval_q <= value;
			default:
				;
		endcase
	endtask
	localparam [31:0] rv32i_csr_pkg_MSTATUS_MIE_BIT = 3;
	localparam [31:0] rv32i_csr_pkg_MSTATUS_MPIE_BIT = 7;
	localparam [31:0] rv32i_csr_pkg_MSTATUS_MPP_LSB = 11;
	localparam [31:0] rv32i_csr_pkg_MSTATUS_MPP_MSB = 12;
	function automatic [31:0] sv2v_cast_4E913;
		input reg [31:0] inp;
		sv2v_cast_4E913 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			mtvec_q <= sv2v_cast_4E913(MTVEC_RESET);
			mepc_q <= 1'sb0;
			mcause_q <= 1'sb0;
			mtval_q <= 1'sb0;
			mstatus_q <= 1'sb0;
		end
		else if (trap_valid_i) begin
			mepc_q <= trap_exception_i[63-:32];
			mtval_q <= trap_exception_i[31-:32];
			mcause_q <= 1'sb0;
			mcause_q[31] <= trap_exception_i[69];
			mcause_q[4:0] <= trap_exception_i[68-:5];
			mstatus_q[rv32i_csr_pkg_MSTATUS_MPIE_BIT] <= mstatus_q[rv32i_csr_pkg_MSTATUS_MIE_BIT];
			mstatus_q[rv32i_csr_pkg_MSTATUS_MIE_BIT] <= 1'b0;
			mstatus_q[rv32i_csr_pkg_MSTATUS_MPP_MSB:rv32i_csr_pkg_MSTATUS_MPP_LSB] <= 2'b11;
		end
		else if (mret_valid_i) begin
			mstatus_q[rv32i_csr_pkg_MSTATUS_MIE_BIT] <= mstatus_q[rv32i_csr_pkg_MSTATUS_MPIE_BIT];
			mstatus_q[rv32i_csr_pkg_MSTATUS_MPIE_BIT] <= 1'b1;
			mstatus_q[rv32i_csr_pkg_MSTATUS_MPP_MSB:rv32i_csr_pkg_MSTATUS_MPP_LSB] <= 2'b11;
		end
		else if ((csr_write_valid_i && !csr_write_illegal_o) && csr_write_enable_effective)
			write_csr_value(csr_write_address_i, csr_write_next_value);
	initial _sv2v_0 = 0;
endmodule
module rv32i_trap_redirect (
	commit_valid_i,
	exception_i,
	trap_vector_i,
	trap_taken_o,
	trap_redirect_valid_o,
	trap_redirect_pc_o
);
	input wire commit_valid_i;
	input wire [70:0] exception_i;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	input wire [31:0] trap_vector_i;
	output reg trap_taken_o;
	output reg trap_redirect_valid_o;
	output reg [31:0] trap_redirect_pc_o;
	always @(*) begin
		trap_taken_o = commit_valid_i && exception_i[70];
		trap_redirect_valid_o = trap_taken_o;
		trap_redirect_pc_o = trap_vector_i;
	end
endmodule
module rv32i_if_id (
	clk_i,
	rst_ni,
	flush_i,
	kill_i,
	valid_i,
	ready_o,
	payload_i,
	valid_o,
	ready_i,
	payload_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire kill_i;
	input wire valid_i;
	output reg ready_o;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	input wire [147:0] payload_i;
	output wire valid_o;
	input wire ready_i;
	output wire [147:0] payload_o;
	reg valid_q;
	reg [147:0] payload_q;
	always @(*) begin
		if (_sv2v_0)
			;
		ready_o = !valid_q || ready_i;
	end
	assign valid_o = valid_q;
	assign payload_o = payload_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'b0;
		else if (flush_i || kill_i)
			valid_q <= 1'b0;
		else if (ready_o)
			valid_q <= valid_i;
	always @(posedge clk_i)
		if (ready_o && valid_i)
			payload_q <= payload_i;
	initial _sv2v_0 = 0;
endmodule
module rv32i_id_ex (
	clk_i,
	rst_ni,
	flush_i,
	kill_i,
	valid_i,
	ready_o,
	payload_i,
	valid_o,
	ready_i,
	payload_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire kill_i;
	input wire valid_i;
	output reg ready_o;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	input wire [378:0] payload_i;
	output wire valid_o;
	input wire ready_i;
	output wire [378:0] payload_o;
	reg valid_q;
	reg [378:0] payload_q;
	always @(*) begin
		if (_sv2v_0)
			;
		ready_o = !valid_q || ready_i;
	end
	assign valid_o = valid_q;
	assign payload_o = payload_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'b0;
		else if (flush_i || kill_i)
			valid_q <= 1'b0;
		else if (ready_o)
			valid_q <= valid_i;
	always @(posedge clk_i)
		if (ready_o && valid_i)
			payload_q <= payload_i;
	initial _sv2v_0 = 0;
endmodule
module rv32i_ex_mem (
	clk_i,
	rst_ni,
	flush_i,
	kill_i,
	valid_i,
	ready_o,
	payload_i,
	valid_o,
	ready_i,
	payload_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire kill_i;
	input wire valid_i;
	output reg ready_o;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	input wire [466:0] payload_i;
	output wire valid_o;
	input wire ready_i;
	output wire [466:0] payload_o;
	reg valid_q;
	reg [466:0] payload_q;
	always @(*) begin
		if (_sv2v_0)
			;
		ready_o = !valid_q || ready_i;
	end
	assign valid_o = valid_q;
	assign payload_o = payload_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'b0;
		else if (flush_i || kill_i)
			valid_q <= 1'b0;
		else if (ready_o) begin
			valid_q <= valid_i;
			if (valid_i)
				payload_q <= payload_i;
		end
	initial _sv2v_0 = 0;
endmodule
module rv32i_mem_wb (
	clk_i,
	rst_ni,
	flush_i,
	kill_i,
	valid_i,
	ready_o,
	payload_i,
	valid_o,
	ready_i,
	payload_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire flush_i;
	input wire kill_i;
	input wire valid_i;
	output reg ready_o;
	input wire [413:0] payload_i;
	output wire valid_o;
	input wire ready_i;
	output wire [413:0] payload_o;
	reg valid_q;
	reg [413:0] payload_q;
	always @(*) begin
		if (_sv2v_0)
			;
		ready_o = !valid_q || ready_i;
	end
	assign valid_o = valid_q;
	assign payload_o = payload_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'b0;
		else if (flush_i || kill_i)
			valid_q <= 1'b0;
		else if (ready_o) begin
			valid_q <= valid_i;
			if (valid_i)
				payload_q <= payload_i;
		end
	initial _sv2v_0 = 0;
endmodule
module rv32i_datapath (
	clk_i,
	rst_ni,
	imem_req_valid_o,
	imem_req_ready_i,
	imem_req_o,
	imem_rsp_valid_i,
	imem_rsp_ready_o,
	imem_rsp_i,
	dmem_req_valid_o,
	dmem_req_ready_i,
	dmem_req_o,
	dmem_rsp_valid_i,
	dmem_rsp_ready_o,
	dmem_rsp_i,
	commit_valid_o,
	commit_trap_o,
	commit_pc_o,
	commit_next_pc_o,
	commit_instruction_o,
	commit_rd_write_o,
	commit_rd_index_o,
	commit_rd_data_o,
	baseline_stall_o,
	debug_redirect_valid_o,
	debug_redirect_pc_o
);
	reg _sv2v_0;
	parameter [31:0] RESET_VECTOR = 32'h00000000;
	parameter [31:0] TRAP_VECTOR = 32'h00000100;
	input wire clk_i;
	input wire rst_ni;
	output wire imem_req_valid_o;
	input wire imem_req_ready_i;
	localparam [31:0] rv32i_types_pkg_FETCH_EPOCH_W = 4;
	output wire [35:0] imem_req_o;
	input wire imem_rsp_valid_i;
	output wire imem_rsp_ready_o;
	input wire [36:0] imem_rsp_i;
	output wire dmem_req_valid_o;
	input wire dmem_req_ready_i;
	output wire [71:0] dmem_req_o;
	input wire dmem_rsp_valid_i;
	output wire dmem_rsp_ready_o;
	input wire [32:0] dmem_rsp_i;
	output wire commit_valid_o;
	output wire commit_trap_o;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	output wire [31:0] commit_pc_o;
	output wire [31:0] commit_next_pc_o;
	localparam [31:0] rv32i_pkg_INSN_WIDTH = 32;
	output wire [31:0] commit_instruction_o;
	output wire commit_rd_write_o;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	output wire [4:0] commit_rd_index_o;
	output wire [31:0] commit_rd_data_o;
	output wire baseline_stall_o;
	output wire debug_redirect_valid_o;
	output wire [31:0] debug_redirect_pc_o;
	wire fetch_valid;
	wire fetch_ready;
	localparam [31:0] rv32i_types_pkg_GHR_WIDTH = 8;
	localparam [31:0] rv32i_types_pkg_PHT_INDEX_WIDTH = 8;
	wire [147:0] fetch_payload;
	wire if_id_valid;
	wire if_id_downstream_ready;
	wire [147:0] if_id_payload;
	wire [4:0] decoded_rs1_index;
	wire [4:0] decoded_rs2_index;
	wire [4:0] decoded_rd_index;
	wire [11:0] decoded_csr_address;
	wire [37:0] decoded_control;
	wire [31:0] decoded_immediate;
	wire [31:0] register_rs1_data;
	wire [31:0] register_rs2_data;
	reg [70:0] id_exception;
	reg [378:0] id_ex_payload_d;
	reg id_instruction_supported;
	wire id_load_use_stall;
	reg id_serialization_stall;
	wire serialization_pipeline_empty;
	wire serializing_id_detected;
	wire serializing_issue_fire;
	wire serializing_retire;
	localparam [1:0] SERIAL_NORMAL = 2'b00;
	localparam [1:0] SERIAL_DRAIN = 2'b01;
	localparam [1:0] SERIAL_ISSUE = 2'b10;
	localparam [1:0] SERIAL_BLOCK = 2'b11;
	reg [1:0] serialization_state_q;
	reg [1:0] serialization_state_d;
	wire id_ex_input_ready;
	wire id_ex_valid;
	wire [378:0] id_ex_payload;
	wire [31:0] ex_rs1_value_forwarded;
	wire [31:0] ex_rs2_value_forwarded;
	wire ex_rs1_forwarded;
	wire ex_rs2_forwarded;
	wire [31:0] alu_operand_a;
	wire [31:0] alu_operand_b;
	wire [31:0] alu_result_raw;
	reg [31:0] alu_result_final;
	wire branch_taken;
	wire [31:0] branch_target;
	wire branch_target_misaligned;
	reg branch_active;
	reg [31:0] actual_next_pc;
	reg branch_mispredict;
	wire branch_redirect;
	wire ex_fire;
	wire predictor_update_valid;
	wire [31:0] predictor_update_pc;
	wire predictor_update_taken;
	wire [31:0] predictor_update_target;
	wire [7:0] predictor_update_pht_index;
	reg [31:0] bpu_branch_count_q;
	reg [31:0] bpu_mispredict_count_q;
	reg [31:0] bpu_correct_count_q;
	reg [31:0] bpu_predicted_taken_count_q;
	reg [31:0] bpu_actual_taken_count_q;
	wire trap_taken;
	wire trap_redirect_valid;
	wire [31:0] trap_redirect_pc;
	wire mret_commit;
	wire mret_redirect_valid;
	wire [31:0] mret_redirect_pc;
	wire commit_redirect_valid;
	wire [31:0] csr_mtvec;
	wire [31:0] csr_mepc;
	wire [31:0] csr_mcause;
	wire [31:0] csr_mtval;
	wire [31:0] csr_mstatus;
	wire [31:0] csr_read_data;
	wire csr_read_illegal;
	wire csr_write_illegal;
	reg [31:0] ex_csr_write_operand;
	wire csr_commit_write_valid;
	wire frontend_redirect_valid;
	reg [31:0] frontend_redirect_pc;
	reg [70:0] ex_exception;
	reg [466:0] ex_mem_payload_d;
	wire ex_mem_valid;
	wire ex_mem_input_ready;
	wire [466:0] ex_mem_payload;
	reg [413:0] mem_wb_payload_d;
	wire mem_wb_valid;
	wire mem_wb_input_ready;
	wire [413:0] mem_wb_payload;
	wire [31:0] writeback_data;
	wire register_write_enable;
	wire mem_stage_is_memory;
	wire mem_stage_lsu_valid;
	reg mem_stage_complete;
	wire mem_stage_ready;
	wire lsu_ready;
	wire lsu_complete;
	wire [31:0] lsu_load_data;
	wire [70:0] lsu_exception;
	reg [70:0] mem_exception;
	assign mret_commit = (mem_wb_valid && !mem_wb_payload[70]) && (mem_wb_payload[76-:4] == 4'd3);
	assign csr_commit_write_valid = ((mem_wb_valid && mem_wb_payload[81]) && !mem_wb_payload[70]) && !commit_redirect_valid;
	rv32i_csr_file #(.MTVEC_RESET(TRAP_VECTOR)) u_csr_file(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.trap_valid_i(mem_wb_valid && mem_wb_payload[70]),
		.trap_exception_i(mem_wb_payload[70-:71]),
		.mret_valid_i(mret_commit),
		.csr_read_valid_i(ex_mem_valid && ex_mem_payload[164]),
		.csr_read_address_i(ex_mem_payload[235-:12]),
		.csr_read_data_o(csr_read_data),
		.csr_read_illegal_o(csr_read_illegal),
		.csr_write_valid_i(csr_commit_write_valid),
		.csr_write_address_i(mem_wb_payload[152-:12]),
		.csr_write_funct3_i(mem_wb_payload[364:362]),
		.csr_write_data_i(mem_wb_payload[140-:32]),
		.csr_write_illegal_o(csr_write_illegal),
		.mtvec_o(csr_mtvec),
		.mepc_o(csr_mepc),
		.mcause_o(csr_mcause),
		.mtval_o(csr_mtval),
		.mstatus_o(csr_mstatus),
		.mret_redirect_valid_o(mret_redirect_valid),
		.mret_redirect_pc_o(mret_redirect_pc)
	);
	rv32i_trap_redirect u_trap_redirect(
		.commit_valid_i(mem_wb_valid),
		.exception_i(mem_wb_payload[70-:71]),
		.trap_vector_i(csr_mtvec),
		.trap_taken_o(trap_taken),
		.trap_redirect_valid_o(trap_redirect_valid),
		.trap_redirect_pc_o(trap_redirect_pc)
	);
	assign commit_redirect_valid = trap_redirect_valid || mret_redirect_valid;
	assign frontend_redirect_valid = commit_redirect_valid || branch_redirect;
	always @(*) begin
		if (_sv2v_0)
			;
		if (trap_redirect_valid)
			frontend_redirect_pc = trap_redirect_pc;
		else if (mret_redirect_valid)
			frontend_redirect_pc = mret_redirect_pc;
		else
			frontend_redirect_pc = actual_next_pc;
	end
	rv32i_fetch_unit #(.RESET_VECTOR(RESET_VECTOR)) u_fetch_unit(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.redirect_valid_i(frontend_redirect_valid),
		.redirect_pc_i(frontend_redirect_pc),
		.predictor_update_valid_i(predictor_update_valid),
		.predictor_update_pc_i(predictor_update_pc),
		.predictor_update_taken_i(predictor_update_taken),
		.predictor_update_target_i(predictor_update_target),
		.predictor_update_pht_index_i(predictor_update_pht_index),
		.imem_req_valid_o(imem_req_valid_o),
		.imem_req_ready_i(imem_req_ready_i),
		.imem_req_o(imem_req_o),
		.imem_rsp_valid_i(imem_rsp_valid_i),
		.imem_rsp_ready_o(imem_rsp_ready_o),
		.imem_rsp_i(imem_rsp_i),
		.fetch_valid_o(fetch_valid),
		.fetch_ready_i(fetch_ready),
		.fetch_payload_o(fetch_payload)
	);
	rv32i_if_id u_if_id(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(frontend_redirect_valid),
		.kill_i(1'b0),
		.valid_i(fetch_valid),
		.ready_o(fetch_ready),
		.payload_i(fetch_payload),
		.valid_o(if_id_valid),
		.ready_i(if_id_downstream_ready),
		.payload_o(if_id_payload)
	);
	rv32i_decoder u_decoder(
		.instruction_i(if_id_payload[115-:32]),
		.rs1_index_o(decoded_rs1_index),
		.rs2_index_o(decoded_rs2_index),
		.rd_index_o(decoded_rd_index),
		.csr_address_o(decoded_csr_address),
		.control_o(decoded_control)
	);
	rv32i_imm_gen u_imm_gen(
		.instruction_i(if_id_payload[115-:32]),
		.imm_sel_i(decoded_control[29-:3]),
		.immediate_o(decoded_immediate)
	);
	rv32i_hazard_unit u_hazard_unit(
		.id_valid_i(if_id_valid),
		.id_rs1_index_i(decoded_rs1_index),
		.id_rs2_index_i(decoded_rs2_index),
		.id_use_rs1_i(decoded_control[37]),
		.id_use_rs2_i(decoded_control[36]),
		.ex_valid_i(id_ex_valid),
		.ex_rd_index_i(id_ex_payload[304-:5]),
		.ex_gpr_write_i(id_ex_payload[189]),
		.ex_memory_valid_i(id_ex_payload[169]),
		.ex_memory_write_i(id_ex_payload[168]),
		.mem_valid_i(ex_mem_valid),
		.mem_rd_index_i(ex_mem_payload[402-:5]),
		.mem_gpr_write_i(ex_mem_payload[189]),
		.mem_memory_valid_i(ex_mem_payload[169]),
		.mem_memory_write_i(ex_mem_payload[168]),
		.load_use_stall_o(id_load_use_stall)
	);
	assign serialization_pipeline_empty = (!id_ex_valid && !ex_mem_valid) && !mem_wb_valid;
	assign serializing_id_detected = (if_id_valid && id_instruction_supported) && decoded_control[1];
	assign serializing_issue_fire = (((serialization_state_q == SERIAL_ISSUE) && serializing_id_detected) && id_ex_input_ready) && !id_load_use_stall;
	assign serializing_retire = mem_wb_valid && mem_wb_payload[72];
	always @(*) begin
		if (_sv2v_0)
			;
		serialization_state_d = serialization_state_q;
		if (frontend_redirect_valid)
			serialization_state_d = SERIAL_NORMAL;
		else
			case (serialization_state_q)
				SERIAL_NORMAL:
					if (serializing_id_detected) begin
						if (serialization_pipeline_empty)
							serialization_state_d = SERIAL_ISSUE;
						else
							serialization_state_d = SERIAL_DRAIN;
					end
				SERIAL_DRAIN:
					if (serialization_pipeline_empty)
						serialization_state_d = SERIAL_ISSUE;
				SERIAL_ISSUE:
					if (serializing_issue_fire)
						serialization_state_d = SERIAL_BLOCK;
				SERIAL_BLOCK:
					if (serializing_retire)
						serialization_state_d = SERIAL_NORMAL;
				default: serialization_state_d = SERIAL_NORMAL;
			endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			serialization_state_q <= SERIAL_NORMAL;
		else
			serialization_state_q <= serialization_state_d;
	always @(*) begin
		if (_sv2v_0)
			;
		id_serialization_stall = 1'b0;
		case (serialization_state_q)
			SERIAL_NORMAL: id_serialization_stall = serializing_id_detected;
			SERIAL_DRAIN: id_serialization_stall = 1'b1;
			SERIAL_ISSUE: id_serialization_stall = !serializing_id_detected;
			SERIAL_BLOCK: id_serialization_stall = 1'b1;
			default: id_serialization_stall = 1'b1;
		endcase
	end
	assign writeback_data = mem_wb_payload[344-:32];
	localparam [4:0] rv32i_pkg_REG_X0 = 5'd0;
	assign register_write_enable = (((mem_wb_valid && mem_wb_payload[106]) && !mem_wb_payload[70]) && !commit_redirect_valid) && (mem_wb_payload[349-:5] != rv32i_pkg_REG_X0);
	rv32i_regfile u_regfile(
		.clk_i(clk_i),
		.rs1_index_i(decoded_rs1_index),
		.rs2_index_i(decoded_rs2_index),
		.rs1_data_o(register_rs1_data),
		.rs2_data_o(register_rs2_data),
		.write_enable_i(register_write_enable),
		.write_index_i(mem_wb_payload[349-:5]),
		.write_data_i(writeback_data)
	);
	localparam [4:0] rv32i_csr_pkg_EXC_BREAKPOINT = 5'd3;
	localparam [4:0] rv32i_csr_pkg_EXC_ECALL_FROM_M = 5'd11;
	localparam [4:0] rv32i_csr_pkg_EXC_ILLEGAL_INSTRUCTION = 5'd2;
	localparam [4:0] rv32i_csr_pkg_EXC_INSN_ACCESS_FAULT = 5'd1;
	always @(*) begin
		if (_sv2v_0)
			;
		id_exception = 1'sb0;
		id_exception[63-:32] = if_id_payload[147-:32];
		id_exception[31-:32] = 1'sb0;
		if (if_id_payload[0]) begin
			id_exception[70] = 1'b1;
			id_exception[69] = 1'b0;
			id_exception[68-:5] = rv32i_csr_pkg_EXC_INSN_ACCESS_FAULT;
			id_exception[31-:32] = if_id_payload[147-:32];
		end
		else if (decoded_control[0]) begin
			id_exception[70] = 1'b1;
			id_exception[69] = 1'b0;
			id_exception[68-:5] = rv32i_csr_pkg_EXC_ILLEGAL_INSTRUCTION;
			id_exception[31-:32] = if_id_payload[115-:32];
		end
		else if (decoded_control[5-:4] == 4'd1) begin
			id_exception[70] = 1'b1;
			id_exception[69] = 1'b0;
			id_exception[68-:5] = rv32i_csr_pkg_EXC_ECALL_FROM_M;
			id_exception[31-:32] = 1'sb0;
		end
		else if (decoded_control[5-:4] == 4'd2) begin
			id_exception[70] = 1'b1;
			id_exception[69] = 1'b0;
			id_exception[68-:5] = rv32i_csr_pkg_EXC_BREAKPOINT;
			id_exception[31-:32] = if_id_payload[147-:32];
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		id_ex_payload_d = 1'sb0;
		id_ex_payload_d[378-:32] = if_id_payload[147-:32];
		id_ex_payload_d[346-:32] = if_id_payload[115-:32];
		id_ex_payload_d[314-:5] = decoded_rs1_index;
		id_ex_payload_d[309-:5] = decoded_rs2_index;
		id_ex_payload_d[304-:5] = decoded_rd_index;
		if (decoded_control[37])
			id_ex_payload_d[299-:32] = register_rs1_data;
		else
			id_ex_payload_d[299-:32] = 1'sb0;
		if (decoded_control[36])
			id_ex_payload_d[267-:32] = register_rs2_data;
		else
			id_ex_payload_d[267-:32] = 1'sb0;
		id_ex_payload_d[235-:32] = decoded_immediate;
		id_ex_payload_d[203-:12] = decoded_csr_address;
		id_ex_payload_d[191-:38] = decoded_control;
		id_ex_payload_d[153-:83] = if_id_payload[83-:83];
		id_ex_payload_d[70-:71] = id_exception;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		id_instruction_supported = (((decoded_control[10] || (decoded_control[5-:4] == 4'd0)) || (decoded_control[5-:4] == 4'd1)) || (decoded_control[5-:4] == 4'd2)) || (decoded_control[5-:4] == 4'd3);
	end
	assign baseline_stall_o = if_id_valid && !id_instruction_supported;
	assign if_id_downstream_ready = ((id_ex_input_ready && id_instruction_supported) && !id_load_use_stall) && !id_serialization_stall;
	rv32i_id_ex u_id_ex(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(frontend_redirect_valid),
		.kill_i(1'b0),
		.valid_i(((if_id_valid && id_instruction_supported) && !id_load_use_stall) && !id_serialization_stall),
		.ready_o(id_ex_input_ready),
		.payload_i(id_ex_payload_d),
		.valid_o(id_ex_valid),
		.ready_i(ex_mem_input_ready),
		.payload_o(id_ex_payload)
	);
	always @(*)
		if (id_ex_payload[329])
			ex_csr_write_operand = {27'b000000000000000000000000000, id_ex_payload[334:330]};
		else
			ex_csr_write_operand = ex_rs1_value_forwarded;
	rv32i_forwarding_unit u_forwarding_unit(
		.ex_valid_i(id_ex_valid),
		.ex_use_rs1_i(id_ex_payload[191]),
		.ex_rs1_index_i(id_ex_payload[314-:5]),
		.ex_rs1_value_i(id_ex_payload[299-:32]),
		.ex_use_rs2_i(id_ex_payload[190]),
		.ex_rs2_index_i(id_ex_payload[309-:5]),
		.ex_rs2_value_i(id_ex_payload[267-:32]),
		.mem_valid_i(ex_mem_valid),
		.mem_exception_valid_i(ex_mem_payload[70]),
		.mem_gpr_write_i(ex_mem_payload[189]),
		.mem_rd_index_i(ex_mem_payload[402-:5]),
		.mem_wb_sel_i(ex_mem_payload[172-:3]),
		.mem_alu_result_i(ex_mem_payload[397-:32]),
		.mem_pc_plus_4_i(ex_mem_payload[333-:32]),
		.wb_valid_i(mem_wb_valid),
		.wb_exception_valid_i(mem_wb_payload[70]),
		.wb_gpr_write_i(mem_wb_payload[106]),
		.wb_rd_index_i(mem_wb_payload[349-:5]),
		.wb_writeback_data_i(writeback_data),
		.rs1_value_o(ex_rs1_value_forwarded),
		.rs2_value_o(ex_rs2_value_forwarded),
		.rs1_forwarded_o(ex_rs1_forwarded),
		.rs2_forwarded_o(ex_rs2_forwarded)
	);
	rv32i_operand_mux u_operand_mux(
		.rs1_value_i(ex_rs1_value_forwarded),
		.rs2_value_i(ex_rs2_value_forwarded),
		.pc_i(id_ex_payload[378-:32]),
		.immediate_i(id_ex_payload[235-:32]),
		.operand_a_sel_i(id_ex_payload[180-:2]),
		.operand_b_sel_i(id_ex_payload[178-:2]),
		.operand_a_o(alu_operand_a),
		.operand_b_o(alu_operand_b)
	);
	rv32i_alu u_alu(
		.operand_a_i(alu_operand_a),
		.operand_b_i(alu_operand_b),
		.alu_op_i(id_ex_payload[188-:5]),
		.result_o(alu_result_raw)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		if (id_ex_payload[172-:3] == 3'd5)
			alu_result_final = id_ex_payload[235-:32];
		else
			alu_result_final = alu_result_raw;
	end
	rv32i_branch_compare u_branch_compare(
		.operand_a_i(ex_rs1_value_forwarded),
		.operand_b_i(ex_rs2_value_forwarded),
		.branch_op_i(id_ex_payload[176-:4]),
		.branch_taken_o(branch_taken)
	);
	rv32i_target_generator u_target_generator(
		.pc_i(id_ex_payload[378-:32]),
		.rs1_value_i(ex_rs1_value_forwarded),
		.immediate_i(id_ex_payload[235-:32]),
		.branch_op_i(id_ex_payload[176-:4]),
		.target_o(branch_target),
		.target_misaligned_o(branch_target_misaligned)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		branch_active = id_ex_payload[176-:4] != 4'd0;
		if (branch_active && branch_taken)
			actual_next_pc = branch_target;
		else
			actual_next_pc = id_ex_payload[378-:32] + 32'd4;
		branch_mispredict = branch_active && (actual_next_pc != id_ex_payload[151-:32]);
	end
	localparam [4:0] rv32i_csr_pkg_EXC_INSN_ADDR_MISALIGNED = 5'd0;
	always @(*) begin
		if (_sv2v_0)
			;
		ex_exception = id_ex_payload[70-:71];
		if (((!ex_exception[70] && branch_active) && branch_taken) && branch_target_misaligned) begin
			ex_exception[70] = 1'b1;
			ex_exception[69] = 1'b0;
			ex_exception[68-:5] = rv32i_csr_pkg_EXC_INSN_ADDR_MISALIGNED;
			ex_exception[63-:32] = id_ex_payload[378-:32];
			ex_exception[31-:32] = branch_target;
		end
	end
	assign ex_fire = id_ex_valid && ex_mem_input_ready;
	assign branch_redirect = (ex_fire && branch_mispredict) && !ex_exception[70];
	assign predictor_update_valid = (((ex_mem_valid && mem_stage_ready) && (ex_mem_payload[176-:4] != 4'd0)) && !ex_mem_payload[70]) && !commit_redirect_valid;
	assign predictor_update_pc = ex_mem_payload[466-:32];
	assign predictor_update_taken = ex_mem_payload[301];
	assign predictor_update_target = ex_mem_payload[268-:32];
	assign predictor_update_pht_index = ex_mem_payload[119-:8];
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			bpu_branch_count_q <= 32'd0;
			bpu_mispredict_count_q <= 32'd0;
			bpu_correct_count_q <= 32'd0;
			bpu_predicted_taken_count_q <= 32'd0;
			bpu_actual_taken_count_q <= 32'd0;
		end
		else if (predictor_update_valid) begin
			bpu_branch_count_q <= bpu_branch_count_q + 32'd1;
			if (ex_mem_payload[236])
				bpu_mispredict_count_q <= bpu_mispredict_count_q + 32'd1;
			else
				bpu_correct_count_q <= bpu_correct_count_q + 32'd1;
			if (ex_mem_payload[152])
				bpu_predicted_taken_count_q <= bpu_predicted_taken_count_q + 32'd1;
			if (ex_mem_payload[301])
				bpu_actual_taken_count_q <= bpu_actual_taken_count_q + 32'd1;
		end
	assign debug_redirect_valid_o = frontend_redirect_valid;
	assign debug_redirect_pc_o = frontend_redirect_pc;
	always @(*) begin
		if (_sv2v_0)
			;
		ex_mem_payload_d = 1'sb0;
		ex_mem_payload_d[466-:32] = id_ex_payload[378-:32];
		ex_mem_payload_d[434-:32] = id_ex_payload[346-:32];
		ex_mem_payload_d[402-:5] = id_ex_payload[304-:5];
		ex_mem_payload_d[397-:32] = alu_result_final;
		ex_mem_payload_d[365-:32] = ex_rs2_value_forwarded;
		ex_mem_payload_d[333-:32] = id_ex_payload[378-:32] + 32'd4;
		ex_mem_payload_d[301] = branch_taken;
		ex_mem_payload_d[300-:32] = branch_target;
		ex_mem_payload_d[268-:32] = actual_next_pc;
		ex_mem_payload_d[236] = branch_mispredict;
		ex_mem_payload_d[235-:12] = id_ex_payload[203-:12];
		if (id_ex_payload[160])
			ex_mem_payload_d[223-:32] = id_ex_payload[235-:32];
		else
			ex_mem_payload_d[223-:32] = ex_csr_write_operand;
		ex_mem_payload_d[191-:38] = id_ex_payload[191-:38];
		ex_mem_payload_d[153-:83] = id_ex_payload[153-:83];
		ex_mem_payload_d[70-:71] = ex_exception;
	end
	rv32i_ex_mem u_ex_mem(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(commit_redirect_valid),
		.kill_i(1'b0),
		.valid_i(id_ex_valid),
		.ready_o(ex_mem_input_ready),
		.payload_i(ex_mem_payload_d),
		.valid_o(ex_mem_valid),
		.ready_i(mem_stage_ready),
		.payload_o(ex_mem_payload)
	);
	assign mem_stage_is_memory = ex_mem_valid && ex_mem_payload[169];
	assign mem_stage_lsu_valid = mem_stage_is_memory && !ex_mem_payload[70];
	rv32i_lsu u_lsu(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.valid_i(mem_stage_lsu_valid),
		.ready_o(lsu_ready),
		.memory_write_i(ex_mem_payload[168]),
		.address_i(ex_mem_payload[397-:32]),
		.store_data_i(ex_mem_payload[365-:32]),
		.size_i(ex_mem_payload[167-:2]),
		.unsigned_load_i(ex_mem_payload[165]),
		.complete_o(lsu_complete),
		.load_data_o(lsu_load_data),
		.exception_o(lsu_exception),
		.dmem_req_valid_o(dmem_req_valid_o),
		.dmem_req_ready_i(dmem_req_ready_i),
		.dmem_req_o(dmem_req_o),
		.dmem_rsp_valid_i(dmem_rsp_valid_i),
		.dmem_rsp_ready_o(dmem_rsp_ready_o),
		.dmem_rsp_i(dmem_rsp_i)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		mem_exception = ex_mem_payload[70-:71];
		if (!mem_exception[70]) begin
			if (lsu_exception[70]) begin
				mem_exception = lsu_exception;
				mem_exception[63-:32] = ex_mem_payload[466-:32];
			end
			else if (csr_read_illegal) begin
				mem_exception[70] = 1'b1;
				mem_exception[69] = 1'b0;
				mem_exception[68-:5] = rv32i_csr_pkg_EXC_ILLEGAL_INSTRUCTION;
				mem_exception[63-:32] = ex_mem_payload[466-:32];
				mem_exception[31-:32] = ex_mem_payload[434-:32];
			end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		mem_stage_complete = 1'b0;
		if (ex_mem_valid) begin
			if (ex_mem_payload[70])
				mem_stage_complete = 1'b1;
			else if (ex_mem_payload[169])
				mem_stage_complete = lsu_complete;
			else
				mem_stage_complete = 1'b1;
		end
	end
	assign mem_stage_ready = mem_wb_input_ready && mem_stage_complete;
	always @(*) begin
		if (_sv2v_0)
			;
		mem_wb_payload_d = 1'sb0;
		mem_wb_payload_d[413-:32] = ex_mem_payload[466-:32];
		mem_wb_payload_d[381-:32] = ex_mem_payload[434-:32];
		mem_wb_payload_d[349-:5] = ex_mem_payload[402-:5];
		case (ex_mem_payload[172-:3])
			3'd1, 3'd5: mem_wb_payload_d[344-:32] = ex_mem_payload[397-:32];
			3'd2: mem_wb_payload_d[344-:32] = lsu_load_data;
			3'd3: mem_wb_payload_d[344-:32] = ex_mem_payload[333-:32];
			3'd4: mem_wb_payload_d[344-:32] = csr_read_data;
			3'd0: mem_wb_payload_d[344-:32] = 1'sb0;
			default: mem_wb_payload_d[344-:32] = 1'sb0;
		endcase
		mem_wb_payload_d[312-:32] = ex_mem_payload[397-:32];
		mem_wb_payload_d[280-:32] = lsu_load_data;
		mem_wb_payload_d[248-:32] = ex_mem_payload[333-:32];
		mem_wb_payload_d[216-:32] = ex_mem_payload[268-:32];
		mem_wb_payload_d[152-:12] = ex_mem_payload[235-:12];
		mem_wb_payload_d[140-:32] = ex_mem_payload[223-:32];
		mem_wb_payload_d[184-:32] = csr_read_data;
		mem_wb_payload_d[108-:38] = ex_mem_payload[191-:38];
		mem_wb_payload_d[70-:71] = mem_exception;
	end
	wire unused_lsu_ready;
	assign unused_lsu_ready = lsu_ready;
	rv32i_mem_wb u_mem_wb(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.flush_i(1'b0),
		.kill_i(1'b0),
		.valid_i((ex_mem_valid && mem_stage_complete) && !commit_redirect_valid),
		.ready_o(mem_wb_input_ready),
		.payload_i(mem_wb_payload_d),
		.valid_o(mem_wb_valid),
		.ready_i(1'b1),
		.payload_o(mem_wb_payload)
	);
	assign commit_valid_o = mem_wb_valid;
	assign commit_trap_o = mem_wb_payload[70];
	assign commit_pc_o = mem_wb_payload[413-:32];
	assign commit_next_pc_o = mem_wb_payload[216-:32];
	assign commit_instruction_o = mem_wb_payload[381-:32];
	assign commit_rd_write_o = register_write_enable;
	assign commit_rd_index_o = mem_wb_payload[349-:5];
	assign commit_rd_data_o = writeback_data;
	initial _sv2v_0 = 0;
endmodule
module rv32i_core (
	clk_i,
	rst_ni,
	imem_req_valid_o,
	imem_req_ready_i,
	imem_req_o,
	imem_rsp_valid_i,
	imem_rsp_ready_o,
	imem_rsp_i,
	dmem_req_valid_o,
	dmem_req_ready_i,
	dmem_req_o,
	dmem_rsp_valid_i,
	dmem_rsp_ready_o,
	dmem_rsp_i,
	commit_valid_o,
	commit_trap_o,
	commit_pc_o,
	commit_next_pc_o,
	commit_instruction_o,
	commit_rd_write_o,
	commit_rd_index_o,
	commit_rd_data_o,
	baseline_stall_o,
	debug_redirect_valid_o,
	debug_redirect_pc_o
);
	parameter [31:0] RESET_VECTOR = 32'h00000000;
	parameter [31:0] TRAP_VECTOR = 32'h00000100;
	input wire clk_i;
	input wire rst_ni;
	output wire imem_req_valid_o;
	input wire imem_req_ready_i;
	localparam [31:0] rv32i_types_pkg_FETCH_EPOCH_W = 4;
	output wire [35:0] imem_req_o;
	input wire imem_rsp_valid_i;
	output wire imem_rsp_ready_o;
	input wire [36:0] imem_rsp_i;
	output wire dmem_req_valid_o;
	input wire dmem_req_ready_i;
	output wire [71:0] dmem_req_o;
	input wire dmem_rsp_valid_i;
	output wire dmem_rsp_ready_o;
	input wire [32:0] dmem_rsp_i;
	output wire commit_valid_o;
	output wire commit_trap_o;
	localparam [31:0] rv32i_pkg_XLEN = 32;
	output wire [31:0] commit_pc_o;
	output wire [31:0] commit_next_pc_o;
	localparam [31:0] rv32i_pkg_INSN_WIDTH = 32;
	output wire [31:0] commit_instruction_o;
	output wire commit_rd_write_o;
	localparam [31:0] rv32i_pkg_REG_COUNT = 32;
	localparam [31:0] rv32i_pkg_REG_ADDR_W = 5;
	output wire [4:0] commit_rd_index_o;
	output wire [31:0] commit_rd_data_o;
	output wire baseline_stall_o;
	output wire debug_redirect_valid_o;
	output wire [31:0] debug_redirect_pc_o;
	rv32i_datapath #(
		.RESET_VECTOR(RESET_VECTOR),
		.TRAP_VECTOR(TRAP_VECTOR)
	) u_datapath(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.imem_req_valid_o(imem_req_valid_o),
		.imem_req_ready_i(imem_req_ready_i),
		.imem_req_o(imem_req_o),
		.imem_rsp_valid_i(imem_rsp_valid_i),
		.imem_rsp_ready_o(imem_rsp_ready_o),
		.imem_rsp_i(imem_rsp_i),
		.dmem_req_valid_o(dmem_req_valid_o),
		.dmem_req_ready_i(dmem_req_ready_i),
		.dmem_req_o(dmem_req_o),
		.dmem_rsp_valid_i(dmem_rsp_valid_i),
		.dmem_rsp_ready_o(dmem_rsp_ready_o),
		.dmem_rsp_i(dmem_rsp_i),
		.commit_valid_o(commit_valid_o),
		.commit_trap_o(commit_trap_o),
		.commit_pc_o(commit_pc_o),
		.commit_next_pc_o(commit_next_pc_o),
		.commit_instruction_o(commit_instruction_o),
		.commit_rd_write_o(commit_rd_write_o),
		.commit_rd_index_o(commit_rd_index_o),
		.commit_rd_data_o(commit_rd_data_o),
		.baseline_stall_o(baseline_stall_o),
		.debug_redirect_valid_o(debug_redirect_valid_o),
		.debug_redirect_pc_o(debug_redirect_pc_o)
	);
endmodule