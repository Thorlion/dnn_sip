# Single-system integration

`tb/single_system_top.sv` contains one master core, one slave core, DMA0, DMA1
and both DMA address decoders. OM remains outside the DUT in
`tb/single_system_tb.sv`.

The CONV1–5 weight prefetch plans and XSim cycle counts are recorded in
[WEIGHT_PREFETCH.md](WEIGHT_PREFETCH.md).

```text
Master DMA_CONFIG --> DMA0 CSRs / DMA1 CSRs
Master SCR --------> slave start + instruction-indexed PC

OM async read --> DMA0 --> write decoder --> IB / KSP / BSP / slave IMEM
OM clocked write <-- DMA1 <-- read decoder + synchronous slave OB read
```

## Full 96-filter CONV1

Run from `source`:

```powershell
python new_sw/core_instruction/conv1_full_program.py
python new_hw/script/run.py test=conv1_full
```

This workload uses `master_mem/conv1_master_imem.mem` and
`slave_mem/conv1_slave_imem.mem`. For manual simulation, use
`single_conv1_tb` as the testbench top and stage both programs alongside the
Caffe assets `om_mem/Conv1/input_img.mem` and `om_mem/Conv1/conv1_weight.mem`, using
their basenames. The full test instantiates 2 MiB of OM and checks all
290,400 output words against the BGR image and Caffe weights. The input crop
is 224 × 224 with implicit padding of 2 in the slave schedule.

The master computes four output rows per tile, with three rows in the final
tile. Each tile uses two filter batches. OSP addresses 0–219 hold filters
0–63, and addresses 256–475 in lanes 0–31 hold filters 64–95. The slave
accumulates all three input channels in each batch. The master alternates
batch order across tiles so only lanes 0–31 need their weights reloaded
between the two batches. KSP buffer 0 holds input-channel offsets 0–120
and 128–248. Buffer 1 holds offsets 0–120 for the middle input channel.
DMA0 prefetches the next input row into the other IB buffer.

The result contains raw signed Q8.8 dot products. The workload loads zero
into BSP[0] so the existing output adder passes the OSP value through.
For hardware execution, supply zero at OM word `0x3D820`, immediately after
the last weight at `0x3D81F`. The dummy LUT passes the value through to OB.

DMA1 alternates OB buffers and drains 283 full 1,024-word blocks, then
the final 608 words. An OB block can span two OSP tiles. The feature map is
pixel-major, with filters 0–95 adjacent at each pixel.

```text
OM[0x40000 + (y*55 + x)*96 + filter]
```

The last word is `0x86E5F`. The checker confirms sequential OM writes,
correct DMA1 block boundaries, and separation of OB reads and writes.
The exported `conv1_feature_map.mem` and the result log are in
`DSIP/tmp/verilator/conv1_full/`.

## Grouped CONV2

Run from `source` in this order. The preparation script uses the raw
`55 × 55 × 96` CONV1 dump from the first run by default.

```powershell
python new_hw/script/run.py test=conv1_full
python new_sw/core_instruction/conv2_prepare_input.py
python new_sw/model/script/bin_to_mem.py --input new_sw/model/alexnet_q88/conv2_weight.bin --output new_hw/tb/single_system/om_mem/Conv2/conv2_weight.mem
python new_sw/core_instruction/conv2_program.py
python new_hw/script/run.py test=conv2_full
```

The preparation script adds the quantized Caffe CONV1 bias, applies ReLU
and five-channel local response normalization, then pools with a 3 × 3
window and stride 2. It writes `27 × 27 × 96` signed Q8.8 samples in CHW
order. The script starts from the DSIP dot products, including the existing
Q8.8 truncation and wrap, and quantizes again after pooling.

CONV2 uses 256 filters of shape `48 × 5 × 5`, stride 1, padding 2, and two
groups. Filter batches 0 and 1 read channels 0–47. Batches 2 and 3 read
channels 48–95. Four OSP regions hold up to four output rows for each batch.
DMA0 loads eight input-channel slices per KSP bank and prefetches image rows
into alternating IB banks. CONV2 exports raw dot products using the zero
bias operand.

| CONV2 OM data | Word addresses | Words |
| --- | --- | ---: |
| Prepared input | `0x10000..0x2115F` | 69,984 |
| Caffe weights | `0x35000..0x7FFFF` | 307,200 |
| Zero-bias operand | `0x80000` | 1 |
| Pixel-major output | `0x90000..0xBD8FF` | 186,624 |

DMA1 alternates OB banks and writes 182 full blocks and a 256-word tail.
Output `y, x, filter` is at `0x90000 + (y*27 + x)*256 + filter`.
The checker compares every output word with a grouped fixed-point reference
and exports `conv2_feature_map.mem` in `DSIP/tmp/verilator/conv2_full/`.
For manual simulation, select `single_conv2_tb` from `tb/single_conv2_tb.sv` and
stage the two `conv2_*_imem.mem` images, `conv2_input.mem`, and
`conv2_weight.mem` by basename.

