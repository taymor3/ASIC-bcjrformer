from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.tools'))
import yowasp_yosys
case = int(sys.argv[1]) if len(sys.argv)>1 else 0
mode = sys.argv[2] if len(sys.argv)>2 else 'prove'
if case not in range(21) or mode not in ('prove','scenario','cover','netlist'):
    raise SystemExit('run_core_control.py CASE[0..20] [prove|scenario|cover|netlist]')
steps = int(sys.argv[3]) if len(sys.argv)>3 else 128
sources = [
    'rtl/interfaces/bcjrformer_contract_pkg.sv',
    'rtl/interfaces/bcjrformer_channels.sv',
    'rtl/control/core_ctrl.sv',
    'rtl/tests/core_control_formal.sv',
]
schedule='-set finish_check 0 '
if mode in ('scenario','cover'):
    schedule+='-set host_go 1 -set memory_go 1 -set stage_go 1 '
    for t in range(2,steps+1):
        if t%5==0: schedule+=f'-set-at {t} host_go 0 '
        if t%7==0: schedule+=f'-set-at {t} memory_go 0 '
        if t%9==0: schedule+=f'-set-at {t} stage_go 0 '
    if mode=='scenario': schedule+=f'-set-at {steps} finish_check 1 '
tail = ('stat; write_json rtl/tests/core-control-netlist.json' if mode=='netlist' else
        f'chformal -assert2assume; sat -seq {steps} -set-assumes -set-at {steps} test_done 1 '
        f'-set-at {steps} saw_stall 1 '+
        (f'-set-at {steps} saw_reset 1 ' if case in (9,10) else '')+
        f'{schedule}-show-ports -timeout 60 -dump_vcd rtl/tests/core-control-cover-{case}.vcd' if mode=='cover' else
        f'sat -seq {steps} {schedule}-prove-asserts -set-assumes -timeout 60 -show-ports '
        f'-dump_vcd rtl/tests/core-control-failure-{mode}-{case}.vcd -verify')
sys.argv=['yosys','-p',
    f'read_slang -j 1 -DSYNTHESIS --top core_control_formal -GCASE={case} '+' '.join(sources)+'; '
    'prep -top core_control_formal -flatten; memory_map; opt; wreduce; opt; async2sync; chformal -lower; '+tail]
sys.exit(yowasp_yosys._run_yosys_argv())
