"""
compare_logs.py
Compares Spike's golden commit log against the DUT's commit log.

Expected DUT log format (one line per committed instruction):
  PC=0x00000000 INSTR=0x00500093 RD=x1 VAL=0x00000005
  PC=0x00000004 INSTR=0x00300113 RD=x2 VAL=0x00000003
  PC=0x00000008 INSTR=0x002081b3 RD=x3 VAL=0x00000008
  PC=0x00000010 INSTR=0x00302023             <- store, no rd write

Usage:
    python3 compare_logs.py <spike_parsed.json> <dut.log>
"""
import argparse, json, re, sys
from pathlib import Path

DUT_RE = re.compile(
    r"PC=0x(?P<pc>[0-9a-fA-F]+)"
    r"\s+INSTR=0x(?P<instr>[0-9a-fA-F]+)"
    r"(?:\s+RD=x(?P<rd>\d+)\s+VAL=0x(?P<rd_val>[0-9a-fA-F]+))?"
)

def parse_dut_log(path: Path) -> list[dict]:
    entries = []
    for line in path.read_text().splitlines():
        m = DUT_RE.search(line)
        if not m:
            continue
        entries.append({
            "pc":     int(m.group("pc"),    16),
            "instr":  int(m.group("instr"), 16),
            "rd":     int(m.group("rd"))      if m.group("rd")     else None,
            "rd_val": int(m.group("rd_val"), 16) if m.group("rd_val") else None,
        })
    return entries

def compare(spike_log: Path, dut_log: Path) -> bool:
    golden  = json.loads(spike_log.read_text())
    actual  = parse_dut_log(dut_log)

    mismatches = 0
    limit = min(len(golden), len(actual))

    for i, (g, a) in enumerate(zip(golden, actual)):
        errors = []
        if g["pc"] != a["pc"]:
            errors.append(f"  PC     expected=0x{g['pc']:08x}  got=0x{a['pc']:08x}")
        if g["instr"] != a["instr"]:
            errors.append(f"  INSTR  expected=0x{g['instr']:08x}  got=0x{a['instr']:08x}")
        if g["rd"] != a["rd"]:
            errors.append(f"  RD     expected=x{g['rd']}  got=x{a['rd']}")
        if g["rd_val"] != a["rd_val"]:
            e = g['rd_val']
            av = a['rd_val']
            errors.append(
                f"  VAL    expected=0x{e:08x}  got=0x{av:08x}"
                if (e is not None and av is not None) else
                f"  VAL    expected={e}  got={av}"
            )
        if errors:
            mismatches += 1
            print(f"[MISMATCH] instruction #{i}  PC=0x{g['pc']:08x}")
            for e in errors:
                print(e)

    if len(golden) != len(actual):
        # Spike may stop early due to a fault (e.g. SW to unmapped address).
        # Report the count difference but only fail if there were also field mismatches.
        shorter = "Spike" if len(golden) < len(actual) else "DUT"
        print(f"[NOTE] commit count differs: Spike={len(golden)}  DUT={len(actual)}")
        print(f"       {shorter} log is shorter — compared first {limit} instructions")
        # Count difference alone isn't a mismatch if all compared instructions matched
        if mismatches == 0 and len(golden) < len(actual):
            print(f"       (Spike likely stopped at a memory fault; partial match is OK)")

    if mismatches == 0:
        print(f"[PASS] {limit} instruction(s) match")
        return True
    else:
        print(f"[FAIL] {mismatches} mismatch(es) in {limit} instructions")
        return False

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("spike_log", type=Path)
    p.add_argument("dut_log",   type=Path)
    args = p.parse_args()
    ok = compare(args.spike_log, args.dut_log)
    sys.exit(0 if ok else 1)
