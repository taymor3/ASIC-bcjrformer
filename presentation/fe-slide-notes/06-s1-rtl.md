# 06 · Embedding copy and address muxes

[Open slide](../BCJRFormer-FE.html#s1-rtl) · [All slide notes](README.md)

Read the mux selectors before following the wires. copy_output selects FEATURE→TOKEN or VECTOR→X and switches the norm descriptor. WRITE_ISSUE switches to the destination pointer. The read response loads word_q, whose low 16 bits drive the next memory write.

## What to point out

- Shared layernorm_ctrl normalizes TOKEN and VECTOR in place. Shared linear_ctrl writes VECTOR using dot_engine.
- Copy phases use READ and WRITE issue/wait states. The final X write acknowledgment gates RESPONSE.

## RTL references

- [Shared service descriptors · `embedding_ctrl.sv:35–44`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/embedding_ctrl.sv#L35-L44)
- [Read/write request muxes · `embedding_ctrl.sv:57–66`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/embedding_ctrl.sv#L57-L66)
- [word_q, acknowledgments and token advancement · `embedding_ctrl.sv:78–96`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/embedding_ctrl.sv#L78-L96)
