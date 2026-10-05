# FC adder-tree retiming: working implementation

Applied and verified on 2026-10-05 in the main working directory.
This records the FC-tree retiming baseline, superseding the pre-retiming timing
in MUL_OUTPUT_PIPELINE.md. The later MAC fusion and latest working RTL timing
are documented in MAC_FUSION.md.

## RTL change

In dnn_core.sv, the original single full-sum NFC register has been replaced
by four 16-bit partial-sum registers after reduction level four:

```
EOA -> 64-to-4 reduction -> NFC partial registers -> 4-to-1 reduction + optional accumulation -> POFC register
```

The partial registers use the existing pipe_valid[3] enable, and POFC keeps
pipe_valid[4]. Register reset and clocking remain asynchronous active-high reset
and posedge clk. No extra pipeline stage, bubble, instruction delay or assembly
change is needed. All valid, control, address and END pipelines are unchanged.
The original POFC feedback register and accumulation semantics are preserved.

Each group sum wraps to DATA_W bits before capture. This yields the same
final DATA_W-bit result as truncating the original full sum, including negative
encodings and overflow. NFC_data_rd is now the combinational sum of the
registered groups; its sole production consumer is still POFC_wr_data.

Production executable RTL matches the tested temporary overlay exactly, ignoring
comments and whitespace. Neither the controller nor its forwarding policy changed.

## Fresh production synthesis

Vivado 2025.1, xck26-sfvc784-2LV-c, ASIP/SINGLE, standalone out-of-context,
rebuilt hierarchy, 10 ns sys_clk. All source files were read directly from
the production asip_files.f; no RTL overlays were supplied.

| Metric | Before retiming | Working RTL |
|---|---:|---:|
| Estimated internal Fmax | 257.334 MHz | 265.534 MHz |
| Checked near-zero-slack period | 3.886 ns | 3.766 ns |
| WNS at 10 ns | +6.114 ns | +6.234 ns |
| Worst full-ASIP data-path delay | 3.882 ns | 3.764 ns |
| CLB LUTs | 13,316 | 13,400 |
| CLB flip-flops | 9,169 | 9,217 |
| DSPs | 67 | 67 |
| RAMB18 primitives | 195 | 195 |

Fmax increases 3.186%; resource cost is +84 LUTs and +48 FFs.
The new critical path is not the adder tree:

```
dnn_core/CONV_slot4_reg[3]_rep__4
 -> weight-selection mux
 -> MAC multiply and accumulation
 -> dnn_core/EOA_array[10].EOA/dout_reg[15]
```

Critical data delay is 3.764 ns (2.919 ns logic + 0.845 ns estimated routing),
with 10 mapped logic levels. The retimed tree head is 3.073 ns; its tail into
POFC is 1.869 ns; POFC feedback is 1.842 ns.

At 3.766 ns, WNS is 0.000 ns, WHS +0.045 ns and WPWS +1.121 ns, with zero
reported setup/hold/pulse-width failing endpoints. Clock audit checks 9,217
ASIP FFs, 195 BRAM primitives and 4,672 distributed-RAM leaves; all checked
storage clocks are non-inverted, with zero latches. There are 7,405 DNN FFs.

Structural checks confirm 1,024 EOA FFs, 64 NFC partial FFs, 16 POFC FFs and no
old full-sum NFC register. No combinational EOA-to-POFC path bypasses the
partial registers. Controller pipeline-cut checks pass. No synthesis black
boxes, combinational loops, unclocked register pins or unconstrained internal
maximum-delay endpoints were found.

These are post-synthesis estimates, not post-route or board-measured Fmax.
External I/O delays and HD.CLK_SRC remain unspecified in the standalone OOC
check. Existing tristate-conversion and TclStore warnings persist.

## Production-RTL verification

- fc_tree_retime_tb: PASS, 8,364 independent arithmetic checks, including
  sign/overflow boundaries, all 64 sparse-lane positions, 8,192 deterministic
  randomized vectors, independently enabled NFC/POFC captures, consecutive
  accumulation, holds, asynchronous reset and no falling-edge output changes.
  The production test is self-contained and uses test-only upstream EOA/control
  forces, not replacement arithmetic or forced NFC/POFC outputs.
- The public run_posedge.ps1 -Testbench fc_tree_retime_tb entry point also passes.
- Existing public-port posedge_flow_tb: PASS, 960 MAC checks, 12 stores,
  nine same-edge OB bypasses, three completed runs; X-loop flow, memory timing,
  holds, masks, END-store alignment, idle, restart and reset pass.
- Full ASIP runs for 0973_hex and image_222: each completes 17 DNN launches
  and 1,536 pooled stores in 221,884 total cycles (221,033 active cycles).
  There are **zero extra cycles**.
- All eight IB/OB/OM/final CSV traces are byte-identical to mul_stage_main:
  same ordered values, addresses and cycle fields. Per image, checks cover
  8,704 IB rows, 6,169 OB rows, 1,536 OM rows and 10 final rows.
- Independent actual-input dense accumulation and ReLU checks report zero
  errors for both images.
- Existing full-network golden mismatches are unchanged: pooled/final counts
  are 29/5 for 0973_hex and 63/4 for image_222. Full inference is therefore
  still not a golden-model PASS. No assembly fix or exhaustive/formal,
  physical implementation, multicore or board verification is claimed.

SHA256 checks confirm unchanged controller/ALU RTL, RTL file list, instruction
images, all three canonical XCI files and dsip.xpr. The production DNN RTL hash
after deployment is 22B4DC80F23E6FECAD053234D3F3BF59476AEC19AA8799EE72EBF80E4A13DDC1.

## Reproduce

Focused production regression, from the workspace root:

```powershell
./source/hardware/tb/run_posedge.ps1 -Testbench fc_tree_retime_tb
./source/hardware/tb/run_posedge.ps1 -Testbench posedge_flow_tb
```

Full production regression and synthesis, from tmp/xloop/rtl_sim:

```powershell
./run_tree_retime_main.ps1
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source tree_retime_main_synth.tcl -log tree_retime_main_vivado.log -journal tree_retime_main_vivado.jou -tclargs tree_retime_main
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source tree_retime_main_audit.tcl -log tree_retime_main_clock_audit.log -journal tree_retime_main_clock_audit.jou -tclargs tree_retime_main
```

Raw deployment results use the tree_retime_main_ prefix under tmp/xloop/rtl_sim.
The older tree_retime_ overlay results remain available for comparison.
