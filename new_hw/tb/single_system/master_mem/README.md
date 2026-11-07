# Channel-0 master program

`single_master_imem.mem` contains 43 executable RV32/custom instruction words
(172 bytes), with assembly comments and byte-PC labels. Runtime loops cover
the first 41 image rows of channel 0 without unrolling every row.

1. Load the first channel of all 64 CONV1 kernels into KSP buffer 0.
2. NOP.
3. Load input row 1 into IB buffer 0; NOP delay; SCR starts the slave at PC 0.
4. Load input row 2 into IB buffer 1; DMA delay; WAIT_ROW consumes row 1's event.
5. Reuse IB buffer 0 for row 3; DMA delay; WAIT_ROW consumes row 2's event.
6. Continue through row 41, waiting for the previous row after each load.
7. WAIT_ROW consumes row 41's event, then park with `jal x0, park`.

SCR is encoded as `0000000B` (opcode `0x0B`, rs1=x0) at master byte PC
`0x80`. It follows the first row's DMA wait. x10 retains the initial row
count; subsequent rows branch around SCR as x9 decreases. The slave starts
once and continues while the master streams later rows. Row 1 jumps around
WAIT_ROW so the master can prefetch row 2 while the slave computes row 1.
After loading each row `n=2..41`, WAIT_ROW consumes row `n-1`'s completion
before row `n+1` can overwrite that row's old buffer.

WAIT_ROW uses the word `0000002B` at byte PC `0x88`. The final wait at
`0x9C` consumes row 41's event; the park instruction is at `0xA0`.
The slave program must emit one ROW_DONE event per consumed input row in
order, using bit 41 after each row's loop. Missing events leave the master
stalled. The event has no row number or buffer ID, and only one pending
event is remembered. The matching 279-word slave program covers all 41 input
rows and supplies these markers. It computes channel-0 contributions for
nine complete output rows, occupying OSP addresses 0..494 in each lane.

Here bank 0/1 means the ping-pong buffer. The KSP has 64 separate lanes in
each buffer; lane `k` receives kernel `k`'s 121 first-channel weights.

## Addressing

All DMA addresses and sizes count 16-bit words. With the existing contiguous
OIHW parameter layout, each output kernel has `3*11*11 = 363` words.
For kernel `k=0..63`, the program transfers 121 words:

```text
OM source       = 0x35000 + k*363
KSP destination = 0x10000 + k*256  (buffer 0, lane k, word 0)
```

Each kernel is a separate DMA0 transfer, accounting for the channel stride
in OM and the 256-word lane stride at the destination. For input row
`y=0..40`, it transfers 224 words:

```text
OM source      = 0x10000 + y*224
IB destination = 0x00000 if y is even, 0x00400 if y is odd
```

Every row starts at local IB word 0. Row 41 reads
`0x12300..0x123DF` into buffer 0. Streaming overwrites each buffer when it is
reused; WAIT_ROW requires the old row's completion before that reuse.
Channels 1 and 2 are not transferred.

## DMA commands and delays

DMA_CONFIG uses opcode `0x78`, funct3=0 (DMA0), rd=0 and forwarded rs1 data.
The immediate selects the CSR: source=0, destination=4, size=8, START=12.
Writing START=1 launches the configured transfer. Registers are:

| Register | Use |
| --- | --- |
| x5 | OM source pointer |
| x6 | KSP lane pointer / IB buffer address |
| x7 | Transfer size (121 kernel words or 224 row words) |
| x8 | Constant 1 for START |
| x9 | Remaining kernels / rows |
| x10 | Initial row count, used to execute SCR only after row 1 |
| x11 | NOP-delay loop counter |

Each transfer is followed by a delay loop containing NOP, ADDI and BNE.
Kernel delays use 42 iterations (at least 126 instruction cycles); row
delays use 76 iterations (at least 228 instruction cycles). Branch flushes
can add cycles. The delays account for the one-word-per-cycle DMA and its
registered START latency without modifying a live transfer's CSRs.
The row delay is reduced from 256 iterations because it now covers only
the 224-word DMA transfer and registered START latency. WAIT_ROW supplies
the additional wait for slave consumption. The program still does not poll
DMA completion. Branch/jump encodings and byte-PC labels account for the
inserted waits and the first-row bypass.

ROW_DONE does not pause the slave. The next row must finish loading before
the slave begins reading it. This schedule prefetches one row ahead, but
does not provide a separate slave-side DMA-ready handshake.

The schedule issues 105 DMA0 transfers containing 16928 payload words:
`64*121 + 41*224`, plus one SCR at slave instruction PC 0 and 41 WAIT_ROW
consumptions when all row events are supplied. It does not load
biases or use DMA1.
The testbench run window is 100000 cycles so it can accommodate these loads
and the delay-loop overhead. Its FINISHED marker is not a functional check.

The `conv1_channel0` Verilator test passed with 41 row events/waits,
105 DMA completions, and all 31680 OSP words matching the Q8.8 reference.
