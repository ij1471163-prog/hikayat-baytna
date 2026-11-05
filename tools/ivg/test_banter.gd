extends SceneTree
const WorldData = preload("res://world_data.gd")
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
	# مكان فيه شخصيتين: ليان + ريم بالصالة مساءً
	main.day = 5
	main.period = 2
	main.go("الصالة")
	await create_timer(0.5).timeout
	print("TXT: ", main.dialogue.text.replace("\n", " | "))
	ok("«" in main.dialogue.text, "banter appended in living room (Layan+Reem)")
	var first: String = main.dialogue.text
	main.room_intro()
	ok(main.dialogue.text.ends_with(main.daily_flags["bn_txt"]), "banter persists on refresh")
	# المقهى: سارة + ميسون (وقت 1/2)
	main.day = 6
	for per in [1, 2]:
		main.period = per
		var cafe: Array = []
		for n in ["سارة", "ميسون"]:
			if main.npc_present(n, "المقهى"): cafe.append(n)
		print("cafe p", per, " present ", cafe)
	# كل الأزواج: لا يرجع فاضي
	var BD = load("res://banter_data.gd")
	for a in BD.ORDER:
		for b in BD.ORDER:
			if a < b:
				var r = BD.pick([a, b])
				ok(r.size() >= 2, "pair %s+%s has banter" % [a, b])
	# المشاهد الجديدة
	main.story_seen.append("g_reem_first")
	for t in [["المقهى", 2, "g_cafe_girls", 6], ["الحديقة", 0, "g_garden_walk", 6], ["المطبخ", 1, "g_reem_nora_kitchen", 6]]:
		main.day = t[3]
		main.period = t[1]
		main.daily_flags["gs_day"] = 0
		main.character_relations["ريم"] = 60
		var sc = main.group_scene_ok(load("res://scenes_data.gd").SCENES.filter(func(x): return x["id"] == t[2])[0], t[0])
		print(t[2], " ok-here=", sc, " (person scheduling decides)")
	quit()
