# Decisions for Amit

> Current review entry point (10 October 2026): ARCHITECTURE-CHECKPOINT-1.md. Working stage and interface contracts take precedence over older generated publication snapshots. Numerical verification is pending Haiel; this checkpoint awaits Taimor's approval.

Target review draft: 24 September 2026, 20:00 Israel time.

| Decision | Proposed baseline | Evidence or approval needed |
|---|---|---|
| BSc finish line | Defined technical subset by end of November; report/presentation in December | Which blocks, synthesis versus place-and-route, mandatory metrics and acceptance criteria |
| Core boundary | Prepared windows + mask to binary logits | Confirm preprocessing and outer decoding excluded |
| Model | B=1; compile-time F,N,M,D,H,K | Select configuration and usable checkpoint; example YAML alone is insufficient |
| Execution | One shared sequential dot engine; one layer engine reused K times | Accept initial throughput tradeoff and later optimization scope |
| Masking | Reproduce source query-row masking first | Review likely semantic issue before approving alternative key masking |
| Static masks | None in baseline | Verify target trainer/configuration and approve excluding static-mask hardware |
| Input padding | Whole missing-read slots preferred | Confirm partial padding policy and C=0 error behavior |
| Precision | Provisional 16-bit/10-fraction storage, widened accumulators | Calibrate dynamic ranges, primitive errors and decoding impact |
| Nonlinear primitives | Defined variable-latency interfaces | Select rsqrt, GELU, exp and reciprocal implementations after range study |
| Memories | Separate frame/scratch banks, serial access adapters | Calculate concrete sizes and choose SRAM macros versus registers for available technology |
| Verification | Float and bit-accurate block references before integration | Agree tolerances, datasets and required results |
| Work split | Taimor architecture/RTL; Haiel verification candidate | Confirm Haiel availability and ownership, not assumed capacity |

Checkpoint availability, interrupted training outcome and paper reproduction remain unverified. Architecture approval does not resolve those questions.
