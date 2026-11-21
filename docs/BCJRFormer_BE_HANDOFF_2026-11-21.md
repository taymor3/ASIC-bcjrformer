# BCJRFormer backend handoff

- Updated on 21 November 2026 from the lab outputs supplied in this chat.
- This file summarizes the backend work and gives the next chat enough context to continue.
- Lab commands below run on the remote Linux machine. They do not run in local Windows PowerShell.
- The routed small design passed the 300 ns slow-corner setup check. After the slew ECO, both slow setup and fast hold passed at 300 ns, all reported setup DRVs cleared, and Innovus physical checks passed.

## Start here in the next chat

- We have a routed, diode-repaired, filler-filled small BCJRFormer core saved in Innovus.
- The clock tree exists. Signal routing exists. The earlier physical checks passed.
- Corrected slow-corner setup timing FAILED at 200 ns with WNS −67.570 ns, TNS about −29,915.4 ns, 478 violating paths, and four transition violations.
- We chose to test a slower 300 ns clock for this lab build. The user prefers completing the lab flow over redesigning the arithmetic now.
- Latest confirmed live state on 21 November is a 300 ns clock with propagation enabled.
- Innovus completed the 300 ns post-route setup analysis in `trial_view` and wrote to `reports-postroute-slow-300ns`.
- The supplied final summary shows WNS +27.961 ns, TNS 0.000 ns, and zero violating paths out of 8,836. Four max-transition violations remain, with worst violation −0.195 in report units. Other listed DRV categories show zero violations.
- The live slow-corner reports confirmed a propagated 300 ns clock, the max library at 1.65 V and 125 C, and unity post-route clock RC scales.
- The hold summary in `reports-postroute-fast-hold-300ns` shows WNS +0.141 ns overall and +0.195 ns reg-to-reg, TNS 0.000 ns, and zero violations out of 8,836 paths. Wall time was 289 seconds. The follow-up live reports confirmed a propagated 300 ns clock, the min library at 2.017 V and −40 C, and unity post-route clock RC scales. The hold-run extraction warnings remain to be reviewed.
- Final foundry-deck DRC/LVS, any required metal fill, and the full trained model's backend implementation remain pending.

## Where everything is

- The relevant tmux session is `bcjr-fillers`.
- Attach from a Linux shell with the following command.

```sh
tmux attach -t bcjr-fillers
```

- Lab project root is `LAB_PROJECT_ROOT`.
- Design Compiler work directory is the `design_syn` subdirectory.
- Innovus work directory is the `innovus_bcjr_small` subdirectory.
- The repository's `RTL_SIM_TO_NOW.md` is an earlier walkthrough. Use this handoff for the latest backend state.
- This handoff was created locally. No commit or push was performed as part of creating it.

## The design we are actually laying out

- The backend run uses a small practice configuration of the same BCJRFormer RTL.
- The wrapper sets `F=2, M=2, N=2, D=2, H=1, K=2` and `MEMORY_DELAY=2`.
- `F` is input features per token, `M` is read slots, `N` is positions per read, `D` is embedding width, `H` is attention heads, and `K` is encoder layers.
- The full trained configuration used for functional simulation was `F=27, M=1, N=144, D=96, H=8, K=6`.
- Backend area, timing, and physical verification numbers in this file belong to the SMALL configuration.
- No trained weight image was loaded during synthesis or place-and-route.
- Weights enter through the host parameter ports and are stored in writable parameter memory during operation.
- The host can load a complete replacement weight image while the core is idle, then assert `parameter_commit`.
- Model dimensions are fixed when the RTL is elaborated. Replacement weights must fit those dimensions.
- The lab instructor advised using synthesizable memory. We kept the RTL memory arrays mapped through the standard-cell flow.
- No SRAM macro was instantiated. `memory_typ.db` was not used. Design Compiler reported zero macros.

## Functional simulation baseline before backend work

