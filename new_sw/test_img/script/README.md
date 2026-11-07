# AlexNet image quantizer

`input_quantizer.py` converts one image into signed Q8.8 input words for the
slave datapath. It uses Python 3.10+ and Pillow, with no PyTorch dependency.

From this directory:

```powershell
python3 -m pip install -r requirements.txt
python3 input_quantizer.py --input raw_img/photo.jpg --output input.mem
```

Input and output filenames can be changed with `-i` / `--input` and
`-o` / `--output`. The input is required. The default output is `input.mem`
beside the script; explicit relative paths are resolved from the working
directory. Existing output files are replaced atomically after successful
conversion. The input image cannot also be the output file.

## Preprocessing

The script uses the standard TorchVision AlexNet ImageNet preprocessing:

1. Convert to RGB.
2. Resize the shorter edge to 256 using bilinear interpolation, preserving
   aspect ratio.
3. Center-crop to 224 by 224.
4. Scale each channel's pixel values by `1/255`.
5. Normalize RGB using mean `(0.485, 0.456, 0.406)` and standard deviation
   `(0.229, 0.224, 0.225)`.

Source: [TorchVision AlexNet weights and inference transforms](https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.alexnet.html).
The geometry and center-offset rounding follow its
[PIL resize / center crop implementation](https://docs.pytorch.org/vision/stable/_modules/torchvision/transforms/functional.html).
This preprocessing assumes the supplied AlexNet parameters use the standard
ImageNet input convention; custom-trained weights may require their own
preprocessing specification.

## Q8.8 encoding

For a normalized real value `x`, the stored signed integer is:

```text
q = clamp(round(x * 256), -32768, 32767)
```

Rounding is nearest with ties to even. The representable real range is
`-128` through `127.99609375`; non-finite inputs are rejected. Each stored
word is `q & 0xFFFF`, written as four hexadecimal digits on its own line.
Examples before image normalization: `0.0 -> 0000`, `0.5 -> 0080`,
`1.0 -> 0100`, `-1.0 -> FF00`.

## Memory layout

The file contains `3 * 224 * 224 = 150528` words in CHW order. Within each
channel, pixels are row-major, left-to-right then top-to-bottom:

| Channel | Word address range |
| --- | --- |
| R | 0..50175 |
| G | 50176..100351 |
| B | 100352..150527 |

For channel `c`, row `y` and column `x`:

```text
address = c * 224 * 224 + y * 224 + x
```

This is a dense 16-bit `$readmemh` image with no header or address offset.
Its payload occupies 301056 bytes (294 KiB). The single-system testbench now
provides a 512 KiB OM and preloads `om_mem/input_img.mem` at word address
`0x10000`. Set `--output` to that file to replace the preloaded image, then
use DMA to load IB tiles when convolution firmware is available. See the
[OM memory map](../../../new_hw/tb/single_system/README.md).
