# Supporting tools

Use [verification](verification.md) for RTL checks. The tools below maintain the broader project artifacts and are not needed for compilation or cycle regression.

| Tool | Purpose | Extra requirements |
|---|---|---|
| `scripts/architecture-budget.cjs` | Symbolic/provisional capacity budget | Node.js |
| `rtl/architecture-connections.cjs` | Validate/generate service inventory | Node.js |
| `rtl/build-architecture-review.cjs` | Rebuild earlier local review bundle | Node.js; retained `output/architecture/icepanel-model.json` |
| `scripts/prepare-math.cjs` | Fetch KaTeX 0.16.22 and embed font assets | Node.js with network access |
| `scripts/build-project-page.cjs` | Rebuild explorer/report from authored sources | Prepared math assets; Node.js |
| `.architecture-assets/*.cjs` | Stage diagram, report, and explorer authoring helpers | Some optional checks need Playwright/Sharp |
| `.pptx-build/*.mjs` | Historical slide creation/update sources | Separately supplied artifact-tool runtime and presentation utilities |

The hidden authoring directories contain selected **source files**, not installed packages or screenshot caches. Outputs are preserved so ordinary readers do not need their original authoring environment.

For explorer regeneration from the repository root:

```sh
node scripts/prepare-math.cjs
node scripts/build-project-page.cjs
```

These commands overwrite generated content and may reconstruct historical report material. Review their diff; they do not automatically synchronize every older report/deck with current RTL.

Optional browser/image dependencies are listed in `package.json`. Install them with `npm install`, then run `npx playwright install chromium` if using browser checks. The PDF helper currently selects the installed Microsoft Edge channel; change that channel for another environment. Local absolute dependency imports were replaced by package imports in publication copies.

The historical deck scripts depend on `@oai/artifact-tool` and utility modules supplied by the original presentation authoring runtime. Set `PRESENTATIONS_SKILL_DIR` to the appropriate separately installed presentation skill directory and `RUNTIME_NODE_MODULES` if required by that runtime, then run from `.pptx-build`. Set `PYTHON_EXECUTABLE` to the Python interpreter used for presentation validation, or ensure `python` is on PATH. These scripts are included for transparency; a public standalone package for that runtime is not assumed. The `.pptx` deliverables can be opened and edited normally in presentation software.

`scripts/update-organized-paths.cjs` is a historical one-time migration script. Do not run it as a build command; the checked-in paths are already organized. Its relative-name manifest contains the original artifact filenames and hashes, not machine-specific absolute paths.
