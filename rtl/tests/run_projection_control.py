from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools'))
import yowasp_yosys
module=int(sys.argv[1]);case=int(sys.argv[2]);mode=sys.argv[3] if len(sys.argv)>3 else 'scenario'
steps=int(sys.argv[4]) if len(sys.argv)>4 else 192
if module not in (0,1) or case not in range(9) or mode not in ('scenario','prove','cover'):raise SystemExit('MODE 0=qkv,1=out; CASE 0..8; scenario|prove|cover')
shape='-GTOKENS=1 -GD=1 ' if case==8 else ''
schedule='-set finish_check 0 '
if mode!='prove':
    schedule+='-set service_go 1 -set response_go 1 '
    for t in range(2,steps+1):
        if t%5==0:schedule+=f'-set-at {t} service_go 0 '
        if t%3==0:schedule+=f'-set-at {t} response_go 0 '
    # A startup stall guarantees the reset witness exercises held service data.
    if mode=='cover':
        for t in range(2,9):
            if t%5!=0:schedule+=f'-set-at {t} service_go 0 '
    if mode=='scenario':schedule+=f'-set-at {steps} finish_check 1 '
tail=(f'chformal -assert2assume; sat -seq {steps} {schedule}-set-assumes -set-at {steps} test_done 1 '
      f'-set-at {steps} saw_stall 1 '+(f'-set-at {steps} saw_reset 1 ' if case in (5,6) else '')+
      f'-show-ports -timeout 60 -dump_vcd rtl/tests/projection-cover-{module}-{case}.vcd' if mode=='cover' else
      f'sat -seq {steps} {schedule}-prove-asserts -set-assumes -timeout 60 -show-ports '
      f'-dump_vcd rtl/tests/projection-failure-{module}-{case}.vcd -verify')
sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
 'rtl/protocol/transaction_router.sv','rtl/protocol/command_switch.sv','rtl/control/projection_loop.sv',
 'rtl/control/qkv_ctrl.sv','rtl/control/output_projection_ctrl.sv','rtl/tests/projection_control_formal.sv']
sys.argv=['yosys','-p',f'read_slang -j 1 -DSYNTHESIS --top projection_control_formal -GMODE={module} -GCASE={case} '+shape+
 ' '.join(sources)+'; prep -top projection_control_formal -flatten; bmuxmap; opt; wreduce; opt; async2sync; chformal -lower; '+tail]
sys.exit(yowasp_yosys._run_yosys_argv())
