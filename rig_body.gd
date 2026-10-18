extends Node2D
# جسم حي عام: يقرأ هيكل الصورة من assets/rig/<key>.json (تجهز تلقائياً بأداة autorig)
# عظام + ذراعين (لو مفصولة) + وجه يرمش ويبتسم + شعر يتأخر + جلد ينضغط. نفس واجهة live_body.gd

const DIR := "res://assets/rig/"
const SHADER := preload("res://rig_body.gdshader")
const ORDER := ["root", "spine", "chest", "head", "bun", "uarmL", "farmL", "uarmR", "farmR", "thighL", "shinL", "thighR", "shinR"]
const PARENT := {"root": "", "spine": "root", "chest": "spine", "head": "chest", "bun": "head", "uarmL": "chest", "farmL": "uarmL", "uarmR": "chest", "farmR": "uarmR", "thighL": "root", "shinL": "thighL", "thighR": "root", "shinR": "thighR"}
static var _cache := {}

var size := Vector2.ONE
var K := 1.0                 # مقاس الجسم مقارنة بالصورة الأصلية للتجربة (1500 بكسل)
var J := {}                  # مكان كل مفصل
var face := {}
var mid_x := 0.0
var belly_y := 0.0
var face_c := Vector2.ZERO
var face_r := 0.0
var parts := []
var mats := []
var sk: Skeleton2D
var bone_nodes := {}
var bone_path := {}
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
var feet_side := 0.0
var PR := 24.0
var press_c := Vector2(-9999, -9999)
var press_d := 0.0
var press_to := 0.0
var press_rate := 6.0
var drag := Vector2.ZERO
var finger_on := false
var _press_t := 0.0
var _late_release := -1.0

static func key_for(path: String) -> String:
	return path.trim_prefix("res://assets/sprites/").replace("/", "__").trim_suffix(".png")

static func has_rig(path: String) -> bool:
	return FileAccess.file_exists(DIR + key_for(path) + ".rig")

# الهيكل لازم يطابق الصورة (لو انعدلت الصورة وما تجهز هيكلها، نرجع للنسخة البسيطة بدل حركة في غير مكانها)
static func fits(path: String, tex: Texture2D) -> bool:
	var key := key_for(path)
	var d: Dictionary = _cache.get(key, {})
	if d.is_empty():
		d = load_rig(key)
		if d.is_empty(): return false
		_cache[key] = d
	return tex != null and int(d["size"][0]) == tex.get_width() and int(d["size"][1]) == tex.get_height()

# ملف الهيكل: مضغوط (gzip) = طول الرأس + رأس JSON + لكل جزء: نقاط uint16 ومثلثات uint16 وأوزان uint8
static func load_rig(key: String) -> Dictionary:
	var raw := FileAccess.get_file_as_bytes(DIR + key + ".rig")
	if raw.is_empty(): return {}
	var b := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var hl := b.decode_u32(0)
	var d: Dictionary = JSON.parse_string(b.slice(4, 4 + hl).get_string_from_utf8())
	var bones: Array = d["bones"]
	var nb := bones.size()
	var o := 4 + hl
	var parts := {}
	for pm in d["parts"]:
		var nv: int = pm[1]
		var nt: int = pm[2]
		var verts := PackedVector2Array()
		verts.resize(nv)
		for i in nv:
			verts[i] = Vector2(b.decode_u16(o + i * 4), b.decode_u16(o + i * 4 + 2))
		o += nv * 4
		var tris := []
		for i in nt:
			var q := o + i * 6
			tris.append(PackedInt32Array([b.decode_u16(q), b.decode_u16(q + 2), b.decode_u16(q + 4)]))
		o += nt * 6
		var wts := {}
		for j in nb:
			var arr := PackedFloat32Array()
			arr.resize(nv)
			var any := false
			for i in nv:
				var w := float(b[o + i * nb + j]) / 255.0
				arr[i] = w
				if w > 0.02: any = true
			if any: wts[bones[j]] = arr
		# نخلي مجموع الأوزان = 1
		for i in nv:
			var tot := 0.0
			for bn in wts: tot += wts[bn][i]
			if tot > 0.0:
				for bn in wts: wts[bn][i] = wts[bn][i] / tot
		o += nv * nb
		parts[pm[0]] = {"verts": verts, "tris": tris, "w": wts}
	d["parts"] = parts
	return d

