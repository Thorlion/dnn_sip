#!/usr/bin/env python3
"""Build the DSIP instruction images for grouped AlexNet CONV4."""

from conv2_program import Layer, main

CONV4 = Layer(number=4, size=13, input_channels=384, filters=384, kernel=3,
              groups=2, ksp_channels=24, output_base=0x110000, zero_bias_base=0x10D000)


if __name__ == "__main__":
    main(CONV4)
