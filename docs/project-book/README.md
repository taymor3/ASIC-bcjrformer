# BCJRFormer ASIC project book

**First draft for review.** The 20-page report follows the selection of the BCJRFormer paper, the software reference, the five-stage architecture and RTL microarchitecture, and the available verification and synthesis evidence.

- [Read the PDF](BCJRFormer-ASIC-Project-Book.pdf).
- [Download the Overleaf ZIP](BCJRFormer-ASIC-Overleaf.zip) or browse the [editable LaTeX source](overleaf/main.tex). In Overleaf, choose **New Project → Upload Project** and select the ZIP.
- [Read the independently reviewed plan](BCJRFormer-Project-Book-Plan.md).

## Review notes for Hamid and Rotem

- **Pages 1–5.** Check whether the objective, paper selection, and software-to-RTL handoff explain what the team implemented and what the software handles.
- **Pages 6–14.** Check that the architecture overview gives enough context for the equations and stage details. Verify the datapath, parameter-loading route, write acknowledgements, and memory completion barriers against the RTL.
- **Pages 15–19.** Check that the one trained-frame comparison and the smaller Design Compiler synthesis run are clearly identified. Flag any ambiguity in the area units, constraints or slack, and confirm the scope of the power, PrimeTime, and post-route evidence still needed.

Please include the page or figure number with each comment so we can locate it in the LaTeX source. Project materials are covered by the [repository license](../../LICENSE.md).
