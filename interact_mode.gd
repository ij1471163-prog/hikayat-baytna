extends Control
# وضع القرب: ليان قريبة منك. لمس متقدم (ضغطة، ضغطة طويلة، مسح بطيء، فرك) + عدادات + حالات + كاميرا تقرّب
const RigBody := preload("res://rig_body.gd")
const LiveBody := preload("res://live_body.gd")
const D := preload("res://interact_data.gd")

signal closed(gain: int)

var game
var npc := "ليان"
var tex: Texture2D
var img: Image
var fig_rect := Rect2()          # حدود جسمها داخل الصورة (بكسل)
var cam: Node2D
var lb
var base_s := 1.0
var c0 := Vector2.ZERO            # مركز الكاميرا في العرض الكامل (بكسل الصورة)
var zoom := 1.0
var zoom_to := 1.0
var center := Vector2.ZERO
var center_to := Vector2.ZERO
var back_at := -1.0
var t := 0.0
var meters := {"comfort": 0.15, "tickle": 0.0, "shy": 0.0, "annoy": 0.0}
var state := "calm"
var state_since := 0.0
var good_time := 0.0              # وقت الحالات الحلوة (يرفع العلاقة)
var touch := {}
var taps: Array = []
var bubble: Label
var bars := {}
var state_lbl: Label

func setup(g, who: String, path: String, bg: Texture2D):
	game = g
	npc = who
	tex = load(path)
	img = tex.get_image()
	if img.is_compressed(): img.decompress()
	var u := img.get_used_rect()
	fig_rect = Rect2(u.position, u.size) if u.size.x > 0 else Rect2(Vector2.ZERO, tex.get_size())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	# الخلفية: الغرفة نفسها مغبشة وأغمق (لقطة قريبة)
	var bgr := TextureRect.new()
	bgr.texture = bg
	bgr.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = Shader.new()
	bm.shader.code = "shader_type canvas_item;\nvoid fragment(){ vec4 s = vec4(0.0); for (int i = -3; i <= 3; i++) for (int j = -3; j <= 3; j++) s += texture(TEXTURE, UV + vec2(float(i), float(j)) * TEXTURE_PIXEL_SIZE * 6.0); COLOR = vec4(s.rgb / 49.0 * 0.62, 1.0); }"
	bgr.material = bm
	add_child(bgr)
	cam = Node2D.new()
	add_child(cam)
	if RigBody.has_rig(path) and RigBody.fits(path, tex):
		lb = RigBody.new()
	else:
		lb = LiveBody.new()
	lb.setup(tex, path)
	cam.add_child(lb)
	if game != null and game.has_method("room_light"):
		var rl: Dictionary = game.room_light()
		lb.set_light(rl["amb"], rl["side"], 0.7)
	_build_ui()
	resized.connect(_layout)
	_layout()
	_say(D.LINES["calm"])

func _build_ui():
	var top := VBoxContainer.new()
	top.position = Vector2(16, 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	for k in ["comfort", "tickle", "shy", "annoy"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = D.NAMES[k]
		l.custom_minimum_size = Vector2(90, 0)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(220, 18)
		pb.max_value = 1.0
		pb.step = 0.001
		pb.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = D.COLORS[k]
		fill.set_corner_radius_all(8)
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(0, 0, 0, 0.45)
		bgs.set_corner_radius_all(8)
		pb.add_theme_stylebox_override("fill", fill)
		pb.add_theme_stylebox_override("background", bgs)
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pb)
		row.add_child(l)
		top.add_child(row)
		bars[k] = pb
	bubble = Label.new()
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_font_size_override("font_size", 30)
	bubble.add_theme_color_override("font_color", Color.WHITE)
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 10)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	var back := Button.new()
	back.text = "رجوع"
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_close)
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.position = Vector2(-150, 16)
	back.size = Vector2(130, 56)
	add_child(back)

func _layout():
	var vs := size if size.x > 0 else get_viewport_rect().size
	# جسمها كامل يملى الشاشة تقريباً
	base_s = minf(vs.y * 0.96 / fig_rect.size.y, vs.x * 0.98 / fig_rect.size.x)
	var fig_bottom := fig_rect.end.y
	var pos := Vector2(vs.x * 0.5 - (fig_rect.position.x + fig_rect.size.x * 0.5) * base_s, vs.y - fig_bottom * base_s)
	c0 = (vs * 0.5 - pos) / base_s
	if center == Vector2.ZERO:
		center = c0
		center_to = c0
	bubble.position = Vector2(vs.x * 0.1, vs.y * 0.80)
	bubble.size = Vector2(vs.x * 0.8, 120)
	_apply_cam()

func _apply_cam():
	var vs := size if size.x > 0 else get_viewport_rect().size
	var s := base_s * zoom
	cam.scale = Vector2(s, s)
	cam.position = vs * 0.5 - center * s

func to_fig(sp: Vector2) -> Vector2:
	return (sp - cam.position) / cam.scale.x

