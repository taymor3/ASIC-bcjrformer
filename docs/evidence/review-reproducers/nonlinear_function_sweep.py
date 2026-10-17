"""Fresh actual-RTL sweep against mathematical functions; may take several minutes."""
from pathlib import Path
from math import erf,sqrt,exp
import json,subprocess,sys

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'rtl/tests/tmp/post-fix-critical-review'
OUT.mkdir(parents=True,exist_ok=True)
samples=sorted(set(range(-4096,1))|{-i*2048 for i in range(8193)}|
               {-(16<<20)-1,-(16<<20)+1})
values=[[4,x,x/1024*0.5*(1+erf(x/1024/sqrt(2)))] for x in range(-32768,32768)]
values += [[1,x,exp(x/(1<<20))] for x in samples]
(OUT/'function-golden.json').write_text(json.dumps(values,separators=(',',':')))
with (OUT/'arithmetic-build.log').open('w') as log:
    subprocess.run([sys.executable,'rtl/tests/build_arithmetic_netlist.py'],cwd=ROOT,
                   stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run(['node','docs/evidence/review-reproducers/nonlinear_function_sweep.cjs'],cwd=ROOT,check=True)
