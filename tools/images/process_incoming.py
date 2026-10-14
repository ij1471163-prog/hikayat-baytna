#!/usr/bin/env python3
"""
يجهّز الصور المرفوعة في incoming/ ويوديها لمكانها في اللعبة.

الاستخدام:  python tools/images/process_incoming.py [--dry-run] [--backup-dir DIR]

- يعرف مكان كل صورة من اسمها (اسم الملف الحالي في اللعبة، أو اسم عربي معروف).
- الخلفيات: 1920x1080 بدون مط ولا تعبئة فراغات. إذا النسبة بعيدة عن 16:9 ترجع الصورة بتقرير.
  تغيير المقاس ليس تحسين جودة؛ إذا الصورة أصغر من المطلوب يذكر التقرير إنها مكبّرة فقط.
- الشخصيات: تنشال الخلفية (إذا ما كانت شفافة أصلًا) وتنقص الحواف الفاضية.
- قبل أي استبدال تنحفظ نسخة من الصورة القديمة في مجلد النسخ الاحتياطية.
- أي صورة ما انعرف مكانها أو فشلت تبقى في incoming/ ويكتب السبب في التقرير.
- يكتب التقرير في incoming/REPORT-AR.md وملخص JSON في incoming/.last_run.json
"""
import json, os, re, shutil, sys, unicodedata
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "incoming"
IMG_EXT = {".png", ".jpg", ".jpeg", ".webp"}
SKIP = {"readme-ar.md", "report-ar.md", ".gdignore", ".gitkeep", ".last_run.json"}
BG_SIZE = (1920, 1080)
BG_RATIO_TOL = 0.03          # فرق مسموح عن 16:9 (يُقص بالتساوي من الطرفين، بدون مط)
CHAR_MAX_H = 1400            # أطول ارتفاع لصور الشخصيات (تصغير فقط، بدون تكبير)
CHAR_MIN_H = 500             # أقل من كذا يعتبر دقة ضعيفة (تحذير)

