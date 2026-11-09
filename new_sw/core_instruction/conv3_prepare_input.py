#!/usr/bin/env python3
"""Prepare the 13x13x256 Caffe CONV3 input from the raw DSIP CONV2 dump."""

from conv2_prepare_input import main
from conv2_program import CONV2


if __name__ == "__main__":
    main(previous_layer=CONV2.number, input_size=CONV2.size, channels=CONV2.filters)
