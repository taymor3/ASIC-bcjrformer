"""Check production source integrity and local Markdown file links."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
record = json.loads((ROOT / 'docs/evidence/implementation-2026-10-16.json').read_text())
errors = []
for name, expected in record['source_sha256'].items():
    path = ROOT / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        errors.append('Production source differs from recorded baseline: ' + name)
try:
    # Check project files, including new untracked documents, without walking
    # ignored model checkouts, dependency packages, or preserved local backups.
    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', '*.md'],
        cwd=ROOT, stderr=subprocess.DEVNULL,
    ).decode('utf-8').split('\0')
    documents = [ROOT / name for name in names if name]
except (OSError, subprocess.CalledProcessError):
    # Source archives need no Git installation and normally contain no extras.
    excluded = {'.git', '.tools', 'node_modules', '.venv', '__pycache__',
                'publish', 'BCJRFormer', 'references', 'tmp', '.vscode'}
    documents = [p for p in ROOT.rglob('*.md')
                 if not excluded.intersection(p.relative_to(ROOT).parts)]
for document in documents:
    for target in re.findall(r'\]\(([^)]+)\)', document.read_text(encoding='utf-8')):
        target = target.strip('<>').split('#', 1)[0]
        if not target or re.match(r'^[a-zA-Z][\w+.-]*:', target):
            continue
        if not (document.parent / unquote(target)).exists():
            errors.append(f'{document.relative_to(ROOT)}: missing {target}')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'PASS: {len(record["source_sha256"])} production hashes and local Markdown file links')
