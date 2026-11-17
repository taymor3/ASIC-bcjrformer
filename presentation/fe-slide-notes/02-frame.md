# 02 · One controller sequences the frame

[Open slide](../BCJRFormer-FE.html#frame) · [All slide notes](README.md)

Point out the two levels of acknowledgement. The memory response acknowledges a committed word. The command response marks completion of a whole stage. The host consumes each output before the core advances its output index.

## What to point out

- Transfers happen when valid and ready are both high. A stalled producer holds its valid and payload.
- The shared memory fabric accepts one transaction at a time, retains its requester, and returns the read value or write acknowledgment.

## RTL references

- [Host signal directions · `bcjrformer_channels.sv:45–81`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/interfaces/bcjrformer_channels.sv#L45-L81)
- [Parameter, feature and mask request/acknowledgment states · `core_ctrl.sv:162–201`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/core_ctrl.sv#L162-L201)
- [Stage barrier, empty-position result and host readout · `core_ctrl.sv:204–237`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/core_ctrl.sv#L204-L237)
