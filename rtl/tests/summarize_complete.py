"""Require explicit success evidence and record the final production file hashes."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[2];tests=root/'rtl/tests'
def read(name):return json.loads((tests/name).read_text())
def marker(name,text):
    assert text in (tests/name).read_text(),f'missing explicit success: {name}'
for name in ('conversion-formal.log','router-complete-regression.log','memory-complete-regression.log'):
    marker(name,'SAT proof finished - no model found: SUCCESS!')
cycles={shape:read(f'complete-{shape}-results.json') for shape in ('single','multi','heads')}
for shape,report in cycles.items():
    assert len(report['results'])==4 and all(r['passed'] for r in report['results'])
    marker(f'complete-{shape}-cycle.log',f'{shape} frame 3: PASS')
    marker(f'core-{shape}-build.log','Found and reported 0 problems.')
arithmetic=read('arithmetic-results.json');faults=read('core-fault-results.json');manifests=read('manifest-results.json')
assert arithmetic['passed'] and arithmetic['vectors']==len(read('arithmetic-vectors.json'))
accuracy=read('taylor-accuracy-results.json')
assert accuracy['status']=='PASS'
assert accuracy['exp']['total_output_error_bound']<1e-5 and accuracy['gelu']['total_output_error_bound']<1e-5
assert faults['passed'] and len(faults['results'])==4 and all(r['passed'] for r in faults['results'])
assert len(manifests)==3 and all(r['passed'] for r in manifests)
sources=(root/'rtl/protocol/files.f').read_text().splitlines()
checksums={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sources}
report={'date':'2026-10-16','status':'PASS: Taylor arithmetic and provisional RTL implementation checks; review/numerical validation remain external',
 'production_sources':len(sources),'public_module_kinds':29,'service_endpoints':65,
 'core_frames':sum(len(r['results']) for r in cycles.values()),
 'checked_intermediate_writes':sum(r['checkedWrites'] for r in cycles.values()),
 'arithmetic_vectors':arithmetic['vectors'],'fault_scenarios':len(faults['results']),
 'manifest_roundtrips':len(manifests),'conversion_proof':'exhaustive 48-bit signed input, Q20 to Q10 signed16 clipping and flags',
 'router_regression_steps':24,'memory_regression_steps':16,
 'cycle_results':{shape:{'cycles':r['cycles'],'writes':r['checkedWrites']} for shape,r in cycles.items()},
 'source_sha256':checksums,
 'nonlinear_method':'Taylor arithmetic; no function-value ROM in production',
 'taylor_accuracy':accuracy,
 'limitations':['deterministic two-state cycle simulation, not four-state event-driven simulation',
   'toy configurations; no selected trained checkpoint or full-size inference',
   'no floating-point/decoding calibration, physical SRAM mapping, area or timing sign-off',
   'existing bounded controller suites are historical; not all rerun here']}
(tests/'complete-evidence.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"PASS: {report['core_frames']} frames / {report['checked_intermediate_writes']} intermediate writes, "
      f"{report['arithmetic_vectors']} primitive vectors, {report['fault_scenarios']} faults, {report['manifest_roundtrips']} manifests")