- Ten frames of the full trained configuration passed exact integer output comparison against the fixed-point Python reference.
- Frame 00 passed in Cadence Xcelium. Frames 01–09 passed in Synopsys VCS.
- Each frame produced 144 logits. All 1,440 RTL output words matched the fixed-point reference.
- The reported cycle count was `1533280239` per frame, with status `0001` recording rounding.
- A separate fixed-point versus floating-point decoded-bit comparison had nine differences near zero. These were separate from the exact RTL comparison.
- The SystemVerilog testbench was `testbench/trained_frame_tb.sv` in the lab handoff.
- Functional simulation of the full configuration does not establish gate-level equivalence of this small mapped layout. Mapped-netlist equivalence remains a separate task.

## Tools used

- Synthesis used Synopsys Design Compiler 2022.12 through `dc_shell`.
- Physical implementation used Cadence Innovus `23.33-s082_1`.
- Cadence PVS is installed at `/eda/cadence/2024-25/RHELx86/PVS_24.10.000/bin/pvs`.
- Quantus is installed at `/eda/cadence/2024-25/RHELx86/DDIEXPORT_23.33.000/bin/quantus`.
- `calibre` was not found in the user's lab shell.
- PVS/Quantus availability alone does not show that final sign-off decks have been configured or run.

## Synthesis work and fixes

- The initial lab setup referenced `/tools/kits/tower2`, which the account could not access.
- The account belongs to `tower-1`. The accessible kit tree is `/tools/kits/tower`.
- We linked the Tower FS120 typical standard-cell database from the following directory.

```text
/tools/kits/tower/PDK_TS18SL/FS120_STD_Cells_0_18um_2005_12/DW_TOWER_tsl18fs120/2005.12/synopsys/2004.12/models/
```

- The synthesis database was `tsl18fs120_typ.db`.
- Two local compatibility patches addressed default-argument and typed-array-parameter issues in Design Compiler.
- Their local filenames are `bcjrformer-dc-default-argument.patch` and `bcjrformer-dc-typed-array-parameters.patch`.
- We used `bcjrformer_dc_top.sv` as a host-only synthesis wrapper after the simulation wrapper caused elaboration trouble.
- The first mapped synthesis run at 20 ns had worst setup slack −145.64 ns and total cell area 1,174,109.50 in the report's library units.
- LayerNorm and GELU were major area contributors in that run.
- Incremental mapping at 200 ns reported setup slack +0.05 ns, hold slack +0.32 ns, and total cell area 1,052,431.25 in library units.
- The mapped exports are `design_syn/bcjr-small-200ns-mapped.v` and `design_syn/bcjr-small-200ns.sdc`.
- These synthesis results preceded the later slow-corner analysis.

## Innovus import and initial floorplan

- The technology is Tower 180 nm with six routing metal layers.
- Initial import with a five-metal LEF reported a missing manufacturing grid.
- We moved the practice flow to `tsl18_6lm_tech.lef`, which includes the manufacturing-grid declaration, and used the matching FS120 cell LEF.
- Innovus could not resolve some Synopsys-exported packed status field names in the SDC.
- We created `bcjr-small-innovus.sdc` with a 200 ns clock and 1 ns input/output delays applied through port collections.
- The design name is `bcjrformer_dc_top`.
- Initial imported instance count was 730,967.
- The core box was `{20.16 20.16 5162.08 5155.36}` in microns.
- Core dimensions are about 5.142 mm by 5.135 mm, with 917 placement rows and approximately 50% initial utilization.
- Import and floorplan checkpoints were saved as `bcjr-small-6lm-import.enc` and `bcjr-small-6lm-floorplan.enc`.

## Placement, power, and signal pins

- Practice placement used `placeDesign -noPrePlaceOpt`.
- `checkPlace` reported 730,967 placed cells and zero unplaced cells at about 49.99% density.
- We created physical VDD and VSS nets and verified their power/ground types.
- Applied global-net rules connecting VDD and VSS to the standard-cell power pins.
- Built VDD/VSS rings with horizontal M3 and vertical M4 segments.
- Trial ring dimensions were 4 micron width, 2 micron spacing, and 2 micron offset.
- The ring command created eight wires and eight vias, with four ring segments per supply net.
- These ring dimensions were practice geometry. No completed IR-drop or electromigration analysis has been established.
- Special routing connected cell-row rails to the rings using M1 through M4.
- The initial power routing created 2,754 wires and 5,508 vias.
- Initial supply connectivity and geometry checks passed.
- Placed all 142 top-level signal pins and confirmed their status was fixed.
- West edge has 54 weight-loading interface pins on M3.
- South edge has 25 frame, feature, and mask interface pins on M4.
- East edge has 61 result, completion, busy, and status pins on M3.
- North edge has clock and reset on M4.
- The pin plan uses 10 micron spacing and groups each interface together.
- These are core boundary pins. A package I/O pad ring has not been added.

