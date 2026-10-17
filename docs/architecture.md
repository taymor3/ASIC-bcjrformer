# Architecture

The core performs one inference frame at a time. Input features and a padding mask enter through a ready/valid host interface after parameters have been loaded and committed. Intermediate tensors live in scratch banks. The final result is one aggregated logit per position; no sigmoid is applied in the core.

## Dimensions

| Symbol | Meaning |
|---|---|
| F | Input features per token |
| M | Read slots per frame |
| N | Positions per read |
| L = M × N | Tokens per frame |
| D | Embedded token width |
| H | Attention heads; D must be divisible by H |
| d = D/H | Features per head |
| K | Encoder layers |

All dimensions are elaboration-time parameters. Defaults of zero are rejected. The wrapper also checks bounded counters/address spaces and rejects static-mask mode. Test shapes are small verification fixtures, not target model selections.

## Five-stage schedule

1. **Embedding:** normalize each F-element input; apply learned F-to-D projection; normalize the D-element embedding; store X.
2. **Position:** add position embedding P and read embedding E to X, with separate fixed-point conversion points.
3. **Encoder:** for each layer, sweep LN1; compute attention; add its residual; sweep LN2; run a D → 4D → D GELU FFN per token and add its residual.
4. **Projection:** apply a learned D-to-1 projection per token, producing logits.
5. **Aggregation:** for each position, average logits from the read slots valid at that position. Produce N outputs only after successful aggregation.

## Attention and padding

Attention projects Q, K, V, then iterates over head/query rows. Each ordinary row computes scaled Q·K scores, subtracts the row maximum, evaluates EXP, sums, normalizes, and computes probability-weighted V. The concatenated head result is output-projected.

The source-compatible padding rule concerns **queries**: a padded query gets a uniform probability row over all L keys. Valid queries retain all keys, including padded ones. This is not key masking. Static attention masks are unsupported in the complete baseline.

Aggregation uses one validity bit for both the sum and count at each position. If a position has no valid reads, the frame reports recoverable `EMPTY_POSITION` and publishes no logits. This corrected aggregation contract must also be used in the validation reference; specific original software branches differ, including the M=1 bypass.

## Parameter layout

Parameters are packed in native signed16/F10 words: embedding normalization/projection, position embeddings, read embeddings, K layer regions, and final projection. A layer region is `12*D*D + 13*D` words. Addresses are native element offsets, not byte offsets.

The [manifest exporter](../rtl/scripts/parameter_manifest.py) and [complete assembly](../rtl/bcjrformer_core.sv) define the layout. Select dimensions and a trained checkpoint together, export and quantize its tensors separately, then check the exact manifest. The exporter validates raw tensor names/counts/ranges; it is not a training or quantization tool.

See [microarchitecture](microarchitecture.md) for the physical sharing and [numerics](numerics.md) for provisional formats.
