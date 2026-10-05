# One-bit branch predicates, without added cycles

Historical snapshot: a subsequent SINGLE-mode acceptance optimization is
documented in `MODE_ACCEPT_REPORT.md`; its timing supersedes this report.

2026-10-05. Applied to the working directory starting from `2e779f2`.
Only the requested branch simplification is implemented; the earlier 300 MHz
fetch/decode stage, BRAM banking, scoreboard, multiplier split and mode-FSM
changes are not reapplied.

## Changes

- `rtl/controller/controller.sv:197`: add a 32-bit bank of register nonzero flags
  and one WB nonzero flag. The WB flag captures `(alu_result != 0)` with exactly
  the same clock edge and enable as ALU_REG. The RF flags copy that predicate
  with exactly the same write edge/destination as the data register file.
- `controller.sv:275`: select the one-bit WB or RF predicate, with the existing
  WB destination-match priority. R0 remains zero, including attempted R0 writes.
- `controller.sv:282`: instantiate BranchDecision with `DATA_W=1`. CBR remains
  conditional on nonzero and BR remains unconditional. The old full-width
  `branch_ra_data` is only a verification probe, not a hardware branch input.
- No changes to instruction fetch, PC selection, RAW/branch stalls, ALU/RF write
  latency, mode sequencing, transfer arbitration, assembly or DNN arithmetic.
  The flags hold through pipeline bubbles and clear on asynchronous reset.
- `rtl/shared/mem.sv`: restore the missing `RAM_STYLE` parameter/attribute already
  referenced by the existing Controller instruction-memory instantiation. Its
  default is `auto`. Memory edge, enable, data and read latency are unchanged.
  The comparable baseline timing snapshot includes this same elaboration fix.
- Add per-cycle RF/WB flag consistency and architectural CBR decision checks to
  `controller_posedge_tb.sv`, and active-reset flag checks to
  `controller_sync_fetch_tb.sv`.

## Verification

All five controller testbenches pass using the actual working RTL:

- Controller ISA/pipeline: 424 issued operations, 356 retired writes, 31 memory
  transfers, four DNN launches; CBR taken 10 / not taken 14; unchanged 36 branch
  dependency-stall cycles and 428 data dependency-stall cycles.
- 1,001 cycles checking all 32 RF flags and the WB flag against their data.
  Tests include consecutive writers, newest-zero priority, ignored R0 writes,
  WB forwarding, multiply results wrapping to zero, END/restart and backpressure.
- ALU pipeline: 4,109 checks, 592 holds and two asynchronous resets.
- Multicore modes: 32 protocol checks; memory controller: 78 incoming packets,
  all 64 lanes. Synchronous fetch tests cover all three modes, branches, PC wrap,
  invalid/held instructions, repeated start, END/restart and active reset.

Both full-image runs pass cycle-exact comparison against `sync_fetch_main`:
`0973_hex` and `image_222` each take 221,884 cycles, exactly the baseline count.
All eight IB/OB/OM/final CSV SHA256 comparisons match, including cycle timestamps.
Each image has 17 DNN launches, 1,536 pool stores, 26,387 CBR issues and 25,914
taken branches. The program sustains 451 consecutive issues. Added cycles: zero.
Directed DNN tests also pass: 8,364 FC-tree checks, 960 X-loop MAC checks, 12
stores and nine same-edge OB-forward cases.

The pre-existing full-inference numerical golden check still fails identically
to the baseline: row-15 pool mismatches 29/63 and final mismatches 5/4 for the two
images. Actual-input dense accumulation and ReLU checks pass. This task preserves
the existing outputs; it does not fix or establish the root cause of those DNN
numerical discrepancies. Simulation is not exhaustive formal proof.

## Controller-only synthesis timing

Fresh Vivado 2025.1 OOC synthesis, `xck26-sfvc784-2LV-c`, Controller top,
`MCMEM_W=4096`, `DATA_W/INSTR_W/ADDR_W=32`, `MODEL=1`, first row/column 1.
Hierarchy rebuilt; clock applied after synthesis, as in the previous comparison
flow. No path cuts, false paths or multicycle exceptions are introduced.

| Metric | Comparable baseline | Applied one-bit branch |
| --- | ---: | ---: |
| Checked post-synthesis period | 4.870 ns | 4.580 ns |
| Estimated internal Fmax | 205.339 MHz | 218.341 MHz |
| Setup slack at checked period | 0 ns | +0.001 ns |
| CLB LUTs | 2,813 | 2,865 |
| Flip-flops | 1,690 | 1,723 |
| DSP / BRAM36 | 3 / 4 | 3 / 4 |

Fmax estimate improves approximately 6.3%, costing 52 LUTs and 33 FFs.
Hold slack is +0.109 ns, pulse-width slack +1.713 ns; no setup/hold/pulse-width
failing endpoints at 4.580 ns, no black boxes, inferred latches or unconstrained
internal endpoints. The timing script rounds conservatively to 4.580 ns; the
earlier temporary trial checked 4.579 ns and reported 218.388 MHz.

These are post-synthesis estimates, not routed closure, a whole-ASIP Fmax or a
guaranteed board clock. External I/O delays and OOC clock-buffer context are
unspecified. This small change does **not** meet 300 MHz: WNS at 3.333 ns is
-1.246 ns. Modes 2/3 are functionally tested but not included in this timing run.

## New critical path

`Instruction BRAM -> EX2 operand dependency check -> data_wait -> issue_valid
 -> masked mode opcode/state decode -> mode-state register clock enable`

Physical source: `MCMem/memory_reg_bram_0/CLKBWRCLK`.
Physical destination: `mode_ctrl/state_reg[0]/CE`; bits 1/2 share the worst slack.
Data path: 4.388 ns (2.453 ns logic, 1.935 ns estimated route), nine levels
including the instruction-BRAM cascade. It is no longer the forwarded 32-bit
branch-value comparison and next-PC feedback path.
Although 4.388 ns exceeds the former 4.231 ns raw data delay, this path ends
at a fabric FF clock-enable pin with a smaller setup requirement than the
former BRAM-address endpoint. Clock period, not raw data delay alone, determines
the Fmax comparison.

Relevant RTL: `controller.sv:247` (data_wait), `:423` (issue_valid), `:475`
(mode opcode masking), `:482` (mode-controller opcode input). Existing
`ctrl_mode2.sv` consumes those events; it is unchanged by this task.

## Reproduction / saved evidence

Controller tests, from `C:/Users/nguye/Desktop/LAB/DSIP/source`:

```powershell
& ./hardware/tb/run_controller_posedge.ps1
```

Controller synthesis, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/controller_300`:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source timing.tcl -tclargs branch_nonzero 1
```

Full regression, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/xloop/rtl_sim`:

```powershell
& ./run_tree_retime_main.ps1 -LogPrefix branch_nonzero_main -Baseline sync_fetch_main
```

Evidence: `tmp/controller_300/branch_nonzero_*`,
`tmp/controller_posedge/*_tb.log`, `tmp/xloop/rtl_sim/branch_nonzero_main_*`.
The full-testbench branch counter uses accepted `issue_valid && PC_sel`; its
obsolete probe of the reverted experimental `redirect` signal was removed.

Validated controller SHA256:
`30CBC3EFDE0A5C22D1FB3F5798DE5D950F6E79132F2F377A805DCDC1A9D40BDE`.
