# DMA address decoders

## DMA write address decoder

`dma_write_decoder.sv` routes DMA0's 16-bit payload to the slave programming
interfaces. Connect the DMA outputs as follows:

| DMA0 output | Decoder input |
| --- | --- |
| `o_slave_addr` | `i_dma_addr[31:0]` |
| `o_slave_data` | `i_dma_data[15:0]` |
| `o_slave_wen` | `i_dma_wen` |

Addresses count **16-bit words**. An address increment of one transfers the
next word. DMA CSR offsets (`0x00`, `0x04`, `0x08`, `0x0C`) still count bytes
and are separate from this memory map.

| Target | Valid DMA destination word addresses | Local address |
| --- | --- | --- |
| IB buffer 0 | `0x0000_0000` through `0x0000_03FF` | Word `[9:0]` |
| IB buffer 1 | `0x0000_0400` through `0x0000_07FF` | Word `[9:0]` |
| KSP buffer 0 | `0x0001_0000` through `0x0001_3FFF` | Bank `[13:8]`, word `[7:0]` |
| KSP buffer 1 | `0x0001_4000` through `0x0001_7FFF` | Bank `[13:8]`, word `[7:0]` |
| BSP | `0x0002_0000` through `0x0002_003F` | `[5:0]` |
| Slave IMEM | `0x0003_0000` through `0x0003_07FF` | `[10:0]` at `PC_W=9` |

The decoder is combinational and adds no clock cycle. IB and BSP each receive
an enable and write-enable strobe. KSP receives matching 64-bit one-hot enable
and write-enable masks, so exactly one bank in the selected buffer accepts
each KSP write. `o_ib_wbuf_sel` is DMA address bit 10; `o_ksp_wbuf_sel` is bit
14. The data bus fans out to all 64 KSP data inputs; the mask and buffer
selector choose which physical memory stores it.
IMEM receives its write enable, 16-bit word and programming word address.

The output addresses and data follow the DMA input even when a target is
disabled; consumers must qualify writes with the corresponding strobe.
With `i_dma_wen=0`, every enable/write-enable is zero. Writes outside the valid
ranges, including OB/OSP regions and higher-address aliases, also enable no
memory. There is no error-response port; the DMA still counts an unmapped beat.

For example, destination `0x0001_0305` writes KSP buffer 0, bank 3, word 5;
`0x0001_4305` writes buffer 1 at the same bank and word.
Instruction `n` is programmed at `0x0003_0000 + 4*n` through
`0x0003_0000 + 4*n + 3`, low word first. Its SCR start-PC value remains `n`.

`PC_W` defaults to 9 and must be in `1..14`; the IMEM window contains
`2**(PC_W+2)` programming words. Memory sizes and KSP bank count otherwise
match the current slave RTL.

IB, KSP and BSP have dedicated write-address inputs in the slave. IB and KSP
also have separate write-buffer selectors:

| Decoder output | Slave input |
| --- | --- |
| `o_ib_addr` | `i_ib_waddr` |
| `o_ib_wbuf_sel` | `i_ib_wbuf_sel` |
| `o_ksp_addr` | `i_ksp_waddr` |
| `o_ksp_wbuf_sel` | `i_ksp_wbuf_sel` |
| `o_bsp_addr` | `i_bsp_waddr` |

Connect each memory's write enable and write data to its corresponding slave
input. Slave instruction bit 51 switches the IB read buffer and bit 39 switches
the KSP read buffer: 0 holds and 1 toggles the active buffer, starting from
buffer 0 after reset. The same instruction uses the new buffer. DMA's own
address-derived write selectors remain absolute. There is no automatic swap
on start or DMA completion. Each memory can read one buffer while DMA writes
the other using a different word address. Writes
targeting the same physical bank as a read have priority, with no retry or stall.

The slave's `i_ib_en`, `i_ksp_en` and `i_bsp_en` also gate execution reads, so
combine the decoder's programming enables with the execution enable masks
(logical OR for IB/BSP, bitwise OR for KSP) in the integration wrapper.
AGU owns the IB/KSP/OSP/BSP execution pointers and updates them on each issued
instruction. It also owns the sequential OB store pointer. The slave supplies
the issue/store events; DMA write addresses are independent of those pointers.
BSP remains single-port, with programming writes taking priority over
execution reads. IMEM programming pauses instruction issue.

The decoder is instantiated by
[`single_system_top.sv`](../../tb/single_system/single_system_top.sv).
It does not implement buffer ownership scheduling or address feedback.

## DMA read address decoder

`dma_read_decoder.sv` decodes DMA1's OB source address for the slave's two
1024-word output buffers. Addresses and transfer sizes count 16-bit words.

| Source | Valid DMA source word addresses | Local address |
| --- | --- | --- |
| OB buffer 0 | `0x0004_0000` through `0x0004_03FF` | Word `[9:0]`, buffer 0 |
| OB buffer 1 | `0x0004_0400` through `0x0004_07FF` | Word `[9:0]`, buffer 1 |

| DMA1 output | Decoder input |
| --- | --- |
| `o_ob_addr[31:0]` | `i_dma_addr[31:0]` |
| `o_ob_ren` | `i_dma_ren` |

| Decoder output | Slave input |
| --- | --- |
| `o_ob_ren` | `i_ob_ren` |
| `o_ob_raddr[9:0]` | `i_ob_raddr[9:0]` |
| `o_ob_rbuf_sel` | `i_ob_rbuf_sel` |

Connect slave `o_ob_rdata[15:0]` directly to DMA1 `i_ob_data[15:0]`.
The decoder contains no clock, reset, data mux or pipeline register. The
slave captures read data and its buffer ID on the read edge, preserving the
one-cycle synchronous-read timing expected by DMA1's initial `READ_FIRST`
state and subsequent streaming transfers.

Buffer selection is address bit 10. The local word address is `[9:0]`.
For example, source `0x0004_0405` selects OB buffer 1, word 5. Both outputs
follow the input even when disabled; only `o_ob_ren` permits an access.
The decoder checks every upper address bit and disables reads for unmapped
regions, holes and higher-address aliases, or when `i_dma_ren` is zero.

There is no error/ready response. Suppressing an unmapped read does not stop
DMA1's transfer or its OM writes; it can write the held or uninitialized OB
read output. Keep the complete source range mapped. Likewise, the decoder
does not arbitrate core/DMA buffer ownership: a read conflicting with a core
write to the same physical buffer is suppressed by the slave, without retry.
Schedule DMA reads from a buffer that the core is not writing.

The decoder is instantiated between DMA1 and the slave in
[`single_system_top.sv`](../../tb/single_system/single_system_top.sv).
