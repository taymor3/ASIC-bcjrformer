# First lab simulation: saturating addition

Start with `position_add_unit`, the simplest arithmetic block. It accepts two
signed16/F10 numbers and returns a clipped signed16/F10 sum, an echoed tag and
status through ready/valid. `arithmetic_register` is a smaller non-arithmetic
helper; it is included here to exercise a real computation and its registered
interface. No model parameters, CSV files, memories or Tower libraries are needed.

```text
testbench: two values + tag --> position_add_unit --> sum + tag + status
               clock/reset and ready/valid surround the transaction
```

Input real value is `raw / 1024`. Examples:

| Inputs (raw) | Expected sum (raw) | Meaning |
|---|---:|---|
| 1024, 2048 | 3072 | 1.0 + 2.0 = 3.0 |
| -1024, 256 | -768 | -1.0 + 0.25 = -0.75 |
| 32767, 1 | 32767 | Positive clipping; saturated=1 |
| -32768, -1 | -32768 | Negative clipping; saturated=1 |

`tb_position_add.sv` checks nine additions (including post-reset reuse), signed
boundaries, exact status/tag/error, held responses during stalls and reset of a
pending response. The expected values are explicit hand calculations; the bench
does not use the DUT's conversion function as its oracle. A watchdog catches hangs.

## Run in the lab

After the admin's Synopsys environment initialization, from the repository root:

```bash
bash rtl/tests/sim/run_position_add_vcs.sh
```

The script analyzes the six sources in `position_add.f`, elaborates
`tb_position_add` (the testbench is the simulation top), then runs `simv`.
Generated files and `analyze.log`, `elaborate.log`, `simulate.log` stay under
`tmp/vcs-position-add/`. The default run is batch mode and finishes automatically.
Expected final message:

```text
PASS tb_position_add: 9 additions, stalls, flags, tags and reset checked
```

To confirm that the checker detects a wrong expected result:

```bash
bash rtl/tests/sim/run_position_add_vcs.sh +INJECT_MISMATCH
```

This run **must fail** at the first addition. It deliberately changes a golden
value in memory; it does not modify RTL or vector files. Record this failure as
a successful checker test, not a passing arithmetic run. Run normally afterward.

Optional VCD recording and the guide's GUI flow:

```bash
bash rtl/tests/sim/run_position_add_vcs.sh +WAVES
cd tmp/vcs-position-add
./simv -gui
```

The GUI is an optional separate run; select signals and start execution there.
The VCD from the batch run is `position_add.vcd`. For first inspection choose
`clk`, `rst`, and the `operation` request/response signals. The 10 ns testbench
clock is a stimulus choice, not a claimed hardware frequency.

The commands target the supplied VCS guide's analyze/elaborate/run flow; exact
installed version, environment and licenses still require a lab run. Local
syntax/elaboration checks are not a VCS simulation PASS. If a command fails,
retain its log and report the first error before changing production RTL.
