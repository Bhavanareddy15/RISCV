"""
compile_test.py
Compiles a RISC-V assembly file to ELF, then extracts:
  - instr_mem.hex  (Verilog $readmemh format, 32-bit wide words)
  - test.elf       (for Spike)

Usage:
    python3 compile_test.py <test.s> --outdir <dir>
"""
import argparse, subprocess, sys, os
from pathlib import Path

AS      = "riscv64-unknown-elf-as"
LD      = "riscv64-unknown-elf-ld"
OBJCOPY = "riscv64-unknown-elf-objcopy"

LINK_SCRIPT = """\
SECTIONS {
    . = 0x00000000;
    .text : { *(.text) }
}
"""

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        print(f"ERROR: {' '.join(cmd)}\n{r.stderr}", file=sys.stderr)
        sys.exit(1)
    return r

def compile_test(src: Path, outdir: Path):
    outdir.mkdir(parents=True, exist_ok=True)
    name  = src.stem
    obj   = outdir / f"{name}.o"
    elf   = outdir / f"{name}.elf"
    hexf  = outdir / "instr_mem.hex"
    ldscr = outdir / "link.ld"

    ldscr.write_text(LINK_SCRIPT)

    print(f"[compile] assembling {src.name} ...")
    run([AS, "-march=rv32i", "-mabi=ilp32", str(src), "-o", str(obj)])

    print(f"[compile] linking ...")
    run([LD, "-T", str(ldscr), str(obj), "-o", str(elf)])

    print(f"[compile] generating {hexf.name} ...")
    run([OBJCOPY, "-O", "verilog", "--verilog-data-width=4", str(elf), str(hexf)])

    print(f"[compile] done -> {elf}, {hexf}")
    return elf, hexf

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("src",    type=Path)
    p.add_argument("--outdir", type=Path, default=Path("out"))
    args = p.parse_args()
    compile_test(args.src, args.outdir)
