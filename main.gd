extends Control

# Keep Lian's approved reference artwork unchanged. Interaction is handled by dialogue choices.
var day := 1
var period := 0
var money := 600
var relationship := 50
var mood := "هادئة"
var outfit := "بيجامة وردية"
var owned_outfits := ["بيجامة وردية", "بيجامة بيضاء", "كاجوال تيشيرت وجينز", "بلوزة وردية وبنطال"]
var outfit_textures := {
 "بيجامة وردية": "res://assets/layan_outfits/01_pink_home_pajamas.png",
 "بيجامة بيضاء": "res://assets/layan_outfits/02_white_sleepwear.png",
 "كاجوال تيشيرت وجينز": "res://assets/layan_outfits/03_casual_tshirt_jeans.png",
 "بلوزة وردية وبنطال": "res://assets/layan_outfits/04_pink_blouse_black_trousers.png",
 "فستان سهرة أحمر": "res://assets/layan_outfits/05_red_evening_dress.png",
 "فستان صيفي مزهر": "res://assets/layan_outfits/06_floral_summer_dress.png",
 "بلوزة وتنورة": "res://assets/layan_outfits/07_white_blouse_pleated_skirt.png",
 "طقم محبوك بيج": "res://assets/layan_outfits/08_beige_knit_outfit.png",
 "بدلة رياضية وردية": "res://assets/layan_outfits/09_pink_tracksuit.png",
 "معطف شتوي": "res://assets/layan_outfits/10_winter_coat_scarf.png",
 "بدلة عمل": "res://assets/layan_outfits/11_office_suit.png",
 "مريول المنزل": "res://assets/layan_outfits/12_home_apron.png"
}
var laundry := 2
var energy := 90
var location := "المنزل"
var house_cleanliness := 75
var meals_prepared := 0
var shower_count := 0
var schedule_note := "بداية يوم هادئ في المنزل"
var character_relations := {"نورة":70, "سارة":55, "هند":40, "ميسون":35, "الشبح":0}
var daily_flags := {}
const StoryData = preload("res://story_data.gd")
var story_seen: Array = []
var weeks_done: Array = []
var weeks_checked: Array = []
var goal_start_day := 1
var events_done := 0
var story_ended := false
const WorldData = preload("res://world_data.gd")
var inventory: Dictionary = {}
var quest_state: Dictionary = {}
var quest_day: Dictionary = {}
var quest_meta: Dictionary = {}
var qflags: Array = []
var skill_pts: Dictionary = {"الطبخ": 0, "الكاريزما": 0, "التنظيم": 0, "اللياقة": 0}
var cards_col = null
var overlay: Control
var overlay_title: Label
var overlay_body: VBoxContainer
# Layan daily-life simulation meters (0..100).
var layan_hunger := 35
var layan_thirst := 25
var layan_tiredness := 20
var layan_activity := "تستريح في المنزل"
var bg: ColorRect
var status: Label
var loc_label: Label
var portrait: TextureRect
var steam_overlay: ColorRect
var steam_toggle: Button
var steam_visible := false
var activity_badge: Label
var portrait_base_position := Vector2.ZERO
var speaker: Label
var dialogue: Label
var choices: GridContainer
var note: Label
var periods := ["صباحًا", "ظهرًا", "مساءً", "ليلًا"]
var colors := {"المنزل":"#8c7465","المطبخ":"#a68b70","غرفة النوم":"#6f607b","غرفة الغسيل":"#627982","العمل":"#52667a","متجر الملابس":"#8b5d78","المقهى":"#88614b","الحديقة":"#537557","السوبرماركت":"#637254","الحمام":"#77939a","الشاطئ":"#c98b6b","غرفة الاسترخاء":"#806c78","الصالة":"#7b716a","غرفة نورة":"#667c80","الممر":"#8a8175","المدخل":"#897b69","غرفة التخزين":"#706d68"}

func _ready():
 load_prefs()
 build_ui()
 load_game()
 if not story_seen.has("intro"):
  show_intro()
 else:
  go(location)

var money_lbl: Label
var rel_bar: ProgressBar
var energy_bar: ProgressBar
var choice_scroll: ScrollContainer
var nav_overlay: Control
var backdrop: TextureRect
const GOLD := Color("#f1c08f")

func mk_style(col: Color, radius := 18, border := Color(1, 1, 1, 0.0), bw := 0) -> StyleBoxFlat:
 var st = StyleBoxFlat.new()
 st.bg_color = col
 st.set_corner_radius_all(radius)
 st.border_color = border
 st.set_border_width_all(bw)
 return st

func build_theme() -> Theme:
 var th = Theme.new()
 var f = load("res://assets/fonts/Tajawal-Medium.ttf")
 if f: th.default_font = f
 th.default_font_size = 24
 var n = mk_style(Color(0.17, 0.2, 0.28, 0.8), 18, Color(1, 1, 1, 0.14), 1)
 var h = mk_style(Color("#39466a"), 18, Color(1, 1, 1, 0.3), 1)
 var pr = mk_style(Color("#d08a5a"), 18)
 for st in [n, h, pr]:
  st.content_margin_left = 16
  st.content_margin_right = 16
  st.content_margin_top = 12
  st.content_margin_bottom = 12
 th.set_stylebox("normal", "Button", n)
 th.set_stylebox("hover", "Button", h)
 th.set_stylebox("pressed", "Button", pr)
 th.set_stylebox("focus", "Button", h)
 th.set_stylebox("disabled", "Button", n)
 th.set_color("font_color", "Button", Color("#f4f1ec"))
 th.set_color("font_hover_color", "Button", Color.WHITE)
 th.set_color("font_pressed_color", "Button", Color("#1b1b1b"))
 th.set_font_size("font_size", "Button", 23)
 th.set_font_size("font_size", "Label", 22)
 th.set_color("font_color", "Label", Color("#f4f1ec"))
 return th

func make_bar(color: Color) -> ProgressBar:
 var b = ProgressBar.new()
 b.min_value = 0
 b.max_value = 100
 b.show_percentage = false
 b.custom_minimum_size = Vector2(0, 14)
 b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 b.add_theme_stylebox_override("background", mk_style(Color(1, 1, 1, 0.15), 7))
 b.add_theme_stylebox_override("fill", mk_style(color, 7))
 return b

func make_stat(title: String, color: Color) -> Array:
 var box = HBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation", 8)
 var t = Label.new()
 t.text = title
 t.add_theme_font_size_override("font_size", 19)
 t.add_theme_color_override("font_color", Color("#d9cfc4"))
 box.add_child(t)
 var bar = make_bar(color)
 box.add_child(bar)
 return [box, bar]

const BG_FILES := {"المنزل":"living_room","المطبخ":"kitchen","الحمام":"bathroom","غرفة النوم":"bedroom","غرفة ليان":"layan_room","غرفة نورة":"nora_room","الصالة":"living_room","غرفة الاسترخاء":"relax_room","غرفة الغسيل":"laundry","متجر الملابس":"clothes_shop","الحديقة":"garden","العمل":"work","المقهى":"cafe","الشاطئ":"beach","النادي الرياضي":"gym","السوبرماركت":"supermarket","الممر":"entrance","المدخل":"entrance","غرفة التخزين":"entrance"}
const PERIOD_TINT := [Color(1, 1, 1), Color(1.0, 1.0, 0.96), Color(1.0, 0.8, 0.66), Color(0.5, 0.55, 0.85)]
const LAYAN_POSES := {"المطبخ":"cook_pan","غرفة الغسيل":"laundry","الصالة":"sofa_game","العمل":"work","النادي الرياضي":"gym","الشاطئ":"beach_hat","الحديقة":"beach_hat","السوبرماركت":"shopping","المقهى":"cup_pj","الحمام":"towel","غرفة النوم":"pillow_pj","غرفة ليان":"pj_cardigan","غرفة الاسترخاء":"towel"}
const NORA_POSES := {"المطبخ":"apron","غرفة الغسيل":"laundry","غرفة نورة":"pj1","الصالة":"mop","السوبرماركت":"grocery","المقهى":"cups","العمل":"work","الحمام":"towel"}
var pose_override := ""
var outfit_view := false
const WEEKDAYS := ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"]
var bg_tex: TextureRect
var sprites_layer: Control
var cg_frame: PanelContainer
var weekday_lbl: Label
var time_icons: Array = []
var sprite_focus: Array = []
var explore_mode := false
var sprite_nodes: Dictionary = {}

func hud_tex(name: String) -> Texture2D:
 var p := "res://assets/ui/%s.png" % name
 return load(p) if ResourceLoader.exists(p) else null

func hud_icon(name: String, sz := 40) -> TextureRect:
 var t = TextureRect.new()
 t.texture = hud_tex(name)
 t.custom_minimum_size = Vector2(sz, sz)
 t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 t.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return t

func hud_btn(name: String, cb: Callable, sz := 54) -> TextureButton:
 var b = TextureButton.new()
 b.texture_normal = hud_tex(name)
 b.ignore_texture_size = true
 b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
 b.custom_minimum_size = Vector2(sz, sz)
 b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 b.name = "Hud_" + name
 b.pressed.connect(cb)
 b.mouse_entered.connect(func(): b.modulate = Color(1.25, 1.2, 1.0))
 b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
 return b

func build_ui():
 theme = build_theme()
 layout_direction = Control.LAYOUT_DIRECTION_LTR
 bg = ColorRect.new()
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bg.color = Color("#2a2433")
 add_child(bg)
 bg_tex = TextureRect.new()
 bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(bg_tex)
 backdrop = bg_tex
 var grad = Gradient.new()
 grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.03, 0.02, 0.06, 0.55)])
 var gt = GradientTexture2D.new()
 gt.gradient = grad
 gt.fill_from = Vector2(0.5, 0.45)
 gt.fill_to = Vector2(0.5, 1)
 var shade = TextureRect.new()
 shade.texture = gt
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(shade)
 sprites_layer = Control.new()
 sprites_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 sprites_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(sprites_layer)
 cards_col = null

 # ---- CG frame (cooking / bath / TV / beach images)
 cg_frame = PanelContainer.new()
 cg_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 cg_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cg_frame.visible = false
 cg_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
 add_child(cg_frame)
 portrait = TextureRect.new()
 portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 portrait.stretch_mode = TextureRect.STRETCH_SCALE
 portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cg_frame.add_child(portrait)
 steam_overlay = ColorRect.new()
 steam_overlay.name = "BathSteamOverlay"
 steam_overlay.color = Color(0.88, 0.94, 0.96, 0.38)
 steam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 steam_overlay.visible = false
 cg_frame.add_child(steam_overlay)
 fx_layer = Control.new()
 fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fx_layer.clip_contents = true
 add_child(fx_layer)

 # ---- top HUD
 var top = PanelContainer.new()
 top.anchor_right = 1.0
 top.offset_left = 10
 top.offset_right = -10
 top.offset_top = 8
 top.offset_bottom = 70
 top.add_theme_stylebox_override("panel", mk_style(Color(0.07, 0.07, 0.12, 0.74), 16, Color(1, 1, 1, 0.14), 1))
 add_child(top)
 var tm = MarginContainer.new()
 for side in ["left", "right"]: tm.add_theme_constant_override("margin_" + side, 12)
 for side in ["top", "bottom"]: tm.add_theme_constant_override("margin_" + side, 4)
 top.add_child(tm)
 var hb = HBoxContainer.new()
 hb.add_theme_constant_override("separation", 16)
 tm.add_child(hb)
 hb.add_child(hud_btn("gear", open_profile))
 var wd = HBoxContainer.new()
 wd.add_theme_constant_override("separation", 6)
 wd.add_child(hud_icon("calendar", 34))
 weekday_lbl = Label.new()
 weekday_lbl.add_theme_font_size_override("font_size", 25)
 weekday_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 wd.add_child(weekday_lbl)
 hb.add_child(wd)
 var lc = HBoxContainer.new()
 lc.add_theme_constant_override("separation", 6)
 lc.add_child(hud_icon("pin", 34))
 loc_label = Label.new()
 loc_label.add_theme_font_size_override("font_size", 25)
 loc_label.add_theme_color_override("font_color", GOLD)
 loc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 lc.add_child(loc_label)
 hb.add_child(lc)
 var ti = HBoxContainer.new()
 ti.add_theme_constant_override("separation", 8)
 for i in 4:
  var ic = hud_icon("sunrise_off", 40)
  time_icons.append(ic)
  ti.add_child(ic)
 hb.add_child(ti)
 var sp = Control.new()
 sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 hb.add_child(sp)
 var mn = HBoxContainer.new()
 mn.add_theme_constant_override("separation", 6)
 mn.add_child(hud_icon("money", 34))
 money_lbl = Label.new()
 money_lbl.add_theme_font_size_override("font_size", 25)
 money_lbl.add_theme_color_override("font_color", Color("#ffe08a"))
 money_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 mn.add_child(money_lbl)
 hb.add_child(mn)
 hb.add_child(hud_btn("phone", open_quests))
 hb.add_child(hud_btn("bag", open_inventory))
 hb.add_child(hud_btn("map", func(): open_map("city")))

 # ---- second row: status + bars
 status = Label.new()
 status.anchor_left = 0.0
 status.anchor_right = 0.55
 status.offset_left = 16
 status.offset_top = 78
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status.add_theme_font_size_override("font_size", 17)
 status.add_theme_color_override("font_color", Color("#f1ebe3"))
 status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
 status.add_theme_constant_override("outline_size", 6)
 add_child(status)
 var bars = HBoxContainer.new()
 bars.anchor_left = 1.0
 bars.anchor_right = 1.0
 bars.offset_left = -400
 bars.offset_right = -16
 bars.offset_top = 82
 bars.add_theme_constant_override("separation", 14)
 add_child(bars)
 var s1 = make_stat("العلاقة", Color("#ff7aa8"))
 rel_bar = s1[1]
 bars.add_child(s1[0])
 var s2 = make_stat("الطاقة", Color("#6fc3ff"))
 energy_bar = s2[1]
 bars.add_child(s2[0])
 steam_toggle = Button.new()
 steam_toggle.name = "SteamToggleButton"
 steam_toggle.text = "إزالة البخار"
 steam_toggle.add_theme_font_size_override("font_size", 18)
 steam_toggle.anchor_left = 1.0
 steam_toggle.anchor_right = 1.0
 steam_toggle.offset_left = -190
 steam_toggle.offset_right = -16
 steam_toggle.offset_top = 112
 steam_toggle.offset_bottom = 156
 steam_toggle.visible = false
 steam_toggle.pressed.connect(toggle_steam)
 add_child(steam_toggle)
 activity_badge = Label.new()
 activity_badge.offset_left = 16
 activity_badge.offset_top = 128
 activity_badge.add_theme_font_size_override("font_size", 19)
 activity_badge.add_theme_color_override("font_color", Color("#fff1d7"))
 var pill = mk_style(Color(0.06, 0.07, 0.11, 0.78), 18, Color(1, 1, 1, 0.2), 1)
 pill.content_margin_left = 14
 pill.content_margin_right = 14
 pill.content_margin_top = 4
 pill.content_margin_bottom = 4
 activity_badge.add_theme_stylebox_override("normal", pill)
 activity_badge.text = "🏠 ليان في المنزل"
 add_child(activity_badge)

 # ---- choices column (left) + VN dialogue box (bottom)
 choice_scroll = ScrollContainer.new()
 choice_scroll.anchor_left = 0.015
 choice_scroll.anchor_right = 0.5
 choice_scroll.anchor_top = 0.21
 choice_scroll.anchor_bottom = 0.80
 choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 add_child(choice_scroll)
 choices = GridContainer.new()
 choices.columns = 1
 choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 choices.add_theme_constant_override("h_separation", 10)
 choices.add_theme_constant_override("v_separation", 8)
 choice_scroll.add_child(choices)
 var sheet = PanelContainer.new()
 sheet.anchor_left = 0.015
 sheet.anchor_right = 0.985
 sheet.anchor_top = 0.82
 sheet.anchor_bottom = 0.985
 var ss = mk_style(Color(0.05, 0.06, 0.1, 0.9), 18, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 2)
 sheet_style = ss
 sheet.add_theme_stylebox_override("panel", ss)
 add_child(sheet)
 var sm = MarginContainer.new()
 for side in ["left", "right"]: sm.add_theme_constant_override("margin_" + side, 22)
 sm.add_theme_constant_override("margin_top", 10)
 sm.add_theme_constant_override("margin_bottom", 10)
 sheet.add_child(sm)
 var col = VBoxContainer.new()
 col.add_theme_constant_override("separation", 4)
 sm.add_child(col)
 speaker = Label.new()
 speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 speaker.add_theme_font_size_override("font_size", 21)
 speaker.add_theme_color_override("font_color", GOLD)
 col.add_child(speaker)
 dialogue = Label.new()
 dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 dialogue.add_theme_font_size_override("font_size", 18)
 dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
 col.add_child(dialogue)
 note = Label.new()
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 note.add_theme_font_size_override("font_size", 14)
 note.add_theme_color_override("font_color", Color("#e7b98f"))
 col.add_child(note)
 var back = hud_btn("back", func(): go(location), 72)
 back.anchor_left = 1.0
 back.anchor_right = 1.0
 back.anchor_top = 0.75
 back.anchor_bottom = 0.75
 back.offset_left = -92
 back.offset_right = -20
 back.offset_top = -86
 back.offset_bottom = -14
 add_child(back)
 build_overlay()
 fade_rect = ColorRect.new()
 fade_rect.color = Color.BLACK
 fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fade_rect.modulate.a = 0.0
 add_child(fade_rect)
 set_process(false)

