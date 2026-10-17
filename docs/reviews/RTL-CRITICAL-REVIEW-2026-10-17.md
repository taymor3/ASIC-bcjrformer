# Critical RTL review — 17 October 2026

The source review is complete for **all 39 production SystemVerilog files** in
`rtl/protocol/files.f`, plus the declaration-only ports header, integration
contracts, and the relevant verification code. Three reviewers challenged the
primary reviewer independently across controllers, arithmetic, and memory and
protocol logic. The exact source inventory, hashes, and new evidence are in the
[review evidence](../evidence/critical-review-2026-10-17.json).

**This is not validation approval.** A LayerNorm numerical invariant violation
was reproduced in actual RTL, and the stored GELU precision does not meet a
10^-5 requirement if that requirement includes FFN storage. Configuration hazards
and verification gaps also remain. Production RTL was not modified in this pass.
No other functional FSM/protocol defect was established under the documented
valid configurations; that is not a guarantee of bug freedom.

The reviewed source baseline is commit
`731bcb2febe67312100a00d572bd663b544685ba`. Report/reproducer additions do not
change those production source hashes. Earlier passing results remain historical
implementation evidence and do not resolve the findings below.

## Findings

### R1 — LayerNorm can turn a constant vector into a nonzero vector

**Confirmed numerical failure mode; address before numerical sign-off.**

