> 17 October correction: LayerNorm statistics use exact nearest-even division; FFN hidden storage is signed32/F22 and its consuming dot uses signed64/F32. See [fix checkpoint](RTL-REVIEW-FIXES-2026-10-17.md).

# BCJRFormer: block inputs and outputs at the RTL boundary

16 October 2026: all public module contracts have matching implementations in the production file list. The generated `rtl/interfaces/bcjrformer_ports.svh` contains their current configuration parameters. `bcjrformer_core` accepts F/M/N/D/H/K, MEMORY_DELAY and STATIC_MASK (unsupported true configurations are rejected); it derives the canonical manifest and bank depths. EXP/GELU table paths were removed when those units changed to Taylor arithmetic. GELU requests remain `act_t`; its response is now signed32/F22 `gelu_t`, with explicit conversion to activation storage in FFN. See `RTL-TAYLOR-CHECKPOINT.md`. Earlier implementation-status paragraphs below are historical; numerical type widths remain provisional.

Draft for interface review, 30 September 2026. This defines ports and connections; it does not implement the FSMs, memories, or arithmetic. The numeric formats remain provisional.

Phase-1 consolidation, 10 October 2026: start review at `ARCHITECTURE-CHECKPOINT-1.md`. Stages 1–2 follow `RTL-specification.md`; Stages 3–5 follow `Stages3-5-design.md`. Older generated publication views are historical until rebuilt and reviewed. These changes await Taimor's checkpoint approval.

Checkpoint 1 is now approved. The next structural pass is `RTL-ARCHITECTURE.md`, with exact link/client ordering in `rtl/RTL-CONNECTIONS.md`. It specifies one buffered request per switch/fabric, owner capture at client acceptance, stable service requests, and ownership through accepted completion. New numerical/model/technology choices remain deferred.

The structural pass is now approved and protocol modules exist in `rtl/protocol`. See `RTL-PROTOCOL-CHECKPOINT.md` for tested configurations and limits. Command switches require CLIENTS/CMD_T/RSP_T, arithmetic switches CLIENTS/REQ_T/RSP_T; the memory fabric requires integration-supplied BANK_DEPTHS[18], default zero. The new type/depth parameters have matching external prototypes. Full stage/arithmetic RTL remains unfinished.

Memory adapters now exist in `rtl/memory`. Parameter adapter configuration is DEPTH/RESPONSE_DELAY; scratch configuration is BANK_DEPTHS[18]/RESPONSE_DELAY. All depths default to disabled zero and delay defaults to one. These behavioral stores preserve committed words on reset and hold responses until accepted. See `RTL-MEMORY-CHECKPOINT.md` for connected tests and review decisions; physical SRAM mapping is still open.

Host/core control now exists in `rtl/control/core_ctrl.sv`. It uses the existing host, stage and memory channels, with explicit `PARAM_WORDS`, `FEATURE_WORDS`, `MASK_WORDS` and `OUTPUT_WORDS` integration parameters (zero defaults require configuration). The `.svh` prototype matches this implementation. `RTL-CORE-CHECKPOINT.md` records loader ordering, commit collisions, completion recovery/fatal locking and testbench-model limits; stage/math RTL remains unfinished.

11 October: the Stage 1 controller now uses explicit F/D/TOKENS and six manifest base parameters, with a matching external prototype. Stage 2's internal sequencer uses an internal `position_add_req_t` ready/valid boundary for its two local additions/conversions. The external `position_ctrl` contract stays unchanged and its numerical wrapper remains pending. See `RTL-STAGES12-CHECKPOINT.md` for exact completion/verification limits.

12 October: encoder/layer parents are implemented with matching external configuration parameters: K, layer stride/extent and first base for encoder; TOKENS/D/K, layer extent and four norm offsets for layer. Command channels and descriptor types remain unchanged. See `RTL-ENCODER-LAYER-CHECKPOINT.md`; numerical children remain pending.

The implemented attention parent adds TOKENS/H/D/K/LAYER_WORDS configuration to its matching prototype, preserving all existing channels and descriptors. It reads BANK_MASK at the query index with FMT_BIT, captures the padding bit, and forwards it to softmax. See `RTL-ATTENTION-CHECKPOINT.md`; no key-mask or new shared arithmetic service was added.

QKV and output projection now have matching TOKENS/D/K/LAYER_WORDS parameters and manifest weight/bias offsets in their implementations and external prototypes. Existing layer-command and linear-command channels are preserved. See `RTL-PROJECTION-CHECKPOINT.md` for token/projection ordering and control-only verification limits.

Read alongside `BCJRFormer_design_review_Amit.tex`, `bcjrformer_asic_architecture_v5.tex`, `bcjrformer-architecture.html`, and `RTL-specification.md`. The review's five-stage schedule is the baseline. The local `bcjrformer.py` and `modules.py` confirm the model ordering, query-row mask, FFN, and aggregation branches.

The SystemVerilog counterparts are:

