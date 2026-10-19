// Combinational read-only instruction memory.
// The PC is byte-addressed; the lower 2 bits are ignored (word-aligned access).
// Memory contents are loaded from a hex file at simulation/elaboration time.

module instr_mem #(
  parameter  int unsigned DepthWords = 256,
  localparam int unsigned AddrWidth  = $clog2(DepthWords)
) (
  input  logic [31:0] pc_i,
  output logic [31:0] instr_o
);

  logic [31:0] mem[DepthWords];

  initial begin
    $readmemh("instr_mem.hex", mem);
  end

  assign instr_o = mem[pc_i[AddrWidth+1:2]];

endmodule : instr_mem
