"""Reproduce/report the constant-vector LayerNorm observation in actual RTL.
Install requirements-dev.txt and Node.js first. Does not modify production RTL.
"""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[3]
if '--build' in sys.argv:
    sys.path.insert(0,str(ROOT/'rtl/.tools'))
    import yowasp_yosys
    sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
        'rtl/arithmetic/fixed_math_pkg.sv','rtl/arithmetic/arithmetic_register.sv',
        'rtl/arithmetic/rsqrt_unit.sv','rtl/control/layernorm_ctrl.sv',
        'docs/evidence/review-reproducers/layernorm_constant_top.sv']
    sys.argv=['yosys','-Q','-T','-p','read_slang -j 1 -DSYNTHESIS --top layernorm_review_top '+
        ' '.join(sources)+'; prep -top layernorm_review_top -flatten; opt_clean; check -assert; '+
        'write_json rtl/tests/review-layernorm-constant-netlist.json']
    raise SystemExit(yowasp_yosys._run_yosys_argv())
with (ROOT/'rtl/tests/review-layernorm-constant-build.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,str(Path(__file__).resolve()),'--build'],cwd=ROOT,
        stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run(['node',str(Path(__file__).with_suffix('.cjs'))],cwd=ROOT,check=True)
