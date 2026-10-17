# RTL review corrections — 17 October 2026

This implementation addresses R1–R6 in the [critical review](../reviews/RTL-CRITICAL-REVIEW-2026-10-17.md).
The original review and 16 October evidence remain historical records. New
[implementation evidence](../evidence/review-fixes-2026-10-17.json) records the
corrected source hashes and checks. The [current source index](../evidence/rtl-source-current.json)
identifies this revision without rewriting the archived baseline.

## Corrections

| Finding | Implementation and evidence |
|---|---|
| R1: constant-row LayerNorm bias | Mean uses exact nearest-even `(sum << 10) / length` into F20; population variance uses exact nearest-even `squares / (length << 8)` into F32. The premature rounded reciprocal is gone. All 53 actual-RTL normalization cases passed, including positive/negative constant extremes at lengths 767, 768 and 769, signed mean ties and length 2048. |
| R2: GELU storage precision | FFN_HIDDEN is native signed32/F22. The first linear writes F10 values that the adapter promotes exactly by `<<12`; GELU writes its full F22 response unchanged. The second linear reads signed32 activations, multiplies by signed16/F10 weights, adds F32-aligned bias and accumulates signed64/F32 before its separate F10 output conversion. |
| R3: mismatched numerical domains | LayerNorm epsilon cannot be below the shared NORMALIZATION_MINIMUM=42950 raw F32. RSQRT's minimum is tied to that constant; incompatible overrides fail elaboration. A LayerNorm epsilon of 42949 is rejected by the targeted preflight. |
| R4: missing fault/reset cases | Added 22 actual-controller scenarios with modeled children: second-normalization failure; reset during linear, second norm, copying and held completion; final-projection early/late/unclassified errors; aggregation reciprocal errors, bad tags/zero result and a failed later output write. Tests require completion, held-response stability, reset/restart, fatal lockout and committed-write barriers. |
| R5: weak maintained memory regression | The maintained regression now requires the 13-client router, unrestricted connected-memory control, signed16, signed32 hidden, signed48 score, unsigned24 EXP and one-bit mask cases. A dedicated 20-step hidden proof checks exact promotion, retained fractions, malformed formats/high bits and rejection of F10 hidden reads. |
| R6: synthesis-only host width hazard | The output-index guard uses the actual interface's constant INDEX_W and remains active under SYNTHESIS. N=3 accepts widths 2 and 64 and rejects width 1 with the intended diagnostic. |

GELU(1) now remains `3528856 / 2^22 = 0.8413448333740234` when stored. No
F22-to-F10 activation conversion occurs at that boundary. A complete-core
precision fixture forces this value, checks all 32 committed GELU writes across
four frames, and uses large legal second-linear weights so a consumer that
silently truncates it would produce a detectable mismatch.

The analytic function-output error bound applies unchanged to stored GELU
results because storage preserves every F22 bit. Input quantization and later
linear/residual output quantization are separate contracts; this is not a
10^-5 end-to-end network error guarantee.

## Interface and storage revision

- The host parameter image remains signed16/F10 with unchanged tensor order and
  parameter-word counts. No trained weights or model dimensions were selected.
- BANK_FFN_HIDDEN has 4D native 32-bit words, adding 64D bits over the old bank.
  It accepts FMT_S32_F22 reads/writes and exact FMT_S16_F10 write promotion;
  F10-format reads are rejected. All other bank widths remain unchanged.
- Memory format is now three bits, making mem_req_t 137 bits at ADDR_W=32.
  Existing format IDs 0–3 are unchanged; FMT_S32_F22 is 4.
- The dot mode is now two bits. DOT_S32_S16 is mode 2; mode 3 is rejected.
  dot_cmd_t is 220 bits and mac_req_t is 114 bits, with a 32-bit A operand.
- Signed16 dots still enforce signed48 range. Probability and signed32 dots
  enforce signed64 range. Unused high A bits in narrow modes must be zero.
- Linear, dot and FFN controllers preserve the existing handshakes and write
  completion barriers. Unsupported narrow consumers reject the hidden bank.

External RTL integrations must rebuild against the updated package. The
parameter manifest identifies interface revision 2 and reports the wider bank.
The microarchitecture diagrams and living interface guide have been updated.

## Corrected implementation checks

| Check | Result |
|---|---|
| Complete/protocol elaboration | 0 errors, 0 warnings |
| Connection inventory | 29 public kinds, 65 endpoints |
| Fresh arithmetic RTL | 958 vectors, including signed32 mode, reserved mode, unused bits and accumulator boundaries |
| Complete-core execution | 16 frames, 2705 intermediate writes, four configurations |
| GELU precision integration | Four complete frames; exact F22 activation storage and widened consumer verified |
| Integration recovery | Four connected core fault/recovery cases |
| Targeted controller faults/resets | 22 scenarios with delayed and stalled modeled children |
| LayerNorm | 53 actual-RTL cases, 567149 cycles; exact BigInt mean/variance/output oracle and selected float comparisons |
| Conversion | Exhaustive signed48/F20 and signed64/F32 to signed16/F10 ties-even rounding, clipping and flags |
| Host width | Synthesis-positive and synthesis-negative preflight cases |
| Hidden storage | 20-step arbitrary-data/format proof plus nonvacuous promotion/fraction/rejection witnesses |
| Infrastructure | 13-client router at 24 steps; required connected-memory cases at 16 steps, depth two |
| Manifest/image | Three unchanged raw parameter-image round trips with updated storage widths |
| Taylor | Exact rational budgets, 65536 Python GELU inputs and 12289 EXP samples |

## Reproduction and CI

```sh
python scripts/check.py smoke
python scripts/check.py numerics
python scripts/check.py regressions
python scripts/check.py full
```

`regressions` compiles and executes the arithmetic and LayerNorm tests, controller
fault tests, configuration preflights and bounded infrastructure proofs. `full`
adds all four complete-core configurations and integration recovery, then
requires explicit success evidence in its summary. CI now runs the regression
group and the complete-core precision fixture in addition to smoke/numerics;
passing Python function sweeps alone cannot satisfy it.

The old review reproducer can still be run; it now reports that the constant-row
mathematical invariant holds. Its original counterexample remains documented
against the archived reviewed revision.

## Remaining validation work

Select the trained checkpoint and compare to the agreed floating-point/decoding
reference before freezing all numerical formats. Four-state simulation,
full-size execution, unbounded liveness, technology SRAM mapping and physical
timing/area/power are not established here. Exact integer division fixes the
statistical bias but remains a potentially expensive physical implementation.
Fixed-priority arbitration and finite-stall tests do not establish arbitrary
endpoint fairness or timeout recovery. No new bug-freedom or silicon-sign-off
claim is made.
