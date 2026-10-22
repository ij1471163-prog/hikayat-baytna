## وضع القرب: المس ليان. ضغطة = لمسة، ضغطة طويلة = تمسح أو تمسك (على الكمبيوتر: زر الفأرة اليمين)

default close_m = {"comfort": 0.15, "tickle": 0.0, "shy": 0.0, "annoy": 0.0}
default close_state = "calm"
default close_line = ""
default close_good = 0.0
default react_kind = ""
default react_t = 0.0

init python:
    import math, time

    CLOSE_NAMES = {"comfort": "ارتياح", "tickle": "دغدغة", "shy": "خجل", "annoy": "انزعاج"}
    CLOSE_COLORS = {"comfort": "#ff8fb1", "tickle": "#ffd75a", "shy": "#ff7070", "annoy": "#9a9ab0"}
    # تأثير الضغطة السريعة، والضغطة الطويلة (مسح/مسك)
    TAP = {
        "head": {"comfort": 0.10},
        "face": {"shy": 0.16, "comfort": 0.03},
        "shoulder": {"comfort": 0.08, "tickle": 0.04},
        "hand": {"comfort": 0.08, "shy": 0.06},
        "waist": {"tickle": 0.22, "shy": 0.04},
        "leg": {"shy": 0.10, "tickle": 0.06},
        "feet": {"tickle": 0.30},
    }
    HOLD = {
        "head": {"comfort": 0.26},
        "face": {"comfort": 0.12, "shy": 0.22},
        "shoulder": {"comfort": 0.24},
        "hand": {"comfort": 0.22, "shy": 0.08},
        "waist": {"tickle": 0.35, "shy": 0.10},
        "leg": {"shy": 0.22},
        "feet": {"tickle": 0.45},
    }
    DECAY = {"comfort": 0.012, "tickle": 0.12, "shy": 0.05, "annoy": 0.04}
    STATES = [("annoyed", "annoy", 0.5), ("laughing", "tickle", 0.55), ("shy", "shy", 0.5), ("melting", "comfort", 0.72), ("happy", "comfort", 0.35)]
    STATE_LINES = {
        "calm": ["هلا... وش فيك تطالعني كذا؟", "قرّب، ما أعض ههه"],
        "happy": ["أحب لما تكون قريب مني.", "هممم... حلو كذا.", "كمّل، لا توقف."],
        "melting": ["خلني كذا شوي... مرتاحة مرة.", "تعرف إنك أحلى شي صار لي؟"],
        "shy": ["بس! استحيت... ههه", "خلاص وجهي صار أحمر!"],
        "laughing": ["ههههه وقّف! وقّف!", "لاا... تعرف إني ما أتحمل! ههههه"],
        "annoyed": ["خلاص عاد! يكفي.", "بزعل منك ترا."],
    }
    # أماكن اللمس على جسمها (نسبة من صورتها): (المنطقة، x، y، عرض، طول)
    ZONES = [
        ("head", 0.30, 0.00, 0.40, 0.07),
        ("face", 0.33, 0.07, 0.34, 0.09),
        ("shoulder", 0.10, 0.17, 0.80, 0.08),
        ("hand", 0.00, 0.25, 0.22, 0.30),
        ("hand", 0.78, 0.25, 0.22, 0.30),
        ("waist", 0.24, 0.32, 0.52, 0.22),
        ("leg", 0.20, 0.55, 0.60, 0.33),
        ("feet", 0.15, 0.88, 0.70, 0.12),
    ]
    _taps = []

    def close_reset():
        store.close_m = {"comfort": 0.15, "tickle": 0.0, "shy": 0.0, "annoy": 0.0}
        store.close_state = "calm"
        store.close_good = 0.0
        store.close_line = renpy.random.choice(STATE_LINES["calm"])

    def close_add(eff, k=1.0):
        m = store.close_m
        for key, v in eff.items():
            m[key] = max(0.0, min(1.0, m[key] + v * k))
        if "annoy" in eff:
            m["comfort"] = max(0.0, m["comfort"] - eff["annoy"] * k * 1.2)
        if "comfort" in eff:
            m["annoy"] = max(0.0, m["annoy"] - eff["comfort"] * k * 0.3)

    def close_touch(zone, held):
        now = time.time()
        global _taps
        _taps = [t for t in _taps if now - t[0] < 1.2] + [(now, zone)]
        close_add((HOLD if held else TAP).get(zone, {}))
        # ضغطات كثيرة بسرعة على الوجه = إزعاج
        if not held and zone in ("face", "head") and sum(1 for t in _taps if t[1] == zone) >= 3:
            close_add({"annoy": 0.22})
        store.react_kind = zone if not held else "hold"
        store.react_t = now
        close_update(force_line=True)
        renpy.restart_interaction()

    def close_update(force_line=False):
        m = store.close_m
        ns = "calm"
        for s, key, lim in STATES:
            if s == store.close_state:
                lim -= 0.12
            if m[key] >= lim:
                ns = s
                break
        if ns != store.close_state or force_line and renpy.random.random() < 0.35:
            store.close_state = ns
            store.close_line = renpy.random.choice(STATE_LINES[ns])

    def close_tick():
        m = store.close_m
        for key in m:
            m[key] = max(0.0, m[key] - DECAY[key] * 0.1)
        if store.close_state in ("happy", "melting"):
            store.close_good += 0.1
        close_update()
        renpy.restart_interaction()

    # حركة جسمها: تتنفس طول الوقت، وتتحرك حسب اللمسة والحالة
    def close_tf(trans, st, at):
        t = time.time() - store.react_t
        k = store.react_kind
        rot = 0.0
        dx = 0.0
        dy = 0.0
        sq = 0.0
        s = store.close_state
        if s == "laughing":
            rot += 2.2 * math.sin(st * 22)
            dx += 6 * math.sin(st * 18)
        elif s == "melting":
            rot -= 2.5
        elif s == "shy":
            rot += 1.8
        elif s == "annoyed":
            rot += 3.0
            dx += 14
        if t < 1.4:
            e = math.exp(-t * 3.2)
            w = math.sin(t * 9)
            if k in ("head", "hold"):
                rot -= 3.5 * e
            elif k == "face":
                rot += 3.0 * e * w
            elif k in ("waist", "feet"):
                dx += 12 * e * w
                rot += 2.0 * e * w
            elif k == "shoulder":
                dy -= 10 * e
            else:
                sq = 0.015 * e * w
        trans.rotate = rot
        trans.xoffset = dx
        trans.yoffset = dy
        trans.yzoom = 1.0 + 0.006 * math.sin(st * 1.7) - sq
        trans.xzoom = 1.0 + sq * 0.5
        return 0

