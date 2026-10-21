"""
run_regression.py
Full flow: riscv-dv → compile → Spike → simulate → compare

Usage:
    # Run one generated test
    python3 run_regression.py --test riscv_arithmetic_basic_test

    # Run a hand-written assembly file directly (skip riscv-dv)
    python3 run_regression.py --asm ../../sw/test_basic.s

    # Run N random iterations
    python3 run_regression.py --test riscv_arithmetic_basic_test --iterations 5
"""
import argparse, subprocess, sys, shutil, json
from pathlib import Path

SCRIPTS  = Path(__file__).parent
ROOT     = SCRIPTS.parents[1]          # RISCV/
SIM_DIR  = ROOT / "sim"
LOGS_DIR = ROOT / "verif" / "logs"

# Simulator command — iverilog two-step: compile then run
TB_SRC = [
    str(ROOT / "rtl" / "riscv_pkg.sv"),
    str(ROOT / "rtl" / "pc_incrementer.sv"),
    str(ROOT / "rtl" / "instr_mem.sv"),
    str(ROOT / "rtl" / "control_unit.sv"),
    str(ROOT / "rtl" / "imm_gen.sv"),
    str(ROOT / "rtl" / "reg_file.sv"),
    str(ROOT / "rtl" / "alu.sv"),
    str(ROOT / "rtl" / "data_mem.sv"),
    str(ROOT / "rtl" / "riscv_core.sv"),
    str(ROOT / "tb"  / "riscv_core_tb.sv"),
]

def wsl_path(win_path: Path) -> str:
    r = subprocess.run(["wsl", "wslpath", str(win_path)],
                       capture_output=True, text=True)
    return r.stdout.strip()

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        print(f"[ERROR] {' '.join(str(c) for c in cmd)}")
        print(r.stdout[-2000:] if r.stdout else "")
        print(r.stderr[-2000:] if r.stderr else "")
        sys.exit(1)
    return r

def compile_asm(src: Path, outdir: Path):
    """Compile .S -> .elf + instr_mem.hex via WSL GCC."""
    from compile_test import compile_test
    return compile_test(src, outdir)

def run_spike(elf: Path, outdir: Path) -> list[dict]:
    """Run Spike in WSL and return parsed commit log."""
    wsl_elf    = wsl_path(elf)
    wsl_out    = wsl_path(outdir)
    wsl_script = wsl_path(SCRIPTS / "run_spike.py")
    r = subprocess.run(
        ["wsl", "python3", wsl_script, wsl_elf, "--outdir", wsl_out],
        capture_output=True, text=True
    )
    print(r.stdout)
    if r.returncode != 0:
        print(f"[ERROR] Spike failed:\n{r.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads((outdir / "spike_parsed.json").read_text())

def run_simulation(test_name: str, hex_path: Path, outdir: Path):
    """Compile and run the iverilog testbench."""
    SIM_DIR.mkdir(exist_ok=True)
    shutil.copy(hex_path, SIM_DIR / "instr_mem.hex")

    sim_bin = outdir / "sim.vvp"
    print(f"[sim] compiling testbench ...")
    run(["iverilog", "-g2012", "-o", str(sim_bin)] + TB_SRC)

    print(f"[sim] running simulation ...")
    r = subprocess.run(["vvp", str(sim_bin)], capture_output=True, text=True,
                       cwd=str(ROOT))
    print(r.stdout)
    if r.returncode != 0:
        print(f"[sim] stderr: {r.stderr}", file=sys.stderr)

def compare(outdir: Path) -> bool:
    spike_log = outdir / "spike_parsed.json"
    dut_log   = LOGS_DIR / "dut.log"
    if not dut_log.exists():
        print(f"[compare] dut.log not found at {dut_log}", file=sys.stderr)
        return False
    # Copy dut.log into test outdir for archiving
    shutil.copy(dut_log, outdir / "dut.log")
    r = subprocess.run(
        [sys.executable, str(SCRIPTS / "compare_logs.py"),
         str(spike_log), str(outdir / "dut.log")]
    )
    return r.returncode == 0

def run_one(test_src: Path, label: str) -> bool:
    outdir = LOGS_DIR / label
    outdir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"  TEST: {label}")
    print(f"{'='*60}")

    elf, hexf = compile_asm(test_src, outdir)
    run_spike(elf, outdir)
    run_simulation(label, hexf, outdir)
    return compare(outdir)

def main():
    p = argparse.ArgumentParser()
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--test", help="riscv-dv test name")
    g.add_argument("--asm",  type=Path, help="Path to hand-written .S file")
    p.add_argument("--iterations", type=int, default=1,
                   help="Number of random tests to generate (--test only)")
    args = p.parse_args()

    results = []

    if args.asm:
        ok = run_one(args.asm.resolve(), args.asm.stem)
        results.append((args.asm.stem, ok))
    else:
        from gen_test import gen_test
        gen_outdir = LOGS_DIR / args.test / "gen"
        asm_files  = gen_test(args.test, gen_outdir, args.iterations)
        for i, asm in enumerate(asm_files):
            label = f"{args.test}_{i}"
            ok    = run_one(asm, label)
            results.append((label, ok))

    print(f"\n{'='*60}")
    print("  REGRESSION SUMMARY")
    print(f"{'='*60}")
    for name, ok in results:
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}]  {name}")
    passed = sum(1 for _, ok in results if ok)
    print(f"\n  {passed}/{len(results)} passed")
    sys.exit(0 if passed == len(results) else 1)

if __name__ == "__main__":
    main()
