# Stages 3–5: architecture draft for our review

> Current review entry point (10 October 2026): ARCHITECTURE-CHECKPOINT-1.md. Working stage and interface contracts take precedence over older generated publication snapshots. Numerical verification is pending Haiel; this checkpoint awaits Taimor's approval.

Together with Stages 1 and 2 in `RTL-specification.md`, this defines the working design for all five stages. It is not RTL, numerical sign-off or supervisor approval. All diagrams are in `BCJRFormer_all_stages.drawio`, with separate stage files too. Memory banks are described here; diagrams show memory access only.

Source: local `BCJRFormer/bcjrformer/models/bcjrformer.py` and `models/modules.py`. Dropout is disabled in inference. Nonlinear methods remain black boxes until reviewed before RTL.

## Definitions and shared rules

B=1 means one frame at a time. M is read slots, N positions/read, L=M*N tokens, D features/token, K encoder layers, H attention heads and d=D/H features/head. A token is one position of one read. Require positive dimensions and D divisible by H. Assign actual numbers after architecture review.

Ready/valid acceptance means both signals high on a clock edge. Hold commands, addresses, operands and results unchanged during stalls. Advance indices only after the associated calculation and confirmed write. Parent controllers wait for child completion, then select the next exclusive owner of shared arithmetic/memory. No concurrent ownership is implied by multiple diagram boxes.

### Reused blocks

| Block | Internal operations | Write ownership |
|---|---|---|
| Normalization | Sum, mean, subtract, square, variance, RSQRT, scale, gamma/beta, conversion | Norm controller |
| Linear | Bias read, output loop, dot request, conversion | Linear controller |
| Dot product | Two operand reads, multiply, add, accumulator | None; returns wide sum |
| Addition | Registers, exact alignment, widened add, conversion | Caller |
| Scalar | Add/subtract or full multiply, conversion | Caller |

Scalar FSM: `IDLE -> ALIGN/PREPARE -> ISSUE_OP -> WAIT_OP -> CONVERT -> DONE`. Sign-extend signed operands and zero-extend unsigned operands. Preserve full products and exact alignment before conversion. A descriptor selects operation and input/output formats. This unit has no memory writes or index loop.

Memory transaction FSM: `IDLE -> REQUEST -> WAIT_RESPONSE -> DONE`. Latch address/data/read-write selection; hold REQUEST until accepted; capture one response; hold DONE until the caller accepts it. Only one transaction is outstanding. Write completion means confirmed commitment, not request acceptance. A diagram's Read/Write state runs this full sequence; Run issues a child command and waits for its result. There is no assumed timeout.

No caller may hold the memory port while waiting for a child that needs it. The arbiter routes responses to the active owner and changes ownership only after outstanding work finishes. Reset clears all pending interfaces.

### Number conversion and black boxes

QACT means round to nearest, ties to even, then clip to the signed activation range. Keep rounded-changed and saturated flags separate; neither alone fails a frame. QScore/QEXP/QPROB convert to their distinct formats. Statistics and accumulators must be wide enough for declared ranges: overflow is fatal, not silent wrap or clipping. Do not implicitly interchange ACT, SCORE, EXP, PROB, SUM or RECIP formats.

The Stage 2 conversion diagram uses shifts, guard/sticky bits, OR/AND, an increment adder and limit comparisons/selectors. Conversion is controlled by its owning arithmetic controller; it does not require its own independent FSM.

| Black box | Domain | Mathematical target | Caller |
|---|---|---|---|
| RSQRT | Positive variance+epsilon | 1/sqrt(x) | Normalization |
| EXP | x<=0 | exp(x) | Softmax |
| RECIP | x>0 | 1/x | Softmax, Stage 5 |
| GELU | Signed activation | x*Phi(x), Phi(x)=0.5*(1+erf(x/sqrt(2))) | FFN |

