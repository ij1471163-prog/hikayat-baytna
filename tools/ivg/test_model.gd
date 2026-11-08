extends SceneTree
var fails := 0
func ok(c: bool, m: String):
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1
func _initialize():
	await _run()
	print("=== FAILS: %d ===" % fails)
	quit(1 if fails > 0 else 0)
func find_btn(node: Node, part: String):
	for c in node.find_children("*", "Button", true, false):
		if part in c.text: return c
	return null
func _run():
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.story_seen.append("intro")
	main.talk_to("ليان")
	await process_frame
	var found := false
	for b in main.choices.get_children():
		if b is Button and "عرض ٣D" in b.text:
			found = true
			b.pressed.emit()
			break
	ok(found, "talk_to shows 3D button when model exists")
	await create_timer(1.0).timeout
	var v = main._model_box
	ok(is_instance_valid(v), "viewer opened")
	ok(v.loaded_ok, "model loaded")
	ok(v._anim != null and v._anim.is_playing(), "animation 'idle' playing")
	ok(find_btn(v, "idle") != null, "animation button listed")
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "m_1.png")
	var y0: float = v._yaw
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.relative = Vector2(120, 20)
	v._gui_input(e)
	ok(absf(v._yaw - y0) > 0.5, "drag rotates (%.2f)" % v._yaw)
	var d0: float = v._dist
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	v._gui_input(w)
	ok(v._dist < d0, "wheel zooms in")
	# قرصة بإصبعين
	var t1 := InputEventScreenTouch.new(); t1.index = 0; t1.pressed = true; t1.position = Vector2(200, 400); v._gui_input(t1)
	var t2 := InputEventScreenTouch.new(); t2.index = 1; t2.pressed = true; t2.position = Vector2(300, 400); v._gui_input(t2)
	var d1: float = v._dist
	var dr := InputEventScreenDrag.new(); dr.index = 1; dr.position = Vector2(500, 400); v._gui_input(dr)
	ok(v._dist < d1, "pinch out zooms in (%.2f -> %.2f)" % [d1, v._dist])
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "m_2_rot.png")
	find_btn(v, "إعادة").pressed.emit()
	ok(is_equal_approx(v._yaw, 0.0) and is_equal_approx(v._dist, v._base_dist), "reset view")
	find_btn(v, "إغلاق").pressed.emit()
	await create_timer(0.3).timeout
	ok(not is_instance_valid(main._model_box), "closed")
	quit()