func build_overlay():
 overlay = Control.new()
 overlay.layout_direction = Control.LAYOUT_DIRECTION_RTL
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.visible = false
 add_child(overlay)
 var dim = ColorRect.new()
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 dim.color = Color(0, 0, 0, 0.78)
 overlay.add_child(dim)
 var pn = PanelContainer.new()
 pn.anchor_left = 0.08
 pn.anchor_right = 0.92
 pn.anchor_top = 0.04
 pn.anchor_bottom = 0.96
 pn.add_theme_stylebox_override("panel", mk_style(Color("#141927"), 30, Color(1, 1, 1, 0.22), 2))
 overlay.add_child(pn)
 var pm = MarginContainer.new()
 for side in ["left", "right", "top", "bottom"]: pm.add_theme_constant_override("margin_" + side, 18)
 pn.add_child(pm)
 var pv = VBoxContainer.new()
 pv.add_theme_constant_override("separation", 10)
 pm.add_child(pv)
 overlay_title = Label.new()
 overlay_title.add_theme_font_size_override("font_size", 34)
 overlay_title.add_theme_color_override("font_color", GOLD)
 pv.add_child(overlay_title)
 var sc = ScrollContainer.new()
 sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
 sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 pv.add_child(sc)
 overlay_body = VBoxContainer.new()
 overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 overlay_body.add_theme_constant_override("separation", 10)
 sc.add_child(overlay_body)
 var close = Button.new()
 close.text = "إغلاق"
 close.custom_minimum_size = Vector2(0, 64)
 close.pressed.connect(close_overlay)
 pv.add_child(close)

func _process(_delta):
 pass

func toggle_steam():
 steam_visible = not steam_visible
 if is_instance_valid(steam_overlay):
  steam_overlay.visible = steam_visible
 if is_instance_valid(steam_toggle):
  steam_toggle.text = "إزالة البخار" if steam_visible else "إظهار البخار"
 if is_instance_valid(note):
  note.text = "تمت إزالة طبقة البخار." if not steam_visible else "تم إظهار طبقة البخار."

func update_status():
 if not is_instance_valid(status): return
 var gday := clampi(day - goal_start_day + 1, 1, StoryData.GOAL_DAYS)
 status.text = "اليوم %d • %s • المزاج: %s • الزي: %s\nنظافة البيت %d%% • غسيل %d • هدف الشهر %d/%d" % [day, periods[period], mood, outfit, house_cleanliness, laundry, gday, StoryData.GOAL_DAYS]
 weekday_lbl.text = WEEKDAYS[(day - 1) % 7]
 var names := ["sunrise", "sun", "sunset", "moon"]
 for i in 4:
  time_icons[i].texture = hud_tex(names[i] + ("_on" if i == period else "_off"))
 bg_tex.modulate = PERIOD_TINT[period]
 money_lbl.text = str(money)
 rel_bar.value = relationship
 energy_bar.value = energy
 loc_label.text = location
 steam_toggle.visible = (location == "الحمام")
 if is_instance_valid(activity_badge):
  activity_badge.text = activity_emoji() + " " + layan_activity

func activity_emoji() -> String:
 if "تأكل" in layan_activity: return "🍽️"
 if "تشرب" in layan_activity: return "🥤"
 if "تطبخ" in layan_activity: return "🍳"
 if "جالسة" in layan_activity or "تستريح" in layan_activity: return "🛋️"
 if "نائمة" in layan_activity: return "💤"
 if "زوجها" in layan_activity: return "💬"
 return "🏠"

# Lightweight visual feedback for the selected action; this is not frame-by-frame character animation.
func show_layan_action(kind: String):
 if not is_instance_valid(portrait): return
 if is_instance_valid(activity_badge): activity_badge.text = kind
 var tgt: Control = portrait if cg_frame.visible else sprite_nodes.get("ليان", null)
 if tgt == null: return
 tgt.pivot_offset = Vector2(tgt.size.x / 2.0, tgt.size.y)
 var tw = create_tween()
 tw.tween_property(tgt, "scale", Vector2(1.03, 1.03), 0.18)
 tw.tween_property(tgt, "scale", Vector2.ONE, 0.22)

func clear_choices():
 for n in choices.get_children():
  choices.remove_child(n)
  n.queue_free()
 choices.columns = 1

func say(who, text):
 speaker.text = who
 dialogue.text = text
 clear_choices()
 explore_mode = false
 if is_instance_valid(choice_scroll): choice_scroll.scroll_vertical = 0

func choice(text, action: Callable):
 var b = Button.new()
 b.text = text
 b.custom_minimum_size = Vector2(0, 54)
 b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 b.add_theme_font_size_override("font_size", 20)
 b.pressed.connect(action)
 choices.add_child(b)
 choices.columns = 2 if choices.get_child_count() >= 6 else 1

func open_free_roam():
 save_game()
 get_tree().change_scene_to_file("res://free_roam.tscn")

func restore_outfit_portrait():
 clear_cg()

var cg_cache: Dictionary = {}
var sheet_style: StyleBoxFlat

# Builds a 16:9 widescreen image: blurred darkened fill + the sharp picture on the right side.
func wide_cg(tex: Texture2D) -> Texture2D:
 if tex == null: return null
 var key = tex.resource_path
 if key != "" and cg_cache.has(key): return cg_cache[key]
 var src: Image = tex.get_image()
 if src == null: return tex
 if src.is_compressed(): src.decompress()
 src.convert(Image.FORMAT_RGBA8)
 var W := 1280
 var H := 720
 var iw := src.get_width()
 var ih := src.get_height()
 if float(iw) / float(ih) >= 1.7:
  if key != "": cg_cache[key] = tex
  return tex
 var cw := iw
 var ch := int(iw * 9.0 / 16.0)
 if ch > ih:
  ch = ih
  cw = int(ih * 16.0 / 9.0)
 var fill: Image = src.get_region(Rect2i((iw - cw) / 2, (ih - ch) / 2, cw, ch))
 fill.resize(40, 22, Image.INTERPOLATE_BILINEAR)
 fill.resize(W, H, Image.INTERPOLATE_BILINEAR)
 var dark = Image.create(W, H, false, Image.FORMAT_RGBA8)
 dark.fill(Color(0, 0, 0, 0.5))
 fill.blend_rect(dark, Rect2i(0, 0, W, H), Vector2i.ZERO)
 var sc: float = min(660.0 / ih, 780.0 / iw)
 var sw := int(iw * sc)
 var sh := int(ih * sc)
 var sharp: Image = src.duplicate()
 sharp.resize(sw, sh, Image.INTERPOLATE_LANCZOS)
 var cx := 880
 var x0 := cx - sw / 2
 var y0 := 28
 var frame = Image.create(sw + 8, sh + 8, false, Image.FORMAT_RGBA8)
 frame.fill(Color(1, 1, 1, 0.55))
 fill.blend_rect(frame, Rect2i(0, 0, sw + 8, sh + 8), Vector2i(x0 - 4, y0 - 4))
 fill.blend_rect(sharp, Rect2i(0, 0, sw, sh), Vector2i(x0, y0))
 var out := ImageTexture.create_from_image(fill)
 if key != "": cg_cache[key] = out
 return out

func show_cg(tex):
 if not is_instance_valid(portrait): return
 portrait.texture = wide_cg(tex)
 current_cg_path = tex.resource_path if tex != null else ""
 cg_frame.visible = true
 sprites_layer.visible = false
 refresh_fx()

func clear_cg():
 if not is_instance_valid(cg_frame): return
 if sheet_style: sheet_style.bg_color.a = 0.9
 cg_frame.visible = false
 current_cg_path = ""
 sprites_layer.visible = true

func layan_sprite_path() -> String:
 if pose_override.begins_with("exercise/") or pose_override.begins_with("steam/"):
  return "res://assets/sprites/%s.png" % pose_override
 if pose_override != "":
  return "res://assets/sprites/poses/%s.png" % pose_override
 if not outfit_view and LAYAN_POSES.has(location):
  var pp := "res://assets/sprites/poses/%s.png" % LAYAN_POSES[location]
  if ResourceLoader.exists(pp): return pp
 var tp: String = str(outfit_textures.get(outfit, "res://assets/layan_outfits/01_pink_home_pajamas.png"))
 return tp.replace("layan_outfits", "sprites/layan")

func set_background(place):
 var n: String = str(BG_FILES.get(place, "city"))
 var ai := "res://assets/backgrounds_ai/%s.jpg" % n
 if ResourceLoader.exists(ai):
  bg_tex.texture = load(ai)
  return
 for ext in ["png", "jpg"]:
  var p := "res://assets/backgrounds/%s.%s" % [n, ext]
  if ResourceLoader.exists(p):
   bg_tex.texture = load(p)
   return
 bg_tex.texture = null

func show_pose(pose: String):
 pose_override = pose
 outfit_view = false
 explore_mode = false
 sprite_focus = ["ليان"]
 clear_cg()
 refresh_cards()

func fade_in():
 if not is_instance_valid(fade_rect): return
 fade_rect.modulate.a = 0.6
 var tw := create_tween()
 tw.tween_property(fade_rect, "modulate:a", 0.0, 0.32)

func go(place):
 fade_in()
 explore_mode = true
 pose_override = ""
 outfit_view = false
 sprite_focus = []
 _go_inner(place)
 if place in ["المطبخ", "الصالة", "غرفة النوم", "غرفة ليان"] and not layan_here(place) and is_instance_valid(note):
  note.text = "ليان مو هنا الحين؛ هي في %s." % str(npc_sched("ليان")[period])
 explore_mode = true
 refresh_cards()

