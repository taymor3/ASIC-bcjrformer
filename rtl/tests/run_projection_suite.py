from pathlib import Path
import json,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
names=['repeated commands / changed layer base','linear numerical failure','error without fatal status',
 'invalid layer index','unaddressable layer base','reset during linear wait','reset around completion',
 'last linear write-completion failure','single token / feature']
jobs=[]
for module in (0,1):
    jobs += [(module,c,'scenario',192 if c in (0,5,6,7) else 64) for c in range(9)]
    jobs += [(module,0,'prove',24),(module,0,'cover',192),(module,5,'cover',192)]
results=[]
for module,case,mode,steps in jobs:
    log=root/f'rtl/tests/projection-{module}-{mode}-{case}.log';start=time.monotonic()
    with log.open('w') as stream:
        try:proc=subprocess.run([sys.executable,str(root/'rtl/tests/run_projection_control.py'),str(module),str(case),mode,str(steps)],
            cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            stream.write('\nRunner timeout; no passing evidence.\n');proc=subprocess.CompletedProcess([],124)
    content=log.read_text();marker='SAT solving finished - model found:' if mode=='cover' else 'SAT proof finished - no model found: SUCCESS!'
    passed=proc.returncode==0 and marker in content
    results.append(dict(module='qkv' if module==0 else 'output_projection',case=case,name=names[case],mode=mode,
        steps=steps,passed=passed,seconds=round(time.monotonic()-start,2),log=str(log.relative_to(root))))
    (root/'rtl/tests/projection-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{module} {mode} {case}: {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:print('\n'.join(content.splitlines()[-18:]));sys.exit(1)
print(f'{len(results)}/{len(jobs)} projection-control checks passed.',flush=True)
