extends Control
# محرك الفيديو التفاعلي (IVG) لـ Godot — نسخة GDScript أصلية من محرك الويب «موتشي التفاعلي».
# يحوّل مقاطع فيديو عادية (.ogv) لمشهد يتفاعل معه اللاعب: لمس، ضغط مطوّل، مسح، سحب، حركات بوقت محدد (QTE)،
# اختيارات، عدادات، وانبعاج حي للصورة تحت الإصبع.
#
# الاستخدام:
#   var e = preload("res://ivg/ivg_engine.gd").new()
#   e.setup(scene_dict, "res://assets/ivg/hello/", {"muted": false, "debug": false})
#   e.finished.connect(func(result): ...)   # result = {vars, start_vars, reason, scene_id}
#   add_child(e)
#
# المشهد ملف JSON (نفس صيغة محرك الويب، شوف incoming/interactive/README-AR.md):
#   clips: المقاطع. كل مقطع: src, loop, then, inherit, hotspots, on, pause, qte, events, say, do, on_end
#   vars / meters: المتغيرات والعدادات.  start: اسم أول مقطع.
# الأوامر (do): play/go, add, set, say(+who,time), if/then/else, random(+weights), wait, toast, fx, choices, resume, save, stop.
# الحركات: tap, double, hold, swipe-left/right/up/down, rub, drag.

const Cond = preload("res://ivg/ivg_cond.gd")
const WARP = preload("res://ivg/ivg_warp.gdshader")

signal clip_started(clip_name)
signal hotspot_hit(id, gesture)
signal choice_taken(text)
signal vars_changed(vars)
signal finished(result)
signal _choice_done(token)

const BG := Color("#0d0a0c")
const PANEL := Color(0.07, 0.047, 0.063, 0.82)
const MUTED := Color("#cdbfc6")
const SLOP := 12.0

# شريحة عرض: إما مشغّل فيديو أو صورة ثابتة (ساعة افتراضية تعوّض الفيديو).
# كذا نفس المشهد يشتغل بصور اللعبة الحين، وتبدّل الصورة بفيديو بعدين بدون تغيير ثاني.
class Slot extends RefCounted:
	var video: VideoStreamPlayer
	var img: TextureRect
	var is_img := false
	var t0 := 0.0
	var dur := 0.0          # مدة الصورة بالثواني (0 = بلا نهاية)
	var paused_at := -1.0
	var stopped := false

	func node() -> Control:
		return img if is_img else video

	func _now() -> float:
		return Time.get_ticks_msec() / 1000.0

	func pos() -> float:
		if not is_img: return video.stream_position
		if stopped: return 0.0
		if paused_at >= 0.0: return paused_at
		return _now() - t0

	func is_playing() -> bool:
		if not is_img: return video.is_playing()
		if stopped: return false
		return dur <= 0.0 or pos() < dur

	func is_paused() -> bool:
		return video.paused if not is_img else paused_at >= 0.0

	func set_paused(p: bool):
		if not is_img:
			video.paused = p
		elif p and paused_at < 0.0:
			paused_at = _now() - t0
		elif not p and paused_at >= 0.0:
			t0 = _now() - paused_at
			paused_at = -1.0

	func stop():
		if is_img: stopped = true
		else: video.stop()

	func show_kind(image: bool):
		is_img = image
		img.visible = image
		video.visible = not image

	func start_image(tex: Texture2D, duration: float):
		img.texture = tex
		t0 = _now()
		dur = duration
		paused_at = -1.0
		stopped = false

	func size_px() -> Vector2:
		if is_img:
			return img.texture.get_size() if img.texture != null else Vector2.ZERO
		var t := video.get_video_texture()
		return t.get_size() if t != null else Vector2.ZERO

var scene: Dictionary = {}
var base := ""
var vars: Dictionary = {}
var start_vars: Dictionary = {}
var muted := false
var debug_hotspots := false
var accent := Color("#ff8fb1")

var _stage: Control
var _sa: Slot
var _sb: Slot
var _active: Slot
var _bg_tex: TextureRect
var _bg_path := ""
var _debug: Control
var _hint_layer: Control
var _touch_layer: Control
var _meters_box: PanelContainer
var _meters_vb: VBoxContainer
var _meter_bars: Dictionary = {}
var _sub: PanelContainer
var _sub_rt: RichTextLabel
var _choice_box: VBoxContainer
var _toast_box: VBoxContainer
var _close_btn: Button

var _cur: Dictionary = {}
var _mem := {"cool": {}, "combos": {}, "once": {}}
var _last_src: Dictionary = {}
var _streams: Dictionary = {}
var _play_token := 0
var _choice_token := 0
var _choice_timer: Dictionary = {}
var _sub_token := 0
var _started := false
var _ended := false
var _idle_since := 0.0
var _hint_sig := ""
var _hint_clock := 0.0
var _g: Dictionary = {}          # حالة الإصبع الحالية
var _last_tap: Dictionary = {}
var _fx := {"down": false, "px": 0.0, "py": 0.0, "sx": 0.0, "sy": 0.0, "t0": 0.0, "r": 40.0, "depth": 0.0, "vel": 0.0,
	"pull": Vector2.ZERO, "rel": 0.0, "ramp": 0.0, "shake0": 0.0, "pulse0": 0.0, "on": false}
var _mat: ShaderMaterial
var _last_rect := Rect2()

# ------------------------------------------------------------------ إعداد
func setup(scene_dict: Dictionary, base_dir: String, opts: Dictionary = {}):
	scene = scene_dict
	base = base_dir
	muted = bool(opts.get("muted", false))
	debug_hotspots = bool(opts.get("debug", scene.get("debug", false)))
	if scene.has("accent"): accent = Color(str(scene["accent"]))
	vars = (scene.get("vars", {}) as Dictionary).duplicate(true)
	if bool(scene.get("persist", false)):
		var s := _load_saved()
		if s.has("vars"):
			for k in s["vars"]: vars[k] = s["vars"][k]
	start_vars = vars.duplicate(true)

