# WB-only branch forwarding: implementation and timing

Historical branch-only result. For the current working controller's WB-only
forwarding and multiplier-output pipeline, see [MUL_OUTPUT_PIPELINE.md](MUL_OUTPUT_PIPELINE.md).

Applied on 2026-10-04 in the main working directory, based on commit
88fc7e8 (sync to posedge). Production assembly and instruction images are
unchanged. This supersedes the timing figures in CONTROLLER_POSEDGE.md.

## RTL change

Controller now gives BranchDecision a dedicated branch_ra_data input, selected
from the registered WB result (alu_result_reg) or the RF. It no longer forwards
the live EX alu_result to the branch condition.

branch_wait detects a CBR whose RA matches a valid, nonzero EX destination.
It suppresses issue_valid for one cycle. Existing issue gating holds PC,
inserts invalid RF/memory issue tags, and hides the held instruction from the
mode FSM. EX/WB are not frozen: the older result captures into the existing
ALU_REG, with its destination and valid tags. The branch then reads that WB
result and updates PC. No new wide pipeline register, delay slot, or assembly
encoding is needed. BR and independent CBR instructions do not incur this wait.

Live EX forwarding to ALU operands and memory-address operands remains intact.
DNN arithmetic, X-loop feedback, memory clocks and ReLU are unchanged.

## Timing and resources

Same standalone Vivado 2025.1 out-of-context synthesis as the preceding result:
ASIP, MODEL=SINGLE, xck26-sfvc784-2LV-c, rebuilt hierarchy, 10 ns sys_clk.

| Metric | Before: live EX branch forwarding | After: WB-only branch forwarding |
|---|---:|---:|
| Estimated internal Fmax | 155.7 MHz | 171.4 MHz |
| Checked near-zero-slack period | 6.424 ns | 5.835 ns |
| WNS at 100 MHz | +3.576 ns | +4.165 ns |
| WHS | +0.045 ns | +0.045 ns |
| Setup / hold failing endpoints | 0 / 0 | 0 / 0 |
| Worst data-path delay | 6.421 ns | 5.832 ns |
| Logic levels on worst path | 19 | 17 |
| CLB LUTs | 13,481 | 13,472 |
| Flip-flops | 9,111 | 9,107 |
| Latches | 0 | 0 |
| DSPs | 67 | 67 |
| RAMB18E2 | 195 | 195 |

Estimated Fmax improves by approximately 10.1%. The saved netlist was re-timed
at 5.835 ns: setup slack 0.000 ns, hold slack +0.045 ns, pulse-width slack
+2.155 ns, and zero setup/hold/pulse-width failing endpoints. No resynthesis
was performed at the shorter period, and the production project clock was not
changed.

The new critical path is:

```text
controller/DRB/dout_reg[1]
  -> controller ALU multiply/carry and result-selection logic
  -> live EX forwarding to the next instruction's operand B
  -> operand-selection mux
  -> controller/DRB/dout_reg[29].D
```

Both endpoints are rising-edge registers. Estimated delay is 5.832 ns:
3.973 ns logic and 1.859 ns routing. This is the next-instruction operand
forwarding path, not a combinational loop and not a branch/PC path.

The synthesis structural check finds 64 operand Q pins and 130 replicated PC D
pins, with zero combinational timing paths from those EX operand Q pins to PC.
The final clock audit verifies all 9,107 ASIP FFs, 195 BRAMs and 4,672
distributed-memory leaf cells have non-inverted clocks; there are no latches,
unclocked register pins or unconstrained internal endpoints.

These are post-synthesis estimates, NOT post-route or board timing sign-off.
Routing/skew remain estimated; 656 external inputs and 898 outputs still lack
board-interface I/O-delay constraints. Existing synthesis warnings about
internal tristate conversion and the local TclStore catalog remain; synthesis
has zero errors and no black boxes.

## Verification

- controller_posedge_tb passes 356 accepted instructions, 296 RF retirements,
  23 memory transactions and four DNN starts across two runs, including restart.
  All 16 expected dependent-CBR bubbles pass: PC/instruction stay held, no new
  RF/memory/mode issue occurs, EX advances into WB, and the branch releases
  after one cycle. Directed cases cover taken/not-taken CBR, newest EX versus
  older WB to the same register, multiply overflow to zero, high-bit results,
  R0 exclusion, unrelated EX writes, same-edge WB forwarding, BR and successive
  CBRs. Poison instructions on skipped paths never change architectural state.
- ONE_ONE/TWO_TWO local FSM tests pass 32 checks; Mem_ctrl tests pass 78 incoming
  transactions across all 64 lane selections. This is not a complete multi-ASIP
  network simulation.
- Both full-image regressions (0973_hex and image_222) finish in 212,126 cycles,
  with 17 DNN launches and 1,536 pooled transfers each. For these existing
  instruction streams the cycle count is unchanged. All IB (8,704 rows), OB
  (6,169 rows), OM (1,536 rows) and final (10 rows) CSV traces are byte-identical
  to controller_posedge_final_*, including cycle columns.
- Independent dense accumulation and activation checks pass. Full golden-network
  inference still fails due to the pre-existing assembly issue: 29 and 63 pooled
  mismatches, all on row 15, and five/four final-output mismatches. These values
  are unchanged. This RTL change does not repair that assembly issue.
- Instruction-image SHA256 values remain unchanged:
  DNN BC091BD8DF760FF3E61817F9BF450D46AB90B539DA145A5CABF19F621EE3969F;
  controller 394A1B4FDE9549325BC815E4F2AB34C5D7F14EB21E9DCC4C3BAD3B52F20C62AA.

## Reproduction and artifacts

From the workspace root:

```powershell
./source/hardware/tb/run_controller_posedge.ps1
./tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix branch_wb_final
./tmp/xloop/rtl_sim/compare_traces.ps1
```

From tmp/xloop/rtl_sim:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log branch_wb_synth.log -journal branch_wb_synth.jou -source synth_posedge.tcl -tclargs branch_wb
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log branch_wb_clock_audit.log -journal branch_wb_clock_audit.jou -source audit_posedge.tcl -tclargs branch_wb
```

Reports and checkpoint: branch_wb_synth_{timing,paths,utilization,clocks}.rpt,
branch_wb_synth.dcp, branch_wb_fmax_{timing,paths}.rpt and
branch_wb_clock_audit.log. Full simulation artifacts use branch_wb_final_*;
focused test logs are under tmp/controller_posedge. Earlier controller_posedge_*
timing artifacts remain intact for comparison. Temporary IP synthesis-flow
settings were restored; no IP, assembly or production-project changes remain.