Each wrapper has `IDLE -> CHECK_DOMAIN -> START_METHOD -> WAIT_METHOD -> CHECK_RESULT -> DONE`. This is an interface FSM, not the internal arithmetic design. Algorithms, coefficient storage, ranges, widths, latencies and error bounds remain open. Taylor/piecewise methods are candidates, not chosen implementations. No placeholder arithmetic should be reported as completed RTL.

## Stage 3: encoder layers

### Input, output and layer math

Input X^(0)[L,D], unchanged padding mask[M,N], and learned parameters for each of K layers. Output X^(K)[L,D]. Superscripts select layer boundaries, not powers.

For each layer k:

1. U = LN1_k(X).
2. O = Attention_k(U).
3. R = QACT(X + O).
4. Vnorm = LN2_k(R).
5. Fout = FFN_k(Vnorm).
6. X = QACT(R + Fout).

One physical layer runs K times with different parameters. LN1/LN2 reuse normalization; the two residuals reuse addition. This is pre-normalization: norm comes before attention/FFN, not after their residuals.

Stage FSM: `IDLE -> INIT_LAYER -> RUN_LAYER -> NEXT_LAYER -> DONE`. Set k=0, run one whole layer, increment only after completion. DONE holds completion after K layers; only then may Stage 4 start.

Layer schedule: LN1 for all tokens; attention for the frame; residual 1 for all tokens; LN2 for all tokens; for each token FFN then residual 2; finish. Reset token t=0 before each sweep. This keeps shared arithmetic exclusive and preserves original residual inputs.

### Memory banks and lifetimes

| Bank | Capacity | Contents and lifetime |
|---|---|---|
| X | L*D ACT | Original layer input through attention, then R through FFN, then next-layer output |
| U | L*D ACT | LN1 output through projections; reused later for LN2 output Vnorm |
| Q/K/V | 3*L*D ACT | Calculated projections; retain through all heads/queries |
| Scores | L SCORE | One head/query row through exponential creation |
| Exponentials | L EXP | One row through probability creation |
| Probabilities | L PROB | One row through all d weighted dots |
| Z | L*D ACT | Joined heads through output projection |
| O | L*D ACT | Attention output through residual 1 |
| Hidden scratch | 4D ACT | One token's linear-1 results, then GELU results in place |
| FFN output scratch | D ACT | One token's linear-2 results through residual 2 |
| Mask | L bits | Attention reads; unchanged for Stage 5 |
| Parameter memory (read-only during compute) | Per-layer parameters/constants | Read only; selected by k |

Logical banks are not confirmed physical SRAM macros. Stage 1 scratch can be reused after Stage 1 finishes if sized adequately. Do not alias simultaneously live banks. X is overwritten only after both operands of its element's residual are captured. U becomes LN2 scratch only after attention no longer needs LN1 data.

Per-layer parameter count is 12D²+13D: two norms 4D; Q/K/V/output projection 4D²+4D; FFN 8D²+5D. Constants and format metadata are extra. This is a capacity formula, not a chosen configuration.

### Normalization

For one D-element token x:

`mean = sum(x)/D`

`variance = sum((x-mean)^2)/D`

`scale = RSQRT(variance+epsilon)`

`out[j] = QACT(gamma[j]*QNORM((x[j]-mean)*scale)+beta[j])`.

Use the Stage 1 engine and conversion locations, with different LN1/LN2 gamma/beta. Variance divides by D, not D-1. Epsilon follows the selected Python LayerNorm configuration (default 1e-5); reject constants that become zero or invalid after quantization. The norm controller owns token writes; the layer controller owns the token loop.

### Q, K and V projections

These are calculated activation arrays, not learned weights. For A=Q,K,V:

`A[t,j] = QACT(bA[j] + sum_f U[t,f]*WA[j,f])`.

FSM: `IDLE -> SELECT_Q/INIT_TOKEN -> RUN_LINEAR -> NEXT_TOKEN -> NEXT_PROJECTION -> DONE`. Run every Q token, then every K token, then every V token with distinct weights/biases and destinations. D→D linear owns D writes; the parent must not duplicate them. No mask, GELU or softmax here.

