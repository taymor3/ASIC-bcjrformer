# Stage 3 attention-parent control checkpoint

12 October 2026. `rtl/control/attention_ctrl.sv` now implements the existing attention-parent interface. This is sequencing/control RTL, not numerical attention or completion of its child controllers. Haiel's numerical verification remains pending.

## Implemented schedule

On an accepted layer command, capture its layer index/base and clear head/query counters and accumulated status. Then:

1. Command QKV once and wait for its successful response, which must certify all three projections are committed.
2. Iterate heads outside queries. For each `(head,query)`, read the original padding bit from `MASK[query]` using FMT_BIT.
3. Command score for that row, then softmax with the captured `padded_query`, then weighted value with the same row descriptor. Wait for each response before proceeding.
4. Increment query, restarting it at zero when advancing the head. Only after every weighted-value row completes, command output projection once with the captured layer descriptor.
5. Hold completion/status until accepted. Success depends on the projection service certifying all its destination writes are committed.

Score and weighted descriptors are `{head_index,query_index}`. QKV and output projection receive the captured `{layer_index,layer_param_base}`, even if the caller changes its command payload afterward. Softmax receives the accepted memory response's padding bit. Ready/valid requests remain stable through stalls, and counters move only after weighted completion.

Padding is query-row behavior. No key mask, static mask, tensor-copy split/join, or skip of padded queries was added. The parent issues the normal score/softmax/weighted sequence for every row; the softmax child is responsible for uniform 1/L probabilities on padded rows and normal softmax over all keys on other rows. This checkpoint does not compute or numerically verify those probabilities.

## Configuration and errors

Integration supplies TOKENS, H, D, K and LAYER_WORDS. Positive count/address limits and D divisibility by H are checked. Defaults of zero require configuration and do not select a trained model. Accepted commands are rejected if the layer index is out of range or the configured layer extent cannot fit the parameter address space. All peer controllers must receive matching integration dimensions and manifest layout.

A failed mask read becomes protocol_error. A child fatal status bit or error flag stops subsequent requests and reports a held fatal completion. An error flag without either fatal status bit becomes protocol_error. Nonfatal rounded/saturated status accumulates. Only one memory or child operation is outstanding, and its response is accepted before error reporting. After a fatal response is accepted, command-ready remains low until reset. Global reset suppresses handshakes and clears counters, captured descriptor/mask and status; children and memory fabric must also reset.

The external prototype has matching configuration parameters and unchanged command/memory channels. The production file list includes the implemented parent. No test arithmetic was included in production RTL.

## Verification evidence

Compilation/elaboration: **0 errors, 0 warnings**. Public structural inventory: **29 module kinds / 65 service endpoints**. **20/20 attention-control checks passed**:

- Fifteen prescribed-stall scenarios cover repeated commands with changed layer descriptors/masks; failures from QKV, score, softmax, weighted value and projection; late mask-read failure; invalid layer index/base; reset during mask, softmax and completion; all-padded/all-valid queries; and one head/one query.
- Two 24-step safety checks allow arbitrary service, memory and host readiness.
- Three completed/stalled witness searches cover repeated commands, reset recovery and the single-head/query boundary. Assertions are enforced as constraints; success requires **model found**.

The independent scoreboard in `rtl/tests/attention_control_formal.sv` checks every child command, original MASK read, row descriptor, padding flag, captured layer descriptor, no overlap, final projection barrier, status/fatal behavior, request/completion stability and loop restart. The normal configuration uses three heads and two queries, exercising a non-power-of-two head count. Width six is a toy configuration; the boundary case uses H=L=D=1. Input payload is deliberately changed after acceptance to check descriptor capture.

Child services are **test-only delayed completion/status models**, and mask responses are modeled. QKV, score, softmax, weighted-value and projection computations and their committed tensor writes are not proved. The connected compilation fixture wires the actual layer parent to this attention parent and memory-fabric client 3; compilation is not a complete numerical integration run.

Scenario bounds are 64, 128, 192 or 320 steps and explicitly require completion under periodic backpressure. Arbitrary-readiness checks use a shorter bound and do not prove end-to-end liveness. Witness VCDs are SAT-generated traces, not event-driven simulation. No numerical accuracy, full-size memory, unbounded proof, area or timing result is claimed.

Evidence: `rtl/tests/attention-results.json`, `attention-scenario-*.log`, `attention-prove-*.log`, `attention-cover-*.log` and the corresponding VCDs. Reproduce from the project root with Python and the existing local verification packages:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_attention_suite.py
node rtl/architecture-connections.cjs
```

## Review and next work

Review QKV/projection barriers, head/query iteration, query-padding forwarding, captured descriptors, held payloads and error/reset handling. Next are the QKV and output-projection token-loop controllers that call the shared linear service. Score-row, softmax, weighted-value, FFN/residual controllers and the shared numerical engines also remain unfinished. This completes the attention parent, not Stage 3's full numerical datapath.