# ------------------------------------------------------------------ الخريطة
def norm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s).strip().lower()
    s = re.sub(r"\.(png|jpe?g|webp)$", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ة", "ه").replace("ى", "ي")
    s = re.sub(r"[\s\-\.]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s

def build_map():
    """يرجع {الاسم_المطبّع: [(المسار, النوع), ...]} من ملفات المشروع نفسه."""
    targets = {}   # path -> kind
    A = ROOT / "assets"
    for p in sorted((A / "backgrounds").glob("*")):
        if p.suffix.lower() in IMG_EXT: targets[p.relative_to(ROOT).as_posix()] = "bg"
    for sub in ["", "layan", "poses", "nora_poses"]:
        d = A / "sprites" / sub
        for p in sorted(d.glob("*.png")):
            targets[p.relative_to(ROOT).as_posix()] = "char"
    # مشاهد عريضة (CG): الطبخ والحمام والمشاهد في assets/wide، والمساج، والشبح
    scene_alias = {}
    for p in sorted((A / "wide").glob("*.jpg")):
        targets[p.relative_to(ROOT).as_posix()] = "bg"
    for p in sorted((A / "massage").glob("*.jpg")):
        rel = p.relative_to(ROOT).as_posix(); targets[rel] = "bg"; scene_alias["massage_" + p.stem] = rel
    for p in sorted((A / "ghost").glob("*.jpg")):
        rel = p.relative_to(ROOT).as_posix(); targets[rel] = "bg"; scene_alias["ghost_" + p.stem] = rel
    for p in sorted((A / "scenes").glob("*.jpg")):
        rel = p.relative_to(ROOT).as_posix(); targets[rel] = "bg"; scene_alias["scene_" + p.stem] = rel
    # صور تنتظرها اللعبة ولسا مو موجودة (من IMAGES-NEEDED-AR.txt)
    needed = ROOT / "IMAGES-NEEDED-AR.txt"
    if needed.exists():
        for m in re.finditer(r"assets/(backgrounds|sprites/layan)/[\w\-]+\.(?:png|jpg)", needed.read_text(encoding="utf-8")):
            path = m.group(0)
            targets.setdefault(path, "bg" if "backgrounds" in path else "char")
    aliases = {}
    def add(alias, path):
        k = norm(alias)
        if not k: return
        lst = aliases.setdefault(k, [])
        if path not in lst: lst.append(path)
    for path, kind in targets.items():
        stem = Path(path).stem
        folder = Path(path).parent.name
        if folder in ("massage", "ghost", "scenes"): continue   # أسماؤها في scene_alias
        add(stem, path)
        add(re.sub(r"^\d+_", "", stem), path)                     # بدون الرقم: pink_hearts_pajamas
        prefix = {"backgrounds": "bg", "layan": "layan", "poses": "pose", "nora_poses": "nora_pose", "sprites": "char"}.get(folder)
        if prefix is None: continue   # المشاهد لها أسماء خاصة (scene_alias)
        add(f"{prefix}_{stem}", path)                               # bg_laundry / pose_laundry ...
        add(f"{prefix}_{re.sub(r'^[0-9]+_', '', stem)}", path)
    for al, rel in scene_alias.items():
        aliases[norm(al)] = [rel]
    # أسماء عربية من كود اللعبة (قراءة فقط)
    main = (ROOT / "main.gd").read_text(encoding="utf-8")
    bgm = re.search(r"const BG_FILES := \{(.*?)\}", main)
    if bgm:
        for place, f in re.findall(r'"([^"]+)":"([^"]+)"', bgm.group(1)):
            for ext in ("jpg", "png"):
                p = f"assets/backgrounds/{f}.{ext}"
                if p in targets: add(place, p); add("خلفيه " + place, p)
    otm = re.search(r"var outfit_textures := \{(.*?)\n\}", main, re.S)
    if otm:
        for name, p in re.findall(r'"([^"]+)":\s*"res://(assets/layan_outfits/[^"]+)"', otm.group(1)):
            sp = p.replace("layan_outfits", "sprites/layan")
            targets.setdefault(sp, "char")
            add(name, sp); add("ليان " + name, sp)
    world = (ROOT / "world_data.gd").read_text(encoding="utf-8")
    for name, img in re.findall(r'"([^"]+)":\s*\{"img":\s*"res://assets/npcs/(\w+)\.png"', world):
        sp = f"assets/sprites/{img}.png"
        if sp in targets: add(name, sp)
    for extra, f in [("المستشفى", "hospital"), ("غرفه البيبي", "nursery"), ("الممر", "hallway"), ("غرفه التخزين", "storage"), ("التخزين", "storage")]:
        p = f"assets/backgrounds/{f}.jpg"
        if p in targets:
            aliases[norm(extra)] = [p]          # الأسماء الجديدة تغلب الخريطة القديمة
            add("خلفيه " + extra, p)
    return aliases, targets

# ------------------------------------------------------------------ المعالجة
def check_image(src: Path):
    with Image.open(src) as im:
        im.verify()
    im = Image.open(src)
    im.load()
    return ImageOps.exif_transpose(im)

def process_bg(im: Image.Image, dst: Path, notes: list):
    w, h = im.size
    r, target = w / h, BG_SIZE[0] / BG_SIZE[1]
    if abs(r - target) / target > BG_RATIO_TOL:
        raise ValueError(f"نسبة الصورة {w}x{h} ({r:.2f}) بعيدة عن 16:9 (1.78). "
                         "ما نمطها ولا نعبّي فراغات. قصّها 16:9 يدويًا، أو اطلب توليد أجزاء ناقصة بالذكاء الاصطناعي (مرحلة منفصلة).")
    if r > target:     # أعرض شوي: قص بسيط بالتساوي من الجنبين
        nw = round(h * target); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
    elif r < target:
        nh = round(w / target); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
    if im.size[0] < BG_SIZE[0]:
        notes.append(f"الأصل {w}x{h} أصغر من 1920x1080؛ تم تكبير المقاس فقط وهذا ليس تحسين جودة.")
    im = im.convert("RGB").resize(BG_SIZE, Image.LANCZOS)
    if dst.suffix.lower() == ".png": im.save(dst, optimize=True)
    else: im.save(dst, quality=90, optimize=True)

_session = None
def cut_background(im: Image.Image) -> Image.Image:
    global _session
    from rembg import remove, new_session
    if _session is None: _session = new_session("isnet-general-use")
    return remove(im.convert("RGB"), session=_session)

def process_char(im: Image.Image, dst: Path, notes: list):
    im = im.convert("RGBA")
    a = np.array(im.getchannel("A"))
    # الصورة تعتبر مقصوصة إذا حوافها شفافة. إذا الحواف معتمة (خلفية أو مربع) نشيل الخلفية.
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    if (edge > 200).mean() > 0.15:
        im = cut_background(im)
        notes.append("انشالت الخلفية تلقائيًا (راجع الحواف).")
    else:
        notes.append("الصورة شفافة أصلًا؛ ما انشالت خلفية.")
    bb = im.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    if not bb: raise ValueError("بعد شيل الخلفية ما بقى شي من الشخصية.")
    pad = 4
    im = im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(im.width, bb[2] + pad), min(im.height, bb[3] + pad)))
    filled = (np.array(im.getchannel("A")) > 128).mean()
    if filled < 0.08: raise ValueError("الشخصية بعد القص صغيرة جدًا أو مقطوعة؛ يمكن الصورة غلط.")
    if im.height > CHAR_MAX_H:
        im = im.resize((round(im.width * CHAR_MAX_H / im.height), CHAR_MAX_H), Image.LANCZOS)
    if im.height < CHAR_MIN_H:
        notes.append(f"دقة ضعيفة (الارتفاع {im.height}px). ما كبّرناها؛ يفضل صورة أكبر.")
    im.save(dst.with_suffix(".png"), optimize=True)