- `rtl/interfaces/bcjrformer_contract_pkg.sv`: packed descriptors, data types, bank IDs, and status.
- `rtl/interfaces/bcjrformer_channels.sv`: every wire and its input/output direction, using interface modports.
- `rtl/interfaces/bcjrformer_ports.svh`: external module port declarations. These intentionally have no implementations.

## 1. What crosses a block boundary

The five stages exchange tensors through memory. For example, Stage 1 writes the X bank and returns a response. The core then commands Stage 2, which reads X. There is no full `[L,D]` array on the wires between those controllers.

Every physical block has `input logic clk` and `input logic rst`: rising-edge clock, synchronous active-high reset. Each controller also has a command input and a completion output. A controller that delegates work has command outputs and response inputs for its children. A controller that accesses data has a memory request output and memory response input.

The words **input** and **output** below are always relative to the block named in the table. In particular, `ready` runs opposite to `valid`.

### Model configuration versus signal widths

`F,N,M,D,H,K` are compile-time model configuration, not host input signals. `L=M*N`, `d=D/H`, `FF=4*D`. The target checkpoint must determine these values; this draft does not invent them. All stage dimensions and parameter tensor offsets come from one matching integration configuration/manifest.

| Type / width | Meaning |
|---|---|
| `act_t`: signed 16 bits, fraction 10 | Stored feature, weight, bias, normalized value, residual, converted FFN activation, logit |
| `gelu_t`: signed 32 bits, fraction 22 | Taylor GELU function response before separate FFN storage conversion |
| `score_t`: signed 48 bits, fraction 20 | Scaled attention score |
| `probability_t`: unsigned 24 bits, fraction 22 | Exponential or attention probability |
| `accum_t`: signed 64 bits | Dot result; fraction 20 in standard mode, 32 in weighted-value mode |
| `count_t`: unsigned 16 bits | Vector length or zero-based layer/head/query index, according to field |
| `addr_t`: unsigned `ADDR_W` bits | Word/element address within a bank, or element stride |
| `ptr_t`: `5+ADDR_W` bits | `{bank, addr}`, identifying a logical bank and element |
| `status_t`: 4 bits | `{protocol_error, numeric_error, saturated, rounded}` |
| `empty_t`: 1 bit, tied to 0 | Reserved payload for commands/responses with no extra data |

`ADDR_W=32` is an explicit interface starting choice, not a model property. Before integration, prove each bank depth and parameter-word count fits it, or increase it in the package. All bank-size and parameter-base calculations use at least 64-bit arithmetic before narrowing. Native RAM addresses may be narrower behind the adapter. Host output index width is `INDEX_W=max(1,$clog2(N))`; set this when instantiating `bcjr_host_if`, whose default 1 is only a placeholder.

Require positive dimensions, `D%H==0`, and `F,L,D,4D,K,d <= 65535`. Zero lengths are illegal. Since `L=M*N`, M and N are also bounded. A 16-bit field can carry the count 65535; a loop counter must still use a last-index comparison or enough bits for its termination count. Host feature counters must represent the full `L*F` load, not just a vector length.

## 2. Common controller command and completion signals

This is the `command` port on a controller, viewed from that controller. `CMD_T` is specified per block below.

| Signal | Direction | Width | Meaning |
|---|---|---:|---|
| `command.cmd_valid` | Input | 1 | Parent presents a command |
| `command.cmd_ready` | Output | 1 | Controller can accept that command |
| `command.cmd` | Input | `$bits(CMD_T)` | Descriptor; captured only on valid AND ready |
| `command.rsp_valid` | Output | 1 | Completed result/status is available |
| `command.rsp_ready` | Input | 1 | Parent accepts completion |
| `command.rsp` | Output | `$bits(RSP_T)` | `empty_t` for most controllers; `aggregation_rsp_t` for aggregation; `accum_t` for dot engine |
| `command.rsp_error` | Output | 1 | Fatal failure; OR of the two fatal status bits |
| `command.rsp_status` | Output | 4 | OR of local and accepted child statuses for this command |

A child port such as `embedding_ctrl.linear` has exactly the **opposite** directions: the embedding controller outputs `linear.cmd_valid`, `linear.cmd`, `linear.rsp_ready`; it inputs `linear.cmd_ready`, `linear.rsp_valid`, `linear.rsp`, `linear.rsp_error`, `linear.rsp_status`.

Only one command may be outstanding per service. Command-ready stays low while executing or holding completion. No same-edge replacement command is required. Completion remains valid and stable until accepted. Success means all commanded writes have returned successful write acknowledgments. It never means only that a MAC finished. Parents wait for completion, not a falling busy bit.

`rounded` and `saturated` are nonfatal and may coexist. `numeric_error` includes accumulator overflow and arithmetic-domain errors; `protocol_error` includes illegal descriptors, addresses, formats, and framing. A fatal result stops new work. Drain already accepted transactions, propagate one error completion, and require reset before another command. Successful earlier writes are not rolled back; the failed frame is invalid.

Reset flushes pending transactions across all blocks, clears valid/ownership/status state, and invalidates the parameter image and frame. Memory data need not be cleared. Data fields are irrelevant while valid is low. Reset is the exception to holding a stalled valid/payload.

## 3. Top-level external input/output signals

