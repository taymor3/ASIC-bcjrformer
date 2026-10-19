# Rounding and precision map for validation

Recorded 19 October 2026 from the current production RTL. Formats remain
provisional. This inventory records locations; it does not add RTL monitors or
an event logger. Keep the IDs stable when formats or implementations change.

`S16/F10` means signed 16-bit storage with 10 fractional bits; `U` means
unsigned. A raw integer represents `raw / 2^F`. The fractional-bit count of a
product is the sum of its operands' counts. Width alone does not identify scale:
aggregation's `sum_q` uses the 48-bit `score_t` type but holds **F10**, not F20.

## Rules shared by the runtime points

Every runtime rounding point below uses nearest, ties to even (RNE). Signed
examples for division by two: `5 -> 2`, `7 -> 4`, `-5 -> -2`, `-7 -> -4`.

[convert()](../../rtl/arithmetic/fixed_math_pkg.sv#L6) rounds first, then checks
the target range. With clipping enabled it clamps and sets `saturated`; otherwise
an out-of-range result sets `numeric_error`. `conversion_t.value` remains a
160-bit carrier; the target width is checked before the later storage cast.

The LayerNorm/GELU division helpers round using quotient and remainder. RSQRT
uses an exact squared-midpoint comparison. Their internal integer floor
divisions are algorithm steps, not extra independently rounded output formats.

## Runtime rounding points

These are **19 logical locations/contexts**, not 19 events per frame. Shared
hardware handles multiple callers; loops repeat many of these operations.

| ID | Operation and location | Before rounding -> after rounding | Occurrence and range handling |
|---|---|---|---|
| R01 | [LayerNorm mean](../../rtl/control/layernorm_ctrl.sv#L38) | Exact `(sum_F10 << 10) / length` -> S32/F20 | Once per vector; division RNE; range error is fatal |
| R02 | [LayerNorm population variance](../../rtl/control/layernorm_ctrl.sv#L39) | F40 squared sum divided by `(length << 8)` -> U48/F32 | Once per vector; division RNE, then exact addition of represented epsilon; range/domain errors are fatal |
| R03 | [LayerNorm reciprocal square root](../../rtl/arithmetic/rsqrt_unit.sv#L11) | `1/sqrt(variance_plus_epsilon)` -> U32/F20 | Once per vector; midpoint RNE; invalid domain/result range is fatal |
| R04 | [LayerNorm normalized element](../../rtl/control/layernorm_ctrl.sv#L40) | Centered F20 x scale F20 = F40 -> S32/F20 | Shift 20, once per element; range error is fatal |
| R05 | [LayerNorm gamma/beta output](../../rtl/control/layernorm_ctrl.sv#L42) | Normalized F20 x gamma F10 + aligned beta = F30 -> S16/F10 | Shift 20, once per element; saturation enabled |
| R06 | [Ordinary linear output](../../rtl/control/linear_ctrl.sv#L13) | Dot/bias accumulator S48/F20 -> S16/F10 | Shift 10, once per output; saturation enabled. Used by embedding, Q/K/V, attention output projection, FFN1 and final projection |
| R07 | [Wide FFN2 linear output](../../rtl/control/linear_ctrl.sv#L13) | Hidden S32/F22 x weight S16/F10 with S64/F32 accumulation -> S16/F10 | Shift 22, once per output; saturation enabled |
| R08 | [Attention score scaling](../../rtl/control/row_dot_ctrl.sv#L36) | QK dot F20 x head scale F30 = F50 -> S48/F20 | Shift 30, once per query/key/head score; range error is fatal |
| R09 | [EXP Horner multiplication](../../rtl/arithmetic/exp_unit.sv#L15) | Polynomial F48 x reduced argument F48 = F96 -> S64/F48 | Shift 48, seven multiplications per polynomial invocation; coefficient addition follows each rounded product; range error is fatal |
| R10 | [EXP repeated squaring](../../rtl/arithmetic/exp_unit.sv#L15) | Accumulator F48 squared = F96 -> S64/F48 | Shift 48, five squarings per polynomial invocation; range error is fatal |
| R11 | [EXP output](../../rtl/arithmetic/exp_unit.sv#L16) | F48 accumulator -> U24/F22 | Shift 26, once after polynomial/squaring path; range error is fatal |
| R12 | [Softmax reciprocal](../../rtl/arithmetic/reciprocal_unit.sv#L9) | `2^54 / sum_of_EXP_raw_F22` -> U40/F32 inverse | One rounded division per non-padded query/head; requested by [softmax](../../rtl/control/softmax_ctrl.sv#L36) |
| R13 | [Softmax probability](../../rtl/control/softmax_ctrl.sv#L20) | EXP F22 x reciprocal F32 = F54 -> U24/F22 | Shift 32, once per key in a non-padded row; range/probability-bound errors are fatal |
| R14 | [Attention weighted value](../../rtl/control/row_dot_ctrl.sv#L35) | Probability F22 x value F10 accumulated at S64/F32 -> S16/F10 | Shift 22, once per output component; saturation enabled |
| R15 | [GELU initial term](../../rtl/arithmetic/gelu_unit.sv#L21) | Phi-zero coefficient F64 x input-square F20, divided by `2^20` -> term F64 | One division RNE per polynomial invocation; retained in signed128 carrier |
| R16 | [GELU recurrence term](../../rtl/arithmetic/gelu_unit.sv#L24) | `-term_raw * input_square_raw * (2k-1) / ((2k(2k+1)) << 20)` -> term F64 | 57 division-RNE steps, k=1..57; rounded term is added to the F64 sum; term/sum range errors are fatal |
| R17 | [GELU output](../../rtl/arithmetic/gelu_unit.sv#L26) | Polynomial sum plus `x/2`, F64 -> S32/F22 | Shift 42, once per polynomial invocation; range error is fatal; hidden storage preserves the result unchanged |
| R18 | [Aggregation reciprocal](../../rtl/arithmetic/reciprocal_unit.sv#L9) | `2^54 / (valid_count << 22)` = `2^32 / valid_count` -> U40/F32 | Once per nonempty output position; same physical reciprocal unit as R12; [request preparation](../../rtl/control/aggregation_ctrl.sv#L21) is exact |
| R19 | [Aggregation output](../../rtl/control/aggregation_ctrl.sv#L11) | Logit sum F10 x reciprocal F32 = F42 -> S16/F10 | Shift 32, once per nonempty output position; saturation enabled |

LayerNorm points repeat for embedding feature normalization, embedding model
normalization, and both norms of each encoder layer. FFN applies GELU to 4D
hidden elements for every token/layer. A polynomial EXP invocation contains
13 rounding steps (7 + 5 + 1); a polynomial GELU invocation contains 59
(1 + 57 + 1). Tail/bypass paths do not execute those steps.

R18 followed by R19 is not generally equivalent to exactly dividing the logit
sum and rounding once. The [post-fix review](../reviews/RTL-POST-FIX-CRITICAL-REVIEW-2026-10-17.md)
records the M=6, raw sum=3 case: actual output raw 1 versus exact-division RNE
raw 0. The validation reference must preserve the selected rounding sequence.

## Rounded constants and external quantization

These also affect validation even though they are not runtime rounding events.

| ID | Constant/boundary | Representation and source |
|---|---|---|
| C01 | Default normalization epsilon | RNE(`1e-5 * 2^32`) = 42950, U48/F32, [package](../../rtl/interfaces/bcjrformer_contract_pkg.sv#L17). An explicit raw parameter override is already represented; the controller does not quantize it again |
| C02 | Attention head scale | RNE(`2^30 / sqrt(D/H)`), U32/F30, [head_scale()](../../rtl/arithmetic/fixed_math_pkg.sv#L56), connected by [core](../../rtl/bcjrformer_core.sv#L59) |
| C03 | Uniform padded-query probability | RNE(`2^22 / TOKENS`), U24/F22, [uniform_probability()](../../rtl/arithmetic/fixed_math_pkg.sv#L49), connected by [core](../../rtl/bcjrformer_core.sv#L63). Reused for every key in the padded row; no runtime reciprocal/probability multiplication |
| C04 | Eight EXP coefficients | RNE(`2^48/k!`), k=0..7, [fixed literals](../../rtl/arithmetic/exp_unit.sv#L6). Coefficient quantization precedes R09 |
| C05 | GELU Phi-zero coefficient | RNE(`2^64 / sqrt(2*pi)`) = 7359186146747302452, [fixed literal](../../rtl/arithmetic/gelu_unit.sv#L7). Quantization precedes R15 |
| E01 | Feature preparation | Host features arrive as raw S16/F10. Float-to-fixed scale, rounding and clipping must be specified by the future external input-preparation flow; the RTL loader does not round them again |
| E02 | Learned parameter preparation | Weights, biases, gamma, beta, position and read embeddings arrive as raw S16/F10. The [manifest/image tool](../../rtl/scripts/parameter_manifest.py) accepts integers, not float tensors: it does not implement trained-weight quantization |

The manifest generator reproduces C01-C03. The [Taylor accuracy checker](../../rtl/tests/verify_taylor_accuracy.py)
checks C04 and certifies C05. The package's `inverse_count()` also implements
RNE, but has no caller in the current production assembly; it is not an extra
runtime rounding point. The Python reference's `inv()` predicts the shared
reciprocal result for aggregation rather than adding another hardware step.

## Clipping, approximations and exact paths

Fractional rounding must be distinguished from these other changes:

| ID | Boundary | Current behavior |
|---|---|---|
| S01 | [Position addition: X + P](../../rtl/arithmetic/position_add_unit.sv#L6) | Same F10 scale, signed17 sum clipped to S16/F10; `convert()` shift is zero, so no fractional rounding |
| S02 | [Read embedding addition: previous result + E](../../rtl/control/position_sequencer.sv#L72) | A second use of the same local add unit, with separate clipping. Preserve `clip(clip(X+P)+E)` rather than combining all three operands first |
| S03 | [Residual additions](../../rtl/control/residual_ctrl.sv#L8) | Same F10 scale, signed17 sum clipped to S16/F10 after attention and FFN; no fractional rounding |
| A01 | [EXP tail](../../rtl/arithmetic/exp_unit.sv#L28) and [softmax shortcut](../../rtl/control/softmax_ctrl.sv#L61) | Shifted scores strictly below -16 produce zero; this is a bounded function approximation, not an ordinary RNE conversion |
| A02 | [GELU tails](../../rtl/arithmetic/gelu_unit.sv#L37) | Inputs strictly above +6 return the input promoted exactly to F22; strictly below -6 return zero. Polynomial endpoints +/-6 still use R15-R17 |
| A03 | Taylor polynomial choice | Finite degree itself is a function approximation, separate from coefficient and arithmetic rounding; see [Taylor budgets](RTL-TAYLOR-CHECKPOINT.md) |

MAC products/accumulation do not drop fractional bits. Their range checks can
raise errors but are not rounding points. The same applies to LayerNorm and
aggregation sum checks using `convert(..., shift=0, ..., clip=0)`.

Bias alignment, sign/zero extension, and F10-to-hidden-F22 promotion by `<<12`
are exact. Before GELU, [FFN's F22-to-F10 extraction](../../rtl/control/ffn_ctrl.sv#L51)
requires the low 12 bits to be zero and the value to fit S16: it rejects a bad
representation instead of silently rounding it. This extraction occurs before
GELU; the GELU output is never narrowed there. Native hidden reads/writes retain
all F22 bits. Host output streaming introduces no additional conversion.

## What the existing status flags can and cannot tell us

- Generic conversions and division report a nonzero discarded fraction as
  `rounded`, including when RNE leaves the integer quotient unchanged.
- Status is accumulated across operations/stages. A final `rounded=1` does not
  identify the operation, element, direction, error magnitude or event count.
- EXP and GELU set their primitive `rounded` flag for nonzero input as a coarse
  approximation indicator. EXP does not OR each internal product's rounding
  flag into a per-step history; GELU's division helper returns no per-term flags.
- Rounded constants have no runtime event flag. The padded-query constant path
  and softmax's below--16 shortcut do not set a new rounding flag themselves.
  An unset flag is therefore not evidence that the entire numerical path was
  exact. Saturation is reported separately from fractional rounding.

## Validation trace checklist

For a mismatch, compare **raw integers and fractional-bit counts** at the first
divergence. The integer reference must reproduce each rounding point, its order,
and clipping; rounding only at the end of a stage is insufficient.

A future simulator trace should use these IDs and record:

- Frame, stage, layer, token, normalization/linear role, head, query/key,
  element/output index, and polynomial phase/term index as applicable.
- Raw operands and full pre-round numerator/product, input/output fractional
  bits, shift or divisor, quotient/remainder, rounded value and clipped value.
- Local `rounded`, `saturated`, `numeric_error` and `protocol_error`, separately
  from the accumulated parent status, plus source/destination bank and address.
- The clock/state in which the result is captured. Log a held ready/valid
  transaction once when accepted, not once for every stalled cycle. For EXP and
  GELU internal recurrences, log each actual state update instead of waiting
  only for the final response.

For LayerNorm specifically, useful probes are `sum_q`, `mean_value`, `mean_q`,
`centered`, `squares_q`, `var_value`, `variance_q`, `scale_q`, `norm_value`,
`normalized_q`, `gamma_q`, `affine` and `act_value`, with the corresponding state
and `index_q`. Shared physical engines need caller context to distinguish, for
example, embedding normalization from encoder LN1/LN2.

Start with exact values, positive/negative halfway cases, adjacent values on
both sides of a tie, zero-variance/non-power-of-two-length rows, clipping
thresholds, Taylor/tail endpoints, and the known aggregation double-rounding
case. Match the integer implementation first, then compare its error to the
chosen floating-point model and agreed tolerances. No new per-event tracing is
implemented by this document.
