#!/usr/bin/env python3
"""Prepare CONV4 input by applying CONV3 bias and ReLU to the raw dump."""

from conv2_prepare_input import main
from conv3_program import CONV3


def prepare_relu(conv_words, biases, input_size):
    """Apply Q8.8 bias and ReLU while converting pixel-major data to CHW."""
    channels = len(biases)
    return [min(32767, max(0, conv_words[pixel*channels + channel] + bias))
            for channel, bias in enumerate(biases) for pixel in range(input_size**2)]


if __name__ == "__main__":
    main(previous_layer=CONV3.number, input_size=CONV3.size, channels=CONV3.filters,
         transform=prepare_relu)