func on_body(p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height(): return false
	return img.get_pixelv(Vector2i(p)).a > 0.15

func zone_at(p: Vector2) -> String:
	var f := (p - fig_rect.position) / fig_rect.size
	return game.touch_zone(f, false) if game != null else "waist"

# ===== اللمس =====
func _gui_input(ev: InputEvent):
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p := to_fig(ev.position)
		if ev.pressed:
			if not on_body(p): return
			var z := zone_at(p)
			touch = {"t0": t, "last": ev.position, "lt": t, "path": 0.0, "zone": z, "p": p, "mode": "tap", "speed": 0.0}
			lb.press(p)
			back_at = -1.0
		elif not touch.is_empty():
			if touch["mode"] == "tap" and t - float(touch["t0"]) < 0.35:
				_tap(touch["zone"], touch["p"])
			lb.release()
			touch = {}
			back_at = t + 1.4
		accept_event()
	elif ev is InputEventMouseMotion and not touch.is_empty():
		var dt := maxf(t - float(touch["lt"]), 1.0 / 120.0)
		var d: float = (ev.position - touch["last"]).length()
		touch["path"] = float(touch["path"]) + d
		touch["speed"] = lerpf(float(touch["speed"]), d / dt, 0.3)
		touch["last"] = ev.position
		touch["lt"] = t
		var p := to_fig(ev.position)
		if float(touch["path"]) > 26.0:
			touch["mode"] = "stroke"
			if on_body(p):
				touch["zone"] = zone_at(p)
				touch["p"] = p
		lb.press_move(p, dt)
		accept_event()

func _tap(zone: String, p: Vector2):
	# ضغطات كثيرة بسرعة على نفس المكان = إزعاج
	taps = taps.filter(func(x): return t - float(x[0]) < 1.2)
	taps.append([t, zone])
	var same := 0
	for x in taps: if x[1] == zone: same += 1
	_add(D.TAP.get(zone, {}), 1.0)
	if same >= 3 and zone in ["face", "head"]:
		_add({"annoy": 0.22}, 1.0)
	lb.react(zone, "tickle" if zone in ["waist", "body", "feet"] and same >= 3 else zone, p)

func _add(eff: Dictionary, k: float):
	for m in eff:
		meters[m] = clampf(meters[m] + float(eff[m]) * k, 0.0, 1.0)
	# الانزعاج يطفي الحلو، والارتياح يهدّي الانزعاج
	if eff.has("annoy"): meters["comfort"] = maxf(0.0, meters["comfort"] - float(eff["annoy"]) * k * 1.2)
	if eff.has("comfort"): meters["annoy"] = maxf(0.0, meters["annoy"] - float(eff["comfort"]) * k * 0.3)

func _process(delta: float):
	t += delta
	# أثناء اللمس: ضغطة طويلة أو مسح
	if not touch.is_empty():
		var held := t - float(touch["t0"])
		var z: String = touch["zone"]
		if touch["mode"] == "stroke":
			var fast: bool = float(touch["speed"]) > 900.0
			_add((D.RUB if fast else D.CARESS).get(z, {}), delta)
			if fast and z in ["waist", "body", "feet", "shoulder", "arm", "leg"] and meters["tickle"] > 0.3 and "tickle_until" in lb:
				lb.tickle_until = maxf(lb.tickle_until, lb.t + 0.4)
			touch["speed"] = float(touch["speed"]) * (1.0 - delta * 4.0)
		elif held > 0.35:
			touch["mode"] = "hold"
		if touch["mode"] == "hold":
			_add(D.HOLD.get(z, {}), delta)
		if held > 0.3:
			zoom_to = 1.7
			center_to = center_to.lerp(touch["p"], 1.0 - exp(-delta * 3.0))
	elif back_at > 0.0 and t > back_at:
		back_at = -1.0
		zoom_to = 1.0
		center_to = c0
	for m in meters:
		meters[m] = maxf(0.0, meters[m] - D.DECAY[m] * delta)
	_update_state()
	if state in ["happy", "melting"]: good_time += delta
	# كاميرا ناعمة
	var k := 1.0 - exp(-delta * 4.0)
	zoom = lerpf(zoom, zoom_to, k)
	center = center.lerp(center_to, k)
	_apply_cam()
	for m in bars: bars[m].value = meters[m]

func _update_state():
	var ns := "calm"
	for s in D.STATES:
		var lim: float = s[2]
		if s[0] == state: lim -= 0.12      # ما تتقلب بسرعة بين حالتين
		if meters[s[1]] >= lim:
			ns = s[0]
			break
	if ns == state or t - state_since < 0.7: return
	state = ns
	state_since = t
	_enter_state()

func _enter_state():
	_say(D.LINES[state])
	if not ("force_blink" in lb):
		lb.react("waist", "annoyed" if state == "annoyed" else ("tickle" if state == "laughing" else "head"), fig_rect.get_center())
		return
	lb.calm_at = -1.0
	match state:
		"calm":
			lb.calm()
		"happy":
			lb.calm(); lb.target("smile", 0.9)
		"melting":
			# تغمض عيونها وتميل عليك
			lb.extra_sway = -1.6; lb.extra_head = -8.0
			lb.target("smile", 1.2); lb.force_blink = 1.0
			lb.target("shrugL", -3.0 * lb.K); lb.target("shrugR", -3.0 * lb.K)
		"shy":
			lb.extra_sway = 0.8; lb.extra_head = 7.0
			lb.target("turn", 0.8); lb.target("smile", 0.7); lb.force_blink = 0.45
		"laughing":
			lb.target("smile", 1.3); lb.force_blink = 0.6
			lb.tickle_until = lb.t + 99.0
		"annoyed":
			lb.extra_sway = 1.8; lb.extra_head = 6.0
			lb.target("turn", 0.9); lb.target("smile", -0.3); lb.force_blink = -1.0
	if state != "laughing" and "tickle_until" in lb: lb.tickle_until = 0.0

func _say(arr: Array):
	bubble.text = str(arr[randi() % arr.size()])
	bubble.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.25)

func _close():
	var gain := 0
	if good_time > 8.0: gain = 2
	elif good_time > 3.0: gain = 1
	if meters["annoy"] > 0.5: gain -= 1
	closed.emit(gain)
	queue_free()
