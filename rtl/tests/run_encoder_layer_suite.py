from pathlib import Path
import json,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
names=['two encoder commands / three layers','norm numeric failure','late FFN protocol failure',
       'invalid encoder command','reset during child wait','reset during final completion',
       'child error without fatal bits','invalid layer index','unaddressable layer base']
jobs=[(i,'scenario',384 if i in (0,5) else 192 if i in (2,4) else 64) for i in range(9)]
jobs += [(0,'prove',24),(7,'prove',24),(0,'cover',384),(4,'cover',192)]
results=[]
for case,mode,steps in jobs:
    log=root/f'rtl/tests/encoder-layer-{mode}-{case}.log';started=time.monotonic()
    with log.open('w') as stream:
        try:proc=subprocess.run([sys.executable,str(root/'rtl/tests/run_encoder_layer.py'),str(case),mode,str(steps)],
            cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            stream.write('\nRunner timeout; no passing evidence.\n');proc=subprocess.CompletedProcess([],124)
    content=log.read_text();marker='SAT solving finished - model found:' if mode=='cover' else 'SAT proof finished - no model found: SUCCESS!'
    passed=proc.returncode==0 and marker in content
    results.append(dict(case=case,name=names[case],mode=mode,steps=steps,passed=passed,
        seconds=round(time.monotonic()-started,2),log=str(log.relative_to(root))))
    (root/'rtl/tests/encoder-layer-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{mode} {case}: {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:print('\n'.join(content.splitlines()[-20:]));sys.exit(1)
print(f'{len(results)}/{len(jobs)} encoder/layer checks passed.',flush=True)
