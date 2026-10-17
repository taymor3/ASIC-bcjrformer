# RTL architecture: structural completion checkpoint

16 October arithmetic update: `exp_unit` and `gelu_unit` are Taylor-series arithmetic submodules in the core; they no longer load function lookup tables. GELU's response is `gelu_t` signed32/F22, explicitly converted at FFN activation storage. See `RTL-TAYLOR-CHECKPOINT.md` for Lagrange remainder/error budgets.

13 October 2026 implementation status: all public modules, provisional numerical services and the complete `bcjrformer_core` assembly are implemented. See `RTL-COMPLETE-CHECKPOINT.md` and `RTL-COMPLETE-REVIEW.md` for current evidence and review boundaries. The dated implementation updates below are historical; their unfinished-module statements are superseded. Numerical validation and physical implementation remain open.

10 October 2026. Checkpoint 1 was approved by Taimor. This document completes the next structural pass for review; it does not select a model, numeric implementation or technology. Numerical verification remains with Haiel. Those open questions will be handled after architecture review, as requested.

Update: Taimor approved this structural checkpoint by instructing us to continue. The implemented protocol infrastructure and its verification limits are recorded in `RTL-PROTOCOL-CHECKPOINT.md`. The statement below about no behavioral modules describes the pre-implementation structural snapshot.

Current implementation update: protocol switches/fabric and behavioral memory adapters are implemented, and host/core control now exists in `rtl/control/core_ctrl.sv`. See `RTL-CORE-CHECKPOINT.md` for loading, sequencing, output/error behavior and its control-only verification boundary. The complete processing wrapper, stage/subcontrollers and numerical datapaths remain unfinished.

11 October update: `embedding_ctrl` is now implemented, and Stage 2's memory/address/control helper is in `rtl/control/position_sequencer.sv`. See `RTL-STAGES12-CHECKPOINT.md`. The external `position_ctrl` wrapper still awaits its local numerical add/conversion datapath; no global scalar service was added.

12 October: encoder and layer parent controllers are implemented and checked together. `RTL-ENCODER-LAYER-CHECKPOINT.md` records the sweep barriers and per-token FFN/residual sequence. Attention/FFN/residual children and numerical services remain unfinished; this does not complete Stage 3 processing.

The attention parent is now also implemented. `RTL-ATTENTION-CHECKPOINT.md` records QKV completion, head/query iteration, original-mask reads, score/softmax/weighted sequencing and the projection barrier. Its numerical child controllers remain unfinished.

QKV and output-projection token-loop controllers are now implemented using the shared internal projection helper. `RTL-PROJECTION-CHECKPOINT.md` records manifest-relative descriptors, linear completion barriers and verification limits. Score-row, softmax, weighted-value and the numerical linear service remain pending.

## Scope of this checkpoint

The five stages, memory lifetimes, shared service connections, controller responsibilities, and frame/error paths now have a single structural baseline. `rtl/RTL-CONNECTIONS.md` is the complete connection inventory; `rtl/architecture-connections.json` is its machine-readable form. The existing SystemVerilog package, channels and external module declarations remain port contracts. There are no behavioral processing modules yet.

Dimensions, numeric widths/primitive methods, physical RAM choice and frequency are deliberately not frozen by this checkpoint. The earlier `architecture-budget.cjs` and `ARCHITECTURE-BUDGET.json` are deferred planning artifacts, not selected requirements or architecture approval evidence.

## Top-level assembly

`bcjrformer_core` instantiates core_ctrl, one of each stage/subcontroller, shared services, switches and memory adapters. It passes the host interface to core_ctrl and distributes one rising-edge clock and synchronous active-high reset. Controller links transfer descriptors/completion, not full tensors; tensors cross boundaries through logical banks.

The wrapper has:

- Five stage controllers: embedding, position, encoder, final, aggregation.
- Encoder hierarchy: layer, attention, QKV, score row, softmax, weighted value, output projection, FFN and residual.
- Shared linear, LayerNorm and dot controllers; the dot controller calls one MAC unit.
- EXP, RECIP, RSQRT and GELU services with existing ready/valid contracts.
- Three command switches: LayerNorm (2 callers), linear (5), dot (3); one reciprocal arithmetic switch (2 callers).
- One memory fabric with 13 clients, a parameter adapter and a scratch adapter.

These are physical instances for the baseline; K layers and H heads are loops, not duplicated hardware. Diagrams that repeat a shared service show its uses. Head split/join is addressing, not copied data.

## Controller responsibilities and completion boundaries