func setup(tex: Texture2D, path: String):
	phase = randf() * 10.0
	var key := key_for(path)
	var d: Dictionary = _cache.get(key, {})
	if d.is_empty():
		d = load_rig(key)
		_cache[key] = d
	size = Vector2(d["size"][0], d["size"][1])
	K = float(d.get("scale", 1.0))
	for b in ORDER:
		var jj = d["joints"].get(b, d["joints"]["root"])
		J[b] = Vector2(jj[0], jj[1])
	face = d.get("face", {})
	mid_x = J["root"].x
	belly_y = lerpf(J["chest"].y, J["root"].y, 0.55)
	if not face.is_empty():
		face_c = _v(face["center"])
		face_r = 115.0 * float(face["s"])
	var mask: Texture2D = load(DIR + str(d["mask"])) if d.has("mask") else null
	sk = Skeleton2D.new()
	sk.name = "sk"
	add_child(sk)
	for b in ORDER:
		var bn := Bone2D.new()
		bn.name = b
		bn.set_autocalculate_length_and_angle(false)
		bn.set_length(10.0)
		var par: String = PARENT[b]
		bn.position = J[b] - (Vector2.ZERO if par == "" else J[par])
		bn.rest = Transform2D(0.0, bn.position)
		(sk if par == "" else bone_nodes[par]).add_child(bn)
		bone_nodes[b] = bn
		bone_path[b] = sk.get_path_to(bn)
	var pi := 0
	for pname in ["body", "armL", "armR"]:
		if not d["parts"].has(pname): continue
		var pd: Dictionary = d["parts"][pname]
		var poly := Polygon2D.new()
		poly.texture = tex
		var rest: PackedVector2Array = pd["verts"]
		poly.polygon = rest
		poly.uv = rest
		poly.polygons = pd["tris"]
		var sm := ShaderMaterial.new()
		sm.shader = SHADER
		sm.set_shader_parameter("part", {"body": 0, "armL": 1, "armR": 2}[pname])
		if mask != null: sm.set_shader_parameter("part_mask", mask)
		sm.set_shader_parameter("use_mask", mask != null)
		sm.set_shader_parameter("fig_size", size)
		poly.material = sm
		add_child(poly)
		poly.skeleton = NodePath("../sk")
		for bn in pd["w"]:
			poly.add_bone(bone_path[bn], pd["w"][bn])
		mats.append(sm)
		sm.set_shader_parameter("K", K)
		sm.set_shader_parameter("mid_x", mid_x)
		sm.set_shader_parameter("belly_y", belly_y)
		sm.set_shader_parameter("has_face", not face.is_empty())
		if not face.is_empty():
			for fk in ["eyeA", "eyeB", "rA", "rB", "mL", "mR", "chA", "chB"]:
				sm.set_shader_parameter(fk, _v(face[fk]))
			sm.set_shader_parameter("face_c", face_c)
			sm.set_shader_parameter("face_r", face_r)
			sm.set_shader_parameter("fs", float(face["s"]))
		pi += 1
	for n in ["sway", "lean", "head", "chestY", "shrugL", "shrugR", "armL", "farmL", "armR", "farmR", "legL", "kneeL", "legR", "kneeR"]:
		spring(n, 90.0)
	spring("bun", 38.0, 4.5)
	spring("blink", 420.0)
	spring("smile", 55.0)
	spring("turn", 70.0)
	spring("bob", 160.0)
	spring("suck", 90.0)
	for n in sp:
		if n != "bun": sp[n]["c"] = maxf(sp[n]["c"], 1.75 * sqrt(sp[n]["k"]))
	target("smile", 0.3)

func _v(a) -> Vector2: return Vector2(a[0], a[1])

func spring(n: String, k := 90.0, c := 11.0):
	sp[n] = {"x": 0.0, "v": 0.0, "to": 0.0, "k": k, "c": c}
func target(n: String, v: float): sp[n]["to"] = v
func val(n: String) -> float: return sp[n]["x"]

# ===== اللمس =====
func press(pt: Vector2):
	_press_t = t; _late_release = -1.0
	press_c = pt; press_to = 1.0; press_rate = 7.0; finger_on = true; drag = Vector2.ZERO
	PR = _radius(pt) * K

func press_move(pt: Vector2, dt: float):
	var v := (pt - press_c) / maxf(dt, 0.001)
	drag = drag.lerp(v.limit_length(220.0 * K) * 0.045, 0.25)
	press_c = pt

func release():
	if t - _press_t < 0.45:
		_late_release = _press_t + 0.45
		return
	press_to = 0.0; press_rate = 2.4; finger_on = false

func _radius(pt: Vector2) -> float:
	if pt.y < J["head"].y - (J["head"].y - J["bun"].y) * 0.55: return 34.0
	if pt.y < J["head"].y: return 15.0
	if absf(pt.x - mid_x) > absf(J["uarmR"].x - J["uarmL"].x) * 0.42: return 22.0
	if pt.y > size.y * 0.9: return 20.0
	return 24.0

