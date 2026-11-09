#!/usr/bin/env python3
"""Build the DSIP instruction images for grouped AlexNet CONV5."""

from conv2_program import Layer, main

CONV5 = Layer(number=5, size=13, input_channels=384, filters=256, kernel=3,
              groups=2, ksp_channels=24, output_base=0x110000, zero_bias_base=0x10D000)


if __name__ == "__main__":
    main(CONV5)
