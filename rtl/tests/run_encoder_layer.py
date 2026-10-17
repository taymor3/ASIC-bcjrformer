from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools'))
import yowasp_yosys
case=int(sys.argv[1]);mode=sys.argv[2] if len(sys.argv)>2 else 'scenario'
steps=int(sys.argv[3]) if len(sys.argv)>3 else 384
schedule='-set finish_check 0 '
if mode!='prove':
    schedule+='-set service_go 1 -set response_go 1 '
    for t in range(2,steps+1):
        if t%5==0:schedule+=f'-set-at {t} service_go 0 '
        if t%3==0:schedule+=f'-set-at {t} response_go 0 '
    if mode=='scenario':schedule+=f'-set-at {steps} finish_check 1 '
tail=(f'chformal -assert2assume; sat -seq {steps} {schedule}-set-assumes -set-at {steps} test_done 1 '
      f'-set-at {steps} saw_stall 1 '+(f'-set-at {steps} saw_reset 1 ' if case in (4,5) else '')+
      f'-show-ports -dump_vcd rtl/tests/encoder-layer-cover-{case}.vcd' if mode=='cover' else
      f'sat -seq {steps} {schedule}-prove-asserts -set-assumes -timeout 60 -show-ports '
      f'-dump_vcd rtl/tests/encoder-layer-failure-{case}.vcd -verify')
sources=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv',
         'rtl/control/encoder_ctrl.sv','rtl/control/layer_ctrl.sv','rtl/tests/encoder_layer_formal.sv']
sys.argv=['yosys','-p',f'read_slang -j 1 -DSYNTHESIS --top encoder_layer_formal -GCASE={case} '+
          ' '.join(sources)+'; prep -top encoder_layer_formal -flatten; opt; wreduce; opt; async2sync; chformal -lower; '+tail]
sys.exit(yowasp_yosys._run_yosys_argv())
