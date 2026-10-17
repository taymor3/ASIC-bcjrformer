# Project library

The project combines current hardware with earlier architecture-development artifacts. Use the [current architecture](architecture.md), [microarchitecture](microarchitecture.md), and [Taylor numerics](numerics.md) as the publication baseline. Older reports and decks remain valuable design history; their unfinished-RTL or lookup-table statements are not current implementation status.

## Current implementation and review

- [Complete RTL assembly](../rtl/bcjrformer_core.sv), [ordered sources](../rtl/protocol/files.f), and [connection inventory](../rtl/RTL-CONNECTIONS.md).
- [Detailed stage specification](rtl/RTL-specification.md), [interface contracts](rtl/RTL-interfaces.md), and [Stages 3–5 design](architecture/Stages3-5-design.md).
- [Complete implementation checkpoint](rtl/RTL-COMPLETE-CHECKPOINT.md), [Taylor checkpoint](rtl/RTL-TAYLOR-CHECKPOINT.md), and [review ledger](rtl/RTL-COMPLETE-REVIEW.md).
- [Verification sources](../rtl/tests) and [recorded source-hashed evidence](evidence/implementation-2026-10-16.json).

## Diagrams

- [New five-stage microarchitecture](images/bcjrformer-microarchitecture.svg) and [encoder detail](images/bcjrformer-encoder-detail.svg).
- [Editable all-stage draw.io document](../diagrams/drawio/BCJRFormer_all_stages.drawio), [frame controller](../diagrams/drawio/Frame_controller.drawio), and [stage sources](../diagrams/drawio).
- [Stage/FSM/shared-block exports](../images).
- [Earlier generated architecture review](../output/architecture/README.md), with local HTML, editable diagrams, and machine-readable model. This October 10 snapshot predates complete processing RTL.

## Authored reports

- [Design-review PDF](../output/pdf/BCJRFormer_design_review_Amit.pdf) and [editable LaTeX](latex/BCJRFormer_design_review_Amit.tex).
- [Architecture report v5](latex/bcjrformer_asic_architecture_v5.tex); [earlier report sources](latex) preserve the design's development history.
- [Architecture checkpoint](architecture/ARCHITECTURE-CHECKPOINT-1.md), [review decisions](reviews/Amit-review-decisions.md), and [review audit](reviews/ARCHITECTURE-REVIEW-AUDIT.md).
- [Provisional architecture budget](planning/ARCHITECTURE-BUDGET.json) is an estimate, not a selected device or measured hardware result.

## Presentations

- [Architecture deck](../presentation/BCJRFormer-Architecture-Amit.pptx).
- [Architecture with model-code excerpts](../presentation/BCJRFormer-Architecture-Amit-with-code.pptx).
- [Reviewed architecture/code deck](../presentation/BCJRFormer-Architecture-Amit-with-code-reviewed.pptx).
- [Speaker notes](../presentation/BCJRFormer-speaker-notes.md) and [code-deck notes](../presentation/BCJRFormer-speaker-notes-with-code.md). The older reviewed-notes export is retained in the same directory; some entries are incomplete.

## Interactive pages and tools

- [Architecture explorer and full technical document](../web/bcjrformer-architecture.html).
- [Connected RTL block/signal explorer](../web/rtl-connected-blocks.html).
- [Tooling and regeneration guide](tooling.md).

Open HTML files locally, or serve the repository with `python -m http.server 8000` and open `http://localhost:8000/web/bcjrformer-architecture.html`. GitHub displays HTML source rather than executing these explorers; GitHub Pages deployment is a separate action.

## External background

The upstream model is [BCJRFormer](https://github.com/streit-julian/BCJRFormer/tree/c7cf84e218730f4583e79af6dd876b04384d33f5). External papers and course material are referenced by the reports rather than redistributed. See [rights and provenance](../NOTICE.md).
