# 04 · Bank IDs select native-width arrays

[Open slide](../BCJRFormer-FE.html#memory-banks) · [All slide notes](README.md)

A bank is the controller-visible address space. An array is its RTL storage implementation. For example, BANK_MASK selects logical bank 2 and address t selects one element of its one-bit array at `scratch.adapter.banks[2].storage.words[t]`. The common transaction payload is 96 bits, while that array stores exactly one bit per word. The shape X[L,D] is flattened into the one-dimensional X array at t×D+j. Keeping these concerns separate lets controllers retain bank IDs and addressing when storage is replaced by SRAM or mapped differently.

## What to point out

- Each enabled bank generates words[depth] in memory_adapter. MASK uses one bit per word even though the channel has 96-bit payloads.
- One bank-level contract lets the controllers keep the same pointers if the backing storage is mapped to SRAM.

## RTL references

- [All 18 logical IDs · `bcjrformer_contract_pkg.sv:46–51`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/interfaces/bcjrformer_contract_pkg.sv#L46-L51)
- [Physical RTL array depth by logical bank, at elaboration · `bcjrformer_core.sv:15–17`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L15-L17)
- [One fabric and the two adapter instances · `bcjrformer_core.sv:85–88`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L85-L88)
- [Parameter-only adapter wrapper · `parameter_mem.sv:1–7`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/memory/parameter_mem.sv#L1-L7)
- [Scratch adapter wrapper · `scratch_mem.sv:1–6`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/memory/scratch_mem.sv#L1-L6)
- [Generate one native-width array per enabled bank · `memory_adapter.sv:45–68`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/memory/memory_adapter.sv#L45-L68)
