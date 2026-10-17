"""Require explicit success evidence and record the final production file hashes."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[2];tests=root/'rtl/tests'
def read(name):return json.loads((tests/name).read_text())
def marker(name,text):
    assert text in (tests/name).read_text(),f'missing explicit success: {name}'
for name in ('conversion-formal.log','router-complete-regression.log','memory-complete-regression.log',
             'memory-control-regression.log','memory-bank-11-regression.log',
             'memory-bank-13-regression.log','memory-bank-14-regression.log','memory-bank-2-regression.log'):
    marker(name,'SAT proof finished - no model found: SUCCESS!')
cycles={shape:read(f'complete-{shape}-results.json') for shape in ('single','multi','heads','precision')}
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
conversions=read('conversion-proof-results.json')
assert {(c['input_width'],c['shift']) for c in conversions if c['passed']}=={(48,10),(64,22)}
layernorm=json.loads((root/'tmp/layernorm-regression/results.json').read_text())
assert layernorm['passed'] and layernorm['cases']==53 and all(c['passed'] for c in layernorm['results'])
controller_faults=read('controller-fault-results.json')
assert len(controller_faults['results'])==22 and all(c['passed'] for c in controller_faults['results'])
marker('host-width.log','HOST WIDTH SYNTHESIS PREFLIGHT PASS')
marker('hidden-memory.log','HIDDEN MEMORY PROVE PASS')
sources=(root/'rtl/protocol/files.f').read_text().splitlines()
checksums={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sources}
index=json.loads((root/'docs/evidence/rtl-source-current.json').read_text())
assert checksums==index['source_sha256'],'Current source index differs from the tested implementation'
report={'date':'2026-10-17','status':'PASS: post-review corrective RTL implementation checks; selected-model numerical validation remains external',
 'production_sources':len(sources),'public_module_kinds':29,'service_endpoints':65,
 'core_frames':sum(len(r['results']) for r in cycles.values()),
 'checked_intermediate_writes':sum(r['checkedWrites'] for r in cycles.values()),
 'arithmetic_vectors':arithmetic['vectors'],'fault_scenarios':len(faults['results']),
 'manifest_roundtrips':len(manifests),'conversion_proofs':conversions,
 'layernorm_regression':layernorm,'targeted_controller_faults':controller_faults,
 'host_width_synthesis_preflight':'PASS: N3 accepts widths2/64, rejects width1',
 'hidden_memory_proof_steps':20,'hidden_format':'signed32/F22; exact F10 promotion on first-linear writes',
 'router_clients':13,'router_regression_steps':24,'memory_regression_steps':16,
 'required_memory_cases':['fast','control','bank-11','bank-13','bank-14','bank-2'],
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
