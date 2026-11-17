# 08 · One adder with operand feedback

[Open slide](../BCJRFormer-FE.html#s2-rtl) · [All slide notes](README.md)

Trace the low 16 response bits into value_q for X or parameter_q for P/E. position_ctrl wires one local adder to the sequencer. Feed ADD_P back into value_q, fetch E, then feed ADD_E back into value_q for the write. The register in the arithmetic unit holds the reply under backpressure.

## What to point out

- Each addition widens the signed operands, then saturates back to signed 16-bit with 10 fractional bits.
- The loop advances j, then n, then m after write acknowledgment. The last acknowledgment gates RESPONSE.

## RTL references

- [Sequencer and one local adder instance · `position_ctrl.sv:7–9`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/position_ctrl.sv#L7-L9)
- [Operand wiring and read/response loads · `position_sequencer.sv:42–79`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/control/position_sequencer.sv#L42-L79)
- [Signed add, saturation and registered reply · `position_add_unit.sv:4–10`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/arithmetic/position_add_unit.sv#L4-L10)
