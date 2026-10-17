"""Lower actual embedding/final/aggregation controllers for focused fault tests."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'rtl/.tools'))
import yowasp_yosys
mode=int(sys.argv[1])
if mode not in (0,1,2):raise SystemExit('MODE: 0 embedding, 1 final, 2 aggregation')
sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
 'rtl/arithmetic/fixed_math_pkg.sv','rtl/control/embedding_ctrl.sv','rtl/control/final_ctrl.sv',
 'rtl/control/aggregation_ctrl.sv','rtl/tests/controller_fault_sim_top.sv']
sys.argv=['yosys','-Q','-T','-p',f'read_slang -j 1 -DSYNTHESIS --top controller_fault_sim_top -GMODE={mode} '+
 ' '.join(sources)+f'; prep -top controller_fault_sim_top -flatten; check -assert; write_json rtl/tests/controller-fault-{mode}-netlist.json']
raise SystemExit(yowasp_yosys._run_yosys_argv())
