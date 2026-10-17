# Checkpoint 1: consolidated architecture for Taimor's review

Prepared 10 October 2026. Status: approved by Taimor's instruction to continue to the next part. The next structural review is `RTL-ARCHITECTURE.md`; model/numerical/technology decisions remain deferred.
The initial architecture is recorded as approved by Amit; his detailed corrections remain pending. This checkpoint does not claim those corrections have been received.
Numerical verification is pending Haiel's results. No computational RTL, numerical validation, synthesis or physical feasibility is claimed here.

## Review the execution flow

`Host parameter load/commit -> frame acceptance -> feature load -> mask load -> Stage 1 -> Stage 2 -> Stage 3 -> Stage 4 -> Stage 5 -> host output -> completion`

All five stages complete their memory writes before the next stage starts. One frame runs at a time (B=1). Model dimensions are compile-time: L=M*N, d=D/H, FF=4D, D divisible by H. They remain symbolic until the model is selected.

| Stage | Approved-phase proposal | Result / boundary |
|---|---|---|
| 1: embedding | For each token, LN over F, F-to-D linear, LN over D; copy into X | X[L,D]; token/vector scratch can be reused afterward |
| 2: learned additions | X[m,n,j] + P[n,j] + E[m,j], using widened arithmetic and explicit conversion | Updated X; every token processed, mask unchanged |
| 3: encoder | Reuse one layer K times, with distinct learned parameters | X contains final encoder tokens |
| 4: final projection | D-to-1 biased linear for each token; no sigmoid or hard decision | LOGIT[M,N] |
| 5: aggregation | Average unmasked contributors separately for every position n | Private OUTPUT[N]; released only after every position succeeds |

### Encoder schedule

`LN1 all tokens -> attention -> residual 1 all tokens -> LN2 all tokens -> for each token: FFN then residual 2`

LN1 writes U. Attention reads U and calculates all Q, then all K, then all V. For each head/query, calculate one score row, softmax, and d weighted-value components into Z. After all heads/queries, project Z into ATTN_OUT. Residual 1 reads X and ATTN_OUT before overwriting X with R. LN2 then reuses U for all normalized R tokens. Each FFN reads its U token, completes D-to-4D linear, GELU over the stored hidden vector, then 4D-to-D linear into separate scratch. Residual 2 reads R and that result before overwriting X.

This selects the schedule already drawn in Stage3_layer_fsm.svg. It replaces the older compact interleaved LN2/FFN schedule.

### Masking and corrected aggregation

Mask bit 1 means padded. Attention follows the inspected query-row mask: padded query -> uniform probability row; valid query -> all keys, including padded keys. Do not silently change to key masking. Baseline excludes static L-by-L masks; confirm the selected configuration supports this before freezing the model.

For every n, including M=1:

`S_n = sum of z[m,n] where mask[m,n]=0`

`C_n = number of those same contributors`

`output[n] = convert(S_n * reciprocal(C_n))`, only if C_n>0.

Example: with two reads z[:,n]=[2,6], both valid gives 4; first valid/second padded gives 2; both padded gives EMPTY_POSITION. A partially padded read participates at its valid positions. With M=1, a valid position returns its logit; a padded position fails the frame.

If C_n=0, never request reciprocal. Drain accepted work, invalidate the entire output frame, emit no logits, and hold EMPTY_POSITION plus the first failing n until the host accepts it. Then return to idle, retaining parameters, without reset. Fatal protocol/memory/overflow/domain errors drain/report and require reset. Rounding and activation saturation remain nonfatal observations.

This intentionally differs from current Python aggregation. Haiel's reference must implement this contract before hardware comparison. No Python change or numerical result is included in this phase.

## Resource and memory contract

One shared sequential dot/MAC engine, one shared linear service, one shared LayerNorm service, and one reused encoder layer. Controllers access shared services through retained-owner command switches. A parent must not hold the memory fabric while waiting for a child that needs memory. Memory ownership lasts for one accepted request through its response. One operation is outstanding per service; payloads remain stable under stalls.

Logical storage includes FEATURE LF, MASK L bits, X/U/Q/KEY/VALUE/Z/ATTN_OUT each LD, token max(F,D), FFN hidden 4D, vector scratch max(D,4D), SCORE/EXP/PROB each L, LOGIT L, and OUTPUT N. Parameter words:

`2F + DF + 3D + ND + MD + K*(12D^2 + 13D) + D + 1`.

