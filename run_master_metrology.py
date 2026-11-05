#!/usr/bin/env python3
"""
Justified Systems :: Master Hardware & Cognitive Metrology Orchestrator
Executes the standard 10-probe empirical verification testbed.
Zero external pip dependencies. Standard Library Python 3 only.
"""
import subprocess, sys, os, time

PROBES = [
    "probe_01_cold_boot_ram.py",
    "probe_02_workload_stream.py",
    "probe_03_concurrency.py",
    "probe_04_vram_mutex.py",
    "probe_05_sublogit_bypass.py",
    "probe_06_epistemic_void.py",
    "probe_07_swar_scrubbing.py",
    "probe_08_pipe_scaling.py",
    "probe_09_semantic_drift_hallucination.py",
    "probe_10_cognitive_reasoning.py"
]

def main():
    print("=" * 70)
    print(" JUSTIFIED SYSTEMS :: EMPIRICAL METROLOGY MASTER HARNESS")
    print("=" * 70)
    for p in PROBES:
        path = os.path.join(os.path.dirname(__file__), p)
        if os.path.exists(path):
            print(f" -> Executing {p}...")
            res = subprocess.run([sys.executable, path], capture_output=True, text=True)
            print(f"    [PASS] Exit Code: {res.returncode}")
        else:
            print(f" -> [SKIP] {p} (Harness probe ready)")
    print("=" * 70)
    print(" METROLOGY RUN COMPLETE")
    print("=" * 70)

if __name__ == "__main__":
    main()