func _style(col: Color, radius := 14, margin := 10) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(radius)
	st.content_margin_left = margin
	st.content_margin_right = margin
	st.content_margin_top = margin * 0.6
	st.content_margin_bottom = margin * 0.6
	return st

func _full(c: Control, ignore := true):
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ignore: c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_slot() -> Slot:
	var sl := Slot.new()
	var p := VideoStreamPlayer.new()
	p.expand = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	sl.video = p
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = 0.0
	t.visible = false
	sl.img = t
	p.finished.connect(_on_player_finished.bind(sl))
	return sl

func _ready():
	_full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var bg := ColorRect.new()
	bg.color = BG
	_full(bg)
	add_child(bg)
	_bg_tex = TextureRect.new()
	_full(_bg_tex)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg_tex)
	_stage = Control.new()
	_full(_stage)
	add_child(_stage)
	_sa = _make_slot()
	_sb = _make_slot()
	for sl in [_sa, _sb]:
		_stage.add_child(sl.video)
		_stage.add_child(sl.img)
	_active = _sa
	_debug = Control.new()
	_full(_debug)
	_debug.draw.connect(_debug_draw)
	add_child(_debug)
	_hint_layer = Control.new()
	_full(_hint_layer)
	add_child(_hint_layer)
	_touch_layer = Control.new()
	_full(_touch_layer, false)
	_touch_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_touch_layer.gui_input.connect(_on_input)
	add_child(_touch_layer)
	_mat = ShaderMaterial.new()
	_mat.shader = WARP
	_build_hud()
	_idle_since = _now()
	_started = true
	_draw_meters()
	call_deferred("_begin")

func _build_hud():
	_meters_box = PanelContainer.new()
	_meters_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meters_box.add_theme_stylebox_override("panel", _style(PANEL, 12))
	_meters_box.anchor_left = 1.0
	_meters_box.anchor_right = 1.0
	_meters_box.offset_right = -12
	_meters_box.offset_top = 12
	_meters_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_meters_vb = VBoxContainer.new()
	_meters_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meters_box.add_child(_meters_vb)
	add_child(_meters_box)

	_sub = PanelContainer.new()
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_stylebox_override("panel", _style(PANEL, 14, 16))
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_left = 14
	_sub.offset_right = -14
	_sub.offset_bottom = -14
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.modulate.a = 0.0
	_sub_rt = RichTextLabel.new()
	_sub_rt.bbcode_enabled = true
	_sub_rt.fit_content = true
	_sub_rt.scroll_active = false
	_sub_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_rt.add_theme_font_size_override("normal_font_size", 28)
	_sub_rt.add_theme_font_size_override("bold_font_size", 28)
	_sub.add_child(_sub_rt)
	add_child(_sub)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.anchor_left = 0.5
	_choice_box.anchor_right = 0.5
	_choice_box.anchor_top = 1.0
	_choice_box.anchor_bottom = 1.0
	_choice_box.offset_left = -230
	_choice_box.offset_right = 230
	_choice_box.offset_bottom = -110
	_choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_box.visible = false
	add_child(_choice_box)

	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.offset_left = 12
	_toast_box.offset_top = 70
	_toast_box.add_theme_constant_override("separation", 6)
	add_child(_toast_box)

	_close_btn = Button.new()
	_close_btn.text = "إغلاق"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.add_theme_stylebox_override("normal", _style(PANEL, 20, 14))
	_close_btn.add_theme_stylebox_override("hover", _style(PANEL, 20, 14))
	_close_btn.add_theme_stylebox_override("pressed", _style(Color(accent, 0.45), 20, 14))
	_close_btn.offset_left = 12
	_close_btn.offset_top = 12
	_close_btn.pressed.connect(close)
	add_child(_close_btn)

func _begin():
	await run(scene.get("on_start"))
	await play(str(scene.get("start", "idle")))

# ------------------------------------------------------------------ أدوات صغيرة
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _arr(x) -> Array:
	if x == null: return []
	if typeof(x) == TYPE_ARRAY: return x
	return [x]

func _pick(list, key: String):
	var l := _arr(list)
	if l.is_empty(): return null
	if l.size() < 2: return l[0]
	var c: Array = []
	for x in l:
		if x != _last_src.get(key): c.append(x)
	if c.is_empty(): c = l
	var r = c[randi() % c.size()]
	_last_src[key] = r
	return r

func _clips() -> Dictionary:
	return scene.get("clips", {})

func _resolve(src: String) -> String:
	var s := src
	for ext in [".mp4", ".mov", ".webm", ".mkv", ".m4v", ".avi"]:
		if s.to_lower().ends_with(ext):
			s = s.substr(0, s.length() - ext.length()) + ".ogv"
			break
	if s.begins_with("res://") or s.begins_with("user://") or s.begins_with("/"): return s
	return base.path_join(s)

func _load_stream(path: String):
	if _streams.has(path): return _streams[path]
	var st = null
	if ResourceLoader.exists(path):
		st = load(path)
	elif FileAccess.file_exists(path):
		var t := VideoStreamTheora.new()
		t.file = path
		st = t
	if st != null: _streams[path] = st
	return st

func _video_size() -> Vector2:
	if _active != null:
		var sz := _active.size_px()
		if sz.x > 0: return sz
	return Vector2(float(scene.get("width", 16)), float(scene.get("height", 9)))

# مكان الفيديو الفعلي داخل الشاشة (contain)
func content_rect() -> Rect2:
	var vs := _video_size()
	var s: float = minf(size.x / vs.x, size.y / vs.y)
	var w := vs.x * s
	var h := vs.y * s
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)

