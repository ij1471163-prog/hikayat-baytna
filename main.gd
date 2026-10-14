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
 "مريول المنزل": "res://assets/layan_outfits/12_home_apron.png",
 "بيجامة القلوب الوردية": "res://assets/layan_outfits/13_pink_hearts_pajamas.png",
 "فستان صوف بيج": "res://assets/layan_outfits/14_beige_sweater_dress.png",
 "فستان الحمل الأزرق": "res://assets/layan_outfits/15_blue_maternity_dress.png",
 "بيجامة الدباديب": "res://assets/layan_outfits/16_teddy_pajamas.png",
 "طقم رياضي رمادي": "res://assets/layan_outfits/17_gray_lounge_set.png",
 "تيشيرت الدبدوب": "res://assets/layan_outfits/18_teddy_tshirt.png",
 "فستان أصفر مزهر": "res://assets/layan_outfits/19_yellow_floral_dress.png"
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
const RoomsData = preload("res://rooms_data.gd")
const TalkData = preload("res://talk_data.gd")
const FamilyData = preload("res://family_data.gd")
const ScenesData = preload("res://scenes_data.gd")
# نقاط التفاعل داخل الغرف
var hotspot_layer: Control
var exits_box: HFlowContainer
var menu_btn: Button
var menu_open := false
var _walking := false
var _interrupted := false
var _mask_cache: Dictionary = {}
# السوالف
var talks_seen: Array = []
# قصة المولود
var preg_stage := 0
var preg_start := 0
var preg_flags: Array = []
var craving := ""
var craving_bought := ""
var nursery: Array = []
var baby_name := ""
var baby_gender := ""
var baby_born := 0
var pre_preg_outfit := ""
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

const BG_FILES := {"المنزل":"living_room","المطبخ":"kitchen","الحمام":"bathroom","غرفة النوم":"bedroom","غرفة ليان":"layan_room","غرفة نورة":"nora_room","الصالة":"living_room","غرفة الاسترخاء":"relax_room","غرفة الغسيل":"laundry","متجر الملابس":"clothes_shop","الحديقة":"garden","العمل":"work","المقهى":"cafe","الشاطئ":"beach","النادي الرياضي":"gym","السوبرماركت":"supermarket","الممر":"hallway","المدخل":"entrance","غرفة التخزين":"storage"}
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
 hotspot_layer = Control.new()
 hotspot_layer.name = "HotspotLayer"
 hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hotspot_layer)
 sprites_layer = Control.new()
 sprites_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 sprites_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(sprites_layer)
 scene_layer = Control.new()
 scene_layer.name = "LiveSceneLayer"
 scene_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 scene_layer.clip_contents = true
 add_child(scene_layer)
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
 activity_badge.text = "ليان في المنزل"
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
 menu_btn = Button.new()
 menu_btn.name = "RoomMenuButton"
 menu_btn.text = "كل الأنشطة"
 menu_btn.anchor_left = 0.015
 menu_btn.anchor_top = 0.235
 menu_btn.offset_right = 230
 menu_btn.offset_bottom = 52
 menu_btn.add_theme_font_size_override("font_size", 19)
 menu_btn.focus_mode = Control.FOCUS_NONE
 menu_btn.visible = false
 menu_btn.pressed.connect(func():
  menu_open = not menu_open
  refresh_hotspots())
 add_child(menu_btn)
 exits_box = HFlowContainer.new()
 exits_box.name = "RoomExits"
 exits_box.anchor_left = 0.015
 exits_box.anchor_right = 0.66
 exits_box.anchor_top = 0.805
 exits_box.anchor_bottom = 0.805
 exits_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
 exits_box.offset_top = -56
 exits_box.offset_bottom = -6
 exits_box.add_theme_constant_override("h_separation", 8)
 exits_box.add_theme_constant_override("v_separation", 6)
 exits_box.visible = false
 add_child(exits_box)
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
 steam_toggle.visible = (location == "الحمام") and not room_active() and bath_mode != "live"
 if is_instance_valid(activity_badge):
  activity_badge.text = activity_emoji() + " " + layan_activity

func activity_emoji() -> String:
 if "تأكل" in layan_activity: return ""
 if "تشرب" in layan_activity: return ""
 if "تطبخ" in layan_activity: return ""
 if "جالسة" in layan_activity or "تستريح" in layan_activity: return ""
 if "نائمة" in layan_activity: return ""
 if "زوجها" in layan_activity: return ""
 return ""

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
 refresh_hotspots()

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
 refresh_hotspots()

func clear_cg():
 if not is_instance_valid(cg_frame): return
 if sheet_style: sheet_style.bg_color.a = 0.9
 cg_frame.visible = false
 current_cg_path = ""
 sprites_layer.visible = true
 refresh_hotspots()

func layan_sprite_path() -> String:
 if pose_override.begins_with("exercise/") or pose_override.begins_with("steam/"):
  return "res://assets/sprites/%s.png" % pose_override
 if pose_override != "":
  return "res://assets/sprites/poses/%s.png" % pose_override
 # داخل البيت: ليان تظهر باللبس اللي لابسته (حتى الجديد). برا البيت: صورة تناسب المكان (نادي، شغل، بحر...)
 if not outfit_view and LAYAN_POSES.has(location) and not (location in WorldData.HOUSE_PLACES):
  var pp := "res://assets/sprites/poses/%s.png" % LAYAN_POSES[location]
  if ResourceLoader.exists(pp): return pp
 var tp: String = str(outfit_textures.get(outfit, "res://assets/layan_outfits/01_pink_home_pajamas.png")).replace("layan_outfits", "sprites/layan")
 if not ResourceLoader.exists(tp): tp = "res://assets/sprites/layan/01_pink_home_pajamas.png"
 return tp

func set_background(place):
 var n: String = str(BG_FILES.get(place, "city"))
 if place == "غرفة التخزين" and nursery.size() >= 3 and ResourceLoader.exists("res://assets/backgrounds/nursery.jpg"): n = "nursery"
 if not ResourceLoader.exists("res://assets/backgrounds/%s.jpg" % n) and not ResourceLoader.exists("res://assets/backgrounds/%s.png" % n): n = "entrance"
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
 menu_open = false
 _walking = false
 _interrupted = false
 bath_mode = ""
 shower_clear()
 _go_inner(place)
 if _interrupted:
  _interrupted = false
  explore_mode = false
  refresh_cards()
  return
 if not RoomsData.ROOMS.has(place):
  var gsc := available_group_scene(place)
  if not gsc.is_empty():
   choice("سالفة: " + str(gsc["title"]), func(): play_group_scene(gsc, 0))
 if place in ["المنزل", "المطبخ", "الصالة", "غرفة النوم", "غرفة ليان"] and not layan_here(place) and is_instance_valid(note):
  note.text = "ليان مو هنا الحين؛ هي في %s." % str(npc_sched("ليان")[period])
 explore_mode = true
 refresh_cards()
 room_intro()

func _go_inner(place):
 location = place
 if place in WorldData.HOUSE_PLACES and family_check():
  _interrupted = true
  return
 if place == "المنزل" and check_scenes():
  _interrupted = true
  return
 restore_outfit_portrait()
 if place != "الحمام":
  steam_visible = false
  if is_instance_valid(steam_overlay): steam_overlay.visible = false
  if is_instance_valid(steam_toggle): steam_toggle.text = "إظهار البخار"
 bg.color = Color(colors.get(place, "#8c7465"))
 set_background(place)
 update_status()
 match place:
  "المنزل":
   say("ليان — زوجتك", "أهلًا! تقدر تتفاعل معي، تختار ملابس، أو تدير شؤون البيت.")
   if layan_here("المنزل"):
    choice("تفاعل مع ليان", interact)
   else:
    var lr: String = str(npc_sched("ليان")[period])
    choice("روح لليان (في %s)" % lr, func(): go(lr))
   if preg_stage >= 1 and preg_stage <= 3:
    choice("ليان والحمل", preg_menu)
   elif preg_stage == 4:
    choice("" + baby_name, baby_menu)
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
   choice("روتين الاستحمام الكامل", func(): live_shower(0))
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
   if preg_stage >= 2:
    choice("تجهيز غرفة البيبي", nursery_menu)
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
   if craving != "" and craving_bought != craving:
    choice("اشتر وحم ليان: %s (-%d ريال)" % [craving, FamilyData.CRAVING_COST], buy_craving)
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
 show_layan_action("ليان تتناول وجبتها")
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
# مكان الدش الزجاجي في خلفية الحمام (نِسَب من الشاشة) — ليان تستحم هنا خلف الزجاج
const SHOWER_RECT := [0.045, 0.17, 0.29, 0.66]
const TUB_RECT := [0.80, 0.62, 0.20, 0.20]
var bath_mode := ""
var scene_layer: Control = null
var _sh := {}
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
 show_layan_action("" + st[1])
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
 show_layan_action("ليان تشرب الماء")
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
 show_layan_action("ليان تجلس وتسترخي")
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
 show_layan_action("ليان نامت لترتاح")
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
 show_layan_action("ليان تتفاعل مع زوجها")
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
 set_background("الحمام")
 var st: Array = FULL_BATH[i]
 if st[0] == "steam":
  steam_visible = true
  bath_mode = "shower"
  show_pose("steam/" + str(st[1]))
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

