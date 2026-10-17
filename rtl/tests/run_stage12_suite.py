from pathlib import Path
import json,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
names=['two commands / restarted counters','memory read error','memory write error','norm/add numerical failure',
       'invalid command','reset during memory','reset during norm/add','linear error flag / bad add tag',
       'nonfatal status / repeated command','linear numeric error / read-embedding error']
jobs=[]
for stage in (0,1):
    for case in range(10):
        steps=(256 if stage==0 else 480) if case in (0,8) else (192 if stage==0 else 256) if case in (5,6) else 64
        jobs.append((stage,case,'scenario',steps))
    jobs.append((stage,0,'prove',24))
    for case in (0,6):jobs.append((stage,case,'cover',256 if stage==0 else (480 if case==0 else 256)))
results=[]
jobs=[(*job,'') for job in jobs]+[(1,0,'scenario',384,'nonpower')]
for stage,case,mode,steps,shape in jobs:
    log=root/f'rtl/tests/stage12-verified-{stage}-{mode}-{case}{"-"+shape if shape else ""}.log'
    started=time.monotonic()
    with log.open('w') as stream:
        try:
            proc=subprocess.run([sys.executable,str(root/'rtl/tests/run_stage12_control.py'),str(stage),str(case),mode,str(steps),shape],
                cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            stream.write('\nRunner timeout; no passing result.\n');proc=subprocess.CompletedProcess([],124)
    content=log.read_text()
    expected='SAT solving finished - model found:' if mode=='cover' else 'SAT proof finished - no model found: SUCCESS!'
    passed=proc.returncode==0 and expected in content
    results.append(dict(stage=stage+1,case=case,name=names[case],mode=mode,steps=steps,shape=shape,passed=passed,
        seconds=round(time.monotonic()-started,2),log=str(log.relative_to(root))))
    (root/'rtl/tests/stage12-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'Stage {stage+1} {mode} {case}: {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:
        print('\n'.join(content.splitlines()[-25:]));sys.exit(1)
print(f'{len(results)}/{len(jobs)} Stage 1–2 control checks passed.',flush=True)
