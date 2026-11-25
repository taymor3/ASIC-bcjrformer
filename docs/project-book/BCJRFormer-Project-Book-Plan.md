# BCJRFormer ASIC project book plan

The book uses a 20-page A4 research-report format. It opens with a title, abstract, and objective, and then traces the research choice, software reference, hardware design, verification, and synthesis evidence.

| Pages | Material |
| --- | --- |
| 1–3 | Abstract, objective and contributions, evidence matrix, literature review, and paper selection |
| 4–5 | Noisy-read feature representation, output meaning, software workflow, and trained-checkpoint handoff |
| 6–9 | Core boundary, five-stage overview, embedding and position, Transformer encoder, projection, and aggregation |
| 10–14 | Shared arithmetic, parameter-load path, parameter and scratch memory, ready/valid, and fixed-point arithmetic |
| 15–17 | Verification methodology, trained-frame results, directed regressions, and reproduction instructions |
| 18–19 | Small-core synthesis, cell area, timing, and remaining physical evidence |
| 20 | Conclusions, next verification steps, and references |

## Critical review changes

- Put the abstract and objective on the first page. Reserve the most space for the design, observed results, and reproduction.
- Separate paper claims, recorded small RTL fixtures, the one-frame trained-model comparison, and the small-core synthesis experiment. Put source and configuration details beside the result tables.
- Describe padded queries explicitly. Show the mathematical mean over valid read slots and explain the hardware's reciprocal and rounding. Record the zero-valid-read case and publication rule.
- Trace one parameter write through the actual host, controller, router, fabric, and memory adapter. Distinguish per-word acknowledgment from image commit.
- Report mapped cell area in report units. Attribute the 200 ns results to the Design Compiler session log. Mark power, PrimeTime and post-route timing as unavailable for verification.

The plan was reviewed independently before authoring. The report diagrams are native LaTeX/TikZ and the bibliography is part of the source.
