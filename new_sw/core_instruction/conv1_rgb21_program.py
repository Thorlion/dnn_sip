#!/usr/bin/env python3
"""Build the master and slave programs for 21 RGB input rows of CONV1."""

import argparse
from pathlib import Path

from core_compiler import FIELDS, IMEM_DEPTH, encode_instruction, memory_image, write_image

SYSTEM = Path(__file__).resolve().parents[2] / "new_hw/tb/single_system"
INPUT_ROWS = 21
OUTPUT_ROWS = 4
OUTPUT_COLS = 55
KERNEL_WORDS = 121
KERNEL_LANES = 64


def targets(y):
    """List output rows touched by one input row, newest first."""
    return [(oy, y - 4*oy + 2) for oy in reversed(range(OUTPUT_ROWS))
            if 0 <= y - 4*oy + 2 < 11]


def slave_channel(accumulate):
    """Emit one channel pass. Channels 1 and 2 share the accumulate entry."""
    rows = []
    # SCR retains AGU state. The previous channel ends at the last right tap
    # of kernel row 10 and OSP[219], with IB buffer 0 active.
    ksp = 119 if accumulate else 0
    osp = OUTPUT_ROWS*OUTPUT_COLS - 1 if accumulate else 0

    def mac(**controls):
        fields = {field.name: 0 for field in FIELDS}
        fields.update({"Load IB": 1, "Load KSP": 1, "MULT1": 1, "MULT2": 1})
        fields.update(controls)
        rows.append(fields)

    def emit_row(y):
        nonlocal ksp, osp
        passes = targets(y)
        for index, (oy, ky) in enumerate(passes):
            first_pass = index == 0
            first_contribution = y == max(0, 4*oy - 2)
            load_osp = int(accumulate or not first_contribution)
            first_tap = {"Load OSP": load_osp, "ACC": load_osp}
            # Left edge has 9 real taps. Skip the two padded positions.
            mac(**first_tap, **{"Set iteration": 6, "Set breakpoint": 1,
                "IB clear": 1, "IB switch": int(y != 0 and first_pass),
                "KSP switch": int(accumulate and y == 0 and first_pass),
                "KSP delta": ky*11 + 2 - ksp, "OSP delta": oy*55 - osp})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Conditional loop": 1})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Store OSP": 1,
                   "Set breakpoint": 2, "Set iteration": 52})
            # 53 interior windows of 11 real taps.
            mac(**first_tap, **{"IB delta": -6, "KSP delta": -10, "OSP delta": 1,
                "Set breakpoint": 1, "Set iteration": 8})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Conditional loop": 1})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Store OSP": 1,
                   "Conditional loop": 2})
            # Right edge has 10 real taps at input columns 214..223.
            mac(**first_tap, **{"IB delta": -6, "KSP delta": -10, "OSP delta": 1,
                "Set breakpoint": 1, "Set iteration": 7})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Conditional loop": 1})
            mac(**{"IB delta": 1, "KSP delta": 1, "ACC": 2, "Store OSP": 1,
                   "Row done": int(index == len(passes) - 1)})
            ksp, osp = ky*11 + 9, oy*55 + 54

    def emit_group(first_y, rows_per_repeat, repeats=1, context=0):
        nonlocal ksp, osp
        if repeats > 1:
            # The previous row's final MAC also records the next group's entry.
            rows[-1].update({"Set breakpoint": context, "Set iteration": repeats - 1})
        for y in range(first_y, first_y + rows_per_repeat):
            emit_row(y)
        if repeats > 1:
            rows[-1]["Conditional loop"] = context
            last_y = first_y + rows_per_repeat*repeats - 1
            oy, ky = targets(last_y)[-1]
            ksp, osp = ky*11 + 9, oy*55 + 54

    emit_group(0, 4)
    emit_group(4, 1, 2, 4)   # Rows 5..6
    emit_group(6, 4, 2, 3)   # Rows 7..14, advance one output row per stripe
    emit_group(14, 1, 3, 4)  # Rows 15..17
    emit_group(17, 1)
    emit_group(18, 1, 2, 4)  # Rows 19..20
    emit_group(20, 1)
    rows[-1]["Done"] = 1
    return rows


