# RV32I Core — Interface Specification

## Top-Level Port List

The core (`riscv_core`) is a self-contained single-cycle RV32I processor.
All memory (instruction ROM and data RAM) is instantiated **inside** the core,
so the external interface is deliberately minimal.

| Port     | Direction | Width | Description                                                  |
|----------|-----------|-------|--------------------------------------------------------------|
| `clk_i`  | Input     | 1     | System clock. All sequential elements sample on the rising edge. |
| `rst_ni` | Input     | 1     | Active-low synchronous reset. Drives the program counter to `0x00000000` and clears the register file on assertion. |

### Notes

- **Active-low reset** — the reset signal is asserted when `rst_ni = 0`.
  The core begins normal execution on the first rising clock edge after
  `rst_ni` is de-asserted (`rst_ni = 1`).
- **No external memory bus** — instruction memory (`instr_mem`) and data
  memory (`data_mem`) are both internal submodules. There are no address,
  data, or control signals brought to the top-level boundary.
- **No interrupt or stall signals** — the current implementation is a
  single-cycle design with no pipeline, hazard unit, or interrupt controller,
  so no additional handshake ports are required.

---

## Internal Submodule Summary

Although not visible at the top-level boundary, the following submodules make
up the datapath and control path wired inside `riscv_core`.

| Submodule       | Instance          | Role                                                    |
|-----------------|-------------------|---------------------------------------------------------|
| `pc_incrementer`| `u_pc_incrementer`| Computes PC+4 for the sequential next address.         |
| `instr_mem`     | `u_instr_mem`     | Instruction ROM — outputs the 32-bit instruction at the current PC. |
| `control_unit`  | `u_control_unit`  | Decodes the instruction and drives all datapath control signals. |
| `imm_gen`       | `u_imm_gen`       | Sign-extends the immediate field for each instruction format. |
| `reg_file`      | `u_reg_file`      | 32 × 32-bit general-purpose register file (x0 hardwired to 0). |
| `alu`           | `u_alu`           | Executes all arithmetic, logical, shift, and compare operations. |
| `data_mem`      | `u_data_mem`      | Data RAM — supports byte, half-word, and word accesses (LB/LH/LW/SB/SH/SW). |

---

## Submodule Definitions

---

### `pc_incrementer`

**What it does:** Pure combinational adder that adds 4 to the current PC, producing the default next instruction address for sequential (non-branch, non-jump) execution.

| Port          | Dir    | Width | Description                  |
|---------------|--------|-------|------------------------------|
| `pc_i`        | Input  | 32    | Current program counter value. |
| `pc_plus_4_o` | Output | 32    | `pc_i + 4` — address of the next sequential instruction. |

---

### `instr_mem`

**What it does:** Combinational read-only instruction memory (ROM). On every cycle it presents the 32-bit instruction stored at the word-aligned address given by the PC. Contents are loaded from `instr_mem.hex` at elaboration/simulation time. Depth is parameterisable (default 256 words = 1 KiB).

| Port      | Dir    | Width | Description                                                                 |
|-----------|--------|-------|-----------------------------------------------------------------------------|
| `pc_i`    | Input  | 32    | Byte address of the instruction to fetch. `pc_i[1:0]` are ignored (word-aligned). |
| `instr_o` | Output | 32    | 32-bit instruction word read from `mem[pc_i >> 2]`. |

---

### `control_unit`

**What it does:** Fully combinational decoder. Inspects the `opcode`, `funct3`, and `funct7[5]` fields of the incoming instruction and asserts the correct control signals to steer the datapath for every RV32I instruction class.

| Port          | Dir    | Width | Description                                                                 |
|---------------|--------|-------|-----------------------------------------------------------------------------|
| `instr_i`     | Input  | 32    | Full 32-bit instruction word from instruction memory.                        |
| `alu_op_o`    | Output | 4     | `alu_op_e` enum — selects the ALU operation (Add, Sub, And, Or, Xor, Sll, Srl, Sra, Slt, Sltu). |
| `op_a_src_o`  | Output | 2     | `op_a_src_e` enum — selects ALU operand A source: register file (`rs1`), PC, or zero. |
| `alu_src_b_o` | Output | 1     | `0` → ALU operand B is `rs2`; `1` → ALU operand B is the sign-extended immediate. |
| `imm_type_o`  | Output | 3     | `imm_type_e` enum — tells `imm_gen` which format to extract (I, S, B, U, J). |
| `reg_wr_en_o` | Output | 1     | Enable write to the register file destination register `rd`.                 |
| `mem_wr_en_o` | Output | 1     | Enable synchronous write to data memory (store instructions).                |
| `mem_rd_en_o` | Output | 1     | Enable combinational read from data memory (load instructions).              |
| `wb_src_o`    | Output | 2     | `wb_src_e` enum — selects write-back data: ALU result, memory read data, or PC+4. |
| `branch_o`    | Output | 1     | Asserted for B-type instructions; the core evaluates the branch condition separately. |
| `jump_o`      | Output | 1     | Asserted for JAL and JALR; forces the PC to the computed jump target.        |
| `jalr_o`      | Output | 1     | Asserted for JALR only; tells the core to clear bit 0 of the jump target.   |

---

### `imm_gen`

**What it does:** Combinational immediate extractor and sign-extender. Given the raw instruction word and the format selector from the control unit, it reconstructs the correct 32-bit sign-extended immediate for I, S, B, U, and J formats.

| Port         | Dir    | Width | Description                                                              |
|--------------|--------|-------|--------------------------------------------------------------------------|
| `instr_i`    | Input  | 32    | Full 32-bit instruction word.                                            |
| `imm_type_i` | Input  | 3     | `imm_type_e` enum from the control unit — selects the extraction format. |
| `imm_o`      | Output | 32    | Sign-extended 32-bit immediate value.                                    |

