# Complete RTL review ledger

16 October numerical-method revision: current EXP/GELU are sequential Taylor units, not ROM implementations. Their Lagrange bounds, widened GELU result, explicit FFN storage conversion and refreshed tests are recorded in `RTL-TAYLOR-CHECKPOINT.md`. The original review rows below are the 13 October baseline where they describe ROMs.

13 October 2026. Implementation review of the provisional fixed-point baseline, before Haiel's numerical validation. User-selected numerical formats remain provisional.

| Area | Implementation check | Evidence / remaining review |
|---|---|---|
| Hierarchy and ownership | One of every public processing/service block; K/H are loops; no duplicated shared matrix engines | Complete elaboration, 29 public contracts / 65 endpoints; actual 13-client assembly |
| Parameter image | Output-major weights, contiguous distinct layer regions, exact word counts; native-element addressing | Manifest/image round trips and every intermediate write in two-layer inference; confirm export from the actual selected checkpoint |
| Stage order | Embedding -> position -> encoder -> final -> aggregation -> host output | Full-frame tests and core parent checks |
| Completion barriers | Parents consume accepted child responses; writers wait for memory acknowledgment | Controller FSM inspection, full write-stream comparison, existing router/memory proofs |
| Stage 1 | FEATURE/TOKEN/VECTOR/X copies; norm(F), F-to-D linear, norm(D); distinct norm parameters | Single, multi and heads write-stream comparisons |
| Stage 2 | m/n/feature order and two separate saturated additions | Complete write-stream comparison; local-add boundary vectors |
| Encoder lifetimes | LN1 sweep precedes attention; residual1 precedes LN2 U reuse; FFN/residual2 per token | Two-layer and three-head traces; source/destination overlap guards |
| Q/K/V and heads | All Q tokens, then KEY, then VALUE; head slices are addresses; Z joins heads by destination address | Three non-power-of-two heads, Q/K strides and probability/V stride checks in full inference |
| Query mask | Original query padding bit; all keys retained; padded row uniform 1/L | Full all-valid/mixed/all-padded frames; no static-mask support, explicitly rejected |
| Softmax | First-element maximum, wide subtraction, -16 clipping, positive sum and reciprocal, one probability writer | Committed row write-stream comparisons; primitive domain/zero vectors |
| LayerNorm | Stored inverse length, full-width statistics, positive epsilon, RSQRT, affine conversion | F/D=1,2,3 and repeated layers; zero-variance case; actual model/range calibration remains |
| MAC and conversion | Unsigned probabilities zero-extended; signed-mode 48-bit and weighted-mode 64-bit overflow; ties to even; clipping distinct from overflow | 841 primitive vectors and exhaustive 48-to-16 conversion proof |
| Nonlinear functions | Integer synthesizable arithmetic and reproducible ROMs; source GELU uses x*Phi(x) | Primitive vectors, generated constants and analytic ROM error bounds; independent numerical/decoding acceptance remains |
| FFN and residual | All hidden outputs written before GELU; each GELU write committed before second linear; both residual operands captured before replacement | Full committed-write comparisons and partial-overlap rejection |
| Final projection | D-to-1 linear for every token, including padded tokens; no sigmoid/hard decision | LOGIT and OUTPUT write/output comparisons |
| Aggregation | Per-position count/sum use the same validity bit; zero count never calls reciprocal; outputs remain private until success | Partial padding, empty last position, all padded, M=1; reference uses corrected aggregation rather than the older Python whole-read count |
| Host backpressure | Indexed/last outputs, parameter acknowledgments and completion payloads held through stalls | Complete-cycle harness assertions and earlier bounded core checks |
| Fatal/reset behavior | No duplicate requests; outstanding operations drain; fatal readiness lock; synchronous reset clears ownership/image validity | Connected bad-packet/illegal-commit/reset/reload cases; primitive tag/stall/reset checks |
| Physical implementation | Behavioral memories, integer dividers/root logic, wide products and ROMs are explicit RTL | Synthesis frontend accepts the assembly; technology SRAM mapping, target constraints, area and timing are still unselected |

Implementation issues corrected during this pass:

- Arithmetic-switch interface-member `$bits` guards were kept for ordinary elaboration and excluded only under SYNTHESIS, matching the command switch. The synthesis frontend cannot evaluate those guards; ordinary connected compilation still checks the real interfaces.
- Signed MAC inputs now reject an accumulator outside the signed48 contract even if a later product would bring its result back into range. A cancellation vector checks that case.
- Core M/N bounds are explicit, alongside the existing total token and address bounds.
- Dot operand addresses advance by their captured strides, and the linear weight-row pointer advances by the captured input count. Runtime loop-index multiplication is absent from those repeated address paths; descriptor-range admission checks remain widened integer calculations.
- The integrated test expectation for EMPTY_POSITION was corrected: the host intentionally sets completion_error for this recoverable input error while fatal status remains clear. This was a test expectation issue, not a change to the established RTL protocol.

No missing public RTL block remains in this baseline. The review does not approve a trained configuration, freeze precision, establish arbitrary-backpressure/unbounded liveness, or establish silicon feasibility. Before validation, jointly confirm the model/checkpoint and manifest, source-mask restrictions and corrected aggregation reference, then approve the provisional numerical baseline for Haiel's comparisons. Synthesis timing/area optimization may require implementation changes after that review.