## CONV3

Run these commands from `source` after the CONV2 simulation has produced its
feature map.

```powershell
python new_sw/core_instruction/conv3_prepare_input.py
python new_sw/model/script/bin_to_mem.py --input new_sw/model/alexnet_q88/conv3_weight.bin --output new_hw/tb/single_system/om_mem/Conv3/conv3_weight.mem
python new_sw/core_instruction/conv3_program.py
python new_hw/script/run.py test=conv3_full
```

The preparation script applies Caffe's CONV2 bias, ReLU, five-channel local
response normalization, and 3 × 3 stride-2 max pooling to the raw DSIP dump.
It emits `13 × 13 × 256` signed Q8.8 samples in CHW order.

CONV3 uses 384 filters of shape `256 × 3 × 3`, stride 1, and padding 1.
The slave runs six batches of 64 filters. Each batch uses a separate OSP
region of 85 words per lane. The program computes output tiles of six, six,
and one row, loading 16 input-channel weight slices into each KSP bank at a
time. CONV3 exports raw dot products using the zero bias operand.

| CONV3 OM data | Word addresses | Words |
| --- | --- | ---: |
| Prepared input | `0x10000..0x1A8FF` | 43,264 |
| Caffe weights | `0x35000..0x10CFFF` | 884,736 |
| Zero-bias operand | `0x10D000` | 1 |
| Pixel-major output | `0x110000..0x11FD7F` | 64,896 |

The test uses 4 MiB of OM. DMA1 alternates OB banks and writes 63 full
blocks followed by a 384-word tail. A full block can end within a pixel's
384 filters. Output `y, x, filter` is at `0x110000 + (y*13 + x)*384 + filter`.
The checker exports `conv3_feature_map.mem` in `DSIP/tmp/verilator/conv3_full/`.
For manual simulation, select `single_conv3_tb` from `tb/single_conv3_tb.sv` and
stage both `conv3_*_imem.mem` images, `conv3_input.mem`, and `conv3_weight.mem`
by basename.

## Grouped CONV4

Run these commands from `source` after the CONV3 simulation produces its
feature map.

```powershell
python new_sw/core_instruction/conv4_prepare_input.py
python new_sw/model/script/bin_to_mem.py --input new_sw/model/alexnet_q88/conv4_weight.bin --output new_hw/tb/single_system/om_mem/Conv4/conv4_weight.mem
python new_sw/core_instruction/conv4_program.py
python new_hw/script/run.py test=conv4_full
```

The preparation script adds Caffe CONV3 bias, applies ReLU, and writes
`13 × 13 × 384` Q8.8 samples in CHW order. The CONV4 schedule uses `3 × 3`
kernels, stride 1, and padding 1. Filters 0–191 read input channels 0–191.
Filters 192–383 read channels 192–383. Each group runs in three 64-filter
batches, with 24 input-channel weight slices loaded into each KSP bank at a
time. The OSP and OB packing follow the same schedule as CONV3.

| CONV4 OM data | Word addresses | Words |
| --- | --- | ---: |
| Prepared input | `0x10000..0x1FD7F` | 64,896 |
| Caffe weights | `0x35000..0xD6FFF` | 663,552 |
| Zero-bias operand | `0x10D000` | 1 |
| Pixel-major output | `0x110000..0x11FD7F` | 64,896 |

The separate test reuses the CONV3 address bases and 4 MiB OM. The checker
exports raw CONV4 dot products to `conv4_feature_map.mem` in
`DSIP/tmp/verilator/conv4_full/`. For manual simulation, select `single_conv4_tb`
from `tb/single_conv4_tb.sv` and stage both `conv4_*_imem.mem` images,
`conv4_input.mem`, and `conv4_weight.mem` by basename.

## Grouped CONV5

Run these commands from `source` after the CONV4 simulation produces its
feature map.

```powershell
python new_sw/core_instruction/conv5_prepare_input.py
python new_sw/model/script/bin_to_mem.py --input new_sw/model/alexnet_q88/conv5_weight.bin --output new_hw/tb/single_system/om_mem/Conv5/conv5_weight.mem
python new_sw/core_instruction/conv5_program.py
python new_hw/script/run.py test=conv5_full
```

The preparation script adds Caffe CONV4 bias and applies ReLU to produce
`13 × 13 × 384` Q8.8 samples in CHW order. The CONV5 schedule uses `3 × 3`
kernels, stride 1, and padding 1. Filters 0–127 read input channels 0–191,
and filters 128–255 read input channels 192–383. Each group runs in two
64-filter batches, with 24 input-channel weight slices per KSP load.

The slave computes an eight-row tile and a five-row tile. The eight-row
tile ends on a full OB boundary, and DMA1 drains 42 full blocks plus a
final 256-word block across the two tiles. The output contains raw CONV5
dot products.

