# RV32I Instruction Categories and Formats

RV32I is the 32-bit base integer instruction set of RISC-V. Its instructions use six encoding formats—R, I, S, B, U, and J—which determine how the instruction fields are arranged.

## R-Type — Register-Register Operations

Used for arithmetic and logical operations on two registers.

**Instructions:** `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`

**Format:** `[funct7 (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [rd (5)] | [opcode (7)]`

## I-Type — Immediate, Load, and Register-Indirect Jump Operations

Used for immediate arithmetic and logic, loads, and `jalr`.

**Instructions:** `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`, `lb`, `lh`, `lw`, `lbu`, `lhu`, `jalr`

**Format:** `[imm[11:0] (12)] | [rs1 (5)] | [funct3 (3)] | [rd (5)] | [opcode (7)]`

## S-Type — Store Operations

Used to store a register value to memory.

**Instructions:** `sb`, `sh`, `sw`

**Format:** `[imm[11:5] (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [imm[4:0] (5)] | [opcode (7)]`

## B-Type — Conditional Branch Operations

Used for conditional PC-relative branches.

**Instructions:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`

**Format:** `[imm[12|10:5] (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [imm[4:1|11] (5)] | [opcode (7)]`

## U-Type — Upper Immediate Operations

Used to work with an upper immediate value.

**Instructions:** `lui`, `auipc`

**Format:** `[imm[31:12] (20)] | [rd (5)] | [opcode (7)]`

## J-Type — Unconditional Jump Operation

Used for an unconditional PC-relative jump.

**Instruction:** `jal`

**Format:** `[imm[20|10:1|11|19:12] (20)] | [rd (5)] | [opcode (7)]`

---

## funct3 Encoding for Memory Instructions

`funct3` (bits [14:12] of the instruction) specifies the access width and, for loads, whether to sign- or zero-extend the result. These encodings are fixed by the RV32I spec.

### Loads (opcode `0000011`)

| `funct3` | Instruction | Access | Extension |
|----------|-------------|--------|-----------|
| `000` | `LB` | 1 byte | Sign-extend to 32 bits |
| `001` | `LH` | 2 bytes | Sign-extend to 32 bits |
| `010` | `LW` | 4 bytes | — |
| `100` | `LBU` | 1 byte | Zero-extend to 32 bits |
| `101` | `LHU` | 2 bytes | Zero-extend to 32 bits |

### Stores (opcode `0100011`)

| `funct3` | Instruction | Access |
|----------|-------------|--------|
| `000` | `SB` | 1 byte |
| `001` | `SH` | 2 bytes |
| `010` | `SW` | 4 bytes |

### Alignment Rules

The spec mandates **natural alignment**:

- `LH`/`SH` — address must be 2-byte aligned (`addr[0] = 0`)
- `LW`/`SW` — address must be 4-byte aligned (`addr[1:0] = 00`)

Unaligned accesses must either be handled in hardware or raise an exception. The base RV32I spec does not require hardware support for unaligned access.