func _go_inner(place):
 location = place
 if place == "المنزل" and check_scenes():
  return
 if place != "الحمام":
  restore_outfit_portrait()
  steam_visible = false
  if is_instance_valid(steam_overlay): steam_overlay.visible = false
  if is_instance_valid(steam_toggle): steam_toggle.text = "إظهار البخار"
 bg.color = Color(colors.get(place, "#8c7465"))
 set_background(place)
 update_status()
 match place:
  "المنزل":
   say("ليان — زوجتك", "أهلًا! تقدر تتفاعل معي، تختار ملابس، أو تدير شؤون البيت.")
   choice("تفاعل مع ليان", interact)
   choice("روتين ليان اليومي", layan_routine)
   choice("افتح خزانة الملابس", wardrobe)
   choice("رتب غرفة الجلوس", clean)
   choice("اطلب مساعدة نورة", helper)
   choice("الشخصيات والصداقات", character_hub)
   choice("اذهب إلى الحمام", func(): go("الحمام"))
   choice("غرفة نورة", func(): go("غرفة نورة"))
   choice("الممر والمدخل", func(): go("الممر"))
   choice("غرفة التخزين", func(): go("غرفة التخزين"))
   choice("جلسة مساج واسترخاء", func(): go("غرفة الاسترخاء"))
   choice("جدول اليوم والمهام", daily_schedule)
   choice("حفظ التقدم الآن", save_now)
   choice("اذهب إلى الصالة", func(): go("الصالة"))
  "الحمام":
   say("الحمام", "اختر روتينًا يوميًا بخصوصية وملابس مناسبة.")
   choice("فتح مشهد الاستحمام", bathing)
   choice("روتين الاستحمام الكامل (مشاهد البخار الجديدة)", func(): full_bath(0))
   choice("العناية بالبشرة (+5 مزاج)", skincare)
   choice("ارتداء ملابس بعد الاستحمام", wardrobe)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "غرفة الاسترخاء":
   say("غرفة الاسترخاء", "اختر جلسة مريحة مع ليان أو نورة. جميع الجلسات اختيارية وغير فاضحة.")
   choice("مساج استرخاء لليان (-20 ريال)", func(): massage("ليان", 20))
   choice("مساج كتفين لليان (-15 ريال)", func(): massage("ليان", 15))
   choice("نورة تساعد في تجهيز الغرفة (-10 ريال)", func(): massage_prep())
   choice("تمدد واسترخاء (+10 طاقة)", relax)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "الصالة":
   say("الصالة", "مكان للراحة والأنشطة المشتركة.")
   choice("ليان تجلس وتشاهد التلفزيون", layan_sit)
   choice("مشاهدة التلفزيون مع ليان (+3 علاقة)", tv_time)
   choice("قراءة كتاب (+8 طاقة)", read_book)
   choice("الجلوس مع نورة وليان", group_time)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "المطبخ":
   say("المطبخ", "اختر نشاطًا منزليًا.")
   choice("ليان تطبخ وجبة", layan_cook)
   choice("ليان تأكل وجبة", layan_eat)
   choice("ليان تشرب ماء", layan_drink)
   choice("جهّز الفطور مع ليان (+5 علاقة)", cook)
   choice("اغسل الصحون", dishes)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "غرفة النوم":
   say("غرفة النوم", "تقدر تتحدث مع ليان أو تختار ملابسها.")
   choice("تحدث مع ليان", interact)
   choice("روتين ليان اليومي", layan_routine)
   choice("افتح الخزانة", wardrobe)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "غرفة الغسيل":
   say("غرفة الغسيل", "حمولات الملابس المتراكمة: %d" % laundry)
   choice("شغّل الغسالة", do_laundry)
   choice("اطلب من نورة غسل الملابس", helper_laundry)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "المدخل":
   say("مدخل المنزل", "وصلت إلى مدخل البيت. تقدر تطلع للمواقع الخارجية أو ترجع للغرف.")
   choice("الخروج إلى الحديقة", func(): go("الحديقة"))
   choice("الذهاب إلى المقهى", func(): go("المقهى"))
   choice("الذهاب إلى السوبرماركت", func(): go("السوبرماركت"))
   choice("الذهاب إلى الشاطئ", func(): go("الشاطئ"))
   choice("العودة للمنزل", func(): go("المنزل"))
  "الممر":
   say("ممر المنزل", "من هنا تقدر تنتقل بين غرف البيت.")
   choice("غرفة النوم", func(): go("غرفة النوم"))
   choice("الصالة", func(): go("الصالة"))
   choice("المطبخ", func(): go("المطبخ"))
   choice("الحمام", func(): go("الحمام"))
   choice("غرفة نورة", func(): go("غرفة نورة"))
   choice("العودة للمنزل", func(): go("المنزل"))
  "غرفة نورة":
   say("غرفة نورة", "هذه غرفة نورة الخاصة. تقدر تطمئن عليها أو تتفقون على مهام البيت باحترام.")
   choice("التحدث مع نورة", func(): character_scene("نورة"))
   choice("التخطيط لمهام المنزل", helper)
   choice("دعوة نورة للصالة", group_time)
   choice("العودة للممر", func(): go("الممر"))
  "غرفة التخزين":
   say("غرفة التخزين", "مكان أدوات التنظيف ومستلزمات البيت.")
   choice("ترتيب أدوات التنظيف (+10% نظافة، -3 طاقة)", organize_storage)
   choice("العودة للممر", func(): go("الممر"))
  "العمل":
   say("مكان العمل", "أنجز مهمة اليوم لتحصل على راتب.")
   choice("أنجز المهمة (+120 ريال)", work_task)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "متجر الملابس":
   clothing_shop()
  "المقهى":
   say("المقهى", "مكان هادئ للخروج مع ليان.")
   choice("موعد مع ليان (-30 ريال، +7 علاقة)", date)
   choice("قهوة (-15 ريال، +5 طاقة)", coffee)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "الحديقة":
   say("الحديقة", "مكان مناسب للمشي وتغيير الجو.")
   choice("تمشّ مع ليان (+5 علاقة)", walk)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "غرفة ليان":
   say("غرفة ليان", "غرفتها الخاصة: خزانتها ومكان للراحة والعناية بنفسها.")
   choice("افتح خزانة الملابس", wardrobe)
   choice("العناية بالبشرة", skincare)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "النادي الرياضي":
   say("النادي الرياضي", "تمرين يرفع اللياقة. التعب يزيد لكن الصحة أفضل.")
   choice("تمرين (-15 طاقة، +اللياقة)", gym_workout)
   choice("جلسة يوغا مع ليان (-20 طاقة)", func(): yoga_step(0))
   choice("رجوع للمنزل", func(): go("المنزل"))
  "الشاطئ":
   scene_texture("04_beach_sunset.png")
   layan_activity = "تستمتع بالغروب على الشاطئ"
   update_status()
   say("الشاطئ", "غروب جميل على البحر. مكان مناسب لقضاء وقت هادئ مع ليان.")
   choice("يوم على الشاطئ مع ليان (-120 ريال، +8 علاقة)", beach_day)
   choice("تمشّ على الرمل (+3 علاقة)", beach_walk)
   choice("رجوع للمنزل", func(): go("المنزل"))
  "السوبرماركت":
   say("السوبرماركت", "اشترِ احتياجات المنزل أو أغراضًا للهدايا.")
   choice("تسوق أغراض وهدايا", open_shop)
   choice("مشتريات المنزل (-40 ريال)", groceries)
   choice("متجر الملابس", func(): go("متجر الملابس"))
   choice("رجوع للمنزل", func(): go("المنزل"))

func layan_routine():
 say("روتين ليان", "تقدر تختار نشاط ليان الآن. تتغير حاجتها للطعام والماء والراحة حسب النشاط.")
 choice("تأكل وجبة", layan_eat)
 choice("تطبخ في المطبخ", layan_cook)
 choice("تشرب ماء", layan_drink)
 choice("تجلس وتستريح", layan_sit)
 choice("تنام وتأخذ قسطًا من الراحة", layan_sleep)
 choice("تتفاعل مع الزوج", layan_interact)
 choice("العودة", func(): go(location))

func layan_eat():
 layan_hunger = maxi(0, layan_hunger - 35)
 layan_thirst = mini(100, layan_thirst + 5)
 layan_activity = "تأكل وجبة في المطبخ"
 kitchen_texture("11_taste.png")
 show_layan_action("🍽️ ليان تتناول وجبتها")
 mood = "راضية"
 note.text = "ليان أكلت وجبة، وانخفض شعورها بالجوع."
 say("ليان", "الأكل كان لذيذًا، الحين أحس أني أفضل.")
 update_status()
 choice("تشرب ماء", layan_drink)
 choice("ترجع لنشاطها", layan_routine)
 choice("العودة للمطبخ", func(): go("المطبخ"))

var cook_steps := [
 ["01_prep_ingredients.png","تحضير المكونات","طلعت كل المكونات على الطاولة ورتبتها."],
 ["02_wash_ingredients.png","غسل المكونات","تغسل الخضار بماء بارد."],
 ["03_chop_vegetables.png","تقطيع الخضروات","تقطّع الطماطم والخيار بهدوء."],
 ["04_prepare_meat.png","إعداد اللحم","تجهّز اللحم وتتبّله."],
 ["05_heat_pan.png","تسخين المقلاة","تشغل النار وتسخّن المقلاة."],
 ["06_fry_ingredients.png","قلي المكونات","تقلي المكونات والريحة تعبّي المطبخ."],
 ["07_add_spices.png","إضافة التوابل","تضيف التوابل بمقدار."],
 ["08_stir.png","التحريك","تحرك الطبخة وتتأكد إنها ما تلصق."],
 ["09_add_sauce.png","إضافة الصلصة","تسكب الصلصة على المكونات."],
 ["10_simmer.png","الطهي على نار هادئة","تخفف النار وتخليها تستوي."],
 ["11_taste.png","تذوق الطعام","تذوق وتعدل الملح."],
 ["12_set_plates.png","إعداد الأطباق","تجهّز الأطباق للتقديم."],
 ["13_serve.png","تقديم الطعام","تصب الأكل في الأطباق."],
 ["14_clean_kitchen.png","تنظيف المطبخ","تمسح الرخامة وتنظف الأدوات."],
 ["15_arrange_dishes.png","ترتيب الأواني","ترتب الأواني في غسالة الصحون."],
 ["16_finish.png","إنهاء العمل","الأكل جاهز، وليان مرتاحة ومبتسمة."]
]

var fade_rect: ColorRect = null
var fx_level := 2          # 0 = متوقفة، 1 = خفيفة، 2 = كاملة
var steam_density := 1     # 0 خفيف، 1 متوسط، 2 كثيف (يحجب الشخصية)
var fx_layer: Control = null
var _fog_tex: Texture2D = null
var _fx_key := ""
var current_cg_path := ""
var _shadow_tex: Texture2D = null
func shadow_texture() -> Texture2D:
 if _shadow_tex == null:
  var g := Gradient.new()
  g.set_color(0, Color(0, 0, 0, 0.5))
  g.set_color(1, Color(0, 0, 0, 0.0))
  var gt := GradientTexture2D.new()
  gt.gradient = g
  gt.fill = GradientTexture2D.FILL_RADIAL
  gt.fill_from = Vector2(0.5, 0.5)
  gt.fill_to = Vector2(1.0, 0.5)
  gt.width = 256
  gt.height = 64
  _shadow_tex = gt
 return _shadow_tex

func wide_path(path: String) -> String:
 var wp := "res://assets/wide/%s_%s.jpg" % [path.get_base_dir().get_file(), path.get_file().get_basename()]
 return wp if ResourceLoader.exists(wp) else path

func kitchen_texture(file_name: String):
 var path = wide_path("res://assets/kitchen/" + file_name)
 if ResourceLoader.exists(path):
  show_cg(load(path))

func layan_cook():
 if layan_tiredness >= 90:
  say("ليان", "أنا تعبانة جدًا، أحتاج أرتاح قبل ما أطبخ.")
  choice("ترتاح", layan_sit)
  choice("العودة", func(): go("المطبخ"))
  return
 layan_activity = "تطبخ وجبة في المطبخ"
 cook_step(0)

func cook_step(i: int):
 var st = cook_steps[i]
 kitchen_texture(st[0])
 layan_activity = "تطبخ: " + st[1]
 show_layan_action("🍳 " + st[1])
 note.text = "خطوة %d من %d — %s" % [i + 1, cook_steps.size(), st[1]]
 say("ليان", st[2])
 if i < cook_steps.size() - 1:
  choice("الخطوة التالية", func(): cook_step(i + 1))
  if i < 12:
   choice("تخطي إلى التقديم", func(): cook_step(12))
  choice("إيقاف الطبخ", func(): go("المطبخ"))
 else:
  finish_cooking()
 update_status()

func finish_cooking():
 layan_tiredness = mini(100, layan_tiredness + 12)
 layan_hunger = mini(100, layan_hunger + 5)
 daily_flags["layan_meal_ready"] = true
 meals_prepared += 1
 add_skill("الطبخ")
 give_item("وجبة جاهزة")
 if inventory.has("وصفة الجدة"): relationship = mini(100, relationship + 1)
 if story_seen.has("nora_80"): relationship = mini(100, relationship + 1)
 if story_seen.has("layan_70"): energy = mini(100, energy + 5)
 note.text = "ليان جهزت وجبة؛ صارت متوفرة للأكل."
 say("ليان", "جهزت الأكل! تعال ناكل قبل ما يبرد.")
 choice("ليان تأكل الوجبة", layan_eat)
 choice("اجلس معها", layan_sit)
 choice("العودة للمطبخ", func(): go("المطبخ"))

func layan_drink():
 layan_thirst = maxi(0, layan_thirst - 40)
 layan_activity = "تشرب الماء"
 show_layan_action("🥤 ليان تشرب الماء")
 mood = "منتعشة"
 note.text = "شربت ليان الماء وانخفض العطش."
 say("ليان", "شرب الماء ريّحني.")
 update_status()
 choice("روتين ليان", layan_routine)
 choice("العودة", func(): go(location))

func scene_texture(file_name: String):
 var path = wide_path("res://assets/scenes/" + file_name)
 if ResourceLoader.exists(path):
  show_cg(load(path))

