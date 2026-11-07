#!/usr/bin/env python3
"""Export the slave instruction worksheet to a 64-bit $readmemh image.

Python 3.10+, standard library only. Defaults are relative to this script;
explicit paths are relative to the current working directory.

    python core_compiler.py
    python core_compiler.py --input schedule.xlsx --output instruction.mem
    python core_compiler.py -i schedule.xlsx -o program.mem --sheet Sheet1

Blank control rows are unused. Active rows require every control to be a
literal integer. Address gaps use @ hexadecimal directives, leaving those
IMEM locations unspecified rather than inserting zero-result MAC operations.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
import os
from pathlib import Path
import posixpath
import sys
import tempfile
import xml.etree.ElementTree as ET
from zipfile import BadZipFile, ZipFile


SCRIPT_DIR = Path(__file__).resolve().parent
IMEM_DEPTH = 512
SHEET_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DOC_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PACKAGE_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"s": SHEET_NS, "r": DOC_REL_NS}


class CompileError(ValueError):
    """Invalid workbook structure or instruction input."""


@dataclass(frozen=True)
class Field:
    name: str
    bit: int
    width: int
    sign_bit: int | None = None

    @property
    def maximum(self) -> int:
        return (1 << self.width) - 1

    @property
    def minimum(self) -> int:
        return -self.maximum if self.sign_bit is not None else 0


# Current RTL: new_hw/INSTRUCTION_FORMAT.md and ip/slave_core/dec_if.sv.
# bit is the least-significant magnitude/data bit.
# Delta width excludes its separate sign bit.
FIELDS = (
    Field("OB switch", 63, 1),
    Field("OSP mux", 57, 6),
    Field("Set iteration", 51, 6),
    Field("Set breakpoint", 41, 3),
    Field("Conditional loop", 38, 3),
    Field("Done", 50, 1),
    Field("Row done", 37, 1),
    Field("IB switch", 49, 1),
    Field("IB clear", 48, 1),
    Field("IB delta", 44, 3, sign_bit=47),
    Field("KSP switch", 35, 1),
    Field("KSP delta", 27, 7, sign_bit=34),
    Field("OSP clear", 26, 1),
    Field("OSP delta", 16, 9, sign_bit=25),
    Field("BSP clear", 15, 1),
    Field("BSP delta", 11, 3, sign_bit=14),
    Field("Load IB", 10, 1),
    Field("Load KSP", 9, 1),
    Field("Load OSP", 8, 1),
    Field("Load BSP", 7, 1),
    Field("MULT1", 6, 1),
    Field("MULT2", 5, 1),
    Field("ACC", 3, 2),
    Field("MAX/MAC", 2, 1),
    Field("Store OSP", 1, 1),
    Field("Store OB", 0, 1),
)


@dataclass(frozen=True)
class Cell:
    value: str | Decimal | bool | None
    formula: str | None = None

    @property
    def blank(self) -> bool:
        return self.formula is None and (
            self.value is None or
            (isinstance(self.value, str) and not self.value.strip())
        )


def column_number(reference: str) -> int:
    """Convert the column portion of an A1 address to a zero-based index."""
    number = 0
    for char in reference:
        if char.isdigit():
            break
        if not ("A" <= char <= "Z"):
            raise CompileError(f"Invalid XLSX cell reference: {reference!r}")
        number = number * 26 + ord(char) - ord("A") + 1
    if number == 0:
        raise CompileError(f"Missing column in XLSX cell reference: {reference!r}")
    return number - 1


def worksheet_path(archive: ZipFile, sheet_name: str) -> str:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    sheets = workbook.findall("s:sheets/s:sheet", NS)
    sheet = next((item for item in sheets if item.get("name") == sheet_name), None)
    if sheet is None:
        names = ", ".join(item.get("name", "") for item in sheets)
        raise CompileError(f"Worksheet {sheet_name!r} not found. Available: {names}")
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    relationship_id = sheet.get(f"{{{DOC_REL_NS}}}id")
    for relationship in relationships.findall(f"{{{PACKAGE_REL_NS}}}Relationship"):
        if relationship.get("Id") == relationship_id:
            if relationship.get("TargetMode") == "External":
                raise CompileError("External worksheet links are not supported.")
            target = relationship.get("Target", "")
            part = posixpath.normpath(
                target.lstrip("/") if target.startswith("/") else
                posixpath.join("xl", target)
            )
            if not part.startswith("xl/"):
                raise CompileError(f"Invalid worksheet target: {target!r}")
            return part
    raise CompileError(f"Cannot resolve worksheet {sheet_name!r}.")


def read_cell(element: ET.Element, shared_strings: list[str]) -> Cell:
    formula = element.find("s:f", NS)
    if formula is not None:
        # Do not assemble stale cached formula values. The workbook's computed
        # Field check column is ignored; instruction inputs must be literal.
        return Cell(None, formula.text or "")
    kind = element.get("t", "n")
    value = element.find("s:v", NS)
    text = value.text if value is not None else None
    if kind == "inlineStr":
        return Cell("".join(item.text or "" for item in element.findall("s:is//s:t", NS)))
    if text is None:
        return Cell(None)
    if kind == "s":
        try:
            return Cell(shared_strings[int(text)])
        except (ValueError, IndexError) as error:
            raise CompileError(f"Invalid shared string index: {text!r}") from error
    if kind == "b":
        return Cell(text == "1")
    if kind == "n":
        try:
            return Cell(Decimal(text))
        except InvalidOperation as error:
            raise CompileError(f"Invalid numeric cell value: {text!r}") from error
    return Cell(text)


def read_rows(input_path: Path, sheet_name: str) -> list[tuple[int, dict[int, Cell]]]:
    """Read just the XLSX worksheet data; no Excel installation is needed."""
    with ZipFile(input_path) as archive:
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            shared_strings = [
                "".join(item.text or "" for item in entry.findall(".//s:t", NS))
                for entry in root.findall("s:si", NS)
            ]
        worksheet = ET.fromstring(archive.read(worksheet_path(archive, sheet_name)))
        rows = []
        for row in worksheet.findall("s:sheetData/s:row", NS):
            cells = {
                column_number(cell.attrib["r"]): read_cell(cell, shared_strings)
                for cell in row.findall("s:c", NS)
            }
            rows.append((int(row.attrib["r"]), cells))
        return rows


def normalize_header(text: str) -> str:
    key = " ".join(text.casefold().split())
    # Existing worksheets may retain the old headings. Their bits now use
    # hold/switch semantics too; these aliases do not encode absolute IDs.
    return {"ob select": "ob switch", "ib select": "ib switch",
            "ksp select": "ksp switch"}.get(key, key)


def integer(cell: Cell | None, name: str, row: int, minimum: int, maximum: int) -> int:
    prefix = f"Row {row}, {name}"
    if cell is None or cell.blank:
        raise CompileError(f"{prefix}: required for an active instruction; use an explicit 0.")
    if cell.formula is not None:
        raise CompileError(f"{prefix}: formulas are not supported in inputs; paste the calculated integer as a value.")
    number = cell.value
    if not isinstance(number, Decimal) or not number.is_finite() or number != number.to_integral_value():
        raise CompileError(f"{prefix}: expected a numeric integer, got {number!r}.")
    if not minimum <= number <= maximum:
        raise CompileError(f"{prefix}: {number} is outside {minimum}..{maximum}.")
    return int(number)


def encode_instruction(values: dict[str, int]) -> int:
    word = 0
    for field in FIELDS:
        value = values[field.name]
        if field.sign_bit is not None:
            word |= int(value < 0) << field.sign_bit
            word |= abs(value) << field.bit
        else:
            word |= value << field.bit
    return word


def compile_workbook(input_path: Path, sheet_name: str = "Sheet1") -> dict[int, int]:
    rows = read_rows(input_path, sheet_name)
    header = next((cells for row, cells in rows if row == 1), None)
    if header is None:
        raise CompileError("The worksheet must have its column headers in row 1.")
    columns: dict[str, int] = {}
    for column, cell in header.items():
        if cell.blank:
            continue
        if cell.formula is not None or not isinstance(cell.value, str):
            raise CompileError("Column headers must be text values.")
        key = normalize_header(cell.value)
        if key in columns:
            raise CompileError(f"Duplicate column header: {cell.value!r}.")
        columns[key] = column
    required = ("Address", *(field.name for field in FIELDS))
    missing = [name for name in required if normalize_header(name) not in columns]
    if missing:
        raise CompileError("Missing required column(s): " + ", ".join(missing))

    instructions: dict[int, int] = {}
    address_rows: dict[int, int] = {}
    for row, cells in rows:
        if row == 1:
            continue
        legacy_clear = cells.get(columns.get("ksp clear", -1))
        if legacy_clear is not None and not legacy_clear.blank:
            if integer(legacy_clear, "KSP clear", row, 0, 1):
                raise CompileError(f"Row {row}: KSP clear was removed; delete the obsolete column or set it to 0.")
        controls = {field.name: cells.get(columns[normalize_header(field.name)]) for field in FIELDS}
        if all(cell is None or cell.blank for cell in controls.values()):
            continue
        address = integer(cells.get(columns[normalize_header("Address")]), "Address", row, 0, IMEM_DEPTH - 1)
        if address in instructions:
            raise CompileError(f"Row {row}: instruction address {address} also occurs in row {address_rows[address]}.")
        values = {
            field.name: integer(controls[field.name], field.name, row, field.minimum, field.maximum)
            for field in FIELDS
        }
        if values["ACC"] == 3:
            raise CompileError(f"Row {row}, ACC: encoding 3 is reserved by the current instruction specification.")
        if values["MAX/MAC"] == 1:
            raise CompileError(f"Row {row}, MAX/MAC: MAX mode is not implemented; use 0 for MAC.")
        instructions[address] = encode_instruction(values)
        address_rows[address] = row
    return instructions


def memory_image(instructions: dict[int, int]) -> str:
    """Preserve sparse instruction indices using standard $readmemh markers."""
    lines: list[str] = []
    next_address = 0
    for address, word in sorted(instructions.items()):
        if address != next_address:
            lines.append(f"@{address:03X}")
        lines.append(f"{word:016X}")
        next_address = address + 1
    return "\n".join(lines) + ("\n" if lines else "")


def write_image(output_path: Path, text: str) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="ascii", newline="\n",
                                         dir=output_path.parent, prefix=".instruction_",
                                         suffix=".tmp", delete=False) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(text)
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-i", "--input", type=Path,
                        default=SCRIPT_DIR / "slave_instruction_template.xlsx", help="Input .xlsx workbook")
    parser.add_argument("-o", "--output", type=Path,
                        default=SCRIPT_DIR / "instruction.mem", help="Output $readmemh instruction image")
    parser.add_argument("--sheet", default="Sheet1", help="Instruction worksheet name (default: Sheet1)")
    args = parser.parse_args(argv)
    try:
        input_path = args.input.expanduser().resolve()
        output_path = args.output.expanduser().resolve()
        if input_path == output_path or (output_path.exists() and input_path.samefile(output_path)):
            raise CompileError("Input and output must be different files.")
        instructions = compile_workbook(input_path, args.sheet)
        write_image(output_path, memory_image(instructions))
    except (CompileError, OSError, BadZipFile, ET.ParseError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    print(f"Exported {len(instructions)} instruction(s) to {output_path}")
    if instructions:
        print(f"Instruction addresses: {min(instructions)}..{max(instructions)}; 64-bit hexadecimal words.")
    else:
        print("The worksheet has no active instruction rows; the output file is empty.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
