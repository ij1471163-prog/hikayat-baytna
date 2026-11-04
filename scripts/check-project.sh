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
for f in ivg/ivg_engine.gd ivg/ivg_cond.gd ivg/ivg_warp.gdshader ivg_data.gd; do
  test -s "$f" || { echo "MISSING IVG FILE: $f"; exit 1; }
done
python3 - <<'PY'
import json, glob
n = 0
for p in glob.glob('assets/ivg/**/scene.json', recursive=True) + ['incoming/interactive/_example/scene.json', 'tools/ivg/test_scene.json']:
    json.load(open(p, encoding='utf-8')); n += 1
print(f'OK: {n} interactive scene JSON files are valid.')
PY
echo 'OK: required Godot project and Android export files are present.'
