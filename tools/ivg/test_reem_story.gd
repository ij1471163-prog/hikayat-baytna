extends SceneTree
var main
var fails := 0
func ok(c: bool, m: String):
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1
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
	main.day = 2
	main.period = 2
	var sc = main.available_group_scene("الصالة")
	ok(not sc.is_empty() and sc["id"] == "g_reem_first", "first Reem scene available in living room evening (%s)" % sc.get("id", "-"))
	main.play_group_scene(sc, 0)
	for i in 6:
		await process_frame
		for b in main.choices.get_children():
			if b is Button and ("التالي" in b.text):
				b.pressed.emit()
				break
	await process_frame
	var picked := false
	for b in main.choices.get_children():
		if b is Button and "رحب فيها" in b.text:
			b.pressed.emit()
			picked = true
			break
	await process_frame
	ok(picked, "choices shown at the end")
	ok(main.character_relations["ريم"] >= 58, "Reem relation up (%s)" % main.character_relations["ريم"])
	ok(main.story_seen.has("g_reem_first"), "marked seen")
	main.day = 6
	main.character_relations["ريم"] = 60
	main.daily_flags["gs_day"] = 0
	var s2 = main.available_group_scene("الصالة")
	ok(s2.get("id", "") == "g_reem_advice", "second scene follows (%s)" % s2.get("id", "-"))
	quit()
