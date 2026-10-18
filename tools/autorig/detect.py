# كشف المفاصل والوجه تلقائياً لكل صورة شخصية
import sys, json, numpy as np, mediapipe as mp
from PIL import Image, ImageDraw
P = mp.solutions.pose; F = mp.solutions.face_mesh
NAMES = {0:"nose",2:"eyeL",5:"eyeR",11:"shL",12:"shR",13:"elL",14:"elR",15:"wrL",16:"wrR",23:"hipL",24:"hipR",25:"knL",26:"knR",27:"anL",28:"anR"}
def run(path):
    im = Image.open(path).convert("RGBA"); W, H = im.size
    pad = int(max(W, H) * 0.15)
    bg = Image.new("RGB", (W + 2 * pad, H + 2 * pad), (128, 128, 128)); bg.paste(im, (pad, pad), im)
    a = np.asarray(bg)
    out = {"size": [W, H], "pose": {}, "face": {}}
    with P.Pose(static_image_mode=True, model_complexity=1, min_detection_confidence=0.3) as pose:
        r = pose.process(a)
        if r.pose_landmarks:
            for i, n in NAMES.items():
                lm = r.pose_landmarks.landmark[i]
                out["pose"][n] = [lm.x * a.shape[1] - pad, lm.y * a.shape[0] - pad, round(lm.visibility, 2)]
    # الوجه: نقص منطقة الراس ونكبرها
    if "nose" in out["pose"]:
        nx, ny = out["pose"]["nose"][:2]
        hs = abs(out["pose"]["shL"][0] - out["pose"]["shR"][0]) * 0.9 if "shL" in out["pose"] else W * 0.25
        hs = max(hs, 40)
        box = (int(nx - hs), int(ny - hs), int(nx + hs), int(ny + hs))
        crop = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), (128, 128, 128))
        crop.paste(im.crop(box), (0, 0), im.crop(box))
        sc = 512 / crop.width; crop = crop.resize((512, 512))
        with F.FaceMesh(static_image_mode=True, refine_landmarks=True, min_detection_confidence=0.2) as fm:
            fr = fm.process(np.asarray(crop))
            if fr.multi_face_landmarks:
                L = fr.multi_face_landmarks[0].landmark
                def pt(i): return [box[0] + L[i].x * 512 / sc, box[1] + L[i].y * 512 / sc]
                # عين يسار الشاشة/يمينها: الجفن فوق وتحت، والفم
                out["face"] = {"eyeA_top": pt(159), "eyeA_bot": pt(145), "eyeA_in": pt(133), "eyeA_out": pt(33),
                               "eyeB_top": pt(386), "eyeB_bot": pt(374), "eyeB_in": pt(362), "eyeB_out": pt(263),
                               "mouthL": pt(61), "mouthR": pt(291), "mouthTop": pt(13), "mouthBot": pt(14), "center": pt(1)}
    return out, im
if __name__ == "__main__":
    res = {}; tiles = []
    for p in sys.argv[2:]:
        o, im = run(p); res[p] = o
        th = 420; s = th / im.height; t = Image.new("RGB", (max(int(im.width * s), 160), th), (70, 70, 70))
        t.paste(im.resize((int(im.width * s), th)), (0, 0), im.resize((int(im.width * s), th)))
        d = ImageDraw.Draw(t)
        q = o["pose"]
        for a_, b_ in [("shL","shR"),("shL","elL"),("elL","wrL"),("shR","elR"),("elR","wrR"),("shL","hipL"),("shR","hipR"),("hipL","hipR"),("hipL","knL"),("knL","anL"),("hipR","knR"),("knR","anR")]:
            if a_ in q and b_ in q: d.line([(q[a_][0]*s, q[a_][1]*s), (q[b_][0]*s, q[b_][1]*s)], fill=(0,255,0), width=2)
        for k, v in q.items(): d.ellipse([v[0]*s-3, v[1]*s-3, v[0]*s+3, v[1]*s+3], fill=(255,0,0) if v[2] > 0.5 else (255,200,0))
        for k, v in o["face"].items(): d.ellipse([v[0]*s-1.5, v[1]*s-1.5, v[0]*s+1.5, v[1]*s+1.5], fill=(0,200,255))
        d.text((3, 3), p.split("/")[-1][:22], fill=(255,255,255))
        tiles.append(t)
    json.dump(res, open(sys.argv[1], "w"))
    Wt = sum(t.width for t in tiles); sheet = Image.new("RGB", (Wt, 420)); x = 0
    for t in tiles: sheet.paste(t, (x, 0)); x += t.width
    sheet.save(sys.argv[1].replace(".json", ".png"))
    for p, o in res.items(): print(p.split("/")[-1], "pose" if o["pose"] else "NO-POSE", "face" if o["face"] else "no-face")
