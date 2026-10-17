from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools'))
import yowasp_yosys
stage=int(sys.argv[1]);case=int(sys.argv[2]);mode=sys.argv[3] if len(sys.argv)>3 else 'scenario'
steps=int(sys.argv[4]) if len(sys.argv)>4 else (384 if stage==0 else 640)
shape=sys.argv[5] if len(sys.argv)>5 else ''
if shape not in ('','nonpower'):raise SystemExit('Optional shape: nonpower')
dimensions='-GTEST_M=3 -GTEST_N=2 -GTEST_D=1 ' if shape=='nonpower' else ''
if stage not in (0,1) or case not in range(10) or mode not in ('scenario','prove','cover'):
    raise SystemExit('run_stage12_control.py STAGE[0=embed,1=position] CASE[0..9] [scenario|prove|cover] [steps]')
schedule='-set finish_check 0 '
if mode!='prove':
    schedule+='-set memory_go 1 -set service_go 1 -set response_go 1 '
    for t in range(2,steps+1):
        if t%7==0:schedule+=f'-set-at {t} memory_go 0 '
        if t%5==0:schedule+=f'-set-at {t} service_go 0 '
        if t%3==0:schedule+=f'-set-at {t} response_go 0 '
    if mode=='scenario':schedule+=f'-set-at {steps} finish_check 1 '
sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
         'rtl/control/embedding_ctrl.sv','rtl/control/position_sequencer.sv','rtl/tests/stage12_control_formal.sv']
tail=(f'chformal -assert2assume; sat -seq {steps} {schedule}-set-assumes -set-at {steps} test_done 1 '
      f'-set-at {steps} saw_stall 1 '+(f'-set-at {steps} saw_reset 1 ' if case in (5,6) else '')+
      f'-show-ports -timeout 60 -dump_vcd rtl/tests/stage12-cover-{stage}-{case}.vcd' if mode=='cover' else
      f'sat -seq {steps} {schedule}-prove-asserts -set-assumes -timeout 60 -show-ports '
      f'-dump_vcd rtl/tests/stage12-failure-{stage}-{case}.vcd -verify')
sys.argv=['yosys','-p',f'read_slang -j 1 -DSYNTHESIS --top stage12_control_formal -GMODE={stage} -GCASE={case} '+dimensions+
          ' '.join(sources)+'; prep -top stage12_control_formal -flatten; opt; wreduce; opt; async2sync; chformal -lower; '+tail]
sys.exit(yowasp_yosys._run_yosys_argv())
