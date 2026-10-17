# Working on ASIC-bcjrformer

This directory is the canonical working checkout of
https://github.com/taymor3/ASIC-bcjrformer. Work here, not in the historical
`publish/ASIC-bcjrformer` copy. Never operate on an ancestor repository.

## Synchronize before editing

1. Verify `git rev-parse --show-toplevel`, `git remote -v`, the active branch,
   and `git status --short` from this directory.
2. Fetch origin and, on a clean tracking branch, run `git pull --ff-only` before
   making changes. Do not silently stash, overwrite, discard, or commit someone
   else's work. If the working tree is dirty or the branches have diverged,
   inspect and preserve the changes before deciding how to integrate them.
3. For parallel development, create a focused `codex/` branch from updated main.
   Continue an existing task branch when appropriate. Do not change branches
   while unrelated edits are pending.

## Check, commit, and push

The maintainer has requested a pull-before-work and commit/push-after-work
workflow for authorized project changes. Stage only relevant files, inspect the
staged diff, run appropriate checks, make a descriptive commit, and push the
working branch. Fetch again before pushing if other collaborators may have
updated it. Integrate concurrent work without force-pushing shared history.
Do not merge or approve pull requests unless the user authorizes that action.

If native Git push authentication is unavailable, use the connected GitHub
plugin for writes to this repository, with the current remote head as the
expected parent/lease. Then fetch and synchronize the local branch without
discarding edits. Never copy credentials out of the connector or print tokens.
Report any authentication or permission blocker accurately.

## Scope and verification

- Keep RTL, architecture, microarchitecture, diagrams, and documentation in sync.
- Numerical formats remain provisional. Preserve ready/valid stability, memory
  completion barriers, and the documented tensor/parameter layout.
- Use `python scripts/check.py smoke` for relevant integration changes and
  `numerics` plus the affected cycle/proof checks for numerical changes. Choose
  checks proportionate to the change; do not claim unrun tests passed.
- Do not alter archived source hashes to make a check pass. If production RTL
  changes, retain the historical evidence and explicitly record the new
  revision's validation and any required baseline-check updates.
- Follow LICENSE.md and preserve third-party notices.
- Do not publish upstream model checkouts, external reference documents,
  weights, local configuration, tool caches, credentials, or excluded backups.
  Do not add ignored files with `git add -f` without explicit user authorization.

See docs/collaboration.md for the human collaboration workflow.