## Pre-CTS and clock tree work

- Initial pre-CTS analysis at 200 ns showed WNS −19.942 ns and 386 setup violations.
- Ran `optDesign -preCTS` inside tmux.
- Final pre-CTS timing showed WNS −0.402 ns, TNS −37.654 ns, and 338 setup violations.
- Capacitance and transition violations fell to zero.
- Intermediate optimizer messages saying timing was met did not match the later final analysis. We used the final timing tables as evidence.
- `create_ccopt_clock_tree_spec` found 8,801 clock sinks and zero clock gates.
- `ccopt_design -cts` failed with `IMPCCOPT-2440` because the placement database was PODv2.
- The matching command `clock_opt_design -cts` completed the CTS flow.
- Initial post-CTS setup showed WNS −0.853 ns and 380 violating paths.
- Initial post-CTS hold showed WNS +0.307 ns and zero violating paths.
- A host sent an external TERM signal to an earlier Innovus process. The saved CTS checkpoint survived. The log did not identify who sent the signal.
- Restored the CTS checkpoint and ran `optDesign -postCTS`.
- That optimization took about 43 minutes.
- Its final checked setup result was WNS −0.037 ns, TNS −0.078 ns, and ten violating paths.
- Hold remained +0.307 ns with zero violations.
- These earlier timing results used settings later found to need correction, particularly clock propagation and clock RC scaling.

## Routing and antenna repair

- Ran `routeDesign -globalDetail` to route signals.
- The first complete routing pass took about 1 hour 9 minutes.
- Saved `bcjr-small-6lm-routed-trial.enc`.
- The first routed antenna check reported 94 violations across 54 nets.
- Geometry checks passed separately.
- The installed antenna checker is `verify_antenna`. `verifyProcessAntenna` is unavailable in this version.
- Its report command was `verify_antenna -use all -limit 10000 -report <filename>`.
- Router diode insertion was initially false and no antenna cell was configured.
- The loaded cell library contains `adiode`.
- Enabled the following routing settings, then reran global/detail routing.

```tcl
setNanoRouteMode -route_detail_fix_antenna true
setNanoRouteMode -route_antenna_diode_insertion true
setNanoRouteMode -route_antenna_cell_name adiode
```

- That reduced the result to three antenna violations across two nets in LayerNorm.
- Remaining net `dut/norm_engine/div_25_C39/u_div/PartRem[19][10]` affected two inverter input pins.
- Remaining net `dut/norm_engine/n9593` affected one inverter input pin.
- Added one diode at each of the following pins.

```tcl
attachDiode -diodeCell adiode -prefix ANT_MANUAL -pin {dut/norm_engine/div_25_C39/u_div/u_add_PartRem_18_7/U407 I}
attachDiode -diodeCell adiode -prefix ANT_MANUAL -pin {dut/norm_engine/div_25_C39/u_div/u_add_PartRem_18_5/U399 I}
attachDiode -diodeCell adiode -prefix ANT_MANUAL -pin {dut/norm_engine/U13713 I}
```

- Ran `refinePlace`, `applyGlobalNets`, and `ecoRoute`.
- Saved `bcjr-small-6lm-manual-diodes-trial.enc`.
- `bcjr-small-manual-diodes-antenna.rpt` reported no antenna violations.
- `bcjr-small-manual-diodes-drc.rpt` reported no DRC violations.
- Regular and VDD/VSS connectivity checks also passed.

## Extraction setup and timing corrections

