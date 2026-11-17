# 13 · Bias-seeded MAC and logit writeback

[Open slide](../BCJRFormer-FE.html#s4-rtl) · [All slide notes](README.md)

Follow the read pointer mux between A and B. The FSM loads a_q and b_q in separate memory responses. The MAC combines their product with accumulator_q. The accumulator mux chooses the aligned bias on command acceptance and the returned MAC value during the loop. After the Dth term, linear_ctrl rounds and saturates to S16/F10.

## What to point out

- linear_ctrl supplies the parameter bias and weight pointers. dot_engine sends term products through mac_unit.
- The shared linear response follows the committed logit write. final_ctrl waits for all L responses.

## RTL references

- [A/B mux and MAC request · `dot_engine.sv:19–29`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/dot_engine.sv#L19-L29)
- [Bias seed, operand latches and accumulation · `dot_engine.sv:35–72`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/dot_engine.sv#L35-L72)
- [Signed multiply/add and response register · `mac_unit.sv:7–20`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/arithmetic/mac_unit.sv#L7-L20)
- [Narrowing and LOGIT write request · `linear_ctrl.sv:13–30`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/linear_ctrl.sv#L13-L30)
