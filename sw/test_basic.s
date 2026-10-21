# Basic RV32I test program
# Tests: ADDI, ADD, SUB, LUI, SW, LW, BEQ, ECALL
#
# Memory map strategy:
#   DUT reset vector = 0x80000000, so this program links at 0x80000000.
#   For SW/LW we need an address that is writable in Spike (DRAM >= 0x80000000)
#   and also maps to a valid slot in the DUT's 256-word data RAM.
#   LUI x8, 0x80001 gives x8 = 0x80001000.
#   In Spike: 0x80001000 is DRAM, well past our code (~44 bytes). Writable. OK.
#   In DUT:   addr[9:2] = 0x80001000[9:2] = 0 -> data_mem[0]. OK.

.section .text
.globl _start

_start:
    addi x1, x0, 5          # x1 = 5
    addi x2, x0, 3          # x2 = 3
    add  x3, x1, x2         # x3 = 8  (5 + 3)
    sub  x4, x1, x2         # x4 = 2  (5 - 3)
    lui  x8, 0x80001         # x8 = 0x80001000  (data address)
    sw   x3, 0(x8)           # mem[0x80001000] = 8  |  DUT: data_mem[0] = 8
    lw   x5, 0(x8)           # x5 = 8
    beq  x3, x5, skip        # if x3 == x5 (8 == 8), skip next instruction
    addi x7, x0, 255         # branch-not-taken path (should be skipped)
skip:
    addi x6, x0, 170         # x6 = 0xAA
halt:
    ecall                    # triggers Spike to exit; DUT detects 0x00000073
