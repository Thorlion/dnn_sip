# Synchronous controller instruction fetch

Applied to the working directory on 2026-10-05, based on main commit b858750.
No assembly, DNN arithmetic, controller ALU/forwarding, or mode-FSM changes.

## Implementation

Controller MCMem now uses EN_OUT_FF=1 and RAM_STYLE=block. Its existing enabled
posedge read is the instruction register; no second instruction-output stage
is added. shared/mem.sv gains an optional RAM_STYLE parameter, default auto,
so other memory instances retain their previous mapping policy and behavior.

PC_next is the current PC during a stall, PC+1 when an instruction issues,
or the branch immediate when a taken branch issues (truncated to PC width).
At an enabled read edge, both PC and memory read use PC_next. This prevents
the repeated/stale instruction that would result from synchronously reading
the old PC while incrementing it on the same edge.

| Condition before rising edge | Read enable | PC / instruction action |
|---|---|---|
| Reset | 0 | PC=0, valid=0; raw RAM output need not reset |
| Start while stopped | 1 | Fetch word zero and set valid; first issue on next edge |
| Accepted ordinary instruction | 1 | Fetch PC+1 and update PC together |
| Accepted taken branch | 1 | Fetch branch target and update PC together |
| Dependency/memory/mode wait | 0 | Hold PC, instruction, valid; execution/WB still drain |
| end_flag asserted | 0 | Reset PC and clear valid on the cleanup edge |

instruction_valid gates issue_valid. Invalid or held instructions cannot
reach the mode FSM (mode_opcode=63) or assert a new RF/memory side-effect
packet. Repeated start during an active run does not refetch word zero.
All existing branch/data interlocks, memory backpressure and END drain remain.

On the END-issue edge the normal sequential read may fetch an unused
fall-through word. The newly asserted end_flag prevents it issuing immediately;
the following edge clears valid and PC. It need not contain an initialized
instruction and it cannot execute. Restart fetches word zero again, including
program updates made while stopped.

Programs must be loaded while stopped/reset. This change does not add
self-modifying-code support or define hot-patching in-flight instructions.
The shared RTL read/write model remains read-first on same-address edges.

## Control verification

run_controller_posedge.ps1 passes all five tests on the working RTL:

- controller_posedge_tb: 424 accepted instructions, 356 ALU retirements,
  31 memory transfers, four DNN launches, 36 CBR-stall cycles, 428 data-stall
  cycles. Independent architectural reference checks instruction order,
  operands, tags/results, all address sources, memory arbitration, END/restart.
  PC/instruction alignment is now explicitly checked whenever decode is valid
  and not stopped by END; invalid issue/mode control is explicitly rejected.
- controller_sync_fetch_tb: public-port tests of SINGLE, ONE_ONE and TWO_TWO.
  Respectively 42/48/51 enabled reads, 80/139/191 output holds,
  105/107/108 invalid cycles, 37/43/46 issued instructions and 26/83/134
  mode-wait cycles. Each mode completes three END runs. Checks every fetch
  against an independent shadow program, including branch target truncation,
  sequential wraparound, taken/not-taken dependent branches, poison words,
  no falling-edge instruction update, repeated start while held, idle program
  replacement, restart, and asynchronous reset during a RAW stall.
- controller_alu_pipe_tb: 4,109 arithmetic/pipeline checks, 592 holds, two resets.
- controller_modes_posedge_tb: 32 mode3/mode4 handshake/state checks.
- mem_ctrl_posedge_tb: 78 incoming packets, all 64 lane selections.

No control violations were observed in these tests. This is directed and
architectural simulation, not an exhaustive formal proof.

## Synthesis and full-ASIP regression

Vivado 2025.1, xck26-sfvc784-2LV-c, ASIP/SINGLE, out-of-context synthesis,
rebuilt hierarchy, production asip_files.f and IP, initially 10 ns sys_clk.

| Metric | b858750 (asynchronous MCMem) | Synchronous MCMem |
|---|---:|---:|
| Rechecked internal Fmax estimate | 270.929 MHz | 204.583 MHz |
| Near-zero-slack clock period | 3.691 ns | 4.888 ns |
| Setup WNS at 10 ns | +6.309 ns | +5.112 ns |
| Global critical data delay | 3.565 ns | 4.249 ns |
| CLB LUTs | 14,196 | 10,885 |
| CLB FFs | 8,273 | 8,151 |
| DSP48E2 | 67 | 67 |
| RAMB18 | 195 | 195 |
| RAMB36 | 0 | 4 |
| UltraRAM | 0 | 0 |
| Total block-RAM tiles | 97.5 | 101.5 |
| Full-ASIP cycles per image | 221,884 | 221,884 |

