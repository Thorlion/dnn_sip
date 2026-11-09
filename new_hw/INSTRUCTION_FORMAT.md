# Instruction layout and IF wiring

The instruction is 64 bits, numbered [63:0]. IB/KSP read buffers and the OB
write buffer have independent hold/switch commands. A command of 0 holds
that memory's active buffer; 1 toggles it, and the issuing instruction uses
the new buffer. Every address group has sign and magnitude fields; IB, OSP
and BSP also have clear controls. KSP has no clear field. Sign 0 adds the
magnitude and sign 1 subtracts it.

| Field | Bits |
| --- | --- |
| OB write-buffer switch | 63 |
| OSP mux selection | 62:57 |
| Set iteration | 56:51 |
| DONE | 50 |
| IB read-buffer switch | 49 |
| IB counter clear | 48 |
| IB sign | 47 |
| IB offset magnitude | 46:44 |
| Set breakpoint selector | 43:41 |
| Conditional loop selector | 40:38 |
| ROW_DONE | 37 |
| Reserved, encode zero | 36 |
| KSP read-buffer switch | 35 |
| KSP sign | 34 |
| KSP offset magnitude | 33:27 |
| OSP counter clear | 26 |
| OSP sign | 25 |
| OSP offset magnitude | 24:16 |
| BSP counter clear | 15 |
| BSP sign | 14 |
| BSP offset magnitude | 13:11 |
| Load IB | 10 |
| Load KSP | 9 |
| Load OSP | 8 |
| Load BSP | 7 |
| MULT1 | 6 |
| MULT2 | 5 |
| ACC | 4:3 |
| MAX or MAC | 2 |
| Store OSP | 1 |
| Store OB | 0 |

Signed deltas are IB `-7..7`, KSP `-127..127`, OSP `-511..511` and BSP `-7..7`.
These smaller magnitudes do not reduce physical address widths or memory
depths: the counters remain IB 10, KSP 8, OSP 9 and BSP 6 bits. Arithmetic
wraps at each counter's width. The contiguous six-bit OSP mux field selects
lane 0 through 63. Encode reserved bit 36 as zero.
Re-export earlier slave instruction images from their worksheets for this
layout. Worksheet control values use the same meanings and the two loop
selectors now accept 0 through 7.

## Buffer hold/switch commands

`dsip_slave` stores one active-buffer bit for IB, KSP and OB, each reset to 0.
For each issued instruction, `resolved_buffer = active_buffer XOR switch`.
That resolved ID controls the same instruction's access and becomes the
stored active buffer. Thus commands `0, 1, 0, 1` from reset use buffers
`0, 1, 1, 0`. Re-executing a switch=1 instruction in a loop switches every
time it issues. A switch also takes effect with Load/Store=0 or when a
memory conflict suppresses the access. Bubbles, programming pauses and SCR
do not switch buffers; SCR retains the active selections.

OB's resolved physical buffer ID is pipelined with its store through all
three existing boundaries. A later switch cannot redirect an earlier store.
The six-bit OSP mux remains an absolute lane selection. DMA write-buffer
and OB read-buffer selectors remain absolute address-decoder outputs.
Switching does not clear an address counter or check buffer ownership.

## Counter clear and loop control

IB clear has immediate priority: clear=1 makes the current instruction's
IB address zero, ignoring its sign and magnitude. If that instruction issues,
the IB counter also captures zero. For example, after address 222, a clear
instruction with Load IB=1 reads address 0; the following +1 instruction reads
address 1. No separate setup instruction is required. With clear=0, IB uses
`stored_counter +/- magnitude` and feeds that result back on issue.

For OSP and BSP, the current instruction accesses `stored_counter +/- magnitude`.
Clear=1 at its issue edge stores the unsigned magnitude into that counter
instead of feeding back the calculated address. The sign bit affects only
the current address calculation; it is ignored for the direct counter load.
Clear does not replace the old base before the current access. For example,
base 10, delta +3 and clear=1 accesses address 13 and stores base 3 for the
next instruction. Delta -3 would access 7 and also store base 3. Clear=0
stores the calculated address as before. To load a zero base, use clear=1
with magnitude=0.
Updates happen on every issued instruction, even when its Load bit is zero.
KSP always feeds back its calculated address on issue. It resets to zero
only on reset; use signed relative offsets to reposition it during execution.
Changing IB/KSP buffers or issuing SCR does not reset any address counter.