- The accessible lab setup directory is `/users/iit/cadence/tsl018b/`.
- `/users/iit/cadence/tsl018b_2/` returned permission denied.
- The accessible setup includes `mmmc.view`, `env.globals`, `fill.src`, `gds2_6lm.map`, CDL files, and I/O support files.
- The lab capacitance table is `/tools/kits/tower/PDK_TS18SL/iit/TSL_0.18_6M1L.CapTbl`.
- The lab Quantus technology file is `/tools/kits/tower/PDK_TS18SL/iit/qrcTechFile`.
- Set the process explicitly using `setDesignMode -process 180` after earlier reports displayed 90 nm and warned that the process was unset.
- Attached the lab extraction files to the practice corner.
- The imported captable has an extra M7 entry ignored by the six-layer LEF.
- Some reported via resistance values came from LEF or fallback values. These warnings still need assessing against the approved lab setup.
- Attaching a Quantus file does not prove the high-accuracy Quantus engine was used. Actual timing logs showed postRoute extraction at effort level low using the lab capacitance/RC tables.
- Innovus requires `setAnalysisMode -analysisType onChipVariation -cppr both` for this post-route timing flow.
- With the earlier typical-corner settings, post-route setup/hold passed. Those values are historical trial results.
- Later `report_analysis_views` showed post-route clock resistance and capacitance scale factors of zero.
- Later `report_clocks` showed clock propagation disabled.
- Explicitly enabled clock propagation and used clock RC scale factors of one in the new slow corner.
- These corrections are essential context for the later timing failure. Earlier typical passes do not establish final timing closure.
- Signal-integrity analysis also issued `IMPESI-3477` warnings about large RC constants and stripped mode. These remain review items.
- Extraction messages saying `Checking LVS Completed` are internal extraction checks. A separate foundry-deck LVS run has not been demonstrated.

## Filler insertion

- The lab filler script is `/users/iit/cadence/tsl018b/fill.src`.
- It inserts `feedth9`, `feedth3`, and `feedth` in three passes.
- The first attempt was interrupted with Ctrl+C. Innovus warned that the interrupted state should not be used to continue the flow.
- We restarted in a fresh headless Innovus process and restored the saved layout before repeating insertion.
- The successful run added 351,074 `feedth9`, 188,380 `feedth3`, and 765,076 `feedth` instances.
- Total inserted fillers were 1,304,530.
- The post-filler database reported 2,017,787 instances.
- Innovus recommended `ecoRoute -target` after inserting fillers into a routed database.
- Ran the cleanup and repeated placement, geometry, antenna, and connectivity checks.
- User confirmed no geometry or antenna violations. Regular and VDD/VSS connectivity summaries each showed zero violations and warnings.
- Saved filler checkpoints include `bcjr-small-6lm-fillers-checked-trial.enc` and `bcjr-small-6lm-fillers-timing-checked-trial.enc`.
- The latter checkpoint was successfully restored during timing recovery, confirming that it exists.
- Historical typical-corner timing after fillers was setup +1.330 ns and hold +1.362 ns, both with zero violating paths. The clock-setting corrections above still apply to interpreting those results.
- Density was 46.675% for functional cells and 100% including fillers. The filler-inclusive density is placement occupancy, not a metal-density sign-off result.
- Antenna checking after fillers consumed substantial memory. At one point Innovus used about 57.8 GiB of resident RAM on a 62 GiB host while continuing to use CPU.
- The checks eventually completed. Avoid launching extra large jobs on that host while verification is memory-heavy.

## Slow-corner setup and the 300 ns decision

- We kept the existing analysis view and changed its delay corner sequentially to preserve its constraint-mode association and saved latency-file association.
- Active analysis view is still named `trial_view` even when it points to slow libraries.
- Constraint mode is `functional`.
- Slow library set is `bcjr_slow_lib`.
- Its timing file is `tsl18fs120_max.lib` in the FS120 models directory listed above.
- Operating condition is `bcjr_slow_op`, with P=1.0, V=1.65, and T=125.
- Operating-condition library name is `tsl18fs120_max`.
- RC corner is `bcjr_slow_rc`, with the lab captable and Quantus file, temperature 125, and post-route clock resistance/capacitance factors of one.
- Delay corner is `trial_delay`.
- Applied clock propagation with the following commands.

