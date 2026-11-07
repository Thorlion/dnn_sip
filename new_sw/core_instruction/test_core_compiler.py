"""Software tests for XLSX input validation and the slave instruction encoding."""

from contextlib import redirect_stderr, redirect_stdout
from dataclasses import dataclass
from decimal import Decimal
from io import StringIO
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from zipfile import ZipFile

import core_compiler as compiler


@dataclass
class Formula:
    text: str


def zero_controls(**changes):
    values = {field.name: 0 for field in compiler.FIELDS}
    values.update(changes)
    return values


def column_name(index):
    name = ""
    while index:
        index, remainder = divmod(index - 1, 26)
        name = chr(65 + remainder) + name
    return name


def fixture(path, rows, *, headers=None, labels=None, shared=False, sheet="Sheet1"):
    """Create small XML/ZIP input fixtures, independent of the workbook UI."""
    headers = headers or ["Address", *(field.name for field in compiler.FIELDS), "Comment", "Field check"]
    labels = labels or {}
    worksheet = ET.Element("worksheet", xmlns=compiler.SHEET_NS)
    data = ET.SubElement(worksheet, "sheetData")
    strings = []
    content = [[labels.get(name, name) for name in headers]]
    content.extend([[row.get(name) for name in headers] for row in rows])
    for index, values in enumerate(content, 1):
        row = ET.SubElement(data, "row", r=str(index))
        for column, value in enumerate(values, 1):
            if value is None:
                continue
            cell = ET.SubElement(row, "c", r=f"{column_name(column)}{index}")
            if isinstance(value, Formula):
                ET.SubElement(cell, "f").text = value.text
                ET.SubElement(cell, "v").text = "1"  # Cached value must not be assembled.
            elif isinstance(value, bool):
                cell.set("t", "b")
                ET.SubElement(cell, "v").text = "1" if value else "0"
            elif isinstance(value, (int, float, Decimal)):
                ET.SubElement(cell, "v").text = str(value)
            elif shared:
                cell.set("t", "s")
                strings.append(value)
                ET.SubElement(cell, "v").text = str(len(strings) - 1)
            else:
                cell.set("t", "inlineStr")
                ET.SubElement(ET.SubElement(cell, "is"), "t").text = value
    workbook = ET.Element("workbook", xmlns=compiler.SHEET_NS)
    sheets = ET.SubElement(workbook, "sheets")
    ET.SubElement(sheets, "sheet", name=sheet, sheetId="1", attrib={f"{{{compiler.DOC_REL_NS}}}id": "rId1"})
    relationships = ET.Element("Relationships", xmlns=compiler.PACKAGE_REL_NS)
    ET.SubElement(relationships, "Relationship", Id="rId1",
                  Type=compiler.DOC_REL_NS + "/worksheet", Target="/xl/worksheets/sheet1.xml")
    with ZipFile(path, "w") as archive:
        archive.writestr("xl/workbook.xml", ET.tostring(workbook))
        archive.writestr("xl/_rels/workbook.xml.rels", ET.tostring(relationships))
        archive.writestr("xl/worksheets/sheet1.xml", ET.tostring(worksheet))
        if shared:
            shared_xml = ET.Element("sst", xmlns=compiler.SHEET_NS)
            for text in strings:
                ET.SubElement(ET.SubElement(shared_xml, "si"), "t").text = text
            archive.writestr("xl/sharedStrings.xml", ET.tostring(shared_xml))
    return path


