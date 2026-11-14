# BCJRFormer from RTL simulation to floorplan

Project status as of 14 November 2026. This is our step-by-step record of what we did, what went wrong, and how we got past it.

## 1. Start with the research and the working software

The BCJRFormer research tackles noisy reads. If a bit is inserted or deleted, the rest of the read can shift out of alignment. The software converts the read into windows of numbers, then the trained model uses those windows to estimate the transmitted bits.

We used the existing PyTorch model to understand the order of operations and the shapes of its inputs and weights. Our SystemVerilog design, also called RTL, starts with the windowed numbers and a padding mask. It produces a score called a logit for each encoded position. We built the decoder in five stages. These prepare the inputs, add position and read information, run the Transformer, produce the logits, and combine valid reads. [ASIC architecture](docs/architecture.md)

## 2. Set up the project and check the RTL

We cloned the ASIC repository and installed its pinned Python dependencies in a local virtual environment. The first install attempt ran into a Windows temporary-folder permission error. We retried with permission to run the installation and then checked the installed packages.

The smoke tests passed. They checked that the small versions of the design could be built, that the named connections were present, and that weights could be packed and read back. That gave us a starting point for testing a real trained model. [Verification guide](docs/verification.md)

## 3. Prepare real weights and input frames

We found a trained checkpoint and a saved software export on the laptop. The export already contained ten windowed input frames, the trained parameters, and the original PyTorch outputs. Each frame had one read, 144 positions, and 27 features per position. The model had width 96, eight attention heads, and six layers. The ten frames had no padded positions.

**What we had to fix.** PyTorch stores decimal values, and the RTL expects signed 16-bit integers with an agreed scale. It also expects each weight at a particular address.

A local Python converter matched the names of the 106 saved tensors to the hardware's parameter list. It took each value, multiplied it by 1024, rounded it to the nearest integer with ties going to even, and clamped it to the signed 16-bit range if needed. It did the same for the input features. The manifest script then wrote **687,991 parameter words** to `parameters.hex` in address order. For example, the first parameter became integer `1014`, written as `03f6` in hex at address 0. [Parameter manifest script](rtl/scripts/parameter_manifest.py) · [Fixed-point formats](docs/numerics.md)

## 4. Make the answer key in Python

We ran the existing fixed-point Python reference using the converted weights, features, and mask. It performs its own calculations using the hardware's integer widths and rounding rules. It produced 144 expected integers per frame. The first expected word for frame 00 was `-680`. Dividing it by 1024 gives `-0.6640625`.

The original PyTorch outputs gave us a separate comparison. Across the ten frames, fixed-point Python and PyTorch agreed on **1,431 of 1,440 decoded bits**. At the other nine positions, the PyTorch score was slightly negative while the fixed-point score was slightly positive. The bit decision changes at zero. These nine differences describe the effect of using fixed-point arithmetic. The hardware had its own exact integer comparison against the Python answer key. [Fixed-point Python reference](rtl/tests/fixed_reference.py)

## 5. Run the first frame on Windows and check the result

Yosys with slang read the SystemVerilog. Its CXXRTL backend converted the design into C++, which we compiled with G++. A C++ driver ran the generated hardware model cycle by cycle. The driver sent the weights and frame through the hardware ports and compared the output words with the Python answers. **Frame 00 matched all 144 words** after about **8 hours and 7 minutes**.

**What we checked afterward.** The Yosys build warned that some signals needed repeated evaluation within a clock step. We had also sped up the generated C++ by reusing the result of 11 division and remainder operations when their inputs stayed the same. We rebuilt the model, regenerated the software answers, and checked the output file again. On a small test, the cached and uncached versions gave the same outputs and finished at the same cycle. Deliberately changing one expected word made the checker report one mismatch and fail. The full-size test in the lab gave us a separate check with a different simulator. [Run report](docs/evidence/trained-frame-validation-2026-11-06.md) · [Windows simulation and audit logs](logs/ASIC-BCJRFormer_RTL_Simulation_and_Audit_Logs_2026-11-06.zip)

## 6. Run the actual SystemVerilog in the lab

We wrote a SystemVerilog testbench named `trained_frame_tb.sv` and prepared a file list for the lab simulator. The existing `core_sim_top.sv` wrapper connects the testbench to the decoder.

1. The testbench starts the clock, resets the RTL, and reads four files. `parameters.hex` holds the weights and biases. `features.txt` holds 3,888 input words. `mask.txt` holds 144 padding bits. `expected.txt` holds 144 answers for the checker.
2. It sends each parameter with its address. It waits for the hardware to accept the request and confirm the write. After the last write, it pulses `parameter_commit` so the hardware can accept a frame.
3. It sends the feature words and the padding mask, waiting for the hardware to be ready for each item.
4. It reads the logits from the RTL output port and checks the position, the value, and the last-output flag. The expected values stay in the checker.
5. It prints `PASS` only when the hardware reports successful completion, all 144 outputs arrived, and every value matched.

**What we encountered on the lab machine.** The standalone testbench was in a local handoff package, so we transferred it and the test vectors to the lab. A later `scp` transfer failed because the client received unexpected text. Sending a Base64 copy through SSH and verifying the SHA-256 checksum transferred the file. The lab shell was `tcsh`, so we used Bash inside `tmux` for the batch loop. The first batch attempt started from the home directory and exited because it could not find `simv`. Changing to the simulation directory fixed that. We used `tmux` to keep the batch running between SSH connections.