There are seven independent breakpoint registers and seven independent
6-bit iteration counters. SBP=0 stores nothing. SBP=1 through 7 stores PC+1
and loads Set iteration into that context. Zero is a valid loaded count.
Set iteration is ignored when SBP=0. CLP=0 performs no branch. CLP=1 through 7
branches to that context's saved target if its old count is nonzero, then
decrements that count. A count N permits N backward jumps, so a loop body
reached once before CLP executes N+1 times (52 gives 53 executions).

Programs can nest loops by using different contexts and reinitializing an
inner context with SBP each time the outer body enters it. If SBP and CLP
select the same context on one instruction, branching uses the old state
and the new SBP target/count load takes priority over the decrement.
Different contexts can be updated independently on the same instruction.

## DONE

DONE=1 stops new instruction issue and holds the PC at that instruction.
The instruction's own loads, arithmetic and stores still execute. If it
issues on edge N, its final OSP/OB store is accepted on edge N+3; `o_done`
asserts after that edge and stays high until reset or another start/SCR.
A new start clears pending completion, redirects fetch and resumes issue.
The system exposes this as `o_slave_done` and connects it to the master.
`WAIT_DONE` holds master fetch and decode until this level is high. A wait
following SCR ignores the old level until the new run has started.
Use this wait for setup, bank switches, intermediate passes, and output
packing. The instruction uses opcode `7'b0101011` with `funct3 = 001`.

```asm
.word 0x0000102b  # WAIT_DONE: wait for the slave to finish and halt
```

## ROW_DONE and master WAIT_ROW

Slave bit 37 is ROW_DONE. Set it only after the last pass for a loaded
input row, including a final store if needed. An instruction issued at edge N produces
`dsip_slave.o_row_done` after its final store is accepted at edge N+3. The
output is a one-cycle event per marked instruction. Consecutive marked
instructions produce events on consecutive cycles. ROW_DONE neither holds
the slave PC nor stops issue. A marker inside a loop reports an event on
every execution, so put the row marker after the loop when only one event
per row is intended. Reset or SCR discards pending slave marker events.

`single_system_top` exposes this pulse as `o_slave_row_done` and connects it
to `dsip_master.i_slave_row_done`. Both cores use the same clock. The master
remembers one unconsumed event, including one received before WAIT_ROW.
Reset and SCR clear that pending event. Multiple events before consumption
coalesce into one; this is not a row counter or a queue.

The master instruction `WAIT_ROW` uses opcode `7'b0101011` (custom-1)
with `funct3 = 000`. Its canonical word is `32'h0000_002B`. Both wait
instructions leave architectural registers alone. In decode, `WAIT_ROW` holds the
PC and IF/ID register until a live or pending row event is available. Older
instructions finish while EX receives bubbles. It then consumes one event
and continues, so a second WAIT_ROW needs a second event. A taken older
branch flushes a wrong-path wait without consuming an event. If a pending
event is consumed as another arrives, the new event remains pending.

```asm
.word 0x0000002b  # WAIT_ROW: consume one slave row-completion event
```

Use WAIT_ROW before DMA overwrites a buffer whose completed row was marked
by the slave. This handshake does not pause the slave for incoming DMA data
or prove that the next row is loaded. Programs must still ensure DMA has
finished before the slave reads that row.

`dec_if` consumes flow control, address control, memory load and output-path
selections. The low seven bits are zero-extended and forwarded through
`reg_if_ml` and `reg_ml_exe` with a separate valid flag. Arithmetic controls
occupy [6:2] and stores occupy [1:0].
At the EXE input, they are exposed as `o_exe_instruction[8:0]` and `o_exe_valid`.
`dec_ex` decodes the arithmetic fields at the EXE input. Store fields advance
through `reg_exe_nl` to `dec_ms`, which requests OSP writes from NL.
The instruction's 9-bit OSP address accompanies it through all three existing
pipeline boundaries. Operand/EOA lane enable masks are temporarily tied high
inside the core; EOA still requires a valid MAC instruction. A separate single-word
output path adds one selected OSP word to its bias and writes the result to OB.

## Fetch and issue

IMEM stores each 64-bit instruction in a 64-bit record, using four parallel
16-bit synchronous 1RW `mem` banks. The default capacity is 512 instruction
slots: 2048 programming words, or 4 KiB. The PC remains instruction-indexed
and 9 bits wide; the programming word address is 11 bits wide.

