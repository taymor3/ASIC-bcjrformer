# BCJRFormer ASIC — 10-slide presentation notes

Source: origin/main `be3fd35a9b1ef648ace40b407a9497167be37411`, fetched 22 November 2026.

## 1 · BCJRFormer ASIC: the complete front end

Present the project as a hardware implementation of BCJRFormer inference. The architecture is the model dataflow; the microarchitecture is the controller, shared-compute and memory organization; the front end is the SystemVerilog design and its verification. Input window construction and any downstream outer decoder are external. The core publishes logits without sigmoid. Authors: Taimor Sabek and Haiel Bader.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/README.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md

## 2 · Five stages execute in sequence

Define L=M×N, with M read slots and N positions. Stage 1 normalizes F input features, projects to width D, then normalizes the embedding. Stage 2 adds learned position and read information. Stage 3 iterates K encoder layers and H attention heads. Stage 4 maps D to one logit per token. Stage 5 averages valid reads at each position. These are sequential phases, not five simultaneously executing pipeline stages. D must be divisible by H. The parameterized dimensions do not imply a fixed selected target.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/microarchitecture.md

## 3 · Controllers, compute and memory form the core

The complete assembly is bcjrformer_core. The command hierarchy is core_ctrl to stage controllers, then encoder/layer/attention/FFN controllers. Shared compute includes LayerNorm, linear and dot controllers, plus MAC, EXP, reciprocal, RSQRT and GELU arithmetic. Some controllers call arithmetic directly; this grouped view avoids implying all arithmetic passes through linear or dot. The memory fabric connects controller/compute clients and the host loader to parameter and scratch memories. Banks are grouped for readability. Behavioral arrays await target-specific memory mapping.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/microarchitecture.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/bcjrformer_core.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/interfaces/bcjrformer_contract_pkg.sv

## 4 · Embedding prepares tokens for the encoder

The input is already windowed. embedding_ctrl calls LayerNorm over F features, linear F-to-D, then LayerNorm over D embedded values. position_ctrl adds learned P[n] and E[m]. Each addition retains its documented fixed-point conversion point. The tensor entering the encoder contains L tokens of width D. Shared LayerNorm and linear hardware are used rather than replicated per token.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/embedding_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/position_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md

## 5 · One encoder layer is reused K times

Show X entering LN1 and also bypassing it to the first residual adder. Attention mixing is followed by its output projection. The result U enters LN2 and bypasses the FFN to the second residual adder. FFN is linear D-to-4D, GELU and linear 4D-to-D. The diagram depicts one logical layer; controller loops repeat it K times using shared physical services. The FFN hidden store retains GELU results at signed32/F22.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/layer_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/ffn_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md

## 6 · Attention mixes tokens one query row at a time

Q, K and V are projected first. For each head and query row, calculate Q·K/sqrt(d), where d=D/H. The softmax subtracts the maximum, evaluates Taylor EXP, sums and applies reciprocal normalization. Multiply probabilities by V, concatenate head results, then use the output projection. This is query padding rather than key masking: valid queries include padded keys. Static attention masks are unsupported in this baseline.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/attention_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/softmax_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md

## 7 · Shared services turn the model into hardware

Command switches have two LayerNorm caller groups, five linear groups and three dot groups. Owners remain locked through their response so results return to the correct caller. Linear uses dot, which reads operands and requests MAC accumulation. LayerNorm uses RSQRT. Softmax uses EXP and reciprocal; aggregation also uses reciprocal; FFN uses GELU. GELU uses Taylor arithmetic and its signed32/F22 results are stored unchanged and consumed with a signed32 × signed16 MAC and signed64/F32 accumulation. Numerical formats remain provisional.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/microarchitecture.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/numerics.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/rtl/RTL-ROUNDING-MAP.md

## 8 · Projection and aggregation produce N outputs

Stage 4 applies a learned D-to-1 projection independently to each of L=M×N tokens. Stage 5 iterates positions n and read slots m. The validity bit gates both the sum and count. The conceptual formula is y[n]=sum_m(v[m,n]·logit[m,n])/sum_m(v[m,n]), implemented through a reciprocal service and fixed-point conversion. Mask=1 means padded/skip in RTL. A position with zero valid reads returns recoverable EMPTY_POSITION, retaining committed parameters. No host logits are published from an unsuccessful frame, even if earlier scratch outputs were written. No sigmoid is included. This is a conceptual algorithm example, not a bit-accurate rounding example.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/final_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/aggregation_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/architecture.md

## 9 · core_ctrl separates commands from completion

Host loading, frame execution and result publication are separate phases. Each parameter write must be acknowledged before parameter_commit. core_ctrl then accepts features/mask and issues stage commands one at a time. A successful completion response means the stage destination writes committed. Aggregation failure suppresses output publication. The core holds indexed logit data, index and last flag through backpressure, then holds the completion report. EMPTY_POSITION is recoverable; fatal errors require reset. Synchronous active-high reset invalidates the parameter image and requires reload/commit.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/control/core_ctrl.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/rtl/interfaces/bcjrformer_channels.sv
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/rtl/RTL-PROTOCOL-CHECKPOINT.md

## 10 · Trained RTL matches the integer reference

Measured results from latest main, not a new simulation. The trained dimensions (F,M,N,D,H,K)=(27,1,144,96,8,6), with 687,991 parameter words. Frame 00 matched fixed-point Python in CXXRTL and Xcelium; frames 01–09 matched VCS. Completion cycle was 1,533,280,239, with rounding recorded and no saturation reported. Fixed-point Python vs saved PyTorch bit decisions agreed at 1,431/1,440 positions; this is distinct from exact RTL/integer-reference agreement. The small practice design (2,2,2,2,1,2) was mapped and initially floorplanned. No trained-design area, frequency, throughput or physical sign-off is established by this result.

- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/RTL_SIM_TO_NOW.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/presentation/fe-slide-notes/16-verification.md
- https://github.com/taymor3/ASIC-bcjrformer/blob/be3fd35a9b1ef648ace40b407a9497167be37411/docs/evidence/trained-frame-validation-2026-11-06.md