# ------------------------------------------------------------------ التشغيل
def main():
    dry = "--dry-run" in sys.argv
    backup_dir = None
    if "--backup-dir" in sys.argv: backup_dir = ROOT / sys.argv[sys.argv.index("--backup-dir") + 1]
    aliases, targets = build_map()
    files = sorted(p for p in INCOMING.rglob("*") if p.is_file() and p.name.lower() not in SKIP and not p.name.startswith("."))
    done, left, used = [], [], {}
    for src in files:
        rel = src.relative_to(ROOT).as_posix()
        if src.suffix.lower() not in IMG_EXT:
            left.append((rel, "مو صورة (المسموح: png / jpg / webp).")); continue
        key = norm(src.stem)
        cands = aliases.get(key, [])
        if not cands:
            left.append((rel, f"ما عرفت وين تروح «{src.stem}». سمّها باسم الملف في اللعبة (مثل cafe أو sara أو 13_pink_hearts_pajamas) أو بالاسم العربي (مثل المقهى، سارة، بيجامة الدباديب).")); continue
        if len(cands) > 1:
            opts = " / ".join(cands)
            left.append((rel, f"الاسم «{src.stem}» يطابق أكثر من مكان: {opts}. أضف بداية مثل bg_ أو pose_ أو nora_pose_.")); continue
        dst_rel = cands[0]
        if dst_rel in used:
            left.append((rel, f"فيه صورة ثانية لنفس المكان ({used[dst_rel]}). ارفع وحدة بس.")); continue
        kind = targets.get(dst_rel, "char")
        dst = ROOT / dst_rel
        notes = []
        try:
            im = check_image(src)
            if dry:
                notes.append("(تجربة: ما تم الحفظ)")
            else:
                if dst.exists() and backup_dir is not None:
                    b = backup_dir / dst_rel
                    b.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dst, b)
                    notes.append(f"نسخة احتياطية: {b.relative_to(ROOT).as_posix()}")
                dst.parent.mkdir(parents=True, exist_ok=True)
                (process_bg if kind == "bg" else process_char)(im, dst, notes)
                check_image(dst if dst.exists() else dst.with_suffix(".png"))   # تحقق إن الناتج سليم
                src.unlink()
            used[dst_rel] = rel
            label = "شخصية" if kind != "bg" else ("خلفية" if "/backgrounds/" in dst_rel else "مشهد")
            done.append((rel, dst_rel, label, notes))
        except Exception as e:
            left.append((rel, f"تعذّرت المعالجة: {e}"))
    # التقرير
    lines = ["# تقرير الصور المستلمة", ""]
    lines.append(f"تمت معالجة **{len(done)}** صورة، وبقيت **{len(left)}** في incoming/.")
    lines.append("")
    if done:
        lines += ["## انعالجت (تنتظر المراجعة قبل الدمج)", "", "| الملف | المكان في اللعبة | النوع | ملاحظات |", "|---|---|---|---|"]
        for s, d, k, n in done: lines.append(f"| {s} | `{d}` | {k} | {' '.join(n)} |")
        lines.append("")
    if left:
        lines += ["## ما انعالجت (باقية في incoming/)", "", "| الملف | السبب |", "|---|---|"]
        for s, why in left: lines.append(f"| {s} | {why} |")
        lines.append("")
    room_bgs = {"living_room", "kitchen", "bedroom", "layan_room", "bathroom", "laundry", "relax_room", "nora_room", "entrance"}
    touched = [d for _, d, k, _ in done if k == "خلفية" and Path(d).stem in room_bgs]
    if touched:
        lines += ["## تنبيه", "", "تغيّرت خلفية غرفة فيها نقاط ضغط: " + ", ".join(f"`{t}`" for t in touched) +
                  ". تأكد إن الأثاث بنفس المكان، وإلا لازم تتعدل المواقع في rooms_data.gd.", ""]
    lines.append("تغيير المقاس وشيل الخلفية ليسا تحسينًا للجودة. أي تحسين أو توليد أجزاء بالذكاء الاصطناعي مرحلة منفصلة.")
    if not dry:
        (INCOMING / "REPORT-AR.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (INCOMING / ".last_run.json").write_text(json.dumps({"done": [[s, d] for s, d, _, _ in done], "left": left}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("\n".join(lines))
    print(f"::DONE={len(done)} LEFT={len(left)}")

if __name__ == "__main__":
    main()
