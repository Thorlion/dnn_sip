#!/usr/bin/env python3
"""Generate lane-major Q8.8 reference words for the first 9 CONV1 rows.

Uses the existing 224x224 CHW image and 64x3x11x11 OIHW weights. Only input
channel 0 contributes. Products truncate by arithmetic shift, and sums wrap
to 16 bits, matching the current DALU. No bias or activation is included.
"""
import argparse
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2]
SYSTEM = SOURCE / "new_hw/tb/single_system"


def read_words(path, count):
    words = [int(line.split("//", 1)[0].strip(), 16)
             for line in path.read_text(encoding="utf-8-sig").splitlines()
             if line.split("//", 1)[0].strip()]
    if len(words) != count or any(not 0 <= word <= 0xFFFF for word in words):
        raise ValueError(f"Expected {count} 16-bit words in {path}")
    return [word - 0x10000 if word & 0x8000 else word for word in words]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, default=SYSTEM / "om_mem/input_img.mem")
    parser.add_argument("--weights", type=Path, default=SYSTEM / "om_mem/Conv1/conv1_weight.mem")
    parser.add_argument("--output", type=Path, default=SYSTEM / "reference/conv1_channel0_osp.mem")
    args = parser.parse_args()
    image = read_words(args.image, 3*224*224)
    weights = read_words(args.weights, 64*3*11*11)
    result = []
    for lane in range(64):
        for oy in range(9):
            for ox in range(55):
                total = 0
                for ky in range(11):
                    y = oy*4 - 2 + ky
                    if not 0 <= y < 224:
                        continue
                    for kx in range(11):
                        x = ox*4 - 2 + kx
                        if 0 <= x < 224:
                            product = image[y*224+x] * weights[lane*363+ky*11+kx]
                            total += product >> 8
                result.append(total & 0xFFFF)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(f"{word:04X}\n" for word in result), encoding="ascii")
    print(f"Wrote {len(result)} reference words: 64 lanes x 495 OSP addresses to {args.output}")


if __name__ == "__main__":
    main()
