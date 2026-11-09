#!/usr/bin/env python3
"""Generate DSIP instruction images for a configurable grouped convolution."""

import argparse
from dataclasses import dataclass
from itertools import groupby
import json
from math import prod
from pathlib import Path

from conv1_full_program import MasterProgram, OB_BASE, SCR_X24, WAIT_DONE, WAIT_ROW
from core_compiler import FIELDS, IMEM_DEPTH, encode_instruction, memory_image, write_image

LANES = 64
IB_WORDS = 1024
KSP_WORDS = 256
OSP_WORDS = 512
OB_WORDS = 1024


def integers(name, value, length, minimum):
    if (not isinstance(value, list) or len(value) != length or
            any(type(n) is not int or n < minimum for n in value)):
        raise ValueError(f"{name} must contain {length} integers >= {minimum}")
    return tuple(value)


@dataclass(frozen=True)
class Settings:
    input_shape: tuple[int, int, int]
    weight_shape: tuple[int, int, int, int]
    stride: tuple[int, int]
    padding: tuple[int, int, int, int]
    groups: int

    @property
    def output_shape(self):
        _, height, width = self.input_shape
        filters, _, kh, kw = self.weight_shape
        top, bottom, left, right = self.padding
        sh, sw = self.stride
        return filters, (height + top + bottom - kh)//sh + 1, (width + left + right - kw)//sw + 1

    def row(self, oy):
        """Return the first real input row and the valid kernel-row interval."""
        base = oy*self.stride[0] - self.padding[0]
        first = max(0, -base)
        end = min(self.weight_shape[2], self.input_shape[1] - base)
        if first >= end:
            return 0, 0, 0
        return base + first, first, end

    @classmethod
    def parse(cls, data):
        if not isinstance(data, dict):
            raise ValueError("Settings must be a JSON object")
        unknown = data.keys() - {"input_shape", "weight_shape", "output_shape", "stride", "padding", "groups", "om"}
        if unknown:
            raise ValueError(f"Unknown settings: {', '.join(sorted(unknown))}")
        image = integers("input_shape", data.get("input_shape"), 3, 1)
        weights = integers("weight_shape", data.get("weight_shape"), 4, 1)
        stride = data.get("stride", 1)
        if type(stride) is int:
            stride = [stride, stride]
        stride = integers("stride", stride, 2, 1)
        padding = data.get("padding", 0)
        if type(padding) is int:
            padding = [padding]*4
        elif isinstance(padding, list) and len(padding) == 2:
            padding = [padding[0], padding[0], padding[1], padding[1]]
        padding = integers("padding", padding, 4, 0)
        groups = data.get("groups", 1)
        if type(groups) is not int or groups <= 0 or image[0] != groups*weights[1] or weights[0] % groups:
            raise ValueError("groups must divide the filters, with weight_shape[1] equal to input channels / groups")
        settings = cls(image, weights, stride, padding, groups)
        _, oh, ow = settings.output_shape
        if oh <= 0 or ow <= 0:
            raise ValueError("The kernel exceeds the padded input")
        if "output_shape" in data and integers("output_shape", data["output_shape"], 3, 1) != settings.output_shape:
            raise ValueError(f"output_shape must be {list(settings.output_shape)} for these settings")
        if image[2] > IB_WORDS or ow > OSP_WORDS or weights[2]*weights[3] > KSP_WORDS:
            raise ValueError("A row exceeds IB (1024 input words) or OSP (512 output words), or a kernel plane exceeds KSP (256 words)")
        return settings


