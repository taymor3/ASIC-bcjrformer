"""Exhaustive independent nearest-even/clipping proofs for both linear paths."""
from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[2]
cases=((48,10),(64,22))
if len(sys.argv)==4 and sys.argv[1]=='--case':
    width,shift=map(int,sys.argv[2:])
    if (width,shift) not in cases:raise SystemExit('Unsupported conversion proof')
    sys.path.insert(0,str(root/'rtl/.tools'))
    import yowasp_yosys
    sys.argv=['yosys','-Q','-T','-p',
      f'read_slang -j 1 -DSYNTHESIS --top conversion_proof -GWIDTH={width} -GSHIFT={shift} '+
      'rtl/interfaces/bcjrformer_contract_pkg.sv rtl/arithmetic/fixed_math_pkg.sv '+
      'rtl/tests/conversion_proof.sv; prep -top conversion_proof -flatten; '+
      'wreduce; opt; sat -set-def-inputs -prove correct 1 -verify -timeout 60']
    raise SystemExit(yowasp_yosys._run_yosys_argv())
results=[]
for width,shift in cases:
    proc=subprocess.run([sys.executable,str(Path(__file__).resolve()),'--case',str(width),str(shift)],
        cwd=root,capture_output=True,text=True,timeout=180)
    print(proc.stdout,flush=True)
    if proc.stderr:print(proc.stderr,file=sys.stderr,flush=True)
    passed=proc.returncode==0 and 'SAT proof finished - no model found: SUCCESS!' in proc.stdout
    if not passed:raise SystemExit(f'Conversion proof FAILED: signed{width}, shift {shift}')
    results.append(dict(input_width=width,shift=shift,output_width=16,passed=True,
        scope='All two-state signed inputs; nearest-even, saturation and rounded flags'))
    print(f'CONVERSION PROOF PASS: signed{width} shift {shift} -> signed16',flush=True)
(root/'rtl/tests/conversion-proof-results.json').write_text(json.dumps(results,indent=2)+'\n')
