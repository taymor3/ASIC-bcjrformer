"""Regenerate external declarations from real public module headers."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
names=json.loads((root/'architecture-connections.json').read_text())['modules']
sources=list(root.glob('**/*.sv'))
headers={}
for path in sources:
    if 'tests' in path.parts or '.tools' in path.parts:continue
    for match in re.finditer(r'\bmodule\s+(\w+)\b[\s\S]*?\);',path.read_text()):
        if match[1] in names:headers[match[1]]='extern '+match[0]
assert set(headers)==set(names),set(names)-set(headers)
(root/'interfaces/bcjrformer_ports.svh').write_text('// Generated public port contracts; implementations are in the production file list.\n\n'+'\n\n'.join(headers[n] for n in names)+'\n')
paths=['rtl/interfaces/bcjrformer_contract_pkg.sv','rtl/interfaces/bcjrformer_channels.sv','rtl/arithmetic/fixed_math_pkg.sv']
paths+=['rtl/'+p.relative_to(root).as_posix() for folder in ('protocol','memory','arithmetic','control')
        for p in sorted((root/folder).glob('*.sv')) if p.name!='fixed_math_pkg.sv']
paths+=['rtl/bcjrformer_core.sv']
(root/'protocol/files.f').write_text('\n'.join(paths)+'\n')
print(f'{len(headers)} public contracts; {len(paths)} production sources')
