# الربط الذكي: صورة شخصية بأي اسم -> تعرف مين، وش تسوي، وش لابسة، وقفتها
# -> تبدّل الصورة القديمة لو هي نسخة معدلة منها، أو تضيفها وضعية جديدة في الغرفة والوقت المناسب
import os, sys, re, json, shutil
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "autorig"))
import vision, characters

ROOT = vision.ROOT
SPR = vision.SPR
DB = os.path.join(HERE, "world_auto.json")        # كل اللي أضافته الأداة (مصدر world_auto.gd)
OUT_GD = os.path.join(ROOT, "world_auto.gd")
MIN_CHAR_CONF = 0.70
REPLACE_SIM = 0.95

# ===== وش تسوي (CLIP يقارن الصورة بهذي الجمل) =====
ACTS = {
    "cooking":  (["a woman cooking with a frying pan", "a woman stirring a pot in the kitchen", "a woman chopping vegetables"],
                 "تطبخ", ["المطبخ"], [0, 1, 2]),
    "cleaning": (["a woman cleaning the floor with a mop", "a woman sweeping with a broom", "a woman wiping with a spray bottle and cloth", "a woman scrubbing with rubber gloves"],
                 "تنظف", ["الصالة", "المطبخ", "الممر", "المدخل"], [0, 1]),
    "laundry":  (["a woman holding a laundry basket full of clothes", "a woman folding laundry"],
                 "تغسل وترتب الملابس", ["غرفة الغسيل"], [0, 1]),
    "towel":    (["a woman wrapped in a bath towel after a shower", "a woman drying her hair with a towel"],
                 "طالعة من الشاور", ["غرفة النوم", "غرفة ليان"], [2, 3]),
    "sleep":    (["a sleepy woman in pajamas hugging a pillow", "a woman in pajamas stretching before bed"],
                 "نعسانة", ["غرفة النوم", "غرفة ليان"], [3]),
    "relax":    (["a woman relaxing sitting on a sofa", "a woman sitting comfortably hugging her knees"],
                 "ترتاح", ["الصالة", "غرفة ليان", "غرفة الاسترخاء"], [1, 2, 3]),
    "phone":    (["a woman looking at her smartphone", "a woman lying down scrolling on her phone"],
                 "تتصفح جوالها", ["غرفة ليان", "غرفة النوم", "الصالة"], [1, 2, 3]),
    "drink":    (["a woman drinking from a mug", "a woman holding a cup of coffee"],
                 "تشرب شي دافي", ["المطبخ", "الصالة", "غرفة ليان"], [0, 2]),
    "eat":      (["a woman eating a meal", "a woman eating noodles from a bowl"],
                 "تاكل", ["المطبخ", "الصالة"], [0, 1, 2]),
    "read":     (["a woman reading a book"],
                 "تقرا", ["غرفة ليان", "الصالة"], [1, 2, 3]),
    "exercise": (["a woman exercising in sportswear", "a woman doing yoga stretches", "a woman with a water bottle after a workout"],
                 "تتمرن", ["الصالة", "غرفة الاسترخاء"], [0, 2]),
    "office":   (["a woman in an office outfit holding a clipboard", "a woman in business clothes ready for work"],
                 "لابسة للدوام", ["الصالة", "المدخل"], [0]),
    "shopping": (["a woman carrying grocery bags", "a woman back from shopping with bags"],
                 "راجعة من التسوق", ["المدخل", "المطبخ"], [1]),
    "serve":    (["a woman serving food on a tray", "a woman carrying a plate of food"],
                 "تقدم الأكل", ["المطبخ", "الصالة"], [1, 2]),
    "stand":    (["a woman standing casually at home", "a woman posing and smiling at home"],
                 "واقفة", ["الصالة", "غرفة ليان", "المطبخ"], [0, 1, 2, 3]),
}
OUTFITS = {
    "pajamas": (["a woman wearing a matching pajama set with long sleeves and pajama pants", "a woman in patterned sleepwear", "a woman in a satin nightgown"], "بالبيجامة"),
    "home":    (["a woman in a t-shirt and shorts at home", "a woman in a cozy sweater at home", "a woman in a tank top and shorts"], "بلبس البيت"),
    "casual":  (["a woman in a t-shirt and jeans", "a woman in a blouse and trousers"], "بلبس كاجوال"),
    "sport":   (["a woman in sportswear and leggings", "a woman in a sports bra"], "باللبس الرياضي"),
    "office":  (["a woman in an office suit or blouse and pencil skirt"], "بلبس الدوام"),
    "dress":   (["a woman wearing a dress"], "بالفستان"),
    "maid":    (["a woman in a maid uniform with an apron"], "بلبس الخدمة"),
    "apron":   (["a woman wearing a kitchen apron"], "بالمريول"),
    "towel":   (["a woman wrapped in a towel"], "بالفوطة"),
    "outdoor": (["a woman in outdoor clothes with a hat or coat"], "بلبس الطلعة"),
}
PREFIX = {"ليان": "l", "نورة": "n", "هند": "h", "ميسون": "m", "سارة": "s"}
# نورة لها غرفتها؛ الضيوف يطلعون في أماكنهم
ROOM_FIX = {"نورة": {"غرفة ليان": "غرفة نورة", "غرفة النوم": "غرفة نورة"}}