**Format mapping:**

| `imm_type_i` | Bits extracted from instruction           | Use           |
|--------------|-------------------------------------------|---------------|
| `ImmI`       | `instr[31:20]`                            | I-type ALU, loads, JALR |
| `ImmS`       | `instr[31:25]`, `instr[11:7]`             | Stores        |
| `ImmB`       | `instr[31]`, `instr[7]`, `instr[30:25]`, `instr[11:8]`, `0` | Branches |
| `ImmU`       | `instr[31:12]`, `12'b0`                   | LUI, AUIPC    |
| `ImmJ`       | `instr[31]`, `instr[19:12]`, `instr[20]`, `instr[30:21]`, `0` | JAL |

---

### `reg_file`

**What it does:** 32 × 32-bit integer register file with two asynchronous (combinational) read ports and one synchronous write port. Register `x0` is permanently zero: writes to address `0` are silently discarded, and reads from address `0` always return `0`. All registers reset to `0` on active-low reset.

| Port           | Dir    | Width | Description                                                   |
|----------------|--------|-------|---------------------------------------------------------------|
| `clk_i`        | Input  | 1     | System clock. Writes are captured on the rising edge.         |
| `rst_ni`       | Input  | 1     | Active-low reset. Clears all registers to `0` synchronously.  |
| `wr_en_i`      | Input  | 1     | Write enable. When asserted, `wr_data_i` is written to `wr_addr_i` on the next clock edge. |
| `wr_addr_i`    | Input  | 5     | Destination register address (0–31).                          |
| `wr_data_i`    | Input  | 32    | Data to write into the destination register.                  |
| `rd_addr_a_i`  | Input  | 5     | Read address for port A (maps to `rs1` in the instruction).   |
| `rd_data_a_o`  | Output | 32    | Combinational read data for port A.                           |
| `rd_addr_b_i`  | Input  | 5     | Read address for port B (maps to `rs2` in the instruction).   |
| `rd_data_b_o`  | Output | 32    | Combinational read data for port B.                           |

---

### `alu`

**What it does:** Fully combinational arithmetic-logic unit. Performs all integer operations required by RV32I based on the `alu_op_e` selector from the control unit. Also produces a `zero` flag used by the branch logic.

| Port       | Dir    | Width | Description                                                            |
|------------|--------|-------|------------------------------------------------------------------------|
| `op_a_i`   | Input  | 32    | First operand (from register file, PC, or zero depending on `op_a_src`). |
| `op_b_i`   | Input  | 32    | Second operand (register file `rs2` or sign-extended immediate).       |
| `alu_op_i` | Input  | 4     | `alu_op_e` enum — selects the operation to perform.                    |
| `result_o` | Output | 32    | Computed result.                                                       |
| `zero_o`   | Output | 1     | Asserted when `result_o == 0`; used by BEQ/BNE branch evaluation.     |

**Operation table:**

| `alu_op_i` | Operation                              |
|------------|----------------------------------------|
| `AluAdd`   | `op_a + op_b`                          |
| `AluSub`   | `op_a − op_b`                          |
| `AluAnd`   | `op_a & op_b`                          |
| `AluOr`    | `op_a \| op_b`                         |
| `AluXor`   | `op_a ^ op_b`                          |
| `AluSll`   | `op_a << op_b[4:0]`                    |
| `AluSrl`   | `op_a >> op_b[4:0]` (logical)          |
| `AluSra`   | `op_a >>> op_b[4:0]` (arithmetic)      |
| `AluSlt`   | `1` if `op_a < op_b` (signed), else `0`  |
| `AluSltu`  | `1` if `op_a < op_b` (unsigned), else `0` |

---

### `data_mem`

**What it does:** Byte-addressable data RAM with synchronous byte-granular writes and combinational reads. `funct3` from the instruction determines the access width (byte / halfword / word) and, for reads, whether to sign- or zero-extend the result into 32 bits. Depth is parameterisable (default 256 words = 1 KiB).

| Port        | Dir    | Width | Description                                                                    |
|-------------|--------|-------|--------------------------------------------------------------------------------|
| `clk_i`     | Input  | 1     | System clock. Writes are committed on the rising edge.                         |
| `wr_en_i`   | Input  | 1     | Write enable for store instructions (SB / SH / SW).                            |
| `rd_en_i`   | Input  | 1     | Read enable for load instructions (LB / LH / LW / LBU / LHU).                 |
| `funct3_i`  | Input  | 3     | Access-width and extension selector, taken directly from `instr[14:12]`.       |
| `addr_i`    | Input  | 32    | Byte address of the memory access (computed by the ALU as `rs1 + imm`).        |
| `wr_data_i` | Input  | 32    | Data to write; for SB/SH only the relevant byte(s) of the word are written.    |
| `rd_data_o` | Output | 32    | Sign- or zero-extended read data; `0` when `rd_en_i` is deasserted.            |

**`funct3` encoding used internally:**

| `funct3_i` | Store / Load | Access  | Read extension          |
|------------|--------------|---------|-------------------------|
| `3'h0`     | SB / LB      | 1 byte  | Sign-extend to 32 bits  |
| `3'h1`     | SH / LH      | 2 bytes | Sign-extend to 32 bits  |
| `3'h2`     | SW / LW      | 4 bytes | No extension            |
| `3'h4`     | — / LBU      | 1 byte  | Zero-extend to 32 bits  |
| `3'h5`     | — / LHU      | 2 bytes | Zero-extend to 32 bits  |