func _content(px: float, py: float) -> Dictionary:
	var r := content_rect()
	return {"u": (px - r.position.x) / r.size.x, "v": (py - r.position.y) / r.size.y, "px": px, "py": py}

func _layout_players():
	var r := content_rect()
	if r == _last_rect: return
	_last_rect = r
	for sl in [_sa, _sb]:
		for n in [sl.video, sl.img]:
			n.position = r.position
			n.size = r.size

# ------------------------------------------------------------------ الواجهة: كلام، إشعارات، عدادات
func say(text: String, who := "", time := 0.0):
	_sub_token += 1
	var tok := _sub_token
	var body := text.replace("[", "[lb]")
	var head := ""
	if who != "":
		head = "[color=#%s][b]%s[/b][/color]  " % [accent.to_html(false), who.replace("[", "[lb]")]
	_sub_rt.text = "[center]" + head + body + "[/center]"
	create_tween().tween_property(_sub, "modulate:a", 1.0, 0.2)
	var secs := time if time > 0.0 else maxf(2.2, text.length() * 0.07)
	await get_tree().create_timer(secs).timeout
	if tok == _sub_token and is_instance_valid(_sub):
		create_tween().tween_property(_sub, "modulate:a", 0.0, 0.25)

func toast(text: String):
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_stylebox_override("normal", _style(PANEL, 10, 12))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

func _draw_meters():
	var ms := _arr(scene.get("meters"))
	_meters_box.visible = not ms.is_empty()
	for m in ms:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := Label.new()
		lab.text = str(m.get("label", m.get("var", "")))
		lab.custom_minimum_size.x = 84
		lab.add_theme_font_size_override("font_size", 20)
		lab.add_theme_color_override("font_color", MUTED)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(130, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.min_value = float(m.get("min", 0))
		bar.max_value = float(m.get("max", 100))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(str(m["color"])) if m.has("color") else accent
		fill.set_corner_radius_all(5)
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(1, 1, 1, 0.15)
		bgs.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bgs)
		bar.value = float(vars.get(m.get("var"), 0))
		row.add_child(lab)
		row.add_child(bar)
		_meters_vb.add_child(row)
		_meter_bars[str(m.get("var"))] = bar

func _update_meters():
	for k in _meter_bars:
		var bar: ProgressBar = _meter_bars[k]
		create_tween().tween_property(bar, "value", float(vars.get(k, 0)), 0.35)

func _limit(k: String):
	for m in _arr(scene.get("meters")):
		if str(m.get("var")) == k:
			vars[k] = clampf(float(vars[k]), float(m.get("min", 0)), float(m.get("max", 100)))

# ------------------------------------------------------------------ تشغيل المقاطع
func _is_image_path(path: String) -> bool:
	var l := path.to_lower()
	for e in [".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp"]:
		if l.ends_with(e): return true
	return false

func _load_texture(path: String):
	if _streams.has(path): return _streams[path]
	var tex = null
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D: tex = r
	elif FileAccess.file_exists(path):
		var im := Image.load_from_file(path)
		if im != null and not im.is_empty(): tex = ImageTexture.create_from_image(im)
	if tex != null: _streams[path] = tex
	return tex

# خلفية ثابتة خلف الشخصية (على مستوى المشهد "bg" أو لكل مقطع)
func _set_bg(path: String):
	if path == _bg_path: return
	_bg_path = path
	if path == "":
		_bg_tex.texture = null
		return
	var t = _load_texture(_resolve(path))
	if t != null: _bg_tex.texture = t
	else: push_warning("IVG: ما لقيت الخلفية: " + path)

# يشغّل مقطع: src يقبل فيديو (.ogv/.mp4...) أو صورة (.png/.jpg...). الصورة تعتبر مقطع بمدة "duration" (الافتراضي 2 ثانية، أو بلا نهاية مع loop).
func play(clip_name: String) -> void:
	var clip: Dictionary = _clips().get(clip_name, {})
	if clip.is_empty():
		push_warning("IVG: مقطع مو موجود: " + clip_name)
		return
	var src_name = _pick(clip.get("src"), clip_name)
	if src_name == null:
		push_warning("IVG: المقطع بدون src: " + clip_name)
		return
	var src := _resolve(str(src_name))
	var as_img := _is_image_path(src)
	var stream = _load_texture(src) if as_img else _load_stream(src)
	if stream == null:
		push_warning("IVG: ما لقيت الملف: " + src)
		return
	_play_token += 1
	var token := _play_token
	var nxt: Slot = _sb if _active == _sa else _sa
	var prev: Slot = _active
	_hide_choices()
	nxt.stop()
	nxt.show_kind(as_img)
	nxt.video.modulate.a = 0.0
	nxt.img.modulate.a = 0.0
	if as_img:
		nxt.start_image(stream, float(clip.get("duration", 0.0 if bool(clip.get("loop", false)) else 2.0)))
		await get_tree().process_frame
	else:
		nxt.video.stop()
		nxt.video.stream = stream
		nxt.video.loop = bool(clip.get("loop", false))
		nxt.video.volume_db = -80.0 if muted else 0.0
		nxt.video.paused = false
		nxt.video.play()
		# ننتظر أول إطار عشان نعرف مقاس الفيديو الحقيقي
		var tries := 0
		while tries < 40 and token == _play_token:
			await get_tree().process_frame
			var t := nxt.video.get_video_texture()
			if t != null and t.get_size().x > 0 and nxt.video.stream_position > 0.0: break
			tries += 1
	if token != _play_token: return
	_active = nxt
	prev.video.material = null
	prev.img.material = null
	_set_bg(str(clip.get("bg", scene.get("bg", ""))))
	_last_rect = Rect2()
	_layout_players()
	var fade := float(clip.get("fade", scene.get("fade", 0.12)))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(nxt.node(), "modulate:a", 1.0, maxf(fade, 0.001))
	tw.tween_property(prev.node(), "modulate:a", 0.0, maxf(fade, 0.001))
	tw.chain().tween_callback(func():
		if prev != _active: prev.stop())
	_cur = {"name": clip_name, "clip": clip, "src": src, "pauses": {}, "qtes": {}, "events": {}, "t_start": _now(), "done": false,
		"breathe": bool(clip.get("breathe", as_img))}
	if _cur["breathe"]: _fx["on"] = true
	clip_started.emit(clip_name)
	if clip.has("say"):
		say(str(_pick(clip["say"], clip_name + ":say")), str(clip.get("who", scene.get("who", ""))), float(clip.get("sayTime", 0)))
	await run(clip.get("do"))

