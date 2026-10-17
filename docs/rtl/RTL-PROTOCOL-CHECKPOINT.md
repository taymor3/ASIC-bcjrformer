# Protocol RTL checkpoint

10 October 2026. The structural architecture checkpoint was approved by Taimor's instruction to continue. This checkpoint implements its first step: protocol infrastructure. Arithmetic, model selection and technology choices remain deferred.

Update: this checkpoint was approved. Memory adapters are now implemented; current connected verification evidence and remaining limits are in `RTL-MEMORY-CHECKPOINT.md`. The unverified memory-fabric statement below describes this earlier protocol snapshot.

## Implemented modules

| File | Behavior |
|---|---|
| rtl/protocol/transaction_router.sv | Lowest-index arbitration, one buffered accepted request, retained owner, stable service request through stalls, response routing to owner, reset cancellation |
| rtl/protocol/command_switch.sv | Typed command/completion interface wrapper; preserves result, fatal error and four status bits |
| rtl/protocol/arithmetic_switch.sv | Typed arithmetic wrapper; additionally buffers request tag and returns response tag |
| rtl/protocol/memory_fabric.sv | 13-client default; parameter/scratch dispatch; held local error response for invalid work |

All modules use the approved rising-edge clock and synchronous active-high state reset. Handshake outputs are suppressed while rst is asserted, so no request is accepted during reset. State clears on the clock edge. Payload/status hold during stalls relies on the downstream service obeying its ready/valid response contract.

Acceptance into the router's request buffer is the client's handshake; dispatch to the service happens later. The client can release/change its request afterward. A new higher-priority client cannot replace the captured request. No second client is accepted until the retained response is accepted. A completion-edge replacement is deliberately not implemented. Response routing is direct from the service while ownership is retained; there is no extra response buffer.

## Memory checks and integration rules

The memory fabric validates legal bank ID, configured element address range, bank-specific format, and zero unused high write bits. PARAM and MASK writes are allowed only from client 0, the core loader. The core remains responsible for idle-time parameter loading, image order/commit and blocking writes during compute.

Invalid work is consumed internally and produces one rsp_error=1 response with zero read data; it reaches neither memory adapter. Caller controllers are responsible for converting that error to fatal frame status. The fabric itself remains a transaction service and does not latch a global fatal state.

`BANK_DEPTHS[18]` must be explicitly supplied by integration. Its default zero disables every bank; it cannot silently assume a selected model. This is an added configuration parameter, not a new host signal. A depth of 8 in the elaboration fixture is only a test value. Backing memories are not implemented in this checkpoint.

Switch instantiations now explicitly supply payload types:

```systemverilog
command_switch #(.CLIENTS(2), .CMD_T(layernorm_cmd_t), .RSP_T(empty_t)) norm_switch(...);
command_switch #(.CLIENTS(5), .CMD_T(linear_cmd_t), .RSP_T(empty_t)) linear_switch(...);
command_switch #(.CLIENTS(3), .CMD_T(dot_cmd_t), .RSP_T(accum_t)) dot_switch(...);
arithmetic_switch #(.CLIENTS(2), .REQ_T(denominator_t), .RSP_T(reciprocal_t)) reciprocal_switch(...);
```

External prototypes in rtl/interfaces/bcjrformer_ports.svh have been updated to match. Payload types are the existing provisional package types; this checkpoint does not approve their numerical widths. Interface instances must use the identical types at both ends. Width mismatch guards provide an additional simulation check; they do not replace type consistency review.

## Verification evidence

Compilation/elaboration uses project-local pyslang 12.0.0. The fixture instantiates the intended LayerNorm, linear, dot and reciprocal switch configurations, one-client boundary case, and 13-client memory fabric. It also compiles the external prototypes against the implemented signatures. Result: **0 errors, 0 warnings**.

Bounded formal verification uses project-local YoWASP Yosys 0.69. Its independent transaction scoreboard checks arbitration, one outstanding request, no duplicate dispatch, retained payload/owner, exclusive/correct response routing, response-ready routing, and reset. Service-response stability is assumed when the service is stalled, matching its contract; request arrival, service readiness, client response readiness, response timing and reset are otherwise unconstrained. Properties include request availability while buffered and response availability once dispatched; unlimited service stalls do not imply a completion deadline.

The proof exercises 24 time steps after an initially asserted reset. It is bounded safety verification, not an unbounded proof, performance measurement or integrated simulation. The generic routing engine is checked; wrapper packing and memory validation/dispatch are compiled and reviewed but **not yet dynamically simulated or formally proven end to end**. No claim is made that the whole memory fabric has passed the router's formal properties.

All five intended client-count cases passed: **1, 2, 3, 5 and 13 clients, 24 steps each**. Saved checker output is in `rtl/tests/router-formal-1.log` through `router-formal-13.log` for those counts. No area/timing result was produced by these SAT checks.

Reproducible commands, from the project root with the bundled Python:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_formal.py 1
python rtl/tests/run_formal.py 2
python rtl/tests/run_formal.py 3
python rtl/tests/run_formal.py 5
python rtl/tests/run_formal.py 13
```

The scripts load validation dependencies from rtl/.tools, which is ignored by Git. No global Python installation was changed. Use an environment that can access these project-local installed files. A fresh checkout needs these validation dependencies installed separately. Production file order is in rtl/protocol/files.f; declaration-only prototypes are checked by the compile script but excluded from the production file list.

## Review and next step

Review the buffered acceptance/response lifecycle, client-index ordering, explicit type parameters, disabled-by-default bank depths, and loader-only PARAM/MASK writes. Numerical units and controller math remain untouched.

After your approval, implement and verify memory adapters with simulation backing storage and response delays, then use them to exercise invalid requests, committed-write timing and fabric routing end to end. Those tests precede host/core integration. Physical SRAM mapping and numerical verification stay at their separate gates.
