# Rising-edge controller retiming and timing results

This report documents the pre-branch-stall baseline. For the newer WB-only
branch forwarding change and current timing, see BRANCH_WB_TIMING.md.

Applied to the main working directory on 2026-10-04, on top of the existing
rising-edge DNN/memory changes and the ReLU-only activation experiment.
Production assembly and compiled instruction images are unchanged.

## Changes

- All controller operand, ALU-result, destination/write-enable and memory-command
  pipeline registers now use clk instead of !clk. All three mode-FSM variants
  are connected to clk, so they advance on the main clock's rising edge.
- Decode reads forward the newest pending EX result, then WB, before reading
  the RF. This covers both ALU operands, the branch condition and all four
  memory-address operands. Write enables distinguish valid producers; R0 is
  never treated as a forwarding producer. The old EX-stage forwarding instance
  is no longer used, avoiding a second overwrite with older data.
- issue_valid qualifies RF write enables and memory-command types. A held PC
  is not executed repeatedly while a mode FSM waits. Mode opcodes are ignored
  unless the corresponding instruction is actually accepted.
- Memory and synchronization/start/end instructions wait for outstanding memory
  commands. ALU/branch instructions can overlap transfers. CMD_REG holds a
  pending local command if an incoming port request temporarily occupies the
  transfer FSM. Memory writes drain before a subsequent DNN start; RF writes
  drain before END. END clears start_flag and fetch stops until a new start.
- Mem_ctrl has a busy output and fully specified combinational defaults for
  every transfer output. Its old incomplete assignments inferred transparent
  latches and could retain stale strobes. Idle/inactive outputs now clear.
- ONE_ONE and TWO_TWO mode FSMs reset their DNN start outputs and ignore sticky
  completion on the edge that the DNN accepts a new start pulse. TWO_TWO's
  sequential blocking assignments were changed to nonblocking assignments to
  remove same-edge ordering races.

This is rising-edge storage, not registered-everything: combinational decode,
forwarding, arithmetic, RF reads and the instruction-memory asynchronous read
remain combinational. Asynchronous reset is retained. DNN pipeline stage count,
X-loop feedback, ReLU arithmetic and BRAM configuration are unchanged.

## Pipeline contract

For a controller instruction accepted at rising edge N:

| Edge | Event |
|---|---|
| N | Forwarded operands and destination/valid tags capture; PC advances or branches |
| N+1 | ALU result captures into WB, or memory address/type captures into CMD_REG |
| N+2 | RF commits WB, or an idle memory FSM accepts the pending command |
| N+3 | OM/OB synchronous read samples the requested address |
| N+4 | The matching destination write samples the returned read data |

Incoming-port arbitration can delay command acceptance; CMD_REG holds it.
All consumers sample pre-edge values. Instruction acceptance, not simply PC
visibility, is the reference point for ALU retirement and mode transitions.

## Verification

- controller_posedge_tb: public-port stimulus with an independent architectural
  reference, no DUT force/deposit. Passes 296 issued instructions, 256 RF
  retirements, 23 memory transactions and four DNN starts over two runs,
  including restart without RF/instruction-memory reset. Coverage includes
  adjacent EX dependencies, same-edge WB dependencies, newest-writer priority,
  ALU/branch/memory-address forwarding, taken/untaken CBR, unconditional branch,
  back-to-back memory commands, simultaneous incoming P0/local command issue,
  idle-before-start, DNN wait/drain, END drain and falling-edge stability.
- controller_modes_posedge_tb: ONE_ONE/TWO_TWO FSM smoke tests pass 32 state/
  enable checks, including reset, one-cycle start pulses, sticky-done rejection,
  vertical/horizontal waits, transfer flags and END. These are local FSM tests,
  not complete multi-ASIP network validation.
- mem_ctrl_posedge_tb: 78 incoming P0/P1 transactions pass, covering all 64 lane
  selections, OM/IB/KSP/BSP/SC destinations, incoming broadcast packets, default
  strobe clearing and reset-abort recovery.
- Full-image final regressions for 0973_hex and image_222 each complete in
  212,126 cycles, with 17 DNN launches and 1,536 pooled transfers. All 8,704 IB
  snapshot rows, 6,169 OB writes, 1,536 OM writes and ten final FCSP/OB pairs
  exactly match the pre-controller-retiming ReLU baseline in order/address/data,
  ignoring cycle columns. Both independently checked dense/ReLU calculations
  match the actual pooled inputs (zero arithmetic mismatches).

