#!/usr/bin/env python3
"""Generate master and slave IMEM images for 96-filter AlexNet CONV1."""

import argparse
from pathlib import Path

from core_compiler import FIELDS, IMEM_DEPTH, encode_instruction, memory_image, write_image

SYSTEM = Path(__file__).resolve().parents[2] / "new_hw/tb/single_system"
IMAGE_BASE = 0x10000
WEIGHT_BASE = 0x35000
OUTPUT_BASE = 0x40000
OB_BASE = 0x40000
IMAGE_SIZE = 224
OUTPUT_SIZE = 55
TILE_ROWS = 4
LANES = 64
FILTERS = 96
INPUT_CHANNELS = 3
KERNEL_SIZE = 11
KERNEL_WORDS = KERNEL_SIZE**2
FILTER_WORDS = INPUT_CHANNELS*KERNEL_WORDS
ZERO_BIAS_BASE = WEIGHT_BASE + FILTERS*FILTER_WORDS
OB_WORDS = 1024
OSP_BATCH_STRIDE = 256
GROUP_WORDS = FILTERS - LANES
GROUPS_PER_PIXEL = FILTERS // GROUP_WORDS
GROUPS_PER_BLOCK = OB_WORDS // GROUP_WORDS
KSP_BASES = (0x10000, 0x14000, 0x10080)
SCR_X24 = (24 << 15) | 0x0B
WAIT_ROW = 0x2B
WAIT_DONE = (1 << 12) | WAIT_ROW


def slave_program():
    instructions = []
    entries = {}

    def emit(**controls):
        fields = {field.name: 0 for field in FIELDS}
        if unknown := controls.keys() - fields.keys():
            raise ValueError(f"Unknown fields: {unknown}")
        fields.update(controls)
        for field in FIELDS:
            if not field.minimum <= fields[field.name] <= field.maximum:
                raise ValueError(f"PC {len(instructions)}: {field.name} out of range")
        instructions.append(encode_instruction(fields))

    def entry(name):
        entries[name] = len(instructions)

    def finish(*, row_done=False, **controls):
        emit(**controls, **{"Done": 1, "Row done": int(row_done)})

    def mac(**controls):
        emit(**controls, **{"Load IB": 1, "Load KSP": 1, "MULT1": 1, "MULT2": 1})

    def horizontal(ky, initialize, row_done):
        # Entry and exit use the same KSP channel base and OSP row base.
        first_tap = {"Load OSP": int(not initialize), "ACC": int(not initialize)}
        tap = {"IB delta": 1, "KSP delta": 1, "ACC": 2}
        mac(**first_tap, **{"IB clear": 1, "KSP delta": ky*11 + 2,
                            "Set breakpoint": 1, "Set iteration": 6})
        mac(**tap, **{"Conditional loop": 1})
        mac(**tap, **{"Store OSP": 1, "Set breakpoint": 2, "Set iteration": 52})
        mac(**first_tap, **{"IB delta": -6, "KSP delta": -10, "OSP delta": 1,
                            "Set breakpoint": 1, "Set iteration": 8})
        mac(**tap, **{"Conditional loop": 1})
        mac(**tap, **{"Store OSP": 1, "Conditional loop": 2})
        mac(**first_tap, **{"IB delta": -6, "KSP delta": -10, "OSP delta": 1,
                            "Set breakpoint": 1, "Set iteration": 7})
        mac(**tap, **{"Conditional loop": 1})
        mac(**tap, **{"Store OSP": 1})
        finish(row_done=row_done, **{"KSP delta": -(ky*11 + 9), "OSP delta": 1 - OUTPUT_SIZE})

    for row_done in (False, True):
        for ky in range(KERNEL_SIZE):
            # Only the first real tap row of a channel-0 output initializes OSP.
            if ky in (0, 2):
                entry((f"init_{ky}", row_done))
                horizontal(ky, initialize=True, row_done=row_done)
            entry((f"accumulate_{ky}", row_done))
            horizontal(ky, initialize=False, row_done=row_done)

    for step in (0, -1, -2):
        entry(f"next_input_{step}")
        finish(**{"IB switch": 1, "OSP delta": step*OUTPUT_SIZE})
    entry("next_output_row")
    finish(**{"OSP delta": OUTPUT_SIZE})

    for batch in range(2):
        osp_base = {"OSP clear": 1, "OSP delta": batch*OSP_BATCH_STRIDE}
        entry(f"channel_0_batch_{batch}")
        finish(**osp_base)
        entry(f"channel_1_batch_{batch}")
        finish(**osp_base, **{"KSP switch": 1})
        entry(f"channel_2_batch_{batch}")
        emit(**{"KSP switch": 1, "KSP delta": 64})
        finish(**osp_base, **{"KSP delta": 64})
    entry("finish_batch")
    # Return KSP from 128 to 0 for the next batch.
    emit(**{"KSP delta": 64})
    finish(**{"KSP delta": 64})
    entry("prepare_output")
    finish(**{"OSP clear": 1, "OSP delta": OSP_BATCH_STRIDE - 1, "Load BSP": 1})
    entry("switch_ob")
    finish(**{"OB switch": 1})

    # Each pixel packs lanes 0..63 from batch 0 and lanes 0..31 from batch 1.
    # Full OB boundaries can split a pixel into a 32- or 64-word fragment.
    groups = ((0, 1 - OSP_BATCH_STRIDE), (GROUP_WORDS, 0), (0, OSP_BATCH_STRIDE))
    for count in (3, 2, 1):
        entry(f"pack_0_{count}")
        for phase, (first_lane, delta) in enumerate(groups[:count]):
            # A partial pixel can enter the full sequence at its next group.
            if count == 3 and phase:
                entry(f"pack_{phase}_{count - phase}")
            for lane in range(first_lane, first_lane + GROUP_WORDS):
                first = lane == first_lane
                emit(**{"OSP mux": lane, "Store OB": 1, "Load OSP": int(first),
                        "OSP delta": delta if first else 0})
        finish()

    if len(instructions) > IMEM_DEPTH:
        raise ValueError("Slave program exceeds IMEM depth")
    return entries, memory_image(dict(enumerate(instructions)))


