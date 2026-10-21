// Combinational read-only instruction memory.
// The PC is byte-addressed; the lower 2 bits are ignored (word-aligned access).
// HEX_FILE is loaded at sim start via $readmemh; path is relative to the
// working directory where the simulation binary is invoked.

module instr_mem #(
  parameter            DepthWords = 256,
  parameter string     HEX_FILE   = "sw/test_basic.hex"
) (
  input  logic [31:0] pc_i,
  output logic [31:0] instr_o
);

  localparam AddrWidth = $clog2(DepthWords);

  logic [31:0] mem[DepthWords];

  initial $readmemh(HEX_FILE, mem);

  assign instr_o = mem[pc_i[AddrWidth+1:2]];

endmodule : instr_mem
