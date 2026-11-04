extends SceneTree
# اختبار آلي لمحرك IVG: يحاكي اللمس والحركات ويتحقق من النتائج.
const Cond = preload("res://ivg/ivg_cond.gd")
const Engine_ = preload("res://ivg/ivg_engine.gd")
var DIR := OS.get_environment("IVG_DIR")

var eng
var fails := 0
var result := {}

func ok(cond: bool, msg: String):
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond: fails += 1

func wait(sec: float):
	await create_timer(sec).timeout

func cur() -> String:
	return str(eng._cur.get("name", ""))

func pos(u: float, v: float) -> Vector2:
	var r: Rect2 = eng.content_rect()
	return r.position + Vector2(u * r.size.x, v * r.size.y)

func btn(pressed: bool, p: Vector2):
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	eng._on_input(e)

func mot(p: Vector2):
	var e := InputEventMouseMotion.new()
	e.position = p
	eng._on_input(e)

func tap(p: Vector2):
	btn(true, p)
	btn(false, p)

func wait_clip(n: String, timeout := 4.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cur() == n: return true
		await process_frame
		t += 0.016
	return cur() == n

func _initialize():
	await _run()
	print("=== FAILS: %d ===" % fails)
	quit(1 if fails > 0 else 0)

func _run():
	# ---- المحلل الشرطي
	var v := {"mood": 70.0, "trust": 1.0, "اسم": "x", "angry": 0.0}
	ok(Cond.check("mood >= 60", v), "cond: mood >= 60")
	ok(not Cond.check("mood < 60", v), "cond: mood < 60 false")
	ok(Cond.check("mood >= 60 && (trust > 2 || !angry)", v), "cond: compound with !")
	ok(Cond.check("trust + 1 == 2", v), "cond: arithmetic")
	ok(Cond.check("missing == 0", v), "cond: missing var is 0")
	ok(Cond.check("اسم == 'x'", v), "cond: arabic var + string")
	ok(not Cond.check("mood >", v), "cond: bad expr returns false")
	ok(Cond.check("", v) and Cond.check(null, v), "cond: empty is true")
	ok(Cond.check("-1 < 0 && 10/2 == 5", v), "cond: unary minus / division")

	# ---- المحرك
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var scene = JSON.parse_string(FileAccess.get_file_as_string(DIR + "scene.json"))
	ok(typeof(scene) == TYPE_DICTIONARY, "scene.json parsed")
	eng = Engine_.new()
	eng.setup(scene, DIR, {"muted": OS.get_environment("IVG_UNMUTED") == "", "debug": true})
	eng.finished.connect(func(r): result = r)
	holder.add_child(eng)
	await process_frame
	await process_frame
	print("engine size: ", eng.size)
	ok(await wait_clip("idle", 6.0), "starts on idle clip (mp4 name remapped to ogv)")
	await wait(0.5)
	var r: Rect2 = eng.content_rect()
	print("content rect: ", r, " video size: ", eng._video_size())
	ok(absf(r.size.x / r.size.y - 16.0 / 9.0) < 0.05, "content rect keeps 16:9")
	ok(eng._meter_bars.has("mood") and eng._meter_bars.has("trust"), "meters built")
	ok(eng._active.stream_position > 0.0, "video is actually playing (stream_position=%.2f)" % eng._active.stream_position)

	# ---- tap على الراس
	var m0: float = eng.vars["mood"]
	tap(pos(0.5, 0.39))
	await wait(0.3)
	ok(cur() in ["happy", "laugh", "laugh2"], "tap head -> reaction clip (%s)" % cur())
	ok(eng.vars["mood"] > m0, "tap head raised mood (%s -> %s)" % [m0, eng.vars["mood"]])
	ok(await wait_clip("idle", 4.0), "reaction clip returns to idle (then)")
	await wait(0.4)

	# ---- hold على الراس
	var t0: float = eng.vars["trust"]
	btn(true, pos(0.5, 0.39))
	await wait(0.9)
	btn(false, pos(0.5, 0.39))
	ok(eng.vars["trust"] == t0 + 1.0, "hold head -> trust +1 (%s)" % eng.vars["trust"])
	ok(await wait_clip("idle", 4.0), "back to idle after hold")
	await wait(0.4)

	# ---- مسح على البطن (rub)
	var m1: float = eng.vars["mood"]
	var b := pos(0.5, 0.69)
	btn(true, b)
	mot(b + Vector2(30, 0))
	mot(b + Vector2(0, 0))
	mot(b + Vector2(30, 0))
	mot(b + Vector2(0, 0))
	btn(false, b)
	await wait(0.3)
	ok(cur() in ["laugh", "laugh2"], "rub belly -> laugh (%s)" % cur())
	ok(eng.vars["mood"] == m1 + 4.0, "rub raised mood by 4 (%s)" % eng.vars["mood"])
	ok(await wait_clip("idle", 4.0), "back to idle after rub")
	await wait(0.4)

	# ---- tap على البطن بدون rub -> shy
	tap(b)
	await wait(0.25)
	ok(cur() == "shy", "tap belly -> shy (%s)" % cur())
	ok(await wait_clip("idle", 4.0), "back to idle after shy (inherit keeps hotspots)")
	await wait(0.4)

	# ---- سحب لفوق -> talk (mood >= 55)
	ok(eng.vars["mood"] >= 55.0, "mood >= 55 before swipe (%s)" % eng.vars["mood"])
	var s := pos(0.8, 0.85)
	btn(true, s)
	mot(s + Vector2(0, -120))
	btn(false, s + Vector2(0, -200))
	await wait(0.4)
	ok(cur() == "talk", "swipe-up -> talk (%s)" % cur())

	# ---- pause + اختيارات
	var waited := 0.0
	while not eng._choice_box.visible and waited < 4.0:
		await process_frame
		waited += 0.016
	ok(eng._choice_box.visible, "pause at 1.0s shows choices")
	ok(eng._active.paused, "video paused during choice")
	var nb := 0
	for ch in eng._choice_box.get_children():
		if ch is Button: nb += 1
	ok(nb == 3, "3 choices visible (trust < 3 gate passes) -> %d" % nb)
	var first: Button = null
	for ch in eng._choice_box.get_children():
		if ch is Button:
			first = ch
			break
	var m2: float = eng.vars["mood"]
	first.pressed.emit()
	await wait(0.4)
	ok(cur() == "happy", "choice 'yalla' -> happy (%s)" % cur())
	ok(eng.vars["mood"] >= m2, "choice raised mood")
	ok(not eng._choice_box.visible, "choices hidden after pick")
	ok(not eng._active.paused, "video resumes after choice (new clip)")
	ok(await wait_clip("idle", 4.0), "back to idle")
	await wait(0.4)

	# ---- double tap -> jump + QTE
	var d := pos(0.8, 0.85)
	tap(d)
	await wait(0.1)
	tap(d + Vector2(2, 2))
	await wait(0.3)
	ok(cur() == "jump", "double tap -> jump (%s)" % cur())
	var tr: float = eng.vars["trust"]
	var g := 0.0
	while eng._active.stream_position < 0.7 and g < 4.0:
		await process_frame
		g += 0.016
	await wait(0.2)
	ok(eng._hint_layer.get_child_count() > 0, "QTE hint bubble visible")
	tap(pos(0.5, 0.3))
	await wait(0.3)
	ok(cur() == "catch", "QTE tap in window -> catch (%s)" % cur())
	ok(eng.vars["trust"] == tr + 1.0, "QTE success trust +1 (%s)" % eng.vars["trust"])
	ok(await wait_clip("idle", 4.0), "back to idle after catch")
	await wait(0.4)

	# ---- QTE فشل: نخلي الوقت يعدي
	tap(d)
	await wait(0.1)
	tap(d)
	await wait(0.3)
	var m3: float = eng.vars["mood"]
	ok(cur() == "jump", "double -> jump again")
	g = 0.0
	while cur() != "fall" and g < 6.0:
		await process_frame
		g += 0.016
	ok(cur() == "fall", "jump ends -> then fall (%s)" % cur())
	ok(eng.vars["mood"] == m3 - 5.0, "on_end applied -5 mood (%s)" % eng.vars["mood"])
	ok(await wait_clip("idle", 4.0), "back to idle after fall")

	# ---- الانبعاج (shader) يتفعل وقت اللمس ويطفي بعده
	btn(true, pos(0.5, 0.3))
	await wait(0.4)
	ok(eng._active.material == eng._mat, "warp shader active while pressing")
	ok(float(eng._fx["depth"]) > 0.1, "press depth > 0 (%.2f)" % float(eng._fx["depth"]))
	btn(false, pos(0.5, 0.3))
	await wait(2.0)
	ok(eng._active.material == null, "warp shader released after settle")

	# ---- إغلاق
	eng.close()
	await wait(0.1)
	ok(result.get("reason", "") == "closed", "close() emits finished(closed)")
	ok(result.get("scene_id", "") == "test-mochi", "finished carries scene id")
	print("final vars: ", eng.vars)
