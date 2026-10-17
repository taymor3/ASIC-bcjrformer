# QKV and output-projection control checkpoint

12 October 2026. `rtl/control/qkv_ctrl.sv` and `rtl/control/output_projection_ctrl.sv` now implement the existing projection command interfaces through the internal `projection_loop.sv` helper. This checkpoint implements sequencing and descriptors. The shared linear controller and numerical datapath remain pending, as does Haiel's numerical verification.

## Implemented behavior

QKV captures the accepted layer descriptor and calls the shared linear service for every U token into Q, then every U token into KEY, then every U token into VALUE. Each call has D inputs and D outputs, with source/destination address `token * D`. The input U bank is reused directly; no head split or tensor-copy operation is introduced.

Output projection captures the same layer descriptor and calls D-to-D linear for each Z token into ATTN_OUT. Each controller waits for the accepted linear response before advancing its token/projection counter. Parent completion follows the final successful linear response; by contract that response certifies the child's destination writes are committed. These controllers themselves do not access memory or calculate tensor values.

Requests and completions stay stable while stalled. Caller payload changes after command acceptance do not affect the captured descriptor. Nonfatal rounded/saturated flags accumulate. A child fatal status or error stops further calls and reports a held fatal completion; an error flag without a fatal status becomes protocol_error. Command-ready stays low after fatal completion until reset. Global reset clears the captured descriptor, counters and status and suppresses handshakes; the shared switch and service must reset together.

## Configuration and integration

Both wrappers require TOKENS, D, K and LAYER_WORDS. QKV takes three WEIGHT_OFFSETS and three BIAS_OFFSETS in Q/KEY/VALUE order; output projection takes WEIGHT_OFFSET and BIAS_OFFSET. Parameter addresses are the captured layer base plus the corresponding manifest offset. All peers must receive matching dimensions, bank depths and manifest layout. Zero dimension/extent defaults require integration configuration; offsets do not select a trained image.

Static checks bound dimensions to positive 16-bit counts, ensure token storage is addressable, and ensure every D-by-D weight tensor and D-element bias fits the configured layer extent. Accepted commands with an invalid layer index or overflowing layer-base extent fail before issuing linear requests. Calculations widen before narrowing addresses.

External prototypes and production file lists include these implementations. The compilation fixture connects the actual attention parent to these wrappers and linear-switch clients 1 and 2. Its small configurations are interface/elaboration fixtures, not a complete model-selected numerical assembly.

The command switch's existing interface-width checks are now simulation-only under `ifndef SYNTHESIS`: the synthesis frontend used for bounded checks cannot evaluate `$bits` on interface members in those initial guards. Simulation/ordinary compilation retains them. Routing and payload logic are unchanged.

## Verification evidence

The final projection suite passed **24/24 checks**, recorded in `rtl/tests/projection-results.json`. Compilation/elaboration passed with **0 errors, 0 warnings**. The existing five-client router safety regression passed at 24 steps. Structural inventory remains **29 public module kinds / 65 service endpoints**; the shared projection helper is internal.

The projection suite uses each actual public wrapper, the actual typed five-client command switch, an independent descriptor/completion scoreboard and a test-only delayed linear service. Only the selected client is active; simultaneous arbitration is outside this harness and covered separately by the router regression.

The suite has 24 checks: eighteen prescribed-readiness scenarios, two 24-step arbitrary-readiness safety checks, and four completion witnesses with assertions enforced as constraints. Scenarios exercise repeated commands with changed layer base/index, numerical-service failure, error without fatal status, invalid layer index, overflowing parameter base, reset during service wait, reset around completion, final-call failure, and TOKENS=D=1. Normal tests use three tokens and width two.

Scenario bounds are 64 or 192 steps and explicitly require completion under periodic backpressure. Witnesses use a 192-step bound, periodic readiness and an explicit startup stall, requiring completion plus a stall; reset witnesses also require reset recovery. Witness success requires **model found**. Short safety checks do not prove unbounded liveness. VCDs are SAT-generated traces, not event-driven simulation.

The scoreboard checks every source/destination bank and address, vector length, weight/bias address, captured layer base, projection order, completion count, held payload and fatal/reset behavior. The modeled linear service computes no numerical result and performs no tensor writes. Numerical correctness, physical SRAM mapping, full-size execution, area and timing are not claimed.

Evidence: `rtl/tests/projection-results.json`, `projection-*-scenario-*.log`, `projection-*-prove-*.log`, `projection-*-cover-*.log`, corresponding witness VCDs and `router-projection-regression-5.log`. Reproduce from the project root using the existing local verification packages:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_projection_suite.py
python rtl/tests/run_formal.py 5
node rtl/architecture-connections.cjs
```

## Review and next work

Review projection order, manifest offsets, token addressing, linear completion barriers and reset/error handling. Next are score-row and weighted-value control. Softmax, FFN/residual, later-stage controllers and numerical services remain unfinished. This checkpoint does not complete numerical attention or Stage 3.
