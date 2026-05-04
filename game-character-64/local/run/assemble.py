#!/usr/bin/env python3
"""Assemble generated strips into atlas. Expects generated/walk_<dir>.png (384x64 each)."""

from pathlib import Path
try:
    from PIL import Image
except ImportError:
    print("pip install Pillow"); raise

RUN_DIR = Path(__file__).parent
GENERATED_DIR = RUN_DIR / "generated"
FINAL_DIR = RUN_DIR / "final"
FINAL_DIR.mkdir(exist_ok=True)

DIRECTIONS = ["south", "south-east", "east", "north-east",
              "north", "north-west", "west", "south-west"]
CELL = 64
COLS = 6


def assemble():
    atlas = Image.new("RGBA", (COLS * CELL, len(DIRECTIONS) * CELL), (0, 0, 0, 0))
    for row_idx, direction in enumerate(DIRECTIONS):
        strip_path = GENERATED_DIR / f"walk_{direction.replace('-','_')}.png"
        if not strip_path.exists():
            print(f"  MISSING: {strip_path.name}")
            continue
        strip = Image.open(strip_path).convert("RGBA")
        if strip.size != (COLS * CELL, CELL):
            strip = strip.resize((COLS * CELL, CELL), Image.NEAREST)
        atlas.paste(strip, (0, row_idx * CELL))
        print(f"  Row {row_idx}: walk-{direction} ✓")

    out = FINAL_DIR / "character-sheet.png"
    atlas.save(out)
    print(f"\nAtlas: {out} ({COLS*CELL}x{len(DIRECTIONS)*CELL})")


if __name__ == "__main__":
    assemble()
