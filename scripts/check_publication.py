"""Check production source integrity and local Markdown file links."""
from pathlib import Path
import hashlib
import json
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
record = json.loads((ROOT / 'docs/evidence/implementation-2026-10-16.json').read_text())
errors = []
for name, expected in record['source_sha256'].items():
    path = ROOT / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        errors.append('Production source differs from recorded baseline: ' + name)
for document in ROOT.rglob('*.md'):
    for target in re.findall(r'\]\(([^)]+)\)', document.read_text(encoding='utf-8')):
        target = target.strip('<>').split('#', 1)[0]
        if not target or re.match(r'^[a-zA-Z][\w+.-]*:', target):
            continue
        if not (document.parent / unquote(target)).exists():
            errors.append(f'{document.relative_to(ROOT)}: missing {target}')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'PASS: {len(record["source_sha256"])} production hashes and local Markdown file links')
