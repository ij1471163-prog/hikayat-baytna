# مولّد صور حكاية بيتنا (يشتغل داخل GitHub Actions على المعالج بدون كرت شاشة)
# الاستخدام: python art/gen.py SHARD NSHARDS [ONLY]
# - inpaint: يرسم الملابس/الجسم فقط ويحافظ على وجه وشعر الشخصية الأصلي بكسل بكسل
# - txt2img: خلفيات جديدة
import json, os, sys, time
import torch
from PIL import Image, ImageOps
from diffusers import StableDiffusionInpaintPipeline, StableDiffusionPipeline, DPMSolverMultistepScheduler

shard, nshards = int(sys.argv[1]), int(sys.argv[2])
only = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else []
cfg = json.load(open("art/jobs.json", encoding="utf-8"))
jobs = [j for j in cfg["jobs"] if not only or j["name"] in only]
mine = [j for i, j in enumerate(jobs) if i % nshards == shard]
print(f"shard {shard}/{nshards}: {[j['name'] for j in mine]}", flush=True)
torch.set_num_threads(os.cpu_count() or 4)
os.makedirs("art_out", exist_ok=True)

MODELS = {"inpaint": "Lykon/dreamshaper-8-inpainting", "txt2img": "Lykon/dreamshaper-8"}
pipes = {}


def get(kind):
    if kind not in pipes:
        cls = StableDiffusionInpaintPipeline if kind == "inpaint" else StableDiffusionPipeline
        p = cls.from_pretrained(MODELS[kind], torch_dtype=torch.float32, safety_checker=None, requires_safety_checker=False)
        p.scheduler = DPMSolverMultistepScheduler.from_config(p.scheduler.config, use_karras_sigmas=True)
        p.set_progress_bar_config(disable=True)
        pipes[kind] = p
    return pipes[kind]


import traceback
def fail(e):
    open("err.txt", "w").write(traceback.format_exc()[-2500:])
    print("FAILED", e, flush=True)
    sys.exit(1)

steps = int(cfg.get("steps", 28))
gs = float(cfg.get("guidance", 6.5))
def run_all():
  for j in mine:
    style = cfg["style"][j.get("style", "char")]
    prompt = j["prompt"] + ", " + style
    for seed in j.get("seeds", [11, 22]):
        t0 = time.time()
        g = torch.Generator().manual_seed(seed)
        if j["type"] == "inpaint":
            init = Image.open(j["base"]).convert("RGB")
            mask = Image.open(j["mask"]).convert("L")
            out = get("inpaint")(prompt=prompt, negative_prompt=cfg["negative"], image=init, mask_image=mask,
                                 width=init.width, height=init.height, num_inference_steps=steps,
                                 guidance_scale=gs, strength=float(j.get("strength", 1.0)), generator=g).images[0]
            out = out.resize(init.size)
            # نرجع الوجه والشعر الأصلي كما هو بالضبط (المنطقة غير الممسوكة)
            out = Image.composite(out, init, mask)
        else:
            out = get("txt2img")(prompt=prompt, negative_prompt=cfg["negative"], width=int(j["width"]), height=int(j["height"]),
                                 num_inference_steps=steps, guidance_scale=gs, generator=g).images[0]
        out.save(f"art_out/{j['name']}_s{seed}.png")
        print(f"{j['name']} seed {seed}: {time.time() - t0:.0f}s", flush=True)
try:
    run_all()
except Exception as e:
    fail(e)
print("SHARD_DONE", flush=True)
