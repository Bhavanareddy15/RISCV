// Functional verification testbench for riscv_core.
//
// Instructions are loaded from sw/test_basic.hex via $readmemh in instr_mem.
// See sw/test_basic.s for the program listing.

module riscv_core_tb;

  localparam int CLK_HALF = 5;  // 10 ns period

  logic clk;
  logic rst_n;

  int     pass_count;
  int     fail_count;
  integer log_fd;       // commit log file handle
  logic   halt_seen;    // stops logging once we reach the halt instruction

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
  // Commit log — one line per instruction, written to dut.log
  //
  // Format matches compare_logs.py:
  //   with rd write:  PC=0x....  INSTR=0x....  RD=xN  VAL=0x....
  //   without:        PC=0x....  INSTR=0x....
  //
  // In a single-cycle core every clock after reset is one commit.
  // Logging stops when the halt instruction (JAL x0, 0) is seen so
  // the log ends cleanly rather than repeating the halt forever.
  //-----------------------------------------------------------------------

  always @(posedge clk) begin
    if (rst_n && !halt_seen) begin
      if (u_riscv_core.reg_wr_en) begin
        $fwrite(log_fd, "PC=0x%08h INSTR=0x%08h RD=x%0d VAL=0x%08h\n",
                u_riscv_core.pc_q,
                u_riscv_core.instr,
                u_riscv_core.rd_addr,
                u_riscv_core.wb_data);
      end else begin
        $fwrite(log_fd, "PC=0x%08h INSTR=0x%08h\n",
                u_riscv_core.pc_q,
                u_riscv_core.instr);
      end
      $display("  [%0t ns]  PC=0x%08h  instr=0x%08h",
               $time, u_riscv_core.pc_q, u_riscv_core.instr);
      // ECALL (0x00000073) = halt sentinel, matches Spike's exit trigger
      if (u_riscv_core.instr == 32'h00000073) halt_seen = 1'b1;
    end
  end

  //-----------------------------------------------------------------------
  // Tasks
  //-----------------------------------------------------------------------

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
    halt_seen  = 1'b0;

    log_fd = $fopen("verif/logs/dut.log", "w");
    if (log_fd == 0) begin
      $display("ERROR: could not open verif/logs/dut.log");
      $display("       Run simulation from C:/Users/marpa/RISCV/");
      $finish;
    end

    rst_n = 1'b0;

    // Hold reset for 2 cycles then release on a falling edge.
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    // 25 cycles is more than enough for 11 instructions.
    repeat (25) @(posedge clk);

    // Results
    $display("");
    $display("=== Register File ===");
    check_reg(1, 32'd5);          // addi x1, x0, 5
    check_reg(2, 32'd3);          // addi x2, x0, 3
    check_reg(3, 32'd8);          // add  x3 = x1 + x2
    check_reg(4, 32'd2);          // sub  x4 = x1 - x2
    check_reg(8, 32'h80001000);   // lui  x8, 0x80001
    check_reg(5, 32'd8);          // lw   x5 = dmem[0] = 8
    check_reg(6, 32'h0AA);        // PASS: beq taken → addi x6 = 0xAA
    check_reg(7, 32'd0);          // FAIL skipped → x7 stays 0

    $display("=== Data Memory ===");
    check_dmem(0, 32'd8);   // sw x3, 0(x8)  addr=0x80001000 → dmem[addr[9:2]]=dmem[0]

    $display("====================");
    $display("  %0d passed,  %0d failed", pass_count, fail_count);
    $display("====================");

    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("TESTS FAILED");

    $fclose(log_fd);
    $display("Commit log written to verif/logs/dut.log");
    $finish;
  end

  // Uncomment to dump waveforms for GTKWave:
  // initial begin
  //   $dumpfile("riscv_core_tb.vcd");
  //   $dumpvars(0, riscv_core_tb);
  // end

endmodule