| CONV5 OM data | Word addresses | Words |
| --- | --- | ---: |
| Prepared input | `0x10000..0x1FD7F` | 64,896 |
| Caffe weights | `0x35000..0xA0FFF` | 442,368 |
| Zero-bias operand | `0x10D000` | 1 |
| Pixel-major output | `0x110000..0x11A8FF` | 43,264 |

The separate simulation uses the same 4 MiB OM and address bases as CONV4.
The checker exports `conv5_feature_map.mem` in `DSIP/tmp/verilator/conv5_full/`.
For manual simulation, select `single_conv5_tb` from `tb/single_conv5_tb.sv` and
stage both `conv5_*_imem.mem` images, `conv5_input.mem`, and `conv5_weight.mem`
by basename.

## File-driven testbench

`test=single_system` is an alias for `test=conv1_full`. Both run the full
96-filter Caffe workload and check the OM output against the Q8.8 reference.
The runner stages the program images, `om_mem/Conv1/input_img.mem`, and
`om_mem/Conv1/conv1_weight.mem` by basename.

The bare `single_system_tb` used by the Vivado project defaults to CONV1.
It expects `conv1_master_imem.mem`, `conv1_slave_imem.mem`, `input_img.mem`,
and `conv1_weight.mem` in the simulator working directory. Each layer wrapper
sets `LAYER_ID` on the shared `single_conv_tb`, which overrides the harness
parameters and checks the output.

The testbench supplies clock, reset, OM preloads, address checks, and logging.
Its OM has independent read and write ports. Reads are combinational when
enabled, and writes occur on the rising edge. Addresses and transfer counts
use 16-bit words. DMA CSR offsets use bytes. The CONV1 image starts at
`0x10000` and the weight tensor starts at `0x35000`.

`MASTER_IMEM_FILE` and `SLAVE_IMEM_FILE` select the program images. Master
records are 32-bit words and slave records are 64-bit words. The testbench
passes the filenames to the DUT memory wrappers for preload.

To regenerate the Caffe input image from `source`, run

```powershell
python new_sw/test_img/script/input_preprocess.py --input path/to/image.jpg --output new_hw/tb/single_system/om_mem/Conv1/input_img.mem
```

## Execution and logs

Clock period is 10 ns. Reset is held low for four clock periods, then the
bare harness runs up to `MAX_CYCLES` (default 8500000). Each full-layer
checker terminates after verifying the final OM output. `single_system_result.log` records preload
ranges, DMA completion pulses, sticky slave completion's rising edge, and
every OM write's time/address/data. Slave completion does not end the bench;
the master can continue its remaining row transfers.

The top retains the existing enabled lane/memory masks and instruction-controlled
loads, stores, and IB/KSP/OB buffer-switch commands (0 holds, 1 toggles).
Each switching instruction uses the new buffer; reset selects buffer 0 and
SCR retains the active buffers. DMA_CONFIG and SCR in your master program
control transfers and slave entry PC. Scheduling belongs to that program;
there is no master-readable DMA/slave status, automatic buffer swap, or
address-counter reset on SCR. Instruction DONE is exposed
through the top's `o_slave_done` output for external observation.

Slave instruction bit 37 (`Row done` in the workbook) produces a one-cycle
`o_slave_row_done` event after its instruction's final store drains. The top
connects it to the master. `WAIT_ROW` (`.word 0x0000002b`, custom-1) stalls
master fetch/decode until it consumes one live or remembered row event.
Older master instructions finish during the wait. Reset or SCR clears the
one pending event. Multiple unconsumed events coalesce. The DMA-only harness
ties both slave completion inputs low.

The generated programs use `WAIT_ROW` at the end of a loaded input row.
Setup and output packing use `WAIT_DONE` (`.word 0x0000102b`), which waits
for the slave to halt after the current run. Use `--wave` to capture a
waveform and open GTKWave.

```powershell
python new_hw/script/run.py test=single_system
python new_hw/script/run.py test=single_system --wave
```

Results go to `DSIP/tmp/verilator/single_system/`: `compile.log`,
`simulation.log`, `single_system_result.log`, and `single_system.vcd` with
`--wave`. GTKWave opens only with `--wave`. The separate `master_dma` test
retains its existing assertions and `PASS` marker.

## Previous verification

The earlier smoke-test harness passed Verilator runs in
`DSIP/tmp/verilator/single_system_check/` and
`DSIP/tmp/verilator/single_system_init_check/`. It loaded a generated slave
program through DMA0 and checked `2.0 * 3.0 - 1.0 = 5.0` at OM[3072].
A separate `DSIP/tmp/verilator/slave_imem_init_check/` run checked 64-bit
preloading and partial 16-bit programming writes. Those runs predate this
cleanup and do not verify the current file-driven harness.
