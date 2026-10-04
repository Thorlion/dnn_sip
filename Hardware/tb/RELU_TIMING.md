# ReLU-only activation timing experiment

This records the pre-controller-retiming ReLU baseline. See
`CONTROLLER_POSEDGE.md` for the subsequent fully rising-edge controller results.

Applied to the main working directory on 2026-10-04. Main and debug cores now
use signed fixed-point ReLU instead of the two LUTs, their selection muxes and
the combinational linear interpolator. Legacy LUT/PWL module files are retained
for reference/unit tests but are not instantiated by either core.

## RTL behavior and pipeline

- CONV still selects MLOM (convolution) or MLFC (dense) and adds MLB bias with
  the original DATA_W-bit wraparound. This source mux is necessary and retained;
  the removed mux was the selection between the two activation LUTs.
- ACT_CONV_NL replaces the old LUT input/coefficient registers, sampling only
  when pipe_valid[2] is asserted. It has a rising-edge clock and asynchronous
  reset, matching the rest of the DNN pipeline.
- NL computes `relu_data_out = ACT_NL_read[DATA_W-1] ? '0 : ACT_NL_read`.
  NOL captures it only when pipe_valid[3] is asserted.
- The former slot5[8] LUT-selection bit is ignored for both encodings. Slot5's
  NOA selection bits, instruction width, stage count, addresses, pooling,
  memory-store routing and END/drain behavior are unchanged.
- For an instruction issued at edge N, the biased input registers at N+3,
  NOL at N+4, pooling at N+5 and the store at N+6. No assembly edits are needed
  for scheduling. Dense outputs now also use ReLU: this deliberately changes
  their numerical activation relative to the old LUT1 function.

## Verification

The focused relu_activation_tb drives upstream data/control boundaries with
forces, leaving the actual bias adder, input register, ReLU and NOL untouched.
It checks all 65,536 signed encodings for each of two source modes and each of
two former LUT-select settings in both main/debug cores. It also checks bias
overflow/wrap, exact register latency, valid holds and asynchronous reset.
The separate posedge_flow_tb uses public-port stimulus without DUT forces,
including both former LUT-select encodings in real stored-output instructions.

Passing functional results:

- ReLU stage: 262,153 sample/hold/reset checks, checking both cores, zero errors.
- Public-port flow: 960 MAC-state comparisons, 12 stores, nine same-edge OB
  forwards and three completed runs, all passing.
- Legacy standalone LUT/PWL and MAC unit regressions still pass. Those LUT/PWL
  modules are not part of the current synthesized datapath. MAC checks cover
  all 65,536 unity encodings and 10,000 fractional/signed/overflow cases.
- Signed pooling: 10,000 cases over six source routes in both cores, zero errors.
- Correct-input assembly chunks: top/middle/bottom each pass 384 unpooled
  convolution and 96 pooled results; both bottom END variants pass. Dense with
  golden pooled input passes all ten sums and ten ReLU outputs. Deliberately
  mispacked bottom-row input fixtures still reproduce their expected errors.
- Full 0973_hex and image_222 executions each complete in 212,106 cycles with
  17 DNN launches and 1,536 pooled transfers. Dense accumulation and final ReLU
  match independent references for actual pooled inputs (zero arithmetic errors).
  Comparing with the pre-ReLU baseline, all 8,704 IB snapshot rows, 6,159
  convolution/pooling OB writes, 1,536 OM writes and ten FCSP sums are identical
  in order/address/value on EACH image, excluding cycle columns. Only dense
  activation is intentionally changed.

The unchanged assembly still produces 29/1,536 pooling errors on 0973_hex and
63/1,536 on image_222, all in the bottom row, with five and four final differences
respectively versus a fully correct ReLU-based network reference. This is the
existing packing/stride problem,
not a ReLU arithmetic or pipeline regression. This experiment does not repair
the assembly or claim the changed dense activation matches a trained model.

## Synthesis and timing comparison

Vivado synthesis succeeds with no black boxes and explicitly confirms that
no LUT activation/interpolator instances remain in the synthesized core.

| Metric | Previous LUT/PWL core | ReLU-only core |
|---|---:|---:|
| Worst setup slack at 10 ns | -29.221 ns | +2.023 ns |
| Setup-failing endpoints | 16 | 0 |
| Activation-stage data-path delay | 39.218 ns | 0.472 ns |
| Activation-stage logic levels | 216 | 1 |
| CLB LUTs | 14,258 | 13,011 |
| Flip-flops | 9,171 | 9,129 |
| DSPs | 70 | 67 |
| RAMB18E2 | 195 | 195 |

Activation path comparisons use each design's worst reported activation data
path: the old path starts at NL_slot5[8] and includes the LUT-selection muxes;
the new path starts at ACT_CONV_NL's sign bit. The ReLU path has +9.523 ns slack.
The LUT reduction is 1,247 (about 8.7%). These are whole-ASIP resource totals,
not only activation-module resources.

The new global worst-slack path is controller/PC_reg_rep[1]_rep to
controller/mode_ctrl/state_reg[0]/CE. It crosses from rising to falling edge,
so it has a 5 ns requirement and a 2.881 ns estimated data-path delay. The
activation stage is no longer the worst path.

Clock polarity audit passes for all 195 BRAMs, 4,672 distributed-memory leaf
cells and 7,357 DNN flip-flops. The DNN still has zero latches; the controller
still has 799 existing latches. The rising-edge memory changes are preserved.

The constrained post-synthesis setup/hold checks pass at 100 MHz. This is NOT
post-route timing closure: routing is estimated, standalone external I/O
constraints are absent, and existing controller latch/no-clock warnings remain.
There is no board execution or inference-accuracy claim from this experiment.

Reports are in tmp/xloop/rtl_sim: relu_synth_timing.rpt,
relu_activation_timing.rpt, relu_synth_utilization.rpt, relu_synth_paths.rpt,
relu_synth.log and relu_clock_audit.log. The original posedge_synth reports
remain intact for comparison.

## Reproduction

From the workspace root:

```powershell
./source/hardware/tb/run_posedge.ps1 -Testbench relu_activation_tb
./source/hardware/tb/run_posedge.ps1
./tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix relu_full
./tmp/xloop/rtl_sim/run_units.ps1 -LogPrefix relu
```

The independent full/chunk reference defaults to ReLU for the current core.
Use `full_reference.py --activation lut1` to compare historical LUT1 logs.
No production assembly or instruction images are changed.

For the same standalone, out-of-context Vivado 2025.1 check as the baseline,
from `tmp/xloop/rtl_sim`:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log relu_synth.log -journal relu_synth.jou -source synth_posedge.tcl -tclargs relu
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log relu_clock_audit.log -journal relu_clock_audit.jou -source audit_posedge.tcl -tclargs relu
```

The synthesis script preserves the prior posedge_synth reports/checkpoint and
writes separate relu_synth reports/checkpoint. Both use ASIP, the same FPGA part,
10 ns clock, memory IP and synthesis options. Post-synthesis estimated routing
is not a replacement for place/route or complete board I/O timing constraints.
Existing controller latch warnings are outside this activation-only change.
