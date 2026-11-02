extends SceneTree
const E = preload("res://ivg/ivg_engine.gd")
var eng
var fails := 0
func ok(c: bool, m: String):
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1
func cur() -> String: return str(eng._cur.get("name", ""))
func pos(u: float, v: float) -> Vector2:
	var r: Rect2 = eng.content_rect()
	return r.position + Vector2(u * r.size.x, v * r.size.y)
func ev(pr: bool, p: Vector2):
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pr
	e.position = p
	eng._on_input(e)
func tap(p: Vector2):
	ev(true, p)
	ev(false, p)
func wait(s: float): await create_timer(s).timeout
func wait_clip(n: String, t := 5.0) -> bool:
	var g := 0.0
	while g < t:
		if cur() == n: return true
		await process_frame
		g += 0.016
	return cur() == n
func shot(n: String):
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + n + ".png")
func _initialize():
	await _run()
	print("=== FAILS: %d ===" % fails)
	quit(1 if fails > 0 else 0)
func _run():
	var h := Control.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(h)
	var path := "res://assets/ivg/layan/demo_images/scene.json"
	var sc = JSON.parse_string(FileAccess.get_file_as_string(path))
	eng = E.new()
	eng.setup(sc, path.get_base_dir() + "/", {"debug": true})
	h.add_child(eng)
	await wait(0.6)
	ok(await wait_clip("idle", 3.0), "starts on idle (image clip)")
	ok(eng._active.is_img, "active slot is an image (no video)")
	ok(eng._bg_tex.texture != null, "scene bg loaded")
	var r: Rect2 = eng.content_rect()
	print("content rect ", r)
	ok(absf(r.size.x / r.size.y - 454.0 / 788.0) < 0.02, "content rect follows sprite aspect")
	ok(bool(eng._cur.get("breathe", false)), "breathing on for image clips")
	await wait(0.4)
	ok(eng._active.node().material == eng._mat, "breathing shader active on idle image")
	await shot("img_1_idle")
	var m0: float = eng.vars["mood"]
	tap(pos(0.31, 0.115))
	await wait(0.3)
	ok(cur() in ["happy", "happy2"], "tap head -> happy clip (%s)" % cur())
	ok(eng.vars["mood"] == m0 + 3.0, "mood +3")
	ok(await wait_clip("idle", 4.0), "image clip with duration ends -> then idle")
	await wait(0.4)
	var t0: float = eng.vars["trust"]
	ev(true, pos(0.31, 0.115))
	await wait(0.9)
	ev(false, pos(0.31, 0.115))
	ok(eng.vars["trust"] == t0 + 1.0, "hold head -> trust +1")
	ok(await wait_clip("idle", 4.0), "back to idle")
	await wait(0.4)
	# سحب لفوق -> talk (image clip with pause)
	var s := pos(0.8, 0.85)
	ev(true, s)
	var m1 := InputEventMouseMotion.new()
	m1.position = s + Vector2(0, -120)
	eng._on_input(m1)
	ev(false, s + Vector2(0, -200))
	await wait(0.2)
	ok(cur() == "talk", "swipe-up -> talk (%s)" % cur())
	var g := 0.0
	while not eng._choice_box.visible and g < 3.0:
		await process_frame
		g += 0.016
	ok(eng._choice_box.visible, "pause at 0.4s on image clip shows choices")
	ok(eng._active.is_paused(), "image clock paused during choice")
	var p1: float = eng._active.pos()
	await wait(0.5)
	ok(absf(eng._active.pos() - p1) < 0.01, "image clock frozen while paused")
	await shot("img_2_choices")
	var first: Button = null
	for c in eng._choice_box.get_children():
		if c is Button:
			first = c
			break
	first.pressed.emit()
	await wait(0.3)
	ok(cur() == "happy", "choice -> happy (%s)" % cur())
	ok(eng.vars["trust"] >= 3.0, "choice trust +2")
	ok(await wait_clip("idle", 4.0), "back to idle")
	await wait(0.4)
	# كومبو الكتفين
	var m2: float = eng.vars["mood"]
	for i in 4:
		tap(pos(0.11, 0.30))
		await wait(0.42)
	await wait(0.2)
	ok(cur() == "annoyed" or eng.vars["mood"] < m2, "4 quick shoulder taps -> combo annoyed (clip=%s mood %s -> %s)" % [cur(), m2, eng.vars["mood"]])
	await shot("img_3_after")
	# تفاعل الانبعاج على الصورة
	ok(await wait_clip("idle", 5.0), "back to idle after annoyed")
	ev(true, pos(0.31, 0.2))
	await wait(0.5)
	ok(float(eng._fx["depth"]) > 0.1, "press warp depth on image")
	await shot("img_4_press")
	ev(false, pos(0.31, 0.2))
	eng.close()
