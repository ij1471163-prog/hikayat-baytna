extends Node2D
# ليان بهيكل كامل (نفس التجربة): عظام + ذراعين منفصلة + وجه يرمش ويبتسم + شعر يتأخر + جلد ينضغط
# نفس واجهة live_body.gd: press / press_move / release / react

const DIR := "res://assets/rig/layan_home/"
const SHADER := preload("res://layan_rig.gdshader")
static var _data := {}

var size := Vector2(1024, 1536)
var BONES := {
	"root":  {"p": "",      "j": Vector2(515, 640)},
	"spine": {"p": "root",  "j": Vector2(515, 640)},
	"chest": {"p": "spine", "j": Vector2(515, 470)},
	"head":  {"p": "chest", "j": Vector2(515, 305)},
	"bun":   {"p": "head",  "j": Vector2(485, 95)},
	"uarmL": {"p": "chest", "j": Vector2(392, 352)},
	"farmL": {"p": "uarmL", "j": Vector2(345, 600)},
	"uarmR": {"p": "chest", "j": Vector2(632, 352)},
	"farmR": {"p": "uarmR", "j": Vector2(690, 600)},
}
const ORDER := ["root", "spine", "chest", "head", "bun", "uarmL", "farmL", "uarmR", "farmR"]
const EYE_L := Vector2(496, 214)
const EYE_R := Vector2(557, 200)

var parts := []
var sp := {}
var t := 0.0
var phase := 0.0
var skin_m := {}
var next_blink := 1.6
var blink_until := 0.0
var force_blink := -1.0
var extra_sway := 0.0
var extra_head := 0.0
var tickle_until := 0.0
var calm_at := -1.0
var PR := 24.0
var press_c := Vector2(-9999, -9999)
var press_d := 0.0
var press_to := 0.0
var press_rate := 6.0
var drag := Vector2.ZERO
var finger_on := false
var _acc := 0.0

static func available() -> bool:
	return ResourceLoader.exists(DIR + "part_body.png") and FileAccess.file_exists(DIR + "mesh.json")

func setup(_tex: Texture2D = null, _key: String = ""):
	phase = randf() * 10.0
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "mesh.json"))
	for pname in ["body", "armL", "armR"]:
		var pd: Dictionary = _data["parts"][pname]
		var off := Vector2(pd["off"][0], pd["off"][1])
		var poly := Polygon2D.new()
		poly.texture = load(DIR + str(pd["tex"]))
		var rest := PackedVector2Array()
		var uv := PackedVector2Array()
		for v in pd["verts"]:
			rest.append(Vector2(v[0], v[1]))
			uv.append(Vector2(v[0], v[1]) - off)
		poly.polygon = rest
		poly.uv = uv
		var tris := []
		for tr in pd["tris"]: tris.append(PackedInt32Array(tr))
		poly.polygons = tris
		var sm := ShaderMaterial.new()
		sm.shader = SHADER
		sm.set_shader_parameter("tex_off", off)
		poly.material = sm
		add_child(poly)
		# أوزان العظام لكل نقطة (أقصى 3)
		var W: Dictionary = pd["weights"]
		var vb := []
		var face := PackedInt32Array()
		for i in rest.size():
			var lst := []
			var tot := 0.0
			for b in W:
				var w: float = W[b][i]
				if w > 0.02:
					lst.append([b, w]); tot += w
			for e in lst: e[1] /= tot
			vb.append(lst)
			var p := rest[i]
			if pname == "body" and p.y < 300 and p.x > 420 and p.x < 640: face.append(i)
		parts.append({"poly": poly, "rest": rest, "vb": vb, "face": face, "out": rest.duplicate()})
	for n in ["sway", "lean", "head", "chestY", "shrugL", "shrugR", "armL", "farmL", "armR", "farmR"]:
		spring(n, 90.0)
	spring("bun", 38.0, 4.5)
	spring("x", 30.0)
	spring("lean", 60.0)
	spring("blink", 420.0)
	spring("smile", 55.0)
	spring("turn", 70.0)
	spring("bob", 160.0)
	spring("suck", 90.0)
	for n in sp:
		if n != "bun": sp[n]["c"] = maxf(sp[n]["c"], 1.75 * sqrt(sp[n]["k"]))
	target("smile", 0.3)