func react(zone: String, kind: String, pt: Vector2):
	var s := -1.0 if pt.x < mid_x else 1.0
	calm_at = t + 1.4
	match kind:
		"annoyed", "cold":
			_r(1.8 * s, 7.0 * s, 0.9 * s, -0.2, 0, 0, 0, -1, 30); return
		"tickle":
			_r(0, 0, 0, 1.2, -10, -10, 1.0, 0.55, 45); tickle_until = t + 1.3; calm_at = t + 1.9; return
	var held := kind.begins_with("hold")
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
			if absf(pt.x - mid_x) < 60.0 * K:
				_r(0, 0, 0, 1.2, -10, -10, 1.0, 0.55, 45); tickle_until = t + 1.2
			else:
				_r(3.0 * s, 5.0 * s, 0.6 * s, 1.1, -8 if s < 0 else 0, 0 if s < 0 else -8, 0.6, 0.5, 35); tickle_until = t + 0.9
		"leg":
			_r(-1.8 * s, -4.0 * s, -0.4 * s, 0.6, 0, 0, 0, -1, 25)
			if s < 0:
				target("legL", -3.5); target("kneeL", 6.0)
			else:
				target("legR", 3.5); target("kneeR", -6.0)
		"feet":
			_r(0, 0, 0, 1.2, -8, -8, 0, 0.55, 40); tickle_until = t + 1.4; calm_at = t + 2.0
			feet_side = s
		_: _r(0.8 * s, 4.0 * s, 0.3 * s, 0.7, 0, 0, 0, -1, 25)
	if held: calm_at = maxf(calm_at, t + 2.0)

func _r(sw: float, hd: float, tn: float, sm: float, sl: float, sr: float, su: float, bl: float, bob: float):
	extra_sway = sw; extra_head = hd
	target("turn", tn); target("smile", sm); target("shrugL", sl * K); target("shrugR", sr * K); target("suck", su)
	force_blink = bl
	sp["bob"]["v"] = bob * K

func calm():
	extra_sway = 0.0; extra_head = 0.0
	for n in ["turn", "shrugL", "shrugR", "suck", "armL", "farmL", "armR", "farmR", "legL", "kneeL", "legR", "kneeR"]: target(n, 0.0)
	feet_side = 0.0
	target("smile", 0.3)
	force_blink = -1.0

# ===== الهيكل =====
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
		"thighL": rot = val("legL")
		"shinL": rot = val("kneeL")
		"thighR": rot = val("legR")
		"shinR": rot = val("kneeR")
	return Transform2D(deg_to_rad(rot), sc, 0.0, rel + off)

func _process(delta: float):
	if mats.is_empty(): return
	t += delta
	if _late_release > 0.0 and t >= _late_release:
		_late_release = -1.0
		press_to = 0.0; press_rate = 2.4; finger_on = false
	if calm_at > 0.0 and t >= calm_at:
		calm_at = -1.0
		calm()
	var tk := t < tickle_until
	var k := int(t / 0.12)
	target("sway", 0.7 * sin(TAU * (t + phase) / 5.2) + extra_sway + ((2.6 if k % 2 == 0 else -2.6) if tk else 0.0))
	target("head", 1.0 * sin(TAU * (t + phase) / 6.3) + extra_head + ((-3.5 if k % 2 == 0 else 3.5) if tk else 0.0))
	target("chestY", 0.012 * sin(TAU * (t + phase) / (1.8 if tk else 3.6)))
	if tk:
		var lw := 2.2 if k % 2 == 0 else -2.2
		target("legL", -absf(lw) if feet_side <= 0.0 and k % 2 == 0 else -0.6)
		target("kneeL", absf(lw) * 1.6 if feet_side <= 0.0 and k % 2 == 0 else 1.0)
		target("legR", absf(lw) if feet_side >= 0.0 and k % 2 == 1 else 0.6)
		target("kneeR", -absf(lw) * 1.6 if feet_side >= 0.0 and k % 2 == 1 else -1.0)
	for n in sp:
		var s: Dictionary = sp[n]
		s["v"] += (s["k"] * (s["to"] - s["x"]) - s["c"] * s["v"]) * delta
		s["x"] += s["v"] * delta
	sp["bun"]["to"] = -(val("head") + val("sway") + val("lean")) * 0.4
	if t >= next_blink:
		blink_until = t + 0.12
		next_blink = t + randf_range(2.4, 4.8)
	target("blink", force_blink if force_blink >= 0.0 else (1.0 if t < blink_until else 0.0))
	press_d += (press_to - press_d) * (1.0 - exp(-press_rate * delta))
	if not finger_on: drag = drag.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	for b in ORDER:
		var par: String = PARENT[b]
		bone_nodes[b].transform = local(b, J[b] - (Vector2.ZERO if par == "" else J[par]))
	for m in mats:
		m.set_shader_parameter("press_c", press_c)
		m.set_shader_parameter("press_d", press_d)
		m.set_shader_parameter("press_r", PR)
		m.set_shader_parameter("drag", drag)
		m.set_shader_parameter("suck", val("suck"))
		m.set_shader_parameter("blink", clampf(val("blink"), 0.0, 1.0))
		m.set_shader_parameter("smile", val("smile"))
		m.set_shader_parameter("turn", val("turn"))

func set_light(amb: Color, side: float, lit: float):
	for m in mats:
		m.set_shader_parameter("amb", Vector3(amb.r, amb.g, amb.b))
		m.set_shader_parameter("side", side)
		m.set_shader_parameter("lit", lit)