`bcjrformer_core` exposes `clk`, `rst`, and `bcjr_host_if.core host`. These are individual wires grouped into an interface, not another protocol converter. They may later be flattened into conventional named ports with `_i`/`_o` suffixes.

| Signal(s), prefixed `host.` | Direction at core | Width | Meaning |
|---|---|---:|---|
| `param_valid` | Input | 1 | Parameter write request |
| `param_ready` | Output | 1 | Accept parameter address/data |
| `param_addr` | Input | `ADDR_W` | Sequential parameter word address |
| `param_data` | Input | signed 16 | Learned parameter at fraction 10 |
| `param_rsp_valid` | Output | 1 | Parameter write has committed or failed |
| `param_rsp_ready` | Input | 1 | Host accepts write acknowledgment |
| `param_rsp_error` | Output | 1 | That write failed |
| `parameter_commit` | Input | 1 | One-cycle image-finalization strobe; no ready |
| `frame_valid` | Input | 1 | Request a new frame |
| `frame_ready` | Output | 1 | Committed image present and core can accept a frame |
| `feature_valid`, `feature_data`, `feature_last` | Input | 1, signed 16, 1 | One prepared window feature |
| `feature_ready` | Output | 1 | Accept current feature |
| `mask_valid`, `mask_bit`, `mask_last` | Input | 1 each | One original padding bit; 1 means padded |
| `mask_ready` | Output | 1 | Accept current padding bit |
| `logit_valid`, `logit_data` | Output | 1, signed 16 | One aggregated output logit |
| `logit_index`, `logit_last` | Output | `INDEX_W`, 1 | Position n and final-position marker |
| `logit_ready` | Input | 1 | Receiver accepts output |
| `completion_valid`, `completion_error` | Output | 1 each | Frame completion; error is high for recoverable empty-position or fatal failure |
| `completion_code` | Output | 2 | OK=0, EMPTY_POSITION=1, FATAL=2; encoding 3 reserved |
| `completion_position` | Output | `INDEX_W` | First failing n for EMPTY_POSITION; zero otherwise |
| `completion_ready` | Input | 1 | Host accepts completion |
| `busy` | Output | 1 | Frame accepted through completion acceptance; also high while holding an idle-time error completion |
| `status` | Output | 4 | Sticky current numerical/protocol status |

**Proposed refinement:** the three `param_rsp_*` signals make write commitment observable. The existing specification requires commit after the final write response but lists no external write response. This draft exposes it rather than assuming fixed memory latency. This is a new port choice for review.

Parameter loading occurs while idle, one outstanding write at a time, addresses `0..PARAM_WORDS-1`. Invalidate the old image when the first new write is accepted. Commit is legal only after the exact final successful acknowledgment was accepted on an earlier edge, with no write pending or presented. An illegal commit/address latches protocol error, produces one error completion after draining any accepted transaction, and requires reset. An illegal accepted write also receives an error write acknowledgment. Prior writes remain stored but the image is invalid. Assert parameter-ready in the idle load state independently of address legality so an invalid presented address can be accepted and reported. The host must not assert commit and write-valid together.

Frame-ready requires a committed image, no pending write/response, no parameter write or commit presented, no fatal state, and no outstanding completion. Parameter writes have priority over frame commands. `busy` is not a parameter-loader-ready indication; use the channel handshakes.

After frame acceptance, transfer `L*F` features in `(m,n,f)` order, then `L` mask bits in `(m,n)` order. The core buffers each accepted word until its memory write commits; next-stage execution waits for the final commit. Feature/mask last must be true exactly on their final accepted element. Unexpected valid on a closed channel is simply backpressured; the host must honor ready. A missing/early last on an accepted element is fatal. No timeout is assumed for a host that stops sending.

Transfer `N` logits in increasing n; `logit_last=(n==N-1)`. Keep data/index/last stable under backpressure. Successful completion appears only after the last output handshake. On failure, drain accepted work and return an error completion without claiming a complete output vector. Status nonfatal bits clear on accepted frame; fatal bits clear only on reset. Completion and status remain stable while completion is stalled.

## 4. The five stages and their actual module ports

All `command` ports below use the callee directions in section 2. All child ports use caller directions. A listed `mem` port uses section 6. All completion response payloads are `empty_t` unless explicitly stated.

| Module | Command payload input | Child command outputs (and response inputs) | Memory request output | Results available when its completion is accepted |
|---|---|---|---|---|
| `core_ctrl` | Host `frame_valid`/`frame_ready` | `embed`, `position`, `encoder`, `final_project`, `aggregate` | `mem` for parameter/frame loading and output reading | N host output transfers, then host completion |
| `embedding_ctrl` | `empty_t` | `norm: layernorm_cmd_t`; `linear: linear_cmd_t` | `mem` for feature-to-token and result-to-X copies | X contains `e[L,D]` |
| `position_ctrl` | `empty_t` | None; two widened additions/conversions are local | `mem`: read X/P/E; write X | X contains position/read-enriched tokens |
| `encoder_ctrl` | `empty_t` | `layer: layer_cmd_t` | None | X contains final layer results |
| `final_ctrl` | `empty_t` | `linear: linear_cmd_t` | None; linear writes logits | LOGIT contains L signed logits |
| `aggregation_ctrl` | `empty_t` | Arithmetic `reciprocal`, detailed below | `mem`: read LOGIT/MASK; write OUTPUT | OUTPUT contains N signed logits |