```tcl
set_interactive_constraint_modes {functional}
set_propagated_clock [all_clocks]
```

- The 200 ns slow-corner run showed WNS −67.570 ns, TNS about −29,915.4 ns, 478 violating paths, and four max-transition violations with worst violation −0.195 in the report's units.
- Its report directory is `reports-postroute-slow`.
- The worst supplied path starts at `dut/norm_engine/variance_q_reg[16]/Q` and ends at `dut/root_service/response/result_q_reg[18]/D`.
- Required arrival time was 201.669 ns. Actual arrival was 269.239 ns.
- The path traverses reciprocal-square-root division, square-root-related arithmetic, and rounding logic.
- Local `rtl/arithmetic/rsqrt_unit.sv` implements those calculations in `always_comb`, including division and a 48-step root search. This explains a long combinational path, although a full gate-delay breakdown was not completed.
- We discussed sequential arithmetic as a future architectural improvement. The user chose to finish the current lab build by testing a slower clock.
- A 300 ns period is approximately 3.33 MHz. It is a revised performance target, not evidence of achieving 200 ns.
- Latest verified live `report_clocks` output shows 300 ns, waveform `{0 150}`, and propagated `y`.
- The 300 ns run completed in 320 seconds and reported to `reports-postroute-slow-300ns`.
- Setup passed at 300 ns in the supplied summary. Four max-transition violations remain in the slow setup report.

## Slow-corner max-transition violations

The saved 300 ns slow setup report lists four real violations. All are rising transitions against a 3.000 ns limit.

| Driver pin | Cell | Rise slew (ns) | Rise slack (ns) |
| --- | --- | ---: | ---: |
| dut/dot_switch/router/U10/ZN | nr02d1 | 3.195 | −0.195 |
| dut/root_service/mult_16_2/U4870/ZN | inv0d0 | 3.017 | −0.017 |
| dut/residual_stage/U72/ZN | inv0d0 | 3.006 | −0.006 |
| dut/activation_service/rem_15_S3_C24/u_div/u_add_PartRem_35_6/U516/ZN | inv0d0 | 3.001 | −0.001 |


## Slew ECO results

- Upsized one NOR and three inverters. Removed 340 local fillers and cleared all eight placement overlaps. ECO routing completed with zero router-reported DRC and antenna violations.
- After refill, the 300 ns slow-corner setup report in reports-slew-eco-slow-300ns passed with WNS +27.961 ns, TNS 0.000 ns, and zero failing paths out of 8,836. All listed DRV counts were zero, including max-transition. The run took 343 seconds.
- Post-refill Innovus geometry and antenna checks found zero violations. Regular and special connectivity checks found no problems or warnings. The post-refill placement check gated the verification batch; the standalone placement summary was not supplied. Foundry DRC/LVS remains pending.
- The saved post-ECO fast hold report in reports-slew-eco-fast-hold-300ns shows WNS +0.141 ns overall and +0.195 ns reg-to-reg, TNS 0.000 ns, and zero failing paths out of 8,836.


## Saved databases and restoration

- Innovus `saveDesign name.enc` creates a small restore script and a companion `name.enc.dat` database directory.
- For `restoreDesign`, use the `.enc.dat` DIRECTORY and the top name.
- Example restoration in a fresh Innovus process is the following.

```tcl
restoreDesign bcjr-small-6lm-fillers-timing-checked-trial.enc.dat bcjrformer_dc_top
```

- Calling `restoreDesign` repeatedly in the same process triggered `IMPIMEX-7031`. We used a fresh process instead of disabling the safeguard.
- Confirmed or successfully used checkpoints during this chat include the import, floorplan, placement, supply-connected, ring, power-routed, signal-pin, CTS, manual-diode, and filler timing checkpoints.
- `bcjr-small-6lm-slow-propagated-trial.enc` and `bcjr-small-6lm-slow-300ns-trial.enc` were requested as later saves. Their existence should be checked before relying on them for recovery.
- Check available checkpoint pairs from the Innovus working directory with the following command.

