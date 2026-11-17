# Skills used for the front-end presentation

| Skill | Role in the deck | Upstream revision |
| --- | --- | --- |
| Diagram Design | Inline SVG layout, diagram accessibility and geometry checks | [`f6db0de`](https://github.com/cathrynlavery/diagram-design/tree/f6db0decea96de66b901331a0f79a8d4b147ebae/skills/diagram-design) |
| Anatomy | Close-up review of wire junctions and component boundaries | [`1482e84`](https://github.com/wheresryan22/anatomy/tree/1482e8469b0a9e0d8cc18ea2740a01423d29ae80) |

The schematics use 2D RTL symbols so signal directions and mux ports are easy to follow. The deck opens offline without either skill. Install them to create or revise diagrams in Codex.

## Install the pinned skills in Codex on Windows

With Python, Git, and the bundled Codex skill installer available, run the commands below in PowerShell. Each destination should be new. Existing installations can be reused.

### Diagram Design

```powershell
$codexSkills = Join-Path $env:USERPROFILE '.codex/skills'
$installer = Join-Path $codexSkills '.system/skill-installer/scripts/install-skill-from-github.py'
python $installer --repo cathrynlavery/diagram-design --ref f6db0decea96de66b901331a0f79a8d4b147ebae --path skills/diagram-design --dest $codexSkills
```

### Anatomy

```powershell
$anatomySkill = Join-Path $env:USERPROFILE '.codex/skills/anatomy'
git clone https://github.com/wheresryan22/anatomy.git $anatomySkill
if ($LASTEXITCODE -eq 0) {
    git -C $anatomySkill checkout --detach 1482e8469b0a9e0d8cc18ea2740a01423d29ae80
}
```

Start a fresh Codex chat to load the installed skills. The complete skill files and their MIT notices live in the upstream repositories.

[Diagram Design install options](https://diagramdesign.dev/#install) · [Anatomy install options](https://github.com/wheresryan22/anatomy#install)