def master_program(accumulate_pc):
    """Assemble the small RV32/custom DMA program from named branch targets."""
    instructions = []
    labels = {}

    def emit(word, text):
        instructions.append((word, text))

    def label(name):
        labels[name] = 4*len(instructions)

    def addi(rd, rs, value):
        emit(((value & 0xfff) << 20) | (rs << 15) | (rd << 7) | 0x13,
             f"addi x{rd}, x{rs}, {value}")

    def lui(rd, value):
        emit((value << 12) | (rd << 7) | 0x37, f"lui x{rd}, 0x{value:x}")

    def alu(name, f3, rd, rs1, rs2):
        emit((rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33,
             f"{name} x{rd}, x{rs1}, x{rs2}")

    def branch(name, f3, rs1, rs2, target):
        def encode(pc):
            offset = (labels[target] - pc) & 0x1fff
            return (((offset >> 12) << 31) | (((offset >> 5) & 0x3f) << 25)
                    | (rs2 << 20) | (rs1 << 15) | (f3 << 12)
                    | (((offset >> 1) & 0xf) << 8) | (((offset >> 11) & 1) << 7) | 0x63)
        emit(encode, f"{name} x{rs1}, x{rs2}, {target}")

    def jump(rd, target):
        def encode(pc):
            offset = (labels[target] - pc) & 0x1fffff
            return (((offset & 0x100000) << 11) | ((offset & 0x7fe) << 20)
                    | ((offset & 0x800) << 9) | (offset & 0xff000) | (rd << 7) | 0x6f)
        emit(encode, f"jal x{rd}, {target}")

    def transfer(source, dest, size):
        for offset, register in [(0, source), (4, dest), (8, size), (12, 8)]:
            emit((offset << 20) | (register << 15) | 0x78,
                 f"DMA_CONFIG dma0, 0x{offset:02x}, x{register}")

    def delay(count, name):
        addi(11, 0, count)
        label(name)
        emit(0x13, "nop")
        addi(11, 11, -1)
        branch("bne", 1, 11, 0, name)

    # x20..x25 track the current input plane, next weights/buffer,
    # channels remaining, slave entry PC, and the input-plane stride.
    addi(8, 0, 1)
    addi(14, 0, KERNEL_WORDS)
    addi(10, 0, INPUT_ROWS)
    addi(17, 0, 4)
    addi(18, 0, INPUT_ROWS - 3)
    lui(19, 4)                # KSP buffer select bit
    lui(20, 0x10)             # Channel 0 image plane
    lui(21, 0x35)
    addi(21, 21, KERNEL_WORDS) # Channel 1 weight base
    lui(22, 0x14)             # KSP buffer 1
    addi(23, 0, 3)
    addi(24, 0, 0)
    lui(25, 0xc)
    addi(25, 25, 0x400)       # 224*224 words between planes
    lui(12, 0x35)
    lui(13, 0x10)
    addi(16, 0, KERNEL_LANES)
    jump(1, "load_kernels")

    label("channel_begin")
    addi(5, 20, 0)
    addi(6, 0, 0)
    addi(7, 0, 224)
    addi(9, 10, 0)
    addi(12, 21, 0)
    addi(13, 22, 0)

    label("input_row")
    transfer(5, 6, 7)
    delay(38, "input_dma_wait")
    branch("bne", 1, 9, 10, "prefetch")
    emit((24 << 15) | 0x0b, "SCR x24")
    jump(0, "advance_row")

    label("prefetch")
    branch("beq", 0, 23, 8, "wait_previous_row")  # Last channel
    branch("blt", 4, 18, 9, "wait_previous_row")  # Rows 2 and 3
    branch("beq", 0, 9, 8, "wait_previous_row")   # Row 21
    addi(16, 0, 4)
    branch("bge", 5, 9, 17, "load_batch")         # Rows 4..18
    addi(16, 0, 2)                               # Rows 19..20 have short gaps
    label("load_batch")
    jump(1, "load_kernels")
    label("wait_previous_row")
    emit(0x2b, "WAIT_ROW")

    label("advance_row")
    addi(5, 5, 224)
    emit(0x40034313, "xori x6, x6, 1024")
    addi(9, 9, -1)
    branch("bne", 1, 9, 0, "input_row")
    emit(0x2b, "WAIT_ROW  # last input row has drained")
    addi(23, 23, -1)
    branch("beq", 0, 23, 0, "park")
    alu("add", 0, 20, 20, 25)
    addi(21, 21, KERNEL_WORDS)
    alu("xor", 4, 22, 22, 19)
    addi(24, 0, accumulate_pc)
    jump(0, "channel_begin")

    label("load_kernels")
    transfer(12, 13, 14)
    delay(21, "weight_dma_wait")
    addi(12, 12, 3*KERNEL_WORDS)
    addi(13, 13, 256)
    addi(16, 16, -1)
    branch("bne", 1, 16, 0, "load_kernels")
    emit(0x8067, "jalr x0, 0(x1)")

    label("park")
    jump(0, "park")
    emit(0x13, "nop")
    emit(0x13, "nop")
    lines = ["// CONV1 RGB, input rows 1..21 for each channel and all 64 kernels.",
             "// Generated by conv1_rgb21_program.py. DMA addresses are 16-bit words.",
             "// Channel-1/2 weights preload in the inactive KSP buffer.",
             f"// Slave entry PCs: 0 (initialize sums) and {accumulate_pc} (accumulate)."]
    label_at = {address: name for name, address in labels.items()}
    for index, (word, comment) in enumerate(instructions):
        pc = 4*index
        if pc in label_at:
            lines.extend(["", f"// {label_at[pc]}:"])
        lines.append(f"{(word(pc) if callable(word) else word):08X} // PC {pc:04X}: {comment}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", type=Path, default=SYSTEM / "master_mem/single_master_imem.mem")
    parser.add_argument("--slave", type=Path, default=SYSTEM / "slave_mem/single_slave_imem.mem")
    args = parser.parse_args()
    initial = slave_channel(accumulate=False)
    rows = initial + slave_channel(accumulate=True)
    if len(rows) > IMEM_DEPTH:
        raise ValueError("Slave program exceeds IMEM depth")
    for pc, row in enumerate(rows):
        for field in FIELDS:
            if not field.minimum <= row[field.name] <= field.maximum:
                raise ValueError(f"PC {pc}: {field.name} out of range")
    write_image(args.slave, memory_image({pc: encode_instruction(row) for pc, row in enumerate(rows)}))
    write_image(args.master, master_program(len(initial)))
    print(f"Built {len(rows)} slave words with entry PCs 0 and {len(initial)}")


if __name__ == "__main__":
    main()
