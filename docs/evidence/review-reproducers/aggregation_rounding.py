"""Reproduce a declared two-rounding numerical caveat, not an RTL contract failure."""
from pathlib import Path
import subprocess,sys

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'rtl/tests/tmp/post-fix-critical-review'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'rtl/.tools'))
import yowasp_yosys

sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
         'rtl/arithmetic/fixed_math_pkg.sv','rtl/arithmetic/arithmetic_register.sv',
         'rtl/arithmetic/reciprocal_unit.sv','rtl/control/aggregation_ctrl.sv',
         'docs/evidence/review-reproducers/aggregation_rounding.sv']
import os
os.chdir(ROOT)
sys.argv=['yosys','-Q','-T','-p',
          'read_slang -j 1 -DSYNTHESIS --top agg_tie_top '+' '.join(sources)+
          '; prep -top agg_tie_top -flatten; check -assert; '
          'write_json rtl/tests/tmp/post-fix-critical-review/aggregation.json']
code=yowasp_yosys.run_yosys(sys.argv[1:])
if code:raise SystemExit(code)
subprocess.run(['node','docs/evidence/review-reproducers/aggregation_rounding.cjs'],cwd=ROOT,check=True)
