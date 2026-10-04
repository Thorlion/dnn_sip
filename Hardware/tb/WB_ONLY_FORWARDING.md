# WB-only controller data forwarding

Applied to the main working RTL on 2026-10-04, based on commit f10c11d
(`optimize branch critical path`). This supersedes the current-design timing
in BRANCH_WB_TIMING.md. Assembly, both instruction images, the DNN core,
memory clocks and canonical memory-IP parameters are unchanged.

## RTL behavior

`controller/controller.sv` no longer forwards the combinational EX `alu_result`
into RA/RB ALU operands or RD/RA/RB/RTEMP memory-address operands. All four
ports now select registered WB `alu_result_reg` or the register file.

`data_wait` detects a valid, nonzero EX destination matching a register that
the current instruction actually reads:

| Instruction | Checked data sources |
|---|---|
| ADD, SUB, MUL, AND, OR | RA, RB |
| INC, DEC, shift, immediate arithmetic, MOV | RA |
| MOVLO, MOVHI | None |
| Memory transfers (opcodes 32..39) | RD, RA, RB, RTEMP |
| CBR | RA, using the existing separate `branch_wait` |

R0 is never a producer. Immediate bits overlapping RB/RTEMP, unused MOVLO/MOVHI
RA fields, and ALU destination-only matches do not cause data bubbles.

On a dependency, `issue_valid` is suppressed for one cycle: PC/instruction stay
held, RF and memory issue tags become invalid, and the held opcode is hidden
from the mode FSM. EX/WB continue advancing. The producer captures into the
existing ALU_REG, then the consumer reads it through WB forwarding. There is
no extra fetched instruction, ISA delay slot, new wide pipeline register,
assembly NOP requirement, or bubble after an independent ALU instruction.
Existing mode/memory waits may still delay issue independently.

## Main-RTL synthesis

Vivado 2025.1, ASIP/SINGLE, xck26-sfvc784-2LV-c, rebuilt hierarchy,
out-of-context synthesis. No controller overlay was supplied.

| Metric | Before: EX data bypass | Current: selective WB-only |
|---|---:|---:|
| Estimated internal Fmax | 171.4 MHz | 189.6 MHz |
| Checked near-zero-slack period | 5.835 ns | 5.275 ns |
| WNS at 10 ns | +4.165 ns | +4.725 ns |
| Worst data delay | 5.832 ns | 5.272 ns |
| Logic levels | 17 | 15 |
| CLB LUTs | 13,472 | 13,336 |
| Flip-flops | 9,107 | 9,090 |
| DSPs / RAMB18 primitives | 67 / 195 | 67 / 195 |

The new critical path is `controller/DRB/dout_reg[1]` through the controller's
32-bit multiply and ALU-result selection to `controller/ALU_REG/dout_reg[29]`.
The DNN MAC is not yet the full-ASIP bottleneck.

At 5.275 ns: WNS 0.000 ns, WHS +0.045 ns, WPWS +1.875 ns; no setup, hold or
pulse-width failing endpoints. Structural audit finds zero live EX operand-data
paths to any of the 305 operand/address/PC capture D pins. All 9,090 FFs and
memory clocks are non-inverted; no latches, black boxes, unclocked register
pins or unconstrained internal endpoints.

These are post-synthesis estimates, not post-route timing or a measured board
clock. External I/O delays and OOC HD.CLK_SRC are not constrained. Existing
tristate-conversion and TclStore warnings remain. Project clock settings and
implementation runs were not changed.

## Verification

The expanded production controller test passes 424 accepted instructions,
356 retirements, 31 memory transactions, four DNN launches, 212 data RAW
bubbles and 16 branch bubbles across execution/restart. Its independent ISA
reference checks WB/RF operands, all four address ports, newest-writer/zero
priority, multiply consumers, dual-source hazards, false encoded-field
matches and R0. Every RAW bubble is checked for PC/instruction hold, invalid
issue tags, EX-to-WB drain and dependency clearance after one rising edge.
The ONE_ONE/TWO_TWO mode tests pass 32 checks, and incoming memory tests pass
78 packets across 64 lanes.

The DNN rising-edge/X-loop regression passes 960 MAC checks, 12 stores,
nine same-edge OB forwards and three completed runs. The ReLU regression
passes 262,153 samples covering every 16-bit encoding, both bias-source modes,
both former LUT-select values, the main/debug cores, valid holds and reset.

Both main-RTL full-image runs complete 17 DNN launches and 1,536 pooled stores.
All ordered non-cycle IB (8,704 rows), OB (6,169), OM (1,536) and final-output
(10) fields match the pre-change baseline. All four CSVs also match the
previous WB-only overlay byte-for-byte, including their cycle fields.
Independent actual-input dense and activation comparisons have zero errors.
Results and trace comparisons are in `tmp/xloop/rtl_sim/wb_only_main_*`.
The source is functionally identical to
the previously profiled `wb_bubble_controller.sv` overlay (only comments differ).
The original profiling evidence is recorded in `tmp/xloop/rtl_sim/FORWARDING_COST.md`.

The measured current assembly overhead is 60 cycles per inference:
212,126 -> 212,186 total test cycles, or 211,275 -> 211,335 active cycles
(+0.0284%). At the respective estimated clock limits this corresponds to
about 10.6% higher inference throughput; at an unchanged clock the run is
slightly slower. Re-profile when assembly scheduling or image size changes.

The existing assembly-related full-network golden mismatches are not fixed by
this RTL change (pool: 29/63; final: 5/4 for 0973_hex/image_222). Actual-input
dense accumulation and ReLU are checked separately. This is not a formal proof,
a full multicore-network verification, or a claim that all RTL is bug-free.

## Reproduce from the workspace root

```powershell
./source/hardware/tb/run_controller_posedge.ps1
./source/hardware/tb/run_posedge.ps1
./source/hardware/tb/run_posedge.ps1 -Testbench relu_activation_tb
./tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix wb_only_main
./tmp/xloop/rtl_sim/compare_traces.ps1 -Baseline branch_wb_final -Candidate wb_only_main
Push-Location tmp/xloop/rtl_sim
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source synth_posedge.tcl -log wb_only_main_synth.log -journal wb_only_main_synth.jou -tclargs wb_only_main
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source audit_posedge.tcl -log wb_only_main_clock_audit.log -journal wb_only_main_clock_audit.jou -tclargs wb_only_main
Pop-Location
```

Timing/utilization reports and checkpoint use the `wb_only_main_` prefix in
`tmp/xloop/rtl_sim`; focused verification logs are in `tmp/controller_posedge`.
Canonical BRAM, MEMSC and MEMOB XCI hashes were restored to their pre-run values.
