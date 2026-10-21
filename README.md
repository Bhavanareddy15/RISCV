# RV32I Single-Cycle Processor

A single-cycle RISC-V base integer (RV32I) processor implemented in SystemVerilog.  
Simulated with **Verilator 5** and verified against **Spike** (RISC-V ISA reference simulator).

---

## Design Overview

The processor uses a **Harvard memory model** — separate instruction and data memories — and a **single-cycle execution model** where every instruction completes in one clock cycle.

The reset vector is `0x80000000`, matching Spike's DRAM base so that PC values in simulation logs can be compared directly.

### Datapath Block Diagram

```
                    ┌──────────────────────────────────────────────────────────┐
                    │                      riscv_core                          │
                    │                                                          │
  clk  ────────────▶│                                                          │
  rst_n ───────────▶│                                                          │
                    │                                                          │
                    │   ┌──────────┐    ┌─────────────┐                       │
                    │   │  PC Reg  │───▶│  instr_mem  │──┐                    │
                    │   │0x80000000│    │  (256 words)│  │ instr[31:0]        │
                    │   └────┬─────┘    └─────────────┘  │                    │
                    │        │                            ▼                    │
                    │   ┌────▼─────┐              ┌─────────────┐             │
                    │   │  pc+4    │              │ control_unit│             │
                    │   └────┬─────┘              │             │             │
                    │        │                    └──────┬──────┘             │
                    │        │  ┌─────────────┐         │ alu_op, wb_src,    │
                    │        │  │   imm_gen   │◀── instr│ reg_wr_en,         │
                    │        │  └──────┬──────┘         │ mem_wr_en, ...     │
                    │        │         │ imm             │                    │
                    │        │         │         ┌───────▼───────┐            │
                    │        │         │         │   reg_file    │            │
                    │        │         │         │   (32 × 32b)  │            │
                    │        │         │         └───┬───────┬───┘            │
                    │        │         │          rs1│    rs2│                │
                    │        │         │             ▼       │                │
                    │        │         │         ┌───────┐   │                │
                    │        │         └────────▶│  ALU  │   │                │
                    │        │                   └───┬───┘   │                │
                    │        │                  res  │       │                │
                    │        │                       ▼       ▼                │
                    │        │                   ┌───────────────┐            │
                    │        │                   │   data_mem    │            │
                    │        │                   │   (256 words) │            │
                    │        │                   └───────────────┘            │
                    │        │                                                 │
                    │   ┌────▼───────────────┐  (branch / jump / PC+4)       │
                    │   │   PC next mux      │◀──────────────────────────     │
                    │   └────────────────────┘                                │
                    └──────────────────────────────────────────────────────────┘
```

### Modules

| Module           | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `riscv_core`     | Top level — wires all submodules together                                   |
| `control_unit`   | Decodes opcode / funct3 / funct7 into control signals                       |
| `alu`            | Arithmetic and logic unit (ADD, SUB, AND, OR, XOR, shifts, SLT/SLTU)       |
| `reg_file`       | 32 × 32-bit integer register file; x0 hardwired to zero                     |
| `instr_mem`      | Combinational read-only instruction memory; loaded from hex at sim start    |
| `data_mem`       | Synchronous data memory with byte/halfword/word access                      |
| `imm_gen`        | Sign-extends immediates for I / S / B / U / J formats                      |
| `pc_incrementer` | Computes PC + 4                                                             |

### Supported Instructions

All RV32I base integer instructions:

- **R-type** — ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **I-type** — ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU, LW, LH, LB, LHU, LBU, JALR
- **S-type** — SW, SH, SB
- **B-type** — BEQ, BNE, BLT, BGE, BLTU, BGEU
- **U-type** — LUI, AUIPC
- **J-type** — JAL
- **System** — ECALL (used as halt sentinel)

---

## Verification

The verification strategy compares the DUT's execution trace against **Spike**, the official RISC-V ISA simulator, instruction by instruction. Both sides produce a **commit log** — one line per retired instruction recording PC, encoding, destination register, and written value.

Currently the test programs are **directed** (hand-written assembly). The planned next step is to integrate **riscv-dv** as a constrained-random front end — it auto-generates thousands of legal RV32I programs which feed into the same GCC → Spike → DUT → compare pipeline below.

### Verification Flow