`dsip_slave.IMEM_INIT_FILE` optionally initializes IMEM from one 64-bit
hexadecimal instruction per line. The system wrapper forwards its
`SLAVE_IMEM_FILE` parameter to this port. Each of the four 16-bit banks loads
its slice of every file record, retaining the existing 1RW organization.
The default standalone slave parameter is `""`, disabling initialization.
An empty file provides no defined contents; later programming writes can
overwrite the initial image. Initialization does not reset the memory or
change its synchronous-read latency. The current single-system bench
preloads the slave image directly; DMA0 programming remains available.

Program it through `i_imem_we`, `i_imem_waddr[PC_W+1:0]` and
`i_imem_wdata[15:0]`. For instruction index `n`, write:

| Programming word address | 16-bit data |
| --- | --- |
| `4*n + 0` | Instruction `[15:0]` |
| `4*n + 1` | Instruction `[31:16]` |
| `4*n + 2` | Instruction `[47:32]` |
| `4*n + 3` | Instruction `[63:48]` |

Word address bits `[1:0]` select the bank; the remaining bits select the
instruction row. A write enables only its selected bank, while all bank read
outputs hold. During fetch, all four banks read the same instruction row on
one rising edge. The core uses the full record `[63:0]`, including the upper
output-path selection fields. Encode reserved bit `[36]` as zero.
The IMEM wrapper has separate address inputs: `i_raddr[ADDR_W-1:0]` is an
instruction index, while `i_waddr[ADDR_W+1:0]` is a 16-bit-word address.
Read address `n` returns instruction `n`, so read addresses `0` and `1`
select different instructions. The core connects its selected fetch PC
directly to `i_raddr` and its programming word address to `i_waddr`.
The wrapper selects the write row when `i_we` is high, otherwise the read row.
The banks remain single-port, allowing one read or write operation per clock.

Each instruction requires four programming writes. For DMA programming, use
`4*N` words for `N` instructions and a destination aligned to four words.
Complete all four words before executing an instruction; there is no atomic
record-commit mechanism. Complete DMA programming before starting the slave.

The slave accepts `i_start` with `i_start_pc[PC_W-1:0]`. The start address is an
instruction index, not a byte address or a 16-bit programming word address.
At the default `PC_W=9`, software must supply an index in `0..511`. Connect
the master's `o_slave_start` to `i_start` and
`o_slave_pc[PC_W-1:0]` to `i_start_pc`.
[`single_system_top.sv`](tb/single_system/tb/single_system_top.sv) makes these
connections directly.

On the start edge, the PC loads `i_start_pc` and IMEM reads that same address.
The old fetched instruction does not issue on this edge. On the following
edge after start is deasserted, the entry instruction's IF controls issue and
the PC advances, or takes the AGU branch. IMEM reads that same next PC value
on the issue edge, so its output and the PC remain aligned for the next issue.
After the initial fetch, fetch and IF issue overlap with one instruction per
clock and no branch delay slot. Each new start pulse restarts fetch at its
supplied entry index, even while running or with `i_pc_en` low. Start has
priority over AGU branching and normal advancement in both the PC and IMEM
read-address selection. Starting redirects IF only: existing ML/EXE/NL work
can finish, and AGU loop state is retained.

`i_pc_en` controls normal PC advancement. AGU branch loading retains priority
over it. Holding `i_pc_en` low holds the normal PC; it is not an instruction
issue stall and the instruction at that PC can be fetched and issued again.
IMEM programming suppresses issue and normal PC advancement, and invalidates
the fetched word so the current PC is fetched again when programming finishes.
A simultaneous start still loads its entry PC, but fetch waits until
programming finishes. No new IF instruction issues before start, during reset,
while start is asserted, or during programming.
Instructions already in ML/EXE can continue advancing while programming pauses IF.

## Remaining instruction forwarding

If IF issues instruction I on edge N, `reg_if_ml` captures I's zero-extended
bits [6:0]
and the OSP address generated by the AGU for I. The data-memory reads for I
complete after that edge. On edge N+1, `reg_ml_exe` forwards the payload
and OSP address to EXE while MLI/MLK/MLO capture I's memory data.

