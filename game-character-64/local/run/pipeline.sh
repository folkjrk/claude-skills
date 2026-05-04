#!/bin/bash
# Full pipeline: generate → assemble → clean → validate → preview
# Usage: bash pipeline.sh

# pipeline continues even if individual steps fail
SKILL="/Users/astroxjrk/.claude/skills/game-character-64"
RUN="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$RUN/.venv/bin/python3"

echo "=== Step 1: Generate via Draw Things ==="
$PYTHON "$RUN/draw_things_generate.py"

echo ""
echo "=== Step 2: Assemble atlas ==="
$PYTHON "$RUN/assemble.py"

echo ""
echo "=== Step 3: Pixel cleanup ==="
$PYTHON "$SKILL/scripts/pixel_snap.py" \
  --input "$RUN/final/character-sheet.png" \
  --output "$RUN/final/character-sheet-clean.png" \
  --cell 64 \
  --palette 32 \
  --scale-mode nearest \
  --alpha-threshold 24 \
  --pixelate-scale 2

echo ""
echo "=== Step 4: Validate ==="
$PYTHON "$SKILL/scripts/validate_64_sheet.py" \
  --input "$RUN/final/character-sheet-clean.png" \
  --rows 8 \
  --columns 6 \
  --json-out "$RUN/qa/validation.json" \
  --contact-sheet "$RUN/qa/contact-sheet.png"

echo ""
echo "=== Step 5: Export previews ==="
$PYTHON "$SKILL/scripts/export_animation_previews.py" \
  --atlas "$RUN/final/character-sheet-clean.png" \
  --rows 8 \
  --columns 6 \
  --row-names "south,south-east,east,north-east,north,north-west,west,south-west" \
  --prefix walk \
  --out-dir "$RUN/qa/previews" \
  --scale 4

echo ""
echo "=== Done! ==="
echo "Atlas:    $RUN/final/character-sheet-clean.png"
echo "QA:       $RUN/qa/"
