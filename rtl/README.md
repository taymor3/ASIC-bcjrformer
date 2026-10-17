# BCJRFormer RTL

The complete provisional implementation is in `bcjrformer_core.sv`; `protocol/files.f` is the ordered production source list. Review [the complete checkpoint](../docs/rtl/RTL-COMPLETE-CHECKPOINT.md) and [review ledger](../docs/rtl/RTL-COMPLETE-REVIEW.md) before numerical validation.

All public modules have real implementations. Internal helpers centralize projection/row loops, fixed-point conversion, and held primitive responses. Interface types are in `interfaces/bcjrformer_contract_pkg.sv`; generated public declarations are in `interfaces/bcjrformer_ports.svh`.

Configure F/M/N/D/H/K explicitly. The complete wrapper derives a canonical packed manifest and native-element memory capacities; it rejects static masks. Numeric widths and methods are provisional. Memory arrays are behavioral backing stores awaiting target-specific mapping. Arithmetic uses synthesizable integer logic; combinational division/root search and wide products require later area/timing assessment.

16 October update: EXP and GELU use sequential Taylor arithmetic, not function-value ROMs. See [Taylor error derivation](../docs/rtl/RTL-TAYLOR-CHECKPOINT.md). No table filename parameters or `$readmemh` calls remain in the production nonlinear units. GELU's result is signed32/F22 (`gelu_t`); `ffn_ctrl` explicitly converts it for the existing signed16/F10 activation bank.

Generate a manifest using actual supplied dimensions, for example this **test fixture**:

```text
python rtl/scripts/parameter_manifest.py --f 2 --m 2 --n 2 --d 2 --h 1 --k 2 --out rtl/tests/multi-manifest.json
```

To pack raw signed Q10 tensors, also supply `--tensor-json` and `--image`. The tool requires the exact tensor names and element counts and rejects out-of-range raw integers. It does not quantize or select a trained checkpoint. Generated test fixture images are not production weights.

Run compilation and tests from the project root. The complete checkpoint lists reproduction commands. Python runners use the existing `rtl/.tools` packages. `tests/cycle_simulator.cjs` executes vector netlists from the actual RTL; Python reference fixtures independently predict the complete scratch-write sequence. Formal conversion and bounded router/memory regressions supplement those deterministic frame tests.

`tests/complete-evidence.json` records explicit passing evidence, Taylor error budgets and production source checksums. Historical checks remain in their earlier checkpoint documents. No inference-accuracy or silicon-performance approval is implied by passing RTL implementation checks.