const MASSAGE_STEPS := ["تبدأ نورة بتدليك الكتفين بلطف.", "تضيف الزيت العطري على الظهر.", "حركات دائرية هادئة على الكتفين.", "تدليك طويل لعمود الظهر.", "تنزل لأسفل الظهر بحركات أعمق وترخي العضلات.", "تدليك الرقبة وفروة الرأس.", "أحجار دافئة على الظهر.", "تدليك الساقين.", "تدليك القدمين.", "تدليك الرأس والاسترخاء.", "منشفة دافئة على الظهر.", "تنتهي الجلسة وتحس ليان براحة تامة."]

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
 rel_once("tv", 3)
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
 var t := pick_talk()
 if t.is_empty():
  relationship = mini(100, relationship + 1)
  say("ليان", "يسعدني نتكلم ونخطط ليومنا مع بعض.")
  choice("رجوع", func(): go(location))
  update_status()
  return
 talk_line(t, 0)

func hold_hand():
 rel_once("hand", 2)
 mood = "مبسوطة"
 note.text = "ليان ابتسمت وتفاعلت بود. (حركة مرسومة يمكن إضافتها لاحقًا)"
 say("ليان", "لحظة لطيفة بين الزوجين.")
 choice("رجوع", func(): go("المنزل"))
 update_status()

func hug():
 rel_once("hug", 4)
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
 if is_instance_valid(note): note.text = "ليان ارتدت %s، وبيظهر عليها في كل غرف البيت." % item
 clear_cg()
 pose_override = ""
 outfit_view = true
 sprite_focus = ["ليان"]
 refresh_cards()
 update_status()
 wardrobe()

func clothing_shop():
 say("متجر الملابس", "اختر قطعة جديدة لخزانة ليان.")
 var catalog = [["فستان سهرة أحمر",160],["فستان صيفي مزهر",75],["بلوزة وتنورة",90],["طقم محبوك بيج",95],["بدلة رياضية وردية",90],["معطف شتوي",180],["بدلة عمل",130],["مريول المنزل",65],["بيجامة القلوب الوردية",85],["فستان صوف بيج",110],["بيجامة الدباديب",70],["طقم رياضي رمادي",95],["تيشيرت الدبدوب",45],["فستان أصفر مزهر",100]]
 for item in catalog:
  var name: String = item[0]
  var price: int = item[1]
  var spr: String = str(outfit_textures.get(name, "")).replace("layan_outfits", "sprites/layan")
  if spr == "" or not ResourceLoader.exists(spr): continue
  var owned_tag := " (عندك)" if owned_outfits.has(name) else ""
  choice("%s — %d ريال%s" % [name, price, owned_tag], func(): buy_outfit(name, price))
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
 note.text = "اشتريت %s، وليان لبسته. بيظهر عليها بكل غرف البيت." % name
 wear(name)

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
   say("نورة", "نورة تشتغل عندكم من سنين، وصارت أقرب صديقة لليان. تقدر تسولف معها أو تتعاونون في شؤون البيت.")
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
 if preg_stage == 3: layan_tiredness = mini(100, layan_tiredness + 4)
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
 if npc == "ليان" and preg_stage == 3: return ["غرفة النوم", "الصالة", "الصالة", "غرفة النوم"]
 var d: Dictionary = WorldData.NPCS[npc]
 if is_weekend() and d.has("weekend"): return d["weekend"]
 return d["sched"]

func npc_present(npc: String, place: String) -> bool:
 if npc == "الشبح" and (day < 3 or has_flag("ghost_free")): return false
 return npc_sched(npc)[period] == place

# ليان: حاضرة في المنزل (الواجهة) وفي الحمام/الاسترخاء وفي الخروجات معها؛ وفي بقية غرف البيت حسب جدولها
func layan_here(place: String) -> bool:
 # ليان في مكان واحد فقط: «المنزل» هو نفس الصالة. الحمام وغرفة الاسترخاء تظهر فيها وقت النشاط فقط.
 if not (place in WorldData.HOUSE_PLACES): return true
 if place == "المنزل": place = "الصالة"
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
 _walking = false
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
 var cs: Array = centers[clampi(who.size(), 1, 3) - 1].duplicate()
 if explore_mode and sprite_focus.is_empty() and RoomsData.ROOMS.has(location):
  var spot: float = float(RoomsData.ROOMS[location].get("spot", 0.74))
  var others := [spot + 0.24, spot - 0.24, spot + 0.46, spot - 0.46]
  var k := 0
  cs = []
  for npc in who:
   if npc == "ليان":
    cs.append(spot)
   else:
    var x: float = others[k]
    if x > 0.88 or x < 0.12: x = others[k + 1] if k + 1 < others.size() else spot
    cs.append(clampf(x, 0.12, 0.88))
    k += 1
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
  var half_body: bool = is_half_body(path)
  var full_body: bool = path.get_base_dir().get_file() != "sprites" and not is_steam and not half_body
  if half_body: h = vh * 0.9
  var lift := 0.0
  if full_body:
   lift = vh * 0.175
   if not ("/exercise/" in path): h = minf(h * 0.775, vh * 0.72)
  var in_shower: bool = is_steam and location == "الحمام" and not cg_frame.visible
  if is_steam:
   h = minf(vh * 0.98, vw * 0.92 * float(tex.get_height()) / float(tex.get_width()))
  if in_shower:
   # داخل الدش الزجاجي على اليسار في خلفية حمام ليان
   var sr: Array = SHOWER_RECT
   h = minf(vh * float(sr[3]) * 0.86, vw * float(sr[2]) * 0.94 * float(tex.get_height()) / float(tex.get_width()))
   lift = vh * (1.0 - float(sr[1]) - float(sr[3])) + vh * 0.04
  var w: float = h * float(tex.get_width()) / float(tex.get_height())
  var sh_node: Control = null
  if full_body:
   var sh := TextureRect.new()
   sh_node = sh
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
  b.texture_click_mask = click_mask_for(path, tex)
  if sh_node != null: b.set_meta("shadow", sh_node)
  b.ignore_texture_size = true
  b.stretch_mode = TextureButton.STRETCH_SCALE
  var cx_a: float = 0.56 if is_steam else cs[i]
  if in_shower: cx_a = float(SHOWER_RECT[0]) + float(SHOWER_RECT[2]) * 0.5
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
 refresh_hotspots()

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
 var steam_scene: bool = location == "الحمام" and steam_visible and (pose_override.begins_with("steam/") or (cg_frame.visible and "bathing" in current_cg_path) or (bath_mode == "tub" and not explore_mode))
 var ghost_scene: bool = ("/ghost/" in current_cg_path) or sprite_nodes.has("الشبح")
 if steam_scene: mode = "steam"
 elif ghost_scene: mode = "ghost"
 var key := "%s|%s|%s|%d|%d" % [mode, bath_mode, pose_override, steam_density, fx_level]
 if key == _fx_key and not force: return
 _fx_key = key
 clear_fx()
 if fx_level == 0 or mode == "none": return
 var low := 0.5 if fx_level == 1 else 1.0
 if mode == "steam" and bath_mode == "tub" and not cg_frame.visible:
  spawn_fog_rect(TUB_RECT, [5, 8, 12][steam_density], [0.35, 0.55, 0.8][steam_density], 0.0)
  return
 if mode == "steam" and pose_override.begins_with("steam/") and not cg_frame.visible:
  # زجاج مضبب فوق الدش + بخار داخله. الكثافة القصوى تغطي ليان بالكامل.
  spawn_fog_rect(SHOWER_RECT, [5, 8, 12][steam_density], [0.28, 0.45, 0.7][steam_density], [0.08, 0.14, 0.22][steam_density])
  if steam_density == 2:
   var sr: Array = SHOWER_RECT
   for i in 4:
    var t := TextureRect.new()
    t.texture = fog_texture()
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    t.size = Vector2(1280.0 * float(sr[2]) * 1.5, 720.0 * float(sr[3]) * 0.9)
    t.position = Vector2(1280.0 * (float(sr[0]) + float(sr[2]) * 0.5) - t.size.x * 0.5, 720.0 * (float(sr[1]) + float(sr[3]) * (0.12 + 0.2 * i)) - t.size.y * 0.35)
    t.modulate = Color(1.0, 0.95, 0.93, 1.0)
    fx_layer.add_child(t)
  return
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

