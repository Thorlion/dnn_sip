#!/usr/bin/env python3
"""Prepare signed Q8.8 image words for the DSIP CONV1 workload.

    python input_preprocess.py --input photo.jpg --output input.mem

Resize the shorter edge to 256 and take an unpadded 224x224 center crop.
Subtract Caffe's ImageNet channel means and write BGR planes.
Pillow is the only external dependency.
Output contains one 16-bit two's-complement hexadecimal word per line.
"""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import sys
import tempfile
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from PIL import Image


SCRIPT_DIR = Path(__file__).resolve().parent
RESIZE_SHORT_EDGE = 256
CROP_SIZE = 224
# Spatially averaged ImageNet BGR means used in Caffe's classification example.
CAFFE_MEAN_BGR = (104.0069879317889, 116.66876761696767, 122.6789143406786)
FRACTIONAL_BITS = 8
SCALE = 1 << FRACTIONAL_BITS
Q_MIN = -(1 << 15)
Q_MAX = (1 << 15) - 1


def q8_8(value: float) -> int:
    """Round to nearest (ties to even) and saturate to a signed 16-bit value."""
    if not math.isfinite(value):
        raise ValueError("Q8.8 conversion requires a finite value.")
    # Check the real limits first so even a huge finite input cannot overflow
    # during multiplication. The returned integer is signed, not hex-encoded.
    if value <= Q_MIN / SCALE:
        return Q_MIN
    if value >= Q_MAX / SCALE:
        return Q_MAX
    return max(Q_MIN, min(Q_MAX, round(value * SCALE)))


def resized_dimensions(width: int, height: int) -> tuple[int, int]:
    """Return (width, height), preserving aspect ratio with the short edge 256."""
    if width <= 0 or height <= 0:
        raise ValueError("Image dimensions must be positive.")
    if width <= height:
        return RESIZE_SHORT_EDGE, int(RESIZE_SHORT_EDGE * height / width)
    return int(RESIZE_SHORT_EDGE * width / height), RESIZE_SHORT_EDGE


def alexnet_preprocess(image: Image.Image) -> Image.Image:
    from PIL import Image

    image = image.convert("RGB")
    size = resized_dimensions(*image.size)
    if image.size != size:
        image = image.resize(size, resample=Image.Resampling.BILINEAR)
    # Round half-integer crop offsets to the nearest even integer.
    left = round((image.width - CROP_SIZE) / 2.0)
    top = round((image.height - CROP_SIZE) / 2.0)
    return image.crop((left, top, left + CROP_SIZE, top + CROP_SIZE))


def quantize_caffe_bgr_chw(image: Image.Image) -> list[int]:
    """Subtract Caffe's BGR means from 0–255 pixels and emit B, G, then R planes."""
    if image.mode != "RGB":
        raise ValueError("Quantization expects a PIL RGB image.")
    lookup = [[q8_8(pixel - mean) for pixel in range(256)] for mean in CAFFE_MEAN_BGR]
    pixels = image.tobytes()  # PIL bytes are RGB-interleaved, row by row.
    return [table[pixel] for table, channel in zip(lookup, (2, 1, 0))
            for pixel in pixels[channel::3]]


def write_mem(output_path: Path, words: list[int]) -> None:
    """Write dense, ascending 16-bit word addresses, starting from address 0."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="ascii", newline="\n",
                                         dir=output_path.parent, prefix=".input_quantizer_",
                                         suffix=".tmp", delete=False) as temporary:
            temporary_path = Path(temporary.name)
            for word in words:
                temporary.write(f"{word & 0xFFFF:04X}\n")
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-i", "--input", type=Path, required=True, help="Input image (JPEG, PNG, etc.)")
    parser.add_argument("-o", "--output", type=Path, default=SCRIPT_DIR / "input.mem",
                        help="Output .mem file (default: input.mem beside this script)")
    parser.add_argument("--model", choices=("caffe",), default="caffe",
                        help="Input convention (default: caffe)")
    args = parser.parse_args(argv)
    try:
        input_path = args.input.expanduser().resolve()
        output_path = args.output.expanduser().resolve()
        if input_path == output_path or (output_path.exists() and input_path.samefile(output_path)):
            raise ValueError("Input and output must be different files.")
        try:
            from PIL import Image
        except ImportError as error:
            raise RuntimeError("Pillow is required. Install it with: python -m pip install Pillow") from error
        with Image.open(input_path) as source:
            original_size = source.size
            prepared = alexnet_preprocess(source)
        words = quantize_caffe_bgr_chw(prepared)
        write_mem(output_path, words)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    print(f"Input: {input_path} ({original_size[0]}x{original_size[1]})")
    print(f"{args.model} BGR CHW: 3x{CROP_SIZE}x{CROP_SIZE}; {len(words)} signed Q8.8 words")
    print(f"Quantized real range: {min(words) / SCALE:.6f}..{max(words) / SCALE:.6f}")
    print(f"Output: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
