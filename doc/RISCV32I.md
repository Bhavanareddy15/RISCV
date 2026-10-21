# RV32I Instruction Categories and Formats

RV32I is the 32-bit base integer instruction set of RISC-V. Its instructions use six encoding formats—R, I, S, B, U, and J—which determine how the instruction fields are arranged.

## R-Type — Register-Register Operations

Used for arithmetic and logical operations on two registers.

**Instructions:** `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`

**Format:** `[funct7 (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [rd (5)] | [opcode (7)]`

**Opcode:** `0110011`

| `funct3` | `funct7`  | Instruction | Operation                          |
|----------|-----------|-------------|------------------------------------|
| `000`    | `0000000` | `ADD`       | rd = rs1 + rs2                     |
| `000`    | `0100000` | `SUB`       | rd = rs1 − rs2                     |
| `001`    | `0000000` | `SLL`       | rd = rs1 << rs2[4:0]               |
| `010`    | `0000000` | `SLT`       | rd = (rs1 < rs2) signed ? 1 : 0    |
| `011`    | `0000000` | `SLTU`      | rd = (rs1 < rs2) unsigned ? 1 : 0  |
| `100`    | `0000000` | `XOR`       | rd = rs1 ^ rs2                     |
| `101`    | `0000000` | `SRL`       | rd = rs1 >> rs2[4:0] (logical)     |
| `101`    | `0100000` | `SRA`       | rd = rs1 >> rs2[4:0] (arithmetic)  |
| `110`    | `0000000` | `OR`        | rd = rs1 \| rs2                    |
| `111`    | `0000000` | `AND`       | rd = rs1 & rs2                     |

---

## I-Type — Immediate, Load, and Register-Indirect Jump Operations

Used for immediate arithmetic and logic, loads, and `jalr`.

**Instructions:** `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`, `lb`, `lh`, `lw`, `lbu`, `lhu`, `jalr`

**Format:** `[imm[11:0] (12)] | [rs1 (5)] | [funct3 (3)] | [rd (5)] | [opcode (7)]`

### Immediate Arithmetic/Logic (opcode `0010011`)

| `funct3` | imm[11:5]  | Instruction | Operation                             |
|----------|------------|-------------|---------------------------------------|
| `000`    | —          | `ADDI`      | rd = rs1 + sext(imm)                  |
| `010`    | —          | `SLTI`      | rd = (rs1 < sext(imm)) signed ? 1 : 0 |
| `011`    | —          | `SLTIU`     | rd = (rs1 < sext(imm)) unsigned ? 1 : 0 |
| `100`    | —          | `XORI`      | rd = rs1 ^ sext(imm)                  |
| `110`    | —          | `ORI`       | rd = rs1 \| sext(imm)                 |
| `111`    | —          | `ANDI`      | rd = rs1 & sext(imm)                  |
| `001`    | `0000000`  | `SLLI`      | rd = rs1 << imm[4:0]                  |
| `101`    | `0000000`  | `SRLI`      | rd = rs1 >> imm[4:0] (logical)        |
| `101`    | `0100000`  | `SRAI`      | rd = rs1 >> imm[4:0] (arithmetic)     |

> For `SLLI`/`SRLI`/`SRAI` the shift amount occupies `imm[4:0]`; `imm[11:5]` serves as an extended opcode discriminator (shown above).

### Loads (opcode `0000011`)

| `funct3` | Instruction | Access | Extension               |
|----------|-------------|--------|-------------------------|
| `000`    | `LB`        | 1 byte | Sign-extend to 32 bits  |
| `001`    | `LH`        | 2 bytes | Sign-extend to 32 bits |
| `010`    | `LW`        | 4 bytes | —                      |
| `100`    | `LBU`       | 1 byte | Zero-extend to 32 bits  |
| `101`    | `LHU`       | 2 bytes | Zero-extend to 32 bits |

### JALR (opcode `1100111`)

| `funct3` | Instruction | Operation                              |
|----------|-------------|----------------------------------------|
| `000`    | `JALR`      | rd = PC+4; PC = (rs1 + sext(imm)) & ~1 |

---

## S-Type — Store Operations

Used to store a register value to memory.

**Instructions:** `sb`, `sh`, `sw`

**Format:** `[imm[11:5] (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [imm[4:0] (5)] | [opcode (7)]`

**Opcode:** `0100011`

| `funct3` | Instruction | Access  |
|----------|-------------|---------|
| `000`    | `SB`        | 1 byte  |
| `001`    | `SH`        | 2 bytes |
| `010`    | `SW`        | 4 bytes |

---

## B-Type — Conditional Branch Operations

Used for conditional PC-relative branches.

**Instructions:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`

**Format:** `[imm[12|10:5] (7)] | [rs2 (5)] | [rs1 (5)] | [funct3 (3)] | [imm[4:1|11] (5)] | [opcode (7)]`

**Opcode:** `1100011`

| `funct3` | Instruction | Condition                     |
|----------|-------------|-------------------------------|
| `000`    | `BEQ`       | Branch if rs1 == rs2           |
| `001`    | `BNE`       | Branch if rs1 != rs2           |
| `100`    | `BLT`       | Branch if rs1 < rs2 (signed)   |
| `101`    | `BGE`       | Branch if rs1 >= rs2 (signed)  |
| `110`    | `BLTU`      | Branch if rs1 < rs2 (unsigned) |
| `111`    | `BGEU`      | Branch if rs1 >= rs2 (unsigned)|

---

## U-Type — Upper Immediate Operations

Used to work with an upper immediate value.

**Instructions:** `lui`, `auipc`

**Format:** `[imm[31:12] (20)] | [rd (5)] | [opcode (7)]`

U-type instructions have no `funct3` field.

| Opcode    | Instruction | Operation                    |
|-----------|-------------|------------------------------|
| `0110111` | `LUI`       | rd = imm << 12               |
| `0010111` | `AUIPC`     | rd = PC + (imm << 12)        |

---

## J-Type — Unconditional Jump Operation

Used for an unconditional PC-relative jump.

**Instruction:** `jal`

**Format:** `[imm[20|10:1|11|19:12] (20)] | [rd (5)] | [opcode (7)]`

J-type instructions have no `funct3` field.

| Opcode    | Instruction | Operation                    |
|-----------|-------------|------------------------------|
| `1101111` | `JAL`       | rd = PC+4; PC = PC + sext(imm) |

---

## Alignment Rules for Memory Instructions

The spec mandates **natural alignment**:

- `LH`/`SH` — address must be 2-byte aligned (`addr[0] = 0`)
- `LW`/`SW` — address must be 4-byte aligned (`addr[1:0] = 00`)

Unaligned accesses must either be handled in hardware or raise an exception. The base RV32I spec does not require hardware support for unaligned access.