[layernorm_ctrl.sv](../../rtl/control/layernorm_ctrl.sv#L21) forms its mean by
multiplying the sum by a previously rounded Q32 reciprocal from
[inverse_count](../../rtl/arithmetic/fixed_math_pkg.sv#L42). The resulting mean
bias is amplified by inverse square root near zero variance. The integer
reference uses the same reciprocal approximation, so a bit-exact match against
that reference does not detect this mathematical deviation.

A fresh lowered-RTL simulation of the actual LayerNorm controller and RSQRT
unit used a simple memory responder returning these exact values:

| Quantity | Value |
|---|---:|
| Vector length | 768 |
| Every input, raw signed16/F10 | 32767 |
| Every gamma, raw signed16/F10 | 1024 (1.0) |
| Every beta | 0 |
| Mathematical LayerNorm result | 0 |
| First actual stored result | 1/1024 = 0.0009765625 |
| Fatal error | None |

The first incorrect write was observed at cycle 3085. This test uses the real
numerical RTL but a constant-value memory test service; it is not a full-core
execution at width 768. The count and values fit the production contracts.

An independently checked exact-integer counterexample at length 65355 produces
`-79/1024 = -0.0771484375` instead of zero. Its Q32 inverse is 65718, mean is
33553663 in F20 instead of 33553408, centered value is -255, and variance plus
epsilon is 43204. All intermediates fit; RSQRT accepts the variance; no clipping
or fatal check catches the deviation. A core configuration with `F=65355, D=2,
M=N=H=K=1` admits that first normalization and has 261507 parameter words.
Selecting one normalized feature into one projection output, with the other
output zero, can further amplify the bias in the second normalization.

Recommended correction: calculate the mean with adequately precise division
or a rigorously bounded higher-precision reciprocal, then separately assess
variance accuracy. Add constant-vector tests at non-power-of-two lengths and
range extremes, comparing to mathematical normalization independently of the
bit-exact implementation. No LayerNorm error tolerance has yet been approved;
this finding establishes a numerical deviation, not violation of an invented
global 10^-5 LayerNorm contract.

Reproduce the actual-RTL observation with:

```sh
python docs/evidence/review-reproducers/layernorm_constant.py
```

The reproducer reports the observation and whether the mathematical invariant
holds. Its successful execution is evidence of the counterexample, not a
passing LayerNorm accuracy test.

### R2 — FFN storage discards the GELU function's precision

**Confirmed storage error; a requirement conflict if 10^-5 covers stored uses.**

The Taylor primitive returns signed32/F22 within its documented function-output
error budget. [ffn_ctrl.sv](../../rtl/control/ffn_ctrl.sv#L17) then rounds that
result back to signed16/F10 before writing `BANK_FFN_HIDDEN`.

For represented input 1.0:

| Result | Value |
|---|---:|
| Exact GELU(1) | 0.8413447460685428 |
| Primitive F22 result | 0.8413448333740234 |
| Stored FFN F10 result | 0.841796875 |
| Stored absolute error | 0.000452128931457 |

This exceeds 10^-5. The Taylor implementation itself is not the source of that
error. The storage boundary is already documented in the Taylor checkpoint;
documentation does not make an end-to-end stored-value precision goal satisfied.

Before validation, explicitly resolve the requirement. If every stored GELU
result must preserve 10^-5 absolute accuracy relative to its represented input,
widen the hidden bank and the consuming linear/dot path with matching format,
manifest, overflow, and test changes. Increasing Taylor degree cannot repair
F10 storage rounding. No widening was performed during this review.

### R3 — LayerNorm epsilon and RSQRT minimum are independently configurable

**Configuration composition hazard; defaults are compatible.**

The guard in [layernorm_ctrl.sv](../../rtl/control/layernorm_ctrl.sv#L15) permits
positive raw epsilon below 42950. The default
[rsqrt_unit.sv](../../rtl/arithmetic/rsqrt_unit.sv#L9) rejects variance below
42950. A constant vector and a smaller accepted LayerNorm epsilon can therefore
fail numerically when those two otherwise valid module configurations are
connected. Lowering the RSQRT minimum also requires a representable result;
raw variance at or below 256 overflows unsigned32/F20, and the unit correctly
reports that overflow.

Share or validate these domain constraints at composition time. The canonical
core's present default epsilon and minimum both equal 42950, so this is not a
failure of that default assembly.

### R4 — Dedicated error/reset coverage is incomplete

**Verification gaps; no associated controller defect established.**

- The embedding error case in
  [stage12_control_formal.sv](../../rtl/tests/stage12_control_formal.sv#L55)
  fails the first normalization. It does not separately inject failure during
  the second normalization after the linear result has been committed.
- Its reset triggers at
  [line 73](../../rtl/tests/stage12_control_formal.sv#L73) do not specifically
  target outstanding linear work, second normalization, final output copying,
  or a held final response. Test those boundaries and subsequent restart.
- Final projection needs dedicated early/late linear-error, unclassified-error,
  held-completion, and reset cases. Aggregation needs reciprocal error/bad tag/
  zero result, delayed response, reset, and output-write failure after an earlier
  position has committed. Complete inference fixtures do not individually
  establish these fault branches.

The earlier missing `F>D` execution case was exercised in this pass: a freshly
lowered full core with `F=3,D=2,M=1,N=3,H=1,K=1` completed four frames,
711 computational-write comparisons, and 28569 cycles, including padded and
empty-position behavior. This closes that specific fixture gap, not the full
dimension space.

### R5 — The maintained full group omits important memory proof cases

**Regression selection gap.**

[scripts/check.py](../../scripts/check.py) runs the router with five clients
and only the `fast` memory case in its `full` group. That memory case is a
single client, one-cycle delays, and signed16 bank X. The fixture makes its
request fields legal for that selected-bank mode. It therefore does not enforce
regression coverage of malformed requests, competing clients, unauthorized
parameter/mask writes, or all bank widths.

Add the existing `control` case and representative signed48, unsigned24, and
mask cases to the maintained regression, and use the actual 13-client router
case. Fresh review proofs passed those representative cases, but they remain
bounded checks at depth two and 16/24 time steps.

### R6 — Synthesis-only integrations can miss an undersized host index

**Integration hazard; correctly instantiated hosts are safe.**

`bcjr_host_if` defaults to `INDEX_W=1`. The guard in
[core_ctrl.sv](../../rtl/control/core_ctrl.sv#L51) checks the output count against
the actual host width during ordinary elaboration; `SYNTHESIS` excludes it.
An integration using `N=3` with the default one-bit index can therefore truncate
indices and empty-position reports in a synthesis-only flow that bypasses the
normal check. Enforce the width in the concrete integration/preflight as well
as the simulation check. This is not a failure of the correctly configured
host instances in the tested core fixtures.

## Other unresolved validation limits

- Actual RTL is tested through a two-state Yosys-cell interpreter, not a
  four-state/event-driven simulator. Exhaustive Python GELU sweeps do not prove
  exhaustive RTL equivalence. Arithmetic RTL vector tests are sampled.
- Router/memory proofs are bounded. The fixed-priority router is not generally
  fair, and there is no timeout when an endpoint never responds. The current
  serial schedule avoids requiring competing-client fairness; arbitrary-delay
  full-core liveness has not been established.
- Wide combinational division/modulo and the RSQRT root-search chain need
  synthesis/technology timing and area assessment. Behavioral arrays have no
  selected physical SRAM implementation. No silicon failure or feasibility
  claim can be inferred from functional tests alone.
- Select the trained model/checkpoint and numerical acceptance criteria before
  calling the design validated. Query-only padding, all-key attention, and the
  corrected per-position aggregation policy need explicit agreement with the
  selected reference. They are documented choices, not newly discovered FSM bugs.

## Checks run during this review

| Check | Fresh result and scope |
|---|---|
| Complete/protocol elaboration and inventory | 0 errors/warnings; 29 public kinds, 65 endpoints |
| Manifest/image round trips | Three shapes passed |
| Asymmetric complete-core execution | Fresh full RTL; 4 frames, 711 compared writes, 28569 cycles |
| Constant-vector LayerNorm | Fresh actual controller/RSQRT; nonzero first result reproduced at length 768 |
| Arithmetic vectors | Freshly rebuilt actual arithmetic RTL; 847 vectors, 7706 cycles passed |
| Taylor bounds and model sweeps | Rational budget checks; 65536 Python GELU inputs and 12289 EXP samples passed |
| Conversion proof | Exhaustive specified signed48/F20 to signed16/F10 conversion passed |
| Router | 13-client, 24-step bounded proof passed |
| Connected memory control | 3 clients, delays 2/3, arbitrary request fields, 16 steps passed; data comparison disabled |
| Memory data cases | Bank X fast, signed48 SCORE, unsigned24 EXP, and BIT MASK; depth two, 16 steps passed |

The full historical controller suite and every historical full-core shape were
not rerun in this pass. Source inspection and fresh targeted checks complement
the archived evidence; neither is exhaustive verification of the full core.

## Disposition

Resolve R1 and the stored-value requirement in R2 before numerical sign-off.
Couple configurable arithmetic domains, add the missing fault/reset tests, and
expand mandatory memory regression coverage before claiming broad robustness.
Review and fixes are separate: this report records the review; it does not
silently change the design or approve validation.
