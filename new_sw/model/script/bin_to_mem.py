#!/usr/bin/env python3
"""Convert little-endian 16-bit parameter words to a $readmemh .mem file.

The input is already quantized Q8.8. Conversion preserves every 16-bit word
and its order; it does not normalize, requantize, or transpose parameters.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
import tempfile


def convert(input_path: Path, output_path: Path) -> int:
    input_path = input_path.expanduser().resolve()
    output_path = output_path.expanduser().resolve()
    if input_path == output_path or (output_path.exists() and input_path.samefile(output_path)):
        raise ValueError("Input and output must be different files.")
    data = input_path.read_bytes()
    if not data or len(data) % 2:
        raise ValueError("Input must contain a nonzero, even number of bytes (16-bit words).")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="ascii", newline="\n",
                                         dir=output_path.parent, prefix=".bin_to_mem_",
                                         suffix=".tmp", delete=False) as temporary:
            temporary_path = Path(temporary.name)
            for offset in range(0, len(data), 2):
                word = int.from_bytes(data[offset:offset + 2], byteorder="little")
                temporary.write(f"{word:04X}\n")
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    return len(data) // 2


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--input", type=Path, required=True, help="Little-endian int16 .bin file")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .mem file")
    args = parser.parse_args(argv)
    try:
        words = convert(args.input, args.output)
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    print(f"Wrote {words} Q8.8 words to {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
