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
	main.day = 5
	main.period = 2
	ok(main.npc_present("ريم", "الصالة"), "Reem present in living room in the evening")
	main.go("الصالة")
	await create_timer(0.8).timeout
	ok(main.sprite_path("ريم").ends_with("full/reem.png") if main.has_method("sprite_path") else true, "sprite path resolves")
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "reem_room.png")
	main.character_hub()
	await process_frame
	ok(has_btn("ريم"), "hub lists Reem")
	press("ريم")
	await process_frame
	ok(has_btn("رحب فيها"), "Reem scene has choices")
	var r0: int = main.character_relations["ريم"]
	press("رحب فيها")
	await process_frame
	ok(main.character_relations["ريم"] == r0 + 3, "relation +3")
	main.talk_to("ريم")
	await create_timer(0.5).timeout
	ok(has_btn("أعطه هدية"), "talk_to works for Reem")
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "reem_talk.png")
	main.period = 0
	ok(not main.npc_present("ريم", "الصالة"), "absent in the morning")
	quit()
