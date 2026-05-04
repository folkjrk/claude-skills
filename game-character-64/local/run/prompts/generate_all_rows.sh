#!/bin/bash
# Walk-only spritesheet: 8 directions x 6 frames
# Run after generating base sprite at run/generated/base.png

DIRECTIONS=(south south-east east north-east north north-west west south-west)
SKILL_DIR="/Users/astroxjrk/.claude/skills/game-character-64"
RUN_DIR="$(dirname "$0")/.."

for dir in "${DIRECTIONS[@]}"; do
  echo "--- walk-${dir} ---"
  # $imagegen prompt: run/prompts/walk_${dir//-/_}.txt
  # Output: run/generated/walk_${dir//-/_}.png
done

# After all strips are generated, assemble and clean:
# python "$SKILL_DIR/scripts/pixel_snap.py" --input run/generated/atlas_raw.png --output run/final/character-sheet-clean.png --cell 64 --palette 32 --scale-mode nearest --alpha-threshold 24

# Validate:
# python "$SKILL_DIR/scripts/validate_64_sheet.py" --input run/final/character-sheet-clean.png --rows 8 --columns 6 --json-out run/qa/validation.json --contact-sheet run/qa/contact-sheet.png

# Export previews:
# python "$SKILL_DIR/scripts/export_animation_previews.py" --atlas run/final/character-sheet-clean.png --rows 8 --columns 6 --row-names south,south-east,east,north-east,north,north-west,west,south-west --prefix walk --out-dir run/qa/previews --scale 4
