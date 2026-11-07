# DSIP core testbench

`dsip_core_tb.sv` instantiates the current core, generates a 10 ns clock and
active-low reset, programs IMEM, then sends one clock-wide start pulse with
`r_start_pc = 0`, connected to the core's instruction-indexed `i_start_pc`.
The local `core_imem_instr.txt` contains one 64-bit binary instruction per line,
ordered from bit 63 to bit 0. `//` comments and digit separators (`_`) are
accepted by `$readmemb`. The loader writes each instruction as four 16-bit
words, low word first. Instruction `n` uses programming word addresses `4*n`
through `4*n+3`. The testbench zero-fills unused instruction slots and writes
all 512 slots (2048 programming words) through the core's IMEM programming ports
while reset remains asserted. The supplied instruction selects a zero-result MAC
with no loads or stores; it is a placeholder, not a convolution program.

The `load_ib` and `load_ksp` tasks are placeholders for the user's loading
sequences. No IB, KSP, OSP or BSP contents are initialized. IB/KSP/OSP/BSP
current addresses feed back inside AGU on every issued instruction,
with respective widths of 10/8/9/6 bits. All pointers reset to zero. The
10-bit OB counter also lives in AGU, increments on valid NL Store OB requests and is included
in the trace. OB has two 1024-word buffers; valid Store OB instructions write
the bias-added, dummy-LUT-registered result to the instruction-selected buffer.
Bank enables and the OSP store mask are high, IB/KSP/BSP write enables are low,
and the four
operand/EOA lane enable ports are tied high. Memory accesses still depend on
the decoded instruction fields. Reads from unwritten data memories can yield X.

IB has two 1024-word buffers and KSP has two sets of 64 256-word banks. Each
instruction switches its IB read buffer with bit 49 and its KSP read buffer
with bit 35. The supplied zero instruction holds buffer 0 for both. Bit 63
switches the OB write buffer, and `instruction[62:57]` selects
the single OSP word for MLOM; the zero instruction selects OB buffer/OSP bank 0.
The scaffold holds both write-buffer selectors at zero, with dedicated IB/KSP/BSP
write addresses initialized to zero. Execution pointers retain their values
across start pulses and buffer changes. Buffer-loading stimulus is still
left for the user's loading schedule.

The OB read port is connected with reads disabled, read address zero and read
buffer zero. No DMA reader is instantiated in this scaffold. OB contents and
read data are uninitialized. The new output path has one MLOM and one MLB
register at ML-to-EXE and one dummy LUT register at EXE-to-NL; the LUT passes
the 16-bit wrapping sum unchanged. No output-path stimulus or result checking
has been added.

`+IMEM_FILE=<path>` and `+RUN_CYCLES=<count>` are available when launching
`dsip_core_tb` directly. Relative instruction paths are resolved from the
simulator's working directory.
The bench's default instruction path is
`../../new_sw/core_instruction/core_imem_instr.txt`; select the local placeholder
file explicitly with `+IMEM_FILE=<path>` if that is the desired image.
The default run duration is 64 rising edges including the start/fetch
edge. This duration does not imply instruction-program completion or a core
halt operation; select enough cycles for the desired program and final stores.
The core now supports instruction DONE and exposes sticky `o_done`; the
scaffold connects it as `w_done` without changing its fixed run duration.

The testbench writes `core_output.log` in the simulator's working directory.
The text trace records pre-edge
PC, IF/EXE/NL controls, branch target, AGU addresses, the current OB address,
OSP write mask/address and EOA lane 0. The completion marker
means only that the testbench reached its time limit; no arithmetic comparison
or convolution correctness check is performed by this scaffold.

`python new_hw/script/run.py test=agu_loop` from `source` checks the packed
loop selectors and all seven AGU contexts, including simultaneous SET and
LOOP, same-context update priority and issue gating.
