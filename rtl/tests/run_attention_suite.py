from pathlib import Path
import json,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
names=['repeated commands / changed descriptor and mask','QKV numeric fault','late score numeric fault','late mask error',
       'softmax fatal status without error flag','weighted protocol error','projection error without fatal status',
       'invalid layer index','unaddressable layer base','reset during mask read','reset during softmax',
       'reset around completion','all queries padded','all queries valid','one head / one query']
jobs=[(c,'scenario',320 if c in (0,11) else 192 if c in (9,10,12,13) else 128 if c in (2,3,6) else 64) for c in range(15)]
jobs += [(0,'prove',24),(7,'prove',24),(0,'cover',320),(10,'cover',192),(14,'cover',64)]
results=[]
for case,mode,steps in jobs:
    log=root/f'rtl/tests/attention-{mode}-{case}.log';start=time.monotonic()
    with log.open('w') as stream:
        try:proc=subprocess.run([sys.executable,str(root/'rtl/tests/run_attention_control.py'),str(case),mode,str(steps)],
            cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            stream.write('\nRunner timeout; no passing evidence.\n');proc=subprocess.CompletedProcess([],124)
    content=log.read_text();marker='SAT solving finished - model found:' if mode=='cover' else 'SAT proof finished - no model found: SUCCESS!'
    passed=proc.returncode==0 and marker in content
    results.append(dict(case=case,name=names[case],mode=mode,steps=steps,passed=passed,
        seconds=round(time.monotonic()-start,2),log=str(log.relative_to(root))))
    (root/'rtl/tests/attention-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{mode} {case}: {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:print('\n'.join(content.splitlines()[-20:]));sys.exit(1)
print(f'{len(results)}/{len(jobs)} attention-control checks passed.',flush=True)
