# Critical review after the RTL corrections — 17 October 2026

Reviewed production baseline: `29ec5a4df7331fb288665f82582899b28a6e3b3c`.
This is a fresh review of the corrected implementation, not a replacement for
the [original findings](RTL-CRITICAL-REVIEW-2026-10-17.md) or their
[correction checkpoint](../rtl/RTL-REVIEW-FIXES-2026-10-17.md).
The [review evidence](../evidence/post-fix-critical-review-2026-10-17.json)
records the unchanged source hashes, methods and fresh check results.

## Result

Together, three independent critical reviewers and the primary reviewer inspected all
39 production SystemVerilog files. **No new confirmed functional RTL defect was
established in this pass.** The reviewers challenged control flow, numerical
widths, reset/error behavior, routing and storage rather than accepting the
earlier passing tests as sufficient evidence. No production RTL was changed.

This result is not approval for model validation or ASIC sign-off. There is one
reproduced numerical caveat below, and important validation work remains.

## Numerical caveat: aggregation is a two-rounding approximation

[aggregation_ctrl.sv:11](../../rtl/control/aggregation_ctrl.sv#L11) multiplies the sum by a previously rounded Q32
reciprocal, then rounds to the output format. It can differ from dividing the
sum exactly and rounding just once.

An actual aggregation controller connected to the actual reciprocal unit,
with a modeled memory responder, completed this case successfully in 37 cycles:

| Quantity | Result |
|---|---|
| Shape | M=6, N=1 |
| Padding | All six logits unmasked |
| Raw signed16/F10 logits | `[1, 1, 1, 0, 0, 0]` |
| Raw sum | 3 |
| Q32 reciprocal of six | 715827883 |
| Actual stored output | Raw 1, or 1/1024 |
| Exact division followed by nearest-even rounding | Raw 0 |

The reciprocal is slightly above 1/6, so its product is slightly above the
halfway point. Exact 3/6 is a tie and rounds to the even integer zero.

This is **not a violation of the declared fixed-point contract**:
[the specification](../rtl/RTL-specification.md) explicitly defines reciprocal
rounding followed by multiplication and output rounding. There is no approved
exact-average requirement or final-logit error tolerance. Preserve this case
when calibrating against the selected reference. If a single correctly rounded
average is required, the implementation and its numerical contract must change.

Reproduce from the repository root after installing the development tools:

```sh
python docs/evidence/review-reproducers/aggregation_rounding.py
```

The script writes only ignored artifacts under `rtl/tests/tmp/post-fix-critical-review`.
Its successful result confirms the observed approximation; it is not an
exact-average accuracy pass.

The LayerNorm constant-row failure from the first review was different: its
mean error was amplified by inverse square root. That implementation was fixed;
this aggregation observation does not reopen that finding.

## Coverage

| Scope | Files | Review focus |
|---|---:|---|
| `rtl/control/*.sv` | 21 | All stage/leaf FSMs, handshakes, counters, extents, aliasing, manifest offsets, padding, committed-write barriers, fatal/recoverable completion |
| `rtl/arithmetic/*.sv` | 8 | Signedness, intermediate bounds, nearest-even conversion, overflow/domain errors, Taylor remainders and rounding, MAC modes, reciprocal and root midpoint logic |
| `rtl/protocol/*.sv` | 4 | Arbitration, owner retention, request capture, response stalls, reset cancellation and bank dispatch |
| `rtl/memory/*.sv` | 3 | Address/format validation, permissions, physical word widths, sign extension, exact F10-to-F22 promotion and native hidden reads |
| `rtl/interfaces/*.sv` | 2 | Packed types, modport directions, field widths and numerical contracts |
| `rtl/bcjrformer_core.sv` | 1 | Complete wiring, shared engines, client indices, configuration bounds and parameter layout |

All 29 public declarations in `bcjrformer_ports.svh` were also crosschecked
against their implementations. Two default expressions use an equal literal
instead of the shared constant; there is no current value mismatch. Relevant
verification harnesses, proof assumptions, check-group selection, the generic
cycle interpreter and numerical/architecture documentation were reviewed too.

## Fresh checks

- Actual core-controller bounded scenario 20 passed at 128 cycles: an illegal
  commit during a stalled output preserves the output, drains accepted work,
  then reports a fatal completion and locks until reset.
- Actual core-controller bounded scenario 11 passed at 128 cycles: a stalled
  original completion stays stable, then a separate fatal completion reports
  the late commit. Both scenarios require completion by the final proof step.
- The 13-client router safety proof passed at 24 steps.
- Independent mathematical/integer checks covered every represented GELU
  input, 25,005 EXP inputs and 10,004 legal RSQRT inputs. The GELU maximum
  absolute error was approximately 2.324991e-7; sampled EXP maximum error was
  approximately 1.192111e-7. These are reference checks, not exhaustive RTL
  equivalence proofs.
- Taylor remainder, tail and finite-precision budgets were independently
  re-derived. Both function-output budgets remain below 1e-5. GELU recurrence
  magnitude and numerator bounds fit their declared 128/160-bit paths.
- The aggregation caveat above was reproduced with actual controller and
  reciprocal RTL, separately from the integer reference.
- A separate actual-RTL sweep passed all 65,536 represented GELU inputs and
  12,289 EXP inputs against independent `math.erf`/`math.exp` expectations.
  It executed 1,040,446 cycles. Maximum observed errors were approximately
  2.324991e-7 for GELU and 1.192012e-7 for EXP, both below 1e-5. This exhausts
  GELU's input values under the tested transaction schedule, not every possible
  protocol/reset sequence; EXP inputs are sampled. Execution remains two-state.

Reproduce the nonlinear RTL sweep from the repository root:

```sh
python docs/evidence/review-reproducers/nonlinear_function_sweep.py
```

This rebuilds the arithmetic netlist, writes ignored fixtures, and can take
several minutes. It supplements the existing arithmetic vector tests; it does
not establish whole-network numerical accuracy.

The previously passing full implementation suite and GitHub run remain
separate evidence; they were not all rerun in this review.

## Remaining gates

1. Select the trained checkpoint and floating-point/decoding reference. Agree
   the mask/aggregation semantics and numerical acceptance tolerances; current
   formats remain provisional.
2. Run four-state event-driven simulation and broader fault/reset insertion.
   Current cycle execution is two-state. Leaf-controller states and very large
   legal configurations are not exhaustively covered.
3. Assess full-size execution and liveness. Bounded proofs use small memories;
   fixed-priority routing provides no general fairness guarantee and a service
   that never responds can prevent completion.
4. Select the technology, clock target and SRAM mapping, then measure area,
   timing and power. Wide division/modulo and root search have no physical
   feasibility or timing sign-off yet.

No reviewer claims that every possible bug has been ruled out. The evidence
supports continuing the walkthrough and planning validation, not freezing the
numerical design or approving silicon.
