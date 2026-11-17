# 15 · Mask gate, accumulator and reciprocal

[Open slide](../BCJRFormer-FE.html#s5-rtl) · [All slide notes](README.md)

The mask test controls whether LOGIT_ISSUE runs. A successful LOGIT_WAIT advances both registers. count_q feeds the zero comparator and the reciprocal service. When nonzero, the returned inverse multiplies sum_q and the converted product loads value_q for the OUTPUT write.

## What to point out

- Dashed paths show control decisions. After each committed OUTPUT write, clear both registers for the next position.
- Only successful aggregation enables host readout. The core holds each logit, index and last flag through backpressure.

## RTL references

- [Sum adder, scaling multiply and request signals · `aggregation_ctrl.sv:10–24`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/aggregation_ctrl.sv#L10-L24)
- [Register updates, zero-count branch, writeback and clear · `aggregation_ctrl.sv:36–61`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/aggregation_ctrl.sv#L36-L61)