**Result.** Frame 00 passed in Cadence Xcelium. Frames 01 through 09 passed in Synopsys VCS. That is **1,440 out of 1,440 exact RTL output matches** against fixed-point Python. Each lab run reported completion at cycle `1533280239` with status `0001`, which indicates rounding. These results cover ten unpadded, single-read frames from the same checkpoint. [Xcelium report and lab excerpt](docs/evidence/trained-frame-validation-2026-11-06.md#independent-xcelium-run-on-8-november-2026) · VCS results from the nine PASS lines supplied from the lab logs.

## 7. Get Design Compiler to read the small design

We followed the course flow with **Synopsys Design Compiler** for synthesis and **Cadence Innovus** for physical layout. Synthesis turns the RTL into a list of gates from the chosen technology library. We started with the small dimensions `(2, 2, 2, 2, 1, 2)` to check the flow.

| What stopped us | How we got past it |
| --- | --- |
| Design Compiler rejected a default argument in a function. | We passed the same value explicitly at the four affected calls. |
| It could not determine the type of arrays passed directly to some modules. | We declared the arrays with explicit types and passed them by name. The values stayed the same. |
| It stopped at the simulation wrapper's scratch-memory probes. | We made a host-only synthesis wrapper named `bcjrformer_dc_top`. The simulation wrapper retained its probes. |
| The course setup pointed to an FS120 library our account could not read under `/tools/kits/tower2`. | We found the corresponding typical-corner library in the readable `/tools/kits/tower` kit, set the target and link libraries, and linked the design successfully. |

The small design reached `check_design`. One warning showed a memory-format bit tied to zero. That bit is zero in both formats selected by that part of the RTL. [Format definitions](rtl/interfaces/bcjrformer_contract_pkg.sv)

## 8. Map the small design to standard cells

Our first compile used a **20 ns trial clock**. It produced a mapped netlist and timing and area reports. The longest reported setup path was inside LayerNorm, from the register holding the input length to the numeric-error flag. The RTL uses the length in calculations with wide division and remainder. LayerNorm and GELU together used about **57.5%** of the mapped cell area in this run.

We saved the 20 ns result and ran an incremental compile at **200 ns**. A clock period is the time a signal has between clock edges. The longer trial gave the logic more time. Positive slack means a timing check has time to spare.

| Small-design result | 20 ns trial | 200 ns trial |
| --- | ---: | ---: |
| Worst setup slack | -145.64 ns | +0.05 ns |
| Worst hold slack | | +0.32 ns |
| Mapped cell area in library units | 1,174,109.50 | 1,052,431.25 |

The 200 ns result met its reported pre-layout timing checks. The check for missing constraints and unconstrained endpoints reported no issues. We used `bcjr-small-200ns-mapped.v` and its timing constraints as the inputs for the practice layout. [LayerNorm RTL](rtl/control/layernorm_ctrl.sv) · Results transcribed from the lab's Design Compiler reports.

## 9. Import the design into Innovus

We found readable Tower FS120 cell drawings and timing data in the kit. A **LEF** tells Innovus the sizes of cells, where their pins are, and how the metal layers are defined. A **Liberty** file provides cell timing data. An **SDC** tells the tool the clock period and the timing limits at the ports.

| What stopped us | How we got past it |
| --- | --- |
| The course's sample Innovus setup was unreadable. | We built an import setup using the kit's files, our netlist, and our constraints. |
| The first technology LEF had no manufacturing grid, which defines where layout geometry can sit. | We used the kit's six-metal technology LEF, which declares a 0.005 µm grid. Six metals is the practice choice. |
| Innovus could not find four status ports under the names used in the Design Compiler SDC. | We made an Innovus SDC that applied the 200 ns clock and 1 ns I/O delays to the port collections Innovus sees. |
| The new SDC paste got stuck at a `?` prompt in `tcsh`. | We canceled the incomplete paste and wrote the five-line file with a single `printf` command. |

After the retry, we confirmed the top module was `bcjrformer_dc_top`, Innovus had loaded **730,967 instances**, and the clock period was **200 ns**. We saved that import. The log still had library and wire-resistance warnings. We need the approved extraction data and timing corners before using post-route results for sign-off.

## 10. Save the initial floorplan

We created and saved an initial floorplan for the **small design**. The floorplan outlines the chip and the area where the cells will go. Innovus created **917 placement rows**. The core measures approximately **5.142 mm by 5.135 mm**, and Innovus reported **49.9974% utilization**. We kept that roughly 50% starting point. The saved checkpoint is `bcjr-small-6lm-floorplan.enc` with its accompanying `.enc.dat` directory.

## What is left before we have a chip

- [x] Run the trained RTL against fixed-point Python in the lab.
- [x] Synthesize the small design and save the initial practice floorplan.
- [ ] Plan the core pins and power connections, then place the small design as a practice run.
- [ ] Agree with the instructor on the trained design's clock, throughput, and SRAM choices. The parameters alone need about 11 megabits of storage.
- [ ] Investigate the LayerNorm timing path and test any arithmetic or memory changes against the saved output words.
- [ ] Synthesize and verify the trained design with the chosen SRAM blocks.
- [ ] Floorplan and place the trained design, build its clock tree, then route the wires.
- [ ] Check timing and physical rules after routing, then prepare the final layout for fabrication and silicon testing.
