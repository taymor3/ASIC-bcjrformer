# Stage 3 encoder/layer control checkpoint

12 October 2026. This implements the parent control hierarchy for Stage 3. It does not complete numerical encoder processing or the attention, FFN and residual child controllers. Numerical verification remains pending Haiel.

## Implemented controllers

`rtl/control/encoder_ctrl.sv` reuses one layer service for K layers. It sends `{layer_index, layer_param_base}`, waits for the accepted layer response, and advances only after successful completion. Bases are `FIRST_LAYER_BASE + index*LAYER_STRIDE`; integration supplies the stride and layer-region size. Static checks require positive bounded K, nonoverlapping configured regions, and addressable parameter ranges. These are manifest parameters, not selected model values.

`rtl/control/layer_ctrl.sv` captures the layer descriptor and follows this exact order:

1. LN1: sweep every token, reading X and writing U.
2. Attention: one complete-frame command with the captured layer descriptor.
3. Residual 1: sweep every token, X + ATTN_OUT → X.
4. LN2: sweep every token, reading updated X and writing reused U.
5. For each token: FFN U[token] → VECTOR, then residual 2 X[token] + VECTOR → X[token].

All LN2 responses are accepted before the first FFN starts. VECTOR is not overwritten by another token's FFN until the preceding residual completes. Normalization and residual sweeps restart token index zero at each phase. Both services are reused rather than duplicated.

Descriptors contain D-element lengths, token addresses `token*D`, the approved logical banks, manifest-relative LayerNorm gamma/beta bases, and the captured layer base for attention/FFN. LayerNorm source is X and destination U. Residual 1 uses token-relative ATTN_OUT; residual 2 uses VECTOR address zero. FFN writes VECTOR address zero. The layer response follows the final accepted residual-2 completion.

Integration supplies TOKENS, D, K, LAYER_WORDS, and four LayerNorm offsets. Static checks cover positive dimensions, count/address limits and norm ranges inside the layer region. Accepted descriptors are checked for layer-index and parameter-range bounds. The integration manifest remains responsible for matching layer regions, all other child tensor offsets and real bank capacities.

## Handshake, errors and reset

Each controller has IDLE, ISSUE, WAIT_RESPONSE and RESPONSE states. Requests and descriptors stay stable through stalls; only the selected child's response is accepted. Status accumulates across child completions and across layers. A fatal status bit or error flag stops further work and produces a held error response; an error flag without a fatal status bit becomes protocol_error. After that response is accepted, command-ready remains low until reset.

The controllers have only one outstanding child operation each, so their error path consumes that operation's response before reporting failure. Child responses must obey the existing committed-write/drained-work contract. There is no memory grant held by either parent across a child command. Reset suppresses handshakes and clears phase/index/descriptor/status state; global reset must also reset all children, switches and the host/core controller.

## Verification results and limits

Compilation/elaboration: **0 errors, 0 warnings**. Public structural inventory: **29 module kinds / 65 service endpoints**. **13/13 composed encoder/layer checks passed**:

- Nine prescribed-stall scenarios: two complete encoder commands; norm numerical error; a late FFN protocol failure; invalid encoder command; reset during a child wait; reset around final completion; error without fatal bits; invalid layer index; and an unaddressable parameter base.
- Two 24-step safety checks with arbitrary service/host readiness, covering normal operation and an invalid layer descriptor.
- Two completed/stalled witness searches, including reset recovery. Assertions are constraints in these searches, and passing evidence requires **model found**.

The actual encoder and layer modules are composed in `rtl/tests/encoder_layer_formal.sv`. Its independent scoreboard checks the flattened child schedule, every normalization/residual/FFN/attention descriptor, no overlap, layer base/index progression, held requests/results, status propagation and fatal locking. The normal scenario executes K=3 layers twice, exercising a non-power-of-two layer count and command restart. Toy values TOKENS=2, D=3, layer extent 20 and stride 64 are control fixtures, not a complete trained parameter image or a selected numerical configuration.

Norm, attention, FFN and residual services are **test-only delayed completion/status models**. No inference values are computed. Their completion semantics are assumed; the scoreboard does not prove their internal arithmetic or committed writes. The compilation fixture also connects the layer's norm caller to the actual shared norm switch, but it is not a numerical integration simulation.

Scenario bounds are 64, 192 or 384 steps and include an explicit finish assertion, under a prescribed periodic stall schedule. Arbitrary-readiness checks have a shorter bound and do not establish end-to-end liveness. Witnesses are SAT-generated VCDs, not event-driven simulation traces. No unbounded proof, numerical accuracy, physical-memory timing, area or throughput claim is made.

Evidence: `rtl/tests/encoder-layer-results.json`, `encoder-layer-scenario-*.log`, `encoder-layer-prove-*.log`, and `encoder-layer-cover-*.log`. Production order and external prototypes include both controllers. Reproduce from the project root with Python and the existing local packages:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_encoder_layer_suite.py
node rtl/architecture-connections.cjs
```

## Review and remaining Stage 3 work

Review layer-region configuration, LN1/LN2 sweep barriers, FFN/residual ordering, descriptor addresses, error propagation and reset behavior. The next subcheckpoint is attention control: QKV phase, head/query loops, query-mask reads, score/softmax/weighted-value sequencing and output projection. FFN/residual controllers and shared numerical services also remain unfinished. This is a parent-controller checkpoint, not completion of the entire Stage 3 RTL.
