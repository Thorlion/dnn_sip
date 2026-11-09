#!/usr/bin/env python3
"""Prepare the 27x27x96 Caffe CONV2 input from the raw DSIP CONV1 dump."""

import argparse
from pathlib import Path
import struct

from conv2_program import INPUT_CHANNELS, SYSTEM
from core_compiler import write_image

SOURCE = Path(__file__).resolve().parents[2]
CONV1_SIZE = 55
SCALE = 256
LRN_RADIUS = 2
LRN_ALPHA_PER_CHANNEL = 0.0001 / 5
LRN_BETA = 0.75
POOL_SIZE = 3
POOL_STRIDE = 2


def read_words(path, count):
    words = [int(line.split("//", 1)[0].strip(), 16)
             for line in path.read_text(encoding="utf-8-sig").splitlines()
             if line.split("//", 1)[0].strip()]
    if len(words) != count or any(not 0 <= word <= 0xFFFF for word in words):
        raise ValueError(f"Expected {count} 16-bit words in {path}")
    return [word - 0x10000 if word & 0x8000 else word for word in words]


def prepare(conv_words, biases, input_size=CONV1_SIZE):
    channels = len(biases)
    output_size = (input_size - POOL_SIZE)//POOL_STRIDE + 1
    # Apply bias and ReLU to each pixel before the across-channel LRN.
    normalized = []
    for first in range(0, len(conv_words), channels):
        pixel = conv_words[first:first + channels]
        positive = [max(0, word + bias) / SCALE for word, bias in zip(pixel, biases)]
        squares = [value*value for value in positive]
        for channel, value in enumerate(positive):
            low = max(0, channel - LRN_RADIUS)
            high = min(channels, channel + LRN_RADIUS + 1)
            normalized.append(value / (1 + LRN_ALPHA_PER_CHANNEL*sum(squares[low:high]))**LRN_BETA)

    # Emit channel planes so DMA0 can fetch contiguous rows into IB.
    words = []
    for channel in range(channels):
        for y in range(0, POOL_STRIDE*output_size, POOL_STRIDE):
            for x in range(0, POOL_STRIDE*output_size, POOL_STRIDE):
                peak = max(normalized[((y + dy)*input_size + x + dx)*channels + channel]
                           for dy in range(POOL_SIZE) for dx in range(POOL_SIZE))
                words.append(min(32767, round(peak*SCALE)))
    return words


def main(previous_layer=1, input_size=CONV1_SIZE, channels=INPUT_CHANNELS, transform=prepare):
    previous = f"conv{previous_layer}"
    layer = previous_layer + 1
    parser = argparse.ArgumentParser(description=f"Prepare CONV{layer} input from the raw CONV{previous_layer} dump.")
    parser.add_argument(f"--{previous}-output", dest="conv_output", type=Path,
                        default=SOURCE.parent / f"tmp/verilator/{previous}_full/{previous}_feature_map.mem")
    parser.add_argument(f"--{previous}-bias", dest="conv_bias", type=Path,
                        default=SOURCE / f"new_sw/model/alexnet_q88/{previous}_bias.bin")
    parser.add_argument("--output", type=Path, default=SYSTEM / f"om_mem/Conv{layer}/conv{layer}_input.mem")
    args = parser.parse_args()
    if args.output.resolve() in (args.conv_output.resolve(), args.conv_bias.resolve()):
        parser.error("Output must be a separate file")
    conv_words = read_words(args.conv_output, input_size**2*channels)
    biases = struct.unpack(f"<{channels}h", args.conv_bias.read_bytes())
    words = transform(conv_words, biases, input_size)
    write_image(args.output, "".join(f"{word:04X}\n" for word in words))
    print(f"Wrote {len(words):,} Q8.8 words in CHW order to {args.output}")


if __name__ == "__main__":
    main()