func spring(n: String, k := 90.0, c := 11.0):
	sp[n] = {"x": 0.0, "v": 0.0, "to": 0.0, "k": k, "c": c}
func target(n: String, v: float): sp[n]["to"] = v
func val(n: String) -> float: return sp[n]["x"]

# ===== اللمس =====
func press(pt: Vector2):
	press_c = pt; press_to = 1.0; press_rate = 7.0; finger_on = true; drag = Vector2.ZERO
	PR = _radius(pt)

func press_move(pt: Vector2, dt: float):
	var v := (pt - press_c) / maxf(dt, 0.001)
	drag = drag.lerp(v.limit_length(220.0) * 0.045, 0.25)
	press_c = pt

func release():
	press_to = 0.0; press_rate = 2.4; finger_on = false

func _radius(pt: Vector2) -> float:
	if pt.y < 180: return 34.0          # راس
	if pt.y < 300: return 15.0          # وجه
	if pt.x < 430 or pt.x > 630: return 22.0 if pt.y < 800 else 18.0
	if pt.y > 1380: return 20.0         # قدم
	return 24.0

# ردة الفعل حسب المكان (نفس حركات التجربة، وتنعكس حسب الجهة)
func react(zone: String, kind: String, pt: Vector2):
	var s := -1.0 if pt.x < 515.0 else 1.0    # الجهة اللي انلمست
	calm_at = t + 1.4
	match kind:
		"annoyed", "cold":
			_r(1.8 * s, 7.0 * s, 0.9 * s, -0.2, 0, 0, 0, -1, 30); return
		"tickle":
			_r(0, 0, 0, 1.2, -10, -10, 1.0, 0.55, 45); tickle_until = t + 1.3; calm_at = t + 1.9; return
	if kind.begins_with("hold"):
		_r(-1.6 * s, -9.0 * s, -0.6 * s, 1.0, -3, -3, 0, 0.8, 15); calm_at = t + 2.0; return
	match zone:
		"head": _r(-1.0 * s, -10.0 * s, 0, 1.0, -4 if s < 0 else 0, 0 if s < 0 else -4, 0, 1.0, 15)
		"face": _r(0.8 * s, 6.0 * s, 0.5 * s, 1.0, 0, 0, 0, 0.4, 30)
		"shoulder": _r(1.2 * s, 6.0 * s, 0.9 * s, 0.7, -12 if s < 0 else 0, 0 if s < 0 else -12, 0, -1, 25)
		"arm": _r(-1.2 * s, -5.0 * s, -0.9 * s, 0.7, -3 if s < 0 else 0, 0 if s < 0 else -3, 0, -1, 25)
		"hand":
			_r(-2.2 * s, -6.0 * s, -1.0 * s, 0.9, -6 if s < 0 else 0, 0 if s < 0 else -6, 0, -1, 25)
			if s < 0:
				target("armL", 5.0); target("farmL", 6.0)
			else:
				target("armR", -5.0); target("farmR", -6.0)
			calm_at = t + 1.6
		"waist", "body":
			if absf(pt.x - 515.0) < 60.0:
				_r(0, 0, 0, 1.2, -10, -10, 1.0, 0.55, 45); tickle_until = t + 1.2
			else:
				_r(3.0 * s, 5.0 * s, 0.6 * s, 1.1, -8 if s < 0 else 0, 0 if s < 0 else -8, 0.6, 0.5, 35); tickle_until = t + 0.9
		"leg": _r(-1.8 * s, -4.0 * s, -0.4 * s, 0.6, 0, 0, 0, -1, 25)
		"feet":
			_r(0, 0, 0, 1.2, -8, -8, 0, 0.55, 40); tickle_until = t + 1.4; calm_at = t + 2.0
		_: _r(0.8 * s, 4.0 * s, 0.3 * s, 0.7, 0, 0, 0, -1, 25)

