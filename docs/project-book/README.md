# BCJRFormer ASIC project book

**Draft for review.** The report follows the selection of the BCJRFormer paper, the software reference, the five-stage architecture and RTL microarchitecture, and the available RTL simulation, synthesis, and post-route implementation evidence.

- [Read the PDF](BCJRFormer-ASIC-Project-Book.pdf).
- [Download the Overleaf ZIP](BCJRFormer-ASIC-Overleaf.zip) or browse the [editable LaTeX source](overleaf/main.tex). In Overleaf, choose **New Project → Upload Project** and select the ZIP.
- [Read the independently reviewed plan](BCJRFormer-Project-Book-Plan.md).

## Review notes for Hamid and Rotem

- **Pages 1–5.** Check whether the objective, paper selection, and software-to-RTL handoff explain what the team implemented and what the software handles.
- **Pages 6–14.** Check that the architecture overview gives enough context for the equations and stage details. Verify the datapath, parameter-loading route, write acknowledgements, and memory completion barriers against the RTL.
- **Results and conclusions.** Check the distinction between the ten-frame trained RTL campaign and the separately synthesized and routed small core. Review the 300 ns post-route timing, physical checks, and scope of the remaining foundry verification and power work.

Please include the page or figure number with each comment so we can locate it in the LaTeX source. Project materials are covered by the [repository license](../../LICENSE.md).
