#!/usr/bin/env python3
"""Build the DSIP instruction images for AlexNet CONV3."""

from conv2_program import Layer, main

CONV3 = Layer(number=3, size=13, input_channels=256, filters=384, kernel=3,
              groups=1, ksp_channels=16, output_base=0x110000)


if __name__ == "__main__":
    main(CONV3)
