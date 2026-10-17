from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.tools'))
import yowasp_yosys
case = sys.argv[1] if len(sys.argv)>1 else 'control'
cases={'control': (3,2,3,-1,0), 'fast':(1,1,1,3,1), 'single':(1,2,3,3,1), 'full':(13,2,3,-1,0)}
cases.update({f'bank-{b}':(1,2,3,b,1) for b in range(18)})
if case not in cases: raise SystemExit('Cases: control, fast, single, full, bank-0 through bank-17')
clients,pdelay,sdelay,bank,data=cases[case]
mode=sys.argv[2] if len(sys.argv)>2 else 'prove'
if mode not in ('prove','netlist','cover'): raise SystemExit('Modes: prove, netlist, cover')
goals = '-set-at 24 cover_readback 1 -set-at 24 cover_stall 1 -set-at 24 cover_reset_readback 1' if data else '-set-at 24 cover_error 1 -set-at 24 cover_stall 1'
tail = 'stat; write_json rtl/tests/memory-netlist.json' if mode=='netlist' else (
    f'chformal -assert2assume; sat -seq 24 -set-assumes {goals} -show-ports -timeout 60 -dump_vcd rtl/tests/memory-cover-{case}.vcd' if mode=='cover' else
    'sat -seq 16 -prove-asserts -set-assumes -timeout 60 -verify')
sources=(root/'protocol/files.f').read_text().splitlines()+['rtl/tests/memory_formal.sv']
sys.argv=['yosys','-p',
    'read_slang -j 1 --top memory_formal '+f'-GCLIENTS={clients} -GPARAM_DELAY={pdelay} -GSCRATCH_DELAY={sdelay} -GTEST_BANK={bank} -GCHECK_DATA={data} '+ ' '.join(sources)+'; '
    'prep -top memory_formal -flatten; memory_map; bmuxmap; opt; wreduce; opt; async2sync; chformal -lower; '+tail]
sys.exit(yowasp_yosys._run_yosys_argv())
