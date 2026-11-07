This folder includes all of AlexNet quantized parameters in Q8.8.

The single-system OM preload treats the supplied `.bin` files as little-endian
16-bit words. `bin_to_mem.py` writes one four-digit hexadecimal word per line,
preserving both the stored bits and the original flat parameter order.
It does not perform another quantization or change the weight layout.

From `source`, regenerate the CONV1 preload files with:

```powershell
python new_sw/parameter/bin_to_mem.py --input new_sw/parameter/Conv1/features_0_weight.bin --output new_hw/tb/single_system/om_mem/Conv1/conv1_weight.mem
python new_sw/parameter/bin_to_mem.py --input new_sw/parameter/Conv1/features_0_bias.bin --output new_hw/tb/single_system/om_mem/Conv1/conv1_bias.mem
```

CONV1 contains 23,232 weight words (`64 * 3 * 11 * 11`) and 64 bias words.
Their OM ranges and input layout are documented in
[`single_system/README.md`](../../new_hw/tb/single_system/README.md).

