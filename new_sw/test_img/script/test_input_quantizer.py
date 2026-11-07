"""Run with: python -m unittest discover -s new_sw/test_img -v"""

from contextlib import redirect_stderr, redirect_stdout
import io
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

import input_quantizer as quantizer


class InputQuantizerTests(unittest.TestCase):
    def test_signed_encoding_and_saturation(self):
        cases = [(0.0, 0), (0.5, 128), (1.0, 256), (-1.0, -256),
                 (-128.0, -32768), (127.99609375, 32767),
                 (-1e300, -32768), (1e300, 32767)]
        for value, expected in cases:
            with self.subTest(value=value):
                self.assertEqual(quantizer.q8_8(value), expected)
        for value in [float("nan"), float("inf"), -float("inf")]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                quantizer.q8_8(value)

    def test_rounding_ties_to_even(self):
        for value, expected in [(0.5, 0), (1.5, 2), (2.5, 2),
                                (-0.5, 0), (-1.5, -2), (-2.5, -2)]:
            with self.subTest(value=value):
                self.assertEqual(quantizer.q8_8(value / 256), expected)

    def test_aspect_ratio_resize(self):
        for size, expected in [((300, 200), (384, 256)),
                               ((200, 300), (256, 384)),
                               ((256, 259), (256, 259)),
                               ((301, 200), (385, 256))]:
            with self.subTest(size=size):
                self.assertEqual(quantizer.resized_dimensions(*size), expected)
        with self.assertRaises(ValueError):
            quantizer.resized_dimensions(0, 10)

    def test_center_crop_rounding_and_row_order(self):
        for height, expected_top in [(259, 18), (257, 16)]:
            with self.subTest(height=height):
                image = Image.new("RGB", (256, height))
                image.putdata([(x, y % 256, 0) for y in range(height) for x in range(256)])
                cropped = quantizer.alexnet_preprocess(image)
                self.assertEqual(cropped.size, (224, 224))
                self.assertEqual(cropped.getpixel((0, 0)), (16, expected_top, 0))
                self.assertEqual(cropped.getpixel((223, 223)), (239, expected_top + 223, 0))

    def test_grayscale_and_rgba_are_converted_to_rgb(self):
        for mode, color, expected in [("L", 128, (128, 128, 128)),
                                       ("RGBA", (5, 10, 20, 0), (5, 10, 20))]:
            with self.subTest(mode=mode):
                image = quantizer.alexnet_preprocess(Image.new(mode, (10, 7), color))
                self.assertEqual(image.mode, "RGB")
                self.assertEqual(image.size, (224, 224))
                self.assertEqual(image.getpixel((0, 0)), expected)

    def test_known_normalized_values_and_chw_order(self):
        image = Image.new("RGB", (2, 1))
        image.putdata([(0, 128, 255), (255, 0, 128)])
        words = quantizer.quantize_rgb_chw(image)
        self.assertEqual(words, [-542, 576, 53, -521, 676, 109])
        self.assertEqual([f"{word & 0xFFFF:04X}" for word in words],
                         ["FDE2", "0240", "0035", "FDF7", "02A4", "006D"])

    def test_all_pixel_values_match_float32_normalization(self):
        # Emulate tensor float32 operations without depending on PyTorch.
        def f32(value):
            return struct.unpack("f", struct.pack("f", value))[0]

        image = Image.new("RGB", (256, 1))
        image.putdata([(pixel, pixel, pixel) for pixel in range(256)])
        reference = []
        for mean, std in zip(quantizer.MEAN, quantizer.STD):
            for pixel in range(256):
                normalized = f32(f32(f32(pixel / 255.0) - f32(mean)) / f32(std))
                reference.append(round(normalized * 256))
        self.assertEqual(quantizer.quantize_rgb_chw(image), reference)

    def test_cli_full_mem_image(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "red image.png"
            output = root / "nested output" / "custom.mem"
            Image.new("RGB", (10, 7), (255, 0, 0)).save(source)
            result = subprocess.run([sys.executable, str(Path(quantizer.__file__).resolve()),
                                     "--input", str(source), "--output", str(output)],
                                    capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = output.read_bytes()
            plane = 224 * 224
            self.assertEqual(data, b"0240\n" * plane + b"FDF7\n" * plane + b"FE32\n" * plane)
            self.assertIn("150528 signed Q8.8 words", result.stdout)

    def test_invalid_input_preserves_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "invalid.png"
            source.write_bytes(b"not an image")
            output = root / "existing.mem"
            output.write_text("keep this output", encoding="ascii")
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(quantizer.main(["-i", str(source), "-o", str(output)]), 2)
                self.assertEqual(quantizer.main(["-i", str(root / "missing.png"),
                                                 "-o", str(output)]), 2)
            self.assertEqual(output.read_text(encoding="ascii"), "keep this output")
            self.assertEqual(list(root.glob(".input_quantizer_*.tmp")), [])

    def test_input_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "image.png"
            Image.new("RGB", (2, 2)).save(source)
            original = source.read_bytes()
            with redirect_stderr(io.StringIO()):
                self.assertEqual(quantizer.main(["-i", str(source), "-o", str(source)]), 2)
            self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
