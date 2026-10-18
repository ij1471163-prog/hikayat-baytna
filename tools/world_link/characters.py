# يعرف الشخصية: يقارن الوجه والجسم بصور اللعبة الحالية (كل صورة نعرف صاحبتها من مجلدها أو من pose_data)
import os, re, glob, json
import numpy as np
from PIL import Image
import vision

CHARS = {"ليان": "layan", "نورة": "nora", "هند": "hind", "ميسون": "maysoon", "سارة": "sara", "الشبح": "ghost"}
REFS = os.path.join(vision.HERE, ".models", "char_refs.npz")

def labeled_images():
    S = vision.SPR
    pd = open(os.path.join(vision.ROOT, "pose_data.gd"), encoding="utf-8").read()
    lay = set(re.findall(r'"id": "([^"]+)"', pd[pd.index("const LAYAN"):pd.index("const NORA")]))
    nor = set(re.findall(r'"id": "([^"]+)"', pd[pd.index("const NORA"):]))
    out = []
    for p in glob.glob(os.path.join(S, "layan", "*.png")) + glob.glob(os.path.join(S, "poses", "*.png")): out.append((p, "ليان"))
    for p in glob.glob(os.path.join(S, "nora_poses", "*.png")): out.append((p, "نورة"))
    for p in glob.glob(os.path.join(S, "idle", "*.png")):
        i = os.path.basename(p)[:-4]
        if i in lay: out.append((p, "ليان"))
        elif i in nor: out.append((p, "نورة"))
    for p in glob.glob(os.path.join(S, "full", "*.png")):
        b = os.path.basename(p)
        if b.startswith("hind"): out.append((p, "هند"))
        elif b.startswith("maysoon"): out.append((p, "ميسون"))
    for b, n in [("hind.png", "هند"), ("maysoon.png", "ميسون"), ("nora.png", "نورة"), ("sara.png", "سارة")]:
        if os.path.exists(os.path.join(S, b)): out.append((os.path.join(S, b), n))
    out += [(p, "الشبح") for p in glob.glob(os.path.join(S, "ghost", "*.png"))]
    return out

def features(im):
    """بصمة الصورة: الوجه (مع الشعر) + الجسم كامل"""
    fc = vision.crop_face(im)
    body = vision.embed_images([im])[0]
    face = vision.embed_images([fc])[0] if fc is not None else None
    return face, body

def build_refs(force=False):
    if os.path.exists(REFS) and not force:
        d = np.load(REFS, allow_pickle=True)
        return list(d["paths"]), list(d["names"]), d["face"], d["body"], d["has_face"]
    paths, names, F, B, HF = [], [], [], [], []
    for p, n in labeled_images():
        im = Image.open(p)
        f, b = features(im)
        paths.append(os.path.relpath(p, vision.SPR)); names.append(n); B.append(b)
        F.append(f if f is not None else np.zeros_like(b)); HF.append(f is not None)
    os.makedirs(os.path.dirname(REFS), exist_ok=True)
    np.savez(REFS, paths=np.array(paths), names=np.array(names), face=np.stack(F), body=np.stack(B), has_face=np.array(HF))
    return paths, names, np.stack(F), np.stack(B), np.array(HF)

def _x(face, body, has_face):
    f = face if has_face else body
    return np.concatenate([f * 0.7, body * 0.3])

_clf = None
def classifier(refs):
    """مصنف خطي على بصمات الصور (أدق من أقرب جار: ٩٥٪ في الاختبار)"""
    global _clf
    if _clf is None:
        from sklearn.linear_model import LogisticRegression
        paths, names, F, B, HF = refs
        X = np.stack([_x(F[i], B[i], HF[i]) for i in range(len(names))])
        _clf = LogisticRegression(C=100, max_iter=4000, class_weight="balanced").fit(X, names)
    return _clf

def identify(face, body, refs, k=3):
    """-> (الشخصية, نسبة التأكد, أقرب صور مشابهة)"""
    clf = classifier(refs)
    x = _x(face if face is not None else body, body, face is not None)
    pr = clf.predict_proba([x])[0]
    i = int(np.argmax(pr))
    paths, names, F, B, HF = refs
    sim = B @ body
    near = [(paths[j], names[j], round(float(sim[j]), 3)) for j in np.argsort(-sim)[:k]]
    return str(clf.classes_[i]), float(pr[i]), near
