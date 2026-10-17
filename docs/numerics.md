# Numerical baseline

Formats and methods are provisional pending selected-model calibration. Width/scale notation below gives total bits and fractional bits, avoiding ambiguity in Q-format naming.

| Quantity | Representation |
|---|---|
| Stored activations, weights, logits | Signed 16 bits / 10 fractional bits |
| Attention scores | Signed 48 bits / 20 fractional bits |
| EXP and probability storage | Unsigned 24 bits / 22 fractional bits |
| GELU function response | Signed 32 bits / 22 fractional bits |
| Linear/dot accumulator | Signed 48/F20 or signed 64/F32 by operation |

The fixed-point package centralizes nearest-even conversion, saturation, and status flags. Stored activation saturation is nonfatal; intermediate overflow and numerical domain errors are fatal. GELU's response is explicitly converted to signed16/F10 when stored by the FFN.

## Taylor nonlinear units

EXP and GELU are sequential arithmetic hardware modules, with fixed coefficients. No function-value ROM or filename parameter is used in production RTL.

| Function | Method | Documented absolute error bound at the function output |
|---|---|---|
| EXP | Degree-7 polynomial at x/32, then five squarings | 3.219408058 × 10⁻⁶ |
| GELU | Maclaurin polynomial through degree 116 on [-6,6], bounded tails outside | 4.543704477 × 10⁻⁷ |

EXP accepts nonpositive shifted scores: [-16,0] uses the polynomial; lower values return zero with bounded absolute tail error; positive values report a domain error. GELU uses zero/input tails outside [-6,6]. The [Taylor checkpoint](rtl/RTL-TAYLOR-CHECKPOINT.md) derives the Lagrange remainder and finite-precision budgets, including output rounding. The [accuracy script](../rtl/tests/verify_taylor_accuracy.py) checks exact rational bounds and reference sweeps.

These bounds compare each function output with the exact function of the **already represented input**. They exclude earlier input quantization and subsequent FFN Q10 storage rounding, which can reach about 4.88 × 10⁻⁴. Thus a 10⁻⁵ function-output bound does not imply that every stored FFN activation or final network result has 10⁻⁵ error.

Reciprocal uses integer division and nearest-even quotient rounding. RSQRT uses division, integer square-root search, and an exact midpoint comparison. LayerNorm epsilon is 42950 / 2³². Wide products/dividers and root search still need target synthesis and timing assessment.

No floating-point inference/decoding accuracy, trained-parameter export, or precision freeze is claimed. Those comparisons follow the RTL review.
