extends Node2D
# جسم حي فوق صورة الشخصية: شبكة خفيفة يحركها كرت الشاشة (live_body.gdshader)
# يشتغل تلقائياً على أي صورة بدون تجهيز يدوي. الحركة كلها نوابض مخمّدة (بدون اهتزاز زايد).

const SHADER := preload("res://live_body.gdshader")
static var _mesh_cache := {}

var poly: Polygon2D
var mat: ShaderMaterial
var size := Vector2.ONE
var wide := false
var t := 0.0
var phase := 0.0
var sp := {}
var press_c := Vector2(-9999, -9999)
var press_d := 0.0
var press_to := 0.0
var press_rate := 6.0
var press_r := 30.0
var drag := Vector2.ZERO
var _prev_c := Vector2.ZERO
var _tickle := 0.0
var _timers: Array = []

func setup(tex: Texture2D, key: String):
	phase = randf() * 10.0
	var m: Dictionary = _mesh_cache.get(key, {})
	if m.is_empty():
		m = build_mesh(tex)
		_mesh_cache[key] = m
	size = m["size"]
	wide = m["wide"]
	press_r = maxf(size.x, size.y) * 0.03
	poly = Polygon2D.new()
	poly.texture = tex
	poly.polygon = m["verts"]
	poly.uv = m["verts"]
	poly.polygons = m["tris"]
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("wide", 1.0 if wide else 0.0)
	mat.set_shader_parameter("neck", m["neck"])
	poly.material = mat
	add_child(poly)
	for n in ["sway", "head", "sh_l", "sh_r", "suck"]: spring(n, 70.0)
	spring("bounce", 160.0)

func spring(n: String, k: float):
	sp[n] = {"x": 0.0, "v": 0.0, "to": 0.0, "k": k, "c": 1.75 * sqrt(k)}
func val(n: String) -> float: return sp[n]["x"]
func goal(n: String, v: float): sp[n]["to"] = v

static func build_mesh(tex: Texture2D) -> Dictionary:
	var img := tex.get_image()
	if img == null: return {}
	if img.is_compressed(): img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(8, int(maxf(w, h) / 80.0))
	var nx := int(ceil(float(w) / step))
	var ny := int(ceil(float(h) / step))
	var idx := {}
	var verts := PackedVector2Array()
	var tris := []
	for j in ny:
		for i in nx:
			var x0 := i * step
			var y0 := j * step
			var hit := false
			for sy in 4:
				for sx in 4:
					if img.get_pixel(mini(x0 + sx * step / 3, w - 1), mini(y0 + sy * step / 3, h - 1)).a > 0.04:
						hit = true
						break
				if hit: break
			if not hit: continue
			var q := []
			for c in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				if not idx.has(c):
					idx[c] = verts.size()
					verts.append(Vector2(minf(c.x * step, w), minf(c.y * step, h)))
				q.append(idx[c])
			tris.append(PackedInt32Array([q[0], q[1], q[2]]))
			tris.append(PackedInt32Array([q[0], q[2], q[3]]))
	var is_wide := w > h * 1.15
	return {"size": Vector2(w, h), "wide": is_wide, "verts": verts, "tris": tris, "neck": find_neck(img, is_wide)}

# الرقبة = أضيق صف في الجزء الفوقي (للصور الواقفة والجالسة)
static func find_neck(img: Image, is_wide: bool) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	if is_wide:
		var l := 0.0
		var r := 0.0
		for y in range(0, int(h * 0.5), 4):
			for x in range(0, w, 4):
				if img.get_pixel(x, y).a > 0.3:
					if x < w / 2: l += 1.0
					else: r += 1.0
		return Vector2(0.72, 0.45) if r > l else Vector2(0.28, 0.45)
	var best_y := int(h * 0.2)
	var best_w := 1e9
	var best_c := w * 0.5
	for y in range(int(h * 0.12), int(h * 0.34), 3):
		var a := -1
		var b := -1
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5:
				if a < 0: a = x
				b = x
		if a >= 0 and float(b - a) < best_w:
			best_w = b - a
			best_y = y
			best_c = (a + b) * 0.5
	return Vector2(best_c / w, float(best_y) / h)

# ===== اللمس =====
# الإصبع نزل على الجسم: الجلد ينضغط بنعومة
func press(pt: Vector2):
	press_c = pt
	_prev_c = pt
	press_to = 1.0
	press_rate = 7.0
	drag = Vector2.ZERO

