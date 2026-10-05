# Dependency / issue-valid optimization

2026-10-05. Applied in the main working RTL on top of the branch-predicate,
SINGLE-mode acceptance and look-ahead-address changes. This report supersedes
the current-timing snapshot in LOOKAHEAD_ADDRESS_REPORT.md. No assembly or DNN
datapath changes are included in this step.

## Changes applied

1. `rtl/controller/dec_ctrl.sv`: add three source-use metadata bits to the
   existing ISA decoder: RA, RB, and RD/RTEMP. Memory instructions use all four
   registers; immediate instructions ignore overlapped RB/RTEMP fields. CBR's
   RA dependency remains represented separately by its CBR flag. Existing
   opcode operations and controls are unchanged.
2. `rtl/controller/controller.sv`: decode those source-use bits and CBR during
   program upload and store them with the instruction. Firmware still supplies
   exactly the same 32-bit words; no assembler or binary-format change is needed.
3. For the current 32-bit configuration, replace the depth-cascaded instruction
   RAM with four parallel byte-plus-metadata banks. Each bank stores nine bits
   at each PC address. All banks share clock, addresses and read/write enables,
   so the instruction and metadata update or hold together. This removes the
   BRAM cascade without adding a fetch register, latency or instruction bubble.
   Vivado confirms four RAMB36E2s, READ_WIDTH_B=9, CASCADE_ORDER_B=NONE for each.
   Native 4Kx9 geometry is documented in
   [AMD UG573](https://docs.amd.com/r/en-US/ug573-ultrascale-memory-resources/Block-RAM-Summary).
4. Replace repeated late comparisons of source-register numbers against EX1
   and EX2 destination numbers with a registered 32-bit pending-write scoreboard.
   Dependency detection selects `rf_pending[source]`, qualified by stored
   source-use metadata. CBR selects `rf_pending[ra]` for branch_wait.
5. Extend the independent pipeline/reference and synchronous-fetch tests;
   add `controller_predecode_tb.sv` and include it in the controller test runner.

The scoreboard update is:

```systemverilog
issued_dest_mask = (issue_valid && rf_wen && rd != 0) ? (32'b1 << rd) : 0;
ex1_dest_mask <= issued_dest_mask;
rf_pending <= ex1_dest_mask | issued_dest_mask;
```

After each edge, rf_pending represents exactly the accepted writers currently
in EX1 or EX2. Both stages continue to drain during an issue stall. Rebuilding
the OR every edge, rather than clearing a bit when one writer leaves, handles
two simultaneous writers to the same register correctly. R0 is excluded. WB is
excluded because its registered data and branch predicate already bypass to
decode with newest-writer priority. Asynchronous reset clears both masks.

This shortens the dependency implementation; it does NOT eliminate legitimate
RAW waits. All existing instruction-valid, start, PC/mode-ready, memory-wait,
END-drain, data-wait and branch-wait qualifiers remain in issue_valid.
No new execution stage, branch flush, clock-edge change or extra cycles were
introduced. Existing one-bit RF/WB branch predicates and look-ahead PC remain.

The non-32-bit parameter fallback retains the original memory organization and
uses live metadata decoding. That fallback was not separately simulated;
the current 32-bit configuration was tested in all three controller modes.

## Verification

All six benches in `run_controller_posedge.ps1` pass on the working RTL:

- ISA/pipeline: 426 issued, 358 retired, 31 transfers and four launches;
  36 branch stalls, ten taken and 14 not-taken CBRs. Data stalls remain 428
  (RA 390, RB 52, RD 4, RTEMP 16; overlapping categories).
- At every reference cycle, all 32 EX1-mask bits and all 32 pending-scoreboard
  bits are independently checked against reference producer packets. Coverage
  includes overlapping same-register writers, R0, bubbles, drain and reset.
  RF/WB predicate and direct mode-acceptance checks remain 1,001 each.
- ALU: 4,109 checks, 592 holds and two asynchronous resets.
- ONE_ONE/TWO_TWO mode protocols: 32 checks. Memory controller: 78 incoming
  packets, including all 64 lanes, broadcasts, default outputs and reset abort.
- Synchronous fetch and metadata alignment: SINGLE/ONE_ONE/TWO_TWO have
  42/48/51 enabled reads and 80/139/191 holds; independent old-address
  equivalence remains checked. Branch/wrap, stale and invalid words, idle
  upload, repeated start, END/restart and active reset cases pass.
- New predecode bench: all 64 opcodes, 98 metadata checks, 66 issues and two
  read-first collision/restart checks. A same-address bootstrap read/write
  observes the old instruction AND old metadata; reset/restart reads the new
  word and matching metadata. This is metadata/protocol-preservation coverage,
  not a claim that every arbitrary ordering of mode instructions is supported.

Directed DNN tests also pass: 8,364 FC-tree checks, 960 X-loop MAC checks,
12 stores and nine same-edge OB-forward cases.

Both full-image runs, `0973_hex` and `image_222`, finish in 221,884 cycles each,
with 17 DNN launches, 1,536 pool stores, 26,387 CBR issues and 25,914 taken
branches. All eight IB/OB/OM/final CSV SHA256 hashes match the immediately
preceding `lookahead_addr_main` baseline, including cycle timestamps. Ordered
trace comparison also reports zero mismatches. Added cycles: zero.
The runner finishes with `TREE_RETIME_MAIN_REGRESSION_PASS`.

The pre-existing full-inference golden discrepancies are unchanged: the two
images retain 29/63 row-15 pool mismatches and 5/4 final mismatches respectively.
Actual-input dense accumulation and ReLU checks pass. These changes preserve
existing behavior; neither simulation nor this report proves the whole DNN
design bug-free or its full numerical golden result correct.

## Controller-only synthesis timing

Fresh Vivado 2025.1 OOC synthesis, xck26-sfvc784-2LV-c, Controller top,
MODEL=1, MCMEM_W=4096, 32-bit instruction/data/address, first row/column=1.
Same synthesis and clock/report flow as the immediate baseline; no temporary
datapath cuts, false paths or multicycle exceptions.

| Metric | Look-ahead-address baseline | Plus banked predecode / scoreboard |
| --- | ---: | ---: |
| Checked clock period | 4.308 ns | 3.737 ns |
| Estimated internal Fmax | 232.126 MHz | 267.594 MHz |
| CLB LUTs | 2,872 | 2,963 |
| Flip-flops | 1,723 | 1,784 |
| DSP / BRAM36 | 3 / 4 | 3 / 4 |
| Added image cycles | 0 | 0 |

Estimated Fmax improves 15.28%, with +91 LUTs and +61 FFs, unchanged DSP/BRAM
counts. At 3.737 ns: setup slack 0.000 ns, hold +0.109 ns, pulse-width +1.291 ns;
no failing internal setup/hold/pulse endpoints, black boxes, inferred latches,
unclocked registers or unconstrained internal maximum-delay endpoints.
At 300 MHz (3.333 ns), WNS remains -0.404 ns: 300 MHz has NOT been achieved.

These are controller-only post-synthesis estimates, not routed/full-ASIP timing
or a guaranteed board clock. External I/O delays and OOC clock-buffer context
are unspecified. All three modes were simulated; only SINGLE was synthesized
in this comparison. The measured gain is for the combined change, not an
isolated measurement of either scoreboard or banking alone.

## Remaining critical path

`instruction[17] / RA[1] -> indexed RF nonzero-flag selection -> WB-predicate
selection and branch decision -> next-PC selection -> instruction BRAM address`.

Netlist inspection confirms the source is byte bank 2, output bit 1, and that
the intermediate muxes consume rf_nonzero bits. The following logic combines
wb_nonzero, WB-match selection, BR and stored CBR; the final LUT combines this
branch result with PC[1:0], start/end and target bit 1.

Physical source clock:
`instruction_banks.bank_mem[2].MCMem/memory_reg_bram_0/CLKBWRCLK`;
launch data output: `DOUTBDOUT[1]`.
Physical destination:
`instruction_banks.bank_mem[0].MCMem/memory_reg_bram_0/ADDRBWRADDR[4]`
(logical next-PC bit 1; equivalent worst endpoints in the other banks).
Data delay is 3.098 ns, consisting of 1.909 ns logic and 1.189 ns estimated
routing, five logic levels, with no instruction-BRAM cascade.

The worst sampled path THROUGH the issue_valid driver now has +0.625 ns slack
at 3.737 ns, to ALUOPREG's enable. Its data delay is 2.921 ns. Dependency/issue
control is no longer the overall limiting path, although it still consumes
timing budget. The four-bank mapping and critical-cell pin/net aliases were
checked against the saved synthesis netlist (`ISSUE_SCOREBOARD_INSPECTION_PASS`).
The diagnostic initially searched for an optimized-away logical alias;
querying the surviving byte-bank alias repaired the diagnostic only, with no
RTL change or resynthesis.

## Reproduction / evidence

Controller tests, from `C:/Users/nguye/Desktop/LAB/DSIP/source`:

```powershell
& ./hardware/tb/run_controller_posedge.ps1
```

Synthesis/inspection, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/controller_300`:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source timing.tcl -log issue_scoreboard_main_vivado.log -journal issue_scoreboard_main_vivado.jou -tclargs issue_scoreboard_main 1
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source issue_scoreboard_inspect.tcl -log issue_scoreboard_main_inspect.log -journal issue_scoreboard_main_inspect.jou
```

Full regression, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/xloop/rtl_sim`:

```powershell
& ./run_tree_retime_main.ps1 -LogPrefix issue_scoreboard_main -Baseline lookahead_addr_main
```

Evidence: `tmp/controller_300/issue_scoreboard_main_*`,
`tmp/controller_posedge/*_tb.log`, `tmp/xloop/rtl_sim/issue_scoreboard_main_*`.
`git diff --check` passes (only normal Git line-ending warnings).

Validated RTL SHA256:

- controller.sv: `5B09437C47B4B38794EE146FF39667BF582079E1520BF95B09F01BFC12275454`
- dec_ctrl.sv: `ECE98ACCF661042FD1E1752A283861D15D46D00DAF34C5C215F6FA83272D51C3`