Core stage links use `bcjr_cmd_if#(empty_t,empty_t)` except aggregation, which uses `bcjr_cmd_if#(empty_t,aggregation_rsp_t)`. There is one physical instance of each of the five stage controllers. Stage command descriptors are empty because dimensions, logical banks, and stage parameter offsets are fixed at elaboration. This is a deliberate simplification of the earlier more general base-address descriptors, not a runtime reconfiguration interface.

Aggregation response: `code` is OK, EMPTY_POSITION, or FATAL; `position` is the first empty n, zero otherwise. `rsp_error` remains the OR of fatal status bits: it is low for EMPTY_POSITION, which is communicated by the typed response. On EMPTY_POSITION, drain accepted work, invalidate the entire OUTPUT bank's frame-valid flag, and release no host logits. The core holds host completion with error=1, code=EMPTY_POSITION and the failing n until acceptance; then it returns to IDLE with parameters retained and no reset. Other failures follow the fatal reset policy. Hold all host completion fields and status stable under backpressure; successful completion has error=0/code=OK/position=0. The core may accept another frame only after host completion acceptance. The output-validity flag clears on new frame, reset or any frame failure and sets only after all N aggregation writes commit.

The core owns parameter validation, host packet counters and the five-stage order. The `bcjrformer_core` wrapper will instantiate the controllers, switches, primitives and memories; `core_ctrl` is its host-facing FSM, not a sixth mathematical stage.

## 5. Encoder subblocks and shared vector engines

| Module | Command payload input | Child command outputs (and response inputs) | Other ports | Stored result / returned value |
|---|---|---|---|---|
| `layer_ctrl` | `layer_cmd_t` | `norm: layernorm_cmd_t`; `attention: layer_cmd_t`; `residual: residual_cmd_t`; `ffn: ffn_cmd_t` | None | Complete layer in X |
| `attention_ctrl` | `layer_cmd_t` | `qkv: layer_cmd_t`; `score: row_cmd_t`; `softmax: softmax_cmd_t`; `weighted: row_cmd_t`; `out_project: layer_cmd_t` | `mem` reads MASK at query index | ATTN_OUT `[L,D]` |
| `qkv_ctrl` | `layer_cmd_t` | `linear: linear_cmd_t` | None | All Q, then all KEY, then all VALUE tokens |
| `score_row_ctrl` | `row_cmd_t` | `dot: dot_cmd_t` | `mem` writes SCORE; local wide scale/conversion | L scaled scores for one head/query |
| `softmax_ctrl` | `softmax_cmd_t` | None | `mem`, arithmetic `exponential`, `reciprocal` | PROB row of L values |
| `weighted_value_ctrl` | `row_cmd_t` | `dot: dot_cmd_t` | `mem` writes Z; local conversion | d components at `Z[query*D+head*d+r]` |
| `output_projection_ctrl` | `layer_cmd_t` | `linear: linear_cmd_t` | None | All ATTN_OUT tokens from Z |
| `ffn_ctrl` | `ffn_cmd_t` | `linear: linear_cmd_t` | `mem`, arithmetic `gelu` | D FFN outputs at command destination |
| `layernorm_ctrl` | `layernorm_cmd_t` | None | `mem`, arithmetic `rsqrt`; local wide statistics and affine datapath | `length` normalized destination values |
| `linear_ctrl` | `linear_cmd_t` | `dot: dot_cmd_t` | `mem` reads bias and writes destination; local conversion | `out_count` destination values |
| `residual_ctrl` | `residual_cmd_t` | None | `mem`; local signed17 addition/conversion | `length` destination sums |
| `dot_engine` | `dot_cmd_t` | None | `mem`, arithmetic `mac` | `command.rsp` is signed64 `accum_t`; no memory write |

Physical sharing is explicit: LN(F), LN(D), LN1 and LN2 all use **one** `layernorm_ctrl`. All linear boxes use **one** `linear_ctrl`. Both residual boxes use **one** `residual_ctrl`. Every projection, score dot and weighted-value dot uses **one** `dot_engine` and **one** `mac_unit`. Drawing multiple mathematical boxes does not create multiple physical units.

### Exact descriptor fields

All fields below are inputs on `command.cmd`, held stable until accepted and latched for the command duration. A pointer refers to an element of a logical bank; tensor dimensions/strides not present in a descriptor are compile-time constants.

