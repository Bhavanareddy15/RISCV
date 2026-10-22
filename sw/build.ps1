# Build a RISC-V assembly test and produce instr_mem.hex for $readmemh
# Usage: .\build.ps1 test_basic

param([string]$Name = "test_basic")

# Ensure the toolchain is on the PATH for this session
$toolbin = "C:\riscv-toolchain\xpack-riscv-none-elf-gcc-15.2.0-1\bin"
if ($env:PATH -notlike "*$toolbin*") { $env:PATH = "$env:PATH;$toolbin" }

$AS  = "riscv-none-elf-as"
$LD  = "riscv-none-elf-ld"
$OCP = "riscv-none-elf-objcopy"
$ODP = "riscv-none-elf-objdump"

$src = "$Name.s"
$obj = "$Name.o"
$elf = "$Name.elf"
$hex = "$Name.hex"

Write-Host "Assembling $src ..."
& $AS -march=rv32i -mabi=ilp32 $src -o $obj
if (!$?) { exit 1 }

Write-Host "Linking ..."
& $LD -T link.ld $obj -o $elf
if (!$?) { exit 1 }

Write-Host "Generating Verilog hex ($hex) ..."
# --verilog-data-width=4  : 32-bit words for $readmemh on [31:0] memory
# --change-address -0x80000000 : normalise link base to 0 so $readmemh
#                                uses array indices starting at 0
& $OCP -O verilog --verilog-data-width=4 --change-address -0x80000000 $elf $hex
if (!$?) { exit 1 }

Write-Host "Disassembly:"
& $ODP -d $elf

# Copy hex to the location instr_mem.sv reads at simulation start
Copy-Item $hex ..\sw\instr_mem.hex -Force
Write-Host "Done - copied to ..\sw\instr_mem.hex"
