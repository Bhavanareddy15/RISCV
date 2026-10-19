// Combinational immediate generator for RV32I.
// Extracts and sign-extends the immediate field based on the instruction format.

module imm_gen
  import riscv_pkg::*;
(
  input  logic      [31:0] instr_i,
  input  imm_type_e        imm_type_i,
  output logic      [31:0] imm_o
);

  always_comb begin
    unique case (imm_type_i)
      // Sign-extend instr[31:20]
      ImmI: imm_o = {{20{instr_i[31]}}, instr_i[31:20]};

      // Sign-extend {instr[31:25], instr[11:7]}
      ImmS: imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

      // Sign-extend {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
      ImmB: imm_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

      // {instr[31:12], 12'b0} — no sign extension, lower 12 bits are zero
      ImmU: imm_o = {instr_i[31:12], 12'b0};

      // Sign-extend {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
      ImmJ: imm_o = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

      default: imm_o = '0;
    endcase
  end

endmodule : imm_gen