Addresses: Ubase+tD+f; WAbase+jD+f; Abase+tD+j. Parameters are stored output-row first. Hardware uses base/stride descriptors and pointer increments, not runtime address multipliers.

### Score row and mask

For head h, query i, key j:

`score[j] = QScore((sum_r Q[i,h*d+r]*K[j,h*d+r]) * c)`, r<d, c=stored 1/sqrt(d).

FSM: `IDLE -> INIT_KEY -> RUN_DOT -> RUN_SCALE -> WRITE_SCORE -> NEXT_KEY -> DONE`. Dot initial sum zero, length d, both strides 1. Keep its wide result until scalar scaling; do not insert ACT narrowing before scaling. Keys j loop across L; h/i stay fixed. Q/K slice bases are Qbase+iD+hd and Kbase+jD+hd. Head splitting is address selection, not copying.

The inspected Python mask[B,1,L,1] masks QUERY rows, not key columns. For the no-static-mask baseline, a padded query gets uniform probabilities 1/L. Valid queries retain all keys, including padded keys. This avoids quantizing the finite -1e9 sentinel; the uniform algebra matches the fully filled float row, subject to probability quantization.

The source supports an optional static L×L mask. This draft does not implement it: confirm it is absent for the chosen checkpoint/configuration before RTL freeze. Reject such a configuration rather than silently ignoring its mask. Static-mask support needs a reviewed storage/sentinel/error policy. Key masking is a different algorithm and is not silently substituted.

### Softmax row

`vmax = max_j score[j]`

`b[j] = QEXP(EXP(score[j]-vmax))`

`T = sum_j b[j]`

`p[j] = QPROB(b[j]*RECIP(T))`.

Arithmetic: compare/select maximum; subtract; EXP black box; sum adder; RECIP black box; multiply; convert/write. Initialize maximum from the first score, not zero. Save exponentials while adding them to a widened positive sum. EXP(0) must remain positive; T<=0 is fatal.

FSM: `IDLE -> CHECK_QUERY_MASK -> FIND_MAX -> EXP_STORE_SUM -> RUN_RECIP -> INIT_PROB_INDEX -> PREPARE_VALUE -> WRITE_PROB -> NEXT_ENTRY -> DONE`.

Masked query jumps from CHECK_QUERY_MASK to INIT_PROB_INDEX in uniform mode. PREPARE_VALUE then selects stored 1/L instead of saved-exp×reciprocal. One probability-write path serves both modes. Each scan includes memory/arithmetic waits and exact index updates. All L writes finish before weighted values start. No forced final-entry correction to make the quantized row sum exactly one is included.

### Weighted values and attention output

`Z[i,h*d+r] = QACT(sum_j p[j]*V[j,h*d+r])`.

FSM: `IDLE -> INIT_FEATURE -> RUN_DOT -> CONVERT_ACT -> WRITE_Z -> NEXT_FEATURE -> DONE`. Dot length L, initial sum zero; probability stride 1, V stride D. No bias or extra scale. Probability is unsigned, V signed; use appropriate extension and a wide signed sum. Preserve the probability row until all d output features finish.

Attention parent: `IDLE -> RUN_QKV -> INIT_HEAD_QUERY -> RUN_SCORE -> RUN_SOFTMAX -> RUN_WEIGHTED -> NEXT_QUERY_HEAD -> RUN_OUTPUT_PROJECTION -> DONE`. Increment query i within head h; then reset i and advance h. After all heads, project every token:

`O[t,j] = QACT(bO[j] + sum_f Z[t,f]*WO[j,f])`.

Reuse D→D linear/token-loop controller. Z already joins heads by feature address; no concatenation copy. All O writes precede residual 1.

### Residual additions

