# Microarchitecture

![Five-stage BCJRFormer microarchitecture](images/bcjrformer-microarchitecture.svg)

`bcjrformer_core` is the assembly. `core_ctrl` manages loading, frame execution, outputs, and errors. Stage controllers issue typed child commands and wait for completion. Tensor data crosses stage boundaries through memories rather than full-tensor ports.

## Physical hierarchy

```text
bcjrformer_core
├── core_ctrl → embedding → position → encoder → final → aggregation
├── encoder_ctrl → layer_ctrl
│   ├── attention_ctrl → QKV → score → softmax → weighted value → output projection
│   ├── residual_ctrl
│   └── ffn_ctrl → linear → GELU → linear
├── shared LayerNorm, linear, and dot controllers
├── shared MAC, EXP, reciprocal, RSQRT, and GELU units
├── command/arithmetic switches
└── 13-client memory fabric → parameter_mem + scratch_mem
```

The hierarchy sketch shows command relationships; shared services are single physical instances. K layers and H heads are iterations, not duplicated blocks. The five stages are sequential processing phases, not an overlapped CPU-style pipeline.

## Shared compute

| Service | Callers | Main role |
|---|---|---|
| LayerNorm | Embedding, encoder layer | Sum/variance, RSQRT, affine conversion |
| Linear | Embedding, QKV, attention output, FFN, final projection | Bias, output-major weights, dot requests |
| Dot | Linear, score row, weighted value | Operand reads, MAC accumulation |
| Reciprocal | Softmax, aggregation | Normalize by denominator/count |
| EXP | Softmax | Taylor exponential of shifted scores |
| RSQRT | LayerNorm | Inverse standard deviation |
| GELU | FFN | Taylor activation before explicit storage conversion |

Command switches have 2 LayerNorm callers, 5 linear callers, and 3 dot callers. The reciprocal arithmetic switch has 2 callers. Owners are retained through a response, so another caller cannot consume a previous caller's result.

## Connections and handshakes

`bcjr_cmd_if` bundles a typed command, command ready/valid, and completion ready/valid with status. `bcjr_arith_if` bundles operands and results with ready/valid, tags, and status. `bcjr_mem_if` bundles memory requests and responses. These interfaces represent wiring; they are not calculating hardware blocks.

Transfers happen on a rising edge with both valid and ready asserted. A producer holds payload and valid during a stall. Module/interface `#(...)` supplies elaboration-time parameters or types; the following instance name and `(...)` identify an instance and connect its ports.

All controllers use one rising-edge clock and synchronous active-high reset. Reset cancels outstanding interface work and invalidates the host's parameter image. Behavioral memory contents are retained, but a reload/commit is required before reuse after reset.

## Memory and completion

One parameter bank and 17 scratch-bank kinds store features, mask, X/U, Q/K/V/Z/attention output, token/FFN/vector workspaces, score/EXP/probability rows, logits, and output. A single memory fabric connects 13 clients to parameter and scratch adapters. See the [typed bank definitions](../rtl/interfaces/bcjrformer_contract_pkg.sv) and [complete capacity expressions](../rtl/bcjrformer_core.sv).

Each memory operation completes only when its response confirms the operation. A controller reports success after its destination writes commit. It never reserves the memory interface while waiting for a child that needs it. Memories are behavioral arrays awaiting technology-specific mapping.

The host commits a parameter image after acknowledged writes, submits frame/features/mask, accepts indexed logits, and consumes a held completion report. Fatal protocol/numerical errors require reset; an empty-position frame is recoverable with retained parameters. See [core_ctrl.sv](../rtl/control/core_ctrl.sv) and the [complete connection inventory](../rtl/RTL-CONNECTIONS.md).
