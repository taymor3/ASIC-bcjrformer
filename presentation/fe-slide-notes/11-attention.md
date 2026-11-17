# 11 · Softmax normalization and bypass mux

[Open slide](../BCJRFormer-FE.html#attention) · [All slide notes](README.md)

Show one row. A first SCORE scan captures maximum_q. A second scan subtracts it, evaluates EXP and accumulates sum_q. The reciprocal response loads inverse_q, and each stored EXP is reread, scaled and written to PROB. Padded queries select the uniform constant. The weighted-value dot reads PROB and VALUE and stores the head slice in Z.

## What to point out

- Ordinary queries normalize across all L keys. A score difference below −16 writes zero into EXP.
- After PROB commits, weighted_value_ctrl reads PROB and VALUE to write the head slice of Z.

## RTL references

- [Query mask and softmax descriptor · `attention_ctrl.sv:31–47`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/attention_ctrl.sv#L31-L47)
- [Subtract, denominator adder, multiplier and memory bank mux · `softmax_ctrl.sv:18–42`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/softmax_ctrl.sv#L18-L42)
- [Maximum, EXP, reciprocal, PROB and bypass paths · `softmax_ctrl.sv:49–100`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/softmax_ctrl.sv#L49-L100)
- [Probability and VALUE operand pointers and Z destination · `row_dot_ctrl.sv:29–46`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/row_dot_ctrl.sv#L29-L46)
