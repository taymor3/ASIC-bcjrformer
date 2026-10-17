from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'rtl/.tools'))
import yowasp_yosys
sources=(root/'rtl/protocol/files.f').read_text().splitlines()+['rtl/tests/core_sim_top.sv']
shape=sys.argv[1] if len(sys.argv)>1 else 'multi'
configs={'single':'-GF=1 -GM=1 -GN=1 -GD=1 -GH=1 -GK=1 ',
         'multi':'','heads':'-GF=2 -GM=1 -GN=2 -GD=3 -GH=3 -GK=1 ',
         'precision':'-GF=2 -GM=1 -GN=1 -GD=2 -GH=1 -GK=1 '}
config=configs[shape]
sys.argv=['yosys','-Q','-T','-p','read_slang -j 1 -DSYNTHESIS --top core_sim_top '+config+' '.join(sources)+
  '; prep -top core_sim_top -flatten; opt_clean; check -assert; write_json rtl/tests/core-'+shape+'-netlist.json']
sys.exit(yowasp_yosys._run_yosys_argv())