func _r(sw: float, hd: float, tn: float, sm: float, sl: float, sr: float, su: float, bl: float, bob: float):
	extra_sway = sw; extra_head = hd
	target("turn", tn); target("smile", sm); target("shrugL", sl); target("shrugR", sr); target("suck", su)
	force_blink = bl
	sp["bob"]["v"] = bob

func calm():
	extra_sway = 0.0; extra_head = 0.0
	for n in ["turn", "shrugL", "shrugR", "suck", "armL", "farmL", "armR", "farmR"]: target(n, 0.0)
	target("smile", 0.3)
	force_blink = -1.0

# ===== الهيكل =====
func world(name: String) -> Transform2D:
	var b: Dictionary = BONES[name]
	var par: String = b["p"]
	var base := Transform2D.IDENTITY if par == "" else world(par)
	var rel: Vector2 = b["j"] - (Vector2.ZERO if par == "" else BONES[par]["j"])
	return base * local(name, rel)

func local(name: String, rel: Vector2) -> Transform2D:
	var rot := 0.0
	var sc := Vector2.ONE
	var off := Vector2.ZERO
	match name:
		"root": off = Vector2(0, val("bob"))
		"spine": rot = val("sway") + val("lean")
		"chest":
			sc = Vector2(1.0 + val("chestY") * 0.45, 1.0 + val("chestY"))
			rot = -val("sway") * 0.4
		"head": rot = val("head") - val("sway") * 0.3
		"bun": rot = val("bun")
		"uarmL": rot = val("armL"); off = Vector2(0, val("shrugL"))
		"farmL": rot = val("farmL")
		"uarmR": rot = val("armR"); off = Vector2(0, val("shrugR"))
		"farmR": rot = val("farmR")
	return Transform2D(deg_to_rad(rot), sc, 0.0, rel + off)

func eye_d(p: Vector2, c: Vector2, rx: float, ry: float, b: float) -> Vector2:
	var dx := absf(p.x - c.x)
	if dx > rx * 1.5: return Vector2.ZERO
	var wx := 1.0 - smoothstep(rx, rx * 1.5, dx)
	var lid := c.y + ry * 0.35
	var wv := 0.0
	if p.y < lid:
		wv = 1.0 if p.y >= c.y - ry else clampf(1.0 - (c.y - ry - p.y) / (ry * 1.3), 0.0, 1.0)
	else:
		wv = 1.0 if p.y <= c.y + ry else clampf(1.0 - (p.y - c.y - ry) / (ry * 0.8), 0.0, 1.0)
	return Vector2(0, b * 0.95 * (lid - p.y) * wv * wx)

func bump(p: Vector2, c: Vector2, off: Vector2, r: float) -> Vector2:
	var d2 := p.distance_squared_to(c)
	return Vector2.ZERO if d2 > r * r * 6.0 else off * exp(-d2 / (r * r))

func face_d(p: Vector2) -> Vector2:
	var d := Vector2.ZERO
	var b: float = clampf(val("blink"), 0.0, 1.0)
	if b > 0.01: d += eye_d(p, EYE_L, 16.0, 10.0, b) + eye_d(p, EYE_R, 15.0, 10.0, b)
	var sm: float = val("smile")
	if absf(sm) > 0.01:
		d += bump(p, Vector2(530, 257), Vector2(-1.5, -4.0) * sm, 10.0) + bump(p, Vector2(553, 251), Vector2(1.5, -4.5) * sm, 10.0)
		d += bump(p, Vector2(500, 240), Vector2(0, -2.2) * sm, 17.0) + bump(p, Vector2(566, 230), Vector2(0, -2.2) * sm, 17.0)
	var tn: float = val("turn")
	if absf(tn) > 0.01:
		var r := p.distance_to(Vector2(527, 225))
		if r < 115.0: d.x += tn * 9.0 * (1.0 - (r / 115.0) * (r / 115.0))
	return d

