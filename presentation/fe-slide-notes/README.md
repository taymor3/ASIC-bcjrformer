# BCJRFormer front-end slide notes

[Open the HTML presentation](../BCJRFormer-FE.html)

Each entry includes a speaking guide and links to the exact SystemVerilog blocks at the presentation’s source revision.

1. [From read windows to decoded logits](01-overview.md)
2. [One controller sequences the frame](02-frame.md)
3. [One shared memory transaction interface](03-memory-interface.md)
4. [Bank IDs select native-width arrays](04-memory-banks.md)
5. [Embed each input token](05-s1-arch.md)
6. [Embedding copy and address muxes](06-s1-rtl.md)
7. [Add position and read identity](07-s2-arch.md)
8. [One adder with operand feedback](08-s2-rtl.md)
9. [Refine X with K encoder layers](09-s3-arch.md)
10. [Shared residual adder and writeback](10-s3-rtl.md)
11. [Softmax normalization and bypass mux](11-attention.md)
12. [Project each token to a scalar logit](12-s4-arch.md)
13. [Bias-seeded MAC and logit writeback](13-s4-rtl.md)
14. [Average only valid reads](14-s5-arch.md)
15. [Mask gate, accumulator and reciprocal](15-s5-rtl.md)
16. [Ten trained frames matched the integer reference](16-verification.md)
