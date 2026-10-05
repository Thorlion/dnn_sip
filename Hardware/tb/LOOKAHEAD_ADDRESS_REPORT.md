# Look-ahead instruction address, without added cycles

2026-10-05. Applied on top of the one-bit branch predicates and SINGLE-mode
acceptance optimization. This report describes the incremental address change.

Historical snapshot: the subsequent banked-predecode/scoreboard change and its
current timing are documented in [ISSUE_SCOREBOARD_REPORT.md](ISSUE_SCOREBOARD_REPORT.md).

## Changes and correctness argument

- `rtl/controller/controller.sv`: replace the `issue_valid` qualifier in the
  combinational PC_next calculation with `start_flag`. While running, PC_next
  is the candidate branch target or PC+1 even if the current instruction stalls.
  Before start_flag, retain PC so bootstrap reads word zero. Preserve the
  end_flag address-zero selection and the original asynchronous PC reset.
- `instruction_read_en` is unchanged. Both the PC register and synchronous
  instruction BRAM output update only when this enable is asserted. Therefore
  a changed candidate address during a stall cannot fetch or issue a new word.
- On an issue edge, start_flag=1 and the candidate equals the old selected next
  address. On a bootstrap edge, start_flag=0 and it equals the old held PC.
  On all other edges, the disabled read makes the candidate irrelevant.
  Reset/END cleanup remains in the PC register's existing higher-priority cases.
- No register, pipeline stage, instruction bubble, clock-edge change, memory
  latency change, assembly change or hazard/branch policy change is introduced.
  Modes SINGLE/ONE_ONE/TWO_TWO all use this same fetch-address optimization.
- `controller_sync_fetch_tb.sv` adds an independent reconstruction of the old
  issue-gated address. Every enabled read must match it. Coverage also requires
  candidate-address changes during stalls while PC/instruction still hold.

## Functional verification

All five controller testbenches pass against the actual working RTL. The
controller ISA/pipeline results remain 426 issues, 358 retirements, 31 transfers,
four launches, 36 branch stalls and 428 data stalls. RF/WB predicate checks,
mode-event equivalence, ALU, memory arbitration and multicore protocols pass.

| Mode | Enabled-address equivalence checks | Bootstrap reads | Holds with a different candidate |
| --- | ---: | ---: | ---: |
| SINGLE | 42 | 5 | 48 |
| ONE_ONE | 48 | 5 | 105 |
| TWO_TWO | 51 | 5 | 156 |

Tests cover branch targets, PC wrap, dependency stalls, delayed handshakes,
invalid instructions, repeated start, idle program updates, END/restart and
asynchronous reset during execution. Directed DNN tests also pass: 8,364 FC-tree
checks, 960 X-loop MAC checks, 12 stores and nine same-edge OB-forward cases.

Both full-image runs (`0973_hex` and `image_222`) pass the automated regression
against `mode_accept_main`. Each finishes in exactly 221,884 cycles, with 17
DNN launches, 1,536 pool stores, 26,387 CBR issues and 25,914 taken branches.
All eight IB/OB/OM/final CSV SHA256 hashes match, including cycle timestamps;
ordered output comparison also has zero mismatches. Added cycles: zero.
The script reports `TREE_RETIME_MAIN_REGRESSION_PASS`.

Both images retain the pre-existing numerical golden discrepancies:
29/63 row-15 pool and 5/4 final mismatches, respectively. Actual-input dense
accumulation and ReLU checks pass. This change preserves existing behavior; simulation is not
formal proof or a claim that the complete inference design is bug-free.

## Controller-only synthesis timing

Fresh Vivado 2025.1 OOC synthesis, xck26-sfvc784-2LV-c, Controller top,
MCMEM_W=4096, MODEL=1, 32-bit instruction/data/address, first row/column 1.
Same timing script and synthesis settings as the preceding comparison.
No false paths, multicycle constraints or temporary datapath cuts.

| Metric | Mode acceptance baseline | Plus look-ahead address |
| --- | ---: | ---: |
| Checked clock period | 4.362 ns | 4.308 ns |
| Estimated internal Fmax | 229.253 MHz | 232.126 MHz |
| CLB LUTs | 2,873 | 2,872 |
| Flip-flops | 1,723 | 1,723 |
| DSP / BRAM36 | 3 / 4 | 3 / 4 |

Fmax estimate improves approximately 1.25%, with one fewer LUT and no extra
registers. At 4.308 ns: setup slack 0.000 ns, hold +0.111 ns, pulse-width
+1.577 ns; no failing internal setup/hold/pulse endpoints, black boxes, inferred
latches, unclocked registers or unconstrained internal maximum-delay endpoints.
300 MHz still fails: WNS at 3.333 ns is -0.975 ns.

These are controller-only synthesis estimates, not routed timing or a guaranteed
board clock. External I/O delays and OOC clock-buffer context remain unspecified.
All three modes were simulated; only SINGLE is included in this synthesis run.

## New critical path

`instruction[6]/RTEMP[0] -> EX1 rd_reg1 dependency comparison -> data_wait /
issue_valid -> instruction_read_en -> instruction BRAM read-enable pin`.

Physical source: `MCMem/memory_reg_bram_0/CLKBWRCLK`.
Physical destination: `MCMem/memory_reg_bram_2/ENBWREN`; BRAM3 has an equivalent
worst path. Data delay 3.754 ns: 2.295 ns logic and 1.459 ns estimated routing,
six levels including the instruction-BRAM cascade.

The improvement is modest because the same hazard chain must still produce
the BRAM read enable. The previous worst address endpoint had 0.547 ns setup;
the new enable endpoint has 0.462 ns setup. The raw worst data delay is actually
0.031 ns longer, but the lower endpoint setup requirement saves 0.054 ns of
required clock period. Raw data delay alone does not determine Fmax.

Netlist inspection confirms zero timing paths through the issue_valid driver
to any BRAM read-address pin, while paths to the read-enable pins remain.
The diagnostic initially used an invalid combinational launch boundary;
switching the query from `-from` to `-through` corrected it. The same synthesis
checkpoint was reused; no RTL was changed to repair that diagnostic.

## Reproduction / evidence

Controller tests, from `C:/Users/nguye/Desktop/LAB/DSIP/source`:

```powershell
& ./hardware/tb/run_controller_posedge.ps1
```

Synthesis, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/controller_300`:

```powershell
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source timing.tcl -log lookahead_addr_main_vivado.log -journal lookahead_addr_main_vivado.jou -tclargs lookahead_addr_main 1
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source lookahead_addr_inspect.tcl -log lookahead_addr_main_inspect.log -journal lookahead_addr_main_inspect.jou
```

Full regression, from `C:/Users/nguye/Desktop/LAB/DSIP/tmp/xloop/rtl_sim`:

```powershell
& ./run_tree_retime_main.ps1 -LogPrefix lookahead_addr_main -Baseline mode_accept_main
```

Evidence: `tmp/controller_300/lookahead_addr_main_*`,
`tmp/controller_posedge/*_tb.log`, `tmp/xloop/rtl_sim/lookahead_addr_main_*`.

Validated controller.sv SHA256:
`CBFE3C0D72BFD016D65701F99E788C53F7202F82E3704D3F27705E5AE9E80D5D`.
