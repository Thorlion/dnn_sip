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
