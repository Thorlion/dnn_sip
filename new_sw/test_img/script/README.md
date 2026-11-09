# AlexNet image quantizer

`input_preprocess.py` converts one image into signed Q8.8 input words for the
slave datapath. It uses Python 3.10+ and Pillow, with no PyTorch dependency.

Run these commands from this directory.

```powershell
python3 -m pip install -r requirements.txt
python3 input_preprocess.py --input photo.jpg --output input.mem
```

Input and output filenames can be changed with `-i` / `--input` and
`-o` / `--output`. The input is required. The default output is `input.mem`
beside the script; explicit relative paths are resolved from the working
directory. Existing output files are replaced atomically after successful
conversion. The input image cannot also be the output file.

## Preprocessing

The script converts the image to RGB for decoding, resizes the shorter edge
to 256 with bilinear interpolation, and takes an unpadded 224 × 224 center
crop. It emits BGR planes after subtracting the Caffe example's averaged
ImageNet means (about 104.007, 116.669, and 122.679 in BGR order) from 0–255
pixel values. [Caffe classification example](https://github.com/BVLC/caffe/blob/master/examples/00-classification.ipynb)

## Q8.8 encoding

The stored signed integer for a preprocessed real value `x` is

```text
q = clamp(round(x * 256), -32768, 32767)
```

Rounding is nearest with ties to even. The representable real range is
`-128` through `127.99609375`; non-finite inputs are rejected. Each stored
word is `q & 0xFFFF`, written as four hexadecimal digits on its own line.
Mean-subtracted values above the Q8.8 limit saturate.
Examples before image normalization: `0.0 -> 0000`, `0.5 -> 0080`,
`1.0 -> 0100`, `-1.0 -> FF00`.

## Memory layout

The file contains `3 * 224 * 224 = 150528` words in CHW order. Within each
channel, pixels are row-major, left-to-right then top-to-bottom.

| Word address range | Channel |
| --- | --- |
| 0..50175 | B |
| 50176..100351 | G |
| 100352..150527 | R |

For stored plane `c`, row `y`, and column `x`, the word address is

```text
address = c * 224 * 224 + y * 224 + x
```

This is a dense 16-bit `$readmemh` image with no header or address offset.
Its payload occupies 301056 bytes (294 KiB). The single-system testbench now
preloads the Caffe image `om_mem/Conv1/input_img.mem` at word address `0x10000`.
See the
[OM memory map](../../../new_hw/tb/single_system/README.md).
