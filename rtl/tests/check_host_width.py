"""Prove synthesis preflight rejects an undersized actual host interface."""
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
SOURCES=' '.join((
    'rtl/interfaces/bcjrformer_contract_pkg.sv',
    'rtl/interfaces/bcjrformer_channels.sv',
    'rtl/control/core_ctrl.sv',
    'rtl/tests/host_width_elaboration.sv',
))

if len(sys.argv)>1 and sys.argv[1]=='--case':
    sys.path.insert(0,str(ROOT/'rtl/.tools'))
    import yowasp_yosys
    width=int(sys.argv[2])
    sys.argv=['yosys','-Q','-T','-p',
        f'read_slang -j 1 -DSYNTHESIS --top host_width_elaboration -GINDEX_W={width} {SOURCES}']
    raise SystemExit(yowasp_yosys._run_yosys_argv())

for width,should_pass in ((2,True),(64,True),(1,False)):
    result=subprocess.run([sys.executable,__file__,'--case',str(width)],cwd=ROOT,
        text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if (result.returncode==0)!=should_pass:
        print(result.stdout)
        raise SystemExit(f'Host width {width}: unexpected preflight return {result.returncode}')
    if not should_pass and 'host INDEX_W cannot represent every output position' not in result.stdout:
        print(result.stdout)
        raise SystemExit('Negative case failed for an unrelated reason')
    print(f'SYNTHESIS host INDEX_W={width}, OUTPUT_WORDS=3: '+('accepted' if should_pass else 'correctly rejected'))
print('HOST WIDTH SYNTHESIS PREFLIGHT PASS')