| Descriptor type | Fields and widths | Contract |
|---|---|---|
| `layer_cmd_t` | `layer_index:16`, `layer_param_base:ADDR_W` | `0<=layer_index<K`; base selects that layer's manifest-defined parameter set |
| `layernorm_cmd_t` | `length:16`, `src:ptr_t`, `dst:ptr_t`, `gamma_base:ADDR_W`, `beta_base:ADDR_W` | Length F or D; contiguous input/output and affine parameters |
| `linear_cmd_t` | `in_count:16`, `out_count:16`, `src:ptr_t`, `dst:ptr_t`, `weight_base:ADDR_W`, `bias_base:ADDR_W` | Contiguous vector; weights `W[out,in]`; biases `b[out]`; parameter bases address PARAM |
| `residual_cmd_t` | `length:16`, `left:ptr_t`, `right:ptr_t`, `dst:ptr_t` | Contiguous signed16 vectors; baseline issues D-element commands |
| `row_cmd_t` | `head_index:16`, `query_index:16` | `head<H`, `query<L`; score/probability buffers start at address 0 |
| `softmax_cmd_t` | `padded_query:1` | Captured by attention from MASK[query]; 1 chooses uniform row |
| `ffn_cmd_t` | `src:ptr_t`, `dst:ptr_t`, `layer_param_base:ADDR_W` | D-element source/destination; W1/b1/W2/b2 offsets from layer manifest |
| `dot_cmd_t` | `length:16`, `a:ptr_t`, `a_stride:ADDR_W`, `b:ptr_t`, `b_stride:ADDR_W`, `mode:2`, `acc_init:signed64` | Term i reads `a.addr+i*a_stride` and `b.addr+i*b_stride`; bounds checked without address wrap |

For `ADDR_W=32`, descriptor widths are: layer 48, layernorm 154, linear 170, residual 127, row 32, softmax 1, FFN 106, dot 220 bits. These are bundles of scalar control wires, not feature-data widths. No descriptor is a host-configurable packet in this baseline.

Parameter tensor offsets must come from the same manifest as the host image. They are not assigned numeric values until dimensions are selected. One layer occupies `12*D*D+13*D` parameter words; the full baseline contains `2*F+D*F+3*D+N*D+M*D+K*(12*D*D+13*D)+D+1` words. A layer base alone does not identify tensor ordering: the manifest must define every relative gamma/beta/W/b offset.

### Concrete linear-to-dot example

For Q projection token t/output feature j, `linear_ctrl` emits:

```systemverilog
// Caller-side assignment intent, not a behavioral implementation.
dot.cmd.length   = D;
dot.cmd.a        = '{bank: BANK_U,     addr: t*D};
dot.cmd.a_stride = 1;
dot.cmd.b        = '{bank: BANK_PARAM, addr: WQ_BASE + j*D};
dot.cmd.b_stride = 1;
dot.cmd.mode     = DOT_S16_S16;
// First sign-extend the signed16 bias to signed64, THEN shift left 10.
dot.cmd.acc_init = $signed({{48{bias[15]}}, bias}) <<< 10;
```

The linear controller holds this command until `cmd_valid && cmd_ready`, waits for `rsp_valid && rsp_ready`, converts the signed48/F20 result, and writes Q[t*D+j]. Dot returns the wide sum; linear returns completion only after all D destination writes.

For a score, A is Q[query*D+head*d], B is KEY[key*D+head*d], both strides 1, length d, initial sum 0. Scale with constant `1/sqrt(d)` after dot completion.

For the second FFN linear, A is FFN_HIDDEN in signed32/F22, mode `DOT_S32_S16`; B remains signed16/F10 weights. Bias is sign-extended then shifted left22 into F32; the linear output conversion shifts right22 to F10 after all products accumulate.

For a weighted value, A is PROB[0], stride 1; B is VALUE[head*d+r], stride D; length L; initial sum 0; mode `DOT_U24_S16`. Convert signed64/F32 to signed16/F10 and store Z[query*D+head*d+r]. There is no bias or extra scale.

## 6. Exact memory interface

Each listed `mem` port is a `bcjr_mem_if.requester`. The fabric/memory sees the inverse directions.

| Signal | Direction at requester | Width | Meaning |
|---|---|---:|---|
| `mem.req_valid` | Output | 1 | Present one read/write request |
| `mem.req_ready` | Input | 1 | Fabric accepts request |
| `mem.req.write` | Output | 1 | 0 read, 1 write |
| `mem.req.bank` | Output | 5 | Logical bank ID |
| `mem.req.addr` | Output | `ADDR_W` | Element address within that bank |
| `mem.req.format` | Output | 3 | Expected native format; checked against bank |
| `mem.req.wdata` | Output | 96 | Write payload; unused high bits zero |
| `mem.rsp_valid` | Input | 1 | Read data or write acknowledgment available |
| `mem.rsp_ready` | Output | 1 | Requester accepts response |
| `mem.rsp_rdata` | Input | 96 | Read data, canonical sign/zero extension; zero for write response |
| `mem.rsp_error` | Input | 1 | Illegal bank/address/format/access; result unusable |

One response per accepted request, including writes. A successful write response means committed data. A failed write must not modify its destination. Read results are extracted from the low native-width bits and explicitly cast before arithmetic; a packed 96-bit bus is not implicitly signed. Writes of negative signed16 values have their two's-complement value in bits 15:0 and zeros above, whereas reading them sign-extends bit 15 through bit 95.