func beach_day():
 if money < 120:
  note.text = "الرصيد لا يكفي لرحلة الشاطئ."
  return
 money -= 120
 relationship = mini(100, relationship + 8)
 energy = mini(100, energy + 10)
 mood = "مسترخية"
 layan_activity = "تستمتع بالغروب على الشاطئ"
 scene_texture("04_beach_sunset.png")
 note.text = "قضيتم يومًا حلوًا على الشاطئ وتحسنت علاقتكما."
 advance()

func beach_walk():
 relationship = mini(100, relationship + 3)
 energy = maxi(0, energy - 3)
 scene_texture("04_beach_sunset.png")
 note.text = "مشيتم على الرمل وتكلمتم عن أحلامكم."
 update_status()

func layan_sit():
 layan_activity = "جالسة تستريح في الصالة"
 scene_texture("03_living_room_tv.png")
 show_layan_action("🛋️ ليان تجلس وتسترخي")
 layan_tiredness = maxi(0, layan_tiredness - 18)
 mood = "مرتاحة"
 note.text = "جلست ليان قليلًا واستعادت بعض نشاطها."
 say("ليان", "خلنا نجلس شوي ونرتاح.")
 update_status()
 choice("تشاهد التلفزيون", tv_time)
 choice("تتحدث مع الزوج", layan_interact)
 choice("روتين ليان", layan_routine)
 choice("العودة للصالة", func(): go("الصالة"))

func layan_sleep():
 layan_activity = "نائمة في غرفة النوم"
 show_layan_action("💤 ليان نامت لترتاح")
 layan_tiredness = maxi(0, layan_tiredness - 55)
 layan_hunger = mini(100, layan_hunger + 12)
 layan_thirst = mini(100, layan_thirst + 10)
 period = (period + 1) % periods.size()
 if period == 0:
  day += 1
 mood = "مرتاحـة بعد النوم"
 note.text = "نامت ليان، وانخفض التعب. مرّ بعض الوقت داخل اللعبة."
 say("غرفة النوم", "ليان أخذت قسطًا من النوم. تقدر تصحيها بلطف أو تتركها ترتاح.")
 update_status()
 choice("تصحى وتبدأ يومها", layan_routine)
 choice("تحضير الفطور", func(): go("المطبخ"))
 choice("العودة للمنزل", func(): go("المنزل"))

func layan_interact():
 layan_activity = "تقضي وقتًا مع زوجها"
 show_layan_action("💬 ليان تتفاعل مع زوجها")
 relationship = mini(100, relationship + 2)
 layan_tiredness = mini(100, layan_tiredness + 2)
 note.text = "قضيت وقتًا مع ليان؛ تحسنت العلاقة قليلًا."
 say("ليان", "أحب لما نخصص وقت لبعض ونتكلم عن يومنا.")
 update_status()
 choice("حضن ودي", hug)
 choice("مسك اليد", hold_hand)
 choice("روتين ليان", layan_routine)
 choice("العودة", func(): go(location))

var bath_poses := [
 ["04_enjoy_warm_water.png","تستمتع بالماء الدافئ","بدأت ليان الاستحمام."],
 ["05_wash_hair.png","تغسل شعرها","ليان تغسل شعرها بالشامبو."],
 ["06_apply_shampoo.png","تضع الشامبو","وضعت ليان الشامبو."],
 ["10_rinse_hair.png","تشطف شعرها","انتهت من شطف الشعر."],
 ["08_relax_in_steam.png","تسترخي وسط البخار","أخذت ليان لحظة للاسترخاء."],
 ["13_sit_in_bathroom.png","تجلس لتستريح","جلست ليان قليلًا للراحة."],
 ["16_turn_off_water.png","تطفئ الماء","أطفأت ليان الماء."]
]
var bath_idx := 0

# الروتين الكامل: مشاهد قديمة (دخول، إغلاق الباب، تشغيل الماء) ثم مشاهد البخار الجديدة ثم المنشفة والخروج
const FULL_BATH := [
 ["old", "01_enter_bathroom.png", "تدخل ليان الحمام."],
 ["old", "02_close_door.png", "تغلق الباب خلفها."],
 ["old", "03_turn_on_water.png", "تشغّل الماء وتنتظر حتى يدفأ."],
 ["steam", "s01", "يملأ البخار المكان وتبدأ ليان الاستحمام."],
 ["steam", "s02", "تغمض عينيها وتستمتع بالماء الدافئ."],
 ["steam", "s03", "تغسل شعرها بهدوء."],
 ["steam", "s04", "ترفع ذراعيها وتمرر الماء على شعرها."],
 ["steam", "s05", "تميل برأسها وتغسل رقبتها."],
 ["steam", "s06", "تمسح كتفيها بحركات ناعمة."],
 ["steam", "s07", "تلتفت قليلًا وسط البخار."],
 ["steam", "s08", "تمد ذراعها وتغسلها."],
 ["steam", "s09", "ترفع يديها لشعرها وتشطفه."],
 ["old", "17_take_towel.png", "تأخذ المنشفة بعد انتهاء الاستحمام."],
 ["old", "18_exit_bathroom.png", "تخرج ليان من الحمام مرتاحة."]
]

func full_bath(i: int):
 location = "الحمام"
 var st: Array = FULL_BATH[i]
 if st[0] == "steam":
  steam_visible = true
  show_pose("steam/" + str(st[1]))
  if is_instance_valid(bg_tex): bg_tex.modulate = Color(0.6, 0.6, 0.66)
 else:
  pose_override = ""
  var p := wide_path("res://assets/bathing/" + str(st[1]))
  if ResourceLoader.exists(p): show_cg(load(p))
 layan_activity = "تستحم في الحمام"
 say("روتين ليان", str(st[2]))
 note.text = "استحمام %d/%d" % [i + 1, FULL_BATH.size()]
 if i < FULL_BATH.size() - 1:
  choice("التالي", func(): full_bath(i + 1))
  choice("كثافة البخار: " + steam_density_name(), func():
   cycle_steam_density()
   full_bath(i))
  choice("إنهاء الروتين", full_bath_end)
 else:
  choice("إنهاء الروتين", full_bath_end)
 update_status()

func full_bath_end():
 pose_override = ""
 finish_bathing()

func next_bath_pose():
 bath_idx = (bath_idx + 1) % bath_poses.size()
 var bp = bath_poses[bath_idx]
 bathing_pose(bp[0], bp[1], bp[2])

func bathing():
 bath_idx = 0
 # Bathroom routine scene: show one of the included, steam-covered reference panels.
 location = "الحمام"
 steam_visible = true
 if is_instance_valid(steam_overlay):
  steam_overlay.visible = true
  steam_overlay.color = Color(0.88, 0.94, 0.96, 0.58)
 if is_instance_valid(steam_toggle): steam_toggle.text = "إزالة البخار"
 layan_activity = "تستحم في الحمام"
 if ResourceLoader.exists(wide_path("res://assets/bathing/04_enjoy_warm_water.png")):
  show_cg(load(wide_path("res://assets/bathing/04_enjoy_warm_water.png")))
 note.text = "مشهد الاستحمام — البخار مفعّل. اختر وضعية أو تحكم بالبخار من الزر العلوي."
 say("روتين ليان", "اختر خطوة من روتين الاستحمام. البخار يغطي المشهد للمحافظة على الخصوصية.")
 choice("كثافة البخار: " + steam_density_name(), func():
  cycle_steam_density()
  bathing())
 choice("بدء الاستحمام", func(): bathing_pose("04_enjoy_warm_water.png", "تستمتع بالماء الدافئ", "بدأت ليان الاستحمام."))
 choice("غسل الشعر", func(): bathing_pose("05_wash_hair.png", "تغسل شعرها", "ليان تغسل شعرها بالشامبو."))
 choice("وضع الشامبو", func(): bathing_pose("06_apply_shampoo.png", "تضع الشامبو", "وضعت ليان الشامبو."))
 choice("الشطف بالماء", func(): bathing_pose("10_rinse_hair.png", "تشطف شعرها", "انتهت من شطف الشعر."))
 choice("الاسترخاء بالبخار", func(): bathing_pose("08_relax_in_steam.png", "تسترخي وسط البخار", "أخذت ليان لحظة للاسترخاء."))
 choice("الجلوس للراحة", func(): bathing_pose("13_sit_in_bathroom.png", "تجلس لتستريح", "جلست ليان قليلًا للراحة."))
 choice("إطفاء الماء", func(): bathing_pose("16_turn_off_water.png", "تطفئ الماء", "أطفأت ليان الماء."))
 choice("أخذ المنشفة", finish_bathing)
 choice("العودة للمنزل", func(): go("المنزل"))
 update_status()

func bathing_pose(file_name: String, activity: String, message: String):
 for i in bath_poses.size():
  if bath_poses[i][0] == file_name: bath_idx = i
 var path = wide_path("res://assets/bathing/" + file_name)
 if ResourceLoader.exists(path): show_cg(load(path))
 layan_activity = activity
 if is_instance_valid(steam_overlay): steam_overlay.visible = steam_visible
 note.text = message + (" البخار ظاهر." if steam_visible else " البخار مخفي.")
 say("ليان", message)
 choice("وضعية الاستحمام التالية", next_bath_pose)
 choice("أخذ المنشفة", finish_bathing)
 choice("العودة للحمام", func(): go("الحمام"))
 update_status()

func finish_bathing():
 shower_count += 1
 if ResourceLoader.exists(wide_path("res://assets/bathing/17_take_towel.png")):
  show_cg(load(wide_path("res://assets/bathing/17_take_towel.png")))
 steam_visible = false
 if is_instance_valid(steam_overlay): steam_overlay.visible = false
 if is_instance_valid(steam_toggle): steam_toggle.text = "إظهار البخار"
 energy = mini(100, energy + 10)
 mood = "منتعشة"
 layan_activity = "أنهت الاستحمام"
 note.text = "انتهى الاستحمام؛ أخذت ليان المنشفة."
 say("روتين يومي", "انتهى الاستحمام، وتستطيع الآن اختيار الملابس أو العودة للمنزل.")
 choice("اختيار ملابس", wardrobe)
 choice("العناية بالبشرة", skincare)
 choice("العودة للحمام", func(): go("الحمام"))
 choice("العودة للمنزل", func(): go("المنزل"))
 update_status()

func skincare():
 mood = "مرتاحة"
 energy = mini(100, energy + 5)
 note.text = "أنهيت روتين العناية بالبشرة."
 say("العناية الشخصية", "روتين بسيط يساعد على الاسترخاء والاستعداد لبقية اليوم.")
 choice("اختيار ملابس", wardrobe)
 choice("العودة", func(): go("الحمام"))
 update_status()

const MASSAGE_STEPS := ["تبدأ نورة بتدليك الكتفين بلطف.", "تضيف الزيت العطري على الظهر.", "حركات دائرية هادئة على الكتفين.", "تدليك طويل لعمود الظهر.", "تمدد الذراع وترخي العضلات.", "تدليك الرقبة وفروة الرأس.", "أحجار دافئة على الظهر.", "تدليك الساقين.", "تدليك القدمين.", "تدليك الرأس والاسترخاء.", "منشفة دافئة على الظهر.", "تنتهي الجلسة وتحس ليان براحة تامة."]

func massage(person: String, cost: int):
 if money < cost:
  note.text = "الرصيد لا يكفي لهذه الجلسة."
  return
 money -= cost
 update_status()
 if person == "ليان" and ResourceLoader.exists("res://assets/massage/01.jpg"):
  massage_step(person, 0)
 else:
  massage_done(person)

func massage_step(person: String, i: int):
 say("ليان" if i % 2 == 1 else "نورة", MASSAGE_STEPS[i])
 note.text = "جلسة مساج %d / %d" % [i + 1, MASSAGE_STEPS.size()]
 show_cg(load("res://assets/massage/%02d.jpg" % (i + 1)))
 if i < MASSAGE_STEPS.size() - 1:
  choice("التالي", func(): massage_step(person, i + 1))
  choice("تخطي", func(): massage_done(person))
 else:
  choice("إنهاء الجلسة", func(): massage_done(person))

func massage_done(person: String):
 energy = mini(100, energy + 12)
 mood = "مسترخية"
 if person == "ليان": relationship = mini(100, relationship + 4)
 note.text = "انتهت جلسة الاسترخاء لـ%s، وتحسنت الراحة والمزاج." % person
 say(person, "شكرًا، كانت جلسة استرخاء مريحة. هل تود اختيار نشاط آخر؟")
 if person == "ليان" and ResourceLoader.exists("res://assets/scenes/05_massage.jpg"): show_cg(load("res://assets/scenes/05_massage.jpg"))
 choice("جلسة أخرى", func(): go("غرفة الاسترخاء"))
 choice("الاستحمام", func(): go("الحمام"))
 choice("مشاهدة التلفزيون", func(): go("الصالة"))
 choice("العودة للمنزل", func(): go("المنزل"))
 update_status()

func massage_prep():
 if money < 10:
  note.text = "الرصيد لا يكفي."
  return
 money -= 10
 note.text = "جهزت نورة المناشف والزيوت العطرية ومكان الاسترخاء."
 say("نورة", "جهزت الغرفة. تقدر تختار جلسة استرخاء الآن.")
 choice("مساج لليان", func(): massage("ليان", 15))
 choice("استرخاء بدون مساج", relax)
 choice("رجوع", func(): go("غرفة الاسترخاء"))
 update_status()

func relax():
 energy = mini(100, energy + 10)
 mood = "مرتاحة"
 note.text = "أخذت استراحة قصيرة واستعدت بعض الطاقة."
 advance()

func tv_time():
 scene_texture("03_living_room_tv.png")
 relationship = mini(100, relationship + 3)
 energy = mini(100, energy + 4)
 note.text = "شاهدتما برنامجًا معًا وتحدثتما عنه."
 say("ليان", "حلو نقضي وقت هادئ مع بعض.")
 choice("تكلم عن البرنامج (+2 علاقة)", talk)
 choice("اذهب للمطبخ", func(): go("المطبخ"))
 choice("العودة", func(): go("الصالة"))
 update_status()

