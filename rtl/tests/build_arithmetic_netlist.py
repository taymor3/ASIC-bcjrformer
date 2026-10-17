from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'rtl/.tools'))
import yowasp_yosys
sources=(root/'rtl/protocol/files.f').read_text().splitlines()+['rtl/tests/arithmetic_sim_top.sv']
sys.argv=['yosys','-Q','-T','-p','read_slang -j 1 -DSYNTHESIS --top arithmetic_sim_top '+' '.join(sources)+
 '; prep -top arithmetic_sim_top -flatten; check -assert; write_json rtl/tests/arithmetic-netlist.json']
sys.exit(yowasp_yosys._run_yosys_argv())
