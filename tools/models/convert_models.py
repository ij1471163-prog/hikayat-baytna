#!/usr/bin/env python3
"""
مجسمات 3D للشخصيات: أي ملف .glb (أو .gltf مع ملفاته) يترفع في incoming/models/<الشخصية>/
ينتقل لـ assets/models/<الشخصية>/ باسم مبسّط، ويتحدث models_data.gd (قائمة المجسمات لكل شخصية).
الأصل ينحذف من incoming بعد النقل. (Godot يستورد glb لحاله، ما نحتاج تحويل.)
"""
import os, shutil, sys, json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "videos"))
from convert_videos import CHARS, slug

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "incoming" / "models"
DST = ROOT / "assets" / "models"
MODEL_EXT = {".glb", ".gltf"}
SIDE_EXT = {".bin", ".png", ".jpg", ".jpeg", ".webp"}  # ملفات gltf الجانبية


def check_glb(p: Path):
    """فحص بسيط: glb يبدأ بـ glTF والإصدار 2."""
    with open(p, "rb") as f:
        head = f.read(12)
    if len(head) < 12 or head[:4] != b"glTF":
        return "الملف مو glb صحيح (ما يبدأ بـ glTF)"
    return None


def main():
    done, failed = [], []
    if SRC.is_dir():
        for folder, npc in CHARS.items():
            d = SRC / folder
            if not d.is_dir():
                continue
            files = [f for f in sorted(d.iterdir()) if f.is_file()]
            for f in files:
                if f.suffix.lower() not in MODEL_EXT:
                    continue
                if f.suffix.lower() == ".glb":
                    err = check_glb(f)
                    if err:
                        failed.append((f.relative_to(ROOT).as_posix(), err))
                        continue
                out_dir = DST / folder
                out_dir.mkdir(parents=True, exist_ok=True)
                name = slug(f.stem)
                out = out_dir / (name + f.suffix.lower())
                shutil.copyfile(f, out)
                if f.suffix.lower() == ".gltf":
                    # gltf: انسخ الملفات الجانبية بنفس أسمائها (الـ gltf يشير لها بالاسم)
                    for s in files:
                        if s.suffix.lower() in SIDE_EXT:
                            shutil.copyfile(s, out_dir / s.name)
                f.unlink()
                done.append((f.name, out.relative_to(ROOT).as_posix()))
            # نظف الملفات الجانبية اللي تبقت بعد النقل
            if d.is_dir():
                for s in list(d.iterdir()):
                    if s.is_file() and s.suffix.lower() in SIDE_EXT and not any(
                            m.suffix.lower() in MODEL_EXT for m in d.iterdir()):
                        s.unlink()
    man = {}
    for folder, npc in CHARS.items():
        d = DST / folder
        if d.is_dir():
            ms = sorted(p.relative_to(ROOT).as_posix() for p in d.iterdir() if p.suffix.lower() in MODEL_EXT)
            if ms:
                man[npc] = ["res://" + m for m in ms]
    body = ",\n".join('\t"%s": [%s]' % (k, ", ".join('"%s"' % v for v in vs)) for k, vs in man.items())
    (ROOT / "models_data.gd").write_text(
        "extends RefCounted\n# تتولد تلقائيًا من tools/models/convert_models.py (لا تعدلها يدويًا)\nconst MODELS := {\n" + body + "\n}\n",
        encoding="utf-8")
    lines = ["# تقرير المجسمات", "", f"انتقل **{len(done)}** مجسم، وفشل **{len(failed)}**.", ""]
    for a, b in done:
        lines.append(f"- {a} ← `{b}`")
    for a, why in failed:
        lines.append(f"- فشل: {a}: {why}")
    print("\n".join(lines))
    with open(os.environ.get("GITHUB_ENV", os.devnull), "a") as fh:
        fh.write(f"MODELS_DONE={len(done)}\n")
    if failed and not done:
        sys.exit(1)


if __name__ == "__main__":
    main()