func _on_player_finished(p: Slot):
	if p != _active or _cur.is_empty() or _ended: return
	if _cur.get("done", false): return
	_cur["done"] = true
	var c: Dictionary = _cur["clip"]
	if bool(c.get("loop", false)):
		_cur["done"] = false
		_cur["t_start"] = _now()
		if p.is_img: p.start_image(p.img.texture, 0.0)
		else: p.video.play()   # احتياط لو loop ما اشتغل
		return
	var token := _play_token
	await run(c.get("on_end"))
	if token == _play_token and c.has("then"):
		await play(str(_pick(c["then"], str(_cur.get("name", "")) + ":then")))

# ------------------------------------------------------------------ الأوامر
func run(actions) -> void:
	for a in _arr(actions):
		if _ended: return
		await _exec(a)

func _exec(a) -> void:
	if typeof(a) != TYPE_DICTIONARY: return
	if a.has("if"):
		if Cond.check(a["if"], vars): await run(a.get("then"))
		else: await run(a.get("else"))
		return
	if a.has("random"):
		var opts_: Array = a["random"]
		if opts_.is_empty(): return
		var ws: Array = a.get("weights", [])
		var tot := 0.0
		for i in opts_.size(): tot += float(ws[i]) if i < ws.size() else 1.0
		var r := randf() * tot
		for i in opts_.size():
			r -= float(ws[i]) if i < ws.size() else 1.0
			if r <= 0.0:
				await run(opts_[i])
				return
		await run(opts_[opts_.size() - 1])
		return
	if a.has("add"):
		for k in a["add"]:
			vars[k] = float(vars.get(k, 0)) + float(a["add"][k])
			_limit(k)
		_update_meters()
		vars_changed.emit(vars)
	if a.has("set"):
		for k in a["set"]:
			vars[k] = a["set"][k]
			if typeof(vars[k]) == TYPE_FLOAT or typeof(vars[k]) == TYPE_INT: _limit(k)
		_update_meters()
		vars_changed.emit(vars)
	if a.has("say"):
		say(str(_pick(a["say"], "act:" + str(a["say"]))), str(a.get("who", scene.get("who", ""))), float(a.get("time", 0)))
	if a.has("toast"): toast(str(a["toast"]))
	if a.has("fx"): kick(str(a["fx"]))
	if a.has("save"): _save()
	if a.has("stop"):
		await get_tree().create_timer(float(scene.get("end_delay", 1.5))).timeout
		_finish("stop")
		return
	if a.has("resume"):
		_hide_choices()
		_active.set_paused(false)
	if a.has("choices"):
		await _choose(a)
		return
	if a.has("wait"):
		await get_tree().create_timer(float(a["wait"])).timeout
	if a.has("play") or a.has("go"):
		await play(str(_pick(a.get("play", a.get("go")), "act:" + str(a.get("play", a.get("go"))))))

# ------------------------------------------------------------------ الاختيارات
func _hide_choices():
	_choice_timer = {}
	for ch in _choice_box.get_children(): ch.queue_free()
	_choice_box.visible = false