# الإصبع يتحرك وهو ضاغط: الحفرة تمشي والجلد ينسحب معه
func press_move(pt: Vector2, dt: float):
	var v := (pt - _prev_c) / maxf(dt, 0.001)
	drag = drag.lerp(v.limit_length(size.y * 0.15) * 0.04, 0.25)
	_prev_c = pt
	press_c = pt

# الإصبع ارتفع: يرجع ببطء مثل الجلد
func release():
	press_to = 0.0
	press_rate = 2.4

# ردة فعل الجسم حسب المكان ونوع اللمسة
func react(zone: String, kind: String, pt: Vector2):
	var side := -1.0 if pt.x < size.x * 0.5 else 1.0
	sp["bounce"]["v"] = -0.18
	match kind:
		"annoyed", "cold":
			_pose(0.06 * side, 0.08 * side, 0.0, 0.0, 0.0, 0.7)
			return
		"tickle":
			_tickle = 1.3
			_pose(0.0, 0.0, 1.0, 1.0, 0.8, 1.3)
			return
	if kind.begins_with("hold"):
		_pose(-0.04 * side, -0.12 * side, 0.3, 0.3, 0.0, 1.4)
		return
	match zone:
		"head": _pose(-0.015 * side, -0.16 * side, 0.2, 0.2, 0.0, 1.1)
		"face": _pose(0.02 * side, 0.10 * side, 0.0, 0.0, 0.0, 0.9)
		"shoulder": _pose(0.03 * side, 0.09 * side, 1.0 if side < 0 else 0.0, 1.0 if side > 0 else 0.0, 0.0, 1.1)
		"arm", "hand": _pose(-0.03 * side, -0.08 * side, 0.4 if side < 0 else 0.0, 0.4 if side > 0 else 0.0, 0.0, 1.0)
		"waist", "body":
			_tickle = 0.7
			_pose(0.05 * side, 0.08 * side, 0.6, 0.6, 1.0, 1.1)
		"leg": _pose(-0.03 * side, -0.05 * side, 0.0, 0.0, 0.2, 1.0)
		"feet":
			_tickle = 1.1
			_pose(0.0, 0.0, 0.8, 0.8, 0.5, 1.2)
		_: _pose(0.02 * side, 0.05 * side, 0.0, 0.0, 0.0, 0.9)

func _pose(sw: float, hd: float, sl: float, sr: float, su: float, dur: float):
	goal("sway", sw); goal("head", hd); goal("sh_l", sl); goal("sh_r", sr); goal("suck", su)
	_timers.append([t + dur, func():
		for n in ["sway", "head", "sh_l", "sh_r", "suck"]: goal(n, 0.0)])

func _process(delta: float):
	if mat == null: return
	t += delta
	for tm in _timers.duplicate():
		if t >= tm[0]:
			_timers.erase(tm)
			tm[1].call()
	var wig := 0.0
	var hwig := 0.0
	if _tickle > 0.0:
		_tickle -= delta
		var k := int(t / 0.12)
		wig = 0.045 if k % 2 == 0 else -0.045
		hwig = -0.06 if k % 2 == 0 else 0.06
	for n in sp:
		var s: Dictionary = sp[n]
		s["v"] += (s["k"] * (s["to"] - s["x"]) - s["c"] * s["v"]) * delta
		s["x"] += s["v"] * delta
	press_d += (press_to - press_d) * (1.0 - exp(-press_rate * delta))
	if press_to <= 0.0: drag = drag.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	var breath_rate := 3.6 if _tickle <= 0.0 else 1.6
	mat.set_shader_parameter("breath", sin(TAU * (t + phase) / breath_rate))
	mat.set_shader_parameter("sway", val("sway") + wig + 0.012 * sin(TAU * (t + phase) / 5.2))
	mat.set_shader_parameter("head", val("head") + hwig + 0.016 * sin(TAU * (t + phase) / 6.3))
	mat.set_shader_parameter("sh_l", val("sh_l"))
	mat.set_shader_parameter("sh_r", val("sh_r"))
	mat.set_shader_parameter("suck", val("suck"))
	mat.set_shader_parameter("bounce", val("bounce") * 0.06)
	mat.set_shader_parameter("press_c", press_c)
	mat.set_shader_parameter("press_r", press_r)
	mat.set_shader_parameter("press_d", press_d)
	mat.set_shader_parameter("drag", drag)
