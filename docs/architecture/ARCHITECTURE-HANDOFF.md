# Architecture draft handoff

> Current review entry point (10 October 2026): ARCHITECTURE-CHECKPOINT-1.md. Working stage and interface contracts take precedence over older generated publication snapshots. Numerical verification is pending Haiel; this checkpoint awaits Taimor's approval.

## Current publication structure

The paper now opens with a separate high-level architecture section, before the detailed five-stage mathematics/RTL mapping. Source: .architecture-assets/high-level-architecture.tex. It covers stage interfaces, internal blocks, architectural FSMs, output readiness, data/mask/parameter paths and controller hierarchy. Existing detailed design is retained afterward. The publication has 65 headings, 184 math expressions and seven figures; use the latest review-checks.json for completed browser-verification results.

The canonical v5 LaTeX and HTML now form a design-review paper, not a dated review log. Five main sections follow execution order: input embedding; position/read embedding; encoder; final projection; aggregation/output. Each contains interface/equations, FSM operations and architectural rationale. Research remains at the end. Calendar dates, planning/work-split notes and duplicate historical architecture sections are excluded from the published paper.

The build uses .architecture-assets/compose-paper.cjs, paper-intro.tex, reviewed-math.tex, numerical-research.tex and selected RTL-specification.md contracts. The old sync-rtl-docs.cjs forwards to the new composer. The prior canonical document is retained as .architecture-assets/pre-paper-architecture.tex for its original TikZ assets and recovery. Do not edit the generated canonical source directly. Latest full checks: 56 views, 56 sections/subsections, 155 math expressions; source/download equality and mobile layout pass. Native LaTeX compilation remains unchecked. Earlier notes below are historical.

Updated 25 September 2026: full reviewed mathematics and execution schedule are now consolidated in canonical v5 LaTeX and HTML. The final section records course-material findings, primary papers, evidence limits and the experiment/acceptance plan for GELU, exponential, reciprocal and inverse square root. Older LaTeX versions remain historical snapshots.

Stage 2 now uses exact nested counters; the final projection has no duplicate logit write; aggregation computes its reciprocal once per frame. Numerical precision and primitive contracts remain unvalidated candidates. Author the new sections in .architecture-assets/reviewed-math.tex and .architecture-assets/numerical-research.tex; the build inlines them into the standalone canonical source. The additional check-reviewed.cjs validates rendering and final-section placement. Earlier run counts below are historical; consult review-checks.json for the latest full run.

Joint-review update: HTML and canonical v5 LaTeX now include the agreed explicit dot/linear/QKV controllers, score-row and weighted-value control, output projection, shared normal/uniform softmax write path, simulation snapshot/flag plan and physical-feasibility caveats. Latest browser run passed 56 interactive views and 57 document sections/subsections with exact source/download checks. Snapshot tooling and RTL are specified, not implemented. Next: review the first architecture sketch together with Taimor; do not proceed automatically to implementation.

## Current artifacts

- bcjrformer-architecture.html: expanded interactive architecture, self-attention and FSM views, document and downloadable LaTeX.
- bcjrformer_asic_architecture_v5.tex: canonical source, including synchronized RTL specification and review questions.
- RTL-specification.md: proposed module contracts, FSM sequences, handshakes, counters, memory ownership and numerical formats.
- Amit-review-decisions.md: unresolved scope and implementation decisions for supervisor review.

This is a review draft, not approved architecture, implemented RTL, or validated numerical behavior. Arithmetic precision and primitive accuracy targets require calibration. Preserve source query-row masking unless an algorithm change is explicitly approved.

## Resume here

1. Browser QA now traverses all 50 views on desktop and mobile. The screenshot timeout was resolved by bringing the document tab to the foreground. See .architecture-assets/review-checks.json for the latest completed run, including exact embedded-source/download checks.
2. The rerouted attention document figure, attention FSM and updated softmax diagram were visually inspected. Softmax now shows its saved-exponential input and uniform-row bypass explicitly.
3. The consistency review added explicit scalar formats/rounding, top-level port widths and parameter-commit protocol, scratch-buffer lifetimes and nested-counter initialization. Descriptor bounds include FFN length 4D and layer count K. See ARCHITECTURE-REVIEW-AUDIT.md for requirement coverage and limitations.
4. Native LaTeX compilation has not been performed: no compiler was found. HTML conversion succeeded with 49 sections/subsections, 116 math expressions and seven figures; this is not a substitute for LaTeX typesetting verification.
5. Next work is review of the consolidated document and Amit's open decisions, then selection of checkpoint/calibration data and one-black-box-at-a-time numerical experiments. Do not treat this draft as supervisor approval or completed hardware.

Build command: run build-project-page.cjs using the bundled Node runtime. It synchronizes the Markdown specification and decision checklist into the generated appendix of the canonical LaTeX, then regenerates HTML. Edit the Markdown originals, not that generated appendix.
