# Controller multiplier-output pipeline: working implementation

Timing update (2026-10-05): the DNN FC tree has since been retimed. The latest
working-design timing and verification are in FC_TREE_RETIMING.md. The timing
below records the controller deployment before that DNN change; the controller
pipeline described here remains in use.

Applied on 2026-10-04 in the main working directory. This supersedes the
working-design timing in WB_ONLY_FORWARDING.md and BRANCH_WB_TIMING.md.
The experimental mul_stage_controller.sv/mul_stage_alu.sv behavior is now
implemented in production controller.sv/ctrl_alu.sv, without overlay includes.
Assembly, instruction images, DNN RTL, canonical memory-IP settings and
dsip.xpr are unchanged. Existing user edits are preserved; the agent did not
stage or commit these changes.

## Computation and control

`ctrl_alu.sv` now has clk/rst/wen inputs and registers the multiply result
before the final result mux. Non-MUL results and the MUL-selection bit are
registered in parallel so every ALU instruction has the same added latency.
The existing ALU_REG captures the selected result on the following edge.

Pipeline: decode/operand capture -> EX1 arithmetic -> EX2 result mux -> WB/RF.

`controller.sv` adds `rd_mid` and `rf_wen_mid` alongside the arithmetic-result
registers. The final WB destination and valid tags advance from this new stage,
not directly from EX1. Results therefore retain the correct destination and
write-enable even across independent instructions or bubbles.

Both data and conditional-branch waits check valid nonzero destinations in
EX1 and EX2. WB-only forwarding remains in place for ALU operands, branch
operands and all four memory-address registers. Immediate true dependencies
can now require two bubbles; distance-two dependencies can require one.
Independent instructions still issue at one per cycle. R0, unused immediate
fields and destination-only matches do not generate false dependencies.

During a dependency wait PC/instruction hold, new ALU/memory tags are invalid,
and the mode FSM sees an invalid opcode. Execution/WB continue draining; no
delay-slot instruction is accepted and no assembly NOP change is required.
END now waits for pending writers in all three stages. All new state uses
posedge clk with asynchronous active-high reset.

## Main-RTL synthesis timing

Fresh Vivado 2025.1 OOC synthesis of ASIP/SINGLE, xck26-sfvc784-2LV-c,
rebuilt hierarchy and 10 ns sys_clk; no temporary RTL overlays were supplied.

| Metric | Before multiplier-output stage | Current working RTL |
|---|---:|---:|
| Estimated internal Fmax | 189.6 MHz | 257.3 MHz |
| Checked near-zero-slack period | 5.275 ns | 3.886 ns |
| WNS at 10 ns | +4.725 ns | +6.114 ns |
| Worst data-path delay | 5.272 ns | 3.882 ns |
| CLB LUTs | 13,336 | 13,316 |
| CLB flip-flops | 9,090 | 9,169 |
| DSPs / RAMB18 primitives | 67 / 195 | 67 / 195 |

The new critical path is in the unchanged DNN FC adder tree:

`dnn_core/EOA_array[39].EOA/dout_reg[0] -> 64-to-1 FC sum -> dnn_core/NFC/dout_reg[15]`

Data delay: 3.882 ns (1.942 ns logic + 1.940 ns estimated routing), 14 logic
levels. The controller multiplier and result mux no longer limit full-ASIP
timing. Vivado maps the multiply boundary into clocked DSP_OUTPUT elements;
the longest operand-to-arithmetic path is 3.162 ns and the longest path into
the WB ALU_REG is 1.291 ns.

At 3.886 ns the checked WNS is 0.000 ns, WHS +0.045 ns and WPWS +1.181 ns,
with no failing setup/hold/pulse-width endpoints. Structural checks find no
direct combinational EX operand-data path to decode operand/address/PC
captures or to the final ALU_REG. There are no latches, black boxes, unclocked
register pins or unconstrained internal endpoints. Checked FF/memory clocks
are non-inverted; all 7,357 DNN FFs are retained.

This is post-synthesis estimated Fmax, not post-route timing or measured board
frequency. External I/O delays and OOC HD.CLK_SRC are not constrained. Existing
tristate-conversion/TclStore warnings remain. Project clock constraints and
implementation runs were not changed.

## Verification

The production controller testbench now models EX1/EX2/WB independently. It
passes 424 accepted instructions, 356 retirements, 31 memory transactions,
four DNN launches, 428 data bubbles and 36 branch bubbles over run/restart.
It checks source masks, arithmetic including MUL/MULI, newest-writer/zero
priority, all four memory-address sources, stalled PC/opcode/issue tags,
stage-valid/destination/result alignment, execution drain, END and restart.

The new direct ALU pipeline regression passes 4,109 samples, including 592
hold cycles and two asynchronous resets, with zero errors. It covers product
overflow/high-bit/zero cases, all supported operations, shifts beyond word
width, consecutive MUL/non-MUL selection changes, exact registered latency,
wen holds and absence of falling-edge state changes.
Local ONE_ONE/TWO_TWO mode tests pass 32 checks; incoming memory tests pass
78 packets across 64 lanes. No full multicore-network or formal proof is claimed.

Both main-RTL full-image runs finish 17 DNN launches and 1,536 pooled stores.
Ordered non-cycle fields in IB (8,704 rows), OB (6,169), OM (1,536) and final
outputs (10) match the pre-stage working baseline for both images. All eight
CSVs also match the tested temporary pipeline byte-for-byte, including cycle
fields. Independent actual-input dense/ReLU comparisons have zero errors.
These results use the `mul_stage_main_` prefix in tmp/xloop/rtl_sim.
Existing assembly-related
golden mismatches are deliberately not fixed (pool 29/63 and final 5/4 for
0973_hex/image_222). Dense/ReLU correctness is checked against actual inputs
separately; passing RTL-stage checks does not imply full-network golden PASS.

The current inference takes 221,884 total test cycles versus 212,186 before
the new stage: +9,698 cycles. Excluding identical reset/load/startup gives
221,033 versus 211,335 active cycles (+4.589%). Estimated Fmax rises 35.74%,
so estimated active time changes from 1.11479 ms to 0.85893 ms, approximately
29.79% higher throughput at the respective clock limits. At an unchanged
clock the added stage would instead make this workload 4.589% slower.
Re-profile future assembly/image-size changes and actual memory handshakes.

## Reproduce from the workspace root

```powershell
./source/hardware/tb/run_controller_posedge.ps1
./tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix mul_stage_main
./tmp/xloop/rtl_sim/compare_traces.ps1 -Baseline wb_only_main -Candidate mul_stage_main
Push-Location tmp/xloop/rtl_sim
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source synth_posedge.tcl -log mul_stage_main_synth.log -journal mul_stage_main_synth.jou -tclargs mul_stage_main
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source audit_posedge.tcl -log mul_stage_main_clock_audit.log -journal mul_stage_main_clock_audit.jou -tclargs mul_stage_main
Pop-Location
```

Focused test logs: tmp/controller_posedge. Main synthesis/checkpoint/reports
and full-image traces: tmp/xloop/rtl_sim/mul_stage_main_*. The historical
two-stage forwarding profiler is not compatible with the new ALU latency;
use the current controller scoreboard and main-RTL runners above.
