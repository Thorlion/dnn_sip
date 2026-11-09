#!/usr/bin/env python3
"""Build the DSIP instruction images for grouped AlexNet CONV2."""

import argparse
from dataclasses import dataclass
from math import gcd
from pathlib import Path

from conv1_full_program import MasterProgram, OB_BASE, SCR_X24, SYSTEM, WAIT_DONE, WAIT_ROW
from core_compiler import FIELDS, IMEM_DEPTH, encode_instruction, memory_image, write_image

LANES = 64
OB_WORDS = 1024
INPUT_BASE = 0x10000
WEIGHT_BASE = 0x35000


@dataclass(frozen=True)
class Layer:
    number: int
    size: int
    input_channels: int
    filters: int
    kernel: int
    groups: int
    ksp_channels: int
    output_base: int
    zero_bias_base: int | None = None

    @property
    def batches(self):
        return self.filters // LANES

    @property
    def osp_batch_words(self):
        return 512 // self.batches

    @property
    def tile_rows(self):
        rows = self.osp_batch_words // self.size
        if self.whole_pixel_blocks:
            # Whole-pixel packers drain only complete OB blocks between tiles.
            rows_per_block = OB_WORDS // gcd(OB_WORDS, self.size*self.filters)
            rows -= rows % rows_per_block
        return rows

    @property
    def ksp_load_words(self):
        return self.ksp_channels*self.kernel**2

    @property
    def whole_pixel_blocks(self):
        return OB_WORDS % self.filters == 0


CONV2 = Layer(number=2, size=27, input_channels=96, filters=256, kernel=5,
              groups=2, ksp_channels=8, output_base=0x90000)
INPUT_CHANNELS = CONV2.input_channels
SIZE = CONV2.size


def tile_shape(layer, oy, tile_rows):
    padding = layer.kernel // 2
    end_oy = min(oy + tile_rows, layer.size)
    first_y = max(0, oy - padding)
    end_y = min(layer.size, end_oy + padding)
    return (end_oy - oy, first_y - (oy - padding), end_y - first_y), first_y


def input_rows(shape, kernel):
    """Yield the first kernel row, OSP row step, and pass count per IB row."""
    rows, first_y, count = shape
    previous_oy = 0
    for y in range(first_y, first_y + count):
        first_oy = max(0, y - kernel + 1)
        end_oy = min(rows, y + 1)
        yield y - first_oy, first_oy - previous_oy, end_oy - first_oy
        previous_oy = end_oy - 1


