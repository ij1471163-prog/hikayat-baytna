#!/usr/bin/env python3
"""
يحوّل الفيديوهات المرفوعة في incoming/videos/<الشخصية>/ إلى صيغة Godot (Ogg Theora .ogv)
ويحطها في assets/videos/<الشخصية>/ ويحدّث video_data.gd (قائمة الفيديوهات لكل شخصية).
الأصل ينحذف من incoming بعد التحويل الناجح. أي ملف يفشل يبقى مكانه مع السبب في التقرير.
"""
import json, re, subprocess, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "incoming" / "videos"
DST = ROOT / "assets" / "videos"
EXT = {".mp4", ".mov", ".webm", ".mkv", ".m4v", ".avi", ".ogv"}
CHARS = {"layan": "ليان", "nora": "نورة", "sara": "سارة", "hind": "هند", "maysoon": "ميسون", "salma": "الشبح"}

def slug(s: str) -> str:
    s = unicodedata.normalize("NFKC", s).lower()
    s = re.sub(r"[^\w\-]+", "_", s, flags=re.UNICODE).strip("_")
    return s or "video"

def main():
    done, failed = [], []
    for folder, npc in CHARS.items():
        d = SRC / folder
        if not d.is_dir(): continue
        for f in sorted(d.iterdir()):
            if not f.is_file() or f.suffix.lower() not in EXT: continue
            out_dir = DST / folder; out_dir.mkdir(parents=True, exist_ok=True)
            name = slug(f.stem); out = out_dir / f"{name}.ogv"; k = 2
            while out.exists():
                out = out_dir / f"{name}_{k}.ogv"; k += 1
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(f),
                   "-vf", "scale='min(1280,iw)':-2:flags=lanczos,fps=30",
                   "-c:v", "libtheora", "-q:v", "8", "-c:a", "libvorbis", "-q:a", "4", "-ar", "44100", str(out)]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0 or not out.exists() or out.stat().st_size < 1000:
                if out.exists(): out.unlink()
                failed.append((f.relative_to(ROOT).as_posix(), (r.stderr or "فشل التحويل")[-300:])); continue
            f.unlink()
            done.append((f.name, out.relative_to(ROOT).as_posix()))
    # manifest: كل الفيديوهات الموجودة لكل شخصية
    man = {}
    for folder, npc in CHARS.items():
        vids = sorted(p.relative_to(ROOT).as_posix() for p in (DST / folder).glob("*.ogv")) if (DST / folder).is_dir() else []
        if vids: man[npc] = ["res://" + v for v in vids]
    DST.mkdir(parents=True, exist_ok=True)
    body = ",\n".join('\t"%s": [%s]' % (k, ", ".join('"%s"' % v for v in vs)) for k, vs in man.items())
    (ROOT / "video_data.gd").write_text("extends RefCounted\n# تتولد تلقائيًا من tools/videos/convert_videos.py (لا تعدلها يدويًا)\nconst VIDEOS := {\n" + body + "\n}\n", encoding="utf-8")
    lines = ["# تقرير الفيديوهات", "", f"تحوّل **{len(done)}** فيديو، وفشل **{len(failed)}**.", ""]
    for a, b in done: lines.append(f"- {a} ← `{b}`")
    for a, why in failed: lines.append(f"- فشل: {a}: {why}")
    print("\n".join(lines))
    print(f"::DONE={len(done)}")
    import os
    with open(os.environ.get("GITHUB_ENV", os.devnull), "a") as fh: fh.write(f"DONE={len(done)}\n")
    if failed and not done: sys.exit(1)

if __name__ == "__main__":
    main()
