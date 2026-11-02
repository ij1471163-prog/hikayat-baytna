extends SceneTree
var fails := 0
var main
func ok(c: bool, m: String):
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1
func has_btn(part: String) -> bool:
	for b in main.choices.get_children():
		if b is Button and part in b.text: return true
	return false
func press(part: String):
	for b in main.choices.get_children():
		if b is Button and part in b.text:
			b.pressed.emit()
			return
func _initialize():
	await _run()
	print("=== FAILS: %d ===" % fails)
	quit(1 if fails > 0 else 0)
func _run():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.story_seen.append("intro")
	main.period = 0
	main.day = 2
	print("layan here kitchen p0: ", main.layan_here("المطبخ"))
	main.go("المطبخ")
	await process_frame
	print("DBG2 avail=", main.available_ivg("المطبخ").get("id", "none"), " seen=", main.story_seen, " loc=", main.location)
	for b in main.choices.get_children():
		if b is Button: print("  BTN ", b.text)
	ok(has_btn("🎬"), "kitchen+morning -> scene button appears")
	ok(not has_btn("لقاء تجريبي"), "demo scene (no 'when') is not a bubble")
	main.go("الصالة")
	await process_frame
	ok(not has_btn("🎬"), "other room -> no button")
	main.period = 2
	main.go("المطبخ")
	await process_frame
	print("DBG period=", main.period, " avail=", main.available_ivg("المطبخ").get("id", "none"), " seen=", main.story_seen)
	ok(not has_btn("🎬"), "evening -> no button")
	main.period = 0
	main.go("المطبخ")
	await process_frame
	press("🎬")
	await create_timer(1.5).timeout
	ok(is_instance_valid(main._ivg_box), "scene opens")
	ok(main.story_seen.has("ivg:cond-cook"), "marked as seen")
	main._ivg_box.close()
	await create_timer(0.8).timeout
	ok(not is_instance_valid(main._ivg_box), "scene closed")
	main.go("المطبخ")
	await process_frame
	ok(not has_btn("🎬"), "once only: button gone after viewing")
	# قائمة اللقاء التفاعلي ما تعرض المشهد المشروط
	main.talk_to("ليان")
	await process_frame
	ok(has_btn("لقاء تفاعلي مع ليان (1)"), "menu counts only non-conditional scenes (1)")
	quit()
