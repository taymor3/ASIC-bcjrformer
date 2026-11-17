# 09 · Refine X with K encoder layers

[Open slide](../BCJRFormer-FE.html#s3-arch) · [All slide notes](README.md)

For each layer, normalize X into U. Project U into Q, KEY and VALUE. For each head/query produce SCORE, EXP and PROB rows, then write Z. Project Z into ATTN_OUT and add to X. Normalize updated X into the reused U bank. For each token, run U→FFN_HIDDEN→VECTOR and add VECTOR back into X.

## What to point out

- For each head, attention scales QKᵀ by 1/√(D/H), applies row softmax, and weights V before the output projection.
- The FFN maps D → 4D → D with GELU between linear maps. Each layer returns L × D.

## RTL references

- [Layer index and parameter-region descriptor · `encoder_ctrl.sv:12–32`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/encoder_ctrl.sv#L12-L32)
- [Pointers for norm, residual and FFN · `layer_ctrl.sv:30–46`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/layer_ctrl.sv#L30-L46)
- [Head/query scheduling and projection barrier · `attention_ctrl.sv:64–91`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/attention_ctrl.sv#L64-L91)
- [Hidden/vector bank selection and GELU memory port · `ffn_ctrl.sv:16–30`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/ffn_ctrl.sv#L16-L30)
