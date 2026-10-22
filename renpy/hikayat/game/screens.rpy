## الواجهة: بسيطة وواضحة على الجوال، كلها بالعربي ومن اليمين لليسار

init offset = -2

define gui.accent = "#ff8fb1"
define gui.text_color = "#ffffff"
define gui.muted = "#d8c9d0"
define gui.panel = "#1b1418d9"

style default:
    font "fonts/Tajawal-Bold.ttf"
    size 38
    color gui.text_color
    shaper "harfbuzz"
    language "unicode"

style button_text:
    size 40
    color "#ffffff"
    hover_color gui.accent
    insensitive_color "#888888"
    text_align 0.5
    xalign 0.5

style button:
    padding (28, 14)

style frame:
    background Frame(Solid(gui.panel), 0, 0)
    padding (30, 24)

style bar:
    ysize 22
    left_bar Solid(gui.accent)
    right_bar Solid("#00000066")

## ===== الحوار =====
screen say(who, what):
    style_prefix "say"
    window:
        id "window"
        if who is not None:
            window:
                id "namebox"
                style "namebox"
                text who id "who" style "say_label"
        text what id "what" style "say_dialogue"
    use quick_menu

style window:
    xfill True
    yalign 1.0
    ysize 300
    background Frame(Solid("#120c10e6"), 0, 0)
    padding (90, 70, 90, 30)

style namebox:
    xalign 1.0
    yalign 0.0
    yoffset -60
    xoffset -40
    padding (34, 10)
    background Frame(Solid(gui.accent), 0, 0)

style say_label:
    size 40
    color "#2a0f1a"

style say_dialogue:
    xalign 1.0
    text_align 1.0
    size 44
    line_spacing 10

screen quick_menu():
    zorder 100
    if quick_menu:
        hbox:
            style_prefix "quick"
            xalign 0.0
            yalign 0.0
            spacing 10
            xoffset 20
            yoffset 16
            textbutton "رجوع" action Rollback()
            textbutton "تسريع" action Skip() alternate Skip(fast=True, confirm=True)
            textbutton "حفظ" action ShowMenu("save")
            textbutton "القائمة" action ShowMenu("load")

style quick_button:
    background Frame(Solid("#00000088"), 0, 0)
    padding (22, 10)
style quick_button_text:
    size 30

default quick_menu = True

## ===== الاختيارات =====
screen choice(items):
    style_prefix "choice"
    vbox:
        xalign 0.5
        yalign 0.42
        spacing 22
        for i in items:
            textbutton i.caption action i.action

style choice_button:
    xsize 1100
    xalign 0.5
    background Frame(Solid("#1b1418e6"), 0, 0)
    hover_background Frame(Solid("#5a2a3ae6"), 0, 0)
    padding (30, 22)
style choice_button_text:
    size 42

## ===== إدخال نص =====
screen input(prompt):
    style_prefix "input"
    window:
        vbox:
            xalign 1.0
            spacing 20
            text prompt xalign 1.0
            input id "input" xalign 1.0

## ===== القائمة الرئيسية =====
screen main_menu():
    tag menu
    add "bg living_room"
    add Solid("#00000077")
    vbox:
        xalign 0.5
        yalign 0.35
        spacing 10
        text "حكاية بيتنا" size 120 color gui.accent xalign 0.5
        text "قصة أسبوع مع ليان" size 44 color gui.muted xalign 0.5
    vbox:
        style_prefix "mm"
        xalign 0.5
        yalign 0.82
        spacing 16
        textbutton "ابدأ" action Start()
        textbutton "كمّل" action ShowMenu("load")
        textbutton "المعرض" action ShowMenu("gallery")
        textbutton "الإعدادات" action ShowMenu("preferences")

style mm_button:
    xsize 560
    xalign 0.5
    background Frame(Solid("#1b1418cc"), 0, 0)
    hover_background Frame(Solid("#5a2a3acc"), 0, 0)
    padding (20, 16)
style mm_button_text:
    size 48

## ===== قائمة اللعبة (حفظ / تحميل / إعدادات) =====
screen game_menu(title):
    add Solid("#0d090bf2")
    text title size 70 color gui.accent xalign 1.0 xoffset -80 yoffset 40
    hbox:
        xalign 0.0
        yalign 0.0
        xoffset 40
        yoffset 40
        spacing 16
        style_prefix "quick"
        textbutton "رجوع" action Return()
        if main_menu:
            textbutton "البداية" action MainMenu(confirm=False)
        else:
            textbutton "القائمة الرئيسية" action MainMenu()
        textbutton "حفظ" action ShowMenu("save")
        textbutton "تحميل" action ShowMenu("load")
        textbutton "الإعدادات" action ShowMenu("preferences")
    transclude

screen save():
    tag menu
    use file_slots("حفظ")

screen load():
    tag menu
    use file_slots("تحميل")

screen file_slots(title):
    use game_menu(title):
        grid 3 2:
            xalign 0.5
            yalign 0.62
            spacing 30
            for i in range(1, 7):
                button:
                    action FileAction(i)
                    xsize 520
                    ysize 360
                    background Frame(Solid("#2a1f25"), 0, 0)
                    hover_background Frame(Solid("#5a2a3a"), 0, 0)
                    vbox:
                        xalign 0.5
                        spacing 8
                        add FileScreenshot(i) xalign 0.5 xysize (480, 270)
                        text FileTime(i, format="%Y-%m-%d %H:%M", empty="خانة فاضية") size 28 xalign 0.5

screen preferences():
    tag menu
    use game_menu("الإعدادات"):
        vbox:
            xalign 0.5
            yalign 0.55
            spacing 30
            xsize 1200
            text "سرعة الكتابة" xalign 1.0
            bar value Preference("text speed")
            text "التقدم التلقائي" xalign 1.0
            bar value Preference("auto-forward time")
            text "الموسيقى" xalign 1.0
            bar value Preference("music volume")
            text "الأصوات" xalign 1.0
            bar value Preference("sound volume")
            hbox:
                xalign 1.0
                spacing 20
                textbutton "تسريع اللي ما قريته" action Preference("skip", "toggle")

screen confirm(message, yes_action, no_action):
    modal True
    zorder 200
    add Solid("#000000aa")
    frame:
        xalign 0.5
        yalign 0.5
        vbox:
            spacing 40
            text _(message) xalign 0.5 text_align 0.5
            hbox:
                xalign 0.5
                spacing 80
                textbutton "إيه" action yes_action
                textbutton "لا" action no_action

screen notify(message):
    zorder 150
    frame at notify_appear:
        xalign 0.5
        yalign 0.08
        text "[message!tq]" size 34
    timer 2.6 action Hide("notify")

transform notify_appear:
    on show:
        alpha 0
        linear .2 alpha 1.0
    on hide:
        linear .4 alpha 0.0

screen skip_indicator():
    zorder 100
    frame:
        xalign 0.5
        yalign 0.02
        text "تسريع..." size 30

## ===== المعرض =====
screen gallery():
    tag menu
    use game_menu("المعرض"):
        grid 3 2:
            xalign 0.5
            yalign 0.62
            spacing 30
            for cg in GALLERY:
                if cg in persistent.seen_cg:
                    imagebutton:
                        idle Transform("cg " + cg, xysize=(520, 292))
                        action Show("cg_view", cg=cg)
                else:
                    frame:
                        xsize 520
                        ysize 292
                        text "؟" size 90 xalign 0.5 yalign 0.5 color "#666"

screen cg_view(cg):
    modal True
    zorder 210
    add "cg " + cg
    button:
        xfill True
        yfill True
        background None
        action Hide("cg_view")
