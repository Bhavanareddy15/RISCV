// Shared types for the RV32I pipeline.

package riscv_pkg;

  // Immediate format selector for the immediate generator.
  typedef enum logic [2:0] {
    ImmI,
    ImmS,
    ImmB,
    ImmU,
    ImmJ
  } imm_type_e;

  // ALU operation selector.
  typedef enum logic [3:0] {
    AluAdd,
    AluSub,
    AluAnd,
    AluOr,
    AluXor,
    AluSll,
    AluSrl,
    AluSra,
    AluSlt,
    AluSltu
  } alu_op_e;

  // Write-back data source selector.
  typedef enum logic [1:0] {
    WbAlu,    // ALU result
    WbMem,    // data memory read data
    WbPcPlus4 // PC+4 link address (JAL/JALR)
  } wb_src_e;

  // ALU operand A source selector.
  typedef enum logic [1:0] {
    OpARegFile, // rs1 register value
    OpAPc,      // program counter (AUIPC, JAL)
    OpAZero     // zero (LUI: 0 + upper_imm = upper_imm)
  } op_a_src_e;

endpackage : riscv_pkg