First: R[t,j]=QACT(X[t,j]+O[t,j]), written into X. Second: next X[t,j]=QACT(R[t,j]+Fout[t,j]), also written into X.

FSM per D-element token: `IDLE -> INIT_FEATURE -> READ_LEFT -> READ_RIGHT -> RUN_ADD -> WRITE_RESULT -> NEXT_FEATURE -> DONE`. Read both operands before replacing the left. Reuse Stage 2 ACT+ACT addition. The layer owns the token loop; no norm/dot inside this box.

### FFN

`A[j] = QACT(b1[j] + sum_f W1[j,f]*Vnorm[t,f])`, j<4D.

`G[j] = QACT(GELU(A[j]))`.

`Fout[r] = QACT(b2[r] + sum_j W2[r,j]*G[j])`, r<D.

Source nn.GELU() targets x*Phi(x), not an assumed tanh approximation. Its hardware method/error remains open. No inference dropout.

FSM: `IDLE -> RUN_LINEAR1 -> INIT_HIDDEN_INDEX -> READ_A -> RUN_GELU -> WRITE_G -> NEXT_HIDDEN -> RUN_LINEAR2 -> DONE`. Store all 4D first-linear results; read each A before replacing it with G. Only after all G writes does 4D→D linear start, into separate D scratch. Linear controllers own their writes; GELU caller owns G writes. R remains outside FFN scratch. The layer runs residual 2 after FFN token completion.

### Stage 3 control and errors

One dot descriptor at a time selects U×W, Q×K or probability×V. Shared-resource ownership is exclusive throughout waits. Parameter bases depend on k; head/query/feature/index state stays fixed until associated writes complete. Simulation snapshots record context, wide/stored values and flags once at existing conversion/commit events; no extra debug state or on-chip storage is implied.

Fatal memory/protocol/overflow/domain errors stop new work, drain accepted work, invalidate partial X and report failed completion, then require reset. Stage 4 must not start. Rounded/saturated flags accumulate without independently failing a frame.

## Stage 4: final projection

Input X^(K)[L,D], final learned W[D] and bias[1]. Output z[M,N], stored as L ACT numbers. Positive favors bit 1, negative bit 0; no sigmoid, probability percentage or hard decision is calculated.

`z[m,n] = QACT(bfinal + sum_j X^(K)[m*N+n,j]*Wfinal[j])`.

Reuse linear with input length D, output length 1. Initialize the dot from aligned bias, sum D products, convert once, commit one logit. The parent does not repeat that write.

| Storage | Capacity / use |
|---|---|
| X | L*D ACT, read only |
| Final parameter memory (read-only during compute) | D+1 values, read only |
| Read-logit bank | L ACT, written then retained for Stage 5 |
| Mask | L bits, unchanged and not read here |
| Controller registers | t, source/destination pointers, status |

FSM: `IDLE -> INIT_TOKEN -> RUN_LINEAR -> NEXT_TOKEN -> DONE`. Source pointer advances D words, destination one; parameter bases stay fixed. Process padded tokens too. After all L writes, hold completion so Stage 5 can start. Fatal failure blocks Stage 5. Only integer add/compare/select address logic is new; linear/dot internals are reused.

## Stage 5: read aggregation

### Input, output and corrected math

Input z[M,N] and mask[M,N]; true mask means padded/unusable. Output N ACT logits, written first into a private buffer.

`valid[m,n] = NOT mask[m,n]`

`S_n = sum_m valid[m,n]*z[m,n]`

`C_n = sum_m valid[m,n]`

`logit[n] = QACT(S_n*RECIP(C_n))`, only when C_n>0.

Hardware selects add-or-skip, without a valid×z multiplier. The SAME valid bit enables sum and count. Partially padded reads count at their valid positions. Compute count/reciprocal per position, not per frame. M=1 uses the same mask-aware rule.