# بخار محصور داخل مستطيل (الدش أو البانيو) + طبقة زجاج مضبب اختيارية
func spawn_fog_rect(rr: Array, count: int, alpha: float, glass: float):
 var low := 0.5 if fx_level == 1 else 1.0
 var x0 := 1280.0 * float(rr[0])
 var y0 := 720.0 * float(rr[1])
 var w := 1280.0 * float(rr[2])
 var hh := 720.0 * float(rr[3])
 if glass > 0.0:
  var g := ColorRect.new()
  g.color = Color(0.92, 0.96, 1.0, glass)
  g.mouse_filter = Control.MOUSE_FILTER_IGNORE
  g.position = Vector2(x0, y0)
  g.size = Vector2(w, hh)
  fx_layer.add_child(g)
 spawn_fog(maxi(2, int(count * low)), float(rr[0]) + float(rr[2]) * 0.5, float(rr[1]) + float(rr[3]) * 0.5, w * 0.32, hh * 0.32, w * 0.55, w * 0.95, Color(1.0, 0.94, 0.92), alpha)

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
 note.text = ("اكتملت المهمة: %s " if done else "تقدّمت المهمة: %s") % q["title"]
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
  var status_txt: String = "مكتملة " if idx >= steps.size() else "الخطوة %d من %d" % [idx + 1, steps.size()]
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
 say("" + str(ev["title"]), str(ev["text"]))
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
 talks_seen = parsed.get("talks_seen", talks_seen)
 preg_stage = int(parsed.get("preg_stage", preg_stage))
 preg_start = int(parsed.get("preg_start", preg_start))
 preg_flags = parsed.get("preg_flags", preg_flags)
 craving = str(parsed.get("craving", craving))
 craving_bought = str(parsed.get("craving_bought", craving_bought))
 nursery = parsed.get("nursery", nursery)
 baby_name = str(parsed.get("baby_name", baby_name))
 baby_gender = str(parsed.get("baby_gender", baby_gender))
 baby_born = int(parsed.get("baby_born", baby_born))
 pre_preg_outfit = str(parsed.get("pre_preg_outfit", pre_preg_outfit))

func save_game():
 var data = {"day":day,"period":period,"money":money,"relationship":relationship,"mood":mood,"outfit":outfit,"owned_outfits":owned_outfits,"laundry":laundry,"energy":energy,"location":location,"character_relations":character_relations,"daily_flags":daily_flags,"layan_hunger":layan_hunger,"layan_thirst":layan_thirst,"layan_tiredness":layan_tiredness,"layan_activity":layan_activity,"house_cleanliness":house_cleanliness,"meals_prepared":meals_prepared,"shower_count":shower_count,"schedule_note":schedule_note,"story_seen":story_seen,"weeks_done":weeks_done,"weeks_checked":weeks_checked,"goal_start_day":goal_start_day,"events_done":events_done,"story_ended":story_ended,"inventory":inventory,"quest_state":quest_state,"quest_day":quest_day,"quest_meta":quest_meta,"qflags":qflags,"skill_pts":skill_pts,"talks_seen":talks_seen,"preg_stage":preg_stage,"preg_start":preg_start,"preg_flags":preg_flags,"craving":craving,"craving_bought":craving_bought,"nursery":nursery,"baby_name":baby_name,"baby_gender":baby_gender,"baby_born":baby_born,"pre_preg_outfit":pre_preg_outfit}
 var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
 if file:
  file.store_string(JSON.stringify(data))
  file.close()

func _notification(what):
 if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
  save_game()

# ================= نقاط التفاعل داخل الغرف =================
func is_half_body(path: String) -> bool:
 return "_half" in path.get_file()

func click_mask_for(path: String, tex: Texture2D) -> BitMap:
 if _mask_cache.has(path): return _mask_cache[path]
 var bm: BitMap = null
 var img: Image = tex.get_image() if tex != null else null
 if img != null:
  if img.is_compressed(): img.decompress()
  if img.detect_alpha() != Image.ALPHA_NONE:
   var small := img.duplicate()
   small.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_BILINEAR)
   bm = BitMap.new()
   bm.create_from_image_alpha(small, 0.25)
 _mask_cache[path] = bm
 return bm

func room_active() -> bool:
 if not is_instance_valid(cg_frame): return false
 if is_instance_valid(overlay) and overlay.visible: return false
 return explore_mode and sprite_focus.is_empty() and not cg_frame.visible and RoomsData.ROOMS.has(location)

func pill_style(col: Color) -> StyleBoxFlat:
 var st := mk_style(col, 16, Color(1, 1, 1, 0.35), 1)
 st.content_margin_left = 10
 st.content_margin_right = 10
 st.content_margin_top = 3
 st.content_margin_bottom = 3
 return st

