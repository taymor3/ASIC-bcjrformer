# 14 · Average only valid reads

[Open slide](../BCJRFormer-FE.html#s5-arch) · [All slide notes](README.md)

For fixed n, scan MASK[m×N+n]. A zero bit admits the corresponding LOGIT[m×N+n]. Reduce over m, scale the signed sum by the reciprocal of the valid count, and write OUTPUT[n]. If one n has no valid reads, the host gets EMPTY_POSITION with that index instead of a logit stream.

## What to point out

- The same set of unpadded logits drives both the sum and the count. The output has N entries.
- If Cₙ = 0, aggregation returns EMPTY_POSITION with the first empty n. The core suppresses the whole output frame.

## RTL references

- [MASK, LOGIT and OUTPUT pointers · `aggregation_ctrl.sv:15–25`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/aggregation_ctrl.sv#L15-L25)
- [Mask gate, sum/count, empty result and reciprocal · `aggregation_ctrl.sv:33–57`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/aggregation_ctrl.sv#L33-L57)
- [Empty result and output readout · `core_ctrl.sv:215–234`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/core_ctrl.sv#L215-L234)
