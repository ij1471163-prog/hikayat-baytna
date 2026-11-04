extends SceneTree
var fails := 0
var main
func ok(c: bool, m: String):
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1
func find_btn(node: Node, part: String):
	for c in node.find_children("*", "Button", true, false):
		if part in c.text: return c
	return null
func vpl():
	return main._video_box.find_children("*", "VideoStreamPlayer", true, false)[0]
func _initialize():
	await _run()
	print("=== FAILS: %d ===" % fails)
	quit(1 if fails > 0 else 0)
func _run():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var p := "res://assets/ivg/layan/user_cook/cook.ogv"
	var done := [false]
	main.play_video(p, func(): done[0] = true, [p, p], 0)
	await create_timer(2.5).timeout
	var v = vpl()
	ok(v.is_playing() and v.stream_position > 1.0, "plays (%.2f)" % v.stream_position)
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "pl_1.png")
	find_btn(main._video_box, "إيقاف").pressed.emit()
	await create_timer(0.3).timeout
	var p0: float = v.stream_position
	await create_timer(1.0).timeout
	ok(v.paused and absf(v.stream_position - p0) < 0.05, "pause freezes")
	ok(find_btn(main._video_box, "كمل") != null, "button becomes 'كمل'")
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "pl_2_paused.png")
	find_btn(main._video_box, "كمل").pressed.emit()
	await create_timer(1.0).timeout
	ok(not v.paused and v.stream_position > p0 + 0.5, "resume continues")
	find_btn(main._video_box, "من البداية").pressed.emit()
	await create_timer(0.5).timeout
	ok(v.stream_position < 1.2 and v.is_playing(), "restart from beginning (%.2f)" % v.stream_position)
	var old = main._video_box
	find_btn(main._video_box, "التالي").pressed.emit()
	await create_timer(0.5).timeout
	ok(main._video_box != old and is_instance_valid(main._video_box), "next opens second video")
	ok(find_btn(main._video_box, "إنهاء") != null, "last video shows 'إنهاء'")
	await create_timer(3.5).timeout
	var bar = find_btn(main._video_box, "إنهاء").get_parent().get_parent()
	ok(not bar.visible, "controls auto-hide while playing")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(300, 200)
	main._video_box.gui_input.emit(e)
	ok(bar.visible, "tap shows controls")
	find_btn(main._video_box, "إنهاء").pressed.emit()
	await process_frame
	ok(done[0], "finish calls 'after'")
	quit()
