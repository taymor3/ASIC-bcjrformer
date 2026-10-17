# Complete provisional RTL checkpoint

16 October update: EXP/GELU ROMs have been replaced by Taylor arithmetic with Lagrange-derived error budgets below 10^-5 at their function outputs. GELU now returns signed32/F22; FFN separately converts to signed16/F10 storage. Table path parameters were removed. See `RTL-TAYLOR-CHECKPOINT.md` and current `complete-evidence.json`; the 13 October numerical-method and test-count descriptions below record the earlier baseline.

13 October 2026. Taimor authorized completion of the remaining RTL and explicitly selected implementation of the draft fixed-point formats as provisional for Haiel's later validation. This supersedes the implementation-status paragraphs in the earlier checkpoints, which remain historical records of their own tests.

## Implementation

All 29 public module kinds now have implementations. The production list contains 39 SystemVerilog sources, including internal helpers and the complete `rtl/bcjrformer_core.sv`. No numerical completion model or placeholder arithmetic is instantiated in that core.

The completed work includes:

- Score-row and weighted-value controllers, with a shared internal row loop: Q/K head slices, all-key iteration, unsigned probability-by-value dots, widened score scaling, and committed SCORE/Z writes.
- The sequential dot engine and linear controller: bias alignment, output-major weights, native-element strides, signed48/F20 and signed64/F32 accumulation modes, overflow checks, and one destination conversion per linear output.
- Softmax: maximum initialized from the first score, wide subtraction/clipping, exp/store/sum, reciprocal, probability writes, and a uniform padded-query path using the same probability writer.
- LayerNorm: exact sum and centered-square passes, stored Q32 inverse length, signed32/F20 mean and normalized values, unsigned96/F40 square accumulation, full-width variance conversion, epsilon, RSQRT, affine conversion, and in-place-safe writes.
- FFN: complete first linear, in-place GELU replacement of all hidden entries, second linear, and completion after its writes commit.
- Residual and positional additions: both operands captured before replacement and signed activation saturation. Stage 2 preserves its two separate addition/conversion points.
- Final projection and per-position aggregation: no sigmoid, one shared valid bit for sum/count, count-derived reciprocal, private OUTPUT writes, and recoverable EMPTY_POSITION with no partial frame publication.
- MAC, EXP, reciprocal, RSQRT and GELU units, tagged registered responses, response stability, numerical domain checks, and reset cancellation.
- Complete integration of the five stages, encoder hierarchy, two norm callers, five linear callers, three dot callers, two reciprocal callers, and 13 memory clients.

Dimensions remain explicit integration parameters. Defaults do not choose a trained model. The complete wrapper uses a canonical packed tensor manifest; `rtl/scripts/parameter_manifest.py` emits its tensor bases, dimensions, constants, bank capacities, and optional raw-Q10 parameter image/checksums. Static masks are rejected. The behavioral parameter/scratch stores retain contents on reset; image validity is reset by the host controller.

## Provisional numerical methods

Stored ACT/weights/logits are signed16/F10. Scores are signed48/F20; probability and exp storage are unsigned24/F22. The existing public interface types remain unchanged. `rtl/arithmetic/fixed_math_pkg.sv` centralizes nearest-even conversion, clipping and status flags. Intermediate overflow is fatal; stored activation saturation is nonfatal.

EXP uses 16385 rounded Q22 knots over [-16,0], at spacing 1/1024, with integer linear interpolation and nearest-even output conversion. Positive inputs are errors; values below -16 return zero. EXP(0) is exactly 1. The interpolation/quantization bound for the retained interval is approximately 3.58e-7 absolute, below the draft 2^-20 target; this analytic bound does not establish inference accuracy.

GELU uses a ROM entry for every representable Q10 input in [-8,8], generated from x*Phi(x). Outside that interval it uses the documented zero/input tails. This implements the draft exact-GELU target at the stored input resolution, without substituting a tanh approximation. Within the table, final quantization contributes at most half an ACT LSB.

Reciprocal uses integer division with nearest-even quotient rounding. RSQRT uses integer division, integer square-root search and an exact midpoint comparison for nearest-even output rounding. These are synthesizable baseline methods, not area/timing-optimized implementations. Large dividers, the combinational root search, wide scalar products and ROMs require synthesis/technology review. No silicon performance is claimed.

ROM contents and generator metadata/checksums are in `rtl/arithmetic/tables`; regenerate with `rtl/arithmetic/generate_tables.py`. Run from the project root, or override the table-file parameters when integrating elsewhere. Approximation flags report non-exact primitive results; they are retained with the held response.

## Verification

The final evidence is summarized in `rtl/tests/complete-evidence.json`. The test shapes below are fixtures, not selected hardware/model requirements.

