#!/usr/bin/env python3
"""
يحوّل المشاهد التفاعلية المرفوعة في incoming/interactive/<الشخصية>/<اسم_المشهد>/ إلى صيغة Godot:
  - المقاطع (mp4/mov/webm/...) تتحول إلى Ogg Theora (.ogv) وتنحط في assets/ivg/<الشخصية>/<اسم_المشهد>/
  - scene.json ينفحص (المقاطع موجودة؟ كل play/then/go يشير لمقطع حقيقي؟ start موجود؟) ثم يُنسخ مع تحديث أسماء المقاطع لـ .ogv
  - يتحدث ivg_data.gd (قائمة المشاهد لكل شخصية)
الأصل ينحذف من incoming بعد التحويل الناجح. أي مشهد يفشل يبقى مكانه مع السبب في التقرير.
"""
import json, os, shutil, subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from convert_videos import CHARS, slug, EXT  # نفس أسماء الشخصيات والصيغ

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "incoming" / "interactive"
DST = ROOT / "assets" / "ivg"


def clip_names_referenced(node, out):
    """يجمع أسماء المقاطع المذكورة في play/go/then داخل أي مكان في المشهد."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("play", "go", "then") and isinstance(v, (str, list)):
                for n in (v if isinstance(v, list) else [v]):
                    if isinstance(n, str):
                        out.add(n)
            else:
                clip_names_referenced(v, out)
    elif isinstance(node, list):
        for x in node:
            clip_names_referenced(x, out)


def srcs_of(clip):
    s = clip.get("src")
    return s if isinstance(s, list) else ([s] if isinstance(s, str) else [])


def validate(scene, folder: Path):
    errs = []
    clips = scene.get("clips")
    if not isinstance(clips, dict) or not clips:
        return ["scene.json ما فيه clips"]
    if scene.get("start") not in clips:
        errs.append(f"start='{scene.get('start')}' مو موجود في clips")
    refs = set()
    clip_names_referenced(clips, refs)
    for r in sorted(refs - set(clips)):
        errs.append(f"يشير لمقطع غير موجود: {r}")
    for name, c in clips.items():
        if not srcs_of(c):
            errs.append(f"المقطع {name} بدون src")
        for s in srcs_of(c):
            if not (folder / s).is_file():
                errs.append(f"المقطع {name}: الملف {s} غير موجود جنب scene.json")
        inh = c.get("inherit")
        if inh and inh not in clips:
            errs.append(f"المقطع {name}: inherit='{inh}' غير موجود")
    return errs


def to_ogv_name(s: str) -> str:
    return slug(Path(s).stem) + ".ogv"


def convert_scene(char_dir: str, scene_dir: Path):
    sj = scene_dir / "scene.json"
    if not sj.is_file():
        return None, "ما فيه scene.json"
    try:
        scene = json.loads(sj.read_text(encoding="utf-8"))
    except Exception as e:
        return None, f"scene.json مو JSON صحيح: {e}"
    errs = validate(scene, scene_dir)
    if errs:
        return None, "؛ ".join(errs)
    out_dir = DST / char_dir / slug(scene_dir.name)
    out_dir.mkdir(parents=True, exist_ok=True)
    done = {}
    for name, c in scene["clips"].items():
        new = []
        for s in srcs_of(c):
            if s in done:
                new.append(done[s])
                continue
            src = scene_dir / s
            dst_name = to_ogv_name(s)
            dst = out_dir / dst_name
            if src.suffix.lower() == ".ogv":
                shutil.copyfile(src, dst)
            else:
                cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
                       "-vf", "scale='min(1280,iw)':-2:flags=lanczos,fps=30",
                       "-c:v", "libtheora", "-q:v", "8", "-c:a", "libvorbis", "-q:a", "4", "-ar", "44100", str(dst)]
                r = subprocess.run(cmd, capture_output=True, text=True)
                if r.returncode != 0 or not dst.exists() or dst.stat().st_size < 500:
                    if dst.exists():
                        dst.unlink()
                    shutil.rmtree(out_dir, ignore_errors=True)
                    return None, f"فشل تحويل {s}: {(r.stderr or '')[-200:]}"
            done[s] = dst_name
            new.append(dst_name)
        c["src"] = new if isinstance(c.get("src"), list) else new[0]
    (out_dir / "scene.json").write_text(json.dumps(scene, ensure_ascii=False, indent=1), encoding="utf-8")
    return out_dir, None


def main():
    done, failed = [], []
    if SRC.is_dir():
        for folder, npc in CHARS.items():
            d = SRC / folder
            if not d.is_dir():
                continue
            for sd in sorted(p for p in d.iterdir() if p.is_dir()):
                out, err = convert_scene(folder, sd)
                if err:
                    failed.append((sd.relative_to(ROOT).as_posix(), err))
                    continue
                shutil.rmtree(sd)
                done.append((sd.name, out.relative_to(ROOT).as_posix()))
    # manifest: كل المشاهد الموجودة لكل شخصية
    man = {}
    for folder, npc in CHARS.items():
        d = DST / folder
        if d.is_dir():
            scenes = sorted(p.relative_to(ROOT).as_posix() for p in d.glob("*/scene.json"))
            if scenes:
                man[npc] = ["res://" + s for s in scenes]
    body = ",\n".join('\t"%s": [%s]' % (k, ", ".join('"%s"' % v for v in vs)) for k, vs in man.items())
    (ROOT / "ivg_data.gd").write_text(
        "extends RefCounted\n# تتولد تلقائيًا من tools/videos/convert_interactive.py (لا تعدلها يدويًا)\nconst SCENES := {\n" + body + "\n}\n",
        encoding="utf-8")
    lines = ["# تقرير المشاهد التفاعلية", "", f"تحوّل **{len(done)}** مشهد، وفشل **{len(failed)}**.", ""]
    for a, b in done:
        lines.append(f"- {a} ← `{b}`")
    for a, why in failed:
        lines.append(f"- فشل: {a}: {why}")
    print("\n".join(lines))
    with open(os.environ.get("GITHUB_ENV", os.devnull), "a") as fh:
        fh.write(f"IVG_DONE={len(done)}\n")
    if failed and not done:
        sys.exit(1)


if __name__ == "__main__":
    main()
