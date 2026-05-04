#!/usr/bin/env python3
"""Clean generated sprites toward game-ready pixel art."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def alpha_threshold(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 0 if a < threshold else 255)
    return rgba


def pixelate(image: Image.Image, scale: int) -> Image.Image:
    if scale <= 1:
        return image
    small = image.resize(
        (max(1, image.width // scale), max(1, image.height // scale)),
        Image.Resampling.NEAREST,
    )
    return small.resize(image.size, Image.Resampling.NEAREST)


def quantize_keep_alpha(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--cell", type=int, default=64)
    parser.add_argument("--palette", type=int, default=32)
    parser.add_argument("--alpha-threshold", type=int, default=24)
    parser.add_argument("--pixelate-scale", type=int, default=1)
    parser.add_argument("--scale-mode", choices=["nearest", "none"], default="nearest")
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve()
    target = Path(args.output).expanduser().resolve()
    with Image.open(source) as opened:
        image = opened.convert("RGBA")

    image = alpha_threshold(image, args.alpha_threshold)
    if args.pixelate_scale > 1:
        image = pixelate(image, args.pixelate_scale)
    if args.palette > 0:
        image = quantize_keep_alpha(image, args.palette)

    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    print(f"wrote {target}")


if __name__ == "__main__":
    main()