The conservative fabric has one transaction outstanding globally. It captures requester and destination on acceptance and keeps that routing through response acceptance. Request-ready remains low until then. Requests must not create a combinational ready/valid loop. Even register-backed banks return responses no earlier than the edge after acceptance, so controllers can use distinct ISSUE and WAIT states.

`parameter_mem.access` responds to BANK_PARAM only. `scratch_mem.access` responds to every other listed bank and decodes native width/depth internally. Both expose the responder directions of the same table. These are adapter boundaries; macro-specific enable/address/write-data signals belong inside their eventual implementation. The design review calls parameter storage ROM: to preserve host loading from the detailed specification, this draft uses writable parameter storage that becomes read-only during inference. A true fixed ROM build would remove the loader and change reset/image-valid behavior explicitly.

The packed request is 137 bits for ADDR_W=32. BANK_FFN_HIDDEN accepts native FMT_S32_F22 reads/writes and FMT_S16_F10 writes with exact signed promotion by <<12; F10 reads are rejected. Other banks retain their formats. Signed32 writes use low32 bits with zero unused high bits; reads sign-extend bit31.

### Banks, producer and consumer connections

All fixed banks start at element address zero. Parameter tensors are exceptions: their bases are manifest offsets within PARAM. This table defines logical capacity, not the SRAM macro count.

| ID / bank | Elements / native format | Writer | Reader |
|---|---|---|---|
| 0 PARAM | `PARAM_WORDS`, signed16/F10 | Core host loader while idle | Position, LayerNorm, linear bias reads, dot weight reads |
| 1 FEATURE | `L*F`, signed16/F10 | Core feature loader | Embedding copy loop |
| 2 MASK | `L`, bit | Core mask loader | Attention query flag; aggregation |
| 3 X | `L*D`, signed16/F10 | Embedding, position, residual | Position, LayerNorm, residual, final dot |
| 4 U | `L*D`, signed16/F10 | LayerNorm 1, then LayerNorm 2 after residual 1 | Q/K/V dot, then FFN dot |
| 5 Q | `L*D`, signed16/F10 | Q linear | Score dot |
| 6 KEY | `L*D`, signed16/F10 | K linear | Score dot |
| 7 VALUE | `L*D`, signed16/F10 | V linear | Weighted dot |
| 8 Z | `L*D`, signed16/F10 | Weighted controller | Output-projection dot |
| 9 ATTN_OUT | `L*D`, signed16/F10 | Output-projection linear | First residual |
| 10 TOKEN | `max(F,D)`, signed16/F10 | Embedding copy, input LayerNorm | LayerNorm, embedding dot |
| 11 FFN_HIDDEN | `4D`, signed32/F22 | First FFN linear, then in-place GELU write loop | GELU read loop, then second FFN linear's dot |
| 12 VECTOR | `max(D,4D)`, signed16/F10 | Embedding linear/LN; second FFN linear | Embedding copy/LN, second residual |
| 13 SCORE | `L`, signed48/F20 | Score controller | Softmax |
| 14 EXP | `L`, unsigned24/F22 | Softmax | Softmax |
| 15 PROB | `L`, unsigned24/F22 | Softmax | Weighted dot |
| 16 LOGIT | `L`, signed16/F10 | Final linear | Aggregation |
| 17 OUTPUT | `N`, signed16/F10 | Aggregation | Core output transfer |

Formats encode as `S16_F10=0`, `BIT=1`, `S48_F20=2`, `U24_F22=3`. All other bank/format combinations are errors. There is no static-mask bank or static-mask port in this selected no-static-mask draft.

Embedding sequence: FEATURE -> TOKEN; normalize TOKEN in place; linear TOKEN -> VECTOR; normalize VECTOR in place; copy VECTOR -> X. LayerNorm completes both statistics passes before overwriting any source value.

Layer sequence: normalize X -> U for all tokens; attention -> ATTN_OUT; residual X+ATTN_OUT -> X for all tokens. Then normalize all X(R) tokens -> reused U. Per token, FFN U -> VECTOR, residual saved X+VECTOR -> X. In FFN, first linear writes all FFN_HIDDEN[0:4D]; GELU reads each value before replacing it in place; second linear reads FFN_HIDDEN and writes VECTOR[0:D]. The first-linear input and second-linear hidden vector survive all outputs that need them. U's LN1 values are no longer live when LN2 begins.

Scalar sums, mean, centered differences, variance and reciprocal registers remain local. They are not squeezed through the 96-bit memory port. LN's unsigned136 variance scaling intermediate is an internal datapath value, for example.

## 7. Arithmetic-unit ports

`bcjr_arith_if` uses the following wires. Directions are relative to the **arithmetic unit** (`operation` port); the requesting controller has the inverse directions.

| Signal | Direction at unit | Width |
|---|---|---:|
| `operation.req_valid` | Input | 1 |
| `operation.req_ready` | Output | 1 |
| `operation.req` | Input | As below |
| `operation.req_tag` | Input | 8 |
| `operation.rsp_valid` | Output | 1 |
| `operation.rsp_ready` | Input | 1 |
| `operation.rsp` | Output | As below |
| `operation.rsp_tag` | Output | 8 |
| `operation.rsp_error` | Output | 1 |
| `operation.rsp_status` | Output | 4 |

