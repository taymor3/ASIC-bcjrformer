# Stages 1–2 control checkpoint

11–12 October 2026. This implements the next authorized controller step after host/core control. Haiel's numerical verification remains pending. Dimensions, parameter offsets, numerical methods, SRAM technology and performance targets are not selected by the test configurations.

## Stage 1: implemented controller

`rtl/control/embedding_ctrl.sv` implements the existing public `embedding_ctrl` contract. For every token, including padded tokens, it:

1. Copies all F FEATURE elements into TOKEN, with one read and one committed write per element.
2. Issues an in-place LayerNorm(F) command for TOKEN and accepts its completion.
3. Issues a linear F→D command from TOKEN into VECTOR and accepts its completion.
4. Issues an in-place LayerNorm(D) command for VECTOR and accepts its completion.
5. Copies D VECTOR elements into that token's X slice, waiting for every write acknowledgment.

The token loop finishes only after the final X write commits. New commands restart token/element counters and clear accumulated status. Command, memory and child-request payloads stay stable while stalled. Completed status remains held until accepted. Memory errors become protocol failures; child fatal bits and errors propagate. An error flag without a fatal status bit is treated as a protocol fault. After a fatal completion is accepted, command-ready stays low until reset.

Integration supplies F, D, TOKENS and six parameter bases: GAMMA_F_BASE, BETA_F_BASE, WEIGHT_BASE, BIAS_BASE, GAMMA_D_BASE and BETA_D_BASE. Dimensions must be positive and fit the approved count/address limits; parameter ranges are checked for addressability. Bases refer to the same manifest as the host-loaded image. Default zero dimensions do not choose a model. The prototype and production file list now match this implementation.

LayerNorm and linear controllers/datapaths remain unimplemented. Their responses are required to certify their own committed writes. Stage 1 is a real controller and copy path, not a working numerical embedding engine yet.

## Stage 2: implemented internal sequencer

`rtl/control/position_sequencer.sv` implements the m/n/j loops and memory/control portion of Stage 2. It traverses read slots, positions, and features, in that order. For each element:

```text
read X[(m*N+n)*D+j]
read PARAM[POSITION_BASE+n*D+j]
request first local add/conversion; accept result/status
read PARAM[READ_BASE+m*D+j]
request second local add/conversion; accept result/status
write X[(m*N+n)*D+j]; wait for commitment
```

It performs two distinct add/conversion requests, preserving the two conversion points in the working specification. No padding-mask access or skip is introduced. Index counters advance only after the X write response; each inner counter resets when the outer loop advances. Counts and parameter ranges are validated, requests/results obey ready/valid, nonfatal status accumulates, and fatal memory/arithmetic/tag faults stop the sequence and hold a response until accepted. Fatal state requires reset before reuse.

The internal numerical boundary is `bcjr_arith_if #(position_add_req_t,act_t)`: a pair of provisional stored operands, tag zero, a converted stored result, echoed tag, and the existing error/status fields. `position_add_req_t` is a new **internal** package type. It does not introduce a global shared scalar service or change the external `position_ctrl` ports.

**The public `position_ctrl` wrapper remains a declaration.** It will combine this sequencer with the local widened-add/conversion datapath after numerical choices are approved. The production file list includes the sequencer but contains no fabricated arithmetic unit or testbench model. This checkpoint therefore completes Stage 2's control helper, not its numerical processing wrapper.

## Verification

Final results: compilation/elaboration **0 errors, 0 warnings**; **27/27 control checks passed** (21 prescribed-stall scenarios, two 24-step arbitrary-readiness safety checks, four completed/stalled witnesses). The additional M=3,N=2,D=1 repeated-command scenario passed at 384 steps. Public structural inventory remains **29 module kinds / 65 service endpoints**; the position sequencer is an internal helper and is not a replacement public arithmetic service.

The existing two-frame host/core scenario also passed its 192-step prescribed-stall regression after the package/declaration changes; evidence is in `rtl/tests/core-stage12-regression.log`. This checks that the existing control behavior still works and is not an integrated Stage 1–2 numerical inference test.

`rtl/tests/stage12_control_formal.sv` checks the actual controllers against an independent transaction/order/address scoreboard. It supplies test-only delayed memory, norm, linear and addition services. Norm/linear models return status/completion rather than computing LayerNorm or matrix multiplication; memory returns specified test patterns. The small Stage 2 addition model only exercises operand/result routing and uses in-range toy values. None of these models is production arithmetic or numerical sign-off.

The main scenarios cover two consecutive commands and counter restart, read/write errors, numerical error propagation, invalid empty commands, reset during memory/service waits, error-without-fatal-status, wrong arithmetic tags, and accumulated rounded/saturated flags. Request and held completion stability are checked. Stage 1 uses F=2,D=3,TOKENS=2. Stage 2 uses M=2,N=2,D=2 and an additional M=3,N=2,D=1 boundary configuration. These are verification fixtures, not selected model dimensions.

Scenario runs prescribe periodic memory/service/response backpressure and assert completion by the final checked step. Short safety runs leave those readiness inputs arbitrary for 24 steps. Witness searches constrain every assertion and require completion plus a real stall; reset witnesses also require a reset. Success requires **model found**. The traces are SAT-generated VCDs, not event-driven simulation or full inference runs.

The connected elaboration fixture checks embedding against the real norm/linear switches and memory-fabric client 1, and the position sequencer against client 2 and its local arithmetic interface. Its standalone fixtures have independently chosen configuration values for width/type checking; this is compilation, not a configured end-to-end inference assembly or a dynamic proof with actual numerical services.

Use `rtl/tests/stage12-results.json` and the `stage12-verified-*.log` files as the result index. Bounds vary by scenario and are recorded per run. Bounded checks do not establish unbounded liveness, all reset-state combinations, full-size memory integration, numerical accuracy, timing or area.

Reproduce from the project root with Python and the existing local verification packages:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_stage12_suite.py
node rtl/architecture-connections.cjs
```

## Review and next step

Review Stage 1's committed-write and child-completion ordering, both stages' address/counter loops, status/fatal behavior, and Stage 2's internal control/datapath split. The next controller checkpoint is Stage 3: encoder/layer sequencing, attention subcontrollers, FFN and residual control. Production numerical services remain behind their separate review gate.
