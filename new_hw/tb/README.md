# AGU feedback trace

Edit `agu_input_indices.txt`: one unsigned decimal IB index per line.
Each entry is one testbench step; repeated indices are allowed.
Blank lines and `#` comments are ignored.

The testbench starts KSP at zero and feeds its output back after every step.
IB is always supplied by the file. The AGU RTL is used unchanged.
Only the feedback trace is run.

From the `source` directory:

```powershell
./new_hw/tb/run_agu.ps1
```

For a 3x3 kernel, or a different input file:

```powershell
./new_hw/tb/run_agu.ps1 -WeightSize 3 -InputFile ./new_hw/tb/agu_input_indices.txt
```

Defaults: input size 224, stride 4, kernel size 11.
Input size and stride are log metadata only. Kernel size labels the weight
row/column in the trace; these values are not AGU inputs.
The file length determines the number of feedback steps.

The output is written to `DSIP/tmp/new_hw_agu/agu_output.log`.
Each row contains:

- `IB_INDEX`: the manually supplied index.
- `KSP_CURRENT`: the weight address paired with that input.
- `WEIGHT_ROW,COL`: row-major interpretation of that address within one kernel.
- `KSP_NEXT`: the actual AGU output used for the next step.

Addresses outside `0..K*K-1` are marked `OUTSIDE_KERNEL`.
The log displays current RTL behavior; it does not certify a correct convolution schedule.
Run the script again after editing the input file to regenerate the log.

## DSIP core testbench

`dsip_core_tb.sv` instantiates the current core, generates a 10 ns clock and
active-low reset, programs IMEM, then sends one clock-wide start pulse.
`core_imem_instr.txt` contains one 58-bit binary instruction per line, ordered
from bit 57 to bit 0. `//` comments are accepted by `$readmemb`. Words begin at
IMEM address 0 and use consecutive addresses. The testbench zero-fills unused
locations and writes all 512 words through the core's IMEM programming ports
while reset remains asserted. The supplied word selects a zero-result MAC
with no loads or stores; it is a placeholder, not a convolution program.

The `load_ib` and `load_ksp` tasks are placeholders for the user's loading
sequences. No IB, KSP, OSP or BSP contents are initialized. Current-address
inputs remain zero; no address-feedback schedule is implemented. Bank enables
and the OSP store mask are high, IB/KSP/BSP write enables are low, and the four
operand/EOA lane enable ports are tied high. Memory accesses still depend on
the decoded instruction fields. Reads from unwritten data memories can yield X.

From the `source` directory, when compilation and simulation are desired:

```powershell
./new_hw/tb/run_dsip_core.ps1
./new_hw/tb/run_dsip_core.ps1 -ImemFile ./new_hw/tb/core_imem_instr.txt -RunCycles 128
```

`+IMEM_FILE=<path>` and `+RUN_CYCLES=<count>` are also available when launching
`dsip_core_tb` directly. Its default instruction path is `core_imem_instr.txt`
relative to the simulator's working directory; the script supplies an absolute
path. The default run duration is 64 rising edges including the start/fetch
edge. This duration does not imply instruction-program completion or a core
halt operation; select enough cycles for the desired program and final stores.

The script places `compile.log`, `simulation.log`, `simulation.wlf` and
`core_output.log` in `DSIP/tmp/new_hw_core/`. The text trace records pre-edge
PC, IF/EXE/NL controls, branch target, AGU addresses, OSP write mask/address and
EOA lane 0. All lanes remain available in the waveform. The completion marker
means only that the testbench reached its time limit; no arithmetic comparison
or convolution correctness check is performed by this scaffold.