func read_book():
 energy = mini(100, energy + 8)
 mood = "هادئة"
 note.text = "قرأت قليلًا وأخذت استراحة."
 advance()

func group_time():
 character_relations["نورة"] = mini(100, int(character_relations.get("نورة", 70)) + 2)
 relationship = mini(100, relationship + 2)
 note.text = "قضيتم وقتًا لطيفًا في الصالة وتبادلتم الحديث."
 say("نورة وليان", "الوقت الجماعي يساعد على تقوية الصداقة والعلاقة.")
 choice("لعب لعبة جماعية", func(): character_action("نورة", 3, "لعبتم لعبة جماعية."))
 choice("العودة", func(): go("الصالة"))
 update_status()

func interact():
 say("ليان — زوجتك", "كيف كان يومك؟ اختر تفاعلًا لطيفًا.")
 choice("تحدث معها (+3 علاقة)", talk)
 choice("امسك يدها (+2 علاقة)", hold_hand)
 choice("عناق اختياري (+4 علاقة)", hug)
 choice("اسألها عن الملابس", wardrobe)
 choice("رجوع", func(): go("المنزل"))

func talk():
 relationship = mini(100, relationship + 3)
 mood = "سعيدة" if relationship >= 60 else "هادئة"
 say("ليان", "يسعدني نتكلم ونخطط ليومنا مع بعض.")
 choice("نروح متجر الملابس", func(): go("متجر الملابس"))
 choice("نطلع للمقهى", func(): go("المقهى"))
 choice("نرتب البيت", clean)
 choice("رجوع", func(): go("المنزل"))
 update_status()

func hold_hand():
 relationship = mini(100, relationship + 2)
 mood = "مبسوطة"
 note.text = "ليان ابتسمت وتفاعلت بود. (حركة مرسومة يمكن إضافتها لاحقًا)"
 say("ليان", "لحظة لطيفة بين الزوجين.")
 choice("رجوع", func(): go("المنزل"))
 update_status()

func hug():
 relationship = mini(100, relationship + 4)
 mood = "سعيدة"
 note.text = "اختيار تفاعل ودي. يحتاج مشهد مرسوم خاص للحركة."
 say("ليان", "ابتسمت ليان وتبادلت معك عناقًا لطيفًا.")
 choice("رجوع", func(): go("المنزل"))
 update_status()

func wardrobe():
 say("خزانة ليان", "الزي الحالي: %s. اختر زيًا تملكه." % outfit)
 for item in owned_outfits:
  choice("ارتداء: " + item, func(): wear(item))
 choice("اذهب لمتجر الملابس", func(): go("متجر الملابس"))
 choice("رجوع", func(): go("المنزل"))

func wear(item):
 outfit = item
 clear_cg()
 pose_override = ""
 outfit_view = true
 sprite_focus = ["ليان"]
 refresh_cards()
 note.text = "ليان ارتدت %s." % item
 update_status()
 wardrobe()

func clothing_shop():
 say("متجر الملابس", "اختر قطعة جديدة لخزانة ليان.")
 var catalog = [["فستان سهرة أحمر",160],["فستان صيفي مزهر",75],["بلوزة وتنورة",90],["طقم محبوك بيج",95],["بدلة رياضية وردية",90],["معطف شتوي",180],["بدلة عمل",130],["مريول المنزل",65]]
 for item in catalog:
  var name: String = item[0]
  var price: int = item[1]
  choice("%s — %d ريال" % [name, price], func(): buy_outfit(name, price))
 choice("افتح الخزانة", wardrobe)
 choice("رجوع للمنزل", func(): go("المنزل"))

func buy_outfit(name, price):
 if owned_outfits.has(name):
  note.text = "هذه القطعة موجودة في الخزانة."
  wardrobe()
  return
 if money < price:
  note.text = "الرصيد لا يكفي."
  return
 money -= price
 owned_outfits.append(name)
 outfit = name
 note.text = "اشتريت %s وأضفتها للخزانة." % name
 update_status()
 wardrobe()

func character_hub():
 say("الشخصيات", "اختر شخصية لزيارتها أو بدء حوار معها. لكل شخصية علاقة مستقلة تتغير مع اختياراتك.")
 choice("نورة — العاملة وصديقة ليان المقربة", func(): character_scene("نورة"))
 choice("سارة — صديقة ليان", func(): character_scene("سارة"))
 choice("هند — الجارة", func(): character_scene("هند"))
 choice("ميسون — صديقة من خارج الحي", func(): character_scene("ميسون"))
 choice("رجوع للمنزل", func(): go("المنزل"))

func character_scene(name: String):
 var relation: int = int(character_relations.get(name, 40))
 match name:
  "نورة":
   say("نورة", "أنا ونورة وليان صديقات مقربات. تقدر تتحدث معها أو تتعاونون في شؤون البيت.")
   choice("حديث ودي مع نورة (+3 علاقة)", func(): character_action(name, 3, "سولفت مع نورة وتكلمت عن يومها."))
   choice("خطط مع نورة وليان لنشاط منزلي (+4 علاقة)", func(): character_action(name, 4, "خططتم لنشاط منزلي جماعي."))
   choice("اطلب خدمة منزلية", helper)
  "سارة":
   say("سارة", "صديقة ليان. تحب القهوة والحديث عن الهوايات والعمل.")
   choice("تحدث عن الهوايات (+3 علاقة)", func(): character_action(name, 3, "تحدثتم عن الهوايات والخطط القادمة."))
   choice("ادعها للمقهى (-20 ريال، +5 علاقة)", func(): invite_character(name, 20, 5))
  "هند":
   say("هند", "جارتكم؛ علاقتكم تبدأ بالتعارف ويمكن أن تتحسن مع الوقت.")
   choice("رحب بها وتعرف عليها (+2 علاقة)", func(): character_action(name, 2, "تعارفتما بشكل ودي."))
   choice("اعرض المساعدة في حمل المشتريات (+3 علاقة، -5 طاقة)", func(): character_action(name, 3, "ساعدت هند في حمل مشترياتها."))
  "الشبح":
   say("سلمى", ["الليل أهدأ لما تجلس معي.", "أحياناً أنسى إني ما عدت من هذا العالم.", "البيت دافي... وهذا يكفيني."][randi() % 3])
   var gp := "res://assets/ghost/x0%d.jpg" % (2 + randi() % 8)
   if ResourceLoader.exists(gp):
    show_cg(load(gp))
    if sheet_style: sheet_style.bg_color.a = 0.6
   choice("سولف معها عن ماضيها (+4 علاقة)", func(): character_action(name, 4, "سلمى حكت لك ذكريات عن البيت القديم."))
   choice("اجلس معها بصمت (+2 علاقة)", func(): character_action(name, 2, "جلستم بهدوء تسمعون صوت الليل."))
  "ميسون":
   say("ميسون", "صديقة خارج الحي تحب الخروج والأنشطة الجديدة.")
   choice("اسألها عن يومها (+2 علاقة)", func(): character_action(name, 2, "تبادلتما أخبار اليوم."))
   choice("اقترح زيارة الحديقة (-10 ريال، +4 علاقة)", func(): invite_character(name, 10, 4))
 choice("رجوع", func(): go(location))
 update_status()

func character_action(name: String, amount: int, result_text: String):
 character_relations[name] = mini(100, int(character_relations.get(name, 40)) + amount)
 add_skill("الكاريزما")
 note.text = result_text
 update_status()
 if not check_scenes():
  character_scene(name)

func invite_character(name: String, cost: int, amount: int):
 if money < cost:
  note.text = "الرصيد لا يكفي."
  return
 money -= cost
 character_relations[name] = mini(100, int(character_relations.get(name, 40)) + amount)
 note.text = "قضيت وقتًا ممتعًا مع %s وتحسنت علاقتكما." % name
 advance()

func helper():
 say("نورة — مساعدة المنزل", "اختر خدمة منزلية.")
 choice("تنظيف غرفة الجلوس (-20 ريال)", func(): pay_helper(20, "نورة نظفت غرفة الجلوس."))
 choice("تنظيف المطبخ (-20 ريال)", func(): pay_helper(20, "نورة نظفت المطبخ."))
 choice("غسل الملابس (-25 ريال)", helper_laundry)
 choice("رجوع", func(): go("المنزل"))

func pay_helper(cost, text):
 if money < cost:
  note.text = "الرصيد لا يكفي."
  return
 money -= cost
 note.text = text
 update_status()
 go("المنزل")

func helper_laundry():
 if laundry <= 0:
  note.text = "ما فيه ملابس متراكمة."
  return
 if money < 25:
  note.text = "الرصيد لا يكفي."
  return
 money -= 25
 laundry -= 1
 note.text = "نورة غسلت حمولة ملابس."
 update_status()
 go("غرفة الغسيل")

func clean():
 energy = maxi(0, energy - 10)
 house_cleanliness = mini(100, house_cleanliness + 15)
 add_skill("التنظيم")
 update_status()
 go("المنزل")
 show_pose("mop")
 say("ليان", "ترتب الصالة وتمسح الأرض.")
 note.text = "رتبت غرفة الجلوس وتحسنت نظافة المنزل."
 choice("تمام", func(): go("المنزل"))

func cook():
 relationship = mini(100, relationship + 5)
 energy = maxi(0, energy - 6)
 note.text = "حضرتما الفطور معًا."
 advance()

func dishes():
 energy = maxi(0, energy - 5)
 add_skill("التنظيم")
 note.text = "غسلت الصحون."
 advance()

func do_laundry():
 if laundry <= 0:
  note.text = "كل الملابس نظيفة."
  return
 laundry -= 1
 energy = maxi(0, energy - 8)
 note.text = "خلص غسل حمولة ملابس."
 advance()

func work_task():
 money += 120
 energy = maxi(0, energy - 12)
 note.text = "حصلت على 120 ريالًا."
 advance()

func date():
 if money < 30:
  note.text = "الرصيد لا يكفي."
  return
 money -= 30
 relationship = mini(100, relationship + 7)
 note.text = "قضيت وقتًا جميلًا مع ليان."
 advance()

func coffee():
 if money < 15:
  note.text = "الرصيد لا يكفي."
  return
 money -= 15
 energy = mini(100, energy + 5)
 note.text = "استرحت قليلًا."
 advance()

func walk():
 relationship = mini(100, relationship + 5)
 energy = maxi(0, energy - 8)
 note.text = "تمشيتما معًا."
 advance()

func groceries():
 if money < 40:
  note.text = "الرصيد لا يكفي."
  return
 money -= 40
 note.text = "اشتريت احتياجات المنزل."
 advance()

func daily_schedule():
 var routine = "الصباح: فطور وترتيب بسيط. الظهر: طبخ أو تسوق. المساء: وقت عائلي. الليل: استرخاء ونوم."
 schedule_note = "الآن %s — %s" % [periods[period], routine]
 say("جدول اليوم", schedule_note)
 choice("هدف الشهر والمهمة الحالية", show_goal)
 choice("إنجاز مهمة منزلية", clean)
 choice("تحضير وجبة", cook)
 choice("قضاء وقت مع ليان", layan_interact)
 choice("النوم وتقدم الوقت", layan_sleep)
 choice("العودة للمنزل", func(): go("المنزل"))

func organize_storage():
 house_cleanliness = mini(100, house_cleanliness + 10)
 add_skill("التنظيم")
 energy = maxi(0, energy - 3)
 note.text = "رتبت أدوات التنظيف وصارت مستلزمات البيت أسهل للوصول."
 update_status()
 go("غرفة التخزين")

func save_now():
 save_game()
 note.text = "تم حفظ التقدم محليًا على الجهاز."
 say("حفظ اللعبة", "تم حفظ اليوم والوقت والمال والعلاقات والملابس واحتياجات ليان.")
 choice("متابعة اللعب", func(): go("المنزل"))

func household_overview():
 say("إدارة المنزل", "النظافة %d%%، الملابس المتراكمة %d، الوجبات التي جُهزت %d." % [house_cleanliness, laundry, meals_prepared])
 choice("تنظيف المنزل", clean)
 choice("غسل الملابس", func(): go("غرفة الغسيل"))
 choice("الطبخ", func(): go("المطبخ"))
 choice("العودة", func(): go("المنزل"))

func tick() -> bool:
 var new_day := false
 period += 1
 if period >= 4:
  new_day = true
  period = 0
  day += 1
  money += 80
  energy = mini(100, energy + 25)
  laundry += 1
  note.text = "بدأ يوم جديد وأضيف راتب تجريبي 80 ريالًا."
 # Layan's daily needs increase as time passes.
 layan_hunger = mini(100, layan_hunger + 8)
 layan_thirst = mini(100, layan_thirst + 7)
 layan_tiredness = mini(100, layan_tiredness + 6)
 if layan_hunger >= 75:
  layan_activity = "جائعة وتبحث عن وجبة"
 elif layan_thirst >= 75:
  layan_activity = "تحتاج إلى شرب الماء"
 elif layan_tiredness >= 80:
  layan_activity = "تحتاج إلى الراحة"
 save_game()
 update_status()
 return new_day

func advance():
 var nd := tick()
 if nd and story_after_day():
  return
 go("المنزل")

func wait_period():
 var nd := tick()
 if nd and story_after_day():
  return
 go(location)
 note.text = "مرّ بعض الوقت. الآن: " + periods[period]

# ================= العالم: خريطة، شخصيات، مهمات =================
func skill_level(name: String) -> int:
 return 1 + int(skill_pts.get(name, 0)) / 3

func add_skill(name: String, n := 1):
 skill_pts[name] = int(skill_pts.get(name, 0)) + n

