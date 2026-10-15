#!/usr/bin/env python3
"""
يرسم صور اللعبة تلقائيًا عن طريق Cloudflare Workers AI (FLUX.2 Klein) ويركّبها مكانها.

- الطلبات مكتوبة في art/requests.json (اسم الصورة، مكانها في اللعبة، الوصف، الصور المرجعية).
- يشغّل فقط الطلبات المذكورة في "run" داخل الملف، أو في متغير البيئة ONLY (أسماء مفصولة بفاصلة).
- الصور المرجعية (مثل صورة ليان) تتصغّر لأقل من 512 بكسل وتنرسل مع الطلب علشان يحافظ على شكل الشخصية.
- الناتج يمر على نفس معالجة incoming/ (قص/مقاس للخلفيات، شيل الخلفية للشخصيات) مع نسخة احتياطية.
- نسخة خام من كل صورة تنحفظ في art/out/ للمراجعة، مع صورة مجمّعة art/out/sheet.jpg.

يحتاج: CF_ACCOUNT_ID و CF_API_TOKEN (أسرار في GitHub).
"""
import base64, io, json, os, sys, time
from pathlib import Path
import requests
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import process_incoming as pi  # noqa: E402

REQ = ROOT / "art" / "requests.json"
OUT = ROOT / "art" / "out"
MODELS = {"klein-4b": "@cf/black-forest-labs/flux-2-klein-4b", "klein-9b": "@cf/black-forest-labs/flux-2-klein-9b"}
SIZES = {"bg": (1920, 1072), "scene": (1920, 1072), "char": (896, 1600)}


def ref_bytes(path: str) -> bytes:
    im = Image.open(ROOT / path)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (225, 225, 225, 255))
        bg.alpha_composite(im)
        im = bg
    im = im.convert("RGB")
    im.thumbnail((500, 500), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, "PNG")
    return b.getvalue()


def call(model: str, prompt: str, refs: list, w: int, h: int, seed) -> Image.Image:
    acc, tok = os.environ["CF_ACCOUNT_ID"].strip(), os.environ["CF_API_TOKEN"].strip()
    url = f"https://api.cloudflare.com/client/v4/accounts/{acc}/ai/run/{MODELS.get(model, model)}"
    fields = {"prompt": (None, prompt), "width": (None, str(w)), "height": (None, str(h))}
    if seed is not None: fields["seed"] = (None, str(seed))
    for i, r in enumerate(refs[:4]):
        fields[f"input_image_{i}"] = (f"ref{i}.png", ref_bytes(r), "image/png")
    for attempt in range(3):
        r = requests.post(url, headers={"Authorization": f"Bearer {tok}"}, files=fields, timeout=180)
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(10 * (attempt + 1)); continue
        break
    ct = r.headers.get("content-type", "")
    if r.ok and ct.startswith("image/"):
        return Image.open(io.BytesIO(r.content))
    try:
        data = r.json()
    except Exception:
        raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
    if not r.ok or not data.get("success", True):
        errs = data.get("errors") or data
        raise RuntimeError(f"HTTP {r.status_code}: {json.dumps(errs, ensure_ascii=False)[:400]}")
    res = data.get("result", data)
    b64 = res.get("image") if isinstance(res, dict) else None
    if not b64:
        raise RuntimeError(f"ما رجعت صورة: {json.dumps(data, ensure_ascii=False)[:300]}")
    return Image.open(io.BytesIO(base64.b64decode(b64)))


_pipe = None
def local_call(model: str, prompt: str, refs: list, w: int, h: int, seed) -> Image.Image:
    """نفس النموذج (FLUX.2 Klein 4B مفتوح المصدر) يشتغل على معالج GitHub نفسه بدون أي حساب."""
    global _pipe
    import torch, gc
    from diffusers import Flux2KleinPipeline
    if _pipe is None:
        torch.set_num_threads(os.cpu_count() or 4)
        _pipe = Flux2KleinPipeline.from_pretrained("black-forest-labs/FLUX.2-klein-4B", torch_dtype=torch.bfloat16, low_cpu_mem_usage=True)
        gc.collect()
    # على المعالج نرسم بحوالي 1 ميغابكسل وبعدين يتكبر المقاس
    scale = min(1.0, (1024 * 1024 / float(w * h)) ** 0.5)
    lw, lh = int(w * scale) // 16 * 16, int(h * scale) // 16 * 16
    kw = dict(prompt=prompt, width=lw, height=lh, num_inference_steps=4, guidance_scale=1.0,
              generator=torch.Generator("cpu").manual_seed(int(seed if seed is not None else 7)))
    if refs:
        imgs = [Image.open(io.BytesIO(ref_bytes(r))).convert("RGB") for r in refs[:4]]
        kw["image"] = imgs if len(imgs) > 1 else imgs[0]
    t0 = time.time()
    with torch.inference_mode():
        out = _pipe(**kw).images[0]
    print(f"  رسم {lw}x{lh} في {time.time() - t0:.0f} ثانية", flush=True)
    return out