This follows the corrected design-review document. Current Python source still counts wholly unpadded reads and bypasses aggregation/mask for M=1. The golden/reference aggregation must use the corrected contract; do not claim source equivalence for these differing cases. Haiel needs this rule for verification outputs.

### Memory and arithmetic

| Storage | Capacity / use |
|---|---|
| Read logits | M*N ACT, contributing values read |
| Mask | M*N bits, each visited bit read |
| Sum register | Signed widened S_n, cleared each position |
| Count register | Exact integer 0..M, cleared each position |
| Reciprocal register | RECIP value, held through scale |
| Output buffer | N ACT, private until all positions succeed |
| Status | Frame-valid, first failing n, flags |

Count width=max(1,ceil(log2(M+1))); sum width at least ACT_W+ceil(log2(M)), at ACT fractional precision. Scale retains full signed-sum×unsigned-reciprocal product before ACT conversion. Convert C_n to reciprocal input format exactly: no count rounding or overflow. Reciprocal approximation/representation error remains part of the model.

Addresses: maskbase+mN+n and zbase+mN+n. Start at selected n, add N as m advances. Next position advances n by one and resets read pointers. Output is outbase+n. No runtime address modulo/divide.

### Stage FSM

`IDLE -> INIT_POSITION -> CLEAR_SUM_COUNT -> READ_MASK -> PROCESS_VALID -> NEXT_READ -> CHECK_COUNT -> RUN_RECIP -> RUN_SCALE -> WRITE_BUFFER -> NEXT_POSITION -> MARK_VALID -> DONE`.

For padding, PROCESS_VALID skips logit access/sum/count. Otherwise read z, widen-add and increment count once. NEXT_READ scans M reads. CHECK_COUNT selects reciprocal or empty-position recovery. WRITE_BUFFER includes commitment wait. NEXT_POSITION clears sum/count for the next n. MARK_VALID enables readout only after all N writes.

Stage controller owns indices, sum/count and memory. RECIP/scalar have their own command/result controllers. There is no external output-valid while aggregation is unfinished.

### Zero-count recovery

If any C_n=0, stop this frame, drain accepted work, invalidate the WHOLE output buffer, including earlier positions. Clearing the validity flag is enough; no memory erasure. Hold `EMPTY_POSITION` and first failing n until error acceptance. Emit no logits, replacement zeros or partial frame. Return to IDLE after acceptance, without hard reset. Never send zero to RECIP.

Other hardware/protocol/temporary-overflow/invalid-primitive errors use fatal stop/drain/report/reset. ACT saturation is nonfatal.

### Output transfer

Owned by the frame controller after successful Stage 5 completion: `IDLE -> CHECK_VALID/INIT_INDEX -> READ_LOGIT -> HOLD_OUTPUT -> NEXT_POSITION -> REPORT_FRAME_COMPLETION -> DONE`.

Hold value/index/last while receiver-ready is low. Advance only on output-valid AND output-ready. Last is n=N-1. Successful frame completion follows the last accepted logit and remains held until accepted. A new frame cannot replace the output bank during readout/completion.

## End-to-end review and remaining decisions

All stages now have working interfaces, operations, memory/lifetimes, control paths and FSMs. This is ready for our review, not numerical/RTL sign-off.

Before RTL: review schedules and bank ports/capacity; confirm no static mask; match checkpoint/config/export layout; open RSQRT/EXP/RECIP/GELU and choose methods/ranges/error limits; assign widths/constants/dimensions; finalize memory implementation and reset rules. Verification follows architecture review: compare float to bit-accurate behavior, then require RTL to match the bit-accurate model exactly.

Later tests: dimensions of one and larger; distinct layer parameters; head/value strides; residual preservation; uniform padded queries; unsigned probability products; zero variance; exp sums; rounding ties/saturation; partial padding and empty positions; stalls on memory/children/output; failure drainage; reset while waiting; no duplicate requests/writes/results.

LaTeX and interactive HTML are not silently regenerated here. Update them after our review so unresolved draft details are not presented as approved design.
