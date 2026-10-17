> 17 October update: the [review fixes](RTL-REVIEW-FIXES-2026-10-17.md) preserve the full F22 GELU result in FFN hidden storage and in its consuming dot. The16October storage-boundary discussion below is retained as history and no longer describes current RTL.

# Taylor EXP and GELU

16 October 2026. Taimor requested Taylor expansion with Lagrange remainder bounds and absolute function error below 10^-5. EXP and GELU now use arithmetic recurrences; there are no function-value ROM reads or table-file path parameters in the production RTL. This supersedes the ROM methods recorded on 13 October.

## Where the modules are

`bcjrformer_core` instantiates one `exp_unit` as `exp_service` and one `gelu_unit` as `activation_service`. They are real hardware submodules inside the core. `bcjr_arith_if` is the ready/valid wiring between a caller and a numerical unit, not another calculating module. The EXP caller is softmax; the GELU caller is the FFN controller. `bcjr_cmd_if` similarly bundles commands/completions between controllers and services.

`#(...)` on modules/interfaces supplies elaboration-time configuration parameters or payload types. The `EXP_TABLE`, `GELU_TABLE` and `TABLE_FILE` string parameters have been removed. Fixed Taylor coefficients are numerical constants, not input/output function lookup tables. The old table files and generator are historical artifacts and are not used by current RTL or its reference model.

## EXP: degree 7 after range reduction

For the softmax domain x<=0, use:

\[
u=x/32,\qquad P_7(u)=\sum_{k=0}^{7}\frac{u^k}{k!},\qquad \widehat{\exp}(x)=P_7(u)^{32}.
\]

For x in [-16,0], u is in [-1/2,0]. By the Lagrange remainder, with every derivative of exp equal to exp and exp(xi)<=1 on that interval:

\[
|e^u-P_n(u)|\le\frac{(1/2)^{n+1}}{(n+1)!}.
\]

Both e^u and P7(u) lie in [0,1]. Applying the mean-value bound to z^32 multiplies the real-polynomial error by at most 32. Degree 6 gives a conservative bound 4.96032e-5 and fails the requested tolerance. Degree 7 gives:

\[
32\frac{(1/2)^8}{8!}=3.100198413\times10^{-6}.
\]

The implementation evaluates P7 with Horner's method in signed64/F48, then squares five times. Q20 input becomes Q48 u exactly by a left shift of 23 bits. Coefficients are nearest-even Q48 representations of 1/k!. Bounding Horner coefficient/product rounding and five squarings by 100 Q48 LSBs, and adding half a Q22 output LSB, gives:

\[
E_{\mathrm{EXP}}\le3.100198413\times10^{-6}+100\,2^{-48}+2^{-23}
=3.219408058\times10^{-6}<10^{-5}.
\]

The 100-LSB allowance is conservative: Horner's coefficient and multiply rounding contributes less than 2 Q48 LSBs since |u|<=1/2; propagating that through five squarings plus their half-LSB rounding contributes less than 80 Q48 LSBs. The tiny departure above one permitted by this fixed-point bound is included in the 100-LSB allowance.

For x<-16 the unit returns zero, with absolute tail error below exp(-16)<1.126e-7. Positive inputs produce a numerical error, as required by the softmax primitive contract. EXP(0) is exactly 1. The response remains unsigned24/F22.

## GELU: Maclaurin series through degree 116

The selected function is exact GELU, g(x)=x*Phi(x), not the tanh approximation. From the error-function power series:

\[
g(x)=\frac{x}{2}+\frac{1}{\sqrt{2\pi}}
\sum_{k=0}^{\infty}\frac{(-1)^k x^{2k+2}}{2^k k!(2k+1)}.
\]