Sum capacities using each bank's eventual width. Logical banks are not a confirmed SRAM macro mapping. Keep simultaneously live banks separate. U reuse is explicitly allowed after attention/residual 1; linear source/destination aliasing is prohibited while future outputs need the source. Output frame-valid clears at frame acceptance/reset/failure and sets only after all aggregation writes commit.

Parameter storage is host-loadable while idle and read-only during computation. A complete, ordered image must receive successful write acknowledgments before commit. Reset invalidates the image. Reloading starts by invalidating the old image. This selects the existing loader contract over literal fixed-ROM wording.

Scalar add/subtract/multiply and conversion remain local to their owning controllers in the current interface scaffold. Shared-scalar diagrams describe reusable arithmetic behavior, not a connected global service. A future physical sharing proposal needs explicit ports, operand widths and arbitration; no global scalar implementation is frozen here. Wide LayerNorm statistics cannot be sent through the dot MAC unchanged.

## Changes made in this phase

| Inconsistency | Consolidated result |
|---|---|
| Interface still used whole-read count and M=1 mask bypass | Per-position sum/count for all M |
| Empty-position recovery had no response payload or host index | Added proposed aggregation_rsp_t and host completion_code/completion_position |
| All failures appeared to require reset | EMPTY_POSITION is recoverable; fatal faults retain reset requirement |
| Compact encoder schedule differed from current diagram | All-token LN2 sweep into reused U before FFN/residual2 loop |
| U table named only LN1 producer/QKV consumer | Added LN2 producer and FFN consumer |
| FFN schedules and bank tables differed | Complete first linear into FFN_HIDDEN, apply GELU in place, then second linear into VECTOR |
| Parameter write acknowledgment omitted from compact top-level list | Added explicit host write acknowledgment |
| ROM wording conflicted with loader | Read-only during compute, reloadable while idle |
| Older publication appeared current | Working-source precedence and historical publication notices added |

The SV additions are declaration-only. Aggregation command rsp_error stays reserved for fatal status; EMPTY_POSITION travels in its typed response, then becomes host completion_error=1 with a distinct completion_code. Completion fields remain stable while stalled. No service switch is needed for this dedicated aggregation link.

## What is ready, and what remains open

Ready for architecture review: stage ordering, logical buffers/lifetimes, resource ownership, host framing, source-compatible attention masking, corrected aggregation, and recoverable/fatal error separation.

Pending next phase: actual checkpoint/configuration, static-mask compatibility, tensor manifest, dimensions, clock/throughput requirements, technology/library/SRAM availability, concrete capacity/cycle estimates, synthesis-versus-physical-design finish line, and acceptance metrics. Example YAML is not checkpoint evidence.

Pending numerical phase: widths/scales, constants, primitive algorithms/coefficients/domains/latencies, error tolerances, bit-accurate reference and decoding measurements. Existing fixed-width SV types and numerical tables are experiments/placeholders for review, not numerical sign-off. Await Haiel's work; do not treat timing estimates as measured RTL performance.

Older v5 LaTeX/HTML, interface HTML pages and presentation notes remain historical snapshots and can contain superseded behavior. They have not been rebuilt or revalidated here. Review this checkpoint plus the working Markdown and SV contracts; synchronize publication and regenerate provisional numerical widths after the relevant approvals.

## Evidence and limits

Reviewed the working specifications, detailed stage schedules, interface package/channels/port declarations and stage-diagram generator. Checked declaration/modport coverage and searched the working sources for superseded control rules. No SystemVerilog compiler is available on the current PATH; compilation, elaboration and simulation are unverified. No new behavioral RTL was written. Numerical work was not performed.

## Your approval gate

Review these five decisions together:

1. Five-stage sequential core and shared engines; prepared windows/mask in, logits out; preprocessing, training, hard decisions and outer decoding outside the core.
2. Query-row attention masking and no-static-mask baseline, subject to selected-model compatibility.
3. All-token LN2 schedule, U reuse, and conservative separate live banks.
4. Per-position aggregation for every M, whole-frame discard on empty position, no reset for that input error, and the new completion code/index ports.
5. Host-loadable parameters, committed-write handshakes and fatal reset policy.

Your OK permits Phase 2: model/target selection and symbolic-to-concrete feasibility budgeting. It does not approve numerical formats or authorize bypassing Haiel's numerical verification. If you request corrections, revise this checkpoint before advancing.
