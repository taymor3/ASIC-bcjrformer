"""Bounded actual-RTL hidden-bank conversion/readback and rejection regression."""
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
worker=len(sys.argv)>1 and sys.argv[1]=='--yosys'
mode=(sys.argv[2] if worker else sys.argv[1]) if len(sys.argv)>(2 if worker else 1) else 'prove'
cover_goals={
    'cover': '-set-at 24 cover_readback 1 -set-at 24 cover_error 1 -set-at 24 cover_stall 1',
    'cover-promotion': '-set-at 24 cover_promoted_readback 1',
    'cover-fraction': '-set-at 24 cover_fractional_readback 1',
    'cover-rejection': '-set-at 24 cover_rejected_f10_read 1',
}
if mode!='prove' and mode not in cover_goals:
    raise SystemExit('Modes: prove, '+', '.join(cover_goals))
if not worker:
    result=subprocess.run([sys.executable,__file__,'--yosys',mode],cwd=ROOT,
        text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    print(result.stdout,end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    marker=('SAT proof finished - no model found: SUCCESS!' if mode=='prove' else
            'SAT solving finished - model found:')
    if marker not in result.stdout:
        raise SystemExit('Hidden-memory result is missing the required success/reachability marker')
    print(f'HIDDEN MEMORY {mode.upper()} PASS')
    raise SystemExit(0)

sys.path.insert(0,str(ROOT/'rtl/.tools'))
import yowasp_yosys
sources=(ROOT/'rtl/protocol/files.f').read_text().splitlines()+['rtl/tests/hidden_memory_formal.sv']
tail=('sat -seq 20 -prove-asserts -set-assumes -timeout 120 -verify' if mode=='prove' else
    'chformal -assert2assume; sat -seq 24 -set-assumes '+cover_goals.get(mode,'')+' -timeout 120 '
    f'-dump_vcd rtl/tests/hidden-memory-{mode}.vcd')
sys.argv=['yosys','-Q','-T','-p',
    'read_slang -j 1 --top hidden_memory_formal '+' '.join(sources)+'; '
    'prep -top hidden_memory_formal -flatten; memory_map; bmuxmap; opt; wreduce; opt; '
    'async2sync; chformal -lower; '+tail]
raise SystemExit(yowasp_yosys._run_yosys_argv())
