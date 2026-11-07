# Single-system integration

`single_system_top.sv` contains one master core, one slave core, DMA0, DMA1
and both DMA address decoders. OM remains outside the DUT in
`single_system_tb.sv`.

```text
Master DMA_CONFIG --> DMA0 CSRs / DMA1 CSRs
Master SCR --------> slave start + instruction-indexed PC

OM async read --> DMA0 --> write decoder --> IB / KSP / BSP / slave IMEM
OM clocked write <-- DMA1 <-- read decoder + synchronous slave OB read
```

## File-driven testbench

The bench supplies clock/reset, a 512 KiB asynchronous-read/clocked-write OM,
image/parameter preloads, OM address checks, optional waves, and a result log.
Your master and slave instruction files supply the programs. The bench no
longer constructs instructions in OM, injects example operands, or checks a
particular DMA sequence, start PC, output lane, word count, or arithmetic result.

The program inputs are:

| Purpose | Source file under this directory | Format |
| --- | --- | --- |
| Master program | `master_mem/single_master_imem.mem` | 32-bit hexadecimal words |
| Slave program | `slave_mem/single_slave_imem.mem` | 64-bit hexadecimal words |
| Input image | `om_mem/input_img.mem` | 16-bit hexadecimal words |
| CONV1 weights | `om_mem/Conv1/conv1_weight.mem` | 16-bit hexadecimal words |
| CONV1 biases | `om_mem/Conv1/conv1_bias.mem` | 16-bit hexadecimal words |

The runner copies all five files into its output directory using their
basenames. The bench and top therefore refer to `single_master_imem.mem`,
`single_slave_imem.mem`, `input_img.mem`, `conv1_weight.mem`, and
`conv1_bias.mem` relative to the simulator working directory. For manual
simulation, stage the files the same way or adjust those filename arguments.

`single_system_top.MASTER_IMEM_FILE` and `.SLAVE_IMEM_FILE` pass through the
existing memory wrappers. Slave records use instruction indices, with one
64-bit instruction per word (16 hex digits, bit 63 first). Each physical
16-bit bank loads its slice of the same image. The bench does not copy the
slave program through OM/DMA or overwrite its preload. Your master program
can still program slave IMEM through DMA0 when explicitly instructed.

The current master image loads channel 0: 64 kernels into KSP buffer 0,
then the first 41 input rows (224 pixels each) into alternating IB buffers 0/1,
with NOP delay loops covering DMA completion. After the first row's wait it
issues SCR once with rs1=x0, starting the file-preloaded slave at instruction
PC 0. It prefetches row 2, then uses WAIT_ROW after each later load to consume
the preceding row's completion before another transfer can reuse its buffer.
After the row-41 completion event it parks. See
[`master_mem/README.md`](master_mem/README.md) for the instruction outline
and source/destination formulas.
The slave image supplies the instructions executed after SCR. It must emit
one ROW_DONE event per consumed input row for the master schedule above.
DONE separately holds the PC and stops new issue, then raises sticky
`o_slave_done` after the final store drains. Reset or another SCR clears
completion. File preloading does not initialize unused slots; provide valid
instructions for every address the slave can execute.

The current slave program is the 279-word export of
`new_sw/core_instruction/single_temp.xlsx` (`Sheet1`). It processes one input
row per transaction and completes nine output rows in OSP addresses 0..494
of each lane, leaving 17 words unused. The last instruction sets ROW_DONE
and DONE. See [`slave_mem/README.md`](slave_mem/README.md) for its nested-loop
schedule and the channel-0 reference test.

## OM memory map

Addresses and DMA transfer counts use **16-bit words**; DMA CSR offsets use
bytes. The OM array spans `0x00000000..0x0003FFFF` (262144 words, 512 KiB).
These OM addresses are independent of the slave decoder address space.

| Contents | First word | Last word (inclusive) | Words | Payload bytes |
| --- | --- | --- | ---: | ---: |
| Input image, RGB CHW, 224 x 224 | `0x00010000` | `0x00034BFF` | 150528 | 301056 |
| CONV1 weights, 64 x 3 x 11 x 11 | `0x00035000` | `0x0003AABF` | 23232 | 46464 |
| CONV1 biases | `0x0003B000` | `0x0003B03F` | 64 | 128 |

All values retain signed Q8.8 two's-complement encoding. Preloads occupy
173824 words (347648 bytes, 339.5 KiB). Other locations, including the former
smoke-test program/data/result locations, retain `0xA55A` until written.

Image address: `0x10000 + c*224*224 + y*224 + x`, with R=0, G=1, B=2.
Planes occupy `0x10000..0x1C3FF`, `0x1C400..0x287FF`, and
`0x28800..0x34BFF`. Weights retain the supplied binary file's flat order.
For contiguous TorchVision OIHW exports, weight `[o,i,ky,kx]` is at
`0x35000 + ((o*3 + i)*11 + ky)*11 + kx`. Bias `o` is at `0x3B000 + o`.

Parameter regeneration is documented in
[`new_sw/parameter/README.md`](../../../new_sw/parameter/README.md).
To replace the image, run from `source`:

```powershell
python new_sw/test_img/script/input_quantizer.py --input path/to/image.jpg --output new_hw/tb/single_system/om_mem/input_img.mem
```

OM uses independent read/write ports without wait states. Reads are
combinational when enabled; writes occur at the rising clock edge. A read
of a simultaneously written word supplies the old value at that edge and
reflects the new value after the nonblocking update. Unknown OM request
signals and invalid enabled addresses cause a fatal error.

## Execution and logs

Clock period is 10 ns. Reset is held low for four clock periods, then the
bench runs for `MAX_CYCLES` (currently 100000); edit that constant for your
program's required duration. `single_system_result.log` records preload
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

Slave instruction bit 41 (`Row done` in the workbook) produces a one-cycle
`o_slave_row_done` event after its instruction's final store drains. The top
connects it to the master. `WAIT_ROW` (`.word 0x0000002b`, custom-1) stalls
master fetch/decode until it consumes one live or remembered row event.
Older master instructions finish during the wait. Reset or SCR clears the
one pending event. Multiple unconsumed events coalesce. The DMA-only harness
ties this input low because it has no slave.

The master image now executes WAIT_ROW before buffer reuse, plus a final
wait for row 41. The slave image supplies one matching row marker after
all vertical passes of each input row.
ROW_DONE does not stop the slave or wait for incoming DMA data; the program
must also ensure a new row is ready before the slave starts reading it.

At the run limit, the bench writes `SINGLE_SYSTEM_TB_FINISHED` and calls
`$finish`. The runner reports `FINISHED`. This means the configured simulation
window ended without a fatal error; it does not assert program completion or
workload correctness. Add workload-specific comparisons once your programs
and expected results are available.

For the current nine-output-row channel-0 workload, use its self-checking
wrapper instead of interpreting FINISHED as a correctness result:

```powershell
python new_sw/core_instruction/conv1_channel0_reference.py
python new_hw/script/run.py test=conv1_channel0
```

This test passed with all 31680 OSP words matching, 41 row events/waits and
105 DMA completions. Regenerate the reference whenever the image or weights
change. Logs are in `DSIP/tmp/verilator/conv1_channel0/`.

From `source`, once compilation/simulation is approved:

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

The OM parameter conversion was previously checked bit-for-bit against its
source binaries. The file-driven harness and current channel-0 master program
have not been compiled or simulated; repository instructions require explicit
approval first.