def main():
    spec = json.loads(REQ.read_text(encoding="utf-8"))
    only = [s.strip() for s in os.environ.get("ONLY", "").split(",") if s.strip()] or spec.get("run", [])
    jobs = [j for j in spec["jobs"] if j["name"] in only]
    if not jobs:
        print("ما فيه طلبات للتشغيل (run فاضي)."); print("::DONE=0"); return
    style = spec.get("style", {})
    named = spec.get("refs", {})
    backup = ROOT / "image_backups" / f"ai-{os.environ.get('GITHUB_RUN_ID', 'local')}"
    OUT.mkdir(parents=True, exist_ok=True)
    done, failed, thumbs = [], [], []
    for j in jobs:
        kind = j.get("kind", "bg")
        w, h = j.get("size", SIZES.get(kind, SIZES["bg"]))
        refs = [named.get(r, r) for r in j.get("refs", [])]
        prompt = j["prompt"].strip() + " " + style.get(kind, "")
        model = j.get("model", spec.get("model", "klein-4b"))
        print(f"[{j['name']}] {model} {w}x{h} refs={refs}")
        try:
            im = (local_call if os.environ.get("BACKEND") == "local" else call)(model, prompt, refs, w, h, j.get("seed"))
            raw = OUT / f"{j['name']}.png"
            im.save(raw)
            dst = ROOT / j["target"]
            notes = []
            if dst.exists():
                b = backup / j["target"]; b.parent.mkdir(parents=True, exist_ok=True); b.write_bytes(dst.read_bytes())
                notes.append("نسخة احتياطية محفوظة")
            dst.parent.mkdir(parents=True, exist_ok=True)
            img = pi.check_image(raw)
            (pi.process_bg if kind in ("bg", "scene") else pi.process_char)(img, dst, notes)
            if "assets/sprites/layan/" in j["target"]:
                # نسخة للخزانة والمتجر (اللعبة تقرأ layan_outfits بعد)
                dup = ROOT / j["target"].replace("sprites/layan", "layan_outfits")
                if dup.exists():
                    b = backup / dup.relative_to(ROOT); b.parent.mkdir(parents=True, exist_ok=True); b.write_bytes(dup.read_bytes())
                dup.parent.mkdir(parents=True, exist_ok=True)
                dup.write_bytes(dst.read_bytes())
            done.append((j["name"], j["target"], notes))
            t = im.convert("RGB"); t.thumbnail((480, 480)); thumbs.append((j["name"], t))
        except Exception as e:
            msg = str(e)
            failed.append((j["name"], msg))
            print(f"::warning title={j['name']}::{msg[:300]}")
            if "4006" in msg or "daily free allocation" in msg.lower() or "neurons" in msg.lower():
                print("::warning title=quota::خلص الرصيد المجاني لليوم، الباقي ينرسم بكرة."); break
    if thumbs:
        cols = 3; rows = (len(thumbs) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 490, rows * 510), (30, 30, 36))
        from PIL import ImageDraw
        d = ImageDraw.Draw(sheet)
        for i, (n, t) in enumerate(thumbs):
            x, y = (i % cols) * 490 + 5, (i // cols) * 510 + 5
            sheet.paste(t, (x, y + 20)); d.text((x, y + 2), n, fill=(255, 255, 255))
        sheet.save(OUT / "sheet.jpg", quality=88)
    lines = ["# صور مرسومة بالذكاء الاصطناعي", "", f"انرسمت **{len(done)}**، وفشلت **{len(failed)}**.", ""]
    if done:
        lines += ["| الاسم | المكان | ملاحظات |", "|---|---|---|"] + [f"| {n} | `{t}` | {' '.join(x)} |" for n, t, x in done] + [""]
    if failed:
        lines += ["## فشلت", "", "| الاسم | السبب |", "|---|---|"] + [f"| {n} | {m[:200]} |" for n, m in failed] + [""]
    (OUT / "REPORT-AR.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"::DONE={len(done)}")
    with open(os.environ.get("GITHUB_ENV", os.devnull), "a") as f:
        f.write(f"DONE={len(done)}\n")


if __name__ == "__main__":
    main()
