# 10 · Shared residual adder and writeback

[Open slide](../BCJRFormer-FE.html#s3-rtl) · [All slide notes](README.md)

In phase 2 the right operand comes from ATTN_OUT at the token base. In phase 5 it comes from VECTOR at base zero. residual_ctrl adds index_q to the selected pointer, saves the left element in left_q, combines it with the right response, and buffers the saturated value for X writeback.

## What to point out

- The controller latches the left X operand and uses the right memory response directly in the add.
- ATTN_OUT supplies residual 1. FFN writes VECTOR for residual 2. Both passes overwrite X and wait for the write acknowledgment.

## RTL references

- [Phase-controlled right bank/base mux · `layer_ctrl.sv:34–41`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/layer_ctrl.sv#L34-L41)
- [Adder and bank/address muxes · `residual_ctrl.sv:8–22`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/residual_ctrl.sv#L8-L22)
- [Operand register, result register and write barrier · `residual_ctrl.sv:34–48`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/residual_ctrl.sv#L34-L48)