Both control boundaries reuse the common `register` module and reset to zero
on active-low reset. Each boundary advances its valid flag every clock.
An invalid input produces a zero payload, zero OSP address and valid=0; it
does not replay the previous instruction. Existing in-flight control words continue advancing when
IF inserts bubbles, including while IMEM programming suppresses new IF issue.
MLI/MLK/MLO capture every rising edge outside reset because their lane enable
inputs are temporarily connected to all ones inside the core. The external
`i_mli_en`, `i_mlk_en`, `i_mlo_en` and `i_eoa_en` ports are retained but bypassed
for now. Decoded memory-load bits still determine when memory reads occur.

The OSP mux selection is registered at IF-to-ML, so it selects from the OSP
read outputs belonging to the same instruction. One 16-bit MLOM register
captures that selected word, and one 16-bit MLB register captures BSP data
at ML-to-EXE. Both capture on valid ML instructions and hold across bubbles.
They use the memories' held read outputs when no new load occurs; they do
not require an extra read cycle or change the 64 existing MLO registers.

At EXE, a signed 16-bit adder forms `MLB + MLOM`. Both inputs retain the
existing eight fractional bits. The result wraps modulo 2^16, matching
DALU addition; no rounding, rescaling or saturation is performed. A dummy
LUT register in `reg_exe_nl` captures this sum on valid EXE instructions,
independently of the MAC commit enable. It passes the sum unchanged to NL;
no activation function or lookup is implemented yet.

## EXE decoding

`dec_ex` splits MULT1 [6], MULT2 [5] and ACC [4:3] and broadcasts those controls
to all 64 DALUs. ACC encoding 11 is reserved in the instruction format; the
decoder passes the field through without changing the existing DALU mux logic.

MAX/MAC [2] is also split out, but its decoder output is left unconnected in
the core.
The MAC commit enable is valid=1
and MAX/MAC=0. The EOA lane mask is temporarily all ones, so every lane's
capture enable equals that MAC commit enable. Bubbles and MAX-selected instructions hold
EOA until a MAX datapath is implemented. No pipeline stage is added here.
The remaining store fields [1:0] are forwarded through `reg_exe_nl` to the
nonlinear-stage input for memory-store decoding.

## EXE to nonlinear control forwarding

`reg_exe_nl` registers store OSP [1] and store OB [0] from
`o_exe_instruction[1:0]`, together with `o_exe_valid` and the matching OSP
address from ML-to-EXE. The instruction outputs are
`o_nl_instruction[1:0]` and `o_nl_valid`. If IF issued instruction I at edge N,
its store controls arrive at NL after edge N+2, on the same edge that its
enabled EOA lanes capture the DALU results.

The control registers reuse the common `register` module and clear on
active-low reset. Invalid inputs insert a zero payload and valid=0. Control
forwarding follows EXE validity independently of the per-lane EOA enables and
MAC-mode qualifier; those still determine whether each EOA result updates.
The OSP address follows the same validity and reset behavior as the store bits.
There is one shared 9-bit address register at each of IF-to-ML, ML-to-EXE and
EXE-to-NL: 27 register bits total, shared across the 64 banks. No additional
pipeline boundary or execution cycle is introduced.

## Memory-store decoding and OSP write address

`dec_ms` decodes `o_nl_instruction[1:0]`, qualified by `o_nl_valid`:
bit 1 requests Store OSP and bit 0 requests Store OB. Invalid entries request
neither store. Store OB writes the dummy LUT register's result to the selected
OB buffer at the sequential OB address and advances that address on the same
edge. Its write-buffer selection travels with the instruction through
IF-to-ML, ML-to-EXE and EXE-to-NL.
The former external `i_store_osp` and `i_store_ob` inputs are replaced by this
decoder.

For each OSP bank, the decoded Store OSP bit is ANDed with that bank's
`i_osp_we` mask. `i_osp_en` still determines whether the bank is enabled.
These external masks apply at the actual memory-access edge.
A selected write uses the OSP address carried with the instruction and takes
its data from that bank's EOA register. Otherwise, an OSP read uses the live
AGU address exposed as `o_osp_addr`.

For instruction I issued at edge N, its address enters ML at N, EXE at N+1
and NL at N+2 alongside its store bits and enabled EOA result. The OSP write
then occurs at edge N+3, using I's registered address and the pre-edge EOA
data. A later IF instruction's address does not redirect that store.

