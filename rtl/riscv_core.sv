// Single-cycle RV32I processor core.
// Instantiates and connects all datapath and control modules.

module riscv_core
  import riscv_pkg::*;
(
  input logic clk_i,
  input logic rst_ni
);

  ////////
  // PC //
  ////////

  logic [31:0] pc_q, pc_next, pc_plus4;
  logic [31:0] branch_target, jump_target;
  logic        branch_taken;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= 32'h8000_0000;
    end else begin
      pc_q <= pc_next;
    end
  end

  assign branch_target = pc_q + imm;
  assign jump_target   = jalr ? {alu_result[31:1], 1'b0} : alu_result;

  always_comb begin
    if (jump) begin
      pc_next = jump_target;
    end else if (branch && branch_taken) begin
      pc_next = branch_target;
    end else begin
      pc_next = pc_plus4;
    end
  end

  ///////////////////////
  // Instruction Fetch //
  ///////////////////////

  logic [31:0] instr;
  logic [4:0]  rs1_addr, rs2_addr, rd_addr;
  logic [2:0]  funct3;

  assign rs1_addr = instr[19:15];
  assign rs2_addr = instr[24:20];
  assign rd_addr  = instr[11:7];
  assign funct3   = instr[14:12];

  ///////////////
  // Datapath  //
  ///////////////

  logic [31:0] imm, op_a, op_b;
  logic [31:0] alu_result, mem_rd_data, wb_data;
  logic        zero;

  always_comb begin
    unique case (op_a_src)
      OpARegFile: op_a = rs1_data;
      OpAPc:      op_a = pc_q;
      OpAZero:    op_a = '0;
      default:    op_a = '0;
    endcase
  end

  assign op_b = alu_src_b ? imm : rs2_data;

  always_comb begin
    unique case (wb_src)
      WbAlu:     wb_data = alu_result;
      WbMem:     wb_data = mem_rd_data;
      WbPcPlus4: wb_data = pc_plus4;
      default:   wb_data = alu_result;
    endcase
  end

  // Branch condition evaluation
  always_comb begin
    unique case (funct3)
      3'h0: branch_taken = zero;              // BEQ
      3'h1: branch_taken = ~zero;             // BNE
      3'h4: branch_taken = alu_result[0];     // BLT  (SLT result)
      3'h5: branch_taken = ~alu_result[0];    // BGE
      3'h6: branch_taken = alu_result[0];     // BLTU (SLTU result)
      3'h7: branch_taken = ~alu_result[0];    // BGEU
      default: branch_taken = 1'b0;
    endcase
  end

  //////////////
  // Control  //
  //////////////

  alu_op_e   alu_op;
  op_a_src_e op_a_src;
  imm_type_e imm_type;
  wb_src_e   wb_src;
  logic      alu_src_b;
  logic      reg_wr_en, mem_wr_en, mem_rd_en;
  logic      branch, jump, jalr;

  logic [31:0] rs1_data, rs2_data;

  /////////////////////////////
  // Submodule Instantiation //
  /////////////////////////////

  pc_incrementer u_pc_incrementer (
    .pc_i       (pc_q),
    .pc_plus_4_o(pc_plus4)
  );

  instr_mem u_instr_mem (
    .pc_i   (pc_q),
    .instr_o(instr)
  );

  control_unit u_control_unit (
    .instr_i    (instr),
    .alu_op_o   (alu_op),
    .op_a_src_o (op_a_src),
    .alu_src_b_o(alu_src_b),
    .imm_type_o (imm_type),
    .reg_wr_en_o(reg_wr_en),
    .mem_wr_en_o(mem_wr_en),
    .mem_rd_en_o(mem_rd_en),
    .wb_src_o   (wb_src),
    .branch_o   (branch),
    .jump_o     (jump),
    .jalr_o     (jalr)
  );

  imm_gen u_imm_gen (
    .instr_i    (instr),
    .imm_type_i (imm_type),
    .imm_o      (imm)
  );

  reg_file u_reg_file (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .wr_en_i    (reg_wr_en),
    .wr_addr_i  (rd_addr),
    .wr_data_i  (wb_data),
    .rd_addr_a_i(rs1_addr),
    .rd_data_a_o(rs1_data),
    .rd_addr_b_i(rs2_addr),
    .rd_data_b_o(rs2_data)
  );

  alu u_alu (
    .op_a_i  (op_a),
    .op_b_i  (op_b),
    .alu_op_i(alu_op),
    .result_o(alu_result),
    .zero_o  (zero)
  );

  data_mem u_data_mem (
    .clk_i    (clk_i),
    .wr_en_i  (mem_wr_en),
    .rd_en_i  (mem_rd_en),
    .funct3_i (funct3),
    .addr_i   (alu_result),
    .wr_data_i(rs2_data),
    .rd_data_o(mem_rd_data)
  );

endmodule : riscv_core
