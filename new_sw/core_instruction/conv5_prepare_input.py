#!/usr/bin/env python3
"""Prepare CONV5 input by applying CONV4 bias and ReLU to the raw dump."""

from conv2_prepare_input import main
from conv4_prepare_input import prepare_relu
from conv4_program import CONV4


if __name__ == "__main__":
    main(previous_layer=CONV4.number, input_size=CONV4.size, channels=CONV4.filters,
         transform=prepare_relu)
