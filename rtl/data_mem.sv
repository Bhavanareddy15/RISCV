// Byte-addressable data memory for RV32I.
// Writes are synchronous. Reads are combinational.
// Supports byte (LB/SB), halfword (LH/SH), and word (LW/SW) accesses.

module data_mem #(
  parameter  int unsigned DepthWords = 256,
  localparam int unsigned AddrWidth  = $clog2(DepthWords)
) (
  input  logic        clk_i,

  input  logic        wr_en_i,
  input  logic        rd_en_i,
  input  logic [2:0]  funct3_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] wr_data_i,
  output logic [31:0] rd_data_o
);

  logic [31:0] mem[DepthWords];

  logic [AddrWidth-1:0] word_addr;
  logic [31:0]          mem_word;
  logic [7:0]           byte_rd;
  logic [15:0]          half_rd;
  logic [3:0]           byte_en;

  assign word_addr = addr_i[AddrWidth+1:2];
  assign mem_word  = mem[word_addr];

  ///////////////////
  // Write control //
  ///////////////////

  // Byte write enable: which of the 4 byte lanes get written this cycle.
  always_comb begin
    unique case (funct3_i[1:0])
      2'b00: begin  // SB: one byte lane selected by addr[1:0]
        unique case (addr_i[1:0])
          2'b00: byte_en = 4'b0001;
          2'b01: byte_en = 4'b0010;
          2'b10: byte_en = 4'b0100;
          2'b11: byte_en = 4'b1000;
          default: byte_en = 4'b0000;
        endcase
      end
      2'b01:   byte_en = addr_i[1] ? 4'b1100 : 4'b0011;  // SH: two lanes
      2'b10:   byte_en = 4'b1111;                          // SW: all four lanes
      default: byte_en = 4'b0000;
    endcase
  end

  // Synchronous byte-granule write.
  always_ff @(posedge clk_i) begin
    for (int unsigned i = 0; i < 4; i++) begin
      if (wr_en_i && byte_en[i]) begin
        mem[word_addr][8*i +: 8] <= wr_data_i[8*i +: 8];
      end
    end
  end

  //////////////////
  // Read control //
  //////////////////

  // Extract the addressed byte from the 32-bit word.
  always_comb begin
    unique case (addr_i[1:0])
      2'b00: byte_rd = mem_word[7:0];
      2'b01: byte_rd = mem_word[15:8];
      2'b10: byte_rd = mem_word[23:16];
      2'b11: byte_rd = mem_word[31:24];
      default: byte_rd = '0;
    endcase
  end

  // Extract the addressed halfword from the 32-bit word.
  assign half_rd = addr_i[1] ? mem_word[31:16] : mem_word[15:0];

  // Combinational read with sign/zero extension.
  always_comb begin
    rd_data_o = '0;
    if (rd_en_i) begin
      unique case (funct3_i)
        3'h0: rd_data_o = {{24{byte_rd[7]}},  byte_rd};   // LB  — sign-extend
        3'h1: rd_data_o = {{16{half_rd[15]}}, half_rd};   // LH  — sign-extend
        3'h2: rd_data_o = mem_word;                        // LW
        3'h4: rd_data_o = {24'b0, byte_rd};                // LBU — zero-extend
        3'h5: rd_data_o = {16'b0, half_rd};                // LHU — zero-extend
        default: rd_data_o = '0;
      endcase
    end
  end

endmodule : data_mem