The final cycle count is only 20 greater than the baseline's 212,106 cycles
(about 0.0094%), mainly because DNN start now crosses a registered rising-edge
boundary. The earlier all-instruction-stall prototype took 315,946 cycles; that
prototype was refined and is NOT the final RTL.

The unchanged assembly still gives 29/1,536 and 63/1,536 bottom-row pooling
mismatches on the two images, with five and four final mismatches respectively
against a fully correct ReLU network reference. These values are unchanged by
controller retiming. Full golden inference therefore still fails; this work
does not repair the previously diagnosed assembly packing/stride problem.

The focused controller test preserves existing instruction arithmetic semantics
(including the current unsigned-shift behavior); this change is not a new ISA
definition or an implementation of previously unsupported commands.

## Timing comparison

Same Vivado 2025.1 standalone out-of-context synthesis as the baseline: ASIP,
MODEL=SINGLE, xck26-sfvc784-2LV-c, 10 ns clock, same memory IP, same synthesis
options. Synthesis completes without errors or black boxes.

| Metric | ReLU + falling-edge controller | ReLU + rising-edge controller |
|---|---:|---:|
| Worst setup slack at 100 MHz | +2.023 ns | +3.576 ns |
| Worst hold slack | +0.025 ns | +0.045 ns |
| Setup/hold failing endpoints | 0 / 0 | 0 / 0 |
| CLB LUTs | 13,011 | 13,481 |
| Flip-flops | 9,129 | 9,111 |
| Inferred latches | 799 | 0 |
| DSPs | 67 | 67 |
| RAMB18E2 | 195 | 195 |
| Unclocked register/latch pins | 6,636 | 0 |
| Unconstrained internal endpoints | 799 | 0 |

The new worst-slack path is:

```text
controller/DRB/dout_reg[1]
  -> controller ALU multiply/result-selection logic
  -> decode forwarding and nonzero branch-condition test
  -> PC_sel / next-PC selection
  -> controller/PC_reg_rep[0].D
```

Both endpoints use rising edges of sys_clk. Requirement: 10 ns. Estimated
data-path delay: 6.421 ns (logic 4.113 ns, estimated route 2.308 ns), 19 logic
levels. The previous worst path was PC -> asynchronous instruction fetch ->
mode-FSM state enable, with only a 5 ns half-cycle requirement. These are
different paths; comparing their raw delays alone is not meaningful.

The final clock audit passes: all 9,111 synthesized ASIP flip-flops have
non-inverted clock pins, all 195 BRAMs and 4,672 distributed-memory leaf cells
have non-inverted clock polarities, and there are zero inferred latches.
The report contains only the non-inverted sys_clk clock. Final audit results
are recorded in controller_posedge_clock_audit.log.

This is NOT post-route timing closure or an Fmax measurement. Routing/skew are
estimated in the standalone check. External board-interface I/O delays remain
unconstrained (656 inputs and 898 outputs). No place/route or board run was done.

## Reproduction and artifacts

From the workspace root:

```powershell
./source/hardware/tb/run_controller_posedge.ps1
./tmp/xloop/rtl_sim/run_full.ps1 -LogPrefix controller_posedge_final
```

The focused runner writes logs under tmp/controller_posedge. Full ASIP logs,
CSV traces, independent-reference summaries and timing reports are under
tmp/xloop/rtl_sim. The final logs use controller_posedge_final_*; earlier
controller_posedge_full_* logs describe the conservative prototype that stalled
all instructions during transfers, not the final implementation.

From tmp/xloop/rtl_sim:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log controller_posedge_synth.log -journal controller_posedge_synth.jou -source synth_posedge.tcl -tclargs controller_posedge
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -log controller_posedge_clock_audit.log -journal controller_posedge_clock_audit.jou -source audit_posedge.tcl -tclargs controller_posedge
```

Final timing/utilization reports are controller_posedge_synth_timing.rpt,
controller_posedge_synth_paths.rpt, controller_posedge_synth_utilization.rpt
and controller_posedge_synth_clocks.rpt. Original relu_synth_* reports remain
intact as the pre-controller-retiming baseline.