class MasterProgram:
    """Assemble the RV32 instructions used by the CONV1 schedule."""

    def __init__(self):
        self.instructions = []
        self.labels = {}

    def emit(self, word, comment):
        self.instructions.append((word, comment))

    def label(self, name):
        self.labels[name] = 4*len(self.instructions)

    def immediate(self, rd, rs, value, funct3=0):
        if not -2048 <= value < 2048:
            raise ValueError(f"I-type immediate out of range: {value}")
        self.emit(((value & 0xFFF) << 20) | (rs << 15) | (funct3 << 12) | (rd << 7) | 0x13,
                  f"{'xori' if funct3 else 'addi'} x{rd}, x{rs}, {value}")

    def load(self, rd, value):
        if -2048 <= value < 2048:
            self.immediate(rd, 0, value)
        else:
            upper = (value + 2048) >> 12
            self.emit((upper << 12) | (rd << 7) | 0x37, f"lui x{rd}, 0x{upper:X}")
            low = value - (upper << 12)
            if low:
                self.immediate(rd, rd, low)

    def load_label(self, rd, name):
        self.emit(lambda pc: (((self.labels[name] + 2048) >> 12) << 12) | (rd << 7) | 0x37,
                  f"lui x{rd}, %hi({name})")
        self.emit(lambda pc: ((self.labels[name] & 0xFFF) << 20) | (rd << 15) | (rd << 7) | 0x13,
                  f"addi x{rd}, x{rd}, %lo({name})")

    def add(self, rd, rs1, rs2):
        self.emit((rs2 << 20) | (rs1 << 15) | (rd << 7) | 0x33, f"add x{rd}, x{rs1}, x{rs2}")

    def branch_nonzero(self, rs, target):
        def encode(pc):
            offset = (self.labels[target] - pc) & 0x1FFF
            return (((offset >> 12) << 31) | (((offset >> 5) & 0x3F) << 25)
                    | (rs << 15) | (1 << 12) | (((offset >> 1) & 0xF) << 8)
                    | (((offset >> 11) & 1) << 7) | 0x63)
        self.emit(encode, f"bne x{rs}, x0, {target}")

    def jump(self, rd, target):
        def encode(pc):
            offset = (self.labels[target] - pc) & 0x1FFFFF
            return (((offset & 0x100000) << 11) | ((offset & 0x7FE) << 20)
                    | ((offset & 0x800) << 9) | (offset & 0xFF000) | (rd << 7) | 0x6F)
        self.emit(encode, f"jal x{rd}, {target}")

    def jump_register(self, rd, rs):
        self.emit((rs << 15) | (rd << 7) | 0x67, f"jalr x{rd}, 0(x{rs})")

    def dma(self, channel, source, dest, size):
        for offset, reg in ((0, source), (4, dest), (8, size), (12, 8)):
            self.emit((offset << 20) | (reg << 15) | (channel << 12) | 0x78,
                      f"DMA_CONFIG dma{channel}, 0x{offset:02x}, x{reg}")

    def delay(self, iterations, name):
        self.load(10, iterations)
        self.label(name)
        self.emit(0x13, "nop")
        self.immediate(10, 10, -1)
        self.branch_nonzero(10, name)

    def image(self, description="96-filter CONV1. Generated by conv1_full_program.py."):
        if len(self.instructions) >= 4096:
            raise ValueError("Master program exceeds IMEM depth")
        lines = [f"// {description}",
                 "// DMA addresses and transfer sizes count 16-bit words."]
        labels_at = {address: name for name, address in self.labels.items()}
        for index, (word, comment) in enumerate(self.instructions):
            pc = 4*index
            if pc in labels_at:
                lines.extend(["", f"// {labels_at[pc]}:"])
            lines.append(f"{(word(pc) if callable(word) else word):08X} // PC {pc:04X}: {comment}")
        return "\n".join(lines) + "\n"


