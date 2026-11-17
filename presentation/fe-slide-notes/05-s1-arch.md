# 05 · Embed each input token

[Open slide](../BCJRFormer-FE.html#s1-arch) · [All slide notes](README.md)

Start with FEATURE[t×F + j]. Copy F words into TOKEN. LayerNorm reads and overwrites TOKEN after its statistics passes. Linear writes D outputs to VECTOR. The second LayerNorm works in VECTOR. Copy the D words to X[t×D + j]. PARAM supplies separate γ and β vectors for each norm and one affine W/b region.

## What to point out

- The output tensor has L rows and D columns. Stage 1 visits all L tokens.
- The two norms have separate learned parameters and use the same LayerNorm hardware.

## RTL references

- [LayerNorm selection and F→D affine descriptor · `embedding_ctrl.sv:35–44`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/embedding_ctrl.sv#L35-L44)
- [FEATURE/TOKEN and VECTOR/X copy addressing · `embedding_ctrl.sv:57–65`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/embedding_ctrl.sv#L57-L65)
- [Stage 1 parameter bases and shared ports · `bcjrformer_core.sv:39–42`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L39-L42)
