"""
run_spike.py
Runs Spike on a compiled ELF and produces a parsed commit log.

Spike commit log line format (with --log-commits):
  core   0: 3 0x80010000 (0x00500093) x1  0x00000005
  core   0: 3 0x80010004 (0x00300113) x2  0x00000003
  core   0: 3 0x80010008 (0x002081b3) x3  0x00000008
  core   0: 3 0x8001001c (0x00000073)              <- ECALL, no rd write

Spike also emits 5 MROM boot instructions at PC 0x1000 before jumping to
our program, and the program is linked at 0x80010000 (Spike DRAM base).

This script:
  1. Filters out the MROM boot sequence (PC < SPIKE_PROG_BASE)
  2. Normalises PCs to 0-based offsets (subtract first program PC) so
     they match the DUT which starts executing at PC=0x0
  3. Stops at ECALL or on any exception (trap_* line)

Each parsed entry is a dict:
  { pc, instr, rd (None if no write), rd_val (None if no write) }

Usage:
    python3 run_spike.py <elf> --outdir <dir>
"""
import argparse, subprocess, re, sys, json
from pathlib import Path

SPIKE = "spike"

# Spike's MROM boot ROM lives at 0x1000.  Our programs link at 0x80010000.
# Skip any committed instruction below this threshold.
SPIKE_PROG_BASE = 0x80000000

# matches commit lines: core   0: 3 0xPPPPPPPP (0xIIIIIIII) [xN  0xVVVVVVVV]
LINE_RE = re.compile(
    r"core\s+\d+:\s+\d+\s+"
    r"0x(?P<pc>[0-9a-fA-F]{8})\s+"
    r"\(0x(?P<instr>[0-9a-fA-F]{8})\)"
    r"(?:\s+x(?P<rd>\d+)\s+0x(?P<rd_val>[0-9a-fA-F]+))?"
)

# matches exception lines so we can stop before the trap handler runs
TRAP_RE = re.compile(r"core\s+\d+:\s+exception\s+trap_")

def run_spike(elf: Path, outdir: Path) -> list[dict]:
    outdir.mkdir(parents=True, exist_ok=True)
    raw_log = outdir / "spike_raw.log"

    print(f"[spike] running {elf.name} ...")
    # timeout 5: prevents hang when program has no exit mechanism
    # --isa=rv32i  : restrict to RV32I base
    # --log-commits: emit one line per committed instruction
    # -l           : full log (needed for --log-commits)
    result = subprocess.run(
        ["timeout", "5",
         SPIKE, "--isa=rv32i", "-l", "--log-commits",
         "--log", str(raw_log), str(elf)],
        capture_output=True, text=True
    )
    # Spike writes the commit log directly to raw_log via --log.
    # stderr/stdout only contains warnings — save separately for debugging.
    (outdir / "spike_stderr.log").write_text(result.stderr + result.stdout)
    if result.stderr.strip():
        print(f"[spike] warnings: {result.stderr.strip()[:200]}")

    entries = []

    for line in raw_log.read_text().splitlines():
        # Stop as soon as Spike reports a fault — don't include trap-handler commits
        if TRAP_RE.search(line):
            print(f"[spike] stopped at exception: {line.strip()}")
            break

        m = LINE_RE.search(line)
        if not m:
            continue

        pc = int(m.group("pc"), 16)

        # Skip Spike's MROM boot sequence (lives at 0x1000).
        # Our program starts at SPIKE_PROG_BASE (0x80000000), same as DUT reset vector.
        if pc < SPIKE_PROG_BASE:
            continue

        entry = {
            "pc":     pc,                          # raw PC — matches DUT log directly
            "instr":  int(m.group("instr"),  16),
            "rd":     int(m.group("rd"))      if m.group("rd")     else None,
            "rd_val": int(m.group("rd_val"), 16) if m.group("rd_val") else None,
        }
        entries.append(entry)

        # Stop at ECALL — same sentinel the DUT uses
        if entry["instr"] == 0x00000073:
            break

    parsed_log = outdir / "spike_parsed.json"
    parsed_log.write_text(json.dumps(entries, indent=2))
    print(f"[spike] {len(entries)} commits -> {parsed_log}")
    return entries

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("elf",    type=Path)
    p.add_argument("--outdir", type=Path, default=Path("out"))
    args = p.parse_args()
    run_spike(args.elf, args.outdir)