def master_program(slave_entries):
    p = MasterProgram()
    init_offset = slave_entries[("accumulate_0", True)] - slave_entries[("init_0", True)]
    for row_done in (False, True):
        for ky in (0, 2):
            if slave_entries[(f"accumulate_{ky}", row_done)] - slave_entries[(f"init_{ky}", row_done)] != init_offset:
                raise ValueError("Initialization routines must have the same length")
    batch_entry_stride = slave_entries["channel_0_batch_1"] - slave_entries["channel_0_batch_0"]

    def select_slave(name, entry_offset_reg=0):
        p.load(24, slave_entries[name])
        if entry_offset_reg:
            p.add(24, 24, entry_offset_reg)

    def run_slave(name, entry_offset_reg=0, *, row_done=False):
        select_slave(name, entry_offset_reg)
        p.jump(3, "run_input_row" if row_done else "run_slave")

    def pack_groups(first, count):
        # Finish an interrupted pixel, emit whole pixels, then emit a prefix.
        phase = first % GROUPS_PER_PIXEL
        if phase:
            prefix = GROUPS_PER_PIXEL - phase
            run_slave(f"pack_{phase}_{prefix}")
            count -= prefix
        pixels, tail = divmod(count, GROUPS_PER_PIXEL)
        if pixels:
            p.load(22, pixels)
            p.jump(29, "pack_pixels")
        if tail:
            run_slave(f"pack_0_{tail}")

    # Persistent registers: x5/x6 next input source/IB bank, x16/x17/x18
    # DMA1 source/destination/length, x19 tile input base, x21 tile shape PC,
    # x23 remaining prefetch lanes, x26/x27 incoming weight batch base/count,
    # and x31 slave channel entry offset.
    p.load(8, 1)
    p.load(6, 1024)
    p.load(7, IMAGE_SIZE)
    p.load(11, KERNEL_WORDS)
    p.load(16, OB_BASE)
    p.load(17, OUTPUT_BASE)
    p.load(18, OB_WORDS)
    p.load(25, IMAGE_SIZE**2)
    p.load(26, WEIGHT_BASE)
    p.load(27, LANES)
    p.jump(30, "load_batch")
    # Lanes 32..63 keep their first-batch weights for the whole image.

    # Supply a zero operand to the existing BSP adder.
    p.load(12, ZERO_BIAS_BASE)
    p.load(13, 0x20000)
    p.dma(0, 12, 13, 8)

    shapes = {}
    packed = 0
    resident_batch = 0
    for oy in range(0, OUTPUT_SIZE, TILE_ROWS):
        end_oy = min(oy + TILE_ROWS, OUTPUT_SIZE)
        first_y = max(0, 4*oy - 2)
        end_y = min(IMAGE_SIZE, 4*(end_oy - 1) - 2 + KERNEL_SIZE)
        shape = (end_oy - oy, first_y - (4*oy - 2), end_y - first_y)
        name = shapes.setdefault(shape, f"shape_{len(shapes)}")
        p.label(f"tile_{oy}")
        p.load_label(21, name)
        # Reverse the batch order on alternating tiles to reuse resident weights.
        incoming_batch = 1 - resident_batch
        p.load(26, WEIGHT_BASE + incoming_batch*LANES*FILTER_WORDS)
        for batch, entry_name in ((resident_batch, "compute_and_prefetch_batch"),
                                  (incoming_batch, "compute_and_prefetch_tail")):
            p.load(19, IMAGE_BASE + first_y*IMAGE_SIZE)
            p.load(31, batch*batch_entry_stride)
            p.jump(2, entry_name)
        resident_batch = incoming_batch
        run_slave("prepare_output")
        remaining = (end_oy - oy)*OUTPUT_SIZE*GROUPS_PER_PIXEL
        while remaining:
            groups = min(remaining, GROUPS_PER_BLOCK - packed % GROUPS_PER_BLOCK)
            pack_groups(packed, groups)
            packed += groups
            remaining -= groups
            if packed % GROUPS_PER_BLOCK == 0:
                p.jump(28, "drain_ob")
                run_slave("switch_ob")

    # The short final block can finish before the preceding DMA1.
    p.delay(172, "wait_before_tail")
    p.load(18, packed*GROUP_WORDS % OB_WORDS)
    p.jump(28, "drain_ob")
    p.label("park")
    p.jump(0, "park")
    p.emit(0x13, "nop")
    p.emit(0x13, "nop")

    # Once a channel is finished, its KSP slice can be replaced while the
    # slave reads the other bank. The incoming batch's channel 2 slice is
    # filled during its own channel 1, after the old batch has released it.
    for entry_name, prefetch_channels in (
        ("compute_and_prefetch_batch", (None, 0, 1)),
        ("compute_and_prefetch_tail", (None, 2, None)),
    ):
        p.label(entry_name)
        for channel, target in enumerate(prefetch_channels):
            run_slave(f"channel_{channel}_batch_0", 31)
            p.immediate(5, 19, 0)
            p.load(20, init_offset if channel else 0)
            p.load(23, GROUP_WORDS if target is not None else 0)
            if target is not None:
                p.immediate(12, 26, target*KERNEL_WORDS)
                p.load(13, KSP_BASES[target])
            p.jump_register(4, 21)
            if channel + 1 < INPUT_CHANNELS:
                p.add(19, 19, 25)
        run_slave("finish_batch")
        p.jump_register(0, 2)

    for (rows, first_y, count), name in shapes.items():
        if count < GROUP_WORDS // 2:
            raise ValueError("CONV1 tile has too few row windows for weight prefetch")
        p.label(name)
        p.jump(1, "load_input")
        p.delay(38, f"{name}_first_dma_wait")
        previous_oy = 0
        for y in range(first_y, first_y + count):
            # Prefetch the next input row while these horizontal passes run.
            if y + 1 < first_y + count:
                p.jump(1, "load_input")
            targets = [(oy, y - 4*oy) for oy in range(rows) if 0 <= y - 4*oy < KERNEL_SIZE]
            run_slave(f"next_input_{targets[0][0] - previous_oy}")
            for index, (oy, ky) in enumerate(targets):
                if index:
                    run_slave("next_output_row")
                initialize = ky == max(0, first_y - 4*oy)
                row_done = index == len(targets) - 1
                name = f"init_{ky}" if initialize else f"accumulate_{ky}"
                if index == 0 and y - first_y < GROUP_WORDS // 2:
                    select_slave((name, row_done), 20 if initialize else 0)
                    p.emit(SCR_X24, "SCR x24")
                    p.jump(30, "prefetch_row_weights")
                    p.emit(WAIT_ROW if row_done else WAIT_DONE, "WAIT_ROW" if row_done else "WAIT_DONE")
                else:
                    run_slave((name, row_done), 20 if initialize else 0, row_done=row_done)
                previous_oy = oy
        p.jump_register(0, 4)

    p.label("run_slave")
    p.emit(SCR_X24, "SCR x24")
    p.emit(WAIT_DONE, "WAIT_DONE")
    p.jump_register(0, 3)

    p.label("run_input_row")
    p.emit(SCR_X24, "SCR x24")
    p.emit(WAIT_ROW, "WAIT_ROW")
    p.jump_register(0, 3)

    p.label("load_input")
    p.dma(0, 5, 6, 7)
    p.immediate(5, 5, IMAGE_SIZE)
    p.immediate(6, 6, 1024, funct3=4)
    p.jump_register(0, 1)

    p.label("load_weights")
    p.dma(0, 12, 13, 11)
    p.delay(21, "weight_dma_wait")
    p.immediate(12, 12, FILTER_WORDS)
    p.immediate(13, 13, 256)
    p.immediate(14, 14, -1)
    p.branch_nonzero(14, "load_weights")
    p.jump_register(0, 1)

    p.label("prefetch_row_weights")
    p.branch_nonzero(23, "prefetch_two_lanes")
    p.jump_register(0, 30)
    p.label("prefetch_two_lanes")
    p.delay(38, "prefetch_ib_wait")
    p.load(14, 2)
    p.jump(1, "load_weights")
    p.immediate(23, 23, -2)
    p.jump_register(0, 30)

    p.label("load_batch")
    for channel, ksp_base in enumerate(KSP_BASES):
        p.immediate(12, 26, channel*KERNEL_WORDS)
        p.load(13, ksp_base)
        p.immediate(14, 27, 0)
        p.jump(1, "load_weights")
    p.jump_register(0, 30)

    p.label("pack_pixels")
    run_slave("pack_0_3")
    p.immediate(22, 22, -1)
    p.branch_nonzero(22, "pack_pixels")
    p.jump_register(0, 29)

    p.label("drain_ob")
    p.dma(1, 16, 17, 18)
    p.add(17, 17, 18)
    p.immediate(16, 16, OB_WORDS, funct3=4)
    p.jump_register(0, 28)
    return p.image()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", type=Path, default=SYSTEM / "master_mem/conv1_master_imem.mem")
    parser.add_argument("--slave", type=Path, default=SYSTEM / "slave_mem/conv1_slave_imem.mem")
    args = parser.parse_args()
    entries, slave = slave_program()
    master = master_program(entries)
    write_image(args.master, master)
    write_image(args.slave, slave)


if __name__ == "__main__":
    main()