| Controller | Owns | Completion means |
|---|---|---|
| core_ctrl | Host loading, image/frame validity, stage sequence, output transfer, completion code | All N output transfers accepted, or one held error report |
| embedding_ctrl | Token loop, FEATURE-to-TOKEN copy, norm/linear/norm calls, VECTOR-to-X copy | All X writes committed |
| position_ctrl | m/n/feature loops, P/E reads, widened additions/conversions | All enriched X writes committed |
| encoder_ctrl | k loop, layer-specific parameter descriptor | K successful layer responses accepted |
| layer_ctrl | LN1 sweep, attention, residual1 sweep, LN2 sweep, FFN/residual2 token loop | All second-residual X writes committed |
| attention_ctrl | QKV phase, head/query loops, query-mask read, score/softmax/weighted sequence, output projection | All ATTN_OUT writes committed |
| qkv_ctrl | Projection selection Q then KEY then VALUE; token loop | All three LD projection arrays committed |
| score_row_ctrl | Key loop for one fixed head/query, dot/scale, SCORE writes | One complete L-element score row committed |
| softmax_ctrl | Max pass, exp/store/sum pass, reciprocal, probability write pass or uniform bypass | All L probability writes committed |
| weighted_value_ctrl | Feature loop within fixed head/query, probability-by-V dots | d Z components committed |
| output_projection_ctrl | Token loop, Z-to-ATTN_OUT linear calls | All ATTN_OUT tokens committed |
| ffn_ctrl | First linear, 4D GELU read/replace loop, second linear | D VECTOR outputs committed |
| residual_ctrl | Element loop, capture both operands, add/convert/write | All requested destination sums committed |
| final_ctrl | Token loop, D-to-1 linear calls | L LOGIT values committed |
| aggregation_ctrl | n/m loops, per-position sum/count, reciprocal/scale, private output writes | All N writes committed, or typed empty-position/fatal response |
| linear_ctrl | Output loop, bias read, dot descriptor, conversion, destination write | Every output write acknowledged |
| layernorm_ctrl | Statistics passes, RSQRT, affine pass, conversion and writes | Every normalized output write acknowledged |
| dot_engine | Term loop, two reads, MAC request/result, wide accumulator | Wide result held; it never writes the caller's destination |

Parents issue each child command once, wait for its accepted response, then advance. There is no completion inferred from busy falling. All loops initialize on accepted commands, restart inner counters at each outer iteration, and advance only after the dependent operation/write finishes.

## Execution and storage order

1. Load/commit parameter image while idle. Accept a frame only with a valid image and no pending loader/completion transaction.
2. Load LF features, then L mask bits, each with correct last indication and committed writes.
3. Embedding: per token, copy F input values, LN(F), F-to-D linear, LN(D), copy to X.
4. Position: traverse m/n/j, read X/P/E, add with explicit conversions, write X. No padding skips.
5. For each k: LN1 all X into U; QKV; head/query attention rows into Z; project all Z into ATTN_OUT; residual1 all tokens into X; LN2 all R into reused U; per token FFN into VECTOR, then residual2 into X.
6. Final: all X tokens through D-to-1 linear into LOGIT, including padded tokens.
7. Aggregation: clear S_n/C_n at each n, scan all reads using the same valid bit for sum/count; write each averaged value into OUTPUT. Set output frame-valid only after every position succeeds.
8. Core reads and sends N outputs, holding data/index/last while stalled. Successful frame completion follows the last accepted output.

U reuse begins after attention and residual1; Q/K/V remain live through weighted values; Z remains live through output projection; ATTN_OUT through residual1; R in X through its residual2. FFN_HIDDEN stores the complete first-linear vector before GELU replacement and stays live through second linear. VECTOR holds the final FFN vector until residual2. The output buffer is private during aggregation.

Full bank IDs, capacities and formats are in RTL-interfaces.md. Native width is per bank, not the common memory payload width. Every producer/consumer mapping is explicit there. Model/precision selection will determine concrete capacity; no bank is assumed to fit a physical macro yet.

## Shared-service control architecture

### Command/arithmetic switches

Structural FSM: `IDLE -> WAIT_SERVICE_ACCEPT -> WAIT_SERVICE_RESPONSE -> HOLD_CLIENT_RESPONSE -> IDLE`. HOLD_CLIENT_RESPONSE may be represented by directly holding the service response until the selected client accepts it; no extra response buffer is required by the architecture.

When idle, select the lowest-index requesting client. Latch owner and request, then hold the outgoing service request stable until accepted. Client ready may acknowledge capture into the switch's one request buffer; the selected client's request then belongs to that buffer until dispatched. Nonselected clients have ready=0 and response-valid=0. Route status/result/error/tag only to the retained owner. Keep ownership until response acceptance. No new command replaces the old one on its completion edge in this baseline. Client/service payload types must match. Arithmetic tags are echoed; they do not permit multiple outstanding operations.