const YOGA_STEPS := ["تبدأ ليان الإحماء على اليدين والركبتين.", "تمدد الظهر والوركين ببطء.", "تمد ساقها للأمام وتلمس قدمها.", "ترفع صدرها بهدوء وتتنفس بعمق.", "تلف جذعها لتمدد العمود الفقري.", "وضعية الطفل: تمد ذراعيها للأمام وترتاح.", "تتمدد على بطنها وترفع صدرها.", "وضعية الكلب المقلوب لتمدد الساقين.", "تمدد الساق للخلف مع التوازن على يد واحدة."]

func yoga_step(i: int):
 if i == 0 and energy < 20:
  note.text = "طاقتك ما تكفي لجلسة اليوغا."
  return
 show_pose("exercise/e%02d" % (i + 1))
 layan_activity = "تمارس اليوغا"
 say("ليان", YOGA_STEPS[i])
 note.text = "يوغا %d/%d" % [i + 1, YOGA_STEPS.size()]
 if i < YOGA_STEPS.size() - 1:
  choice("التمرين التالي", func(): yoga_step(i + 1))
  choice("إنهاء الجلسة", yoga_done)
 else:
  choice("إنهاء الجلسة", yoga_done)

func yoga_done():
 energy = maxi(0, energy - 20)
 add_skill("اللياقة")
 add_skill("اللياقة")
 relationship = mini(100, relationship + 2)
 mood = "نشيط"
 note.text = "جلسة يوغا ممتازة! اللياقة: %d، العلاقة +2" % skill_level("اللياقة")
 advance()

func gym_workout():
 if energy < 15:
  note.text = "طاقتك ما تكفي للتمرين."
  return
 energy -= 15
 add_skill("اللياقة")
 mood = "نشيط"
 note.text = "تمرين ممتاز! اللياقة: %d" % skill_level("اللياقة")
 advance()

func has_item(name: String) -> bool:
 return int(inventory.get(name, 0)) > 0

func give_item(name: String, n := 1):
 inventory[name] = int(inventory.get(name, 0)) + n

func take_item(name: String, n := 1) -> bool:
 if int(inventory.get(name, 0)) < n: return false
 inventory[name] = int(inventory[name]) - n
 if int(inventory[name]) <= 0: inventory.erase(name)
 return true

func has_flag(f: String) -> bool:
 return qflags.has(f)

func quest_by_id(qid: String) -> Dictionary:
 for q in WorldData.QUESTS:
  if q["id"] == qid: return q
 return {}

func cond_ok(c: Dictionary) -> bool:
 for k in c:
  var v = c[k]
  match k:
   "rel":
    if int(character_relations.get(v[0], 0)) < int(v[1]): return false
   "relationship":
    if relationship < int(v): return false
   "money":
    if money < int(v): return false
   "item":
    if not has_item(v): return false
   "skill":
    if skill_level(v[0]) < int(v[1]): return false
   "flag":
    if not has_flag(v): return false
   "period":
    if not (period in v): return false
   "day_min":
    if day < int(v): return false
   "meals_since":
    if meals_prepared - int(quest_meta.get(str(v[0]) + "_meals", meals_prepared)) < int(v[1]): return false
 # flag can also be an array of flags via "flags"
 return true

func step_ready(qid: String, st: Dictionary) -> bool:
 if not cond_ok(st.get("cond", {})): return false
 var w := int(st.get("wait", 0))
 if w > 0 and day < int(quest_day.get(qid, 0)) + w: return false
 return true

func find_quest_step(npc: String) -> Array:
 for q in WorldData.QUESTS:
  var idx := int(quest_state.get(q["id"], 0))
  if idx >= q["steps"].size(): continue
  var st: Dictionary = q["steps"][idx]
  if st["npc"] == npc and step_ready(q["id"], st):
   return [q["id"], st]
 return []

func is_weekend() -> bool:
 var wd := (day - 1) % 7
 return wd == 0 or wd == 6   # السبت والجمعة

func npc_sched(npc: String) -> Array:
 var d: Dictionary = WorldData.NPCS[npc]
 if is_weekend() and d.has("weekend"): return d["weekend"]
 return d["sched"]

func npc_present(npc: String, place: String) -> bool:
 if npc == "الشبح" and (day < 3 or has_flag("ghost_free")): return false
 return npc_sched(npc)[period] == place

# ليان: حاضرة في المنزل (الواجهة) وفي الحمام/الاسترخاء وفي الخروجات معها؛ وفي بقية غرف البيت حسب جدولها
func layan_here(place: String) -> bool:
 if place == "المنزل" or place == "الحمام" or place == "غرفة الاسترخاء": return true
 if not (place in WorldData.HOUSE_PLACES): return true
 return npc_sched("ليان")[period] == place

func npc_texture(npc: String):
 explore_mode = false
 sprite_focus = [npc]
 clear_cg()
 refresh_cards()

func sprite_path_for(npc: String) -> String:
 if npc == "ليان": return layan_sprite_path()
 if npc == "نورة":
  var nn: String = str(NORA_POSES.get(location, "maid"))
  var np := "res://assets/sprites/nora_poses/%s.png" % nn
  if ResourceLoader.exists(np): return np
 if npc == "الشبح":
  return "res://assets/sprites/ghost/body6.png" if int(quest_state.get("ghost", 0)) < 4 else "res://assets/sprites/ghost/body4.png"
 var p: String = str(WorldData.NPCS[npc]["img"]).replace("assets/npcs", "assets/sprites")
 var hd := "res://assets/sprites_hd/%s.png" % p.get_file().get_basename()
 if ResourceLoader.exists(hd): return hd
 return p

func refresh_cards():
 if not is_instance_valid(sprites_layer): return
 for c in sprites_layer.get_children():
  sprites_layer.remove_child(c)
  c.queue_free()
 sprite_nodes = {}
 var who: Array = []
 if not sprite_focus.is_empty():
  who = sprite_focus.duplicate()
 else:
  for npc in WorldData.NPCS:
   if (npc == "ليان" and layan_here(location)) or (npc != "ليان" and npc_present(npc, location)): who.append(npc)
 var centers := [[0.74], [0.80, 0.56], [0.82, 0.62, 0.44]]
 var cs: Array = centers[clampi(who.size(), 1, 3) - 1]
 var vh: float = get_viewport_rect().size.y
 var vw: float = get_viewport_rect().size.x
 for i in who.size():
  var npc: String = who[i]
  var path := sprite_path_for(npc)
  if not ResourceLoader.exists(path): continue
  var tex: Texture2D = load(path)
  var hf := 0.93 if npc == "ليان" else 0.70
  if sprite_focus.size() == 1 and npc != "ليان": hf = 0.78
  var h := vh * hf
  if "/exercise/" in path:
   h = minf(vh * 0.74, vw * 0.52 * float(tex.get_height()) / float(tex.get_width()))
  elif "/nora_poses/" in path: h = minf(vh * 0.97, vh * 0.9 * float(tex.get_height()) / 490.0)
  elif "/poses/" in path: h = minf(vh * 0.97, vh * 0.9 * float(tex.get_height()) / 395.0)
  var is_steam: bool = "/steam/" in path
  var full_body: bool = path.get_base_dir().get_file() != "sprites" and not is_steam
  var lift := 0.0
  if full_body:
   lift = vh * 0.175
   if not ("/exercise/" in path): h = minf(h * 0.775, vh * 0.72)
  if is_steam:
   h = minf(vh * 0.98, vw * 0.92 * float(tex.get_height()) / float(tex.get_width()))
  var w: float = h * float(tex.get_width()) / float(tex.get_height())
  if full_body:
   var sh := TextureRect.new()
   sh.texture = shadow_texture()
   sh.stretch_mode = TextureRect.STRETCH_SCALE
   sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
   sh.anchor_left = cs[i]
   sh.anchor_right = cs[i]
   sh.anchor_top = 1.0
   sh.anchor_bottom = 1.0
   sh.offset_left = -w * 0.5
   sh.offset_right = w * 0.5
   sh.offset_top = -lift - 26
   sh.offset_bottom = -lift + 26
   sprites_layer.add_child(sh)
  var b = TextureButton.new()
  b.texture_normal = tex
  b.ignore_texture_size = true
  b.stretch_mode = TextureButton.STRETCH_SCALE
  var cx_a: float = 0.56 if is_steam else cs[i]
  b.anchor_left = cx_a
  b.anchor_right = cx_a
  b.anchor_top = 1.0
  b.anchor_bottom = 1.0
  b.offset_left = -w / 2.0
  b.offset_right = w / 2.0
  b.offset_top = -h - lift
  b.offset_bottom = -lift
  b.name = "Sprite_" + str(i)
  b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  if explore_mode and sprite_focus.is_empty():
   b.mouse_entered.connect(func(): b.modulate = Color(1.18, 1.14, 1.08))
   b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
   b.pressed.connect(func(): talk_to(npc))
  else:
   b.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var tint: Color = Color.WHITE.lerp(PERIOD_TINT[period], 0.5)
  b.self_modulate = Color(tint.r, tint.g, tint.b, 0.82 if npc == "الشبح" else 1.0)
  sprites_layer.add_child(b)
  sprite_nodes[npc] = b
  animate_sprite(b, npc, path, w, h)
  if explore_mode and sprite_focus.is_empty() and not find_quest_step(npc).is_empty():
   var mk = Label.new()
   mk.text = "!"
   mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   mk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
   mk.add_theme_font_size_override("font_size", 30)
   mk.add_theme_color_override("font_color", Color("#1b1b1b"))
   mk.add_theme_stylebox_override("normal", mk_style(Color("#ffd34d"), 22, Color.WHITE, 2))
   mk.anchor_left = 0.5
   mk.anchor_right = 0.5
   mk.offset_left = -22
   mk.offset_right = 22
   mk.offset_top = 6
   mk.offset_bottom = 50
   mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
   b.add_child(mk)
 refresh_fx()

# ================= الحركة والمؤثرات =================
func load_prefs():
 var cf := ConfigFile.new()
 if cf.load("user://prefs.cfg") == OK:
  fx_level = clampi(int(cf.get_value("fx", "level", 2)), 0, 2)
  steam_density = clampi(int(cf.get_value("fx", "steam", 1)), 0, 2)

func save_prefs():
 var cf := ConfigFile.new()
 cf.set_value("fx", "level", fx_level)
 cf.set_value("fx", "steam", steam_density)
 cf.save("user://prefs.cfg")

func fx_level_name() -> String:
 return ["متوقفة", "خفيفة", "كاملة"][fx_level]

func cycle_fx_level():
 fx_level = (fx_level + 2) % 3 if fx_level == 0 else fx_level - 1
 save_prefs()
 _fx_key = ""
 refresh_fx()
 refresh_cards()

func motion_profile(npc: String, path: String) -> Dictionary:
 # amp: تمدد التنفس (x,y) ، per: مدة الدورة، sway: ميل بالدرجات ، sper: مدة التمايل ، pulse: نبض الشفافية
 var file := path.get_file().get_basename()
 if npc == "الشبح": return {"ax": 0.010, "ay": 0.020, "per": 4.4, "sway": 1.0, "sper": 5.8, "pulse": 0.10}
 if "/steam/" in path: return {"ax": 0.018, "ay": 0.018, "per": 7.0, "sway": 0.0, "sper": 1.0, "pulse": 0.0}
 if "/exercise/" in path: return {"ax": 0.005, "ay": 0.012, "per": 3.8, "sway": 0.0, "sper": 1.0, "pulse": 0.0}
 if file in ["cook_pan", "laundry", "work", "shopping", "mop", "apron", "grocery", "cups"]:
  return {"ax": 0.004, "ay": 0.008, "per": 3.0, "sway": 0.7, "sper": 2.4, "pulse": 0.0}
 if file in ["gym", "beach_hat"]:
  return {"ax": 0.006, "ay": 0.012, "per": 2.8, "sway": 0.8, "sper": 3.0, "pulse": 0.0}
 if file in ["sofa_game", "cup_pj", "pillow_pj", "pj_cardigan", "towel", "pj1"]:
  return {"ax": 0.003, "ay": 0.010, "per": 4.8, "sway": 0.0, "sper": 1.0, "pulse": 0.0}
 return {"ax": 0.004, "ay": 0.010, "per": 3.9, "sway": 0.4, "sper": 5.2, "pulse": 0.0}