| Check | Evidence / result |
|---|---|
| Complete single and multiple assembly elaboration | 0 errors, 0 warnings |
| Existing connected protocol elaboration | 0 errors, 0 warnings |
| Public port/connection inventory | 29 module kinds, 65 endpoints |
| Synthesis-frontend structural checks | Complete single, multi and heads assemblies; zero structural problems |
| Primitive cycle checks | 841 vectors across MAC, EXP, reciprocal, RSQRT, GELU and local addition; errors, flags, tags, held responses and reset |
| Conversion proof | Exhaustive signed48/F20 to signed16/F10 nearest-even rounding/saturation, including independent flag checks |
| Single-element complete core | F=M=N=D=H=K=1; four frames; 112 checked intermediate writes |
| Two-layer complete core | F=2,M=2,N=2,D=2,H=1,K=2; four frames; 1693 checked intermediate writes |
| Three-head complete core | F=2,M=1,N=2,D=3,H=3,K=1; four frames; 692 checked intermediate writes |
| Core integration faults/recovery | Wrong feature last, illegal commit during computation, reset during computation/reload/success, EMPTY_POSITION followed by success without reset/reload |
| Manifest/export | Three shapes: exact native-word image round trips |
| Existing router regression | Five clients, 24-step safety proof |
| Existing connected memory regression | Fast-delay configuration, 16-step safety proof |

Complete-frame tests compare **every committed computational scratch write** against an independent Python integer reference, including overwritten TOKEN/VECTOR/FFN/score/exp/probability storage. They check indexed outputs and last, held host reports, retained parameters across frames, normal/all-valid queries, padded uniform rows, partial padding, later empty positions, all-padded frames, and reuse after recoverable completion. Fatal tests check draining, stable reports, readiness locking, reset image invalidation and reload.

Cycle tests execute the actual lowered RTL through a generic Yosys vector-cell interpreter. They are deterministic two-state cycle simulations, not a commercial four-state/event-driven simulator run. The interpreter rejects unsupported cells, non-common clocks, clocked memory reads, undriven/multiply-driven bits, and combinational loops. Uninitialized unused storage bits are represented as zero; the tests rely on the actual load/write sequencing before meaningful reads. No test-only completion or arithmetic service is substituted in the complete assembly. Python reference arithmetic uses an independent magnitude/division formulation; ROM contents are shared because they define the provisional primitive approximation.

The conversion proof is combinational and exhaustive for its specified 48-to-16 path; it does not prove every controller. Existing bounded router/memory proofs retain their original bounds. Deterministic full frames do not prove arbitrary-latency liveness or full-size execution. The earlier 114 controller checks remain recorded historical evidence; they were not all rerun in this pass.

## Review before numerical validation

The complete implementation is ready for the joint RTL review. Review entry points are this checkpoint, `rtl/bcjrformer_core.sv`, the generated manifest, and `rtl/RTL-CONNECTIONS.md`. The review ledger is `RTL-COMPLETE-REVIEW.md`.

Remaining decisions concern the actual repository/checkpoint/model configuration, static-mask absence, trained-image export, supervisor review, numerical calibration against floating point and decoding performance, primitive accuracy acceptance, and physical synthesis/memory/timing feasibility. These are not missing RTL module bodies. Haiel's numerical validation and approval have not been performed by this implementation pass.

## Reproduction

Use the existing Python runtime with `rtl/.tools` available, and Node.js. From the project root:

```text
python rtl/tests/compile_complete.py
python rtl/tests/compile_protocol.py
node rtl/architecture-connections.cjs
python rtl/tests/run_conversion_formal.py
python rtl/tests/arithmetic_vectors.py
python rtl/tests/build_arithmetic_netlist.py
node rtl/tests/run_arithmetic_cycle.cjs
python rtl/tests/fixed_reference.py
python rtl/tests/verify_manifest.py
python rtl/tests/build_cycle_netlist.py single
python rtl/tests/build_cycle_netlist.py multi
python rtl/tests/build_cycle_netlist.py heads
node rtl/tests/run_complete_cycle.cjs single
node rtl/tests/run_complete_cycle.cjs multi
node rtl/tests/run_complete_cycle.cjs heads
node rtl/tests/run_core_fault_cycle.cjs
python rtl/tests/run_formal.py 5
python rtl/tests/run_memory_formal.py fast
python rtl/tests/summarize_complete.py
```

For the two formal regressions, preserve the stdout logs named in the evidence summary. The summary requires their explicit proof-success markers; a process exit code alone is insufficient evidence. Netlists and fixture images are reproducible test artifacts, not production trained weights.
