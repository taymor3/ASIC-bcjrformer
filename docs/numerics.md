# Numerical baseline

Formats and methods are provisional pending selected-model calibration. Width/scale notation below gives total bits and fractional bits, avoiding ambiguity in Q-format naming.

The [rounding and precision map](rtl/RTL-ROUNDING-MAP.md) records every current runtime rounding context, rounded constant, saturation boundary and exact format adapter, with stable validation IDs and source links. Existing status bits summarize events; they are not a per-operation trace.

| Quantity | Representation |
|---|---|
| Stored activations, weights, logits | Signed 16 bits / 10 fractional bits |
| Attention scores | Signed 48 bits / 20 fractional bits |
| EXP and probability storage | Unsigned 24 bits / 22 fractional bits |
| GELU function response and FFN hidden bank | Signed 32 bits / 22 fractional bits |
| Linear/dot accumulator | Signed 48/F20 or signed 64/F32 by operation |

The fixed-point package centralizes nearest-even conversion, saturation, and status flags. Stored activation saturation is nonfatal; intermediate overflow and numerical domain errors are fatal. GELU's response is stored unchanged as signed32/F22. First-linear signed16/F10 writes are promoted exactly by shifting left 12; the second linear reads signed32/F22, uses signed64/F32 products and accumulation with F10 weights, and rounds only its own output back to F10.

## Taylor nonlinear units

EXP and GELU are sequential arithmetic hardware modules, with fixed coefficients. No function-value ROM or filename parameter is used in production RTL.

| Function | Method | Documented absolute error bound at the function output |
|---|---|---|
| EXP | Degree-7 polynomial at x/32, then five squarings | 3.219408058 × 10⁻⁶ |
| GELU | Maclaurin polynomial through degree 116 on [-6,6], bounded tails outside | 4.543704477 × 10⁻⁷ |

EXP accepts nonpositive shifted scores: [-16,0] uses the polynomial; lower values return zero with bounded absolute tail error; positive values report a domain error. GELU uses zero/input tails outside [-6,6]. The [Taylor checkpoint](rtl/RTL-TAYLOR-CHECKPOINT.md) derives the Lagrange remainder and finite-precision budgets, including output rounding. The [accuracy script](../rtl/tests/verify_taylor_accuracy.py) checks exact rational bounds and reference sweeps.

These bounds compare each function output with the exact function of the **already represented input**. The same bound now applies to stored GELU results because hidden-bank storage is bit-exact F22. Earlier input quantization and later linear/residual output conversions remain separate; this is not an end-to-end network accuracy claim.

LayerNorm computes the signed F20 mean by exact nearest-even division of (sum << 10) by length, then the unsigned F32 population variance by exact nearest-even division of the F40 square sum by (length << 8). It no longer multiplies by a rounded inverse length. Epsilon is at least the shared NORMALIZATION_MINIMUM of 42950 / 2³²; RSQRT enforces that shared minimum.

Reciprocal uses integer division and nearest-even quotient rounding. RSQRT uses division, integer square-root search, and an exact midpoint comparison. Wide products/dividers and root search still need target synthesis and timing assessment.

No floating-point inference/decoding accuracy, trained-parameter export, or precision freeze is claimed. Those comparisons follow the RTL review.
