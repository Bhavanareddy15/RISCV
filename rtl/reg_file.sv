//RISC-V RV32I integer register file with two read ports and one write port.
// Register x0 is hardwired to zero; writes to x0 are ignored.

module reg_file #(
  parameter  int unsigned DataWidth = 32,
  parameter  int unsigned NumRegs   = 32,
  localparam int unsigned AddrWidth = $clog2(NumRegs)
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // Write port
  input  logic                  wr_en_i,
  input  logic [AddrWidth-1:0]  wr_addr_i,
  input  logic [DataWidth-1:0]  wr_data_i,

  // Read port A (rs1)
  input  logic [AddrWidth-1:0]  rd_addr_a_i,
  output logic [DataWidth-1:0]  rd_data_a_o,

  // Read port B (rs2)
  input  logic [AddrWidth-1:0]  rd_addr_b_i,
  output logic [DataWidth-1:0]  rd_data_b_o
);

  logic [DataWidth-1:0] regs_q[NumRegs];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned i = 0; i < NumRegs; i++) begin
        regs_q[i] <= '0;
      end
    end else if (wr_en_i && (wr_addr_i != '0)) begin
      regs_q[wr_addr_i] <= wr_data_i;
    end
  end

  assign rd_data_a_o = (rd_addr_a_i == '0) ? '0 : regs_q[rd_addr_a_i];
  assign rd_data_b_o = (rd_addr_b_i == '0) ? '0 : regs_q[rd_addr_b_i];

endmodule : reg_file
