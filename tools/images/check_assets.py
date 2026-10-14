#!/usr/bin/env python3
"""
تحقق من سلامة صور اللعبة ومساراتها.
- كل صورة داخل assets/ لازم تنفتح بدون تلف.
- كل مسار صورة مكتوب في كود اللعبة (*.gd) لازم يكون موجود، إلا الصور المذكورة في
  IMAGES-NEEDED-AR.txt (اللعبة تتعامل مع غيابها) والمسارات اللي لها نسخة عريضة في assets/wide.
يرجع رمز خطأ 1 إذا فيه مشكلة.
"""
import re, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
bad, missing, warn = [], [], []
count = 0
for p in sorted((ROOT / "assets").rglob("*")):
    if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
        count += 1
        try:
            with Image.open(p) as im: im.verify()
        except Exception as e:
            bad.append(f"{p.relative_to(ROOT).as_posix()}: {e}")
needed_txt = (ROOT / "IMAGES-NEEDED-AR.txt").read_text(encoding="utf-8") if (ROOT / "IMAGES-NEEDED-AR.txt").exists() else ""
expected = set(re.findall(r"assets/[\w/\-]+\.(?:png|jpg)", needed_txt))
expected |= {e.replace("sprites/layan", "layan_outfits") for e in expected}
src = "".join(f.read_text(encoding="utf-8") for f in ROOT.glob("*.gd"))
for ref in sorted(set(re.findall(r"res://(assets/[^\"\s%]+\.(?:png|jpg|webp))", src))):
    if (ROOT / ref).exists(): continue
    wide = ROOT / "assets/wide" / f"{Path(ref).parent.name}_{Path(ref).stem}.jpg"
    if wide.exists(): continue
    (warn if ref in expected else missing).append(ref)
print(f"صور تم فحصها: {count}")
for b in bad: print("تالفة:", b)
for m in missing: print("مسار مفقود:", m)
for w in warn: print("تنتظر صورة (اللعبة تتعامل مع غيابها):", w)
if bad or missing:
    print("FAILED"); sys.exit(1)
print("OK")