OSP remains single-port 1RW. If a load and an enabled store target the same
bank on the same edge, the write takes priority at the delayed store address.
The read is not performed, and the bank's read output retains its previous
value. There is no automatic retry or stall. Banks not selected for a write
can still service a requested read at the live AGU address.

## Data-memory connections

IB contains two buffers of 1024 16-bit words: 2 KiB per buffer and 4 KiB total.
KSP contains two buffers, each with 64 banks of 256 16-bit words: 128 memory
instances, 512 bytes per bank and 64 KiB total. The KSP address register and
AGU output remain 8 bits, with a 7-bit instruction offset magnitude;
addition and subtraction wrap modulo 256. The IB word address remains 10 bits
with a 3-bit instruction magnitude. Instruction bits 51 and 39
switch the IB and KSP read buffers independently.

Decoded fields drive the AGU's iteration, breakpoint, conditional-loop and
clear/sign/offset inputs. `agu.sv` owns all five execution address registers;
`dsip_slave.sv` forwards the address outputs and supplies the update events:

| Memory | Pointer width | Address range | Update event |
| --- | --- | --- | --- |
| IB | 10 bits | `0..1023` | Capture AGU output on IF issue; clear makes output/base zero |
| KSP | 8 bits | `0..255` | Capture AGU output on IF issue; no clear control |
| OSP | 9 bits | `0..511` | Load offset magnitude or capture AGU output on IF issue |
| BSP | 6 bits | `0..63` | Load offset magnitude or capture AGU output on IF issue |
| OB | 10 bits | `0..1023` | Increment by one on each valid NL Store OB request |

AGU calculates IB/KSP/OSP/BSP outputs from its internal registered current
addresses. These outputs are used for the current instruction and captured
when `i_addr_en` is high. IB clear overrides both the current output and the
captured base to zero. OSP/BSP clear instead loads the unsigned offset
magnitude into the corresponding base; KSP always captures its AGU output.
`i_addr_en` connects to `w_issue`
in the slave, including instructions without the corresponding Load bit.
With clear=0, offset zero holds a pointer;
signed offsets advance or rewind it, wrapping at its width. For example,
three issued `+1` offsets from reset produce addresses 1, 2, 3. Use a zero
offset for an initial access to address zero. OSP stores still use the IF
address carried through the pipeline, rather than a later pointer value.

All pointers reset to zero and retain their values across start/restart.
IB and KSP each share one address pointer across their two buffers; changing
buffer selection does not reset it. The four AGU feedback pointers hold when
no instruction issues, including fetch bubbles and IMEM programming pauses.

OB uses `o_ob_addr` as its current sequential store address. The first valid
Store OB request after reset uses address 0; the counter increments on that
request's rising edge, wraps from 1023 to 0 and holds on cycles without a
valid Store OB request. AGU's `i_store_ob` is connected to the slave's decoded
valid NL Store OB request. It counts NL requests independently of IF issue, so
already-issued Store OB instructions can advance it while IF is paused.
The same pre-edge address and NL Store OB request drive the OB memory write.
For an instruction issued at edge N, MLOM/MLB capture at N+1, the dummy LUT
register captures the sum at N+2, and OB writes that result at N+3.

OB contains two buffers of 1024 16-bit words, or 4 KiB total. The sequential
write pointer is shared across the two buffers and is not reset by a buffer
selection change. Instruction bit 63 is a hold/switch command resolved in IF;
the resulting buffer ID travels with the store. There is no buffer-ownership
scheduler or automatic swap on DMA completion.

