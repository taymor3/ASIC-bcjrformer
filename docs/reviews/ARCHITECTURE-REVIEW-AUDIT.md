# Review-draft completion audit

> Current review entry point (10 October 2026): ARCHITECTURE-CHECKPOINT-1.md. Working stage and interface contracts take precedence over older generated publication snapshots. Numerical verification is pending Haiel; this checkpoint awaits Taimor's approval.

Current paper revision: all five stages are top-level sections in execution order, each with mathematical definition, control/completion sequence and design rationale. Stage 1 contains the shared LayerNorm derivation; Stage 2 contains learned P/E additions and integer indexing; Stage 5 is separate from final projection. The paper removes calendar dates and progress-log sections. Browser checks pass 56 views, 56 headings and 155 equations, with exact LaTeX embedding/download, source-order checks and no mobile overflow. Stage 1/2 renders visually inspected. This verifies publication structure, not numerical correctness or native PDF typesetting.

This audit concerns a coherent first architecture/RTL specification draft, not implementation or numerical validation.

25 September consolidation: full mathematics and FSM-operation mapping added for every reviewed stage. Stage-2 integer counters, final linear write ownership and once-per-frame aggregation reciprocal synchronized in the specification and interactive views. Research findings and the black-box validation plan form the last LaTeX/HTML section. Current offline browser verification passes 56 views, 78 sections/subsections, 229 math expressions, exact embedded/downloaded source and mobile layout checks. The separate reviewed-content test passes; new math/research screenshots were visually inspected. Native LaTeX compilation remains unavailable. No RTL, calibration results or synthesis results are claimed.

24 September joint-review update: the latest verifier run passes 56 views on desktop/mobile and 57 document sections/subsections. Dedicated QKV, score-row, weighted-value and output-projection FSMs and the numeric-snapshot plan are now reachable. Dot/linear request and response waits are explicit; softmax shares one probability writer for normal and uniform modes. QKV and softmax FSM screenshots were visually inspected. Earlier counts below describe the prior draft. No RTL or snapshot application was implemented in this documentation update.

## Scope coverage

| Requirement | Current evidence |
|---|---|
| All five core stages | HTML core view and stage pages; RTL specification FSM sections for embedding, learned position/sequence addition, encoder, final projection and aggregation |
| Encoder subblocks and self-attention | One reused layer; LN1, attention, first residual, LN2, FFN and second residual. Attention expands to Q/K/V, scaled dot scores, source-compatible masking, row softmax, weighted values, head joining and output projection |
| Connected datapaths | Interactive diagrams plus seven document figures; attention V bypass and softmax saved-exponential/uniform paths explicitly shown. Attention document figure, attention FSM and softmax render visually inspected |
| FSM conditions and counters | RTL FSM conventions and per-controller schedules; explicit accepted-command initialization, nested-loop restart, ready/valid issue/wait rules, committed-write completion, error/reset behavior and terminal-response hold |
| Module interfaces | Hierarchy and descriptor contracts, top-level port widths, parameter load/commit protocol, memory and numeric request/response interfaces |
| Memory ownership and sharing | Bank table, parameter-count formula, row-major and head addressing, residual lifetime, in-place normalization restrictions and prohibition of unsafe linear aliasing; one exclusive sequential dot engine |
| Proposed precision/configuration | Dimensions and count bounds, arithmetic storage/intermediate widths, rounding and saturation, constants, primitive domains and proposed accuracy targets; explicitly uncalibrated |
| Bounded unresolved primitives | rsqrt, GELU, exponential and reciprocal input/output formats, domains, response/error protocol and proposed optional watchdog bound; algorithms remain open |
| HTML/LaTeX consistency | Build synchronizes the Markdown RTL specification/checklist into canonical LaTeX and embeds that exact source in HTML. Browser checks compare embedded and downloaded source byte content |
| Standalone RTL specification and Amit checklist | RTL-specification.md and Amit-review-decisions.md |

## Source audit

Inspected current bcjrformer.py and modules.py in BCJRFormer, revision c7cf84e218730f4583e79af6dd876b04384d33f5; scoped git status reported no changes. The model source was not modified.

Confirmed: input LN/linear/LN; learned position and sequence tables; pre-normalized attention and FFN residual order; separate biased Q/K/V and output projections; FFN D-to-4D/GELU/4D-to-D; layer-specific parameters; binary output projection; query-row padding-mask broadcast; fully masked finite-sentinel rows; and M=1 bypass versus M>1 aggregation with a fully-valid-slot denominator. The C=0 hardware error is explicitly a proposed guard, not identical nonfinite source behavior.

## Verification evidence and limits

The browser verifier runs offline, traverses all 50 views at desktop and mobile widths, checks back navigation and required FSM pages, renders screenshots, validates section counts and KaTeX, checks exact source/download content, tests source toggle and table-of-contents navigation, and checks document/boundary mobile overflow. Results are recorded in .architecture-assets/review-checks.json. The overflow checks do not constitute a pixel-by-pixel audit of every mobile diagram.

Native LaTeX typesetting remains unverified because no pdflatex, lualatex or tectonic executable was found. HTML conversion renders 116 mathematical expressions and seven figures successfully; this is not a native PDF compilation. The deliverable is an HTML review package and synchronized LaTeX source, not a newly compiled PDF.

No checkpoint/configuration calibration, primitive implementation, bit-accurate model, RTL simulation, synthesis or supervisor approval is claimed. Optional static masking is outside the proposed baseline and requires a separate configuration decision. SRAM feasibility, numerical error and throughput cannot be concluded from symbolic architecture alone. These are next-phase gates in the specification and checklist, not completed results.
