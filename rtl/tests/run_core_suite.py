from pathlib import Path
import json, subprocess, sys, time
root=Path(__file__).resolve().parents[2]
runner=root/'rtl/tests/run_core_control.py'
cases=['two frames / retained parameters','empty position / recovery','early feature last',
       'missing mask last','bad parameter address','premature commit','feature write error',
       'stage numerical failure','commit during parameter transaction','reset during parameter transaction',
       'reset during stalled output','commit during held completion','invalid empty position',
       'parameter write error','output read error after first transfer','commit during stage transaction',
       'duplicate parameter address','excess parameter word','commit before held write acknowledgement',
       'parameter reload wins over frame','commit during held output']
extra=len(sys.argv)>1 and sys.argv[1] in ('extra','finish')
finish=len(sys.argv)>1 and sys.argv[1]=='finish'
index=root/'rtl/tests/core-control-results.json'
results=json.loads(index.read_text()) if extra and index.exists() else []
jobs=([(i,'scenario',192) for i in (0,1,16,17,18,19,20)]+[(i,'cover',192) for i in (0,1,9,10,14)] if finish else
      [(i,'scenario',192) for i in range(16,21)] if extra else
      [(i,'scenario',192) for i in range(21)]+[(i,'prove',24) for i in (0,8,11,15)]+[(i,'cover',192) for i in (0,1,9,10,14)])
for case,mode,steps in jobs:
    log=root/f'rtl/tests/core-verified-{mode}-{case}.log'
    started=time.monotonic()
    with log.open('w') as stream:
        try:
            proc=subprocess.run([sys.executable,str(runner),str(case),mode,str(steps)],cwd=root,
                                stdout=stream,stderr=subprocess.STDOUT,timeout=120)
        except subprocess.TimeoutExpired:
            stream.write('\nRunner timeout after 120 seconds; no passing result.\n')
            proc=subprocess.CompletedProcess([],124)
    contents=log.read_text()
    expected='SAT solving finished - model found:' if mode=='cover' else 'SAT proof finished - no model found: SUCCESS!'
    passed=proc.returncode==0 and expected in contents
    result=dict(case=case,name=cases[case],mode=mode,steps=steps,passed=passed,
                seconds=round(time.monotonic()-started,2),log=str(log.relative_to(root)))
    results=[r for r in results if (r['case'],r['mode'])!=(case,mode)]
    results.append(result)
    (root/'rtl/tests/core-control-results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{mode} {case} ({cases[case]}): {"PASS" if passed else "FAIL"}',flush=True)
    if not passed:
        print('\n'.join(contents.splitlines()[-18:]),flush=True)
        sys.exit(1)
print(f'{sum(r["passed"] for r in results)}/{len(results)} recorded controller checks passed.',flush=True)
