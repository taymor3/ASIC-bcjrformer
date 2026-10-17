# Provenance and rights

This is a standalone publication of the project's hardware implementation, architecture, microarchitecture, authored reports, presentations, diagrams, interactive pages, supporting tools, and checks. The publication excludes unrelated reference papers, the third-party model checkout, trained weights, local tool installations, generated netlists, and personal machine configuration.

## Hardware and documentation

The original project materials are covered by the [Viewing and Prior Written Permission License](LICENSE.md), copyright (c) 2026 Taimor Sabek and Haiel Bader. Viewing is permitted; use beyond the license's viewing and hosting permissions requires prior written permission from the copyright holders. This is a custom restrictive license, not an open-source license. The MIT license in the separate model repository is not applied to this RTL. Third-party components and excerpts retain their own license terms.

The repository contains AI-assisted implementation and documentation work. It remains a provisional research design with the review and validation limits described in the README and verification guide.

## Model background

The inspected model checkout is a separate BCJRFormer repository with an MIT notice naming Julian Streit (2025) and yoniLc (2022). The upstream model source is [streit-julian/BCJRFormer at c7cf84e218730f4583e79af6dd876b04384d33f5](https://github.com/streit-julian/BCJRFormer/tree/c7cf84e218730f4583e79af6dd876b04384d33f5), as cited in the authored technical report. The full checkout, original figures/thesis, and weights are not vendored. Authored reports and code presentations contain attributed model excerpts; the inspected upstream [MIT notice is retained](rights/BCJRFormer-MIT.txt) for those excerpts. Model behavior informed the hardware contracts; the documented per-position aggregation rule intentionally differs from specific branches of the inspected software. Confirm the selected trained configuration before claiming model equivalence.

## External references

- [ama-riscv](https://github.com/AleksandarLilic/ama-riscv) informed documentation organization only. None of its GPL-3.0 source, text, or diagrams is copied.
- [NIST DLMF, error-function power series](https://dlmf.nist.gov/7.6.E1) and [exponential function](https://dlmf.nist.gov/4.2) are mathematical references for the Taylor derivations.
- Python, Node.js, slang/pyslang, YoWASP Yosys, and their dependencies are external tools installed separately under their own terms. No tool binaries or third-party packages are bundled.
- The rendered technical explorer embeds KaTeX-rendered mathematics/fonts and carries its included MIT notice. The original KaTeX notice is also retained at [rights/KaTeX-MIT.txt](rights/KaTeX-MIT.txt). Optional regeneration fetches KaTeX 0.16.22 separately.

This notice records scope and provenance; it is not a substitute for a license or a complete legal provenance audit.
