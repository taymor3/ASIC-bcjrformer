# Verification and reproduction

The recorded baseline is [implementation-2026-10-16.json](evidence/implementation-2026-10-16.json). Its source hashes identify the production RTL and its numbers are historical implementation evidence, not results newly obtained by cloning this repository.

## Environment

Install [requirements-dev.txt](../requirements-dev.txt) in a Python 3.12 virtual environment and use Node.js 22 or newer. Publication smoke/numerical checks were run with Python 3.12.14 and Node.js 24.19.0. The Python runners import normally installed packages; their legacy optional `rtl/.tools` search path need not exist. Do not vendor tool installations into the repository.

The recorded packages include pyslang 12.0.0 and YoWASP Yosys 0.69.0.0.post1233 with its `read_slang` frontend. PyPI/network access is required for initial setup; the actual verification then runs locally. No GPU or model weights are required.

## Reproduction groups

Run from the repository root:

```sh
python scripts/check.py smoke
python scripts/check.py numerics
python scripts/check.py full
```

`smoke` checks package integrity, both elaboration fixtures, connection inventory, and manifest round trips. `numerics` checks Taylor budgets and integer-reference sweeps. `full` additionally generates arithmetic vectors, lowers actual RTL into vector-cell netlists, executes the cycle interpreter, checks all three core shapes and fault recovery, proves the selected conversion, and runs bounded router/memory regressions. It captures the explicit proof/build/cycle success markers required by the final summarizer.

Logs and generated fixtures appear under `rtl/tests` and are ignored by Git. The archived summary under `docs/evidence` is retained unchanged. The fresh full run writes `rtl/tests/complete-evidence.json`; inspect that file and the logs to evaluate your run.

## Recorded coverage

| Check | Scope |
|---|---|
| Elaboration | Complete single/multi fixtures and connected protocol fixture; 0 errors/warnings |
| Structural frontend | Three complete lowered assemblies; zero reported structural problems |
| Primitive cycles | 847 vectors: results, flags, tags, held responses, reset |
| Complete frames | 4 frames in each of three small configurations; every computational scratch write checked |
| Integration recovery | 4 fatal/recoverable/reset scenarios |
| Manifests | Three exact raw-word image round trips |
| Conversion proof | Exhaustive signed48/F20 → signed16/F10 rounding/saturation and flags |
| Bounded infrastructure | Router: 24 steps; connected memory: 16 steps |
| GELU reference sweep | All 65,536 represented signed16/F10 inputs |
| EXP reference sweep | 12,289 inputs plus analytic all-domain bound |

Complete configurations `(F,M,N,D,H,K)` are `(1,1,1,1,1,1)`, `(2,2,2,2,1,2)`, and `(2,1,2,3,3,1)`. Across the 12 frames, 2,497 computational scratch writes are checked, including overwritten workspaces. Frames exercise ordinary/padded queries, partial padding, empty positions, retained parameters, and reuse after recoverable completion.

## What these checks do not establish

The cycle engine executes lowered **actual RTL** with a generic two-state interpreter; it is not commercial four-state/event-driven simulation. Unused uninitialized bits are represented as zero, and meaningful reads rely on actual prior writes. Complete checks use deterministic stalls and small fixtures. They do not prove arbitrary-delay liveness, all controller state spaces, or full-size behavior.

The Python reference predicts integer behavior independently of the controller implementation but follows the same provisional numerical contract. Matching it does not establish equivalence to a selected floating-point network or decoding quality. Source-level Taylor bounds apply to represented inputs and function outputs, not end-to-end model error.

There is no selected device, SRAM macro, measured frequency, utilization, power, throughput, or silicon sign-off. Earlier bounded controller-suite evidence remains in dated checkpoints; those suites are available but are not silently included in the current full run.
