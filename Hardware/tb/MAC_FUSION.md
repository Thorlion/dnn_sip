# Fused DSP MAC: working implementation

Applied on 2026-10-05 to the working directory, based on main commit cef3738.
This records the MAC-fusion synthesis baseline, superseding FC_TREE_RETIMING.md.
The subsequent controller-fetch change and latest timing are documented in
SYNC_INSTRUCTION_FETCH.md. MAC fusion is committed in b858750.

## RTL change and numerical behavior

Only the executable arithmetic in rtl/dnn_core/mac.sv changes. The MAC still
selects zero/local/broadcast input, weight/fixed-point unity, and one of
zero/MLO/self-EOA/neighbor-EOA as the accumulation operand.

Previously the product was scaled/truncated before adding the accumulator:

```
selected operands -> DSP multiply -> product[23:8] -> fabric add -> EOA register
```

The new expression adds a widened, aligned accumulator before scaling:

```
selected operands -> DSP multiply-add -> sum[23:8] -> EOA result register
```

For the production 16-bit Q8.8 configuration:

```
raw_sum = signed(input) * signed(weight) + (sign_extend(accumulator) << 8)
result  = raw_sum[23:8]
```

The accumulator is widened to 32 bits BEFORE shifting. Since its aligned
fractional bits are zero, the original and fused expressions have identical
16-bit results, including negative products, fractional truncation and modular
overflow. No saturation, rounding, extra precision in the stored EOA result,
instruction change or extra pipeline stage is introduced. The original case
defaults for unknown selectors are retained.

The mac_result signal has USE_DSP=yes to encourage multiply-add inference.
The module ports and the DNN/control RTL remain unchanged, as do EOA enables,
valid/address/END pipelines, self/neighbor feedback and the FC-tree retiming.

## Actual synthesized mapping

Vivado inferred 64 C+A*B DSP48E2 MACs, one per lane. All 64 have AREG=BREG=CREG=
MREG=0 and PREG=1. The existing EOA result boundary was packed into DSP PREG;
it was not supplemented by a new stage. All 64 live result-register clocks
are non-inverted sys_clk. Consequently the old EOA_array/.../dout_reg fabric
names no longer exist in this netlist, although the EOA RTL is unchanged.

A fan-in audit of all 1,024 relevant DSP C-input bits finds no fabric CARRY8
in the accumulation-input cone. Total CARRY8 count falls from 233 to 105.
Some remaining FC reduction carry chains are assigned MAC hierarchy names
by rebuilt synthesis, so a hierarchy-name search alone does not classify
them as MAC accumulation adders.

The old structural checker initially rejected the changed EOA storage names.
It was updated to inspect DSP result slices and output-register configuration.
The final synthesis and mapping/clock checks pass. There are 64 NFC partial
FFs and 16 POFC FFs, no old full-sum NFC FFs, and no EOA-to-POFC combinational
path bypassing the NFC register boundary. Controller pipeline-cut checks pass.

## Synthesis timing and resources

Vivado 2025.1, xck26-sfvc784-2LV-c, top ASIP/SINGLE, standalone out-of-context,
rebuilt hierarchy, initially 10 ns sys_clk; production asip_files.f and IP.

| Metric | Before MAC fusion | Fused working RTL |
|---|---:|---:|
| Estimated internal Fmax | 265.534 MHz | 270.929 MHz |
| Near-zero-slack clock period | 3.766 ns | 3.691 ns |
| Setup WNS at 10 ns | +6.234 ns | +6.309 ns |
| Global critical data delay | 3.764 ns | 3.565 ns |
| CLB LUTs | 13,400 | 14,196 |
| CLB FFs | 9,217 | 8,273 |
| DSP48E2 | 67 | 67 |
| RAMB18 | 195 | 195 |
| CARRY8 | 233 | 105 |

Fmax improves 2.032%, with no additional cycles. The area trade-off is
796 more LUTs (+5.940%) and 944 fewer fabric FFs; DSP and BRAM counts are
unchanged. Removing fabric accumulation adders did NOT reduce total LUTs
in this synthesized mapping.

At the rechecked 3.691 ns clock, WNS is 0.000 ns, WHS +0.045 ns and WPWS
+1.083 ns, with zero reported setup/hold/pulse-width failing endpoints.
The clock audit passes for all 8,273 fabric FFs (6,397 under the DNN), 195
BRAM primitives and 4,672 distributed-RAM leaves, plus the 64 active MAC
DSP result registers checked separately. There are no latches, unclocked
registers, unconstrained internal maximum-delay endpoints or combinational
loops in the reported netlist.

