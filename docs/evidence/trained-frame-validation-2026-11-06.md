# Trained-frame RTL validation

On 6 November 2026, the SystemVerilog inner decoder produced **144 of 144 exact integer logit matches** against the fixed-point Python reference for one trained frame.

| Item | Result |
| --- | --- |
| RTL revision | `becdee6fe8fee65f44b93a6544692023a2ac726b` |
| Model | Binary marker-code BCJRFormer, LDPC (96, 48) outer code, checkpoint epoch 94 |
| Frame | Sample 0 from the 10-frame software capture, no padded tokens |
| Dimensions `(F, M, N, D, H, K)` | `(27, 1, 144, 96, 8, 6)` |
| Parameter load | 106 tensors packed into 687,991 signed 16-bit words, all writes acknowledged |
| RTL completion | Code 0 at cycle 1,533,280,239 |
| RTL status | Rounding recorded. No saturation or fatal errors. |
| Windows run time | Approximately 8 hours 7 minutes, including parameter and frame loading |
| Fixed-point Python vs. saved PyTorch | 144/144 decoded bits agree. Mean absolute logit difference 0.019557, maximum 0.068535. |

## How the comparison was made

The upstream PyTorch implementation supplied the learned tensors and the already-windowed decoder input. A local converter mapped the PyTorch tensors into the RTL parameter manifest, kept the row-major weight ordering, and quantized weights, biases, and input features to signed 16-bit integers with 10 fractional bits. The conversion multiplied by 1024, rounded to nearest with ties to even, and clamped to the signed 16-bit range. No input or parameter required clipping for this frame.

The [integer Python reference](../../rtl/tests/fixed_reference.py) computed the expected logits from those quantized inputs and parameters. The saved PyTorch logits served as a separate baseline for measuring numerical differences and checking decoded bits.

YoWASP Yosys with slang elaborated the [production sources](../../rtl/protocol/files.f) and [core simulation wrapper](../../rtl/tests/core_sim_top.sv) at the trained dimensions, with `MEMORY_DELAY=2`. The CXXRTL backend generated a C++ model, which G++ 14.2 compiled. The driver loaded weights through the host interface, waited for write acknowledgments, committed the image, and sent the feature words and padding mask. It checked the output index, final-output marker, completion status, and signed logit word at every position. A separate CSV comparison confirmed all 144 exact matches.

## Repeating the test in another simulator

1. Compile the production source list and core wrapper in SystemVerilog mode. Set `F=27`, `M=1`, `N=144`, `D=96`, `H=8`, and `K=6` on the wrapper.
2. From the local capture, use the same parameter image, signed input feature words, and padding mask. Drive the wrapper through its ready/valid handshakes, then compare the signed output words against the integer reference. Output position 0 should be `-680` in the raw fixed-point format.
3. Require a successful completion code, 144 outputs in order, and zero mismatches. Measure the new simulator's wall-clock time independently.

The trained checkpoint, parameter image, frame, per-position comparison CSV, and generated simulator files are kept locally. Repeating this exact frame requires access to those local test vectors. The [verification guide](../verification.md) describes the public fixture runs.

This result covers final outputs for one unpadded, single-read frame. The other nine captured frames, padding and multi-read behavior with trained weights, and decoding accuracy across a larger dataset are still open.