This is obtained by expanding exp(-t^2/2) in the defining Gaussian integral. The series identity is documented in [NIST DLMF 7.6.1](https://dlmf.nist.gov/7.6.E1); the following integrated Lagrange bound is derived for this implementation.

Applying the exponential Lagrange remainder before integrating gives, when the last retained index is N:

\[
|R_g(x)|\le\frac{1}{\sqrt{2\pi}}
\frac{|x|^{2N+4}}{2^{N+1}(N+1)!(2N+3)}.
\]

We use |x|<=6 and bound 1/sqrt(2*pi)<0.4. N=54 gives 1.12033e-5 and does not meet the target. N=55 already gives 3.53734e-6. The implementation retains two additional terms for margin: **N=57**, 58 terms, highest power **116**, giving:

\[
|R_g|\le0.4\frac{6^{118}}{2^{58}58!\,117}
=3.348191882\times10^{-7}.
\]

Direct low-precision coefficient Horner evaluation is unsuitable over this larger interval because very small coefficients and cancellation lose accuracy. Instead, the RTL accumulates signed128/F64 terms using:

\[
T_0=\frac{x^2}{\sqrt{2\pi}},\qquad
T_k=-T_{k-1}\frac{x^2(2k-1)}{2k(2k+1)},\qquad
g_{57}(x)=x/2+\sum_{k=0}^{57}T_k.
\]

The recurrence uses full signed160 intermediates and nearest-even division. Phi(0)'s Q64 constant is 7359186146747302452; its nearest-even rounding is certified by exact rational pi intervals in `verify_taylor_accuracy.py`.

Since |T_k/T_(k-1)|<=18/k, total propagation of an individual term-rounding error through subsequent terms is bounded by e^18<2^27. Initial-term error is at most 18.5 Q64 LSBs, and the following 57 divisions each add at most half an LSB. Thus total internal evaluation error is bounded by:

\[
E_{\mathrm{fixed}}\le (18.5+57/2)2^{27}2^{-64}
=3.419700079\times10^{-10}.
\]

The absolute-term sum is below 0.4*36*e^18<2^31, so F64 accumulation stays below 2^95 in magnitude, well within signed128. Multiplication intermediates also fit signed160. RTL checks recurrence-register overflow explicitly.

The function returns **signed32/F22 (`gelu_t`)**, making its half-LSB output rounding error 2^-23. Combining all three sources gives:

\[
E_{\mathrm{GELU}}\le3.348191882\times10^{-7}
+3.419700079\times10^{-10}+2^{-23}
=4.543704477\times10^{-7}<10^{-5}.
\]

For x>6 the unit returns x; for x<-6 it returns zero. These are analytically bounded Gaussian tails: |x|*Phi(-|x|)<phi(|x|)<=phi(6)<1.193e-8. These shortcuts meet the same error target without a lookup table. Every non-tail request follows the Taylor recurrence. The complete represented input range is signed16/F10, [-32,32).

## Precision boundary

The 10^-5 guarantee is for each function's returned value relative to the exact mathematical function of its already represented input. It includes the function's output rounding. It is not a guarantee relative to an earlier unquantized floating-point input.

The existing FFN activation bank still stores signed16/F10. Its separate Q22-to-Q10 conversion is now explicit in `ffn_ctrl`, with rounding/saturation status. That later storage rounding can introduce up to 2^-11=0.00048828125 error without saturation, which is larger than 10^-5. The Taylor function output meets the target; the stored FFN activation has a different precision contract. Making all stored activations meet 10^-5 would require a separate system-wide format, memory, parameter/host and datapath revision, not only a polynomial-order change.

## Checks and reproduction

`rtl/tests/taylor-accuracy-results.json` records exact rational error budgets plus:

- All 65,536 signed16/F10 inputs checked in the integer GELU reference against x*Phi(x). Maximum observed function-output error: about 2.325e-7.
- 12,289 EXP inputs covering [-16,0], near zero and clipping boundaries. Maximum sampled error: about 1.193e-7. The analytic bound, not this sample alone, covers all supported inputs.

`arithmetic-results.json` checks actual lowered RTL values, flags, request tags, held responses, reset and variable latency against the integer reference. The complete core regressions check actual FFN conversion and every committed intermediate write. These remain deterministic two-state vector-netlist tests, not commercial four-state simulation or silicon timing sign-off. Division and wide multipliers require physical synthesis review.

Final 16 October results: 847 actual RTL arithmetic vectors passed; all 12 complete-core matrix frames passed with 2497 computational scratch writes matching the updated integer reference; all four connected fault/recovery scenarios and three manifest/image round trips passed. Complete and protocol elaboration each report zero errors and zero warnings. All three lowered core assemblies pass structural checks. `complete-evidence.json` records the current production source hashes and analytic error budgets.

Run from the project root using the existing local Python verification dependencies:

```text
python rtl/tests/verify_taylor_accuracy.py
python rtl/tests/arithmetic_vectors.py
python rtl/tests/build_arithmetic_netlist.py
node rtl/tests/run_arithmetic_cycle.cjs
python rtl/tests/fixed_reference.py
python rtl/tests/build_cycle_netlist.py single
python rtl/tests/build_cycle_netlist.py multi
python rtl/tests/build_cycle_netlist.py heads
node rtl/tests/run_complete_cycle.cjs single
node rtl/tests/run_complete_cycle.cjs multi
node rtl/tests/run_complete_cycle.cjs heads
node rtl/tests/run_core_fault_cycle.cjs
```