class ExporterTests(unittest.TestCase):
    def setUp(self):
        # Keep software-test fixtures inside the project workspace.
        root = Path(__file__).resolve().parents[3] / "tmp" / "core_compiler_tests"
        root.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(dir=root)
        self.addCleanup(self.directory.cleanup)
        self.input = Path(self.directory.name) / "input workbook.xlsx"
        self.output = Path(self.directory.name) / "output program.mem"

    def compile_rows(self, rows, **options):
        fixture(self.input, rows, **options)
        return compiler.compile_workbook(self.input, options.get("sheet", "Sheet1"))

    def active(self, address=0, **changes):
        return {"Address": address, **zero_controls(**changes)}

    def test_current_mac_instruction(self):
        values = self.active(7, **{"IB switch": 1, "KSP switch": 1, "Load IB": 1,
                                  "Load KSP": 1, "MULT1": 1, "MULT2": 1, "Store OSP": 1})
        self.assertEqual(self.compile_rows([values]), {7: 0x0002_0008_0000_0662})

    def test_current_output_instruction(self):
        values = self.active(11, **{"OB switch": 1, "OSP mux": 37, "BSP delta": 5,
                                   "Load OSP": 1, "Load BSP": 1, "Store OB": 1})
        self.assertEqual(self.compile_rows([values]), {11: 0xCA00_0000_0000_2981})

    def test_control_bits_against_literal_words(self):
        vectors = {
            "OB switch": 0x8000_0000_0000_0000,
            "Set iteration": 0x0008_0000_0000_0000,
            "Set breakpoint": 0x0000_0200_0000_0000,
            "Conditional loop": 0x0000_0040_0000_0000,
            "Done": 0x0004_0000_0000_0000,
            "Row done": 0x0000_0020_0000_0000,
            "IB switch": 0x0002_0000_0000_0000,
            "IB clear": 0x0001_0000_0000_0000,
            "KSP switch": 0x0000_0008_0000_0000,
            "OSP clear": 0x0000_0000_0400_0000,
            "BSP clear": 0x0000_0000_0000_8000,
            "Load IB": 0x0400, "Load KSP": 0x0200, "Load OSP": 0x0100,
            "Load BSP": 0x0080, "MULT1": 0x0040, "MULT2": 0x0020,
            "ACC": 0x0008, "Store OSP": 0x0002, "Store OB": 0x0001,
        }
        for field, expected in vectors.items():
            with self.subTest(field=field):
                self.assertEqual(self.compile_rows([self.active(**{field: 1})])[0], expected)

    def test_contiguous_osp_selector(self):
        for selector, expected in [(1, 0x0200_0000_0000_0000), (37, 0x4A00_0000_0000_0000),
                                   (63, 0x7E00_0000_0000_0000)]:
            with self.subTest(selector=selector):
                self.assertEqual(self.compile_rows([self.active(**{"OSP mux": selector})])[0], expected)

    def test_negative_deltas_use_sign_and_magnitude(self):
        vectors = {"IB delta": 0x0000_9000_0000_0000, "KSP delta": 0x0000_0004_0800_0000,
                   "OSP delta": 0x0000_0000_0201_0000, "BSP delta": 0x0000_0000_0000_4800}
        for field, expected in vectors.items():
            with self.subTest(field=field):
                self.assertEqual(self.compile_rows([self.active(**{field: -1})])[0], expected)

    def test_all_bits_and_largest_address(self):
        values = {field.name: field.minimum if field.sign_bit is not None else field.maximum
                  for field in compiler.FIELDS}
        values.update({"ACC": 2, "MAX/MAC": 0})
        self.assertEqual(self.compile_rows([{"Address": 511, **values}]), {511: 0xFFFF_FFEF_FFFF_FFF3})

    def test_seven_bit_ksp_magnitude(self):
        for delta, expected in [(32, 0x0000_0001_0000_0000),
                                (127, 0x0000_0003_F800_0000),
                                (-127, 0x0000_0007_F800_0000)]:
            with self.subTest(delta=delta):
                self.assertEqual(self.compile_rows([self.active(**{"KSP delta": delta})]),
                                 {0: expected})

    def test_obsolete_ksp_clear_zero_is_accepted(self):
        headers = ["Address", *(field.name for field in compiler.FIELDS), "KSP clear"]
        row = {**self.active(), "KSP clear": 0}
        self.assertEqual(self.compile_rows([row], headers=headers), {0: 0})

    def test_obsolete_ksp_clear_nonzero_is_rejected(self):
        headers = ["Address", *(field.name for field in compiler.FIELDS), "KSP clear"]
        row = {**self.active(), "KSP clear": 1}
        with self.assertRaisesRegex(compiler.CompileError, "KSP clear was removed"):
            self.compile_rows([row], headers=headers)

    def test_independent_loop_selectors_and_6_bit_count(self):
        values = self.active(**{"Set iteration": 52, "Set breakpoint": 3, "Conditional loop": 2})
        self.assertEqual(self.compile_rows([values]), {0: 0x01A0_0680_0000_0000})

    def test_extended_loop_selectors_are_contiguous(self):
        values = self.active(**{"Set breakpoint": 7, "Conditional loop": 5})
        self.assertEqual(self.compile_rows([values]), {0: 0x0000_0F40_0000_0000})

    def test_zero_loop_count_can_be_stored(self):
        self.assertEqual(self.compile_rows([self.active(**{"Set breakpoint": 2})]),
                         {0: 0x0000_0400_0000_0000})

    def test_done_can_share_the_final_store_instruction(self):
        self.assertEqual(self.compile_rows([self.active(**{"Done": 1, "Store OSP": 1})]),
                         {0: 0x0004_0000_0000_0002})

    def test_row_done_can_share_a_store_without_halting(self):
        self.assertEqual(self.compile_rows([self.active(**{"Row done": 1, "Store OSP": 1})]),
                         {0: 0x0000_0020_0000_0002})

    def test_numeric_integer_formats(self):
        self.assertEqual(self.compile_rows([self.active(**{"IB delta": Decimal("1.0")})]), {0: 1 << 44})

    def test_skip_unused_rows_but_keep_explicit_zero(self):
        rows = [{"Address": 0, "Field check": Formula('IF(1,"Unused",0)')},
                self.active(1), {"Address": 2, "Comment": "unused"}]
        self.assertEqual(self.compile_rows(rows), {1: 0})
        self.assertEqual(compiler.memory_image({1: 0}), "@001\n0000000000000000\n")

    def test_sparse_sorting_and_consecutive_words(self):
        self.assertEqual(compiler.memory_image({11: 0xC80000000004A609, 7: 0x0008008000001982}),
                         "@007\n0008008000001982\n@00B\nC80000000004A609\n")
        self.assertEqual(compiler.memory_image({1: 1, 0: 0}), "0000000000000000\n0000000000000001\n")

    def test_shared_strings_and_reordered_headers(self):
        headers = ["Field check", *(field.name for field in reversed(compiler.FIELDS)), "Address"]
        rows = [self.active(9, **{"OB switch": 1, "Field check": Formula('IF(1,"Ready",0)')})]
        result = self.compile_rows(rows, headers=headers, labels={"OB switch": "  ob   SWITCH  "}, shared=True)
        self.assertEqual(result, {9: 1 << 63})

    def test_legacy_buffer_headers_are_switch_aliases(self):
        labels = {f"{buffer} switch": f"{buffer} select" for buffer in ["OB", "IB", "KSP"]}
        result = self.compile_rows([self.active(**{"OB switch": 1, "IB switch": 1,
                                                   "KSP switch": 1})], labels=labels)
        self.assertEqual(result, {0: 0x8002_0008_0000_0000})

    def test_legacy_and_new_buffer_headers_are_duplicates(self):
        headers = ["Address", *(field.name for field in compiler.FIELDS), "IB select"]
        with self.assertRaisesRegex(compiler.CompileError, "Duplicate column header"):
            self.compile_rows([self.active()], headers=headers)

    def test_missing_header(self):
        headers = ["Address", *(field.name for field in compiler.FIELDS if field.name != "Store OB")]
        with self.assertRaisesRegex(compiler.CompileError, "Missing required column.*Store OB"):
            self.compile_rows([self.active()], headers=headers)

    def test_duplicate_header(self):
        headers = ["Address", *(field.name for field in compiler.FIELDS), "Address"]
        with self.assertRaisesRegex(compiler.CompileError, "Duplicate column"):
            self.compile_rows([self.active()], headers=headers)

    def test_duplicate_active_addresses(self):
        with self.assertRaisesRegex(compiler.CompileError, "also occurs in row 2"):
            self.compile_rows([self.active(7), self.active(7)])

    def test_address_limits(self):
        for address in [-1, 512]:
            with self.subTest(address=address), self.assertRaisesRegex(compiler.CompileError, "Address.*outside"):
                self.compile_rows([self.active(address)])

    def test_invalid_values_are_rejected(self):
        for field, value in [("OB switch", 2), ("OSP mux", 64), ("Set iteration", 64),
                             ("Set breakpoint", 8), ("Conditional loop", 8), ("Done", 2),
                             ("IB clear", 2), ("OSP clear", 2), ("BSP clear", 2),
                             ("IB delta", -8), ("KSP delta", 128), ("KSP delta", -128), ("OSP delta", 512),
                             ("BSP delta", -8), ("Load IB", 0.5), ("MULT1", "1"),
                             ("MULT2", True), ("Store OB", None), ("Load BSP", Formula("1+0"))]:
            with self.subTest(field=field, value=value), self.assertRaises(compiler.CompileError):
                self.compile_rows([self.active(**{field: value})])

    def test_reserved_and_unimplemented_modes(self):
        for changes, message in [({"ACC": 3}, "reserved"), ({"MAX/MAC": 1}, "not implemented")]:
            with self.subTest(changes=changes), self.assertRaisesRegex(compiler.CompileError, message):
                self.compile_rows([self.active(**changes)])

    def test_custom_paths_and_sheet(self):
        fixture(self.input, [self.active(511, **{"Store OB": 1})], sheet="Instructions")
        with redirect_stdout(StringIO()):
            status = compiler.main(["-i", str(self.input), "-o", str(self.output), "--sheet", "Instructions"])
        self.assertEqual(status, 0)
        self.assertEqual(self.output.read_text(), "@1FF\n0000000000000001\n")

    def test_empty_workbook_creates_empty_output(self):
        fixture(self.input, [{"Address": 0}])
        with redirect_stdout(StringIO()):
            status = compiler.main(["-i", str(self.input), "-o", str(self.output)])
        self.assertEqual(status, 0)
        self.assertEqual(self.output.read_bytes(), b"")

    def test_invalid_input_preserves_existing_output(self):
        fixture(self.input, [self.active(**{"ACC": 3})])
        self.output.write_text("keep this output\n")
        with redirect_stderr(StringIO()):
            status = compiler.main(["-i", str(self.input), "-o", str(self.output)])
        self.assertEqual(status, 2)
        self.assertEqual(self.output.read_text(), "keep this output\n")

    def test_source_cannot_be_overwritten(self):
        fixture(self.input, [self.active()])
        before = self.input.read_bytes()
        with redirect_stderr(StringIO()):
            status = compiler.main(["-i", str(self.input), "-o", str(self.input)])
        self.assertEqual(status, 2)
        self.assertEqual(self.input.read_bytes(), before)

    def test_missing_worksheet(self):
        fixture(self.input, [])
        with self.assertRaisesRegex(compiler.CompileError, "not found.*Sheet1"):
            compiler.compile_workbook(self.input, "Missing")


if __name__ == "__main__":
    unittest.main()
