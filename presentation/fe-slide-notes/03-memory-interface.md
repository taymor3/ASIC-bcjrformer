# 03 · One shared memory transaction interface

[Open slide](../BCJRFormer-FE.html#memory-interface) · [All slide notes](README.md)

A read or write transfers on req_valid && req_ready. The requester holds the request until that edge. The fabric captures the owner and request, checks the address, format and permissions, then routes by bank. A read returns data; a write returns an acknowledgment after commit. The response remains associated with the captured owner until rsp_valid && rsp_ready.

## What to point out

- Both channels transfer on valid && ready. A read returns a word. A write responds after commit.
- The fabric holds one outstanding request across 13 clients and returns the response to the captured owner.

## RTL references

- [Memory channel and requester/responder directions · `bcjrformer_channels.sv:17–27`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/interfaces/bcjrformer_channels.sv#L17-L27)
- [Bank encoding, format tag and packed request · `bcjrformer_contract_pkg.sv:46–65`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/interfaces/bcjrformer_contract_pkg.sv#L46-L65)
- [PARAM versus scratch routing and errors · `memory_fabric.sv:68–93`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/protocol/memory_fabric.sv#L68-L93)
- [Request and response ownership across stalls · `transaction_router.sv:22–78`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/protocol/transaction_router.sv#L22-L78)
- [Capture, wait, commit/read and hold response · `memory_adapter.sv:75–90`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/memory/memory_adapter.sv#L75-L90)
