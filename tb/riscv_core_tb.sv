// Functional verification testbench for riscv_core.
//
// Test program (hand-assembled RV32I):
//
//   Addr    Encoding    Assembly
//   0x00  0x00500093  addi x1, x0, 5       ; x1 = 5
//   0x04  0x00300113  addi x2, x0, 3       ; x2 = 3
//   0x08  0x002081B3  add  x3, x1, x2      ; x3 = 8
//   0x0C  0x40208233  sub  x4, x1, x2      ; x4 = 2
//   0x10  0x00302023  sw   x3, 0(x0)       ; mem[0] = 8
//   0x14  0x00002283  lw   x5, 0(x0)       ; x5 = 8
//   0x18  0x00518463  beq  x3, x5, +8      ; branch to 0x20 (x3 == x5)
//   0x1C  0x0FF00393  addi x7, x0, 255     ; FAIL — must be skipped by BEQ
//   0x20  0x0AA00313  addi x6, x0, 170     ; PASS marker  (x6 = 0xAA)
//   0x24  0x0000006F  jal  x0, 0           ; halt

module riscv_core_tb;

  localparam int CLK_HALF = 5;  // 10 ns period

  logic clk;
  logic rst_n;

  int pass_count;
  int fail_count;

  //-----------------------------------------------------------------------
  // DUT
  //-----------------------------------------------------------------------

  riscv_core u_riscv_core (
    .clk_i (clk),
    .rst_ni(rst_n)
  );

  //-----------------------------------------------------------------------
  // Clock
  //-----------------------------------------------------------------------

  initial clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  //-----------------------------------------------------------------------
  // Cycle-by-cycle trace (runs whenever reset is released)
  //-----------------------------------------------------------------------

  always @(posedge clk) begin
    if (rst_n) begin
      $display("  [%0t ns]  PC=0x%08h  instr=0x%08h",
               $time, u_riscv_core.pc_q, u_riscv_core.instr);
    end
  end

  //-----------------------------------------------------------------------
  // Tasks
  //-----------------------------------------------------------------------

  task load_program;
    u_riscv_core.u_instr_mem.mem[0] = 32'h00500093;
    u_riscv_core.u_instr_mem.mem[1] = 32'h00300113;
    u_riscv_core.u_instr_mem.mem[2] = 32'h002081B3;
    u_riscv_core.u_instr_mem.mem[3] = 32'h40208233;
    u_riscv_core.u_instr_mem.mem[4] = 32'h00302023;
    u_riscv_core.u_instr_mem.mem[5] = 32'h00002283;
    u_riscv_core.u_instr_mem.mem[6] = 32'h00518463;
    u_riscv_core.u_instr_mem.mem[7] = 32'h0FF00393;
    u_riscv_core.u_instr_mem.mem[8] = 32'h0AA00313;
    u_riscv_core.u_instr_mem.mem[9] = 32'h0000006F;
  endtask

  task automatic check_reg(
    input int          reg_num,
    input logic [31:0] expected
  );
    logic [31:0] actual;
    actual = u_riscv_core.u_reg_file.regs_q[reg_num];
    if (actual === expected) begin
      $display("  PASS  x%-2d = 0x%08h", reg_num, actual);
      pass_count++;
    end else begin
      $display("  FAIL  x%-2d = 0x%08h  (expected 0x%08h)",
               reg_num, actual, expected);
      fail_count++;
    end
  endtask

  task automatic check_dmem(
    input int          word_index,
    input logic [31:0] expected
  );
    logic [31:0] actual;
    actual = u_riscv_core.u_data_mem.mem[word_index];
    if (actual === expected) begin
      $display("  PASS  dmem[%0d] = 0x%08h", word_index, actual);
      pass_count++;
    end else begin
      $display("  FAIL  dmem[%0d] = 0x%08h  (expected 0x%08h)",
               word_index, actual, expected);
      fail_count++;
    end
  endtask

  //-----------------------------------------------------------------------
  // Stimulus and checking
  //-----------------------------------------------------------------------

  initial begin
    pass_count = 0;
    fail_count = 0;

    rst_n = 1'b0;

    // #1 lets any $readmemh in submodules finish before we write over it.
    #1;
    load_program();

    // Hold reset for 2 cycles then release on a falling edge.
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    // 20 cycles is more than enough for 10 instructions.
    repeat (20) @(posedge clk);

    // Results
    $display("");
    $display("=== Register File ===");
    check_reg(1, 32'd5);    // addi x1, x0, 5
    check_reg(2, 32'd3);    // addi x2, x0, 3
    check_reg(3, 32'd8);    // add  x3 = x1 + x2
    check_reg(4, 32'd2);    // sub  x4 = x1 - x2
    check_reg(5, 32'd8);    // lw   x5 = mem[0]
    check_reg(6, 32'h0AA);  // PASS: beq taken → addi x6 = 0xAA
    check_reg(7, 32'd0);    // FAIL skipped → x7 stays 0

    $display("=== Data Memory ===");
    check_dmem(0, 32'd8);   // sw x3, 0(x0)

    $display("====================");
    $display("  %0d passed,  %0d failed", pass_count, fail_count);
    $display("====================");

    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("TESTS FAILED");

    $finish;
  end

  // Uncomment to dump waveforms for GTKWave:
  // initial begin
  //   $dumpfile("riscv_core_tb.vcd");
  //   $dumpvars(0, riscv_core_tb);
  // end

endmodule
