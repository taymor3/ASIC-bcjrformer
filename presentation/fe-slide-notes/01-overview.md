# 01 · From read windows to decoded logits

[Open slide](../BCJRFormer-FE.html#overview) · [All slide notes](README.md)

Trace one frame from host-supplied feature windows to N output logits. The top-level commands carry control. Each tensor handoff is a read from a logical bank where the preceding producer committed data.

## What to point out

- M = reads, N = positions, L = M × N tokens, F = input features, D = model width.
- H = attention heads, K = encoder layers. Token index t = m × N + n.

## RTL references

- [Frame shape, parameter regions and 18 bank depths · `bcjrformer_core.sv:9–17`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L9-L17)
- [Core and first three stage instances · `bcjrformer_core.sv:37–51`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L37-L51)
- [Five-stage command and response selection · `core_ctrl.sv:66–78`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/core_ctrl.sv#L66-L78)