class SlaveProgram:
    def __init__(self):
        self.entries = {}
        self.words = []

    def entry(self, name):
        self.entries[name] = len(self.words)

    def emit(self, **controls):
        fields = {field.name: 0 for field in FIELDS}
        if unknown := controls.keys() - fields.keys():
            raise ValueError(f"Unknown slave fields: {unknown}")
        fields.update(controls)
        for field in FIELDS:
            if not field.minimum <= fields[field.name] <= field.maximum:
                raise ValueError(f"PC {len(self.words)}: {field.name} out of range")
        self.words.append(encode_instruction(fields))
        if len(self.words) > IMEM_DEPTH:
            raise ValueError(f"Slave program exceeds the {IMEM_DEPTH}-instruction IMEM")

    def finish(self, *, row_done=False, **controls):
        self.emit(**controls, **{"Done": 1, "Row done": int(row_done)})

    def mac(self, **controls):
        self.emit(**controls, **{"Load IB": 1, "Load KSP": 1, "MULT1": 1, "MULT2": 1})

    def finish_ksp_move(self, delta, *, switch=False, row_done=False):
        # Use the shortest move on the modulo-256 KSP pointer.
        delta = (delta + 128) % KSP_WORDS - 128
        if delta == -128:
            self.emit(**{"KSP delta": -1})
            delta = -127
        self.finish(row_done=row_done, **{"KSP delta": delta, "KSP switch": int(switch)})

    def window(self, taps, ib_delta, ksp_delta, osp_delta, repeat=False):
        while abs(ib_delta) > 7 or abs(ksp_delta) > 127:
            ib_step = max(-7, min(7, ib_delta))
            ksp_step = max(-127, min(127, ksp_delta))
            self.emit(**{"IB delta": ib_step, "KSP delta": ksp_step})
            ib_delta -= ib_step
            ksp_delta -= ksp_step
        self.mac(**{"IB delta": ib_delta, "KSP delta": ksp_delta, "OSP delta": osp_delta,
                    "Load OSP": 1, "ACC": 1, "Store OSP": int(taps == 1)})
        tap = {"IB delta": 1, "KSP delta": 1, "ACC": 2}
        for remaining in range(taps - 2, 0, -64):
            count = min(remaining, 64)
            if count > 1:
                # Carry EOA through the loop setup instruction.
                self.emit(**{"ACC": 2, "Set breakpoint": 2, "Set iteration": count - 1})
            self.mac(**tap, **{"Conditional loop": 2 if count > 1 else 0})
        if taps > 1:
            self.mac(**tap, **{"Store OSP": 1})
        # OSP stores commit three clocks after issue. Drain before the next
        # OSP load, including when a window has just one valid tap.
        self.emit()
        self.emit()
        self.emit(**{"Conditional loop": int(repeat)})


def compile_slave(settings):
    p = SlaveProgram()
    _, oh, ow = settings.output_shape
    _, _, _, kw = settings.weight_shape
    width = settings.input_shape[2]
    sw = settings.stride[1]
    left = settings.padding[2]

    p.entry("zero_row")
    p.emit(**{"OSP clear": 1, "OSP delta": OSP_WORDS - 1})
    for remaining in range(ow, 0, -64):
        p.emit(**{"Set breakpoint": 1, "Set iteration": min(64, remaining) - 1})
        p.emit(**{"OSP delta": 1, "Store OSP": 1, "Conditional loop": 1})
    p.finish()

    p.entry("horizontal")
    p.emit(**{"IB clear": 1, "IB switch": 1, "OSP clear": 1})
    ib = ksp = osp = 0
    intervals = []
    for ox in range(ow):
        base = ox*sw - left
        first, end = max(0, -base), min(kw, width - base)
        intervals.append((first, end) if first < end else None)
    ox = 0
    for interval, run in groupby(intervals):
        count = sum(1 for _ in run)
        if interval is not None:
            first, end = interval
            taps = end - first
            first_ib = ox*sw - left + first
            p.window(taps, first_ib - ib, first - ksp, ox - osp)
            for remaining in range(count - 1, 0, -64):
                p.emit(**{"Set breakpoint": 1, "Set iteration": min(64, remaining) - 1})
                p.window(taps, sw - taps + 1, 1 - taps, 1, repeat=True)
            osp = ox + count - 1
            ib = osp*sw - left + end - 1
            ksp = end - 1
        ox += count
    p.finish_ksp_move(kw - ksp, row_done=True)

    # One SCR selects the loaded KSP bank and moves to the first real kernel row.
    start_moves = set()
    restore_moves = set()
    for y in range(oh):
        _, first, end = settings.row(y)
        start_moves.add(first*kw % KSP_WORDS)
        restore_moves.add(-end*kw % KSP_WORDS)
    for delta in sorted(start_moves):
        p.entry(f"begin_channel_{delta}")
        p.finish_ksp_move(delta, switch=True)
    for delta in sorted(restore_moves):
        p.entry(f"ksp_move_{delta}")
        p.finish_ksp_move(delta)

    p.entry("switch_ob")
    p.finish(**{"OB switch": 1})
    p.entry("prepare_pack")
    p.finish(**{"OSP clear": 1, "OSP delta": OSP_WORDS - 1, "Load BSP": 1})
    p.entry("pack_pixel")
    for lane in range(LANES):
        p.emit(**{"Store OB": 1, "OSP mux": lane, "Load OSP": int(lane == 0),
                  "OSP delta": int(lane == 0)})
    p.finish()
    return p


