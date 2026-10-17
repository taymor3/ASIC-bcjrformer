"""Freshly lower and exercise focused controller fault/reset regressions."""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
for mode in range(3):
    with (ROOT/f'rtl/tests/controller-fault-{mode}-build.log').open('w',encoding='utf-8') as log:
        subprocess.run([sys.executable,'rtl/tests/build_controller_fault_netlist.py',str(mode)],
            cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run(['node','rtl/tests/run_controller_fault_cycle.cjs'],cwd=ROOT,check=True)
