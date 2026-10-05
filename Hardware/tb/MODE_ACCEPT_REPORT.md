# SINGLE-mode acceptance optimization, without added cycles

Historical snapshot: the subsequent fetch-address optimization is documented
in `LOOKAHEAD_ADDRESS_REPORT.md`; its timing supersedes this report.

2026-10-05. Applied to the main working RTL after the one-bit branch-predicate
change. This report describes the incremental mode-acceptance change, not the
previously reverted 300 MHz fetch/decode pipeline.

## Changes

- `rtl/controller/controller.sv`: SINGLE mode computes `accept_sdc`,
  `accept_vsync`, and `accept_end` directly from the opcode and `mode_ready`.
  The common qualifier retains instruction validity, start_flag, PC enable,
  end_flag, outstanding-memory checks and END writeback draining.
- Only these operand-free mode instructions bypass the general RAW/branch
  dependency qualifiers. Their decoder sets all register-use masks and CBR
  false; the new events therefore equal the former accepted-opcode events.
  Normal `issue_valid`, PC/fetch behavior, ALU/memory hazards and forwarding
  remain unchanged. No register, pipeline stage or issue bubble is added.
- `rtl/controller/ctrl_mode2.sv`: consume the three qualified one-bit events
  instead of decoding a globally masked six-bit opcode. The state transition
  bodies, reset, handshake handling and output assignments are unchanged.
  Opcode constants now live in the caller; unused local opcode parameters
  are removed along with the old opcode input.
- Modes ONE_ONE/TWO_TWO keep their existing masked-opcode interface and RTL.
  No assembly, DNN arithmetic, memory latency or project constraints are changed.
  The previously applied RF/WB nonzero flags and RAM_STYLE declaration remain.
- Testbenches add per-cycle equivalence checks against the previous opcode
  gating, plus unused-field collisions, memory waits and END-drain coverage.

## Functional verification

All five controller testbenches pass against the actual working RTL:

- 1,001 direct-event equivalence checks: SDC 4, VSYNC 4, END 2 accepted events;
  eight unused-field/tag matches, six mode memory-wait cycles and six END-drain
  cycles. None causes premature mode acceptance.
- ISA/pipeline test: 426 issues, 358 retirements, 31 transfers, four DNN launches;
  36 branch and 428 data dependency stalls. The extra two issued MOVLOs are
  directed test-program additions (one per run), not added architecture
  cycles. All arithmetic/branch reference checks pass.
- 1,001 RF/WB nonzero alignment checks; ALU 4,109 checks, 592 holds, two async
  resets; multicore modes 32 protocol checks; incoming memory 78 packets and
  all 64 lanes. Fetch/reset/restart tests pass in all three controller modes.
- Directed DNN tests: 8,364 FC-tree checks; 960 X-loop MAC checks, 12 stores
  and nine same-edge OB-forward cases, all passing.

Both full-image runs (`0973_hex` and `image_222`) pass the automated regression
against `branch_nonzero_main`. Each finishes in exactly 221,884 cycles, with
17 DNN launches, 1,536 pool stores, 26,387 CBR issues and 25,914 taken branches.
All eight IB/OB/OM/final CSV SHA256 hashes match, including cycle timestamps;
ordered output comparison also has zero mismatches. Added cycles: zero.
`TREE_RETIME_MAIN_REGRESSION_PASS` is reported by the regression script.

Both images retain the pre-existing numerical golden discrepancies:
29/63 row-15 pool and 5/4 final mismatches, respectively. Actual-input dense
accumulation and ReLU checks pass. This optimization preserves existing behavior; it is not a
claim that the full inference design is bug-free or a formal proof.

## Controller-only synthesis timing

Fresh Vivado 2025.1 OOC synthesis of production RTL, xck26-sfvc784-2LV-c,
Controller top, MCMEM_W=4096, MODEL=1, 32-bit instruction/data/address,
IS_FIRST_ROW/IS_FIRST_COL=1. Hierarchy rebuilt; clock applied after synthesis,
identically to the preceding comparison. No timing exceptions or path cuts.

| Metric | One-bit branch only | Plus mode acceptance |
| --- | ---: | ---: |
| Checked clock period | 4.580 ns | 4.362 ns |
| Estimated internal Fmax | 218.341 MHz | 229.253 MHz |
| CLB LUTs | 2,865 | 2,873 |
| Flip-flops | 1,723 | 1,723 |
| DSP / BRAM36 | 3 / 4 | 3 / 4 |

Approximately 5% higher Fmax, eight extra LUTs and zero extra registers.
At 4.362 ns, setup slack is 0.000 ns, hold +0.111 ns and pulse-width +1.604 ns;
no failing internal setup/hold/pulse endpoints, inferred latches, black boxes,
unclocked registers or unconstrained internal maximum-delay endpoints.
300 MHz still fails: WNS at 3.333 ns is -1.029 ns.

These are synthesis estimates, not placed/routed closure, whole-ASIP timing
or board-measured limits. External I/O delays and OOC clock-buffer context
remain unspecified. Modes 2/3 were functionally tested but not synthesized here.

## New critical path

`instruction[6]/RTEMP[0] -> EX1 rd_reg1 dependency comparison -> data_wait /
issue_valid -> next-PC selection -> instruction BRAM read address`.

Physical launch: `MCMem/memory_reg_bram_0/CLKBWRCLK`.
Physical capture: `MCMem/memory_reg_bram_0/ADDRBWRADDR[4]`, carrying logical
PC_next[0]. Equivalent paths reach the other three instruction BRAMs.
Data delay 3.723 ns: 2.319 ns logic and 1.404 ns estimated routing, six levels
including the BRAM cascade. Netlist pin aliases confirm instruction[6],
rd_reg1 (not rd_mid) and issue_valid along this path.

A timing query from instruction[6] to every mode-state D/CE endpoint returns
zero paths. The worst remaining mode-state path has 3.105 ns data delay and
+1.066 ns setup slack at 4.362 ns, so that FSM is no longer the bottleneck.

## Reproduction / evidence

From `C:/Users/nguye/Desktop/LAB/DSIP/source`:

```powershell
& ./hardware/tb/run_controller_posedge.ps1
```

From `C:/Users/nguye/Desktop/LAB/DSIP/tmp/controller_300`:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source timing.tcl -log mode_accept_main_vivado.log -journal mode_accept_main_vivado.jou -tclargs mode_accept_main 1
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source mode_accept_inspect.tcl -log mode_accept_main_inspect.log -journal mode_accept_main_inspect.jou
```

From `C:/Users/nguye/Desktop/LAB/DSIP/tmp/xloop/rtl_sim`:

```powershell
& ./run_tree_retime_main.ps1 -LogPrefix mode_accept_main -Baseline branch_nonzero_main
```

Evidence: `tmp/controller_300/mode_accept_main_*`,
`tmp/controller_posedge/*_tb.log`, `tmp/xloop/rtl_sim/mode_accept_main_*`.

Validated RTL SHA256:

- controller.sv: `CEE35FCBBE4844D5CBD1C83FDA5D25156547DC97B68287BD44D1730B845FE610`
- ctrl_mode2.sv: `51F2F36568084251456C49D149716CE19403B4ADD660E2F5C0FD3F2A6F30A132`
