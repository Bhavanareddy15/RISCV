// Combinational ALU for RV32I.
// Performs arithmetic, logical, shift, and comparison operations.

module alu
  import riscv_pkg::*;
(
  input  logic    [31:0] op_a_i,
  input  logic    [31:0] op_b_i,
  input  alu_op_e        alu_op_i,
  output logic    [31:0] result_o,
  output logic           zero_o
);

  always_comb begin
    unique case (alu_op_i)
      AluAdd:  result_o = op_a_i + op_b_i;
      AluSub:  result_o = op_a_i - op_b_i;
      AluAnd:  result_o = op_a_i & op_b_i;
      AluOr:   result_o = op_a_i | op_b_i;
      AluXor:  result_o = op_a_i ^ op_b_i;
      AluSll:  result_o = op_a_i << op_b_i[4:0];
      AluSrl:  result_o = op_a_i >> op_b_i[4:0];
      AluSra:  result_o = 32'($signed(op_a_i) >>> op_b_i[4:0]);
      AluSlt:  result_o = {31'b0, ($signed(op_a_i) < $signed(op_b_i))};
      AluSltu: result_o = {31'b0, (op_a_i < op_b_i)};
      default: result_o = '0;
    endcase
  end

  assign zero_o = (result_o == '0);

endmodule : alu