def posture(det):
    """واقفة / على كرسي / على الأرض / منسدحة — من المفاصل"""
    q = {k: np.array(v[:2]) for k, v in det.get("pose", {}).items() if v[2] > 0.3}
    if not all(k in q for k in ["shL", "shR", "hipL", "hipR"]): return "stand"
    sh = (q["shL"] + q["shR"]) / 2; hip = (q["hipL"] + q["hipR"]) / 2
    tv = hip - sh; tl = np.linalg.norm(tv) + 1e-6
    if abs(tv[0]) > abs(tv[1]) * 1.1: return "lie"
    kn = [q[k] for k in ["knL", "knR"] if k in q]
    an = [q[k] for k in ["anL", "anR"] if k in q]
    if not kn: return "stand"
    knee = np.mean(kn, 0)
    if knee[1] - hip[1] < tl * 0.45:          # الفخذ قريب من الأفقي = قاعدة
        if an and np.mean(an, 0)[1] - knee[1] > tl * 0.55: return "chair"
        return "sit"
    return "stand"

def silhouette_iou(a, b):
    def m(im):
        im = im.convert("RGBA"); h = 256; w = max(1, round(im.width * h / im.height))
        x = np.zeros((h, 256), bool); al = np.asarray(im.resize((w, h)).getchannel("A")) > 40
        w = min(w, 256); x[:, (256 - w) // 2:(256 - w) // 2 + w] = al[:, :w]
        return x
    A, B = m(a), m(b)
    return float((A & B).sum() / max((A | B).sum(), 1))

def load_db():
    return json.load(open(DB, encoding="utf-8")) if os.path.exists(DB) else {"entries": []}

def save_db(db):
    json.dump(db, open(DB, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    write_gd(db)

def write_gd(db):
    # world_auto.gd: اللعبة تقرأ منه الوضعيات اللي أضافتها الأداة (لا تعدله يدوي، يتولد تلقائياً)
    by = {}
    for e in db["entries"]: by.setdefault(e["char"], []).append(e)
    lines = ["extends RefCounted", "# يتولد تلقائياً من tools/world_link (الربط الذكي للصور). لا تعدله يدوي.", "const ENTRIES := {"]
    for c, es in by.items():
        lines.append('\t"%s": [' % c)
        for e in es:
            d = {k: e[k] for k in ["id", "post", "rooms", "periods", "label", "act", "w"]}
            lines.append("\t\t" + json.dumps(d, ensure_ascii=False) + ",")
        lines.append("\t],")
    lines.append("}")
    open(OUT_GD, "w", encoding="utf-8").write("\n".join(lines) + "\n")

def analyze(png_path, orig_path=None):
    """يحلل صورة شخصية مقصوصة. يرجع قرار كامل (بدون ما يحفظ شي)"""
    import detect
    im = Image.open(png_path).convert("RGBA")
    det, _ = detect.run(png_path)
    if not det.get("pose"):
        return {"ok": False, "why": "ما لقيت شخص واضح في الصورة."}
    refs = characters.build_refs()
    face, body = characters.features(im)
    who, conf, near = characters.identify(face, body, refs)
    # وش تسوي: نشوف الصورة المقصوصة والأصلية (الخلفية تساعد: مطبخ، حمام...) ونجمع الرأيين
    embs = [body]
    if orig_path and os.path.exists(orig_path):
        embs.append(vision.embed_images([Image.open(orig_path)])[0])
    def avg(classes):
        rs = [vision.zero_shot(e, classes) for e in embs]
        return {k: sum(r[k] for r in rs) / len(rs) for k in classes}
    acts = avg({k: v[0] for k, v in ACTS.items()})
    outs = vision.zero_shot(body, {k: v[0] for k, v in OUTFITS.items()})
    act = max(acts, key=acts.get); outfit = max(outs, key=outs.get)
    # لو مو متأكدة وش تسوي، اللبس يحسم (لبس خدمة = تنظف، مريول = تطبخ...)
    act_conf = acts[act]
    if acts[act] < 0.4:
        act_conf = -1.0   # القرار من اللبس
        act = {"maid": "cleaning", "apron": "cooking", "sport": "exercise", "towel": "towel", "office": "office"}.get(outfit, "stand")
    post = posture(det)
    if post == "stand" and im.width > im.height * 0.85: post = "sit"     # صورة عريضة = غالباً قاعدة
    # هل هي نسخة معدلة من صورة موجودة؟
    paths, names, F, B, HF = refs
    sims = B @ body
    order = np.argsort(-sims)
    replace = None
    for j in order[:3]:
        if names[j] != who or sims[j] < REPLACE_SIM: continue
        old = Image.open(os.path.join(SPR, paths[j]))
        iou = silhouette_iou(im, old)
        second = sims[order[1]] if order[0] == j else sims[order[0]]
        if iou > 0.72 and (sims[j] - second > 0.015 or iou > 0.85):
            replace = {"path": paths[j], "sim": round(float(sims[j]), 3), "iou": round(iou, 2)}
            break
    A = ACTS[act]
    rooms = [ROOM_FIX.get(who, {}).get(r, r) for r in A[2]]
    rooms = list(dict.fromkeys(rooms))
    if post == "lie": rooms = [r for r in rooms if r in ["غرفة النوم", "غرفة ليان", "غرفة نورة", "الصالة"]] or ["غرفة النوم"]
    label = "%s %s" % (A[1], OUTFITS[outfit][1]) if outfit not in ("towel",) or act != "towel" else A[1]
    if who == "الشبح":
        rooms, label = ["غرفة النوم"], "الشبح"
    return {"ok": True, "char": who, "char_conf": round(conf, 2), "near": near,
            "act": act, "act_conf": round(act_conf, 2), "outfit": outfit, "outfit_conf": round(outs[outfit], 2),
            "post": post, "rooms": rooms, "periods": A[3], "label": label, "replace": replace}

def place(png_path, info, db, dry=False, backup_dir=None):
    """يحفظ الصورة في مكانها ويسجلها في اللعبة. يرجع المسار داخل المشروع"""
    who = info["char"]
    if info["replace"]:
        dst_rel = "assets/sprites/" + info["replace"]["path"]
    elif who == "الشبح":
        i = 1
        while os.path.exists(os.path.join(SPR, "ghost", "body%d.png" % i)): i += 1
        dst_rel = "assets/sprites/ghost/body%d.png" % i
    else:
        base = "%s_%s_%s" % (PREFIX.get(who, "x"), info["act"], info["outfit"])
        i = 1
        while os.path.exists(os.path.join(SPR, "idle", "%s%d.png" % (base, i))) or any(e["id"] == "%s%d" % (base, i) for e in db["entries"]): i += 1
        dst_rel = "assets/sprites/idle/%s%d.png" % (base, i)
    dst = os.path.join(ROOT, dst_rel)
    if dry: return dst_rel
    if os.path.exists(dst) and backup_dir:
        b = os.path.join(backup_dir, dst_rel); os.makedirs(os.path.dirname(b), exist_ok=True); shutil.copy2(dst, b)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(png_path, dst)
    if not info["replace"] and who != "الشبح":
        db["entries"].append({"id": os.path.basename(dst)[:-4], "char": who, "post": info["post"], "rooms": info["rooms"],
                              "periods": info["periods"], "label": info["label"], "act": info["act"], "w": 2.0})   # الجديدة تطلع أكثر
    return dst_rel

if __name__ == "__main__":
    # تجربة: python link.py صورة.png  (يحلل بس، ما يحفظ)
    for p in sys.argv[1:]:
        print(p, json.dumps(analyze(p), ensure_ascii=False))
