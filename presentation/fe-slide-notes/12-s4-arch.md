# 12 · Project each token to a scalar logit

[Open slide](../BCJRFormer-FE.html#s4-arch) · [All slide notes](README.md)

Read X[t×D + j] and PARAM[FINAL_WEIGHT + j] across j, seed the accumulator with the final bias, then store the narrowed result at LOGIT[t]. Repeat over all L tokens. The host still has N outputs because Stage 5 reduces across reads.

## What to point out

- Weights and bias are shared across tokens. The result contains L logits in flattened read/position order.
- The affine head runs on padded tokens too. Stage 5 uses MASK to decide which scores contribute.

## RTL references

- [Final weight and bias bases · `bcjrformer_core.sv:13–15`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L13-L15)
- [D→1 descriptor and X/LOGIT pointers · `final_ctrl.sv:11–22`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/final_ctrl.sv#L11-L22)
- [Bias alignment, dot and destination formatting · `linear_ctrl.sv:9–30`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/linear_ctrl.sv#L9-L30)
