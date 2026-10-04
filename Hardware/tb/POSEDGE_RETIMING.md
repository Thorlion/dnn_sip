# Rising-edge memory and DNN retiming verification

This records the pre-ReLU retiming baseline. The subsequent ReLU-only change
and its current timing/functional results are recorded in `RELU_TIMING.md`.

Applied to the main working directory on 2026-10-04. Assembly and compiled
instruction images are unchanged. Functional simulation passes the checks
below; the design is **not timing-closed at 100 MHz**.

## Production changes

- All IB, KSP, OSP, BSP, FCSP and OB_MC BRAM ports use `clk`, not `!clk`.
- OBIP writes use `clk`. SC, controller instruction-memory and register-file
  writes already used the rising edge. Their asynchronous reads, including
  OBIP's read, are deliberately retained.
- DNN operand/result registers, LUT coefficient registers and PC now use the
  rising edge. The controller's existing falling-edge datapath is unchanged.
- AGU branch selection is combinational from pre-edge loop state. Its new
  `issue_en` input prevents idle/drain cycles from changing addresses or loops.
- A six-stage valid/END pipeline gates operand loads, EOA updates, subsequent
  data registers and stores. END is issued once, including its other slots.
  `dnn_done` asserts at the END instruction's memory-commit edge and remains
  high until the next accepted start or reset. Start requests while busy are
  ignored; memory loading through the public write ports still works in reset.
- The asynchronous OB read uses the PL address. An older MS-stage write to
  the same address is forwarded to pooling before the memory commit edge.
  Both OB memories receive the same address/data/write-enable packet.
- Main and debug cores use the same rising-edge schedule and valid handling.
- Vivado regenerated the canonical BRAM IP with common clocks, `READ_FIRST`
  operation and one-cycle read latency. Optional output registers remain off.
  The unused duplicate XCI was synchronized to that configuration, preserving
  its relative generation-directory paths.

The synchronous BRAM collision policy is read-before-write: a read and write
of the same address on one edge return the pre-write word. This follows AMD's
[UltraScale memory collision guidance](https://docs.amd.com/r/en-US/ug573-ultrascale-memory-resources/Address-Collision).
There is no automatic OSP/FCSP load bypass; programs must respect that latency.
OB's PL/MS dependency has the explicit forwarding described above.

## Timing contract

For an instruction issued on rising edge N, the values belong to that same
instruction throughout the following schedule:

| Edge | Data/control event |
|---|---|
| N | IF instruction and AGU addresses register |
| N+1 | BRAM read output and ML controls update |
| N+2 | ML operand registers capture; CONV controls update |
| N+3 | EOA/LUT registers capture; NL controls update |
| N+4 | NEOA/NOA/NOL/NFC capture; PL controls update |
| N+5 | PEOA/POA/POL/POM/POFC capture; MS controls update |
| N+6 | Memories commit the matching MS write packet; END may complete |

All clocked consumers sample pre-edge values. EOA self/neighbor feedback is
still one computation cycle; no register was inserted into that recurrence.
With uninterrupted issue, an OSP/FCSP load issued at least six cycles after
its producer's issue reads the newly committed word. A five-cycle issue gap
would read on the producer's commit edge and obtain the old word.

## Passing functional checks

ModelSim 10.1d used the regenerated AMD memory simulation models. Default
configuration: 64 lanes, signed Q8.8, 512-word scratchpads.

- The new standalone flow test checks both main and debug cores using only
  public write/start/read ports and read-only native-memory probes. It passes
  960 MAC-state comparisons, 12 output stores, nine same-edge OB forwards and
  three completed runs. Coverage includes broadcast/local inputs, distinct
  lane weights, held weights/operands, self/neighbor accumulation, lane masks,
  shifted OSP writes, a store bundled with END, non-execution after END,
  idle preservation, restart without reset, reset-abort recovery and public
  OB reads. A standalone BRAM/debug-RAM comparison also checks rising-edge
  writes/reads, disabled-read hold and same-address read-before-write.
- AGU `sit` counts 1, 2, 31 and 32 pass with every loop input/kernel address
  checked. `sit 0` retains the existing one sequential-body-pass behavior.
- Five randomized first-row X-loop cases pass 192 convolution outputs each.
- Correct-input top/middle/bottom chunks each pass 384 unpooled convolution
  outputs and 96 pooled outputs. Dense with golden pooled input passes all
  ten sums and ten final activation outputs.
- Arithmetic regressions pass all 65,536 encodings for each current LUT and
  MAC unity, 10,000 normal-MAC cases and 10,000 signed pooling cases over all
  six valid source routes in both cores.
- Full unmodified-assembly runs for `0973_hex` and `image_222` complete at
  212,106 cycles, with 17 DNN launches and 1,536 pooled transfers each. All
  8,704 input-buffer snapshot entries, 6,169 OB writes, 1,536 OM writes and
  ten final values match the pre-retiming RTL-fixed baseline for each image
  when cycle numbers are excluded. Native OBIP/OB_MC contents match writes.
  Dense and activation calculations match independent references for the
  actual pooled inputs on both images.

The unchanged assembly still causes 29/1,536 and 63/1,536 pooling mismatches,
respectively, confined to the bottom row. Full golden inference still fails;
this retiming does not repair the controller's incorrect last-row source
stride/destination packing described in `tmp/xloop/rtl_sim/RTL_FIXES.md`.

## Synthesis and limitations

Standalone Vivado 2025.1 synthesis of ASIP for `xck26-sfvc784-2LV-c` succeeds
with no black boxes: 14,258 LUTs, 9,171 flip-flops, 195 RAMB18E2 and 70 DSPs.
The synthesized clock audit passes: all 195 BRAMs, 4,672 distributed-RAM
leaf cells and 7,399 DNN flip-flops have non-inverted clocks. The DNN has
zero inferred latches; the audit log is `posedge_clock_pins.log`.
The existing controller still infers 799 latches and emits internal-tristate
conversion warnings. Those controller sources were not modified.

The post-synthesis, out-of-context timing estimate at a 10 ns clock has WNS
**-29.221 ns**. The worst path is NL LUT selection through combinational
interpolation to NOL, with an estimated data-path delay of 39.218 ns and
216 logic levels. This is not a post-route result or an Fmax measurement.
External I/O timing is not constrained in this standalone check. Activation
path optimization, controller cleanup and complete implementation/board
validation remain necessary before claiming reliable 100 MHz operation.

## Reproduction

From the workspace root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File source/hardware/tb/run_posedge.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tmp/xloop/rtl_sim/run_agu.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tmp/xloop/rtl_sim/run_dnn.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix posedge_final_full
powershell -NoProfile -ExecutionPolicy Bypass -File tmp/xloop/rtl_sim/run_units.ps1 -LogPrefix posedge_final
```

The standalone flow runner is provided with the RTL and takes `-ModelSimBin`
for an alternate installation. Regenerate the project IP first on a fresh
checkout. It places its logs in `tmp/posedge_flow`, outside the source repo.
Other regression logs and synthesis reports are in `tmp/xloop/rtl_sim`:
`posedge_final_full_*`, `*_posedge_final`, `dnn_posedge_seed*`,
`modelsim_agu_posedge_sit*`, `posedge_synth*.rpt` and `posedge_synth.log`.

Instruction SHA256 values remain:

```text
DNN BC091BD8DF760FF3E61817F9BF450D46AB90B539DA145A5CABF19F621EE3969F
MC  394A1B4FDE9549325BC815E4F2AB34C5D7F14EB21E9DCC4C3BAD3B52F20C62AA
```
