# CONV1–5 weight prefetch schedule

DMA0 refills the next IB row first. The master then uses the remaining
compute time to write the next weight chunk into the inactive KSP bank.
It waits for each DMA transfer before rewriting its CSRs. `ROW_DONE` marks
completion of a loaded input row. Setup and packing use `WAIT_DONE`.

## CONV1

The first 64-filter batch starts with three 121-word channel slices per
lane. Lanes 32–63 keep those weights throughout the layer. The two filter
batches alternate their order from tile to tile, so each tile starts with
the batch left resident by the previous tile.

For each incoming batch, DMA0 loads the following slices for lanes 0–31.
Each slice takes 16 input-row windows with two 121-word lane transfers per
window. The master issues the transfers during the first horizontal pass
of each selected row, after its IB refill drains. [CONV1 generator](../../../new_sw/core_instruction/conv1_full_program.py)

| Compute window | Destination slice | Words |
| --- | --- | ---: |
| Resident batch, channel 1 | Incoming channel 0 in bank 0, words 0–120 | 3,872 |
| Resident batch, channel 2 | Incoming channel 1 in bank 1, words 0–120 | 3,872 |
| Incoming batch, channel 1 | Incoming channel 2 in bank 0, words 128–248 | 3,872 |

## CONV2–5

For each loaded input row, the generator budgets DMA time from the number
of horizontal passes. It reserves time for the IB refill, DMA command and
wait instructions, and staging the next slave PC. Lane slices can span
row windows. After a chunk's final channel, the master finishes any
remaining weights before switching banks. The last chunk of each filter
batch targets the first chunk of the next batch, including across tile
boundaries. The first chunk of the layer is loaded at startup. [Shared generator](../../../new_sw/core_instruction/conv2_program.py)

| Layer | Output rows per tile | Channels per chunk | Words per chunk | Words prefetched per transition, by tile size | Words left at the boundary, by tile size |
| --- | --- | ---: | ---: | --- | --- |
| CONV2 | 4, 4, 4, 4, 4, 4, 3 | 8 | 12,800 | 4 rows: 12,800; 3 rows: 9,600 | 4 rows: 0; 3 rows: 3,200 |
| CONV3 | 6, 6, 1 | 16 | 9,216 | 6 rows: 5,064; 1 row: 270 | 6 rows: 4,152; 1 row: 8,946 |
| CONV4 | 6, 6, 1 | 24 | 13,824 | 6 rows: 7,776; 1 row: 432 | 6 rows: 6,048; 1 row: 13,392 |
| CONV5 | 8, 5 | 24 | 13,824 | 8 rows: 10,884; 5 rows: 6,504 | 8 rows: 2,940; 5 rows: 7,320 |

The CONV2 baseline already prefetched within each batch. Extending that
schedule across batches and tiles reduced the first batch handoff from
138.21 µs to 1.24 µs at 100 MHz. Full runtime went from 4,061,719 to
3,700,827 cycles, and idle KSP transfer cycles went from 422,400 to 86,400.

## Vivado XSim timing

The replay uses the master, DMA, and slave control RTL with zero-valued
payloads. It checks the output addresses and block counts, DMA0 CSR writes
while active, and IB/KSP writes against the banks currently being read.
Full cycles run from reset release through final DMA1 completion. Idle KSP
transfer cycles count DMA0 weight words moved on cycles without slave issue.

| Layer | Master IMEM words | MAC cycles | Slave issue cycles | Full cycles | Idle KSP transfer cycles |
| --- | ---: | ---: | ---: | ---: | ---: |
| CONV1 | 3,189 | 2,174,424 | 2,475,727 | 2,686,906 | 23,232 |
| CONV2 | 3,206 | 3,195,072 | 3,434,626 | 3,700,827 | 86,400 |
| CONV3 | 3,923 | 2,102,784 | 2,288,910 | 4,594,699 | 1,656,270 |
| CONV4 | 3,490 | 1,577,088 | 1,733,502 | 3,397,603 | 1,223,856 |
| CONV5 | 2,194 | 1,051,392 | 1,150,775 | 1,678,747 | 334,824 |

Separate XSim output checks matched the first 21,504 real CONV1 words
through the first tile boundary. Two-tile Q8.8 fixtures matched 6,400
words for CONV2, 9,600 each for CONV3 and CONV4, and 6,400 for CONV5.
