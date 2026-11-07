# Slave instruction exporter

`core_compiler.py` reads the instruction worksheet and writes a 64-bit
hexadecimal image for the slave IMEM's `$readmemh` loader. It requires Python
3.10 or later and uses only the standard library.

From this directory:

```powershell
python core_compiler.py
python core_compiler.py --input slave_instruction_template.xlsx --output instruction.mem
python core_compiler.py -i my_schedule.xlsx -o my_program.mem --sheet Sheet1
```

The defaults are `slave_instruction_template.xlsx` and `instruction.mem`
beside the script, regardless of the working directory. Explicit relative
paths are resolved from the working directory. Absolute paths are accepted.
The script can also be run from `source`:

```powershell
python new_sw/core_instruction/core_compiler.py -i new_sw/core_instruction/slave_instruction_template.xlsx -o new_hw/tb/single_system/slave_mem/single_slave_imem.mem
```

## Worksheet inputs

Keep headers in row 1. The exporter matches headers by name, ignoring case
and extra whitespace, so control columns may be reordered. Required columns
are `Address` plus the 26 controls in the template. `Comment`, `Field check`
and other metadata columns are ignored. The exporter validates the controls
itself rather than trusting Excel's calculated status.

Leave every control blank for an unused row. For an active instruction,
enter all 26 controls as literal numeric integers, including explicit zeros
for controls you do not use. Input formulas, numeric text and booleans are
rejected; paste formula results as numeric values before exporting. The
computed `Field check` formulas are ignored and do not need recalculation.

Addresses are instruction indices in `0..511`, with no duplicate active
addresses. Delta fields use signed magnitudes: IB `-7..7`, KSP
`-127..127`, OSP `-511..511`, BSP `-7..7`. KSP uses sign bit 34 and the seven
magnitude bits `[33:27]`. OSP clear is at bit 26. An obsolete KSP clear worksheet column
may be blank or zero, but a nonzero value is rejected.
The exporter packs every field into a contiguous bit range. OSP mux occupies
`[62:57]`, SET occupies `[43:41]`, and LOOP occupies `[40:38]`.
Export the saved worksheet again to use the new layout.
ACC 3 is reserved and MAX/MAC 1 is unimplemented; both are rejected.

`IB switch`, `KSP switch` and `OB switch` are independent one-bit commands:
0 holds the active buffer; 1 toggles it before the current instruction's
access. All three active buffers reset to 0 and retain their state on SCR.
A switch executes even with its Load/Store bit zero. Inside a loop, switch=1
toggles on every execution. OB's resolved buffer ID follows its store through
the pipeline. DMA address selection and the six-bit OSP mux remain absolute.
The old `IB select`, `KSP select` and `OB select` headers are accepted as
aliases for these switch commands, with the same new semantics. Use either
heading for a field, not both. The exporter encodes commands directly; it
does not convert old absolute-buffer schedules into toggle schedules.

`IB clear=1` makes the current IB address zero immediately, ignoring IB delta
and sign; the issue edge also stores zero into the IB counter. The next
instruction can use delta=+1 to read address 1 without a setup instruction.

The OSP/BSP `clear` fields load
their counter with the unsigned offset magnitude (`abs(delta)`) at the issue
edge, ignoring the sign for this direct load. The current address still uses
the old counter plus/minus its delta. Clear with delta=0 loads zero.
KSP always captures its calculated address and has no direct-load control.
Set breakpoint selects context 1 through 7
and loads both PC+1 and the 6-bit Set iteration count (`0..63`). Selector 0
stores nothing. Conditional loop selects which context to check/decrement;
0 performs no jump. Count N permits N taken jumps, hence N+1 body executions.
Different contexts support nested loops when inner contexts are reloaded
on entry. Set iteration has no effect without Set breakpoint.

`Done=1` stops issue and holds the PC, then raises sticky slave completion
after the final instruction drains. It may share an instruction with a
final store. Reset or SCR clears completion. Older workbooks must add the
IB/OSP/BSP clear controls and Done; old hexadecimal images require re-encoding.

`Row done` is at instruction bit 37. Enter 0 for an
ordinary instruction and 1 for a row-completion marker. It may share the
final store and emits `o_row_done` after that instruction's final store is
accepted, three clocks after issue. It does not halt the slave. Put a marker
after a row loop to avoid reporting completion on every loop iteration.
The master consumes one live or remembered event with `WAIT_ROW`, encoded
as `.word 0x0000002b`. Reset or SCR clears the master's pending event. Only
one event is remembered; multiple unconsumed events coalesce. Add the
`Row done` column with explicit zeros to older workbooks before export.
No markers or waits are inserted automatically into existing programs.

The bit mapping follows `new_hw/INSTRUCTION_FORMAT.md`. The exporter does
not insert delays or analyze pipeline hazards and buffer ownership.

## Output format

Each instruction is 16 hexadecimal digits. Instructions are sorted by their
explicit addresses. Gaps use standard `$readmemh` address markers, for example:

```text
@007
0002000800000662
@00B
CA00000000002981
```

These words occupy instruction addresses 7 and 11. Locations between them
remain unspecified: the exporter does not create delay/NOP instructions for
unused rows. Enter every instruction that execution must pass through. An
explicit all-zero control row is exported as an instruction and updates EOA
with a zero-result MAC in the current core.

An entirely unused template produces an empty output file and reports zero
instructions. Invalid inputs return exit code 2 without replacing an existing
output file. Successful exports replace the output atomically. The source
workbook is read only; using it as the output path is rejected.

File initialization is independent of DMA programming. The single-system
bench directly preloads `slave_mem/single_slave_imem.mem`; it does not
overwrite that image with an embedded program. The current template retains
the existing 22 instructions, with Done set on the final OSP store.