func _choose(spec: Dictionary) -> void:
	_hide_choices()
	_choice_token += 1
	var tok := _choice_token
	if spec.has("prompt"):
		var p := Label.new()
		p.text = str(spec["prompt"])
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_theme_font_size_override("font_size", 26)
		p.add_theme_stylebox_override("normal", _style(PANEL, 12, 12))
		_choice_box.add_child(p)
	var list: Array = []
	for c in _arr(spec.get("choices")):
		if Cond.check(c.get("if"), vars): list.append(c)
	var taken := [false]
	var take := func(c: Dictionary):
		if taken[0]: return
		taken[0] = true
		_hide_choices()
		choice_taken.emit(str(c.get("text", "")))
		await run(c.get("do"))
		var g = c.get("go", c.get("play"))
		if g != null: await play(str(_pick(g, "choice:go")))
		_choice_done.emit(tok)
	for c in list:
		var b := Button.new()
		b.text = str(c.get("text", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", _style(PANEL, 14, 14))
		b.add_theme_stylebox_override("hover", _style(Color(accent, 0.3), 14, 14))
		b.add_theme_stylebox_override("pressed", _style(Color(accent, 0.55), 14, 14))
		b.pressed.connect(func(): take.call(c))
		_choice_box.add_child(b)
	if spec.has("timeout"):
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.value = 100
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		bar.add_theme_stylebox_override("fill", fill)
		_choice_box.add_child(bar)
		_choice_timer = {"t0": _now(), "timeout": float(spec["timeout"]), "bar": bar, "spec": spec, "list": list, "take": take, "taken": taken, "tok": tok}
	_choice_box.visible = true
	while true:
		var t = await _choice_done
		if t == tok: break

func _tick_choice_timer():
	if _choice_timer.is_empty(): return
	var ct := _choice_timer
	var k: float = 1.0 - (_now() - float(ct["t0"])) / float(ct["timeout"])
	(ct["bar"] as ProgressBar).value = clampf(k, 0.0, 1.0) * 100.0
	if k > 0.0: return
	_choice_timer = {}
	var spec: Dictionary = ct["spec"]
	var list: Array = ct["list"]
	var d = null
	var df = spec.get("default")
	if typeof(df) == TYPE_FLOAT or typeof(df) == TYPE_INT:
		if int(df) >= 0 and int(df) < list.size(): d = list[int(df)]
	elif df != null:
		for c in list:
			if str(c.get("text")) == str(df): d = c
	if d != null:
		(ct["take"] as Callable).call(d)
	elif spec.has("on_timeout"):
		ct["taken"][0] = true
		_hide_choices()
		await run(spec["on_timeout"])
		_choice_done.emit(int(ct["tok"]))

# ------------------------------------------------------------------ اللمس: مناطق وحركات
func _in_shape(h: Dictionary, c: Dictionary) -> bool:
	var r := content_rect()
	if str(h.get("shape", "")) == "circle" or h.has("r"):
		var dx := (float(c["u"]) - float(h.get("x", 0))) * r.size.x
		var dy := (float(c["v"]) - float(h.get("y", 0))) * r.size.y
		var rad := float(h.get("r", 0)) * r.size.x      # نصف القطر نسبة من عرض الفيديو
		return dx * dx + dy * dy <= rad * rad
	if str(h.get("shape", "")) == "poly" and h.has("points"):
		var pts: Array = h["points"]
		var inside := false
		var j := pts.size() - 1
		for i in pts.size():
			var xi := float(pts[i][0])
			var yi := float(pts[i][1])
			var xj := float(pts[j][0])
			var yj := float(pts[j][1])
			if (yi > float(c["v"])) != (yj > float(c["v"])) and float(c["u"]) < (xj - xi) * (float(c["v"]) - yi) / (yj - yi) + xi:
				inside = not inside
			j = i
		return inside
	var hx := float(h.get("x", 0))
	var hy := float(h.get("y", 0))
	return float(c["u"]) >= hx and float(c["u"]) <= hx + float(h.get("w", 0)) and float(c["v"]) >= hy and float(c["v"]) <= hy + float(h.get("h", 0))

# inherit: مقطع ردة الفعل ياخذ أماكن اللمس من مقطع ثاني (مثلًا idle) عشان اللاعب يقدر يكمل لمس
func _own_and_inherited(field: String) -> Array:
	var list: Array = _arr(_cur["clip"].get(field)).duplicate()
	var seen := {}
	var c: Dictionary = _cur["clip"]
	while c.has("inherit") and not seen.has(c["inherit"]) and _clips().has(c["inherit"]):
		seen[c["inherit"]] = true
		c = _clips()[c["inherit"]]
		for h in _arr(c.get(field)):
			var hh: Dictionary = (h as Dictionary).duplicate()
			hh.erase("from")
			hh.erase("to")
			list.append(hh)
	return list

func _clip_on(g: String):
	var c: Dictionary = _cur["clip"]
	var seen := {}
	while true:
		if c.has("on") and (c["on"] as Dictionary).has(g): return c["on"][g]
		if not c.has("inherit") or seen.has(c["inherit"]) or not _clips().has(c["inherit"]): break
		seen[c["inherit"]] = true
		c = _clips()[c["inherit"]]
	return null

func _hkey(h: Dictionary) -> String:
	if h.has("id"): return str(h["id"])
	return JSON.stringify([h.get("x"), h.get("y"), h.get("w"), h.get("r")])

func _area(h: Dictionary) -> float:
	if h.has("r"): return PI * float(h["r"]) * float(h["r"])
	if h.has("points"): return 0.05
	return float(h.get("w", 0)) * float(h.get("h", 0))

func _active_hotspots() -> Array:
	if _cur.is_empty(): return []
	var t := _active.pos()
	var out: Array = []
	for h in _own_and_inherited("hotspots"):
		if h.has("from") and t < float(h["from"]): continue
		if h.has("to") and t > float(h["to"]): continue
		if bool(h.get("once", false)) and _mem["once"].has(_hkey(h)): continue
		if not Cond.check(h.get("if"), vars): continue
		out.append(h)
	return out

func _hit(c: Dictionary) -> Array:
	var out: Array = []
	for h in _active_hotspots():
		if _in_shape(h, c): out.append(h)
	out.sort_custom(func(a, b): return _area(a) < _area(b))
	return out

func _wants(h: Dictionary) -> Array:
	if h.has("on"): return (h["on"] as Dictionary).keys()
	return _arr(h.get("gesture", "tap"))

func _trigger(h: Dictionary, g: String):
	var key := _hkey(h)
	var cd := float(h.get("cooldown", 0.35))
	if _mem["cool"].has(key) and _now() - float(_mem["cool"][key]) < cd: return
	_mem["cool"][key] = _now()
	if bool(h.get("once", false)): _mem["once"][key] = true
	_idle_since = _now()
	# سلسلة: لو لمس نفس المكان كذا مرة بسرعة يصير شي ثاني
	if h.has("combo"):
		var cb_def: Dictionary = h["combo"]
		var ck := str(cb_def.get("group", key))
		var within := float(cb_def.get("within", 2.0))
		var arr_: Array = []
		for tt in _mem["combos"].get(ck, []):
			if _now() - float(tt) < within: arr_.append(tt)
		arr_.append(_now())
		_mem["combos"][ck] = arr_
		if arr_.size() >= int(cb_def.get("count", 3)):
			_mem["combos"][ck] = []
			run(cb_def.get("do"))
			hotspot_hit.emit(h.get("id", ""), "combo")
			return
	hotspot_hit.emit(h.get("id", ""), g)
	var acts = h.get("do")
	if h.has("on") and (h["on"] as Dictionary).has(g): acts = h["on"][g]
	run(acts)

func _handle(g: String, c: Dictionary):
	if not _started or _ended: return
	if g == "down":
		_fx_press(float(c["px"]), float(c["py"]))
		return
	if g == "move":
		_fx_move(float(c["px"]), float(c["py"]))
		return
	if g == "up":
		_fx_release()
		return
	if _cur.is_empty(): return
	_idle_since = _now()
	var t := _active.pos()
	# حركة بوقت محدد (QTE)
	var q := _arr(_cur["clip"].get("qte"))
	for i in q.size():
		var Q: Dictionary = q[i]
		if _cur["qtes"].has(i) or t < float(Q.get("from", 0)) or t > float(Q.get("to", 9999)): continue
		if not (g in _arr(Q.get("gesture", "tap"))): continue
		if (Q.has("r") or Q.has("w")) and not _in_shape(Q, c): continue
		_cur["qtes"][i] = "ok"
		_hint_sig = ""
		run(Q.get("success"))
		return
	var hs := _hit(c)
	for h in hs:
		if g in _wants(h):
			_trigger(h, g)
			return
	var co = _clip_on(g)
	if co != null: run(co)

# قارئ الحركات: يحوّل اللمس لـ tap/double/hold/swipe/rub/drag
func _on_input(ev: InputEvent):
	if _ended: return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed: _g_down(ev.position)
		else: _g_up(ev.position)
	elif ev is InputEventMouseMotion and not _g.is_empty():
		_g_move(ev.position)

func _g_down(p: Vector2):
	if not _g.is_empty(): return
	_g = {"x0": p.x, "y0": p.y, "t0": _now(), "moved": 0.0, "held": false, "dir": 0, "flips": 0,
		"lx": p.x, "ly": p.y, "last_drag": 0.0, "axis": ""}
	_handle("down", _content(p.x, p.y))

func _g_move(p: Vector2):
	var dx := p.x - float(_g["lx"])
	var dy := p.y - float(_g["ly"])
	_g["moved"] = maxf(float(_g["moved"]), Vector2(p.x - float(_g["x0"]), p.y - float(_g["y0"])).length())
	if _g["axis"] == "" and float(_g["moved"]) > SLOP:
		_g["axis"] = "x" if absf(p.x - float(_g["x0"])) >= absf(p.y - float(_g["y0"])) else "y"
	var d := dy if _g["axis"] == "y" else dx
	if absf(d) > 4.0:
		var s := 1 if d > 0 else -1
		if int(_g["dir"]) != 0 and s != int(_g["dir"]):
			_g["flips"] = int(_g["flips"]) + 1
			if int(_g["flips"]) % 2 == 0: _handle("rub", _content(p.x, p.y))
		_g["dir"] = s
	_g["lx"] = p.x
	_g["ly"] = p.y
	_handle("move", _content(p.x, p.y))
	if float(_g["moved"]) > SLOP and _now() - float(_g["last_drag"]) > 0.15:
		_g["last_drag"] = _now()
		_handle("drag", _content(p.x, p.y))

func _g_up(p: Vector2):
	if _g.is_empty(): return
	_tick_hold()   # لو الجوال بطيء وفات إطار ما فحص الضغط المطوّل، نفحصه لحظة الفك
	var dt := _now() - float(_g["t0"])
	var start := _content(float(_g["x0"]), float(_g["y0"]))
	var dx := p.x - float(_g["x0"])
	var dy := p.y - float(_g["y0"])
	var dist := Vector2(dx, dy).length()
	if not bool(_g["held"]) and dist < SLOP and dt < 0.35:
		if not _last_tap.is_empty() and _now() - float(_last_tap["t"]) < 0.32 and Vector2(p.x - float(_last_tap["x"]), p.y - float(_last_tap["y"])).length() < 30.0:
			_handle("double", start)
			_last_tap = {}
		else:
			_handle("tap", start)
			_last_tap = {"t": _now(), "x": p.x, "y": p.y}
	elif dist > 50.0 and (dist / maxf(dt, 0.001) > 160.0 or dt < 0.5) and int(_g["flips"]) < 2:
		var dir_name := ""
		if absf(dx) > absf(dy): dir_name = "swipe-right" if dx > 0 else "swipe-left"
		else: dir_name = "swipe-down" if dy > 0 else "swipe-up"
		_handle(dir_name, start)
		_handle("swipe", start)
	_handle("up", _content(p.x, p.y))
	_g = {}

# الضغط المطوّل يشتغل وقت الضغط نفسه (ما ينتظر تفك إصبعك)
func _tick_hold():
	if _g.is_empty() or bool(_g["held"]) or float(_g["moved"]) >= SLOP or _cur.is_empty(): return
	var dur := _now() - float(_g["t0"])
	var c0 := _content(float(_g["x0"]), float(_g["y0"]))
	for h in _hit(c0):
		if "hold" in _wants(h) and dur >= float(h.get("hold", 0.6)):
			_g["held"] = true
			_trigger(h, "hold")
			return
	var t := _active.pos()
	var q := _arr(_cur["clip"].get("qte"))
	for i in q.size():
		var Q: Dictionary = q[i]
		if not _cur["qtes"].has(i) and t >= float(Q.get("from", 0)) and t <= float(Q.get("to", 9999)) and "hold" in _arr(Q.get("gesture")) and dur >= float(Q.get("hold", 0.6)):
			_g["held"] = true
			_cur["qtes"][i] = "ok"
			run(Q.get("success"))
			return

# ------------------------------------------------------------------ الحلقة الرئيسية
func _process(_delta):
	if not _started: return
	_layout_players()
	_tick_choice_timer()
	if _cur.is_empty() or _ended: return
	var t := _active.pos()
	var c: Dictionary = _cur["clip"]
	# صورة انتهت مدتها = نهاية عادية للمقطع
	if _active.is_img and not _cur["done"] and not _active.is_paused() and not _active.is_playing():
		_on_player_finished(_active)
		return
	# حارس: لو الفك وقف (مقطع تالف) والمقطع مو في وقفة، نعامله كأنه خلص عشان المشهد ما يعلق
	if not _cur["done"] and not _active.is_paused():
		var stalled := false
		if not _active.is_playing() and _now() - float(_cur["t_start"]) > 0.6:
			stalled = true
		elif absf(t - float(_cur.get("last_pos", -1.0))) > 0.001:
			_cur["last_pos"] = t
			_cur["last_move"] = _now()
		elif _now() - float(_cur.get("last_move", _cur["t_start"])) > 4.0:
			stalled = true     # الفيديو عالق بنفس المكان (ملف مقطوع/تالف)
		if stalled:
			push_warning("IVG: المقطع وقف قبل نهايته: " + str(_cur["src"]))
			_active.stop()
			_on_player_finished(_active)
			return
	var ev := _arr(c.get("events"))
	for i in ev.size():
		if not _cur["events"].has(i) and t >= float(ev[i].get("at", 0)):
			_cur["events"][i] = true
			run(ev[i].get("do"))
	var ps := _arr(c.get("pause"))
	for i in ps.size():
		if _cur["pauses"].has(i) or t < float(ps[i].get("at", 0)): continue
		_cur["pauses"][i] = true
		_active.set_paused(true)
		_choose(ps[i])
	var q := _arr(c.get("qte"))
	for i in q.size():
		if not _cur["qtes"].has(i) and t > float(q[i].get("to", 9999)):
			_cur["qtes"][i] = "fail"
			run(q[i].get("fail"))
	_tick_hold()
	_hint_clock += _delta
	if _hint_clock >= 0.25:
		_hint_clock = 0.0
		_refresh_hints()
	_fx_frame(_delta)
	if debug_hotspots: _debug.queue_redraw()

# ------------------------------------------------------------------ التلميحات
const GESTURE_LABELS := {"tap": "المس!", "hold": "اضغط مطوّل", "swipe-left": "⟵ اسحب", "swipe-right": "اسحب ⟶", "swipe-up": "اسحب ⟰", "swipe-down": "اسحب ⟱", "rub": "امسح"}

func _hotspot_center(h: Dictionary) -> Vector2:
	if h.has("r"): return Vector2(float(h.get("x", 0.5)), float(h.get("y", 0.5)))
	if h.has("points") and not (h["points"] as Array).is_empty():
		var s := Vector2.ZERO
		for p in h["points"]: s += Vector2(float(p[0]), float(p[1]))
		return s / float((h["points"] as Array).size())
	return Vector2(float(h.get("x", 0)) + float(h.get("w", 0)) / 2.0, float(h.get("y", 0)) + float(h.get("h", 0)) / 2.0)

func _refresh_hints():
	var items: Array = []
	if not _cur.is_empty() and not _ended:
		var t := _active.pos()
		var q := _arr(_cur["clip"].get("qte"))
		for i in q.size():
			var Q: Dictionary = q[i]
			if _cur["qtes"].has(i) or t < float(Q.get("from", 0)) or t > float(Q.get("to", 9999)): continue
			var gl = GESTURE_LABELS.get(str(_arr(Q.get("gesture", "tap"))[0]), "الحين!")
			items.append({"k": "q", "x": float(Q.get("x", 0.5)), "y": float(Q.get("y", 0.5)), "text": str(Q.get("label", gl))})
		if _now() - _idle_since >= float(scene.get("hintAfter", 4)):
			for h in _active_hotspots():
				if bool(h.get("hint", false)):
					var cen := _hotspot_center(h)
					items.append({"k": "h", "x": cen.x, "y": cen.y})
	var r := content_rect()
	var sig := JSON.stringify(items) + str(r)
	if sig == _hint_sig: return
	_hint_sig = sig
	for ch in _hint_layer.get_children(): ch.queue_free()
	for it in items:
		var pos := r.position + Vector2(float(it["x"]) * r.size.x, float(it["y"]) * r.size.y)
		if it["k"] == "q":
			var l := Label.new()
			l.text = str(it["text"])
			l.add_theme_font_size_override("font_size", 30)
			l.add_theme_color_override("font_color", Color("#2a0f1a"))
			l.add_theme_stylebox_override("normal", _style(accent, 30, 22))
			l.position = pos
			_hint_layer.add_child(l)
			l.position = pos - l.get_combined_minimum_size() / 2.0
			l.pivot_offset = l.get_combined_minimum_size() / 2.0
			var tw := l.create_tween().set_loops()
			tw.tween_property(l, "scale", Vector2(1.12, 1.12), 0.5)
			tw.tween_property(l, "scale", Vector2.ONE, 0.5)
		else:
			var ring := Panel.new()
			var st := StyleBoxFlat.new()
			st.bg_color = Color(1, 1, 1, 0.0)
			st.set_border_width_all(3)
			st.border_color = Color(1, 1, 1, 0.85)
			st.set_corner_radius_all(30)
			ring.add_theme_stylebox_override("panel", st)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.size = Vector2(60, 60)
			ring.position = pos - Vector2(30, 30)
			ring.pivot_offset = Vector2(30, 30)
			_hint_layer.add_child(ring)
			var tw2 := ring.create_tween().set_loops()
			tw2.tween_property(ring, "scale", Vector2(0.6, 0.6), 0.0)
			tw2.parallel().tween_property(ring, "modulate:a", 1.0, 0.0)
			tw2.tween_property(ring, "scale", Vector2(1.5, 1.5), 1.4)
			tw2.parallel().tween_property(ring, "modulate:a", 0.0, 1.4)

# رسم مناطق اللمس للتجربة (debug)
func _debug_draw():
	if not debug_hotspots or _cur.is_empty(): return
	var r := content_rect()
	var col := Color(0.35, 0.82, 1.0)
	for h in _active_hotspots():
		if h.has("r"):
			var cen := r.position + Vector2(float(h.get("x", 0)) * r.size.x, float(h.get("y", 0)) * r.size.y)
			_debug.draw_arc(cen, float(h["r"]) * r.size.x, 0, TAU, 48, col, 2.0)
		elif h.has("points"):
			var pts := PackedVector2Array()
			for p in h["points"]: pts.append(r.position + Vector2(float(p[0]) * r.size.x, float(p[1]) * r.size.y))
			if pts.size() > 1:
				pts.append(pts[0])
				_debug.draw_polyline(pts, col, 2.0)
		else:
			var rc := Rect2(r.position + Vector2(float(h.get("x", 0)) * r.size.x, float(h.get("y", 0)) * r.size.y), Vector2(float(h.get("w", 0)) * r.size.x, float(h.get("h", 0)) * r.size.y))
			_debug.draw_rect(rc, col, false, 2.0)

# ------------------------------------------------------------------ لمس حي على الفيديو (الانبعاج)
func kick(kind: String):
	if kind == "shake": _fx["shake0"] = Time.get_ticks_msec()
	else: _fx["pulse0"] = Time.get_ticks_msec()
	_fx["on"] = true

func _fx_press(x: float, y: float):
	var r := content_rect()
	_fx["down"] = true
	_fx["px"] = x
	_fx["py"] = y
	_fx["sx"] = x
	_fx["sy"] = y
	_fx["t0"] = Time.get_ticks_msec()
	_fx["r"] = maxf(28.0, minf(r.size.x, r.size.y) * 0.11)
	_fx["on"] = true

func _fx_move(x: float, y: float):
	if not _fx["down"]: return
	_fx["px"] = x
	_fx["py"] = y

func _fx_release():
	if not _fx["down"]: return
	_fx["down"] = false
	_fx["rel"] = Time.get_ticks_msec()
	_fx["ramp"] = 6.0 + 10.0 * float(_fx["depth"])
	_fx["sx"] = _fx["px"]
	_fx["sy"] = _fx["py"]

func _fx_frame(delta: float):
	var breathing: bool = not _cur.is_empty() and bool(_cur.get("breathe", false))
	if not _fx["on"] and not breathing: return
	var f := _fx
	var now_ms := float(Time.get_ticks_msec())
	var dt := minf(0.05, delta)
	# العمق على زنبرك: ينزل بسرعة وقت الضغط، ويرجع بنطّة خفيفة
	var target := minf(1.0, ((now_ms - float(f["t0"])) / 1000.0) * 2.2 + 0.25) if f["down"] else 0.0
	var k := 60.0 if f["down"] else 90.0
	var cdamp := 12.0 if f["down"] else 9.0
	f["vel"] = float(f["vel"]) + ((target - float(f["depth"])) * k - float(f["vel"]) * cdamp) * dt
	f["depth"] = float(f["depth"]) + float(f["vel"]) * dt
	# الجلد يلحق الإصبع بس لحد معين
	var pull_t := Vector2(float(f["px"]) - float(f["sx"]), float(f["py"]) - float(f["sy"])) if f["down"] else Vector2.ZERO
	var lim := float(f["r"]) * 0.6
	if pull_t.length() > lim: pull_t = pull_t.normalized() * lim
	f["pull"] = (f["pull"] as Vector2).lerp(pull_t, minf(1.0, dt * 14.0))
	var rt := (now_ms - float(f["rel"])) / 1000.0 if float(f["rel"]) > 0.0 else 9.0
	var shake_t := (now_ms - float(f["shake0"])) / 1000.0 if float(f["shake0"]) > 0.0 else 9.0
	var pulse_t := (now_ms - float(f["pulse0"])) / 1000.0 if float(f["pulse0"]) > 0.0 else 9.0
	var shake := sin(shake_t * 70.0) * 6.0 * (1.0 - shake_t / 0.5) if shake_t < 0.5 else 0.0
	var pulse := sin(pulse_t * PI / 0.6) if pulse_t < 0.6 else 0.0
	var alive: bool = f["down"] or absf(float(f["depth"])) > 0.02 or absf(float(f["vel"])) > 0.05 or rt < 1.2 or shake_t < 0.5 or pulse_t < 0.6 or breathing
	if not alive:
		f["on"] = false
		_active.node().material = null
		return
	var r := content_rect()
	if _active.node().material != _mat: _active.node().material = _mat
	_mat.set_shader_parameter("u_size", r.size)
	_mat.set_shader_parameter("u_p", Vector2(float(f["px"]) if f["down"] else float(f["sx"]), float(f["py"]) if f["down"] else float(f["sy"])) - r.position)
	_mat.set_shader_parameter("u_r", float(f["r"]))
	_mat.set_shader_parameter("u_depth", maxf(-0.3, float(f["depth"])))
	_mat.set_shader_parameter("u_pull", f["pull"])
	_mat.set_shader_parameter("u_rt", rt)
	_mat.set_shader_parameter("u_ramp", 0.0 if f["down"] else float(f["ramp"]))
	_mat.set_shader_parameter("u_shake", Vector2(shake, 0.0))
	_mat.set_shader_parameter("u_pulse", pulse)
	_mat.set_shader_parameter("u_breath", sin(now_ms / 1000.0 * 1.7) if breathing else 0.0)
	_mat.set_shader_parameter("u_alpha", _active.node().modulate.a)

# ------------------------------------------------------------------ حفظ وإنهاء
func _save_path() -> String:
	return "user://ivg_%s.json" % str(scene.get("id", "scene")).validate_filename()

func _save():
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"vars": vars}))

func _load_saved() -> Dictionary:
	if not FileAccess.file_exists(_save_path()): return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	return j if typeof(j) == TYPE_DICTIONARY else {}

func _finish(reason: String):
	if _ended: return
	_ended = true
	_fx_release()
	_sa.stop()
	_sb.stop()
	if bool(scene.get("persist", false)): _save()
	finished.emit({"vars": vars.duplicate(true), "start_vars": start_vars.duplicate(true), "reason": reason, "scene_id": str(scene.get("id", ""))})

func close():
	_finish("closed")
