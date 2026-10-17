# Memory adapters: review checkpoint

10 October 2026. The previous protocol RTL checkpoint was approved. This step adds the parameter and scratch adapters and verifies their connection to the fabric. Model selection, arithmetic calibration, physical SRAM macros and technology decisions remain deferred.

## What changed

| File | Purpose |
|---|---|
| rtl/memory/memory_adapter.sv | Common request buffer, validation, delayed storage access and held response; generated native-width backing arrays |
| rtl/memory/parameter_mem.sv | PARAM-only adapter, explicit DEPTH and RESPONSE_DELAY |
| rtl/memory/scratch_mem.sv | Non-PARAM banks, explicit BANK_DEPTHS[18] and RESPONSE_DELAY |
| rtl/interfaces/bcjrformer_ports.svh | Matching adapter configuration parameters |
| rtl/protocol/files.f | Compile order now includes the adapters |
| rtl/protocol/transaction_router.sv | Explicit per-client request/response muxes replace variable-width selections; same handshake contract |
| rtl/protocol/memory_fabric.sv | Constant slice checks replace variable shifts for unused write bits; same validation policy |
| rtl/tests/memory_formal.sv | Connected fabric/adapters checked against an independent transaction and tracked-word reference |
| rtl/tests/run_memory_formal.py | Reproducible partitioned data/control proofs and witness generation |

These backing arrays are behavioral RTL, not a selected physical SRAM implementation. Native widths follow the existing provisional package: 16-bit signed activation/parameters, 48-bit signed scores, 24-bit unsigned exponentials/probabilities and 1-bit mask. No numerical format was calibrated or approved here. Physical mapping can replace the storage behind the interface later.

## Memory lifecycle

`IDLE -> WAIT_ACCESS -> RESPONSE -> IDLE`

The adapter accepts one request only in IDLE and captures its payload. After RESPONSE_DELAY clock edges, it performs the storage access. A valid write changes its native word on that edge; a read captures the returned word. Response-valid is then asserted with captured data/error. Write acknowledgments carry zero read-data. No further request is accepted while an access or response is pending.

The response stays unchanged until accepted. Backpressure cannot repeat the storage operation. Signed words are sign-extended to the common payload on reads; MASK/EXP/PROB are zero-extended. Writes require unused high bits to be zero, even for negative native values: write the native two's-complement low bits, not a sign-extended payload.

RESPONSE_DELAY must be at least 1. A test delay is a model of storage timing, not an SRAM/clock target. Parameters default to disabled depth zero; integration must supply real capacities. The adapter checks bank ownership, depth/address, expected format and unused high write bits before touching storage. PARAM-only and scratch-only boundaries cannot access each other's banks.

Reset clears the pending request, delay state and response but does not erase backing words. A reset on the planned access edge cancels that access. If a write already committed before reset, its word remains even if its response was not accepted. Image/frame validity remains the future core controller's responsibility. Unwritten words are uninitialized; callers must load/write required data before reading it.

## Verification and its limits

The integrated 13-client elaboration fixture instantiates both adapters with small test depths and delays. Compilation with pyslang 12.0.0 is clean: 0 errors, 0 warnings. Depths of two/eight elements in tests are verification fixtures, not a chosen model.

Connected bounded checks use the actual SystemVerilog fabric/adapters through the Yosys slang frontend. The reference predicts request legality independently, records the accepted owner/payload, predicts storage commitment using configured delays, and tracks an arbitrary location across writes and resets. It checks that successful response cannot precede storage access, response fields remain stable under stalls, errors reach only the owner, and rejected fabric requests never dispatch to storage.

The proof is partitioned deliberately:

- **Data checks:** one client, well-formed requests and arbitrary data/read-write direction, either test address, request timing, receiver backpressure and reset. Representative banks cover PARAM, MASK, activation, SCORE, EXP and PROB; delays 2/3 and the one-cycle boundary are checked. Read data is compared after a known write; uninitialized data is not assigned a fabricated value.
- **Control/fault checks:** three clients with unrestricted request fields, including invalid bank/address/format/high write bits and forbidden non-loader PARAM/MASK writes. Error, ownership, dispatch and stable-response properties are checked; valid read data is covered separately by the data checks.
- **Router regression:** 1, 2, 3, 5 and 13 clients checked again after the mux change, at 24 steps each.

Memory safety checks use a **16-step bound**. Witness searches use 24 steps and demonstrate real write/read-back, response stalls and read-back after reset; a separate fault witness exercises an error response under backpressure. Witnesses are solver-generated traces, not an event-driven simulation run.

Final results: **8/8 memory checks passed**, **5/5 router regressions passed**, compilation **0 errors/0 warnings**, and both witness searches returned **model found** with all scoreboard assertions enforced as constraints. The result index is `rtl/tests/memory-results.json`; native activation data is the `single` case, and the other bank cases cover PARAM/MASK/SCORE/EXP/PROB. The eight checks count the single, five bank cases, fast-delay and unrestricted-control cases listed below.

This is bounded verification, not an unbounded proof or end-to-end inference simulation. The connected fault proof has three clients; the intended 13-client assembly is compiled, and its shared routing engine has a separate 13-client proof. Native data cases use representative banks and small depths; all model-sized memories and physical-macro timing remain outside these checks. Adapter-local malformed requests bypassing the fabric are not separately proven in this checkpoint. No arithmetic accuracy, area or timing result is claimed.

Reproduce from the project root with Python and the existing local rtl/.tools dependencies:

```text
python rtl/tests/compile_protocol.py
python rtl/tests/run_memory_formal.py single
python rtl/tests/run_memory_formal.py bank-0
python rtl/tests/run_memory_formal.py bank-2
python rtl/tests/run_memory_formal.py bank-13
python rtl/tests/run_memory_formal.py bank-14
python rtl/tests/run_memory_formal.py bank-15
python rtl/tests/run_memory_formal.py fast
python rtl/tests/run_memory_formal.py control
python rtl/tests/run_memory_formal.py single cover
python rtl/tests/run_memory_formal.py control cover
```

The initial monolithic check exhausted resources; it was replaced by the partitioned checks. Superseded logs are not passing evidence. Use `memory-verified-*.log`, `memory-cover-single.log`, `memory-cover-control.log` and `router-final-*.log` for this checkpoint's results. For a cover run, success requires the log to say **model found**, not just a zero process exit status. The generated VCD files contain the corresponding witness transactions.

## Your review

Approve or correct these implementation choices:

1. One buffered request and one held response per adapter, with explicit configurable response delay.
2. Native-width backing storage and canonical read extension; no clearing RAM on reset.
3. Write acknowledgment only after commitment; pending access cancelled on reset, committed words retained.
4. Explicit depth configuration, zero disabled default and validation before storage access.

After your OK, the next step is host/core control: parameter loading/commit, frame loading, five-stage sequencing, output transfer and the approved recoverable/fatal completion paths. Stage response models can exercise control before numerical engines exist; they will remain clearly marked testbench models.
