module pc_incrementer (
  input  logic [31:0] pc_i,
  output logic [31:0] pc_plus_4_o
);

  localparam logic [31:0] INSTRUCTION_SIZE_BYTES = 32'd4;

  assign pc_plus_4_o = pc_i + INSTRUCTION_SIZE_BYTES;

endmodule