def weight_prefetch_plan(row_setups, layer, ib_wait_iterations):
    """Place sequential KSP slices in the DMA0 time available during each IB row."""
    padding = layer.kernel // 2
    pass_cycles = layer.size*layer.kernel - padding*(padding + 1) + 1
    lane_words = layer.ksp_load_words
    filter_words = layer.input_channels // layer.groups * layer.kernel**2
    lane_step_cycles = 4 if filter_words > 2047 else 3
    lane = offset = 0
    channels = []
    for _ in range(layer.ksp_channels):
        rows = []
        for index, (_, _, passes) in enumerate(row_setups):
            # Leave time for staging the next SCR and entering WAIT_ROW.
            # An IB refill also takes a call, CSR writes, and a DMA drain wait.
            cycles = passes*pass_cycles - 4
            if index + 1 < len(row_setups):
                cycles -= 14 + 6*ib_wait_iterations
            jobs = []
            while lane < LANES:
                left = lane_words - offset
                # The transfer helper costs at most 13 cycles in addition to
                # its six-cycle delay loop, plus the lane step if it finishes.
                full_cost = 6*((left + 5)//6) + 13 + lane_step_cycles
                if full_cost <= cycles:
                    jobs.append((left, True))
                    lane += 1
                    offset = 0
                    cycles -= full_cost
                else:
                    words = min(left - 1, 6*((cycles - 13)//6))
                    if words > 0:
                        jobs.append((words, False))
                        offset += words
                    break
            rows.append(jobs)
        channels.append(rows)
    return channels, lane_words - offset if offset else 0


def slave_program(width, tile_rows, layer=CONV2):
    """Emit one slave run per IB row and a shared output packer."""
    entries = {}
    instructions = []
    kernel = layer.kernel
    padding = kernel // 2

    def emit(**controls):
        values = {field.name: 0 for field in FIELDS}
        if unknown := controls.keys() - values.keys():
            raise ValueError(f"Unknown fields: {unknown}")
        values.update(controls)
        for field in FIELDS:
            if not field.minimum <= values[field.name] <= field.maximum:
                raise ValueError(f"PC {len(instructions)}: {field.name} out of range")
        instructions.append(encode_instruction(values))

    def entry(name):
        entries[name] = len(instructions)

    def finish(*, row_done=False, **controls):
        emit(**controls, **{"Done": 1, "Row done": int(row_done)})

    def emit_input_row(first_ky, osp_step, pass_count):
        # Each pass uses the same IB row and a different kernel and OSP row.
        emit(**{"IB switch": 1, "KSP delta": first_ky*kernel + padding,
                "OSP delta": osp_step*width, "Set breakpoint": 5, "Set iteration": pass_count - 1})
        first_tap = {"Load OSP": 1, "ACC": 1}
        tap = {"IB delta": 1, "KSP delta": 1, "ACC": 2}

        def mac(**controls):
            emit(**controls, **{"Load IB": 1, "Load KSP": 1, "MULT1": 1, "MULT2": 1})

        # Left windows all start at input column zero, skipping padded taps.
        for ox in range(padding):
            taps = kernel - padding + ox
            if ox == 0:
                mac(**first_tap, **{"IB clear": 1})
            else:
                mac(**first_tap, **{"IB delta": 2 - taps, "KSP delta": 1 - taps, "OSP delta": 1})
            for _ in range(taps - 2):
                mac(**tap)
            if ox == padding - 1:
                mac(**tap, **{"Store OSP": 1, "Set breakpoint": 2,
                               "Set iteration": width - 2*padding - 1})
            else:
                mac(**tap, **{"Store OSP": 1})

        # Interior windows advance one pixel and use every tap.
        mac(**first_tap, **{"IB delta": 2 - kernel, "KSP delta": 1 - kernel, "OSP delta": 1,
                            "Set breakpoint": 1, "Set iteration": kernel - 3})
        mac(**tap, **{"Conditional loop": 1})
        mac(**tap, **{"Store OSP": 1, "Conditional loop": 2})

        # Right windows drop one trailing tap per pixel.
        for taps in range(kernel - 1, kernel - padding - 1, -1):
            mac(**first_tap, **{"IB delta": 1 - taps, "KSP delta": -taps, "OSP delta": 1})
            for _ in range(taps - 2):
                mac(**tap)
            mac(**tap, **{"Store OSP": 1})
        # Continue at the preceding kernel row and the next OSP row.
        last_tap = kernel - padding - 1
        emit(**{"KSP delta": padding - kernel - last_tap, "OSP delta": 1, "Conditional loop": 5})
        finish(row_done=True, **{"KSP delta": (pass_count - first_ky)*kernel - padding, "OSP delta": -width})

    row_setups = set()
    for oy in range(0, layer.size, tile_rows):
        shape, _ = tile_shape(layer, oy, tile_rows)
        row_setups.update(input_rows(shape, kernel))
    for setup in sorted(row_setups):
        entry(setup)
        emit_input_row(*setup)

    # Initialize all batch regions once per tile so every pass can accumulate.
    entry("clear_tile_osp")
    emit(**{"OSP clear": 1, "OSP delta": 511, "Set breakpoint": 5, "Set iteration": 7})
    emit(**{"Set breakpoint": 6, "Set iteration": 63})
    emit(**{"OSP delta": 1, "Store OSP": 1, "Conditional loop": 6})
    emit(**{"Conditional loop": 5})
    finish()

    for batch in range(layer.batches):
        entry(f"begin_channel_{batch}")
        finish(**{"OSP clear": 1, "OSP delta": batch*layer.osp_batch_words})
    for batch in range(layer.batches):
        entry(f"begin_weight_chunk_{batch}")
        finish(**{"KSP switch": 1, "OSP clear": 1, "OSP delta": batch*layer.osp_batch_words})
    entry("advance_channel")
    finish(**{"KSP delta": kernel**2})
    entry("rewind_ksp")
    finish(**{"KSP delta": 256 - layer.ksp_load_words})

    last_batch_offset = (layer.batches - 1)*layer.osp_batch_words
    entry("prepare_output")
    finish(**{"OSP clear": 1, "OSP delta": last_batch_offset - 1, "Load BSP": 1})
    entry("switch_ob")
    finish(**{"OB switch": 1})
    if layer.whole_pixel_blocks:
        entry("pack_block")
        emit(**{"Set breakpoint": 3, "Set iteration": OB_WORDS // layer.filters - 1})
        entry("pack_pixel")
        # The batch bases partition OSP evenly, so one lane sequence can
        # walk every batch and wrap back to batch zero for the next pixel.
        emit(**{"OSP delta": 1, "Set breakpoint": 4, "Set iteration": layer.batches - 1})
        for lane in range(LANES):
            emit(**{"OSP mux": lane, "Store OB": 1, "Load OSP": int(lane == 0),
                    "OSP delta": layer.osp_batch_words if lane == 0 else 0,
                    "Conditional loop": 4 if lane == LANES - 1 else 0})
        emit(**{"Conditional loop": 3})
        finish()
    else:
        for batch in range(layer.batches):
            entry(f"pack_group_{batch}")
            delta = layer.osp_batch_words if batch else 1 - last_batch_offset
            for lane in range(LANES):
                emit(**{"OSP mux": lane, "Store OB": 1, "Load OSP": int(lane == 0),
                        "OSP delta": delta if lane == 0 else 0})
            finish()

    if len(instructions) > IMEM_DEPTH:
        raise ValueError("Slave program exceeds IMEM depth")
    return entries, memory_image(dict(enumerate(instructions)))


def master_program(entries, layer=CONV2):
    p = MasterProgram()
    size = layer.size
    channels_per_group = layer.input_channels // layer.groups
    weight_chunks = channels_per_group // layer.ksp_channels
    overlap_weights = weight_chunks > 1 or layer.batches > 1 or layer.tile_rows < size
    ib_wait_iterations = max(1, (size + 2)//6)
    filters_per_group = layer.filters // layer.groups
    filter_words = channels_per_group*layer.kernel**2
    zero_bias_base = layer.zero_bias_base
    if zero_bias_base is None:
        zero_bias_base = WEIGHT_BASE + layer.filters*filter_words

    def run_slave(name, entry_offset_reg=0):
        p.load(24, entries[name])
        if entry_offset_reg:
            p.add(24, 24, entry_offset_reg)
        p.jump(3, "run_slave")

    def prefetch_weight(words, end_of_lane):
        p.load(9, words)
        p.load(10, (words + 5)//6)
        p.jump(1, "prefetch_weight_slice")
        if end_of_lane:
            if filter_words > 2047:
                p.add(12, 12, 25)
                p.immediate(12, 12, -layer.ksp_load_words)
            else:
                p.immediate(12, 12, filter_words - layer.ksp_load_words)
            p.immediate(13, 13, 256 - layer.ksp_load_words)
            p.immediate(14, 14, -1)

    def run_input_rows(row_setups, name, weight_jobs=()):
        p.jump(1, "load_input")
        p.delay((size + 9)//6, f"{name}_first_dma_wait")
        p.load(24, entries[row_setups[0]])
        for row in range(len(row_setups)):
            p.emit(SCR_X24, "SCR x24")
            refill_ib = row + 1 < len(row_setups)
            jobs = weight_jobs[row] if weight_jobs else ()
            if refill_ib:
                p.jump(1, "load_input")
                if jobs:
                    p.delay(ib_wait_iterations, f"{name}_ib_wait_{row}")
            for words, end_of_lane in jobs:
                prefetch_weight(words, end_of_lane)
            if refill_ib:
                # Stage the next PC so its SCR immediately follows WAIT_ROW.
                p.load(24, entries[row_setups[row + 1]])
            p.emit(WAIT_ROW, "WAIT_ROW")

    # x5/x6 track the next IB source and bank. x16..x18 hold DMA1 CSRs.
    # x19/x21 select the current input plane and row schedule. x22 holds the
    # next batch's weight base. x23/x26 select the KSP bank and current chunk.
    # x31 selects the OSP region for the batch.
    p.load(6, 1024)
    p.load(7, size)
    p.load(8, 1)
    p.load(11, layer.ksp_load_words)
    p.load(15, 0x4000)
    p.load(16, OB_BASE)
    p.load(17, layer.output_base)
    p.load(18, OB_WORDS)
    p.load(23, 0x14000)
    if filter_words > 2047:
        p.load(25, filter_words)
    p.load(12, zero_bias_base)
    p.load(13, 0x20000)
    p.dma(0, 12, 13, 8)

    shapes = {}
    tail_words = 0
    for oy in range(0, size, layer.tile_rows):
        shape, first_y = tile_shape(layer, oy, layer.tile_rows)
        rows = shape[0]
        name = shapes.setdefault(shape, f"shape_{len(shapes)}")
        p.label(f"tile_{oy}")
        run_slave("clear_tile_osp")
        p.load_label(21, name)
        if overlap_weights:
            p.load_label(20, f"{name}_prefetch")
        for batch in range(layer.batches):
            first_filter = batch*LANES
            group = first_filter // filters_per_group
            first_channel = group*channels_per_group
            p.load(19, INPUT_BASE + (first_channel*size + first_y)*size)
            p.load(26, WEIGHT_BASE + first_filter*filter_words)
            p.load(31, batch)
            if overlap_weights:
                has_next_batch = batch + 1 < layer.batches or oy + rows < size
                next_batch = (batch + 1) % layer.batches
                p.load(22, WEIGHT_BASE + next_batch*LANES*filter_words if has_next_batch else 0)
            batch_entry = "compute_batch"
            if overlap_weights and (oy > 0 or batch > 0):
                batch_entry = "compute_prefetched_batch"
            p.jump(2, batch_entry)
        run_slave("prepare_output")
        pixels = rows*size
        if layer.whole_pixel_blocks:
            blocks, tail_words = divmod(pixels*layer.filters, OB_WORDS)
            if tail_words and oy + rows != size:
                raise ValueError("Only the final tile may end in a partial OB block")
            p.load(22, blocks)
            p.jump(29, "pack_tile")
        else:
            # Carry a partially filled OB across tile boundaries. Each group
            # is 64 contiguous words, so every DMA starts on a bank boundary.
            for _ in range(pixels):
                for batch in range(layer.batches):
                    run_slave(f"pack_group_{batch}")
                    tail_words += LANES
                    if tail_words == OB_WORDS:
                        p.jump(28, "drain_ob")
                        run_slave("switch_ob")
                        tail_words = 0

    if layer.whole_pixel_blocks:
        if tail_words != layer.filters:
            raise ValueError(f"Unsupported final OB tail of {tail_words} words")
        run_slave("pack_pixel")  # The previous full block exhausted loop context 3.
    p.delay(172, "wait_before_tail")
    p.load(18, tail_words)
    p.jump(28, "drain_ob")
    p.label("park")
    p.jump(0, "park")
    p.emit(0x13, "nop")
    p.emit(0x13, "nop")

    p.label("compute_batch")
    p.load(27, weight_chunks)
    p.label("weight_chunk")
    p.immediate(12, 26, 0)
    p.immediate(13, 23, 0)
    p.load(14, LANES)
    p.jump(1, "load_weights")
    if overlap_weights:
        p.jump(0, "weight_chunk_ready")
        p.label("compute_prefetched_batch")
        p.load(27, weight_chunks)
        p.label("weight_chunk_ready")
    # Set up the first channel while switching to the newly loaded KSP bank.
    run_slave("begin_weight_chunk_0", 31)
    p.emit((15 << 20) | (23 << 15) | (4 << 12) | (23 << 7) | 0x33, "xor x23, x23, x15")
    if overlap_weights:
        p.immediate(27, 27, -1)
        p.branch_nonzero(27, "compute_with_weight_prefetch")
        p.branch_nonzero(22, "compute_with_batch_prefetch")
    p.load(30, layer.ksp_channels)
    p.jump(0, "compute_channel")
    p.label("input_channel")
    run_slave("begin_channel_0", 31)
    p.label("compute_channel")
    p.immediate(5, 19, 0)
    p.jump_register(4, 21)
    run_slave("advance_channel")
    p.immediate(19, 19, size**2)
    p.immediate(30, 30, -1)
    p.branch_nonzero(30, "input_channel")
    run_slave("rewind_ksp")
    if not overlap_weights:
        p.immediate(26, 26, layer.ksp_load_words)
        p.immediate(27, 27, -1)
        p.branch_nonzero(27, "weight_chunk")
    p.jump_register(0, 2)

    if overlap_weights:
        p.label("compute_with_weight_prefetch")
        # The next chunk's DMA cursor walks the inactive bank across channels.
        p.immediate(12, 26, layer.ksp_load_words)
        p.jump(0, "prefetch_inactive_ksp")
        p.label("compute_with_batch_prefetch")
        p.immediate(12, 22, 0)
        p.label("prefetch_inactive_ksp")
        p.immediate(13, 23, 0)
        p.load(14, LANES)
        p.jump_register(4, 20)
        p.branch_nonzero(14, "load_remaining_weights")
        p.jump(0, "weight_prefetch_done")
        p.label("load_remaining_weights")
        p.jump(1, "load_weights")
        p.label("weight_prefetch_done")
        p.branch_nonzero(27, "advance_weight_chunk")
        p.jump_register(0, 2)
        p.label("advance_weight_chunk")
        p.immediate(26, 26, layer.ksp_load_words)
        p.jump(0, "weight_chunk_ready")

    for shape, name in shapes.items():
        p.label(name)
        row_setups = list(input_rows(shape, layer.kernel))
        run_input_rows(row_setups, name)
        p.jump_register(0, 4)
        if overlap_weights:
            p.label(f"{name}_prefetch")
            channels, unfinished = weight_prefetch_plan(row_setups, layer, ib_wait_iterations)
            channels = [tuple(tuple(row) for row in jobs) for jobs in channels]
            shared = {}
            if layer.number != CONV2.number:
                for jobs in dict.fromkeys(channels):
                    if channels.count(jobs) > 1:
                        shared[jobs] = f"{name}_prefetch_rows_{len(shared)}"
            for channel, jobs in enumerate(channels):
                if channel:
                    run_slave("begin_channel_0", 31)
                p.immediate(5, 19, 0)
                if jobs in shared:
                    p.jump(30, shared[jobs])
                else:
                    run_input_rows(row_setups, f"{name}_prefetch_{channel}", jobs)
                run_slave("advance_channel")
                p.immediate(19, 19, size**2)
            run_slave("rewind_ksp")
            if unfinished:
                prefetch_weight(unfinished, True)
            p.jump_register(0, 4)
            for jobs, label in shared.items():
                p.label(label)
                run_input_rows(row_setups, label, jobs)
                p.jump_register(0, 30)

    p.label("run_slave")
    p.emit(SCR_X24, "SCR x24")
    p.emit(WAIT_DONE, "WAIT_DONE")
    p.jump_register(0, 3)

    p.label("load_input")
    p.dma(0, 5, 6, 7)
    p.immediate(5, 5, size)
    p.immediate(6, 6, 1024, funct3=4)
    p.jump_register(0, 1)

    p.label("load_weights")
    p.dma(0, 12, 13, 11)
    p.delay((layer.ksp_load_words + 9)//6, "weight_dma_wait")
    if filter_words > 2047:
        p.add(12, 12, 25)
    else:
        p.immediate(12, 12, filter_words)
    p.immediate(13, 13, 256)
    p.immediate(14, 14, -1)
    p.branch_nonzero(14, "load_weights")
    p.jump_register(0, 1)

    if overlap_weights:
        p.label("prefetch_weight_slice")
        p.dma(0, 12, 13, 9)
        p.label("prefetch_weight_wait")
        p.emit(0x13, "nop")
        p.immediate(10, 10, -1)
        p.branch_nonzero(10, "prefetch_weight_wait")
        p.add(12, 12, 9)
        p.add(13, 13, 9)
        p.jump_register(0, 1)

    if layer.whole_pixel_blocks:
        p.label("pack_tile")
        run_slave("pack_block")
        p.jump(28, "drain_ob")
        run_slave("switch_ob")
        p.immediate(22, 22, -1)
        p.branch_nonzero(22, "pack_tile")
        p.jump_register(0, 29)

    p.label("drain_ob")
    p.dma(1, 16, 17, 18)
    p.add(17, 17, 18)
    p.immediate(16, 16, OB_WORDS, funct3=4)
    p.jump_register(0, 28)
    return p.image(f"{layer.filters}-filter CONV{layer.number}. Generated by conv{layer.number}_program.py.")


def main(layer=CONV2):
    parser = argparse.ArgumentParser(description=f"Build the DSIP instruction images for AlexNet CONV{layer.number}.")
    stem = f"conv{layer.number}"
    parser.add_argument("--master", type=Path, default=SYSTEM / f"master_mem/{stem}_master_imem.mem")
    parser.add_argument("--slave", type=Path, default=SYSTEM / f"slave_mem/{stem}_slave_imem.mem")
    args = parser.parse_args()
    entries, slave = slave_program(layer.size, layer.tile_rows, layer)
    write_image(args.master, master_program(entries, layer))
    write_image(args.slave, slave)


if __name__ == "__main__":
    main()
