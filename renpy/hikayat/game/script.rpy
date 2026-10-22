## حكاية بيتنا: أسبوع مع ليان (نسخة Ren'Py الأولى)

define l = Character("ليان", color="#2a0f1a", what_prefix="«", what_suffix="»")
define me = Character("أنت", color="#2a0f1a")
define n = Character(None, what_italic=False)

## ===== الصور =====
image bg living_room = "images/bg/living_room.jpg"
image bg kitchen = "images/bg/kitchen.jpg"
image bg bedroom = "images/bg/bedroom.jpg"
image bg layan_room = "images/bg/layan_room.jpg"
image cg tv_night = Transform("images/cg/tv_night.jpg", xysize=(1920, 1080))
image cg kitchen_chop = Transform("images/cg/kitchen_chop.jpg", xysize=(1920, 1080))
image cg kitchen_taste = Transform("images/cg/kitchen_taste.jpg", xysize=(1920, 1080))
image cg kitchen_finish = Transform("images/cg/kitchen_finish.jpg", xysize=(1920, 1080))
image cg hug = Transform("images/cg/hug.jpg", xysize=(1920, 1080))
image layan = DynamicImage("images/layan/[layan_outfit].png")

define GALLERY = ["tv_night", "kitchen_chop", "kitchen_taste", "kitchen_finish", "hug"]
default persistent.seen_cg = set()

## اللبسات المكتملة بس (كلها لها صور)
define OUTFITS = [
    ("01_pink_home_pajamas", "البيجامة الوردية"),
    ("02_white_sleepwear", "البيجامة البيضاء"),
    ("20_home_tank_shorts", "توب وشورت البيت"),
    ("03_casual_tshirt_jeans", "تيشيرت وجينز"),
    ("04_pink_blouse_black_trousers", "بلوزة وردية وبنطال"),
    ("08_beige_knit_outfit", "الطقم البيج المحبوك"),
    ("09_pink_tracksuit", "البدلة الرياضية الوردية"),
    ("12_home_apron", "مريول البيت"),
    ("06_floral_summer_dress", "الفستان الصيفي المزهر"),
    ("07_white_blouse_pleated_skirt", "البلوزة والتنورة"),
    ("05_red_evening_dress", "فستان السهرة الأحمر"),
    ("10_winter_coat_scarf", "المعطف الشتوي"),
    ("11_office_suit", "بدلة الدوام"),
]

## ===== الحالة =====
default layan_outfit = "01_pink_home_pajamas"
default rel = 50
default day = 1
default actions_left = 2
default talked_today = False
default close_today = False

## ليان واقفة وتتنفس بهدوء
transform layan_stand(x=0.5):
    xalign x
    yanchor 1.0
    ypos 1.06
    block:
        ease 1.9 yzoom 1.007 xzoom 0.997
        ease 1.9 yzoom 1.0 xzoom 1.0
        repeat

transform cg_in:
    alpha 0.0
    linear 0.6 alpha 1.0

init python:
    def see_cg(name):
        persistent.seen_cg.add(name)

    def add_rel(v):
        store.rel = max(0, min(100, store.rel + v))
        if v > 0:
            renpy.notify("ليان مبسوطة (+%d)" % v)
        elif v < 0:
            renpy.notify("ليان انزعجت (%d)" % v)

    DAY_NAMES = ["", "السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"]

label splashscreen:
    python:
        import os
        if os.environ.get("HIKAYAT_SHOTS"):
            renpy.jump("autotest_shots")
    return

label start:
    $ day = 1
    $ rel = 50
    $ layan_outfit = "01_pink_home_pajamas"
    scene black
    n "بعد سنة من الزواج... أسبوع عادي في بيتكم. أو هذا اللي كنت تحسبه."
    jump day_loop

## ===== حلقة الأيام =====
label day_loop:
    $ actions_left = 2
    $ talked_today = False
    $ close_today = False
    $ day_label = DAY_NAMES[day]
    scene black with fade
    show text "{size=90}اليوم [day]{/size}\n{size=50}[day_label]{/size}" at truecenter
    pause 1.4
    hide text
    $ renpy.call("day_%d" % day)
    if day >= 7:
        jump ending
    call free_time
    $ day += 1
    jump day_loop

