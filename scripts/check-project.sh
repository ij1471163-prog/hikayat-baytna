#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for f in project.godot main.tscn main.gd export_presets.cfg; do
  test -s "$f" || { echo "MISSING: $f"; exit 1; }
done
for f in assets/layan_outfits/0{1..9}_*.png assets/layan_outfits/1{0..2}_*.png; do
  test -s "$f" || { echo "MISSING OUTFIT: $f"; exit 1; }
done
python3 - <<'PY'
from pathlib import Path
from PIL import Image
root=Path('assets/layan_outfits')
files=sorted(root.glob('*.png'))
for p in files:
    with Image.open(p) as im:
        im.verify()
print(f'OK: {len(files)} outfit PNGs are readable.')
PY
echo 'OK: required Godot project and Android export files are present.'