screen close_mode():
    modal True
    add Transform("bg living_room", blur=14)
    add Solid("#00000066")
    $ iw, ih = renpy.image_size("images/layan/%s.png" % layan_outfit)
    $ z = 1040.0 / ih
    $ W, H = int(iw * z), int(ih * z)
    fixed:
        xysize (W, H)
        xalign 0.5
        ypos 20
        add "layan":
            zoom z
            xanchor 0.5
            yanchor 1.0
            xpos W // 2
            ypos H
            at Transform(function=close_tf)
        for zone, zx, zy, zw, zh in ZONES:
            button:
                xpos int(zx * W)
                ypos int(zy * H)
                xysize (int(zw * W), int(zh * H))
                background None
                action Function(close_touch, zone, False)
                alternate Function(close_touch, zone, True)
    vbox:
        xpos 40
        ypos 40
        spacing 14
        for key in ["comfort", "tickle", "shy", "annoy"]:
            hbox:
                spacing 16
                bar value StaticValue(close_m[key], 1.0) xsize 340 left_bar Solid(CLOSE_COLORS[key])
                text CLOSE_NAMES[key] size 32
    frame:
        xalign 0.5
        yalign 0.97
        xmaximum 1400
        text "«[close_line]»" size 44 text_align 0.5
    textbutton "رجوع":
        xalign 1.0
        yalign 0.0
        xoffset -40
        yoffset 40
        background Frame(Solid("#1b1418cc"), 0, 0)
        action Return()
    timer 0.1 repeat True action Function(close_tick)

label close_mode:
    $ close_reset()
    call screen close_mode
    if close_m["annoy"] > 0.5:
        $ add_rel(-1)
    elif close_good > 8.0:
        $ add_rel(3)
    elif close_good > 3.0:
        $ add_rel(1)
    return

## ===== صور شاشة تلقائية للتجربة (GitHub Actions) =====
label autotest_shots:
    python:
        import os, traceback
        out = os.environ.get("HIKAYAT_SHOTS")
        class _It(object):
            def __init__(self, c):
                self.caption = c
                self.action = NullAction()
        def shot(name):
            renpy.pause(1.2, hard=True)
            renpy.screenshot(os.path.join(out, name + ".png"))
        def step(name, fn):
            try:
                fn()
                shot(name)
            except Exception:
                with open(os.path.join(out, "errors_" + name + ".txt"), "w") as f:
                    f.write(traceback.format_exc())
        def s1():
            renpy.show_screen("main_menu")
        step("01_main_menu", s1)
        renpy.hide_screen("main_menu")
        def s2():
            renpy.scene()
            renpy.show("bg living_room")
            renpy.show("layan", at_list=[layan_stand])
            renpy.show_screen("say", who="ليان", what="«تدري؟ أحب هالأمسيات... حتى لو ما سوينا شي.»")
        step("02_dialogue", s2)
        renpy.hide_screen("say")
        def s2b():
            renpy.show_screen("align_test")
        step("02b_align", s2b)
        renpy.hide_screen("align_test")
        def s3():
            renpy.show_screen("choice", items=[_It("تقرّب منها"), _It("اسألها عن يومها"), _It("اقترح عليها لبس"), _It("نام بدري")])
        step("03_choice", s3)
        renpy.hide_screen("choice")
        def s4():
            renpy.scene()
            renpy.show("cg tv_night")
            renpy.show_screen("say", who="ليان", what="«جيت؟ تعال، خليت لك مكان... والفشار بعده حار.»")
        step("04_cg", s4)
        renpy.hide_screen("say")
        def s5():
            renpy.scene()
            close_reset()
            close_touch("head", True)
            close_touch("head", True)
            close_touch("shoulder", True)
            renpy.show_screen("close_mode")
        step("05_close_happy", s5)
        def s6():
            close_touch("waist", True)
            close_touch("feet", True)
            close_touch("feet", False)
        step("06_close_laugh", s6)
        renpy.hide_screen("close_mode")
        def s7():
            renpy.show_screen("save")
        step("07_save", s7)
        renpy.hide_screen("save")
        def s8():
            store.layan_outfit = "06_floral_summer_dress"
            renpy.scene()
            renpy.show("bg layan_room")
            renpy.show("layan", at_list=[layan_stand])
        step("08_outfit", s8)
        renpy.quit()
    return

screen align_test():
    add Solid("#203040")
    vbox:
        xfill True
        spacing 40
        ypos 200
        text "text_align 1.0 xfill: «هذا سطر تجربة للمحاذاة»" xfill True text_align 1.0
        text "text_align 0.0 xfill: «هذا سطر تجربة للمحاذاة»" xfill True text_align 0.0
        text "xalign 1.0: «هذا سطر تجربة للمحاذاة»" xalign 1.0