func animate_sprite(b: Control, npc: String, path: String, w: float, h: float):
 if fx_level == 0: return
 var k := 0.5 if fx_level == 1 else 1.0
 var p := motion_profile(npc, path)
 b.pivot_offset = Vector2(w * 0.5, h)
 var tws: Array = []
 var phase := randf() * 1.2
 # دخول سلس
 b.modulate.a = 0.0
 b.scale = Vector2(0.975, 0.975)
 var tin := b.create_tween().set_parallel(true)
 tin.tween_property(b, "modulate:a", 1.0, 0.4)
 tin.tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 tws.append(tin)
 # تنفس
 var tb := b.create_tween().set_loops()
 tb.tween_interval(0.4 + phase)
 var per: float = p["per"]
 tb.tween_property(b, "scale", Vector2(1.0 + p["ax"] * k, 1.0 + p["ay"] * k), per * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 tb.tween_property(b, "scale", Vector2.ONE, per * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 tws.append(tb)
 # تمايل خفيف (فقط في الوضع الكامل)
 if fx_level == 2 and float(p["sway"]) > 0.0:
  var ts := b.create_tween().set_loops()
  ts.tween_interval(0.4 + phase)
  var sp: float = p["sper"]
  ts.tween_property(b, "rotation_degrees", float(p["sway"]), sp * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  ts.tween_property(b, "rotation_degrees", -float(p["sway"]), sp * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tws.append(ts)
 # نبض شفافية (الشبح)
 if float(p["pulse"]) > 0.0:
  var tp := b.create_tween().set_loops()
  var base: Color = b.self_modulate
  tp.tween_property(b, "self_modulate:a", base.a - float(p["pulse"]), 2.2).set_trans(Tween.TRANS_SINE)
  tp.tween_property(b, "self_modulate:a", base.a, 2.2).set_trans(Tween.TRANS_SINE)
  tws.append(tp)
 b.set_meta("tws", tws)
 # إيقاف الحركة عندما يختفي العنصر (الصورة مشهد CG أو نافذة فوقه)
 b.visibility_changed.connect(func():
  var on: bool = b.is_visible_in_tree()
  for t in tws:
   if t is Tween and t.is_valid():
    if on: t.play()
    else: t.pause())

func fog_texture() -> Texture2D:
 if _fog_tex == null:
  var g := Gradient.new()
  g.set_color(0, Color(1, 1, 1, 0.9))
  g.set_color(1, Color(1, 1, 1, 0.0))
  var gt := GradientTexture2D.new()
  gt.gradient = g
  gt.fill = GradientTexture2D.FILL_RADIAL
  gt.fill_from = Vector2(0.5, 0.5)
  gt.fill_to = Vector2(1.0, 0.5)
  gt.width = 256
  gt.height = 256
  _fog_tex = gt
 return _fog_tex

func clear_fx():
 if not is_instance_valid(fx_layer): return
 for c in fx_layer.get_children():
  fx_layer.remove_child(c)
  c.queue_free()

func spawn_fog(count: int, cx: float, cy: float, spread_x: float, spread_y: float, size_min: float, size_max: float, col: Color, alpha: float):
 var vw := 1280.0
 var vh := 720.0
 for i in count:
  var t := TextureRect.new()
  t.texture = fog_texture()
  t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  t.stretch_mode = TextureRect.STRETCH_SCALE
  t.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var sz := randf_range(size_min, size_max)
  t.size = Vector2(sz, sz * 0.8)
  t.position = Vector2(vw * cx + randf_range(-spread_x, spread_x) - sz * 0.5, vh * cy + randf_range(-spread_y, spread_y) - sz * 0.4)
  t.modulate = Color(col.r, col.g, col.b, 0.0)
  fx_layer.add_child(t)
  if fx_level == 0: continue
  var tw := t.create_tween().set_loops()
  var dur := randf_range(7.0, 12.0)
  var dx := randf_range(30.0, 70.0) * (1.0 if i % 2 == 0 else -1.0)
  tw.tween_property(t, "position:x", t.position.x + dx, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tw.tween_property(t, "position:x", t.position.x, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  var ta := t.create_tween().set_loops()
  ta.tween_property(t, "modulate:a", alpha, dur * 0.45).set_trans(Tween.TRANS_SINE)
  ta.tween_property(t, "modulate:a", alpha * 0.6, dur * 0.55).set_trans(Tween.TRANS_SINE)

func refresh_fx(force := false):
 if not is_instance_valid(fx_layer): return
 var mode := "none"
 var steam_scene: bool = location == "الحمام" and steam_visible and (pose_override.begins_with("steam/") or (cg_frame.visible and "bathing" in current_cg_path))
 var ghost_scene: bool = ("/ghost/" in current_cg_path) or sprite_nodes.has("الشبح")
 if steam_scene: mode = "steam"
 elif ghost_scene: mode = "ghost"
 var key := "%s|%d|%d" % [mode, steam_density, fx_level]
 if key == _fx_key and not force: return
 _fx_key = key
 clear_fx()
 if fx_level == 0 or mode == "none": return
 var low := 0.5 if fx_level == 1 else 1.0
 if mode == "steam":
  var counts := [4, 7, 11]
  var alphas := [0.22, 0.38, 0.55]
  spawn_fog(maxi(2, int(counts[steam_density] * low)), 0.56, 0.5, 420, 230, 380, 620, Color(1.0, 0.93, 0.9), alphas[steam_density])
  if steam_density == 2:
   # أقصى كثافة: طبقة بخار كثيفة تحجب الشخصية بالكامل
   for i in 5:
    var t := TextureRect.new()
    t.texture = fog_texture()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    t.size = Vector2(900, 800)
    t.position = Vector2(720 - 450 + (i - 2) * 70, 400 - 400 + (i % 2) * 20)
    t.modulate = Color(1.0, 0.94, 0.92, 1.0)
    fx_layer.add_child(t)
 elif mode == "ghost":
  spawn_fog(maxi(2, int(5 * low)), 0.6, 0.62, 380, 200, 380, 620, Color(0.66, 0.76, 1.0), 0.20)

func cycle_steam_density():
 steam_density = (steam_density + 1) % 3
 save_prefs()
 refresh_fx(true)

func steam_density_name() -> String:
 return ["خفيف", "متوسط", "كثيف (يحجب الشخصية)"][steam_density]

func talk_to(npc: String):
 var q: Array = find_quest_step(npc)
 npc_texture(npc)
 if not q.is_empty():
  quest_dialogue(q[0], q[1], 0)
  return
 if npc == "ليان":
  interact()
  choice("روتين ليان اليومي", layan_routine)
  choice("أعطها هدية", func(): gift_menu("ليان"))
  choice("رجوع", func(): go(location))
 else:
  character_scene(npc)
  choice("أعطه هدية", func(): gift_menu(npc))

func quest_dialogue(qid: String, st: Dictionary, i: int):
 var lines: Array = st["lines"]
 say(lines[i][0], lines[i][1])
 if lines[i].size() > 2 and ResourceLoader.exists(str(lines[i][2])):
  show_cg(load(lines[i][2]))
  if sheet_style: sheet_style.bg_color.a = 0.6
 note.text = "مهمة: " + str(quest_by_id(qid)["title"])
 if i < lines.size() - 1:
  choice("التالي", func(): quest_dialogue(qid, st, i + 1))
  return
 if st.has("choices"):
  for c in st["choices"]:
   var ok := true
   if c.has("take"):
    var tk: Dictionary = c["take"]
    if tk.has("money") and money < int(tk["money"]): ok = false
    if tk.has("item") and not has_item(tk["item"]): ok = false
   var b = Button.new()
   b.text = c["t"]
   b.custom_minimum_size = Vector2(0, 66)
   b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   b.disabled = not ok
   b.pressed.connect(func(): quest_choice(qid, st, c))
   choices.add_child(b)
 else:
  choice("متابعة", func(): quest_complete(qid, st, {}))

func quest_choice(qid: String, st: Dictionary, c: Dictionary):
 if c.get("defer", false):
  go(location)
  return
 quest_complete(qid, st, c)

func quest_complete(qid: String, st: Dictionary, c: Dictionary):
 var q := quest_by_id(qid)
 var tk: Dictionary = c.get("take", {})
 if tk.has("money"): money = maxi(0, money - int(tk["money"]))
 if tk.has("item"): take_item(tk["item"])
 for it in st.get("give", []): give_item(it)
 for it in c.get("give", []): give_item(it)
 apply_fx(st.get("fx", {}))
 apply_fx(c.get("fx", {}))
 for k in st.get("skill", {}): add_skill(k, int(st["skill"][k]))
 for fl in [st.get("flag", ""), c.get("flag", "")]:
  if fl != "" and not qflags.has(fl): qflags.append(fl)
 if st.get("mark_meals", false): quest_meta[qid + "_meals"] = meals_prepared
 quest_state[qid] = int(quest_state.get(qid, 0)) + 1
 quest_day[qid] = day
 var done: bool = int(quest_state[qid]) >= q["steps"].size()
 save_game()
 var res: String = str(c.get("res", "تمت المهمة بنجاح."))
 var gained := ""
 for it in st.get("give", []): gained += "حصلت على: %s\n" % it
 say(st["npc"], res)
 note.text = ("اكتملت المهمة: %s ✓" if done else "تقدّمت المهمة: %s") % q["title"]
 if gained != "": dialogue.text = res + "\n" + gained.strip_edges()
 choice("متابعة", func(): go(location))
 update_status()

func gift_menu(npc: String):
 say("هدية", "اختر هدية لـ" + npc + ".")
 var any := false
 for it in inventory:
  if WorldData.ITEMS.get(it, {}).get("gift", false):
   any = true
   choice("%s ×%d" % [it, int(inventory[it])], func(): give_gift(npc, it))
 if not any:
  note.text = "ما عندك هدايا. تسوق من السوبرماركت."
 choice("رجوع", func(): talk_to(npc))

func give_gift(npc: String, it: String):
 if not take_item(it): return
 add_skill("الكاريزما")
 if npc == "ليان":
  relationship = mini(100, relationship + 4)
 else:
  character_relations[npc] = mini(100, int(character_relations.get(npc, 40)) + 5)
 note.text = "قدمت %s إلى %s وسعدت بها." % [it, npc]
 say(npc, "شكرًا! هذي لفتة جميلة.")
 choice("متابعة", func(): go(location))
 update_status()

func open_shop():
 say("السوبرماركت — أغراض وهدايا", "اختر ما تبي تشتريه.")
 for it in WorldData.ITEMS:
  var d: Dictionary = WorldData.ITEMS[it]
  if not d.get("shop", false): continue
  var price := int(d["price"])
  var b = Button.new()
  b.text = "%s — %d ريال" % [it, price]
  b.custom_minimum_size = Vector2(0, 66)
  b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  b.disabled = money < price
  b.pressed.connect(func(): buy_item(it))
  choices.add_child(b)
 choice("رجوع", func(): go("السوبرماركت"))
 update_status()

func buy_item(it: String):
 var price := int(WorldData.ITEMS[it]["price"])
 if money < price:
  note.text = "الرصيد لا يكفي."
  return
 money -= price
 give_item(it)
 open_shop()
 note.text = "اشتريت: " + it

# ---- overlays
func open_overlay(title: String) -> VBoxContainer:
 overlay_title.text = title
 for c in overlay_body.get_children():
  c.queue_free()
 overlay.visible = true
 return overlay_body

func close_overlay():
 overlay.visible = false

func add_card_label(body: Container, text: String, size := 22, color := Color("#f4f1ec")) -> Label:
 var l = Label.new()
 l.text = text
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size", size)
 l.add_theme_color_override("font_color", color)
 body.add_child(l)
 return l

func open_quests():
 var body = open_overlay("المهام")
 for q in WorldData.QUESTS:
  var idx := int(quest_state.get(q["id"], 0))
  var steps: Array = q["steps"]
  var box = PanelContainer.new()
  box.add_theme_stylebox_override("panel", mk_style(Color("#1f2740"), 20, Color(1, 1, 1, 0.14), 1))
  var m = MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 14)
  box.add_child(m)
  var v = VBoxContainer.new()
  v.add_theme_constant_override("separation", 6)
  m.add_child(v)
  var status_txt: String = "مكتملة ✓" if idx >= steps.size() else "الخطوة %d من %d" % [idx + 1, steps.size()]
  add_card_label(v, "%s — %s" % [q["title"], status_txt], 25, GOLD)
  if idx < steps.size():
   add_card_label(v, str(steps[idx]["hint"]), 20, Color("#d8d1c8"))
  body.add_child(box)

func open_inventory():
 var body = open_overlay("الحقيبة")
 add_card_label(body, "الرصيد: %d ريال" % money, 24, Color("#9be28f"))
 if inventory.is_empty():
  add_card_label(body, "الحقيبة فاضية. تسوق من السوبرماركت أو اطبخ وجبة مع ليان.", 21, Color("#d8d1c8"))
 for it in inventory:
  var d: Dictionary = WorldData.ITEMS.get(it, {})
  var box = PanelContainer.new()
  box.add_theme_stylebox_override("panel", mk_style(Color("#1f2740"), 18, Color(1, 1, 1, 0.14), 1))
  var m = MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 12)
  box.add_child(m)
  var v = VBoxContainer.new()
  m.add_child(v)
  add_card_label(v, "%s ×%d" % [it, int(inventory[it])], 24, GOLD)
  add_card_label(v, str(d.get("desc", "")), 19, Color("#d8d1c8"))
  if d.has("use"):
   var ub = Button.new()
   ub.text = "استخدم"
   ub.custom_minimum_size = Vector2(0, 56)
   ub.pressed.connect(func(): use_item(it))
   v.add_child(ub)
  body.add_child(box)

func use_item(it: String):
 if not take_item(it): return
 apply_fx(WorldData.ITEMS[it]["use"])
 note.text = "استخدمت " + it
 update_status()
 open_inventory()

func open_profile():
 var body = open_overlay("الملف الشخصي")
 add_card_label(body, "اليوم %d • %s • الرصيد %d ريال" % [day, periods[period], money], 22)
 add_card_label(body, "العلاقات", 26, GOLD)
 var rels = [["ليان", relationship]]
 for n in ["نورة", "سارة", "هند", "ميسون", "الشبح"]:
  if n == "الشبح" and not has_flag("ghost_met"): continue
  rels.append([n, int(character_relations.get(n, 0))])
 for r in rels:
  var row = HBoxContainer.new()
  row.add_theme_constant_override("separation", 10)
  var l = Label.new()
  l.text = r[0]
  l.custom_minimum_size = Vector2(110, 0)
  row.add_child(l)
  var bar = make_bar(Color("#ff7aa8"))
  bar.value = r[1]
  row.add_child(bar)
  var vl = Label.new()
  vl.text = str(r[1])
  vl.custom_minimum_size = Vector2(52, 0)
  row.add_child(vl)
  body.add_child(row)
 add_card_label(body, "المهارات", 26, GOLD)
 for sk in WorldData.SKILLS:
  add_card_label(body, "%s: المستوى %d" % [sk, skill_level(sk)], 22)
 var fb = Button.new()
 fb.text = "الحركة والمؤثرات: " + fx_level_name()
 fb.custom_minimum_size = Vector2(0, 62)
 fb.pressed.connect(func():
  cycle_fx_level()
  fb.text = "الحركة والمؤثرات: " + fx_level_name())
 body.add_child(fb)
 var wb = Button.new()
 wb.text = "انتظر (تمرير الوقت)"
 wb.custom_minimum_size = Vector2(0, 62)
 wb.pressed.connect(func():
  close_overlay()
  wait_period())
 body.add_child(wb)
 var gb = Button.new()
 gb.text = "هدف الشهر والمهمة الحالية"
 gb.custom_minimum_size = Vector2(0, 62)
 gb.pressed.connect(func():
  close_overlay()
  show_goal())
 body.add_child(gb)
 var sb = Button.new()
 sb.text = "حفظ التقدم"
 sb.custom_minimum_size = Vector2(0, 62)
 sb.pressed.connect(func():
  save_game()
  note.text = "تم الحفظ."
  close_overlay())
 body.add_child(sb)

func map_pin_has_quest(place: String) -> bool:
 for npc in WorldData.NPCS:
  if npc_present(npc, place) and not find_quest_step(npc).is_empty(): return true
 return false

func open_map(tab := "city"):
 var body = open_overlay("الخريطة")
 var tabs = HBoxContainer.new()
 tabs.add_theme_constant_override("separation", 10)
 for t in [["city", "المدينة"], ["house", "المنزل"]]:
  var tb = Button.new()
  tb.text = t[1]
  tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  tb.custom_minimum_size = Vector2(0, 58)
  if tab == t[0]:
   tb.add_theme_stylebox_override("normal", mk_style(Color("#d08a5a"), 18))
   tb.add_theme_color_override("font_color", Color("#1b1b1b"))
  var key: String = t[0]
  tb.pressed.connect(func(): open_map(key))
  tabs.add_child(tb)
 body.add_child(tabs)
 var tex_path := "res://assets/maps/city_map.png" if tab == "city" else "res://assets/maps/house_map.png"
 var pins: Array = WorldData.CITY_PINS if tab == "city" else WorldData.HOUSE_PINS
 var src: Vector2 = WorldData.CITY_SIZE if tab == "city" else WorldData.HOUSE_SIZE
 var arc = AspectRatioContainer.new()
 arc.ratio = src.x / src.y
 arc.custom_minimum_size = Vector2(0, 400)
 arc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 arc.layout_direction = Control.LAYOUT_DIRECTION_LTR
 body.add_child(arc)
 var holder = Control.new()
 holder.layout_direction = Control.LAYOUT_DIRECTION_LTR
 arc.add_child(holder)
 var img = TextureRect.new()
 if ResourceLoader.exists(tex_path): img.texture = load(tex_path)
 img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 img.stretch_mode = TextureRect.STRETCH_SCALE
 img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 img.mouse_filter = Control.MOUSE_FILTER_IGNORE
 holder.add_child(img)
 for pin in pins:
  var place: String = pin["id"]
  var pos: Vector2 = pin["pos"]
  var sz: Vector2 = pin["size"]
  var b = Button.new()
  b.anchor_left = (pos.x - sz.x / 2.0) / src.x
  b.anchor_right = (pos.x + sz.x / 2.0) / src.x
  b.anchor_top = (pos.y - sz.y / 2.0) / src.y
  b.anchor_bottom = (pos.y + sz.y / 2.0) / src.y
  var here: bool = (place == location) or (tab == "house" and place == "المنزل")
  b.add_theme_stylebox_override("normal", mk_style(Color(0, 0, 0, 0.0), 12, GOLD if here else Color(1, 1, 1, 0.0), 3 if here else 0))
  b.add_theme_stylebox_override("hover", mk_style(Color(1, 1, 1, 0.16), 12, GOLD, 3))
  b.add_theme_stylebox_override("pressed", mk_style(Color(1, 0.8, 0.4, 0.35), 12, GOLD, 3))
  b.add_theme_stylebox_override("focus", mk_style(Color(0, 0, 0, 0.0), 12))
  b.pressed.connect(func():
   close_overlay()
   go(place))
  holder.add_child(b)
  if map_pin_has_quest(place):
   var mk = Label.new()
   mk.text = "!"
   mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   mk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
   mk.add_theme_font_size_override("font_size", 24)
   mk.add_theme_color_override("font_color", Color("#1b1b1b"))
   mk.add_theme_stylebox_override("normal", mk_style(Color("#ffd34d"), 18))
   mk.custom_minimum_size = Vector2(32, 32)
   mk.anchor_left = b.anchor_left
   mk.anchor_right = b.anchor_left
   mk.anchor_top = b.anchor_top
   mk.anchor_bottom = b.anchor_top
   mk.offset_left = -10
   mk.offset_right = 22
   mk.offset_top = -14
   mk.offset_bottom = 18
   mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
   holder.add_child(mk)
 var extras: Array = WorldData.EXTRA_ROOMS if tab == "house" else ["متجر الملابس"]
 add_card_label(body, "أماكن أخرى" if tab == "city" else "غرف أخرى", 24, GOLD)
 var grid = GridContainer.new()
 grid.columns = 2
 grid.add_theme_constant_override("h_separation", 10)
 grid.add_theme_constant_override("v_separation", 10)
 for ex in extras:
  var eb = Button.new()
  eb.text = ex
  eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  eb.custom_minimum_size = Vector2(0, 62)
  eb.pressed.connect(func():
   close_overlay()
   go(ex))
  grid.add_child(eb)
 body.add_child(grid)

# ================= القصة =================
func friends_avg() -> int:
 var total := 0
 for n in ["نورة", "سارة", "هند", "ميسون"]:
  total += int(character_relations.get(n, 0))
 return total / 4

func stat_value(key: String) -> int:
 match key:
  "relationship": return relationship
  "house_cleanliness": return house_cleanliness
  "money": return money
  "meals_prepared": return meals_prepared
  "friends_avg": return friends_avg()
 return 0

func week_met(i: int) -> bool:
 var reqs: Dictionary = StoryData.WEEKS[i]["reqs"]
 for k in reqs:
  if stat_value(k) < int(reqs[k]): return false
 return true

func current_week() -> int:
 return clampi((day - goal_start_day) / 7, 0, StoryData.WEEKS.size() - 1)

func show_intro():
 story_seen.append("intro")
 say("حكاية بيتنا", StoryData.INTRO)
 note.text = "هدف الشهر: 30 يوم، 4 مهام أسبوعية."
 choice("ابدأ الشهر", func(): go("المنزل"))
 update_status()

func show_goal():
 var w = StoryData.WEEKS[current_week()]
 var lines = "%s\n%s\n" % [w["title"], w["desc"]]
 var reqs: Dictionary = w["reqs"]
 for k in reqs:
  lines += "• %s: %d / %d\n" % [StoryData.REQ_NAMES.get(k, k), stat_value(k), int(reqs[k])]
 lines += "المكافأة: %d ريال. مهام منجزة: %d من 4." % [int(w["reward"]), weeks_done.size()]
 say("هدف الشهر — يوم %d من %d" % [clampi(day - goal_start_day + 1, 1, StoryData.GOAL_DAYS), StoryData.GOAL_DAYS], lines)
 choice("رجوع", func(): go("المنزل"))
 update_status()

func apply_fx(fx: Dictionary):
 for k in fx:
  match k:
   "money": money = maxi(0, money + int(fx[k]))
   "energy": energy = clampi(energy + int(fx[k]), 0, 100)
   "relationship": relationship = clampi(relationship + int(fx[k]), 0, 100)
   "house_cleanliness": house_cleanliness = clampi(house_cleanliness + int(fx[k]), 0, 100)
   "laundry": laundry = maxi(0, laundry + int(fx[k]))
   "rel":
    var d: Dictionary = fx[k]
    for n in d:
     character_relations[n] = clampi(int(character_relations.get(n, 40)) + int(d[n]), 0, 100)

func check_scenes() -> bool:
 for sc in StoryData.SCENES:
  if story_seen.has(sc["id"]): continue
  var cur: int = relationship if sc.get("kind", "") == "layan" else int(character_relations.get(sc["who"], 0))
  if cur >= int(sc["min"]):
   story_seen.append(sc["id"])
   apply_fx(sc["fx"])
   show_scene(sc, 0)
   return true
 return false

func show_scene(sc: Dictionary, idx: int):
 var lines: Array = sc["lines"]
 say(sc["who"], lines[idx])
 note.text = "مشهد جديد مع " + sc["who"]
 if idx < lines.size() - 1:
  choice("التالي", func(): show_scene(sc, idx + 1))
 else:
  choice("متابعة", func(): go("المنزل"))
 update_status()

func story_after_day() -> bool:
 var d := day - goal_start_day
 if d >= StoryData.GOAL_DAYS and not story_ended:
  show_ending()
  return true
 if d > 0 and d % 7 == 0 and d <= 28:
  var i := d / 7 - 1
  if not weeks_checked.has(i):
   weeks_checked.append(i)
   var w = StoryData.WEEKS[i]
   if week_met(i):
    weeks_done.append(i)
    money += int(w["reward"])
    say("نتيجة الأسبوع", "أنجزتم «%s». ربحتم مكافأة %d ريال." % [w["title"], int(w["reward"])])
   else:
    say("نتيجة الأسبوع", "ما اكتمل هدف «%s» هالمرة. ما فيه مشكلة، كملوا." % w["title"])
   choice("متابعة", func(): go("المنزل"))
   update_status()
   return true
 if day % 2 == 0:
  var ev = StoryData.EVENTS[events_done % StoryData.EVENTS.size()]
  events_done += 1
  start_event(ev)
  return true
 return false

func start_event(ev: Dictionary):
 say("🔔 " + str(ev["title"]), str(ev["text"]))
 for c in ev["choices"]:
  choice(c["t"], func(): resolve_event(c))
 update_status()

func resolve_event(c: Dictionary):
 apply_fx(c["fx"])
 save_game()
 say("النتيجة", str(c["res"]))
 choice("متابعة", func(): go("المنزل"))
 update_status()

func show_ending():
 story_ended = true
 var score := weeks_done.size()
 var en = StoryData.ENDINGS[StoryData.ENDINGS.size() - 1]
 for e in StoryData.ENDINGS:
  if score >= int(e["min"]):
   en = e
   break
 say(str(en["title"]), "%s\n\nمهام منجزة: %d من 4." % [str(en["text"]), score])
 note.text = "انتهى الشهر الأول."
 choice("ابدأ شهرًا جديدًا", start_new_month)
 choice("كمل اللعب بدون هدف", func(): go("المنزل"))
 update_status()

func start_new_month():
 goal_start_day = day
 weeks_done = []
 weeks_checked = []
 story_ended = false
 save_game()
 go("المنزل")

func load_game():
 var file = FileAccess.open("user://savegame.json", FileAccess.READ)
 if not file:
  return
 var parsed = JSON.parse_string(file.get_as_text())
 file.close()
 if typeof(parsed) != TYPE_DICTIONARY:
  return
 day = int(parsed.get("day", day))
 period = int(parsed.get("period", period))
 money = int(parsed.get("money", money))
 relationship = int(parsed.get("relationship", relationship))
 mood = str(parsed.get("mood", mood))
 outfit = str(parsed.get("outfit", outfit))
 owned_outfits = parsed.get("owned_outfits", owned_outfits)
 laundry = int(parsed.get("laundry", laundry))
 energy = int(parsed.get("energy", energy))
 location = str(parsed.get("location", location))
 character_relations = parsed.get("character_relations", character_relations)
 if not character_relations.has("الشبح"): character_relations["الشبح"] = 0
 daily_flags = parsed.get("daily_flags", daily_flags)
 layan_hunger = int(parsed.get("layan_hunger", layan_hunger))
 layan_thirst = int(parsed.get("layan_thirst", layan_thirst))
 layan_tiredness = int(parsed.get("layan_tiredness", layan_tiredness))
 layan_activity = str(parsed.get("layan_activity", layan_activity))
 house_cleanliness = int(parsed.get("house_cleanliness", house_cleanliness))
 meals_prepared = int(parsed.get("meals_prepared", meals_prepared))
 shower_count = int(parsed.get("shower_count", shower_count))
 schedule_note = str(parsed.get("schedule_note", schedule_note))
 story_seen = parsed.get("story_seen", story_seen)
 weeks_done = parsed.get("weeks_done", weeks_done)
 weeks_checked = parsed.get("weeks_checked", weeks_checked)
 goal_start_day = int(parsed.get("goal_start_day", goal_start_day))
 events_done = int(parsed.get("events_done", events_done))
 story_ended = bool(parsed.get("story_ended", story_ended))
 inventory = parsed.get("inventory", inventory)
 quest_state = parsed.get("quest_state", quest_state)
 quest_day = parsed.get("quest_day", quest_day)
 quest_meta = parsed.get("quest_meta", quest_meta)
 qflags = parsed.get("qflags", qflags)
 skill_pts = parsed.get("skill_pts", skill_pts)

func save_game():
 var data = {"day":day,"period":period,"money":money,"relationship":relationship,"mood":mood,"outfit":outfit,"owned_outfits":owned_outfits,"laundry":laundry,"energy":energy,"location":location,"character_relations":character_relations,"daily_flags":daily_flags,"layan_hunger":layan_hunger,"layan_thirst":layan_thirst,"layan_tiredness":layan_tiredness,"layan_activity":layan_activity,"house_cleanliness":house_cleanliness,"meals_prepared":meals_prepared,"shower_count":shower_count,"schedule_note":schedule_note,"story_seen":story_seen,"weeks_done":weeks_done,"weeks_checked":weeks_checked,"goal_start_day":goal_start_day,"events_done":events_done,"story_ended":story_ended,"inventory":inventory,"quest_state":quest_state,"quest_day":quest_day,"quest_meta":quest_meta,"qflags":qflags,"skill_pts":skill_pts}
 var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
 if file:
  file.store_string(JSON.stringify(data))
  file.close()

func _notification(what):
 if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
  save_game()
