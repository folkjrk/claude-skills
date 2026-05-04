#!/usr/bin/env python3
"""Validate a 64x64 game-character sprite atlas and optionally make a contact sheet."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


def alpha_count(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def edge_count(image: Image.Image, margin: int) -> int:
    alpha = image.getchannel("A")
    w, h = alpha.size
    total = 0
    for box in (
        (0, 0, w, margin),
        (0, h - margin, w, h),
        (0, 0, margin, h),
        (w - margin, 0, w, h),
    ):
        total += sum(alpha.crop(box).histogram()[1:])
    return total


def make_contact(atlas: Image.Image, rows: int, columns: int, cell: int, output: Path) -> None:
    pad = 1
    label_h = 12
    sheet = Image.new("RGBA", (columns * (cell + pad) + pad, rows * (cell + label_h + pad) + pad), (255, 255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    for row in range(rows):
        for col in range(columns):
            x = col * (cell + pad) + pad
            y = row * (cell + label_h + pad) + label_h + pad
            frame = atlas.crop((col * cell, row * cell, (col + 1) * cell, (row + 1) * cell))
            bg = Image.new("RGBA", (cell, cell), (230, 230, 230, 255))
            for by in range(0, cell, 8):
                for bx in range(0, cell, 8):
                    if (bx // 8 + by // 8) % 2:
                        ImageDraw.Draw(bg).rectangle((bx, by, bx + 7, by + 7), fill=(245, 245, 245, 255))
            bg.alpha_composite(frame)
            sheet.alpha_composite(bg, (x, y))
            draw.rectangle((x, y, x + cell, y + cell), outline=(0, 120, 60, 255))
            draw.text((x + 2, y - label_h), f"{row}:{col}", fill=(0, 0, 0, 255))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--columns", type=int, required=True)
    parser.add_argument("--cell", type=int, default=64)
    parser.add_argument("--json-out", required=True)
    parser.add_argument("--contact-sheet")
    parser.add_argument("--min-pixels", type=int, default=80)
    parser.add_argument("--edge-margin", type=int, default=1)
    parser.add_argument("--edge-threshold", type=int, default=12)
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve()
    with Image.open(source) as opened:
        atlas = opened.convert("RGBA")

    expected = (args.columns * args.cell, args.rows * args.cell)
    errors: list[str] = []
    warnings: list[str] = []
    cells = []

    if atlas.size != expected:
        errors.append(f"atlas is {atlas.width}x{atlas.height}; expected {expected[0]}x{expected[1]}")

    for row in range(args.rows):
        for col in range(args.columns):
            box = (col * args.cell, row * args.cell, (col + 1) * args.cell, (row + 1) * args.cell)
            frame = atlas.crop(box)
            nontransparent = alpha_count(frame)
            edge_pixels = edge_count(frame, args.edge_margin)
            if nontransparent < args.min_pixels:
                warnings.append(f"cell {row}:{col} is sparse or empty ({nontransparent} pixels)")
            if edge_pixels > args.edge_threshold:
                warnings.append(f"cell {row}:{col} has {edge_pixels} edge pixels")
            cells.append({"row": row, "column": col, "nontransparent_pixels": nontransparent, "edge_pixels": edge_pixels})

    result = {"ok": not errors, "file": str(source), "width": atlas.width, "height": atlas.height, "errors": errors, "warnings": warnings, "cells": cells}
    out = Path(args.json_out).expanduser().resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    if args.contact_sheet:
        make_contact(atlas, args.rows, args.columns, args.cell, Path(args.contact_sheet).expanduser().resolve())
    print(json.dumps({"ok": not errors, "errors": errors, "warnings": len(warnings)}, indent=2))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
