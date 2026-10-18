# يبني هيكل حي تلقائي لكل صورة من نتيجة كشف المفاصل (detect.py)
# المخرجات لكل صورة: <key>.json (عظام + شبكة + أوزان + وجه) و <key>_mask.png (أي بكسل للذراع)
import sys, json, os, struct, gzip, numpy as np
from PIL import Image
from scipy import ndimage

BONES = ["root", "spine", "chest", "head", "bun", "uarmL", "farmL", "uarmR", "farmR"]

def seg_dist(px, py, a, b):
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy + 1e-6
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / L2, 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))

def build(path, det, out_dir, key, root_dir):
    im = Image.open(os.path.join(root_dir, path)).convert("RGBA")
    W, H = im.size
    A = np.asarray(im.getchannel("A")) > 12
    q = {k: np.array(v[:2], float) for k, v in det["pose"].items()}
    vis = {k: v[2] for k, v in det["pose"].items()}
    need = ["nose", "shL", "shR", "hipL", "hipR", "elL", "elR", "wrL", "wrR"]
    if any(k not in q for k in need): return None, "missing joints"
    # الشاشة: نخلي L = يسار الشاشة دائماً
    if q["shL"][0] > q["shR"][0]:
        for a, b in [("shL", "shR"), ("elL", "elR"), ("wrL", "wrR"), ("hipL", "hipR"), ("knL", "knR"), ("anL", "anR")]:
            if a in q and b in q: q[a], q[b] = q[b], q[a]
    sh = (q["shL"] + q["shR"]) / 2
    hip = (q["hipL"] + q["hipR"]) / 2
    shw = abs(q["shR"][0] - q["shL"][0])
    torso = hip[1] - sh[1]
    # واقفة أو قاعدة مستقيمة فقط (المنسدحة ترجع للنسخة البسيطة)
    if torso < H * 0.12 or shw < W * 0.08 or abs(sh[0] - hip[0]) > torso * 0.5:
        return None, "not upright"
    hn = sh[1] - q["nose"][1]
    if hn < shw * 0.25: return None, "head?"
    neck = np.array([sh[0] + (q["nose"][0] - sh[0]) * 0.3, sh[1] - hn * 0.38])
    chest = np.array([sh[0] * 0.5 + hip[0] * 0.5, sh[1] + torso * 0.45])
    joints = {"root": hip, "spine": hip, "chest": chest, "head": neck,
              "bun": np.array([q["nose"][0], q["nose"][1] - hn * 1.1]),
              "uarmL": q["shL"], "farmL": q["elL"], "uarmR": q["shR"], "farmR": q["elR"]}
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    # ===== الذراعين: الحد بين الذراع والجسم في كل صف =====
    R = shw * 0.16
    lab = np.zeros((H, W), np.int16)
    lab[ys < hip[1]] = 1
    lab[ys < chest[1]] = 2
    head_y = neck[1] + hn * 0.12
    lab[ys < head_y] = 3
    lab[ys < joints["bun"][1]] = 4
    # خصلات الشعر النازلة على الكتف تتبع الصدر
    fw = shw * 0.36
    lab[(ys >= neck[1] - hn * 0.45) & (ys < head_y) & (np.abs(xs - q["nose"][0]) > fw)] = 2
    arm_free = {}
    for side, s, e, w in [("L", "shL", "elL", "wrL"), ("R", "shR", "elR", "wrR")]:
        S, E, Wr = q[s], q[e], q[w]
        hand = Wr + (Wr - E) * 0.75
        dist = np.minimum(seg_dist(xs, ys, S, E), seg_dist(xs, ys, E, Wr))
        dist = np.minimum(dist, seg_dist(xs, ys, Wr, hand) * 0.8)
        zone = A & (dist < R * 1.25) & (ys > S[1] + R * 0.2)
        # الذراع لازم تكون جهة الطرف (مو جهة منتصف الجسم) من خط الجسم
        tor_x = lambda y: np.interp(y, [sh[1], hip[1]], [q["sh" + side][0], q["hip" + side][0]])
        inset = shw * 0.10 * (1 if side == "L" else -1)
        rows = np.arange(int(S[1]), int(min(hand[1], H - 1)))
        gaps = 0; tot = 0
        bound = {}
        for y in rows:
            ax = np.interp(y, [S[1], E[1], hand[1]], [S[0], E[0], hand[0]])
            tx = tor_x(y) + inset
            row = A[y]
            lo, hi = (int(ax), int(tx)) if side == "L" else (int(tx), int(ax))
            lo = max(lo, 0); hi = min(hi, W - 1)
            b = (ax + tx) / 2
            if hi > lo:
                seg = row[lo:hi]
                empty = np.where(~seg)[0]
                if len(empty):
                    b = lo + empty.mean()
            # الصف "حر" لو فيه فراغ بين الذراع والجسم أو الذراع برا خط الجسم بوضوح
            if E[1] < y < Wr[1]:
                tot += 1
                if (hi > lo and (~row[lo:hi]).any()) or abs(ax - tx) > R * 1.6: gaps += 1
            bound[y] = b
        free = tot > 0 and gaps / tot > 0.7 and min(det["pose"]["wrL"][2], det["pose"]["wrR"][2], det["pose"]["elL"][2], det["pose"]["elR"][2]) > 0.4
        arm_free[side] = bool(free)
        if not free: continue
        by = np.array(sorted(bound)); bx = np.array([bound[y] for y in by])
        bxi = np.interp(ys, by, bx)
        outer = (xs < bxi) if side == "L" else (xs > bxi)
        arm = zone & outer & (ys >= by[0]) & (ys <= by[-1])
        arm = ndimage.binary_opening(arm, iterations=1)
        lb, n = ndimage.label(arm)
        if n:
            sizes = ndimage.sum(arm, lb, range(1, n + 1))
            arm = lb == (1 + int(np.argmax(sizes)))
        u, f = (5, 6) if side == "L" else (7, 8)
        lab[arm & (ys < E[1])] = u
        lab[arm & (ys >= E[1])] = f
    armL = np.isin(lab, [5, 6]); armR = np.isin(lab, [7, 8])
    armLd = ndimage.binary_dilation(armL, iterations=2) & A
    armRd = ndimage.binary_dilation(armR, iterations=2) & A
    # قناع الأجزاء: R = ذراع يسار، G = ذراع يمين (الجسم = الباقي)
    mask = np.zeros((H, W, 3), np.uint8)
    mask[..., 0] = armLd * 255; mask[..., 1] = armRd * 255; mask[..., 2] = (armL | armR) * 255
    Image.fromarray(mask).save(os.path.join(out_dir, key + "_mask.png"), optimize=True)
    parts_def = {"body": (A & ~np.isin(lab, [5, 6, 7, 8]), [0, 1, 2, 3, 4]),
                 "armL": (armLd, [2, 5, 6]), "armR": (armRd, [2, 7, 8])}
    s = max(2, H // 380)
    out_parts = {}
    for pname, (pm, allowed) in parts_def.items():
        if not pm.any(): continue
        pl = np.where(pm, lab, -1)
        if pname != "body":
            pl = np.where(pm & (ys < joints["uarm" + pname[-1]][1] + R * 0.9), 2, pl)
        small = pl[::s, ::s]
        sig = max(1.5, H / 1536 * 12 / s)
        wm = []
        for i in range(len(BONES)):
            if i not in allowed: wm.append(np.zeros(small.shape, np.float32)); continue
            wm.append(ndimage.gaussian_filter((small == i).astype(np.float32), sig * (0.8 if pname != "body" else 1.0)))
        wm = np.stack(wm, -1)
        inside = small >= 0
        _, (iy, ix) = ndimage.distance_transform_edt(~inside, return_indices=True)
        wm = wm[iy, ix]
        wm /= np.maximum(wm.sum(-1, keepdims=True), 1e-6)
        dil = ndimage.binary_dilation(pm, iterations=3)
        step = max(6, int(H / 95))
        fine_y = int(head_y) if pname == "body" else -1
        fs = max(3, step // 2)
        verts = []; vid = {}; tris = []
        def V(x, y):
            x, y = int(min(x, W)), int(min(y, H))
            if (x, y) not in vid:
                vid[(x, y)] = len(verts); verts.append((x, y))
            return vid[(x, y)]
        def has(x0, y0, x1, y1):
            return y0 < H and x0 < W and dil[y0:min(y1, H), x0:min(x1, W)].any()
        y = 0
        if fine_y > 0:
            fine_y = (fine_y // step) * step
            while y < fine_y:
                for x in range(0, W, fs):
                    if has(x, y, x + fs, y + fs):
                        a, b, c, d = V(x, y), V(x + fs, y), V(x + fs, y + fs), V(x, y + fs)
                        tris += [[a, b, c], [a, c, d]]
                y += fs
            # صف انتقال بدون شقوق
            y = fine_y
            for x in range(0, W, step):
                if not has(x, y, x + step, y + step): continue
                top = [V(x + k, y) for k in range(0, step + 1, fs)]
                if top[-1] != V(min(x + step, W), y): top.append(V(x + step, y))
                b0, b1 = V(x, y + step), V(x + step, y + step)
                for k in range(len(top) - 1):
                    tris.append([top[k], top[k + 1], b0 if k < (len(top) - 1) // 2 else b1])
                tris.append([top[(len(top) - 1) // 2], b1, b0])
            y += step
        while y < H:
            for x in range(0, W, step):
                if has(x, y, x + step, y + step):
                    a, b, c, d = V(x, y), V(x + step, y), V(x + step, y + step), V(x, y + step)
                    tris += [[a, b, c], [a, c, d]]
            y += step
        wts = np.array([wm[min(yy // s, wm.shape[0] - 1), min(xx // s, wm.shape[1] - 1)] for (xx, yy) in verts])
        out_parts[pname] = {"verts": np.array(verts, np.uint16), "tris": np.array(tris, np.uint16), "w": np.clip(np.round(wts * 255), 0, 255).astype(np.uint8)}
    # الوجه
    face = {}
    fd = det.get("face", {})
    if fd:
        P = {k: np.array(v) for k, v in fd.items()}
        ea = (P["eyeA_top"] + P["eyeA_bot"]) / 2; ea[0] = (P["eyeA_in"][0] + P["eyeA_out"][0]) / 2
        eb = (P["eyeB_top"] + P["eyeB_bot"]) / 2; eb[0] = (P["eyeB_in"][0] + P["eyeB_out"][0]) / 2
        if ea[0] > eb[0]:
            ea, eb = eb, ea
            ra = abs(P["eyeB_out"][0] - P["eyeB_in"][0]) / 2; rb = abs(P["eyeA_out"][0] - P["eyeA_in"][0]) / 2
            ha = abs(P["eyeB_bot"][1] - P["eyeB_top"][1]) / 2; hb = abs(P["eyeA_bot"][1] - P["eyeA_top"][1]) / 2
        else:
            ra = abs(P["eyeA_out"][0] - P["eyeA_in"][0]) / 2; rb = abs(P["eyeB_out"][0] - P["eyeB_in"][0]) / 2
            ha = abs(P["eyeA_bot"][1] - P["eyeA_top"][1]) / 2; hb = abs(P["eyeB_bot"][1] - P["eyeB_top"][1]) / 2
        ml, mr = P["mouthL"], P["mouthR"]
        if ml[0] > mr[0]: ml, mr = mr, ml
        ed = np.linalg.norm(eb - ea)
        # تأكد إن الوجه منطقي (العيون فوق الرقبة وقريبة من الأنف)
        ok_face = ed > W * 0.02 and 0.12 * shw < ed < 0.6 * shw and max(ea[1], eb[1]) < neck[1] and abs((ea[0] + eb[0]) / 2 - q["nose"][0]) < ed
        if ok_face:
            face = {"eyeA": ea.tolist(), "eyeB": eb.tolist(), "rA": [float(ra) * 1.15, float(max(ha * 1.3, ra * 0.55))],
                    "rB": [float(rb) * 1.15, float(max(hb * 1.3, rb * 0.55))],
                    "mL": ml.tolist(), "mR": mr.tolist(),
                    "chA": [ea[0] + 4 * ed / 61, ea[1] + (ml[1] - ea[1]) * 0.6], "chB": [eb[0], eb[1] + (mr[1] - eb[1]) * 0.6],
                    "center": P["center"].tolist(), "s": float(ed / 61.0)}
    figh = float(np.ptp(np.where(A.any(1))[0]))
    hdr = {"size": [W, H], "scale": figh / 1500.0, "joints": {k: [round(float(v[0]), 1), round(float(v[1]), 1)] for k, v in joints.items()},
           "arm_free": arm_free, "face": face, "mask": key + "_mask.png", "bones": BONES,
           "parts": [[n, int(p["verts"].shape[0]), int(p["tris"].shape[0])] for n, p in out_parts.items()]}
    hb = json.dumps(hdr, separators=(",", ":")).encode()
    blob = struct.pack("<I", len(hb)) + hb
    for n, p in out_parts.items():
        blob += p["verts"].tobytes() + p["tris"].tobytes() + p["w"].tobytes()
    open(os.path.join(out_dir, key + ".rig"), "wb").write(gzip.compress(blob, 9))
    # صورة تأكد
    pal = np.array([[90, 90, 90], [200, 120, 60], [230, 200, 60], [60, 180, 230], [230, 80, 200], [60, 200, 90], [30, 120, 50], [200, 60, 60], [120, 30, 30]], np.uint8)
    viz = pal[lab].copy(); viz[~A] = 40
    v = Image.fromarray(viz)
    # نخلط الصورة الأصلية مع الألوان عشان نشوف الوجه، ونرسم العيون والفم
    v = Image.blend(v.convert("RGB"), Image.alpha_composite(Image.new("RGBA", im.size, (40, 40, 40, 255)), im).convert("RGB"), 0.55)
    from PIL import ImageDraw
    dr = ImageDraw.Draw(v); rr = max(3, W // 120)
    if face:
        for k in ["eyeA", "eyeB", "mL", "mR"]:
            x0, y0 = face[k]; dr.ellipse([x0 - rr, y0 - rr, x0 + rr, y0 + rr], outline=(255, 0, 0), width=max(1, rr // 2))
    return v, "ok %s verts=%d" % (arm_free, sum(int(p["verts"].shape[0]) for p in out_parts.values()))

if __name__ == "__main__":
    det = json.load(open(sys.argv[1])); out_dir = sys.argv[2]; root_dir = sys.argv[3]
    os.makedirs(out_dir, exist_ok=True)
    tiles = []
    for path in sys.argv[4:]:
        key = path.replace("/", "__").replace(".png", "")
        v, msg = build(path, det[path], out_dir, key, root_dir)
        print(path, msg)
        if v is not None:
            tiles.append((path.split("/")[-1], v))
    if tiles:
        from PIL import ImageDraw
        cols, tw, th = 12, 150, 230
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tw, rows * th), (30, 30, 30))
        for i, (nm, t) in enumerate(tiles):
            t = t.copy(); t.thumbnail((tw, th - 14))
            x, y = (i % cols) * tw, (i // cols) * th
            sheet.paste(t, (x + (tw - t.width) // 2, y))
            ImageDraw.Draw(sheet).text((x + 2, y + th - 13), "%d %s" % (i, nm[:20]), fill=(255, 255, 0))
        sheet.save(os.path.join(out_dir, "_labels.png"))
