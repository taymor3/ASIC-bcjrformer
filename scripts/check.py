"""Run reproducible check groups; preserve tool stdout for evidence markers."""
from pathlib import Path
import argparse
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PY = sys.executable


def run(argv, log=None):
    print('+ ' + ' '.join(argv), flush=True)
    if log:
        target = ROOT / 'rtl/tests' / log
        with target.open('w', encoding='utf-8') as stream:
            result = subprocess.run(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        print(f'  log: {target.relative_to(ROOT)}', flush=True)
        if result.returncode:
            print(target.read_text(encoding='utf-8', errors='replace')[-10000:])
            raise SystemExit(result.returncode)
    else:
        subprocess.run(argv, cwd=ROOT, check=True)


def smoke():
    run([PY, 'scripts/check_publication.py'])
    run([PY, 'rtl/tests/compile_complete.py'])
    run([PY, 'rtl/tests/compile_protocol.py'])
    run(['node', 'rtl/architecture-connections.cjs'])
    run([PY, 'rtl/tests/fixed_reference.py'])
    run([PY, 'rtl/tests/verify_manifest.py'])


def numerics():
    run([PY, 'rtl/tests/verify_taylor_accuracy.py'], 'taylor-accuracy.log')


def full():
    smoke()
    numerics()
    run([PY, 'rtl/tests/run_conversion_formal.py'], 'conversion-formal.log')
    run([PY, 'rtl/tests/arithmetic_vectors.py'])
    run([PY, 'rtl/tests/build_arithmetic_netlist.py'], 'arithmetic-build.log')
    run(['node', 'rtl/tests/run_arithmetic_cycle.cjs'], 'arithmetic-cycle.log')
    for shape in ('single', 'multi', 'heads'):
        run([PY, 'rtl/tests/build_cycle_netlist.py', shape], f'core-{shape}-build.log')
        run(['node', 'rtl/tests/run_complete_cycle.cjs', shape], f'complete-{shape}-cycle.log')
    run(['node', 'rtl/tests/run_core_fault_cycle.cjs'], 'core-fault-cycle.log')
    run([PY, 'rtl/tests/run_formal.py', '5'], 'router-complete-regression.log')
    run([PY, 'rtl/tests/run_memory_formal.py', 'fast'], 'memory-complete-regression.log')
    run([PY, 'rtl/tests/summarize_complete.py'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('group', choices=('smoke', 'numerics', 'full'))
    args = parser.parse_args()
    {'smoke': smoke, 'numerics': numerics, 'full': full}[args.group]()