Each future switch implementation must explicitly use this buffered-acceptance convention. It prevents a newly arriving higher-priority request from changing a stalled outgoing payload. Existing interface tables require retained requester identity; this defines its implementation behavior.

### Memory fabric and adapters

Structural FSM: `IDLE -> DISPATCH -> WAIT_BANK_RESPONSE -> HOLD_CLIENT_RESPONSE -> IDLE`. Capture one request plus owner at a client handshake; validate bank/format/address against the configured bank table before dispatch. Invalid requests return one held error without accessing storage. Legal PARAM requests go to parameter_mem; other legal banks go to scratch_mem. Route one read value/write acknowledgment to the recorded client. Change ownership only after response acceptance. Retain accepted transactions until drained even after an upstream failure.

Only one global fabric transaction is outstanding. This deliberately serial baseline does not require simultaneous parameter/scratch transactions. A parent waiting for a child releases memory after each transaction; it cannot hold a bank/fabric grant across its entire controller command. That avoids linear->dot and norm->primitive deadlocks.

Memory adapter FSM: `IDLE -> CHECK_REQUEST -> ACCESS_STORAGE -> WAIT_STORAGE -> HOLD_RESPONSE -> IDLE`. Backing storage timing is hidden by ready/valid. A write acknowledgment certifies commitment; a read response returns captured data. Address legality and bank format are checked before access. Macro-specific wiring remains inside the adapters. Reset may cancel pending transactions because it invalidates the entire image/frame.

### Scalar datapaths

Local scalar registers/add/subtract/multiply/conversion serve the owning controller's existing schedule. Normalization uses its wider statistics datapath; the dot MAC is not a substitute for it. Shared_scalar diagrams specify arithmetic behavior, while the current boundary inventory has no global scalar service port. Physical scalar sharing, if later needed, must be a separately reviewed optimization with explicit widths and connections. No such change is needed to finish this structural baseline.

## Host, reset and error paths

Parameter-load framing and ordering are owned by core_ctrl. A successful image requires all expected ordered writes and acknowledgment acceptance before commit. New loading invalidates the previous image; writes are blocked during compute. Bad address/order/commit is fatal. After a frame, the committed image can serve another frame without reload. Reset invalidates it.

Three completion codes are structural: OK, EMPTY_POSITION, FATAL. Host completion_error is 0 only for OK. completion_position identifies the first empty n and is zero for OK/FATAL. All completion fields/status stay stable until accepted.

- EMPTY_POSITION: stop aggregation, drain accepted work, invalidate the whole OUTPUT frame, return typed response. Core emits no logits for that frame, holds host error, then returns idle after acceptance without reset. Parameters remain valid.
- FATAL: stop issuing new work, consume outstanding child/memory/primitive responses, invalidate current frame, propagate fatal status, hold host error. Require reset before another command. There is no rollback of stored words.
- Rounded/saturated conversions: accumulate nonfatal status. Do not independently discard the frame.

A fatal read failure during host output may happen after earlier outputs were sent; the receiver must invalidate that incomplete frame when it receives fatal completion. The no-partial-output guarantee applies to aggregation/EMPTY_POSITION because host readout starts only after successful aggregation.

Synchronous reset clears valids, request buffers, owner state, counters and frame/image-valid flags together. Memory erasure is unnecessary. Reset overrides payload-hold requirements. No host-input timeout is assumed.

## Architecture verification before behavioral RTL

The generated inventory checks every declared module kind, concrete controller/engine service port, and unique endpoint ownership. It passes for 29 module kinds and 65 service endpoints. Regenerate it with `node rtl/architecture-connections.cjs` after a structural change. These checks concern architecture coverage; they do not compile SV or prove runtime behavior.

Behavioral RTL verification must demonstrate stable stalled requests/results; one response per accepted operation; no duplicate destination writes; counters terminate/restart correctly; retained switch/fabric owners; successful completion after committed writes; reset in every wait state; and empty-position recovery without logits or parameter loss. Arithmetic data comparison waits for Haiel's approved reference/formats.

## Review checkpoint and next implementation order

Review the hierarchy/connections, buffered switch/fabric handshakes, controller boundaries, memory lifetimes and frame/error lifecycle above. The implementation order for the structurally approved RTL is:

1. Protocol infrastructure: buffered command/arithmetic switches and memory fabric.
2. Memory adapters with a simulation backing store and explicit response timing.
3. Host/core control and stage sequencing using testbench response models.
4. Stage/subcontroller loops with the agreed interfaces and bank layout.
5. Integrate numerical datapaths only after the separate numerical gate.

Testbench response models are verification aids, not completed compute hardware. No placeholder arithmetic will be presented as working RTL.

After your OK on this structural checkpoint, tackle the remaining model, memory/technology and numerical questions. Do not return to the provisional budget as a selected model. No new model decision is required to review these connections and controls.
