"""Run actual-RTL LayerNorm checks; generated netlist/report files are ignored.

Usage: python rtl/tests/layernorm_regression.py
Results: tmp/layernorm-regression/results.json (exact outputs and float checks).
"""
from pathlib import Path
import subprocess
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'rtl/.tools'))
OUT = ROOT / 'tmp/layernorm-regression'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] in ('--build', '--invalid-epsilon'):
        import yowasp_yosys
        invalid = sys.argv[1] == '--invalid-epsilon'
        sources = [
            'rtl/interfaces/bcjrformer_contract_pkg.sv',
            'rtl/interfaces/bcjrformer_channels.sv',
            'rtl/arithmetic/fixed_math_pkg.sv',
            'rtl/arithmetic/arithmetic_register.sv',
            'rtl/arithmetic/rsqrt_unit.sv',
            'rtl/control/layernorm_ctrl.sv',
            'rtl/tests/layernorm_regression.sv',
        ]
        sys.argv = ['yosys', '-Q', '-T', '-p',
            'read_slang -j 1 -DSYNTHESIS --top layernorm_regression ' +
            ('-GEPSILON=42949 ' if invalid else '') + ' '.join(sources) +
            '; prep -top layernorm_regression -flatten; opt_clean; check -assert; '
            'write_json rtl/tests/layernorm-regression-netlist.json']
        return yowasp_yosys._run_yosys_argv()
    with (OUT / 'build.log').open('w') as log:
        subprocess.run([sys.executable, str(Path(__file__)), '--build'], cwd=ROOT,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    shutil.copyfile(ROOT / 'rtl/tests/layernorm-regression-netlist.json', OUT / 'netlist.json')
    with (OUT / 'invalid-epsilon.log').open('w') as log:
        rejected = subprocess.run([sys.executable, str(Path(__file__)), '--invalid-epsilon'],
                                  cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    if rejected.returncode == 0 or 'invalid LayerNorm epsilon' not in (OUT / 'invalid-epsilon.log').read_text():
        raise RuntimeError('LayerNorm must reject epsilon below the shared RSQRT minimum')
    subprocess.run(['node', 'rtl/tests/layernorm_regression.cjs'], cwd=ROOT, check=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
