# Contributing

Open an issue with the relevant RTL path, configuration, expected behavior, and a minimal reproducer. For numerical findings, identify the represented input, binary scale, rounding rule, and whether the comparison concerns the function output or later tensor storage.

Changes should preserve ready/valid stability, memory-write completion barriers, and the canonical parameter layout. Run `python scripts/check.py smoke` for structural/documentation changes; run `numerics` and the relevant cycle/proof checks for arithmetic changes. The `full` suite is the implementation regression.

State the checks you actually ran. Do not describe a passing toy fixture as trained-model accuracy or hardware performance. Update the architecture/numerics documentation when behavior or precision changes.

The project uses a [custom restrictive license](LICENSE.md). Obtain prior written permission before using or modifying the original materials, including when preparing a contribution. Discuss contribution rights with the maintainer before submitting work intended for redistribution. Submitting a contribution does not automatically grant a general license to your work.
