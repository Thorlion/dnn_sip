import caffe_pb2
import numpy as np
from pathlib import Path

MODEL_PATH = "bvlc_alexnet.caffemodel"
OUTPUT_DIR = Path("alexnet_q88")
OUTPUT_DIR.mkdir(exist_ok=True)

# Load Caffe model using Protobuf
net = caffe_pb2.NetParameter()

with open(MODEL_PATH, "rb") as f:
    net.ParseFromString(f.read())

# Support newer and older Caffe model formats
layers = net.layer if len(net.layer) else net.layers

def get_blob_data(blob):
    # Newer Caffe format
    if len(blob.shape.dim):
        shape = tuple(blob.shape.dim)
    else:
        # Legacy Caffe format
        shape = tuple(
            d for d in [
                blob.num,
                blob.channels,
                blob.height,
                blob.width
            ] if d > 0
        )

    if len(blob.double_data):
        data = np.asarray(blob.double_data, dtype=np.float64)
    else:
        data = np.asarray(blob.data, dtype=np.float32)

    return data.reshape(shape) if shape else data

# Convert FP32 to Q8.8
def to_q88(x):
    q = np.round(x.astype(np.float64) * 256.0)
    q = np.clip(q, -32768, 32767)
    return q.astype("<i2")

# Extract and export all parameters
for layer in layers:
    if len(layer.blobs) == 0:
        continue

    print(f"\nLayer: {layer.name}")

    for i, blob in enumerate(layer.blobs):
        param_type = "weight" if i == 0 else "bias"

        param = get_blob_data(blob)
        q = to_q88(param)

        filename = OUTPUT_DIR / f"{layer.name}_{param_type}.bin"
        q.tofile(filename)

        print(
            f"  {param_type}: "
            f"shape={param.shape}, "
            f"FP32=[{param.min():.6f}, {param.max():.6f}], "
            f"Q8.8=[{q.min()}, {q.max()}]"
        )

        print(f"  Saved: {filename}")

print("\nExtraction complete.")