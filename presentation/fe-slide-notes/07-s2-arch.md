# 07 · Add position and read identity

[Open slide](../BCJRFormer-FE.html#s2-arch) · [All slide notes](README.md)

At token t = m×N+n and feature j, read X[t×D+j], P from PARAM at POSITION_BASE+n×D+j and E at READ_BASE+m×D+j. The first addition saturates before the second addition. Write the result back to the original X address.

## What to point out

- The logical expression is (X[t,j] + P[n,j]) + E[m,j]. The intermediate result is narrowed before the second add.
- Stage 2 preserves the L × D shape and visits padded tokens too.

## RTL references

- [P and E regions of packed PARAM · `bcjrformer_core.sv:11–13`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L11-L13)
- [X, P and E address arithmetic · `position_sequencer.sv:33–42`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/position_sequencer.sv#L33-L42)
- [Intermediate result and X write barrier · `position_sequencer.sv:72–89`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/position_sequencer.sv#L72-L89)