func _process(delta: float):
	if parts.is_empty(): return
	t += delta
	if calm_at > 0.0 and t >= calm_at:
		calm_at = -1.0
		calm()
	var tk := t < tickle_until
	var k := int(t / 0.12)
	target("sway", 0.7 * sin(TAU * (t + phase) / 5.2) + extra_sway + ((2.6 if k % 2 == 0 else -2.6) if tk else 0.0))
	target("head", 1.0 * sin(TAU * (t + phase) / 6.3) + extra_head + ((-3.5 if k % 2 == 0 else 3.5) if tk else 0.0))
	target("chestY", 0.012 * sin(TAU * (t + phase) / (1.8 if tk else 3.6)))
	for n in sp:
		var s: Dictionary = sp[n]
		s["v"] += (s["k"] * (s["to"] - s["x"]) - s["c"] * s["v"]) * delta
		s["x"] += s["v"] * delta
	sp["bun"]["to"] = -(val("head") + val("sway") + val("lean")) * 0.9
	if t >= next_blink:
		blink_until = t + 0.12
		next_blink = t + randf_range(2.4, 4.8)
	target("blink", force_blink if force_blink >= 0.0 else (1.0 if t < blink_until else 0.0))
	press_d += (press_to - press_d) * (1.0 - exp(-press_rate * delta))
	if not finger_on: drag = drag.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	# تحديث الشبكة 30 مرة بالثانية (يخفف على الجوال)
	_acc += delta
	if _acc < 1.0 / 30.0: return
	_acc = 0.0
	for b in ORDER:
		skin_m[b] = world(b) * Transform2D(0.0, -BONES[b]["j"])
	var hm: Transform2D = skin_m["head"]
	var cm: Transform2D = skin_m["chest"]
	var pressing := press_d > 0.003
	var su: float = val("suck")
	for pi in parts.size():
		var pt: Dictionary = parts[pi]
		var rest: PackedVector2Array = pt["rest"]
		var vb: Array = pt["vb"]
		var out: PackedVector2Array = pt["out"]
		var m: ShaderMaterial = pt["poly"].material
		m.set_shader_parameter("press_c", press_c)
		m.set_shader_parameter("press_d", press_d)
		m.set_shader_parameter("press_r", PR)
		for i in rest.size():
			var p := rest[i]
			var acc := Vector2.ZERO
			for e in vb[i]:
				acc += (skin_m[e[0]] * p) * float(e[1])
			if pressing:
				var r := p.distance_to(press_c)
				if r < PR * 2.8:
					var f := exp(-(r * r) / (PR * PR))
					var g := exp(-pow((r - PR * 1.5) / (PR * 0.55), 2.0))
					var dir := (p - press_c) / maxf(r, 1.0)
					acc += cm.basis_xform((press_c - p) * 0.17 * press_d * f + dir * 2.4 * press_d * g + drag * f * press_d)
			if su > 0.003 and p.y > 540.0 and p.y < 640.0:
				var wy := smoothstep(540.0, 570.0, p.y) * (1.0 - smoothstep(600.0, 640.0, p.y))
				acc += cm.basis_xform(Vector2((515.0 - p.x) * 0.07 * su * wy, -3.0 * su * wy))
			out[i] = acc
		for i in pt["face"]:
			var fd := face_d(rest[i])
			if fd != Vector2.ZERO: out[i] += hm.basis_xform(fd)
		pt["poly"].polygon = out

func set_light(amb: Color, side: float, lit: float):
	for m in _mats():
		m.set_shader_parameter("amb", Vector3(amb.r, amb.g, amb.b))
		m.set_shader_parameter("side", side)
		m.set_shader_parameter("lit", lit)

func _mats() -> Array:
	var a := []
	for pt in parts: a.append(pt["poly"].material)
	return a