func refresh_hotspots():
 if not is_instance_valid(hotspot_layer): return
 for c in hotspot_layer.get_children():
  hotspot_layer.remove_child(c)
  c.queue_free()
 for c in exits_box.get_children():
  exits_box.remove_child(c)
  c.queue_free()
 var on := room_active()
 hotspot_layer.visible = on
 exits_box.visible = on
 menu_btn.visible = on
 if is_instance_valid(steam_toggle): steam_toggle.visible = (location == "الحمام") and not on
 if not on:
  choice_scroll.visible = true
  choice_scroll.anchor_top = 0.21
  # وقت الاستحمام الحي: الأزرار يمين الشاشة علشان ما تغطي الدش (يسار)
  choice_scroll.anchor_left = 0.55 if bath_mode == "live" else 0.015
  choice_scroll.anchor_right = 0.985 if bath_mode == "live" else 0.5
  return
 var rd: Dictionary = RoomsData.ROOMS[location]
 var hs: Array = rd["hotspots"]
 choice_scroll.anchor_left = 0.015
 choice_scroll.anchor_right = 0.5
 choice_scroll.visible = menu_open or hs.is_empty()
 choice_scroll.anchor_top = 0.31
 menu_btn.text = "إخفاء القائمة" if choice_scroll.visible else "كل الأنشطة"
 for h in hs:
  var rr: Array = h["rect"]
  var b := Button.new()
  b.name = "Hot_" + str(h["id"])
  b.focus_mode = Control.FOCUS_NONE
  b.anchor_left = rr[0]
  b.anchor_top = rr[1]
  b.anchor_right = rr[0] + rr[2]
  b.anchor_bottom = rr[1] + rr[3]
  b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  b.add_theme_stylebox_override("normal", mk_style(Color(1, 1, 1, 0.0), 14))
  b.add_theme_stylebox_override("hover", mk_style(Color(1, 0.95, 0.8, 0.12), 14, GOLD, 2))
  b.add_theme_stylebox_override("pressed", mk_style(Color(1, 0.8, 0.4, 0.28), 14, GOLD, 3))
  b.add_theme_stylebox_override("focus", mk_style(Color(1, 1, 1, 0.0), 14))
  var hd: Dictionary = h
  b.pressed.connect(func(): hotspot_pressed(hd))
  hotspot_layer.add_child(b)
  var lb := Label.new()
  lb.text = str(h["label"])
  lb.add_theme_font_size_override("font_size", 17)
  lb.add_theme_color_override("font_color", Color("#fff6e8"))
  lb.add_theme_stylebox_override("normal", pill_style(Color(0.18, 0.32, 0.55, 0.82) if h.has("to") else Color(0.08, 0.08, 0.13, 0.72)))
  lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
  lb.anchor_left = 0.5
  lb.anchor_right = 0.5
  var lp: float = float(h.get("lp", 0.0))
  lb.anchor_top = lp
  lb.anchor_bottom = lp
  lb.grow_horizontal = Control.GROW_DIRECTION_BOTH
  lb.offset_top = 4
  lb.offset_bottom = 34
  b.add_child(lb)
  if fx_level > 0:
   var tw := lb.create_tween().set_loops()
   tw.tween_property(lb, "modulate:a", 0.72, 1.6).set_trans(Tween.TRANS_SINE)
   tw.tween_property(lb, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
 var gsc := available_group_scene(location)
 if not gsc.is_empty():
  var sb := Button.new()
  sb.name = "GroupScene"
  sb.text = "سالفة: " + str(gsc["title"])
  sb.focus_mode = Control.FOCUS_NONE
  sb.anchor_left = 0.5
  sb.anchor_right = 0.5
  sb.anchor_top = 0.215
  sb.grow_horizontal = Control.GROW_DIRECTION_BOTH
  sb.custom_minimum_size = Vector2(0, 52)
  sb.add_theme_font_size_override("font_size", 20)
  sb.add_theme_color_override("font_color", Color("#1b1b1b"))
  sb.add_theme_stylebox_override("normal", pill_style(Color("#ffd34d")))
  sb.add_theme_stylebox_override("hover", pill_style(Color("#ffe17a")))
  sb.add_theme_stylebox_override("pressed", pill_style(Color("#d08a5a")))
  var gd: Dictionary = gsc
  sb.pressed.connect(func(): play_group_scene(gd, 0))
  hotspot_layer.add_child(sb)
  if fx_level > 0:
   var tw := sb.create_tween().set_loops()
   tw.tween_property(sb, "modulate", Color(1.12, 1.1, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
   tw.tween_property(sb, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
 for ex in rd["exits"]:
  var eb := Button.new()
  eb.text = "%s %s" % [str(RoomsData.EXIT_ICONS.get(ex, "")), ex]
  eb.focus_mode = Control.FOCUS_NONE
  eb.custom_minimum_size = Vector2(0, 48)
  eb.add_theme_font_size_override("font_size", 17)
  eb.add_theme_stylebox_override("normal", pill_style(Color(0.18, 0.32, 0.55, 0.86)))
  eb.add_theme_stylebox_override("hover", pill_style(Color(0.25, 0.42, 0.7, 0.95)))
  eb.add_theme_stylebox_override("pressed", pill_style(Color(0.82, 0.54, 0.35, 0.95)))
  var dest: String = ex
  eb.pressed.connect(func(): go(dest))
  exits_box.add_child(eb)

func room_intro():
 if not room_active(): return
 var rd: Dictionary = RoomsData.ROOMS[location]
 if sprite_nodes.has("ليان"):
  if is_instance_valid(note) and note.text.begins_with("ليان مو هنا"): note.text = ""
  if not ("جائعة" in layan_activity or "تحتاج" in layan_activity):
   layan_activity = "معك في " + location
   update_status()
  var g: Array = TalkData.GREET.get(period, TalkData.GREET[0])
  speaker.text = "ليان"
  dialogue.text = str(g[randi() % g.size()]) + "\n" + str(rd["desc"])
 else:
  speaker.text = location
  dialogue.text = str(rd["desc"])

func _set_sprite_x(v: float, b, sh):
 if is_instance_valid(b):
  b.anchor_left = v
  b.anchor_right = v
 if sh != null and is_instance_valid(sh):
  sh.anchor_left = v
  sh.anchor_right = v

# ليان تمشي نحو الغرض (حركة أفقية ناعمة مع تمايل بسيط)، ثم ينفذ التفاعل
func walk_layan(cx: float, cb: Callable):
 var b: Control = sprite_nodes.get("ليان", null)
 if b == null or fx_level == 0 or not is_instance_valid(b):
  cb.call()
  return
 var sh = b.get_meta("shadow") if b.has_meta("shadow") else null
 var from: float = b.anchor_left
 var dist: float = absf(cx - from)
 if dist < 0.04:
  cb.call()
  return
 _walking = true
 var dur: float = clampf(dist * 1.5, 0.3, 0.85)
 var tw := b.create_tween()
 tw.tween_method(_set_sprite_x.bind(b, sh), from, cx, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 var steps := maxi(1, int(dur / 0.22))
 var bob := b.create_tween()
 for i in steps:
  bob.tween_property(b, "rotation_degrees", 1.4 if i % 2 == 0 else -1.4, dur / steps * 0.5)
  bob.tween_property(b, "rotation_degrees", 0.0, dur / steps * 0.5)
 tw.finished.connect(func():
  _walking = false
  cb.call())

func hotspot_pressed(h: Dictionary):
 if _walking: return
 if h.has("to"):
  go(str(h["to"]))
  return
 var act: String = str(h["act"])
 if bool(h.get("walk", false)) and sprite_nodes.has("ليان"):
  var rr: Array = h["rect"]
  walk_layan(clampf(float(rr[0]) + float(rr[2]) * 0.5, 0.16, 0.84), func(): hotspot_action(act))
 else:
  hotspot_action(act)

# انتقال جلوس/وقوف: الصورة تنخفض وتتلاشى ثم تظهر الوضعية الجديدة
func pose_transition(pose: String, after: Callable):
 var b: Control = sprite_nodes.get("ليان", null)
 if b == null or fx_level == 0 or not is_instance_valid(b):
  show_pose(pose)
  after.call()
  return
 _walking = true
 var tw := b.create_tween().set_parallel(true)
 tw.tween_property(b, "modulate:a", 0.0, 0.24)
 tw.tween_property(b, "scale", Vector2(1.0, 0.94), 0.24)
 tw.tween_property(b, "position:y", b.position.y + 26.0, 0.24)
 tw.chain().tween_callback(func():
  _walking = false
  show_pose(pose)
  after.call())

func back_choice():
 choice("رجوع", func(): go(location))

func hotspot_action(act: String):
 var here := sprite_nodes.has("ليان")
 match act:
  "tv":
   say("التلفزيون", "وش تبي تشوف؟")
   if here: choice("شاهدوا مع بعض (+3 علاقة)", tv_time)
   choice("الأخبار لحالك (+4 طاقة)", func():
    energy = mini(100, energy + 4)
    note.text = "شفت الأخبار شوي."
    advance())
   back_choice()
  "sofa":
   say("الكنبة", "مكان الجلسة الهادية.")
   if here:
    choice("اجلسوا مع بعض (+3 علاقة)", func(): pose_transition("sofa_game", sofa_sit))
    choice("خل ليان ترتاح", layan_sit)
   choice("استرخِ شوي (+10 طاقة)", relax)
   back_choice()
  "book":
   say("الطاولة", "كتب ومجلات.")
   choice("اقرأ كتاب (+8 طاقة)", read_book)
   if here:
    choice("اقرأ لليان بصوت عالي (+3 علاقة)", func():
     rel_once("readaloud", 3)
     note.text = "قريت لليان فصل من روايتها المفضلة."
     advance())
   back_choice()
  "plan": daily_schedule()
  "fridge":
   say("الثلاجة", "الثلاجة: موية وعصير وأغراض الطبخ.")
   if here:
    choice("ليان تشرب ماء", layan_drink)
    choice("سناك سريع لليان", layan_eat)
   choice("مشتريات البيت (-40 ريال)", groceries)
   back_choice()
  "stove":
   say("الفرن", "وقت الطبخ.")
   if here:
    choice("ليان تطبخ وجبة (الخطوات كاملة)", layan_cook)
    choice("اطبخوا الفطور سوا (+5 علاقة)", cook)
   else:
    choice("اطبخ أنت شي بسيط", dishes)
   back_choice()
  "island":
   say("طاولة الأكل", "الأكل أحلى مع بعض.")
   if here:
    choice("كلوا مع بعض (+4 علاقة)", eat_together)
    choice("ليان تاكل", layan_eat)
   back_choice()
  "sink":
   say("المغسلة", "الصحون تنتظر.")
   choice("اغسل الصحون", dishes)
   back_choice()
  "bed":
   say("السرير", "السرير مرتب وريحته حلوة.")
   if here:
    choice("ليان تنام وترتاح", layan_sleep)
    if period >= 2: choice("سوالف قبل النوم", talk)
   choice("خذ قيلولة (يمر الوقت)", wait_period)
   back_choice()
  "closet": wardrobe()
  "vanity":
   say("التسريحة", "عطور ومكياج وأمشاط.")
   choice("روتين العناية", skincare)
   if here:
    choice("سرّح شعر ليان (+3 علاقة)", func():
     rel_once("hair", 3)
     mood = "مبسوطة"
     say("ليان", "ههه، يدك خفيفة! من وين تعلمت؟")
     note.text = "سرحت شعر ليان وربطته لها."
     back_choice()
     update_status())
   back_choice()
  "window":
   var views := ["الشمس طالعة والحي هادي، وصوت العصافير واضح.", "حر الظهر واضح، والشارع فاضي.", "السماء برتقالية، والجيران يتمشون.", "الليل هادي، والقمر واضح فوق البيوت."]
   say("النافذة", views[period])
   choice("انتظر شوي (يمر الوقت)", wait_period)
   back_choice()
  "shower":
   say("الدش", "روتين الاستحمام بخصوصية؛ البخار يغطي المشهد.")
   choice("روتين الاستحمام الكامل", func(): live_shower(0))
   choice("دش سريع", bathing)
   choice("كثافة البخار: " + steam_density_name(), func():
    cycle_steam_density()
    hotspot_action("shower"))
   back_choice()
  "tub": tub_bath()
  "towel":
   say("المناشف", "مناشف نظيفة ومطوية.")
   choice("جهّز منشفة دافية لليان (+1 علاقة)", func():
    rel_once("towel", 1)
    note.text = "حطيت منشفة دافية جنب الدش."
    go(location))
   choice("اختيار ملابس بعد الاستحمام", wardrobe)
   back_choice()
  "bsink": bath_sink()
  "bshelf":
   say("رف العناية", "كريمات وماسكات وزيوت للشعر.")
   choice("العناية بالبشرة (+5 مزاج)", skincare)
   choice("ماسك للوجه مع ليان (+3 علاقة)", face_mask)
   back_choice()
  "washer":
   say("الغسالة", "حمولات الملابس المتراكمة: %d" % laundry)
   choice("شغّل الغسالة", do_laundry)
   choice("اطلب من نورة (-25 ريال)", helper_laundry)
   back_choice()
  "lshelf":
   house_cleanliness = mini(100, house_cleanliness + 5)
   energy = maxi(0, energy - 3)
   add_skill("التنظيم")
   note.text = "رتبت رف المنظفات (+5% نظافة)."
   go(location)
  "lounger":
   say("كرسي المساج", "جلسة استرخاء هادية.")
   choice("مساج استرخاء لليان (-20 ريال)", func(): massage("ليان", 20))
   choice("نورة تجهز الغرفة (-10 ريال)", massage_prep)
   back_choice()
  "rcouch": relax()
  "outside":
   say("الباب الأمامي", "وين تبي تروح؟")
   choice("الحديقة", func(): go("الحديقة"))
   choice("المقهى", func(): go("المقهى"))
   choice("السوبرماركت", func(): go("السوبرماركت"))
   choice("الشاطئ", func(): go("الشاطئ"))
   choice("خريطة المدينة", func(): open_map("city"))
   back_choice()
  "mirror":
   mood = "واثقة"
   note.text = "تشيك على شكلك قبل لا تطلع. تمام!"
   go(location)
  "nora_desk":
   if npc_present("نورة", location):
    character_scene("نورة")
   else:
    say("مكتب نورة", "نورة مو في غرفتها الحين. مكتبها مرتب وعليه دفتر مواعيد البيت.")
    choice("خطط مهام البيت", helper)
    back_choice()
  _:
   go(location)
 update_status()

# زيادة العلاقة من نفس التفاعل مرة وحدة بكل فترة (حتى ما تنفجر العلاقة بالتكرار)
func rel_once(key: String, amt: int) -> int:
 var k := "rel_%s_%d_%d" % [key, day, period]
 if daily_flags.has(k): return 0
 daily_flags[k] = true
 relationship = clampi(relationship + amt, 0, 100)
 return amt

func sofa_sit():
 rel_once("sofa", 3)
 layan_tiredness = maxi(0, layan_tiredness - 15)
 layan_activity = "جالسة معك على الكنبة"
 mood = "مرتاحة"
 var lines := ["تعال قربي... كذا أحسن.", "أحب هالجلسة، لا تقوم بسرعة.", "حط راسك هنا وقل لي وش صار اليوم."]
 say("ليان", lines[randi() % lines.size()])
 note.text = "جلستوا على الكنبة مع بعض (+3 علاقة)."
 choice("سولفوا", talk)
 choice("شغلوا التلفزيون", tv_time)
 choice("قوموا", func(): go(location))
 update_status()

func eat_together():
 rel_once("eat", 4)
 layan_hunger = maxi(0, layan_hunger - 30)
 mood = "راضية"
 note.text = "أكلتوا مع بعض على الطاولة (+4 علاقة)."
 kitchen_texture("13_serve.png")
 say("ليان", "الأكل يصير ألذ لما نجلس سوا.")
 choice("متابعة", advance)
 update_status()

func bath_sink():
 say("المغسلة والمرآة", "روتين سريع قدام المرآة.")
 choice("تفريش الأسنان وغسل الوجه (+3 طاقة)", func():
  energy = mini(100, energy + 3)
  mood = "منتعشة"
  note.text = "غسلت وجهك وفرشت أسنانك."
  go(location))
 choice("ليان تسرّح شعرها", func():
  layan_activity = "تسرّح شعرها قدام المرآة"
  show_pose("towel")
  say("ليان", "دقيقة بس أخلص شعري.")
  note.text = "ليان قدام المرآة تسرح شعرها."
  choice("تمام", func(): go(location)))
 back_choice()

func face_mask():
 rel_once("mask", 3)
 mood = "مبسوطة"
 say("ليان", "حط لك ماسك معي! ...ههه شكلك يضحك بالأخضر.")
 note.text = "سويتوا ماسك مع بعض (+3 علاقة)."
 choice("متابعة", func(): go(location))
 update_status()

# حمام البانيو: البخار كثيف ويغطي الشخصية بالكامل
func tub_bath():
 location = "الحمام"
 set_background("الحمام")
 steam_visible = true
 bath_mode = "tub"
 pose_override = ""
 sprite_focus = []
 explore_mode = false
 clear_cg()
 refresh_cards()
 layan_activity = "تسترخي في البانيو"
 layan_tiredness = maxi(0, layan_tiredness - 25)
 energy = mini(100, energy + 6)
 mood = "مسترخية"
 say("البانيو", "ماء دافي وفقاعات، والبخار مالي المكان. ليان تسترخي وتسكّر عيونها.")
 note.text = "حمام دافي في البانيو (-25 تعب لليان)."
 choice("أخذ المنشفة", finish_bathing)
 choice("رجوع للحمام", func(): go("الحمام"))
 update_status()

# ================= السوالف =================
func talk_ok(t: Dictionary) -> bool:
 var ps: Array = t.get("p", [])
 if not ps.is_empty() and not (period in ps): return false
 if relationship < int(t.get("min", 0)): return false
 if t.get("wk", false) and not is_weekend(): return false
 if t.has("preg") and not (preg_stage in t["preg"]): return false
 if t.get("baby", false) and preg_stage != 4: return false
 return true

func pick_talk() -> Dictionary:
 var pool: Array = []
 for t in TalkData.TALKS:
  if talk_ok(t) and not talks_seen.has(t["id"]): pool.append(t)
 if pool.is_empty():
  for t in TalkData.TALKS:
   if talk_ok(t):
    talks_seen.erase(t["id"])
    pool.append(t)
 if pool.is_empty(): return {}
 # الأولوية لسوالف الحمل والمولود إذا موجودة
 var special: Array = pool.filter(func(x): return x.has("preg") or x.get("baby", false))
 if not special.is_empty() and randi() % 2 == 0: pool = special
 return pool[randi() % pool.size()]

func talk_line(t: Dictionary, i: int):
 var lines: Array = t["lines"]
 var ln: Array = lines[i]
 say(str(ln[0]), str(ln[1]))
 if sprite_nodes.is_empty() or not sprite_nodes.has("ليان"):
  sprite_focus = ["ليان"]
  refresh_cards()
 if i < lines.size() - 1:
  choice("التالي", func(): talk_line(t, i + 1))
 else:
  for c in t["ch"]:
   var cd: Dictionary = c
   choice(str(cd["t"]), func(): talk_reply(t, cd))

func talk_reply(t: Dictionary, c: Dictionary):
 if not talks_seen.has(t["id"]): talks_seen.append(t["id"])
 var key := "talk_%d_%d" % [day, period]
 var n := int(daily_flags.get(key, 0))
 daily_flags[key] = n + 1
 var gain := int(c.get("rel", 0))
 if n >= 2 and gain > 0: gain = 0
 relationship = clampi(relationship + gain, 0, 100)
 mood = "سعيدة" if gain >= 3 else ("زعلانة شوي" if gain < 0 else "هادئة")
 say("ليان", str(c["r"]))
 if gain > 0: note.text = "سالفة حلوة مع ليان (+%d علاقة)." % gain
 elif gain < 0: note.text = "ليان زعلت شوي (%d علاقة). حاول تراضيها." % gain
 else: note.text = "سولفتوا كثير هالوقت؛ السوالف الجاية بعد شوي تفرق أكثر."
 choice("سولف معها بعد", talk)
 choice("رجوع", func(): go(location))
 update_status()

# ================= قصة المولود =================
func preg_day() -> int:
 return day - preg_start

func family_check() -> bool:
 if preg_stage == 0:
  if relationship >= FamilyData.START_REL and day >= FamilyData.START_DAY and period <= 2 and location != "الحمام" and layan_here(location):
   preg_stage = 1
   preg_start = day
   pre_preg_outfit = outfit
   relationship = mini(100, relationship + 6)
   save_game()
   story_lines("خبر سعيد", FamilyData.ANNOUNCE, 0, func():
    say("ليان", "ما أصدق! بنصير أهل!")
    choice("تحضنها وتفرح معها (+4 علاقة)", func():
     relationship = mini(100, relationship + 4)
     go("المنزل"))
    choice("تسكت من الفرحة ثم تضحك", func(): go("المنزل")))
   return true
  return false
 if preg_stage >= 1 and preg_stage <= 3:
  var d := preg_day()
  if d >= FamilyData.STAGE_DAYS * 3:
   birth_scene()
   return true
  var target := 1 + d / FamilyData.STAGE_DAYS
  if target > preg_stage:
   preg_stage = target
   var mat_ok := ResourceLoader.exists(str(outfit_textures.get(FamilyData.MATERNITY_OUTFIT, "")).replace("layan_outfits", "sprites/layan"))
   if preg_stage == 3 and mat_ok and not owned_outfits.has(FamilyData.MATERNITY_OUTFIT):
    owned_outfits.append(FamilyData.MATERNITY_OUTFIT)
   if preg_stage == 3 and mat_ok: outfit = FamilyData.MATERNITY_OUTFIT
   save_game()
   var ms: Dictionary = FamilyData.MILESTONES[preg_stage]
   story_lines(str(ms["title"]), ms["lines"], 0, func(): go("المنزل"))
   return true
  if preg_stage <= 2 and int(daily_flags.get("crave_day", 0)) != day:
   daily_flags["crave_day"] = day
   craving = FamilyData.CRAVINGS[randi() % FamilyData.CRAVINGS.size()]
   craving_bought = ""
   if is_instance_valid(note): note.text = "ليان تتوحم اليوم على: %s" % craving
  return false
 if preg_stage == 4 and period == 3:
  var ck := "cry_%d" % day
  if not daily_flags.has(ck):
   daily_flags[ck] = true
   if randi() % 2 == 0:
    say("%s %s!" % [baby_name, gx("يبكي", "تبكي")], "صوت بكاء من غرفة النوم... ليان شكلها تعبانة.")
    choice("قوم أنت و%s (-8 طاقة، +5 علاقة)" % gx("هدّيه", "هدّيها"), func():
     energy = maxi(0, energy - 8)
     relationship = mini(100, relationship + 5)
     say("ليان", gx("الله يخليك لي... نام على صدرك.", "الله يخليك لي... نامت على صدرك."))
     choice("متابعة", func(): go("المنزل")))
    choice("خل ليان تقوم (-2 علاقة)", func():
     relationship = maxi(0, relationship - 2)
     say("ليان", "...طيب، أنا بقوم.")
     choice("متابعة", func(): go("المنزل")))
    update_status()
    return true
 return false

func story_lines(title: String, lines: Array, i: int, done: Callable):
 say(title, str(lines[i]))
 note.text = title
 if i < lines.size() - 1:
  choice("التالي", func(): story_lines(title, lines, i + 1, done))
 else:
  choice("متابعة", done)
 update_status()

func preg_stage_name() -> String:
 return ["", "بداية الحمل", "منتصف الحمل", "الشهور الأخيرة", "بعد الولادة"][preg_stage]

func preg_menu():
 var d := preg_day()
 var info := "المرحلة: %s • اليوم %d من %d" % [preg_stage_name(), d + 1, FamilyData.STAGE_DAYS * 3]
 if craving != "": info += "\nالوحم اليوم: %s%s" % [craving, " (اشتريته)" if craving_bought == craving else ""]
 if preg_stage >= 2: info += "\nغرفة البيبي: %d من %d" % [nursery.size(), FamilyData.NURSERY.size()]
 if baby_gender != "": info += "\nالجنس: %s" % ("ولد" if baby_gender == "boy" else "بنت")
 sprite_focus = ["ليان"]
 clear_cg()
 refresh_cards()
 say("ليان والحمل", info)
 if not preg_flags.has("doc%d" % preg_stage):
  choice("موعد الدكتورة (-%d ريال)" % FamilyData.DOCTOR_COST, doctor_visit)
 if craving != "" and craving_bought == craving:
  choice("اعطها %s (+5 علاقة)" % craving, func():
   relationship = mini(100, relationship + 5)
   say("ليان", "يااااه! كنت أحلم فيه من الصبح. أنت أحسن زوج!")
   note.text = "ليان فرحت بالوحم."
   craving = ""
   craving_bought = ""
   choice("رجوع", func(): go(location))
   update_status())
 elif craving != "":
  choice("اسألها وش تشتهي", func():
   say("ليان", "أبي %s... الحين!" % craving)
   choice("أروح السوبرماركت", func(): go("السوبرماركت"))
   choice("رجوع", func(): go(location)))
 var mk := "rub_%d_%d" % [day, period]
 if not daily_flags.has(mk):
  choice("دلّك رجولها وريّحها (+3 علاقة)", func():
   daily_flags[mk] = true
   relationship = mini(100, relationship + 3)
   layan_tiredness = maxi(0, layan_tiredness - 15)
   say("ليان", "الله... ارتحت. التعب راح نصه.")
   choice("رجوع", func(): go(location))
   update_status())
 choice("سولف معها", talk)
 if preg_stage >= 2: choice("تجهيز غرفة البيبي", nursery_menu)
 choice("رجوع", func(): go(location))
 update_status()

func doctor_visit():
 if money < FamilyData.DOCTOR_COST:
  note.text = "الرصيد ما يكفي لموعد الدكتورة."
  return
 money -= FamilyData.DOCTOR_COST
 preg_flags.append("doc%d" % preg_stage)
 relationship = mini(100, relationship + 4)
 say("عيادة الدكتورة", str(FamilyData.DOCTOR[preg_stage]))
 note.text = "موعد الدكتورة (+4 علاقة)."
 if preg_stage == 2 and baby_gender == "":
  choice("إيه، نبي نعرف", func():
   baby_gender = "boy" if randi() % 2 == 0 else "girl"
   say("الدكتورة", "مبروك... %s!" % ("ولد" if baby_gender == "boy" else "بنت"))
   note.text = "عرفتوا جنس البيبي."
   choice("متابعة", advance))
  choice("خلوها مفاجأة", advance)
 else:
  choice("متابعة", advance)
 update_status()

func buy_craving():
 if money < FamilyData.CRAVING_COST:
  note.text = "الرصيد ما يكفي."
  return
 money -= FamilyData.CRAVING_COST
 craving_bought = craving
 note.text = "اشتريت %s لليان. وصّله لها من «ليان والحمل» بالبيت." % craving
 go(location)

func nursery_menu():
 say("غرفة البيبي", "جهّز غرفة التخزين لتصير غرفة البيبي. (%d من %d)" % [nursery.size(), FamilyData.NURSERY.size()])
 for it in FamilyData.NURSERY:
  var nm: String = it[0]
  var pr: int = it[1]
  if nursery.has(nm): continue
  choice("%s — %d ريال" % [nm, pr], func():
   if money < pr:
    note.text = "الرصيد ما يكفي."
    return
   money -= pr
   nursery.append(nm)
   relationship = mini(100, relationship + 2)
   house_cleanliness = mini(100, house_cleanliness + 2)
   note.text = "اشتريت %s لغرفة البيبي (+2 علاقة)." % nm
   update_status()
   nursery_menu())
 if nursery.size() >= FamilyData.NURSERY.size():
  note.text = "غرفة البيبي جاهزة بالكامل! ليان مرة فرحانة."
 choice("رجوع", func(): go(location))
 update_status()

func birth_scene():
 if ResourceLoader.exists("res://assets/backgrounds/hospital.jpg"):
  clear_cg()
  bg_tex.texture = load("res://assets/backgrounds/hospital.jpg")
 story_lines("المولود", FamilyData.BIRTH, 0, func():
  if baby_gender == "": baby_gender = "boy" if randi() % 2 == 0 else "girl"
  var names: Array = FamilyData.BOY_NAMES if baby_gender == "boy" else FamilyData.GIRL_NAMES
  say("ليان", "%s... وش نسميه؟" % ("ولدنا" if baby_gender == "boy" else "بنتنا"))
  for nm in names:
   var n2: String = nm
   choice(n2, func(): name_baby(n2)))

func name_baby(nm: String):
 baby_name = nm
 preg_stage = 4
 baby_born = day
 relationship = mini(100, relationship + 10)
 if pre_preg_outfit != "" and owned_outfits.has(pre_preg_outfit): outfit = pre_preg_outfit
 craving = ""
 craving_bought = ""
 var extra := ""
 if nursery.has("حقيبة المستشفى"): extra = "\nالحمد لله إن حقيبة المستشفى كانت جاهزة."
 if nursery.size() >= FamilyData.NURSERY.size(): extra += "\nرجعتوا البيت وغرفة البيبي جاهزة ومرتبة."
 save_game()
 say("%s" % nm, "أهلًا بـ%s في بيتكم! ليان %s وقالت: «الحين البيت صار كامل.»%s" % [nm, gx("ضمّته", "ضمّتها"), extra])
 note.text = "صار عندكم مولود: %s (+10 علاقة)." % nm
 choice("متابعة", func(): go("المنزل"))
 update_status()

func gx(boy: String, girl: String) -> String:
 return girl if baby_gender == "girl" else boy

func baby_menu():
 var age := day - baby_born
 sprite_focus = ["ليان"]
 clear_cg()
 refresh_cards()
 say("%s" % baby_name, "عمر %s: %d يوم. وش تسوي %s الحين؟" % [baby_name, age, gx("معه", "معها")])
 for c in FamilyData.BABY_CARE:
  var cc: Array = c
  var label := gx(str(cc[0]), str(cc[4]))
  var key := "baby_%s_%d_%d" % [str(cc[0]), day, period]
  if daily_flags.has(key): continue
  choice("%s (+%d علاقة)" % [label, int(cc[2])], func():
   daily_flags[key] = true
   energy = clampi(energy + int(cc[1]), 0, 100)
   relationship = mini(100, relationship + int(cc[2]))
   say("ليان", gx(str(cc[3]), str(cc[5])))
   note.text = "%s (%s)." % [label, baby_name]
   choice("متابعة", baby_menu)
   choice("رجوع", func(): go(location))
   update_status())
 choice("سولف مع ليان", talk)
 choice("رجوع", func(): go(location))
 update_status()


# ================= استحمام حي: ليان تدخل الحمام وتستحم ورا زجاج الدش =================
# الشخصية صورتها الكاملة نفسها؛ ورا الزجاج تتحول لظل ناعم (بدون تفاصيل) والزجاج المضبب يغبّش اللي وراه.
const LIVE_SHOWER := [
 ["enter", "تدخل ليان الحمام وتسكّر الباب وراها."],
 ["water", "تفتح الماء الدافي، ويبدأ البخار يطلع."],
 ["inside", "تدخل ورا زجاج الدش... والبخار يغطي المكان."],
 ["hair", "تغسل شعرها بهدوء."],
 ["rinse", "تشطف الشامبو وتميل براسها."],
 ["turn", "تلتفت والماء ينزل على كتوفها."],
 ["relax", "توقف شوي وتستمتع بالماء الدافي."],
 ["off", "تسكّر الماء، والبخار يخف شوي شوي."]
]
const SIL_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.80, 0.72, 1.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * (1.0 + 7.0 * amount);
	vec4 acc = vec4(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			acc += texture(TEXTURE, UV + vec2(float(x), float(y)) * px);
		}
	}
	acc /= 25.0;
	vec4 orig = texture(TEXTURE, UV);
	vec3 sil = mix(acc.rgb, tint.rgb, 0.82);
	COLOR.rgb = mix(orig.rgb, sil, amount);
	COLOR.a = mix(orig.a, acc.a * 0.9, amount);
}
"""
const GLASS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * (1.0 + 5.0 * strength);
	vec4 acc = vec4(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			acc += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * ps);
		}
	}
	acc /= 25.0;
	vec3 frost = vec3(0.93, 0.96, 1.0);
	COLOR = vec4(mix(acc.rgb, frost, 0.16 * strength), 1.0);
}
"""

func shower_clear():
 if is_instance_valid(scene_layer):
  for c in scene_layer.get_children():
   scene_layer.remove_child(c)
   c.queue_free()
 _sh = {}

func _shower_rect_px() -> Rect2:
 var sr: Array = SHOWER_RECT
 return Rect2(1280.0 * float(sr[0]), 720.0 * float(sr[1]), 1280.0 * float(sr[2]), 720.0 * float(sr[3]))

func _shower_setup():
 shower_clear()
 location = "الحمام"
 set_background("الحمام")
 clear_cg()
 bath_mode = "live"
 pose_override = ""
 sprites_layer.visible = false
 clear_fx()
 _fx_key = ""
 var tex: Texture2D = load(layan_sprite_path())
 var fig := TextureRect.new()
 fig.name = "Layan"
 fig.texture = tex
 fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 fig.stretch_mode = TextureRect.STRETCH_SCALE
 fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var h := 720.0 * 0.6
 var w := h * float(tex.get_width()) / float(tex.get_height())
 fig.size = Vector2(w, h)
 fig.pivot_offset = Vector2(w * 0.5, h)
 fig.position = Vector2(1300.0, 720.0 * 0.86 - h)
 var mat := ShaderMaterial.new()
 var sh := Shader.new()
 sh.code = SIL_SHADER
 mat.shader = sh
 fig.material = mat
 scene_layer.add_child(fig)
 _sh["fig"] = fig
 var drops := Control.new()
 drops.mouse_filter = Control.MOUSE_FILTER_IGNORE
 drops.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene_layer.add_child(drops)
 _sh["drops"] = drops
 var r := _shower_rect_px()
 var glass := ColorRect.new()
 glass.position = r.position
 glass.size = r.size
 glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var gm := ShaderMaterial.new()
 var gs := Shader.new()
 gs.code = GLASS_SHADER
 gm.shader = gs
 gm.set_shader_parameter("strength", 0.0)
 glass.material = gm
 scene_layer.add_child(glass)
 _sh["glass"] = glass
 var steam := Control.new()
 steam.mouse_filter = Control.MOUSE_FILTER_IGNORE
 steam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 steam.modulate.a = 0.0
 scene_layer.add_child(steam)
 _sh["steam"] = steam
 _shower_build_steam()

func _shower_build_steam():
 var steam: Control = _sh.get("steam")
 if steam == null: return
 for c in steam.get_children():
  steam.remove_child(c)
  c.queue_free()
 var r := _shower_rect_px()
 var n: int = [6, 9, 13][steam_density]
 if fx_level == 1: n = maxi(3, n / 2)
 var a: float = [0.3, 0.55, 1.0][steam_density]
 for i in n:
  var t := TextureRect.new()
  t.texture = fog_texture()
  t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  t.stretch_mode = TextureRect.STRETCH_SCALE
  t.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var s := randf_range(r.size.x * 0.6, r.size.x * 1.1)
  t.size = Vector2(s, s * 0.85)
  t.position = Vector2(r.position.x + randf_range(-0.2, 0.8) * r.size.x - s * 0.25, r.position.y + randf_range(0.0, 0.85) * r.size.y - s * 0.3)
  t.modulate = Color(1.0, 0.95, 0.93, a * randf_range(0.55, 0.9))
  steam.add_child(t)
  if fx_level > 0:
   var tw := t.create_tween().set_loops()
   var dur := randf_range(5.0, 9.0)
   var dx := randf_range(20.0, 45.0) * (1.0 if i % 2 == 0 else -1.0)
   tw.tween_property(t, "position", t.position + Vector2(dx, -randf_range(15.0, 35.0)), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
   tw.tween_property(t, "position", t.position, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 if steam_density == 2:
  # أقصى كثافة: بخار كثيف يغطي ليان بالكامل داخل الدش
  for i in 3:
   var t := TextureRect.new()
   t.texture = fog_texture()
   t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   t.stretch_mode = TextureRect.STRETCH_SCALE
   t.mouse_filter = Control.MOUSE_FILTER_IGNORE
   t.size = Vector2(r.size.x * 1.6, r.size.y * 0.75)
   t.position = Vector2(r.position.x + r.size.x * 0.5 - t.size.x * 0.5, r.position.y + r.size.y * (0.05 + 0.3 * i) - t.size.y * 0.2)
   t.modulate = Color(1.0, 0.95, 0.93, 1.0)
   steam.add_child(t)

func _shower_water(on: bool):
 var drops: Control = _sh.get("drops")
 if drops == null: return
 for c in drops.get_children():
  drops.remove_child(c)
  c.queue_free()
 if not on or fx_level == 0: return
 var r := _shower_rect_px()
 var head := Vector2(r.position.x + r.size.x * 0.36, r.position.y + r.size.y * 0.14)
 var n := 26 if fx_level == 2 else 12
 for i in n:
  var d := ColorRect.new()
  d.color = Color(0.85, 0.93, 1.0, randf_range(0.25, 0.55))
  d.size = Vector2(2, randf_range(10.0, 22.0))
  d.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var x := head.x + randf_range(-r.size.x * 0.2, r.size.x * 0.2)
  d.position = Vector2(x, head.y)
  drops.add_child(d)
  var tw := d.create_tween().set_loops()
  tw.tween_interval(randf_range(0.0, 0.6))
  tw.tween_property(d, "position:y", r.position.y + r.size.y * 0.97, randf_range(0.45, 0.7)).from(head.y)
  tw.tween_callback(func(): d.position.x = head.x + randf_range(-r.size.x * 0.2, r.size.x * 0.2))

func _shower_gesture(kind: String):
 var fig: TextureRect = _sh.get("fig")
 if fig == null or fx_level == 0: return
 if _sh.has("gesture"):
  var old = _sh["gesture"]
  if old is Tween and old.is_valid(): old.kill()
 fig.rotation_degrees = 0.0
 var tw := fig.create_tween().set_loops()
 match kind:
  "hair":
   tw.tween_property(fig, "scale", Vector2(1.0, 1.025), 0.45).set_trans(Tween.TRANS_SINE)
   tw.parallel().tween_property(fig, "rotation_degrees", -1.6, 0.45)
   tw.tween_property(fig, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
   tw.parallel().tween_property(fig, "rotation_degrees", 1.2, 0.45)
  "rinse":
   tw.tween_property(fig, "rotation_degrees", 3.0, 1.2).set_trans(Tween.TRANS_SINE)
   tw.tween_property(fig, "rotation_degrees", -1.0, 1.2).set_trans(Tween.TRANS_SINE)
  "turn":
   tw.tween_property(fig, "scale:x", 0.0, 0.35)
   tw.tween_callback(func(): fig.flip_h = not fig.flip_h)
   tw.tween_property(fig, "scale:x", 1.0, 0.35)
   tw.tween_interval(2.2)
  _:
   tw.tween_property(fig, "scale", Vector2(1.012, 1.02), 1.8).set_trans(Tween.TRANS_SINE)
   tw.tween_property(fig, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_SINE)
 _sh["gesture"] = tw

func _shower_walk(to_x: float, dur: float, then: Callable = Callable()):
 var fig: TextureRect = _sh.get("fig")
 if fig == null: return
 var tw := fig.create_tween()
 tw.tween_property(fig, "position:x", to_x, dur if fx_level > 0 else 0.01).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 if fx_level > 0:
  var bob := fig.create_tween()
  var steps := maxi(2, int(dur / 0.3))
  for i in steps:
   bob.tween_property(fig, "rotation_degrees", 1.6 if i % 2 == 0 else -1.6, dur / steps * 0.5)
   bob.tween_property(fig, "rotation_degrees", 0.0, dur / steps * 0.5)
 if then.is_valid(): tw.finished.connect(then)

func live_shower(i: int):
 var st: Array = LIVE_SHOWER[i]
 var act: String = st[0]
 if i == 0 or not _sh.has("fig"):
  _shower_setup()
 var fig: TextureRect = _sh.get("fig")
 var r := _shower_rect_px()
 steam_visible = true
 layan_activity = "تستحم في الحمام"
 match act:
  "enter":
   _shower_walk(1280.0 * 0.6 - fig.size.x * 0.5, 1.6)
  "water":
   _shower_water(true)
   var steam: Control = _sh["steam"]
   steam.create_tween().tween_property(steam, "modulate:a", 0.45, 2.5)
  "inside":
   if not (_sh.get("drops") as Control).get_child_count(): _shower_water(true)
   var target_x := r.position.x + r.size.x * 0.5 - fig.size.x * 0.46
   fig.create_tween().tween_property(fig, "scale", Vector2(0.94, 0.94), 1.4)
   _shower_walk(target_x, 1.4, func():
    var mat: ShaderMaterial = fig.material
    fig.create_tween().tween_method(func(v): mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.9)
    var gm: ShaderMaterial = (_sh["glass"] as ColorRect).material
    fig.create_tween().tween_method(func(v): gm.set_shader_parameter("strength", v), 0.0, 1.0, 1.2)
    var steam: Control = _sh["steam"]
    steam.create_tween().tween_property(steam, "modulate:a", 1.0, 2.5)
    _shower_gesture("relax"))
  "off":
   _shower_water(false)
   _shower_gesture("relax")
   var steam: Control = _sh["steam"]
   steam.create_tween().tween_property(steam, "modulate:a", 0.4, 2.5)
  _:
   _instant_inside()
   _shower_gesture(act)
 say("ليان", str(st[1]))
 note.text = "استحمام %d/%d" % [i + 1, LIVE_SHOWER.size()]
 if i < LIVE_SHOWER.size() - 1:
  choice("التالي", func(): live_shower(i + 1))
 else:
  choice("تاخذ المنشفة", live_shower_end)
 choice("كثافة البخار: " + steam_density_name(), func():
  cycle_steam_density()
  _shower_build_steam()
  say("ليان", str(st[1]))
  live_shower_menu(i))
 choice("إنهاء الروتين", live_shower_end)
 update_status()

func live_shower_menu(i: int):
 if i < LIVE_SHOWER.size() - 1:
  choice("التالي", func(): live_shower(i + 1))
 else:
  choice("تاخذ المنشفة", live_shower_end)
 choice("كثافة البخار: " + steam_density_name(), func():
  cycle_steam_density()
  _shower_build_steam()
  say("ليان", str(LIVE_SHOWER[i][1]))
  live_shower_menu(i))
 choice("إنهاء الروتين", live_shower_end)

# إذا اللاعب تخطى خطوات: نحطها داخل الدش مباشرة
func _instant_inside():
 var fig: TextureRect = _sh.get("fig")
 if fig == null: return
 var r := _shower_rect_px()
 fig.position.x = r.position.x + r.size.x * 0.5 - fig.size.x * 0.46
 fig.scale = Vector2(0.94, 0.94)
 (fig.material as ShaderMaterial).set_shader_parameter("amount", 1.0)
 ((_sh["glass"] as ColorRect).material as ShaderMaterial).set_shader_parameter("strength", 1.0)
 (_sh["steam"] as Control).modulate.a = 1.0
 if (_sh["drops"] as Control).get_child_count() == 0: _shower_water(true)

func live_shower_end():
 shower_clear()
 bath_mode = ""
 sprites_layer.visible = true
 finish_bathing()


# ================= مشاهد الحوار الجماعية =================
const SPEAKER_NPC := {"ليان": "ليان", "نورة": "نورة", "سارة": "سارة", "هند": "هند", "ميسون": "ميسون", "سلمى": "الشبح"}

func group_scene_ok(sc: Dictionary, place: String) -> bool:
 if story_seen.has(sc["id"]): return false
 var where: Array = sc.get("where", [])
 if where.is_empty():
  if not (place in WorldData.HOUSE_PLACES): return false
 elif not (place in where):
  return false
 var ps: Array = sc.get("p", [])
 if not ps.is_empty() and not (period in ps): return false
 if day < int(sc.get("day", 1)): return false
 var rel: Dictionary = sc.get("rel", {})
 for n in rel:
  var cur: int = relationship if n == "ليان" else int(character_relations.get(n, 0))
  if cur < int(rel[n]): return false
 for n in sc.get("who", []):
  if n == "ليان":
   if not layan_here(place): return false
  elif not npc_present(str(n), place):
   return false
 for f in sc.get("need", []):
  if not (story_seen.has(f) or has_flag(str(f))): return false
 if sc.has("preg") and not (preg_stage in sc["preg"]): return false
 if sc.get("baby", false) and preg_stage != 4: return false
 return true

func available_group_scene(place: String) -> Dictionary:
 if int(daily_flags.get("gs_day", 0)) == day: return {}
 for sc in ScenesData.SCENES:
  if group_scene_ok(sc, place): return sc
 return {}

func play_group_scene(sc: Dictionary, i: int):
 var lines: Array = sc["lines"]
 if i == 0:
  var cast: Array = []
  for n in sc.get("who", []) + sc.get("visit", []):
   var npc: String = str(SPEAKER_NPC.get(n, n))
   if WorldData.NPCS.has(npc) and not cast.has(npc) and cast.size() < 3: cast.append(npc)
  explore_mode = false
  clear_cg()
  sprite_focus = cast
  refresh_cards()
 var ln: Array = lines[i]
 say(str(ln[0]), str(ln[1]))
 note.text = "سالفة: %s (%d/%d)" % [str(sc["title"]), i + 1, lines.size()]
 _highlight_speaker(str(ln[0]))
 if i < lines.size() - 1:
  choice("التالي", func(): play_group_scene(sc, i + 1))
 else:
  for c in sc["ch"]:
   var cd: Dictionary = c
   choice(str(cd["t"]), func(): group_scene_choice(sc, cd))
 update_status()

func group_scene_choice(sc: Dictionary, c: Dictionary):
 if not story_seen.has(sc["id"]): story_seen.append(sc["id"])
 daily_flags["gs_day"] = day
 apply_fx(c.get("fx", {}))
 var rr: Array = c.get("r", ["ليان", "..."])
 say(str(rr[0]), str(rr[1]))
 _highlight_speaker(str(rr[0]))
 note.text = "انتهت السالفة: " + str(sc["title"])
 save_game()
 choice("متابعة", func(): go(location))
 update_status()

# المتكلم يبان أوضح، والباقين يخفّون شوي
func _highlight_speaker(who: String):
 var npc: String = str(SPEAKER_NPC.get(who, ""))
 for n in sprite_nodes:
  var b: Control = sprite_nodes[n]
  if not is_instance_valid(b): continue
  var on: bool = (npc == "") or (n == npc)
  b.modulate = Color(1, 1, 1, 1) if on else Color(0.72, 0.72, 0.78, 1)