The change saves 3,311 LUTs (23.323%) and 122 FFs, at the cost of four BRAM
tiles and 24.489% lower estimated Fmax. At the rechecked 4.888 ns period,
WNS is 0.000 ns, WHS +0.045 ns and WPWS +1.682 ns, with zero failing
setup/hold/pulse-width endpoints. These are post-synthesis estimates, not
placed/routed or board-measured frequencies. The final instruction memory
is four RAMB36E2 primitives with a native
one-cycle read, DOA_REG=DOB_REG=0: the optional additional output register is
not enabled. The first automatic-mapping attempt selected unpipelined UltraRAM;
it was discarded and MCMem explicitly mapped to block RAM for this final run.

The new worst path is in the controller, not the DNN:

```
MCMem/memory_reg_bram_0/CLKBWRCLK
 -> CASDOUTPB[1] -> memory_reg_bram_1/DOUTPBDOUTP[1]
 -> instruction[17] (RA[1]) / compare RA with WB rd_reg2
 -> branch_ra_data WB/RF selection
 -> nonzero reduction / conditional branch decision
 -> PC_next[0] selection
 -> MCMem/memory_reg_bram_0/ADDRBWRADDR[4]
```

ADDRBWRADDR[4] is the physical BRAM address pin carrying logical word-address
bit zero, not logical PC bit four. The netlist connection trace confirms that
the data mux selects ALU_REG/Q[24] (registered WB) or RF read data; there is
still no live controller-ALU feedback path. The critical source instruction
bit is RA[1], not the former RTEMP hazard-comparator bit.

Data delay is 4.249 ns (2.473 ns logic, 1.776 ns estimated routing), eight
mapped levels including a BRAM cascade. Native BRAM clock-to-output/cascade
delay contributes 1.684 ns; branch/next-address logic must now meet the BRAM
address setup time (0.547 ns on this path), not a fabric PC-register setup.
The old asynchronous RAM/PC-to-issue data path is cut, but the replacement
BRAM-to-branch-to-BRAM loop is slower. Synchronous read is an area win here,
not a timing win. An optional extra BRAM output stage would change latency
and require a different fetch/control protocol; it was not added.

The DNN-only registered worst path is unchanged: MAC lane 4 DSP_OUTPUT to
NFC_partial_array[0] bit 15, 3.387 ns data delay, +6.575 ns slack at 10 ns.
The 64 MACs still have AREG=BREG=CREG=MREG=0 and PREG=1, no fabric CARRY8 in
the DSP C-input accumulation cone; the FC-tree and EX/WB pipeline cuts pass.
No instruction async-RAM primitives or synthesis black boxes remain in MCMem.

The actual clock-pin audit passes: 199 BRAM primitives, 2,112 distributed-RAM
leaves and 8,151 FFs (6,397 DNN), plus 64 MAC DSP result registers checked
separately. No negative-edge clock pins, latches, unclocked registers,
unconstrained internal maximum-delay endpoints or combinational loops were
reported. The older audit first flagged eight empty cell-level BRAM36 clock
properties; direct pin inspection and the exported functional netlist confirm
non-inverted sys_clk, not negative-edge storage. The checker now inspects
actual clock-pin IS_INVERTED values and does not accept missing values.

Final run_controller_posedge.ps1, fc_tree_retime_tb and posedge_flow_tb pass.
Full-ASIP 0973_hex and image_222 each complete 17 DNN launches and 1,536 pooled
stores in 221,884 total cycles. All eight IB/OB/OM/final CSV traces are byte
identical to both mac_fused_main and mul_stage_main, including cycle fields:
no added bubble, skipped/repeated instruction or changed computation observed.

Existing full-network golden-model mismatches remain: pooled/final counts
29/5 for 0973_hex and 63/4 for image_222. Independent actual-input dense
accumulation/ReLU checks pass, but full inference is still NOT a numerical
golden-model PASS. This fetch change introduces no observed regression and
does not repair those pre-existing mismatches.

MAC, DNN-core and controller-ALU RTL, assembly, canonical IP XCI files and
dsip.xpr are unchanged (the latter files' hashes match the starting baseline).
Synthesis changes are confined to the controller fetch and optional shared
memory mapping parameter. Existing tristate-conversion/TclStore warnings and
unconstrained external I/O remain; no formal equivalence, routed/board timing
or full multicore-system verification is claimed.

## Reproduce

From the workspace root:

```powershell
./source/hardware/tb/run_controller_posedge.ps1
```

From tmp/xloop/rtl_sim:

```powershell
./run_tree_retime_main.ps1 -LogPrefix sync_fetch_main
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source tree_retime_main_synth.tcl -log sync_fetch_main_vivado.log -journal sync_fetch_main_vivado.jou -tclargs sync_fetch_main
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source mac_fused_netlist_audit.tcl -log sync_fetch_main_clock_audit.log -journal sync_fetch_main_clock_audit.jou -tclargs sync_fetch_main
```

Results use the sync_fetch_main_ prefix. These standalone synthesis checks do
not alter dsip.xpr or its project runs. IP checkpoint settings are restored.