def om_addresses(settings, om):
    if not isinstance(om, dict) or om.keys() != {"input", "weights", "zero", "output"}:
        raise ValueError("Master generation requires om with input, weights, zero, and output word bases")
    addresses = {}
    regions = []
    for name, count in (("input", prod(settings.input_shape)), ("weights", prod(settings.weight_shape)),
                        ("zero", 1), ("output", prod(settings.output_shape))):
        value = om[name]
        if isinstance(value, str):
            value = int(value, 0)
        if type(value) is not int or value < 0 or value + count > 0x80000000:
            raise ValueError(f"OM {name} region exceeds the supported word address range 0..0x7FFFFFFF")
        addresses[name] = value
        regions.append((value, value + count, name))
    regions.sort()
    for (_, end, previous), (start, _, name) in zip(regions, regions[1:]):
        if start < end:
            raise ValueError(f"OM regions {previous} and {name} overlap")
    return addresses


def compile_master(settings, entries, om):
    p = MasterProgram()
    _, height, width = settings.input_shape
    filters, oh, ow = settings.output_shape
    _, channels, kh, kw = settings.weight_shape
    kernel_words = kh*kw
    filter_words = channels*kernel_words
    filters_per_group = filters // settings.groups

    def run_slave(name):
        p.load(24, entries[name])
        p.jump(3, "run_slave")

    # x6/x15 select the next IB/KSP write bank. x16/x22 track the circular
    # OB slot. x18 is the number of live lanes in the current filter batch.
    for register, value in ((6, IB_WORDS), (7, width), (8, 1), (11, kernel_words),
                            (15, 0x14000), (16, 0), (22, OB_WORDS//LANES), (25, OB_BASE), (31, 0x4000)):
        p.load(register, value)
    p.load(12, om["zero"])
    p.load(13, 0x20000)
    p.dma(0, 12, 13, 8)

    for group in range(settings.groups):
        p.load(20, om["input"] + group*channels*height*width)
        for lane_base in range(0, filters_per_group, LANES):
            first_filter = group*filters_per_group + lane_base
            p.load(18, min(LANES, filters_per_group - lane_base))
            p.load(21, om["weights"] + first_filter*filter_words)
            p.load(26, om["output"] + first_filter)
            p.jump(4, "run_batch_rows")
    p.label("park")
    p.jump(0, "park")
    p.emit(0x13, "nop")
    p.emit(0x13, "nop")

    p.label("run_batch_rows")
    for oy in range(oh):
        first_y, first, end = settings.row(oy)
        p.label(f"output_row_{oy}")
        p.load(19, first_y*width)
        p.add(19, 19, 20)
        p.load(17, oy*ow*filters)
        p.add(17, 17, 26)
        p.load(27, end - first)
        p.load(28, entries[f"begin_channel_{first*kw % KSP_WORDS}"])
        p.load(30, entries[f"ksp_move_{-end*kw % KSP_WORDS}"])
        p.jump(2, "render_row")
    p.jump_register(0, 4)

    p.label("render_row")
    run_slave("zero_row")
    p.branch_nonzero(27, "row_channels")
    p.jump(0, "emit_row")
    p.label("row_channels")
    p.load(9, channels)
    p.immediate(23, 21, 0)
    p.label("input_channel")
    p.jump(1, "load_weights")
    p.emit((31 << 20) | (15 << 15) | (4 << 12) | (15 << 7) | 0x33, "xor x15, x15, x31")
    p.immediate(24, 28, 0)
    p.jump(3, "run_slave")
    p.immediate(5, 19, 0)
    p.immediate(29, 27, 0)
    p.label("input_tap_row")
    p.jump(1, "load_input")
    p.load(24, entries["horizontal"])
    p.emit(SCR_X24, "SCR x24")
    p.emit(WAIT_ROW, "WAIT_ROW")
    p.immediate(29, 29, -1)
    p.branch_nonzero(29, "input_tap_row")
    p.immediate(24, 30, 0)
    p.jump(3, "run_slave")
    p.load(12, height*width)
    p.add(19, 19, 12)
    p.immediate(23, 23, kernel_words)
    p.immediate(9, 9, -1)
    p.branch_nonzero(9, "input_channel")

    p.label("emit_row")
    run_slave("prepare_pack")
    p.load(30, ow)
    p.label("emit_pixel")
    run_slave("pack_pixel")
    p.add(12, 25, 16)
    p.dma(1, 12, 17, 18)
    p.delay((LANES + 9)//6, "output_dma_wait")
    p.load(12, filters)
    p.add(17, 17, 12)
    p.immediate(16, 16, LANES)
    p.emit(((2*OB_WORDS - 1) << 20) | (16 << 15) | (7 << 12) | (16 << 7) | 0x13,
           "andi x16, x16, 2047")
    p.immediate(22, 22, -1)
    p.branch_nonzero(22, "next_pixel")
    run_slave("switch_ob")
    p.load(22, OB_WORDS//LANES)
    p.label("next_pixel")
    p.immediate(30, 30, -1)
    p.branch_nonzero(30, "emit_pixel")
    p.jump_register(0, 2)

    p.label("load_weights")
    p.immediate(12, 23, 0)
    p.immediate(13, 15, 0)
    p.immediate(14, 18, 0)
    p.load(29, filter_words)
    p.label("weight_lane")
    p.dma(0, 12, 13, 11)
    p.delay((kernel_words + 9)//6, "weight_dma_wait")
    p.add(12, 12, 29)
    p.immediate(13, 13, KSP_WORDS)
    p.immediate(14, 14, -1)
    p.branch_nonzero(14, "weight_lane")
    p.jump_register(0, 1)

    p.label("load_input")
    p.dma(0, 5, 6, 7)
    p.delay((width + 9)//6, "input_dma_wait")
    p.immediate(5, 5, width)
    p.immediate(6, 6, IB_WORDS, funct3=4)
    p.jump_register(0, 1)

    p.label("run_slave")
    p.emit(SCR_X24, "SCR x24")
    p.emit(WAIT_DONE, "WAIT_DONE")
    p.jump_register(0, 3)
    return p.image("Configurable grouped convolution. Generated by conv_program.py.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("settings", type=Path, help="JSON convolution settings")
    parser.add_argument("--slave", type=Path, required=True, help="Output 64-bit slave IMEM image")
    parser.add_argument("--master", type=Path, help="Optional matching 32-bit master IMEM image")
    parser.add_argument("--manifest", type=Path, help="Optional JSON dimensions, layout, and SCR entry PCs")
    args = parser.parse_args()
    paths = [path.resolve() for path in (args.settings, args.slave, args.master, args.manifest) if path]
    if len(set(paths)) != len(paths):
        parser.error("Settings and output paths must be distinct")
    try:
        data = json.loads(args.settings.read_text(encoding="utf-8-sig"))
        settings = Settings.parse(data)
        slave = compile_slave(settings)
        om = om_addresses(settings, data.get("om")) if args.master else None
        master = compile_master(settings, slave.entries, om) if args.master else None
        manifest = {
            "input_shape": settings.input_shape, "input_layout": "CHW",
            "weight_shape": settings.weight_shape, "weight_layout": "OIHW within each group",
            "output_shape": settings.output_shape, "output_layout": "pixel-major HWC",
            "stride": settings.stride, "padding": settings.padding, "groups": settings.groups,
            "slave_instructions": len(slave.words), "scr_entry_pc": slave.entries,
        }
        if om is not None:
            manifest["om_word_addresses"] = om
        write_image(args.slave, memory_image(dict(enumerate(slave.words))))
        if args.master:
            write_image(args.master, master)
        if args.manifest:
            write_image(args.manifest, json.dumps(manifest, indent=2) + "\n")
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(f"Output shape {settings.output_shape}. Slave IMEM uses {len(slave.words)}/{IMEM_DEPTH} instructions.")


if __name__ == "__main__":
    main()