## وقت حر بعد موقف اليوم: تختار وش تسوي
label free_time:
    while actions_left > 0:
        scene bg living_room with dissolve
        show layan at layan_stand
        menu:
            "وقتك مع ليان (باقي [actions_left])"
            "تقرّب منها" if not close_today:
                $ close_today = True
                call close_mode
            "اسألها عن يومها" if not talked_today:
                $ talked_today = True
                call small_talk
            "اقترح عليها لبس":
                call wardrobe
            "نام بدري":
                $ actions_left = 0
                return
        $ actions_left -= 1
    scene bg bedroom with fade
    n "اليوم خلص. تطفي النور وتسمع نفسها الهادي جنبك."
    return

label small_talk:
    $ i = renpy.random.randint(0, 3)
    if i == 0:
        l "اليوم كلمت أمي، تسلم عليك وتقول ليش ما تزورنا؟"
        menu:
            "«الجمعة الجاية إن شاء الله، وعد.»":
                l "صدق؟ بتنبسط مرة!"
                $ add_rel(3)
            "«مشغول هالفترة...»":
                l "دايماً مشغول... طيب."
                $ add_rel(-1)
    elif i == 1:
        l "تخيل، الجيران جابوا قطوة! أبي وحدة..."
        menu:
            "«نجيب وحدة، بس أنتِ تنظفين لها.»":
                l "اتفقنا! ههههه"
                $ add_rel(2)
            "«لا، تكفين، شعرها في كل مكان.»":
                l "ما عندك قلب."
    elif i == 2:
        l "قريت اليوم رواية، البطل فيها يشبهك شوي."
        me "أحلى ولا أوسم؟"
        l "لا تغتر... بس يمكن أوسم شوي. ههه"
        $ add_rel(2)
    else:
        l "تعبت اليوم من الترتيب... بس البيت صار يلمع."
        menu:
            "«ما قصرتي، الله يعطيك العافية.»":
                l "الله يعافيك... كلمة وحدة منك تكفي."
                $ add_rel(3)
            "«عادي، هذا شغل البيت.»":
                l "عادي؟... أوكي."
                $ add_rel(-2)
    return

label wardrobe:
    l "ها؟ وش تبيني ألبس؟"
    $ choices = [(name, oid) for oid, name in OUTFITS]
    $ picked = renpy.display_menu(choices)
    $ layan_outfit = picked
    show layan at layan_stand with dissolve
    l "كذا؟... شكلي حلو؟"
    menu:
        "«حلوة بكل شي.»":
            l "دايماً تعرف وش تقول. ههه"
            $ add_rel(1)
        "«يعني... كان الأول أحلى.»":
            l "كان قلت من البداية!"
    return

## ===== الأيام =====
label day_1:
    scene bg living_room with fade
    n "ترجع من الدوام متأخر. الصالة ريحتها فشار، وصوت فلم شغال."
    scene cg tv_night at cg_in
    $ see_cg("tv_night")
    l "جيت؟ تعال، خليت لك مكان... والفشار بعده حار."
    menu:
        "تقعد جنبها وتشاركها الفلم":
            l "هذا الفلم شفته مرتين، بس أبي أشوفه معك."
            $ add_rel(4)
        "«أنا تعبان، بروح أنام.»":
            l "اوه... طيب، تصبح على خير."
            $ add_rel(-3)
        "تاخذ من صحن الفشار بسرعة وتهرب":
            l "هيييه! حرامي! ههههه"
            $ add_rel(2)
    scene bg living_room with dissolve
    show layan at layan_stand
    l "تدري؟ أحب هالأمسيات... حتى لو ما سوينا شي."
    return

label day_2:
    $ layan_outfit = "12_home_apron"
    scene bg kitchen with fade
    n "تصحى على صوت سكين يقطع، وريحة بيض وطماط."
    scene cg kitchen_chop at cg_in
    $ see_cg("kitchen_chop")
    l "صباح الخير! قلت أسوي لك فطور قبل الدوام."
    menu:
        "«خليني أساعدك، أقطع البصل.»":
            l "البصل؟ بتبكي! ...طيب، تعال."
            n "بعد دقيقة عيونك تدمع، وهي تضحك عليك."
            $ add_rel(4)
        "«أسوي لنا قهوة؟»":
            l "إيه والله، ما في أحلى من قهوتك."
            $ add_rel(3)
        "تطالع جوالك وتنتظر الفطور":
            l "...الفطور جاهز بعد عشر دقايق."
            $ add_rel(-2)
    return

