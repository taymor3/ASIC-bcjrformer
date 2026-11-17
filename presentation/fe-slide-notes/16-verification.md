# 16 · Ten trained frames matched the integer reference

[Open slide](../BCJRFormer-FE.html#verification) · [All slide notes](README.md)

Present exact compatibility with fixed-point Python as the measured result. The ten frames used one read and no padding. Treat the small-design physical checkpoint as a separate milestone.

## What to point out

- Frame 00 matched in Windows CXXRTL and lab Xcelium. Lab VCS matched frames 01–09. Reported completion was cycle 1,533,280,239 with rounding status and no saturation.
- The trained fixture used (F, M, N, D, H, K) = (27, 1, 144, 96, 8, 6) and 687,991 parameter words. The ten frames were unpadded and single-read.
- Fixed-point Python and saved PyTorch bit decisions matched at 1,431 of 1,440 positions. Trained multi-read and padded coverage remain open.
- The lab mapped the small (2, 2, 2, 2, 1, 2) practice design and saved an initial floorplan. Trained-design synthesis, SRAM selection and physical sign-off remain open.

## RTL references

- [Simulation harness and parameterized DUT boundary · `core_sim_top.sv:2–31`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/tests/core_sim_top.sv#L2-L31)
- [Parameterized production top and memory depths · `bcjrformer_core.sv:3–19`](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/rtl/bcjrformer_core.sv#L3-L19)
- [Trained-frame evidence](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/docs/evidence/trained-frame-validation-2026-11-06.md)
- [Lab progress through 14 Nov](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/RTL_SIM_TO_NOW.md)
- [Verification guide](https://github.com/taymor3/ASIC-bcjrformer/blob/376ec2af8d1232fbff8adbad2ba909691f0ee148/docs/verification.md)
