This folder includes all of AlexNet quantized parameters in Q8.8.

The single-system OM preload treats the supplied `.bin` files as little-endian
16-bit words. `bin_to_mem.py` writes one four-digit hexadecimal word per line,
preserving both the stored bits and the original flat parameter order.
It does not perform another quantization or change the weight layout.

Run this command from `source` to regenerate the Caffe CONV1 weight preload.

```powershell
python new_sw/model/script/bin_to_mem.py --input new_sw/model/alexnet_q88/conv1_weight.bin --output new_hw/tb/single_system/om_mem/Conv1/conv1_weight.mem
```

CONV1 contains 34,848 weight words (`96 * 3 * 11 * 11`) in BGR filter-plane
order and 96 bias words. The `conv1_full` workload loads zero into BSP for
raw dot products. Its OM ranges and input layout are documented in
[`single_system/README.md`](../../new_hw/tb/single_system/README.md).