The tag is echoed unchanged and can be zero for a dedicated caller; it does not authorize multiple outstanding requests or replace routing ownership. `rsp_error` equals the OR of fatal status bits. Responses are held until accepted, with variable latency and the same reset/error rules as command channels. These units have no memory ports.

| Unit / caller port | Request type and fields | Result type | Connection / interpretation |
|---|---|---|---|
| `mac_unit` / `dot_engine.mac` | `mac_req_t`: `mode:2`, `a:32`, `b:signed16`, `acc:signed64` (114 bits total) | `accum_t`, signed64 | `acc + a*b`; mode determines A signedness and accumulator fraction/range |
| `exp_unit` / `softmax_ctrl.exponential` | `score_t`, signed48/F20 | `probability_t`, unsigned24/F22 | Difference <=0; exp(0)=1; below -16 returns 0 |
| `reciprocal_unit` / softmax and aggregation `reciprocal` | `denominator_t`, unsigned64/F22 | `reciprocal_t`, unsigned40/F32 | Positive denominator in [1,65535] |
| `rsqrt_unit` / `layernorm_ctrl.rsqrt` | `variance_t`, unsigned48/F32 | `rsqrt_t`, unsigned32/F20 | Variance + epsilon, in [quantized epsilon,4096] |
| `gelu_unit` / `ffn_ctrl.gelu` | `act_t`, signed16/F10 | `gelu_t`, signed32/F22 | Taylor k=0..57 on [-6,6], analytically bounded tails; total function error <10^-5, stored without precision loss in the F22 hidden bank |

In MAC mode 0, sign-interpret `a[15:0]` and require `a[23:16]==0`; multiply signed16 by signed16 and check signed48 accumulator range. In mode 1, A is unsigned24, zero-extend it before signed multiplication with B, and check signed64 accumulator range. Do not accidentally treat probability bit 23 as a sign bit. The physical result is always signed64.

Aggregation converts count C to the reciprocal input by zero-extending to 64 bits **before** shifting left 22. Softmax already has a 64-bit/F22 sum. LN includes nonzero epsilon before issuing rsqrt. The score difference subtraction uses signed49/F20 and checks the -16 cutoff before narrowing to the exp input.

Local scalar datapaths implement position/residual adds, score scaling, softmax normalization, aggregation scaling, and LN statistics/affine operations with the widths and conversion points in `RTL-specification.md`. They do not have extra inter-module ports in this draft. Their controls are internal FSM/register enables. If later extracted into a shared scalar unit, its operand/result contract needs a separate definition; the dot MAC interface does not support those wider operations unchanged.

## 8. Wiring and shared-resource routing

The control edges are unambiguous:

| Requesting block.port | Receiving block.port | Command/request type | Result type |
|---|---|---|---|
| `core_ctrl.embed` | `embedding_ctrl.command` | `empty_t` | `empty_t` |
| `core_ctrl.position` | `position_ctrl.command` | `empty_t` | `empty_t` |
| `core_ctrl.encoder` | `encoder_ctrl.command` | `empty_t` | `empty_t` |
| `core_ctrl.final_project` | `final_ctrl.command` | `empty_t` | `empty_t` |
| `core_ctrl.aggregate` | `aggregation_ctrl.command` | `empty_t` | `aggregation_rsp_t` |
| `encoder_ctrl.layer` | `layer_ctrl.command` | `layer_cmd_t` | `empty_t` |
| `layer_ctrl.attention` | `attention_ctrl.command` | `layer_cmd_t` | `empty_t` |
| `layer_ctrl.ffn` | `ffn_ctrl.command` | `ffn_cmd_t` | `empty_t` |
| `layer_ctrl.residual` | `residual_ctrl.command` | `residual_cmd_t` | `empty_t` |
| `attention_ctrl.qkv` | `qkv_ctrl.command` | `layer_cmd_t` | `empty_t` |
| `attention_ctrl.score` | `score_row_ctrl.command` | `row_cmd_t` | `empty_t` |
| `attention_ctrl.softmax` | `softmax_ctrl.command` | `softmax_cmd_t` | `empty_t` |
| `attention_ctrl.weighted` | `weighted_value_ctrl.command` | `row_cmd_t` | `empty_t` |
| `attention_ctrl.out_project` | `output_projection_ctrl.command` | `layer_cmd_t` | `empty_t` |
| Embedding and layer `.norm` (2 callers) | LN command switch -> `layernorm_ctrl.command` | `layernorm_cmd_t` | `empty_t` |
| Embedding, QKV, output projection, FFN, final `.linear` (5 callers) | Linear command switch -> `linear_ctrl.command` | `linear_cmd_t` | `empty_t` |
| Linear, score, weighted `.dot` (3 callers) | Dot command switch -> `dot_engine.command` | `dot_cmd_t` | `accum_t` |
| Softmax and aggregation `.reciprocal` (2 callers) | Arithmetic switch -> `reciprocal_unit.operation` | `denominator_t` | `reciprocal_t` |
| Dot `.mac`, softmax `.exponential`, LN `.rsqrt`, FFN `.gelu` | Corresponding unit `.operation` | Section 7 | Section 7 |