label day_3:
    $ layan_outfit = "12_home_apron"
    scene bg kitchen with fade
    n "بالليل، ليان جربت طبخة جديدة من مقطع شافته."
    scene cg kitchen_taste at cg_in
    $ see_cg("kitchen_taste")
    l "ذوق... بس قول الصدق. الصدق!"
    menu:
        "«لذيذة، بس تبي ملح شوي.»":
            l "صح! كنت حاسة إنها ناقصة شي. شكراً إنك صريح."
            $ add_rel(4)
        "«أحلى طبخة ذقتها بحياتي!»":
            l "كذاب... بس كذبة حلوة. ههه"
            $ add_rel(2)
        "«حارة مرة! ماء ماء!»":
            l "ههههه حطيت فلفل زيادة؟ آسفة!"
            $ add_rel(1)
    return

label day_4:
    $ layan_outfit = "02_white_sleepwear"
    scene bg layan_room with fade
    show layan at layan_stand
    l "بكرة عزيمة عند خالتي... ساعدني أختار وش ألبس."
    call wardrobe
    l "خلاص، هذا. ولو أحد سأل، أقول زوجي اختاره."
    $ add_rel(2)
    return

label day_5:
    $ layan_outfit = "20_home_tank_shorts"
    scene bg living_room with fade
    show layan at layan_stand
    n "ليان اليوم ساكتة، وتمسك رقبتها كل شوي."
    l "شغل البيت اليوم كان كثير... رقبتي وكتوفي تعبانة."
    menu:
        "«تعالي، أمسّج لك كتوفك.»":
            l "صدق؟... تكفى، بشويش."
            call close_mode
            l "الله... ارتحت. يدك فيها شي سحري."
            $ add_rel(4)
        "«ارتاحي، أنا أطلب عشا الليلة.»":
            l "أحسن فكرة سمعتها اليوم."
            $ add_rel(3)
        "«خذي بندول وارتاحي.»":
            l "...إيه، أكيد."
            $ add_rel(-1)
    return

label day_6:
    $ layan_outfit = "12_home_apron"
    scene bg kitchen with fade
    n "سويت لها مفاجأة: رجعت بدري وجبت أغراض طبختها المفضلة."
    scene cg kitchen_finish at cg_in
    $ see_cg("kitchen_finish")
    l "مين علّمك تسوي كذا؟... هذي طبختي المفضلة!"
    l "تعرف إن هالأسبوع كان حلو؟ حسيت إنك قريب مني."
    if rel >= 60:
        scene cg hug at cg_in
        $ see_cg("hug")
        n "تقرب منك وتسند راسها على كتفك، وتحس بيدك على كتفها."
        l "خلنا كذا شوي... بس شوي."
        $ add_rel(3)
    else:
        l "...بس أحياناً أحس إنك بعيد."
        menu:
            "«آسف، بحاول أكون أقرب.»":
                l "هذا كل اللي أبيه."
                $ add_rel(5)
            "«لا تكبرين السالفة.»":
                l "...طيب."
                $ add_rel(-3)
    return

label day_7:
    $ layan_outfit = "06_floral_summer_dress"
    scene bg living_room with fade
    show layan at layan_stand
    l "آخر يوم بالأسبوع... وش رايك نطلع نتمشى؟"
    return

## ===== النهايات =====
label ending:
    scene bg living_room with fade
    show layan at layan_stand
    if rel >= 75:
        l "تدري؟ هذا أحلى أسبوع من يوم تزوجنا."
        l "مو لأنه صار شي كبير... لأنك كنت معي، بكل التفاصيل الصغيرة."
        n "النهاية: «بيت دافي»"
    elif rel >= 50:
        l "كان أسبوع حلو... وأبي الجاي يكون أحلى."
        n "النهاية: «أيام عادية حلوة»"
    else:
        l "أحس إننا ساكنين مع بعض... بس كل واحد في عالمه."
        n "النهاية: «بيت هادي أكثر من اللازم»... ممكن تحاول من جديد."
    n "شكراً إنك لعبت. العلاقة النهائية: [rel]"
    return