The external read port uses `i_ob_ren`, `i_ob_raddr[9:0]` and `i_ob_rbuf_sel`.
`o_ob_rdata[15:0]` updates after the accepting rising edge and holds when
reads are disabled. The core can write one buffer while DMA reads the other.
Each physical buffer remains a single-port 1RW memory. A simultaneous read
of the buffer being written is suppressed, retaining the previous read
output, with no retry or stall. The completed read's buffer ID is registered
so changing a live selector without a read does not redirect the held data.
OB memory and read data are uninitialized until written/read; only the
pipeline registers and the read-buffer-selection register reset to zero.
The standalone [DMA read decoder](ip/dma/README.md#dma-read-address-decoder)
maps DMA1 source word addresses `0x0004_0000..0x0004_03FF` to OB buffer 0
and `0x0004_0400..0x0004_07FF` to buffer 1. DMA address bit 10 selects the
buffer, and bits [9:0] select the local word.
[`single_system_top.sv`](tb/single_system/tb/single_system_top.sv) connects the
decoder and DMA1 to the slave while keeping OM outside the DUT.

Decoded Load IB/KSP/OSP/BSP bits request reads. Existing `i_*_en` inputs act
as enable/lane masks. IB/KSP/BSP `i_*_we` inputs permit programming writes
independently of load bits. OSP `i_osp_we` is a per-bank mask that additionally
requires decoded Store OSP.

`dec_if` extracts `o_ib_switch` from instruction bit 51 and `o_ksp_switch`
from bit 39. The slave resolves them against its stored active buffer bits
for the corresponding IF memory read. There are no external IB/KSP execution
read-buffer selectors. IB writes use
`i_ib_wbuf_sel` and `i_ib_waddr[9:0]`; KSP writes use `i_ksp_wbuf_sel` and
`i_ksp_waddr[7:0]`. BSP programming uses its dedicated `i_bsp_waddr[5:0]`.
Execution addresses come from the internal feedback pointers. The write and
read addresses can differ, allowing DMA
to fill one buffer while execution reads the other. Each physical memory is
still single-port 1RW. A write targeting the read buffer blocks that bank's
read; its read result holds, with no automatic retry or stall.

The selected read-buffer ID is captured on the memory-read edge, per lane for
KSP. It holds when no read occurs, including a same-buffer write conflict.
The output mux therefore follows the completed read rather than a live
selector change. This preserves the existing one-cycle memory latency and
keeps the following ML-to-EXE operand capture aligned across buffer changes.
Memory contents are not reset or initialized.

The program switches its active read buffer with explicit toggle commands.
Software/synchronization logic
must schedule DMA writes away from the buffer being read when concurrent
loading is desired. SCR/start and DMA completion do not toggle buffers.
The integration wrapper must also combine execution enable masks with the
DMA decoder's programming enables so `i_ib_en`, `i_ksp_en` and `i_bsp_en`
permit the requested accesses. BSP remains single-port: programming writes
take priority over a simultaneous execution read, without changing its
execution pointer except through an issued instruction's offset.

The [DMA write decoder](ip/dma/README.md) selects the IB write buffer from DMA
word-address bit 10 and the KSP write buffer from bit 14. Its local IB/KSP/BSP
address outputs connect to `i_ib_waddr`, `i_ksp_waddr` and `i_bsp_waddr`.

Memory read data is available after the issue edge. With operand lane enables
tied high, MLI/MLK/MLO capture that data on the following edge. When a memory
does not read, these registers capture its held read output.
Flow control and address control do not gate the DALU arithmetic datapath.

## Master SCR instruction

The master uses 32-bit instructions. `SCR rs1` uses opcode `7'b0001011`
(`0x0B`, custom-0) and takes its only operand from instruction `[19:15]`.
Write the unused fields as zero; the decoder ignores them:

| Bits | Field |
| --- | --- |
| `[31:20]` | Unused, write zero |
| `[19:15]` | `rs1` register index |
| `[14:12]` | Unused, write zero |
| `[11:7]` | Unused, write zero |
| `[6:0]` | `0001011` |

During SCR's EX cycle, `dsip_master` exposes:

- `o_slave_start`: a start strobe, sampled on the rising edge ending EX.
- `o_slave_pc[31:0]`: the full forwarded `rs1` value, valid with that strobe.
  It is an instruction index, with no byte/word conversion or truncation.

The PC value uses the existing EX/MEM and MEM/WB forwarding paths. The
existing load-use hazard logic inserts a bubble when needed. SCR's start
control bit passes through ID/EX and clears on reset or flush. Each SCR
produces one active EX cycle; consecutive SCR instructions can keep the
strobe high across consecutive cycles, representing one request per edge.
The PC output is not held after SCR and should only be sampled with start.
SCR does not write a register, memory, or DMA CSR. These outputs are exposed
at the master top and connected to the slave by `single_system_top.sv`.

For example, `SCR x5` is the raw instruction word `32'h0002_800B`:

```assembly
addi x5, x0, 12
.word 0x0002800b  # SCR x5: start with slave instruction PC = 12
```

Verilator compilation and the single-system smoke test passed, including
SCR entry at PC 7 and the selected OSP/bias-to-OB output path. See the
[integration validation notes](tb/single_system/README.md#validation) for
coverage and log locations.
