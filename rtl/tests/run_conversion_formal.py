from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'rtl/.tools'))
import yowasp_yosys
sys.argv=['yosys','-Q','-T','-p',
 'read_slang -j 1 -DSYNTHESIS --top conversion_proof rtl/interfaces/bcjrformer_contract_pkg.sv '+
 'rtl/arithmetic/fixed_math_pkg.sv rtl/tests/conversion_proof.sv; prep -top conversion_proof -flatten; '+
 'wreduce; opt; sat -set-def-inputs -prove correct 1 -verify -timeout 60']
sys.exit(yowasp_yosys._run_yosys_argv())
