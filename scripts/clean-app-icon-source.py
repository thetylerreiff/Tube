#!/usr/bin/env python3
import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def luminance(pixel):
    r, g, b = pixel[:3]
    return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)


def edge_connected_dark_mask(image, threshold):
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue = deque()

    def enqueue(x, y):
        index = (y * width) + x
        if visited[index]:
            return
        if luminance(pixels[x, y]) > threshold:
            return
        visited[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)

    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x < width - 1:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y < height - 1:
            enqueue(x, y + 1)

    return visited


def clean_icon(input_path, output_path, threshold, feather):
    image = Image.open(input_path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    mask = edge_connected_dark_mask(image, threshold)

    transparent = Image.new("L", image.size, 255)
    alpha = transparent.load()

    for y in range(height):
        for x in range(width):
            if mask[(y * width) + x]:
                alpha[x, y] = 0

    if feather > 0:
        # Soften only the extracted matte; the icon art itself is not blurred.
        from PIL import ImageFilter

        transparent = transparent.filter(ImageFilter.GaussianBlur(feather))

    image.putalpha(transparent)
    image.save(output_path)


def main():
    parser = argparse.ArgumentParser(description="Remove edge-connected dark background from an app icon source.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--threshold", type=float, default=48.0)
    parser.add_argument("--feather", type=float, default=0.7)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    clean_icon(args.input, args.output, args.threshold, args.feather)


if __name__ == "__main__":
    main()