The global critical path is now in the controller:

```
controller/PC_reg_rep[1]_rep__9/Q
 -> asynchronous instruction-memory read
 -> instruction decode / issue-control logic
 -> controller/mode_ctrl/state_reg[0]/CE
```

Its data delay is 3.565 ns: 1.563 ns logic and 2.002 ns estimated routing,
11 mapped levels. CE is a flip-flop clock-enable input, not another clock.

The DNN-only worst registered path, including the DSP PREG registers, is now
the FC-tree head: MAC lane 4 DSP_OUTPUT -> NFC_partial_array[0] bit 15.
Data delay is 3.387 ns, slack +6.575 ns at 10 ns, effective period 3.425 ns
(analytical equivalent 291.971 MHz). This is not a tested standalone-DNN or
routed frequency. The worst path into a MAC result register is 2.606 ns data
with +7.387 ns slack at 10 ns. It no longer limits the full ASIP.

These are post-synthesis estimates, NOT placed/routed or board-measured Fmax.
External I/O delays and HD.CLK_SRC are not specified in this OOC check.
Existing tristate-conversion and TclStore warnings remain; no black boxes
were found. Physical implementation, formal equivalence and multicore
verification are not claimed.

## Verification

- mac_fused_tb: PASS, 1,677,440 comparisons against the original multiply,
  then scale, then accumulate order. DATA_W=16 and DECIMAL_BIT=0/4/8/15;
  all 32 known selector combinations, 4,913 boundary operand vectors,
  8,192 deterministic random vectors and the unknown acc_sel default.
- posedge_flow_tb: PASS, 960 MAC-state checks, 12 stores, nine same-edge OB
  bypasses and three completed runs. Public-port tests cover X-loop broadcast,
  held weights, self/neighbor accumulation, lane masks, memory timing, idle,
  reset/restart and END-store alignment in production and debug cores.
- fc_tree_retime_tb: PASS, 8,364 arithmetic checks with captures, accumulation,
  holds and asynchronous resets.
- relu_activation_tb: PASS, 262,153 checks, all 65,536 encodings, both bias
  sources and former LUT-select settings, valid holds and resets in both cores.
- Full ASIP: 0973_hex and image_222 each complete 17 DNN launches and 1,536
  pooled stores in 221,884 total cycles, exactly as before. All eight
  IB/OB/OM/final CSV traces are byte-identical to both tree_retime_main and
  mul_stage_main, including values, addresses and cycle fields.
- Independent actual-input dense accumulation and ReLU checks pass for both
  images. Existing full-network golden-model mismatches are unchanged:
  pooled/final counts 29/5 for 0973_hex and 63/4 for image_222. Full inference
  is therefore still NOT a golden-model PASS; this change introduces no
  observed regression and does not claim to fix those earlier mismatches.

Controller/ALU/DNN-core RTL, IP XCI configuration and dsip.xpr hashes remain
unchanged. MAC RTL SHA256:
ED46EF6254772C80B4592FFADB6D39DD4561018EE5643F99DED5754FDDAC0CC1.

## Reproduce

From the workspace root:

```powershell
./source/hardware/tb/run_posedge.ps1 -Testbench mac_fused_tb
./source/hardware/tb/run_posedge.ps1 -Testbench posedge_flow_tb
./source/hardware/tb/run_posedge.ps1 -Testbench fc_tree_retime_tb
./source/hardware/tb/run_posedge.ps1 -Testbench relu_activation_tb
```

From tmp/xloop/rtl_sim:

```powershell
./run_tree_retime_main.ps1 -LogPrefix mac_fused_main
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source tree_retime_main_synth.tcl -log mac_fused_main_vivado.log -journal mac_fused_main_vivado.jou -tclargs mac_fused_main
& 'D:/Vivado/2025.1/Vivado/bin/vivado.bat' -mode batch -source mac_fused_netlist_audit.tcl -log mac_fused_main_clock_audit.log -journal mac_fused_main_clock_audit.jou
```

Reports and the saved netlist use the mac_fused_main_ prefix in that directory.
The near-zero-slack clock is rechecked in memory; project runs and dsip.xpr
are not changed. Canonical IP checkpoint settings are restored after synthesis.
