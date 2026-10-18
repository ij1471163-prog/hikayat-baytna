# يجهز الجسم الحي تلقائياً لأي صورة جديدة أو معدلة (ويحذف هياكل الصور المحذوفة)
# يشتغل في GitHub Actions قبل بناء الـ APK، أو يدوياً:  python tools/autorig/run.py
# يحتاج: python 3.12 + mediapipe==0.10.14 + numpy<2 + scipy + pillow
import os, sys, glob, gzip, json, struct, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "assets", "rig")
DIRS = ["layan", "full", "idle", "nora_poses", "poses"]

def md5(p): return hashlib.md5(open(p, "rb").read()).hexdigest()
def rig_md5(p):
    try:
        b = gzip.decompress(open(p, "rb").read()); hl = struct.unpack("<I", b[:4])[0]
        return json.loads(b[4:4 + hl]).get("src_md5", "")
    except Exception:
        return ""

def main():
    os.makedirs(OUT, exist_ok=True)
    imgs = []
    for d in DIRS: imgs += sorted(glob.glob(os.path.join(SPR, d, "*.png")))
    want = {}
    stale = []
    for p in imgs:
        rel = os.path.relpath(p, SPR).replace(os.sep, "/")
        key = rel.replace("/", "__")[:-4]
        want[key] = True
        h = md5(p)
        if rig_md5(os.path.join(OUT, key + ".rig")) != h: stale.append((rel, key, h))
    # هياكل صور انحذفت
    for f in glob.glob(os.path.join(OUT, "*.rig")):
        k = os.path.basename(f)[:-4]
        if k not in want:
            os.remove(f)
            for x in [k + "_mask.png", k + "_mask.png.import"]:
                if os.path.exists(os.path.join(OUT, x)): os.remove(os.path.join(OUT, x))
            print("removed", k)
    print("images:", len(imgs), "to rig:", len(stale))
    if not stale: return
    import detect, autorig
    ok = 0
    for rel, key, h in stale:
        try:
            det, _ = detect.run(os.path.join(SPR, rel))
            det["src_md5"] = h
            v, msg = autorig.build(rel, det, OUT, key, SPR)
        except Exception as e:
            v, msg = None, "error %s" % e
        if v is None:
            # ما زبط: نشيل الهيكل القديم عشان اللعبة ترجع للنسخة البسيطة بدل حركة غلط
            for x in [key + ".rig", key + "_mask.png"]:
                if os.path.exists(os.path.join(OUT, x)): os.remove(os.path.join(OUT, x))
        else:
            ok += 1
        print(rel, msg)
    print("done", ok, "/", len(stale))

if __name__ == "__main__":
    main()
