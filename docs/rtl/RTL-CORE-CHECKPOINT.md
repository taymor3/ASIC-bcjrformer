# Host/core control checkpoint

10 October 2026. This implements the next authorized structural RTL step after the protocol and memory adapters. Numerical verification remains with Haiel. No trained model, numerical primitive, physical SRAM or hardware target is selected here.

## Implemented behavior

`rtl/control/core_ctrl.sv` connects the existing host interface, five stage-command interfaces, and one memory requester. It supplies the core loader at memory-fabric client 0. The full `bcjrformer_core` processing wrapper and stage/controller implementations remain unfinished.

Integration supplies four compile-time native-element counts: `PARAM_WORDS`, `FEATURE_WORDS`, `MASK_WORDS`, and `OUTPUT_WORDS`. Zero defaults deliberately do not invent a model. Counts must be positive and addressable; outputs must fit the 16-bit aggregation position contract and the host's configured `INDEX_W`. Actual bank capacities, tensor shapes and parameter offsets must match the selected manifest later.

The controller:

- Accepts parameter words in strict address order starting at zero. New loading invalidates the previous image. Invalid addresses receive an error acknowledgment without reaching memory.
- Waits for each committed-memory response and its accepted host acknowledgment. Commit is legal only back in idle after all expected words. A second/early/overlapping commit is fatal.
- Gives parameter loading priority over a simultaneously presented frame. Frame-ready requires a committed image, no pending transaction, and no write/commit presented that cycle.
- Loads exactly `FEATURE_WORDS` features, then `MASK_WORDS` bits. Checks `last` at each accepted element, before issuing its write. Negative 16-bit values use native two's-complement low bits with zero unused high bits, matching the fabric contract.
- Commands embedding, position, encoder, final projection, and aggregation once each, waiting for the selected child's accepted completion before advancing. Accumulates nonfatal rounded/saturated status and propagates either fatal status bit or `rsp_error`.
- Starts output reads only after successful aggregation. Returns outputs in index order; data/index/last remain stable through stalls. OK completion follows the final accepted output.
- Handles `EMPTY_POSITION` by emitting no outputs, reporting its validated position, and returning idle with the parameter image retained after host acceptance.
- Handles fatal faults by draining outstanding memory/stage transactions, reporting FATAL, then locking host readiness until reset. Busy remains asserted in that fatal lock. Earlier writes are not rolled back; a fatal output-read error can follow already transferred outputs, which the receiver must discard.
- Synchronously resets transaction/control state and image validity without clearing storage.

The FSM uses distinct accept/issue/wait states for loading, issue/wait for stages and reads, a held output state, and a held completion state. Counter widths come from complete configured bank lengths; feature loading is not limited by the 16-bit stage vector descriptor.

## Illegal commit during outstanding work

The unhandshaked `parameter_commit` strobe can arrive while a request, parameter acknowledgment, output or completion is stalled. Already presented requests remain valid/stable until accepted, and their responses drain before a fatal report. Parameter acknowledgment error/data and output payload do not change merely because of that later fault.

If a commit arrives during a held completion, that existing report stays unchanged. After it is accepted, a separate FATAL report describes the illegal host operation; reset is then required. Further activity while fatal-locked is ignored. These collision choices are explicit review points.

## Verification approach and limits

Final results: compilation/elaboration **0 errors, 0 warnings**; structural inventory **29 module kinds / 65 unique service endpoints**; **30/30 recorded controller checks passed** (21 scenarios, four short arbitrary-backpressure safety checks, five completed/stalled witnesses). The existing fast-delay memory/fabric regression also passed at its 16-step bound after the core was added to the production file list. The two-frame scenario additionally passed a separate 96-step arbitrary-backpressure safety run in `rtl/tests/core-control-0.log`; this is supplemental evidence, not an extra scenario in the 30-check count.

`rtl/tests/core_control_formal.sv` uses the actual controller with **testbench-only** delayed memory and stage services. The stages do not calculate inference; output memory responses contain known signed patterns. An independent scoreboard checks parameter and frame writes, committed-write ordering, stage order, output values/index/last, fatal locking, response stability, and reset behavior.

The elaboration fixture connects the actual controller to client 0 of the existing 13-client fabric and both actual memory adapters. It also elaborates one-element and non-power-of-two output configurations, plus a feature length of 131072 to check counter sizing. These are test configurations, not model choices. This connected fixture is compiled, not an end-to-end dynamic memory/core proof.

`run_core_suite.py` records results and log locations in `rtl/tests/core-control-results.json`:

- Scenario checks use 192 time steps, a prescribed periodic backpressure schedule, all scoreboard assertions, and an assertion that the scenario actually finishes. They cover two frames with parameter reuse; empty-position recovery; packet errors; parameter ordering/excess words; memory/stage faults; commit collisions; reload priority; and reset during loading or stalled output.
- Short safety checks leave host, memory and stage backpressure arbitrary, with a 24-step bound. They do not establish end-to-end progress through every later state.
- Witness searches require completed scenarios and an observed stall; reset cases also require an observed reset. Assertions are enforced as constraints, and success requires **model found**, not merely a zero exit status. Witness files are SAT-generated VCD traces, not event-driven simulation runs.

The final five witnesses use the same prescribed periodic stall schedule as the scenario checks. An earlier unrestricted two-frame witness search exceeded the runner's 120-second limit and was replaced; it is not passing evidence. The successful `core-verified-*.log` files and `core-control-results.json` describe the final checked runs. Scope remains control-only even when the result says PASS.

These are bounded control checks with modeled services. They do not establish unbounded safety/liveness, correctness of stage computation, numerical inference accuracy, physical memory timing, or silicon performance. Existing adapter/fabric verification remains documented separately in `RTL-MEMORY-CHECKPOINT.md`.

Reproduce from the project root using Python with access to the existing `rtl/.tools` packages:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_core_suite.py
node rtl/architecture-connections.cjs
```

The production file list includes `rtl/control/core_ctrl.sv`. The external prototype has matching configuration parameters. Interface width/type guards are simulation-only when the synthesis frontend cannot evaluate interface-member `$bits`; the connected compilation fixture checks their real interface declarations.

## Review and next step

Review loading/commit ordering, held host payloads, EMPTY_POSITION recovery, fatal draining/locking, and the separate error report for a commit during held completion. The next phase is stage/subcontroller loops using the approved typed interfaces and memory layout. Numerical arithmetic remains behind its separate review gate.
