extends Control
# عارض مجسم 3D داخل اللعبة: تدوير بإصبع، تقريب بإصبعين، حركات المجسم، إعادة الوضع، إغلاق.
# الاستخدام: var v = ModelViewer.new(); v.setup("res://assets/models/layan/x.glb", "العنوان"); add_child(v); v.closed.connect(...)

signal closed

var _path := ""
var _title := ""
var _svc: SubViewportContainer
var _sv: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _model: Node3D
var _anim: AnimationPlayer = null
var _yaw := 0.0
var _pitch := 0.0
var _dist := 3.0
var _base_dist := 3.0
var _touches := {}
var _pinch_prev := 0.0
var _msg: Label
var _anim_box: HBoxContainer
var loaded_ok := false


func setup(path: String, title: String = "") -> void:
	_path = path
	_title = title


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_svc)
	_sv = SubViewport.new()
	_sv.transparent_bg = true
	_sv.msaa_3d = Viewport.MSAA_2X
	_sv.own_world_3d = true
	_svc.add_child(_sv)
	var world := Node3D.new()
	_sv.add_child(world)
	# إضاءة: رئيسية + تعبئة خفيفة + بيئة
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.3
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_energy = 0.55
	world.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.55
	env.environment = e
	world.add_child(env)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 40.0
	world.add_child(_cam)
	_build_ui()
	_load_model()
	_update_cam()


func _build_ui() -> void:
	var top := Label.new()
	top.text = _title
	top.add_theme_font_size_override("font_size", 24)
	top.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 20
	top.offset_left = 20
	top.offset_right = -150
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var close := Button.new()
	close.text = "إغلاق"
	close.focus_mode = Control.FOCUS_NONE
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -130
	close.offset_right = -16
	close.offset_top = 16
	close.offset_bottom = 62
	close.pressed.connect(func(): closed.emit())
	add_child(close)
	_msg = Label.new()
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_msg)
	var bar := VBoxContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -120
	bar.offset_bottom = -14
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_anim_box = HBoxContainer.new()
	_anim_box.add_theme_constant_override("separation", 8)
	bar.add_child(_anim_box)
	var row := HBoxContainer.new()
	bar.add_child(row)
	var rb := Button.new()
	rb.text = "إعادة الوضع"
	rb.focus_mode = Control.FOCUS_NONE
	rb.custom_minimum_size = Vector2(0, 52)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.pressed.connect(reset_view)
	row.add_child(rb)


func _load_model() -> void:
	var res = null
	if ResourceLoader.exists(_path):
		res = load(_path)
	if res == null or not (res is PackedScene):
		_msg.text = "ما قدرت أحمّل المجسم."
		return
	_model = (res as PackedScene).instantiate() as Node3D
	if _model == null:
		_msg.text = "المجسم مو بصيغة صحيحة."
		return
	_pivot.add_child(_model)
	# توسيط وتكبير حسب الحجم (المجسم يوقف على الأرض، وسطه عند المحور)
	var box := _aabb(_model)
	if box.size.length() < 0.0001:
		_msg.text = "المجسم فاضي."
		return
	var s := 1.8 / maxf(box.size.y, maxf(box.size.x, box.size.z))
	_model.scale = Vector3.ONE * s
	var c := box.get_center() * s
	_model.position = Vector3(-c.x, -c.y, -c.z)
	_base_dist = 1.8 / (2.0 * tan(deg_to_rad(_cam.fov) * 0.5)) * 1.55
	_dist = _base_dist
	# الحركات
	var aps := _model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim = aps[0] as AnimationPlayer
		var names: PackedStringArray = _anim.get_animation_list()
		var shown := 0
		for n in names:
			if n == "RESET":
				continue
			var a := _anim.get_animation(n)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			var b := Button.new()
			b.text = n
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 48)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): _anim.play(n))
			_anim_box.add_child(b)
			if shown == 0:
				_anim.play(n)
			shown += 1
	loaded_ok = true


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = _model.global_transform.affine_inverse() * mi.global_transform if _model.is_inside_tree() else mi.transform
		var bb: AABB = xf * mi.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


func reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_dist = _base_dist
	_update_cam()


func _update_cam() -> void:
	if _cam == null:
		return
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_cam.position = Vector3(0, 0, _dist)
	_cam.look_at(Vector3.ZERO, Vector3.UP)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch_prev = _pinch_dist()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var pd := _pinch_dist()
			if _pinch_prev > 0.0 and pd > 0.0:
				_dist = clampf(_dist * (_pinch_prev / pd), _base_dist * 0.35, _base_dist * 2.2)
			_pinch_prev = pd
		else:
			_rotate(d.relative)
		_update_cam()
	elif ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_rotate((ev as InputEventMouseMotion).relative)
		_update_cam()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist * 0.92, _base_dist * 0.35, _base_dist * 2.2)
			_update_cam()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist * 1.08, _base_dist * 0.35, _base_dist * 2.2)
			_update_cam()


func _rotate(rel: Vector2) -> void:
	_yaw += rel.x * 0.01
	_pitch = clampf(_pitch + rel.y * 0.006, -0.6, 0.6)


func _pinch_dist() -> float:
	if _touches.size() < 2:
		return 0.0
	var ks := _touches.keys()
	return (_touches[ks[0]] as Vector2).distance_to(_touches[ks[1]] as Vector2)
