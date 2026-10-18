# عيون الأداة: CLIP (يفهم وش في الصورة) + كشف الوجه (MediaPipe)
# الأوزان تنزل من GitHub أول مرة وتنحفظ في tools/world_link/.models (أو WL_MODELS)
import os, re, glob, json, urllib.request
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SPR = os.path.join(ROOT, "assets", "sprites")
MODELS = os.environ.get("WL_MODELS", os.path.join(HERE, ".models"))
CLIP_ARCH = "ViT-B-16-plus-240"
CLIP_FILE = "vit_b_16_plus_240-laion400m_e32-699c4b84.pt"
CLIP_URL = "https://github.com/mlfoundations/open_clip/releases/download/v0.2-weights/" + CLIP_FILE

_clip = None
def clip():
    global _clip
    if _clip is None:
        import open_clip, torch
        os.makedirs(MODELS, exist_ok=True)
        f = os.path.join(MODELS, CLIP_FILE)
        if not os.path.exists(f):
            print("downloading CLIP weights ...")
            urllib.request.urlretrieve(CLIP_URL, f + ".part"); os.rename(f + ".part", f)
        m, _, pre = open_clip.create_model_and_transforms(CLIP_ARCH, pretrained=f)
        m.eval()
        _clip = (m, pre, open_clip.get_tokenizer(CLIP_ARCH), torch)
    return _clip

def flat(im, bg=(255, 255, 255)):
    im = im.convert("RGBA")
    b = Image.new("RGB", im.size, bg); b.paste(im, (0, 0), im)
    return b

def embed_images(ims):
    m, pre, _, torch = clip()
    out = []
    with torch.no_grad():
        for i in range(0, len(ims), 16):
            x = torch.stack([pre(flat(im)) for im in ims[i:i + 16]])
            e = m.encode_image(x); e = e / e.norm(dim=-1, keepdim=True)
            out.append(e.numpy())
    return np.concatenate(out) if out else np.zeros((0, 640), np.float32)

_tcache = {}
def embed_texts(texts):
    key = tuple(texts)
    if key not in _tcache:
        m, _, tok, torch = clip()
        with torch.no_grad():
            e = m.encode_text(tok(list(texts))); e = e / e.norm(dim=-1, keepdim=True)
        _tcache[key] = e.numpy()
    return _tcache[key]

def zero_shot(img_emb, classes):
    """classes: {name: [prompt, ...]} -> {name: prob} (متوسط عدة جمل لكل فئة)"""
    names = list(classes)
    T = []
    for n in names:
        e = embed_texts(classes[n]).mean(0); T.append(e / np.linalg.norm(e))
    T = np.stack(T)
    lo = 100.0 * img_emb @ T.T
    p = np.exp(lo - lo.max()); p /= p.sum()
    return dict(zip(names, p.tolist()))

_fd = None
def face_box(im):
    """أكبر وجه: (x0,y0,x1,y1) يشمل الشعر، أو None"""
    global _fd
    import mediapipe as mp
    if _fd is None:
        _fd = mp.solutions.face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.3)
    W, H = im.size
    pad = int(max(W, H) * 0.1)
    b = Image.new("RGB", (W + 2 * pad, H + 2 * pad), (128, 128, 128)); b.paste(flat(im, (128, 128, 128)), (pad, pad))
    r = _fd.process(np.asarray(b))
    if not r.detections: return None
    d = max(r.detections, key=lambda d: d.location_data.relative_bounding_box.width)
    bb = d.location_data.relative_bounding_box
    x, y, w, h = bb.xmin * b.width - pad, bb.ymin * b.height - pad, bb.width * b.width, bb.height * b.height
    cx, cy, s = x + w / 2, y + h / 2, max(w, h)
    return (int(cx - s * 1.1), int(cy - s * 1.3), int(cx + s * 1.1), int(cy + s * 0.9))

def crop_face(im):
    fb = face_box(im)
    if fb is None: return None
    c = Image.new("RGBA", (fb[2] - fb[0], fb[3] - fb[1]), (0, 0, 0, 0))
    c.paste(im.convert("RGBA").crop(fb), (0, 0))
    return c
