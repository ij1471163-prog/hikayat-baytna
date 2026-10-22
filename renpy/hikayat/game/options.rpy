## إعدادات اللعبة الأساسية
define config.name = "حكاية بيتنا"
define config.version = "0.1"
define build.name = "HikayatBaytna"
define config.save_directory = "HikayatBaytna-renpy"
define config.window_title = "حكاية بيتنا"

define config.screen_width = 1920
define config.screen_height = 1080

## العربي: من اليمين لليسار وتشكيل الحروف
define config.rtl = True

define config.has_sound = True
define config.has_music = True
define config.has_voice = False

define config.enter_transition = dissolve
define config.exit_transition = dissolve
define config.after_load_transition = dissolve
define config.end_game_transition = fade

define config.default_text_cps = 45
define config.default_afm_time = 15
define config.rollback_enabled = True

init python:
    build.classify("**~", None)
    build.classify("**.bak", None)
    build.classify("**/.**", None)
    build.classify("**/#**", None)
    build.classify("**/thumbs.db", None)
    build.archive("images", "all")
    build.classify("game/**.png", "images")
    build.classify("game/**.jpg", "images")
    build.documentation("*.txt")

define build.itch_project = ""