```
  [riscv-dv]  ← planned: auto-generates random RV32I programs
       │
       ▼  (currently: hand-written)
  sw/test_basic.s
        │
        │  riscv-none-elf-as + ld  (links at 0x80000000)
        ▼
  sw/test_basic.elf ──────────────────────────────────────▶ Spike (ISA sim)
        │                                                          │
        │  objcopy -O verilog                              --log-commits
        │  --change-address -0x80000000                           │
        ▼                                                          ▼
  sw/test_basic.hex                                  verif/logs/spike_parsed.json
  (@00000000 normalized)                             (golden commit log)
        │                                                          │
        │  $readmemh → instr_mem                                   │
        ▼                                                          │
  DUT (Verilator simulation)                                       │
        │                                                          │
        │  commit log                                              │
        ▼                                                          │
  verif/logs/dut.log ──────────────────────────────────────▶ compare_logs.py
                                                                   │
                                                                   ▼
                                                             PASS / FAIL
```

### Tools

| Tool                            | Role                                                           |
|---------------------------------|----------------------------------------------------------------|
| `riscv-none-elf-as` / `ld`      | Assembles and links test programs to ELF at `0x80000000`      |
| `riscv-none-elf-objcopy`        | Converts ELF → Verilog hex for `$readmemh`                    |
| **Spike** (`riscv-isa-sim`)     | Official RISC-V golden reference; generates expected results   |
| **Verilator 5**                 | Compiles RTL to a cycle-accurate C++ simulation                |
| `verif/scripts/run_spike.py`    | Runs Spike, parses `--log-commits` output to JSON             |
| `verif/scripts/compare_logs.py` | Diffs DUT log against Spike JSON line-by-line                  |

### Commit Log Format

Every retired instruction is logged as one line:

```
PC=0x80000000 INSTR=0x00500093 RD=x1 VAL=0x00000005
PC=0x80000004 INSTR=0x00300113 RD=x2 VAL=0x00000003
PC=0x80000008 INSTR=0x002081b3 RD=x3 VAL=0x00000008
```

Spike produces the same fields; `compare_logs.py` checks PC, instruction encoding, destination register, and written value for every committed instruction.

### Running a Test

```bash
# 1.  Compile the test program (PowerShell, from sw/)
.\build.ps1 test_basic

# 2.  Simulate the DUT (WSL, from project root)
verilator --sv --cc --exe --main --timing --top-module riscv_core_tb \
  --Mdir obj_dir rtl/*.sv tb/riscv_core_tb.sv
make -C obj_dir -f Vriscv_core_tb.mk
./obj_dir/Vriscv_core_tb          # writes verif/logs/dut.log

# 3.  Run Spike reference
python3 verif/scripts/run_spike.py sw/test_basic.elf --outdir verif/logs

# 4.  Compare DUT against golden
python3 verif/scripts/compare_logs.py verif/logs/spike_parsed.json verif/logs/dut.log
```

### Address Space Alignment

Both DUT and Spike execute instructions starting at `0x80000000`:

| | Spike | DUT |
|---|---|---|
| Reset / entry | MROM boot → jump to `0x80000000` | `pc_q <= 32'h8000_0000` |
| Memory index | DRAM at `0x80000000` | `mem[pc[9:2]]` → `mem[0]` |
| Hex base | `@00000000` (normalized by `--change-address`) | `$readmemh` → `mem[0]` |

---

## Directory Structure

```
RISCV/
├── rtl/            SystemVerilog source (synthesisable)
│   ├── riscv_pkg.sv
│   ├── riscv_core.sv
│   ├── control_unit.sv
│   ├── alu.sv
│   ├── reg_file.sv
│   ├── instr_mem.sv
│   ├── data_mem.sv
│   ├── imm_gen.sv
│   └── pc_incrementer.sv
├── tb/             Testbench (simulation only)
│   └── riscv_core_tb.sv
├── sw/             Test programs
│   ├── test_basic.s
│   ├── test_basic.elf
│   ├── test_basic.hex
│   ├── link.ld
│   └── build.ps1
├── verif/
│   ├── scripts/
│   │   ├── run_spike.py
│   │   ├── compare_logs.py
│   │   └── run_regression.py
│   └── logs/
│       ├── dut.log
│       ├── spike_parsed.json
│       └── spike_raw.log
└── obj_dir/        Verilator build output (generated)
```
