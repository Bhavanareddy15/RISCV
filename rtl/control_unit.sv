// Combinational control unit for RV32I.
// Decodes a 32-bit instruction and drives all datapath control signals.

module control_unit
  import riscv_pkg::*;
(
  input  logic      [31:0] instr_i,

  output alu_op_e          alu_op_o,
  output op_a_src_e        op_a_src_o,
  output logic             alu_src_b_o,   // 0 = rs2, 1 = immediate
  output imm_type_e        imm_type_o,
  output logic             reg_wr_en_o,
  output logic             mem_wr_en_o,
  output logic             mem_rd_en_o,
  output wb_src_e          wb_src_o,
  output logic             branch_o,
  output logic             jump_o,
  output logic             jalr_o         // JALR clears bit 0 of jump target
);

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic       funct7_5;

  assign opcode   = instr_i[6:0];
  assign funct3   = instr_i[14:12];
  assign funct7_5 = instr_i[30];

  localparam logic [6:0] OP_R_TYPE = 7'b0110011;
  localparam logic [6:0] OP_I_ALU  = 7'b0010011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;

  always_comb begin
    // Safe defaults: no register or memory writes.
    alu_op_o    = AluAdd;
    op_a_src_o  = OpARegFile;
    alu_src_b_o = 1'b1;
    imm_type_o  = ImmI;
    reg_wr_en_o = 1'b0;
    mem_wr_en_o = 1'b0;
    mem_rd_en_o = 1'b0;
    wb_src_o    = WbAlu;
    branch_o    = 1'b0;
    jump_o      = 1'b0;
    jalr_o      = 1'b0;

    unique case (opcode)

      // R-type: rd = rs1 op rs2
      OP_R_TYPE: begin
        alu_src_b_o = 1'b0;
        reg_wr_en_o = 1'b1;
        unique case (funct3)
          3'h0: alu_op_o = funct7_5 ? AluSub : AluAdd;
          3'h1: alu_op_o = AluSll;
          3'h2: alu_op_o = AluSlt;
          3'h3: alu_op_o = AluSltu;
          3'h4: alu_op_o = AluXor;
          3'h5: alu_op_o = funct7_5 ? AluSra : AluSrl;
          3'h6: alu_op_o = AluOr;
          3'h7: alu_op_o = AluAnd;
          default: alu_op_o = AluAdd;
        endcase
      end

      // I-type arithmetic: rd = rs1 op imm
      OP_I_ALU: begin
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmI;
        reg_wr_en_o = 1'b1;
        unique case (funct3)
          3'h0: alu_op_o = AluAdd;                          // ADDI
          3'h1: alu_op_o = AluSll;                          // SLLI
          3'h2: alu_op_o = AluSlt;                          // SLTI
          3'h3: alu_op_o = AluSltu;                         // SLTIU
          3'h4: alu_op_o = AluXor;                          // XORI
          3'h5: alu_op_o = funct7_5 ? AluSra : AluSrl;     // SRAI / SRLI
          3'h6: alu_op_o = AluOr;                           // ORI
          3'h7: alu_op_o = AluAnd;                          // ANDI
          default: alu_op_o = AluAdd;
        endcase
      end

      // Load: rd = mem[rs1 + imm]
      OP_LOAD: begin
        alu_op_o    = AluAdd;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmI;
        reg_wr_en_o = 1'b1;
        mem_rd_en_o = 1'b1;
        wb_src_o    = WbMem;
      end

      // Store: mem[rs1 + imm] = rs2
      OP_STORE: begin
        alu_op_o    = AluAdd;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmS;
        mem_wr_en_o = 1'b1;
      end

      // Branch: if (rs1 op rs2) PC = PC + imm
      OP_BRANCH: begin
        alu_src_b_o = 1'b0;
        imm_type_o  = ImmB;
        branch_o    = 1'b1;
        unique case (funct3)
          3'h0, 3'h1: alu_op_o = AluSub;   // BEQ, BNE  — check zero_o
          3'h4, 3'h5: alu_op_o = AluSlt;   // BLT, BGE  — check result_o[0]
          3'h6, 3'h7: alu_op_o = AluSltu;  // BLTU, BGEU — check result_o[0]
          default:    alu_op_o = AluSub;
        endcase
      end

      // JAL: rd = PC+4; PC = PC + imm
      OP_JAL: begin
        op_a_src_o  = OpAPc;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmJ;
        reg_wr_en_o = 1'b1;
        wb_src_o    = WbPcPlus4;
        jump_o      = 1'b1;
      end

      // JALR: rd = PC+4; PC = (rs1 + imm) & ~1
      OP_JALR: begin
        alu_op_o    = AluAdd;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmI;
        reg_wr_en_o = 1'b1;
        wb_src_o    = WbPcPlus4;
        jump_o      = 1'b1;
        jalr_o      = 1'b1;
      end

      // LUI: rd = imm  (0 + upper_imm via OpAZero)
      OP_LUI: begin
        op_a_src_o  = OpAZero;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmU;
        reg_wr_en_o = 1'b1;
      end

      // AUIPC: rd = PC + imm
      OP_AUIPC: begin
        op_a_src_o  = OpAPc;
        alu_src_b_o = 1'b1;
        imm_type_o  = ImmU;
        reg_wr_en_o = 1'b1;
      end

      default: ;  // Undefined opcode: hold safe defaults, no side effects.

    endcase
  end

endmodule : control_unit