`command_switch` and `arithmetic_switch` each have `clients[CLIENTS]` ports in callee/responder direction and one `service` port in caller/requester direction. Instantiate command switches with 2, 5, and 3 clients and the arithmetic switch with 2. All interface instances on each switch must have identical payload types. Record the granted client on command acceptance; route only that client's response until accepted. Nonselected clients see ready=0 and response-valid=0. Use lowest client index for deterministic arbitration if several request simultaneously; the intended schedule normally permits only one.

The 13 memory clients, in proposed client-index order, are core, embedding, position, attention, LayerNorm, linear, score, softmax, weighted, FFN, residual, aggregation, dot. `memory_fabric.clients[0:12]` uses responder directions and `parameters`/`scratch` use requester directions. PARAM requests go to `parameter_mem.access`; all other valid banks go to `scratch_mem.access`. Invalid bank IDs return error without reaching a bank. Fabric errors become the requester's protocol-error status.

Resource ownership is hierarchical. A parent waits while its child uses memory/arithmetic; it does **not** lock the memory fabric across its whole command. Memory ownership lasts for one request/response transaction. Otherwise linear waiting for dot would block dot's own reads. A linear service grant can remain active while dot and memory independently grant the nested operations. All accepted responses must still be consumed while propagating an error.

Parameter writes reach memory only through the validated idle-time core loader; compute controllers issue parameter reads only. MASK is immutable during compute. Core output reads begin only after aggregation completion. Reset clears switch grants and pending response routing together with the endpoints.

### Example interface instantiation

```systemverilog
import bcjrformer_contract_pkg::*;
bcjr_cmd_if #(.CMD_T(linear_cmd_t), .RSP_T(empty_t)) linear_link();
bcjr_cmd_if #(.CMD_T(dot_cmd_t), .RSP_T(accum_t)) dot_link();
bcjr_arith_if #(.REQ_T(denominator_t), .RSP_T(reciprocal_t)) recip_link();
bcjr_mem_if mem_link();
// The future top wrapper connects caller/callee modports to these instances.
```

Compile order for the interface definitions is package, channels, then any consumers. The `.svh` contains SystemVerilog `extern module` prototypes for review; it is not a simulation top or a file list of implemented modules. Interface/modport support and external-prototype handling must be checked with the selected RTL toolchain. If it requires flattened ports, the tables and modports specify the exact expansion.

## 9. Boundary behavior that the ports must preserve

1. Stage command acceptance does not imply data readiness. Completion after the final write acknowledgment releases the next stage.
2. All Q/K/V exist before score evaluation. All heads/queries in Z exist before output projection. All ATTN_OUT exists before first residual overwrites X.
3. Attention reads one padding bit for the query, then passes `padded_query`. Padded query -> L copies of rounded `1/L`; normal query -> softmax over **all** keys, including padded keys. No key-mask signal is introduced.
4. Head split/join are addresses only. There are no split-head or concatenate data-copy modules.
5. For every n, including M=1, sum and count the same unmasked contributors. Compute reciprocal per position when C_n>0. C_n=0 is recoverable EMPTY_POSITION, not numeric_error; discard the whole frame and return to idle after host error acceptance. This intentionally differs from current Python aggregation.
6. Output validity and stage completion are held levels with acknowledgment, not one-cycle done pulses. No standalone internal busy wires are needed for sequencing.
7. Simulation numerical observations should bind to existing conversion/commit events with saved context; this interface draft introduces no trace RAM, debug host pins, or computation backpressure for logging. The detailed trace contract remains in `RTL-specification.md`.

## 10. Review decisions and verification boundary

New concrete choices in this draft are the signal names, typed interface bundles, bank/format encodings, 32-bit common element addresses, fixed-bank stage commands, four status bits, arithmetic tag width, explicit parameter-write acknowledgments, and switches with retained requester identity. These fill omissions in the architecture; they are proposals for interface review.

The design review says parameter ROM while the detailed architecture supports host reload; section 6 chooses the reloadable implementation. The older compact FFN paragraph interleaves first-linear/GELU work; this draft follows the design review and canonical v5 schedule: complete linear 1, apply GELU over its stored results, then linear 2. Static masking is excluded as in the design review; a checkpoint requiring it needs an explicit interface extension.

Before behavioral RTL is frozen, select dimensions/checkpoint/parameter offsets, validate the numeric formats and nonlinear units, and budget physical memory. Interface review can proceed now without those numerical choices being falsely presented as final.

This deliverable was checked for block/port coverage, descriptor widths, and interface direction consistency. No SystemVerilog compiler was found on the current PATH; syntax/elaboration, handshake simulation, synthesis, and numerical accuracy have not been verified. The next implementation should test stable stalled payloads, exactly one response per request, write-completion ordering, reset during waits, nested shared-resource access, invalid descriptors, and both aggregation branches.
