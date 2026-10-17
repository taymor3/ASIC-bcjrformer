# Reading guide

| To understand… | Start here |
|---|---|
| The algorithm, dimensions, and five-stage schedule | [Architecture](architecture.md) |
| Controllers, wires, shared services, and memory | [Microarchitecture](microarchitecture.md) |
| Fixed-point formats and Taylor bounds | [Numerics](numerics.md) |
| What has been checked and how to repeat it | [Verification](verification.md) |
| Top-level hardware | [bcjrformer_core.sv](../rtl/bcjrformer_core.sv) |
| Every service connection | [Connection inventory](../rtl/RTL-CONNECTIONS.md) |
| Host/command/arithmetic/memory wire bundles | [Channels](../rtl/interfaces/bcjrformer_channels.sv) |
| Typed commands and numerical values | [Contract package](../rtl/interfaces/bcjrformer_contract_pkg.sv) |
| Detailed working stage contracts | [RTL specification](rtl/RTL-specification.md), [Stages 3–5](architecture/Stages3-5-design.md) |
| Latest nonlinear implementation | [Taylor checkpoint](rtl/RTL-TAYLOR-CHECKPOINT.md) |
| Outstanding implementation review | [Review ledger](rtl/RTL-COMPLETE-REVIEW.md) |
| Latest critical review and unresolved findings | [17 October review](reviews/RTL-CRITICAL-REVIEW-2026-10-17.md) |
| Corrective RTL revision and current checks | [17 October corrections](rtl/RTL-REVIEW-FIXES-2026-10-17.md) |

Files under `rtl/` and `architecture/` in this documentation directory preserve dated design decisions. Their earlier unfinished-module and ROM statements are historical and are superseded by the latest Taylor checkpoint and actual production RTL. The concise guides above describe the current publication baseline.