```tcl
puts [join [lsort [glob -nocomplain *.enc *.enc.dat]] "\n"]
```

- After any restore, inspect `report_clocks` and `report_analysis_views`. Old checkpoints can restore the typical library, zero clock RC factors, or an ideal clock.
- Preserve earlier checkpoints and save future stages with new descriptive names.

## Remote working lessons

- Use tmux for long jobs and headless Innovus so an X11 disconnect does not terminate the tool.
- Start a headless process from the Innovus working directory using the following pattern.

```sh
env -u DISPLAY innovus -nowin -log bcjr-resume.log
```

- Detach with Ctrl+B, release both keys, then lowercase d.
- Uppercase D opened tmux's client-selection screen. Esc returned from that screen.
- A tmux session exists only on the host where it was created. Check `hostname -s` before assuming a session was lost.
- Ctrl+C twice can terminate Innovus. For long analysis, allow completion or inspect CPU/log activity from a separate terminal.
- The lab shell is normally tcsh. We used Bash when a script specifically required Bash syntax.
- MobaXterm MultiExec may broadcast pasted commands to multiple terminals. Disable it when issuing tool-specific commands.
- At `innovus>` the command language is Tcl. Use braces to protect regular expressions and bus-index names where appropriate.
- A grep regex containing `[[:space:]]` inside Tcl double quotes caused substitution errors. Bracing the regex fixed that issue.

## Waveform work still open

- The user also wants to see RTL waveforms in SimVision.
- The initial `xrun -R -gui` reused a snapshot whose signals displayed No Read Access.
- Read access must be enabled during elaboration for waveform capture.
- The original lab history showed a build using `-f testbench/files.f`, top `trained_frame_tb`, and the `vectors` directory.
- We supplied this rebuild command from the lab simulation root in a terminal with working VNC/X11.

```sh
xrun -64bit -sv -f testbench/files.f -top trained_frame_tb +vectors=./vectors -access +r -gui -l xrun-wave-preview.log
```

- After loading, the suggested simulator-console commands record a short preview.

```tcl
database -open rtl_preview -shm -default
probe -create -shm [scope -tops] -all -depth 1
run 100 us
```

- Then select `trained_frame_tb` and send clock, reset, and parameter-loading signals to the waveform viewer.
- A 100 us initial interval would show startup and weight loading. Output logits occur much later.
- Successful waveform capture and display have not yet been confirmed.

## Remaining work and decisions

- Collect the final post-ECO fast hold and post-refill placement summaries. The post-ECO slow setup report shows all four max-transition violations cleared.
- Review extraction warnings from the hold run log.
- The lab's fast operating condition uses `tsl18fs120_min.lib`, P=1.0, V=2.017, and T=−40. The follow-up live report confirmed these settings in trial_view using bcjr_fast_rc at −40 C.
- Consider both setup and hold at additional corners if required by the lab's sign-off methodology. A slow setup and fast hold pair alone is not an exhaustive PVT sign-off claim.
- Review clock source-latency handling, extraction warnings, and signal-integrity warnings before treating any timing results as final.
- Use the lab's approved PVS DRC/LVS flow. Deck paths, run scripts, and successful final results have not been established.
- Decide whether the deliverable is a core block or a complete chip with I/O pads. No pad ring has been added.
- Determine and run required metal-density fill and related checks.
- Export the final matching layout and circuit netlist using the lab's approved mapping and cell views. `gds2_6lm.map` exists in the accessible setup directory but has not been used for a verified final export.
- Establish mapped/post-layout equivalence as required.
- The full trained configuration still needs its own backend implementation and measurements.
- Future optimization ideas discussed include identifying cycle bottlenecks, arithmetic sharing versus parallelism, precision, reloadable weights, and measured area/power/frame-time trade-offs.
- The user wants those improvements supported by measurements and prefers clear, simple explanations.
- Technology files and licensed library contents stay on the lab system. The advisor knows AI is being used. This handoff records setup paths and user-supplied results without copying the PDK files.
