extends SceneTree
const WorldData = preload("res://world_data.gd")
var main
func _initialize():
	await _run()
	quit()
func press_all(limit := 8):
	var n := 0
	for b in main.choices.get_children():
		if b is Button and n < limit:
			n += 1
			if "حفظ" in b.text or "حذف" in b.text or "إنهاء" in b.text: continue
			b.pressed.emit()
			await process_frame
func _run():
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.story_seen.append("intro")
	var places: Array = []
	for p in WorldData.HOUSE_PLACES: places.append(p)
	for p in ["الحديقة", "المقهى", "السوبرماركت", "الشاطئ", "العمل"]: places.append(p)
	var cnt := 0
	for day in [3, 8, 14]:
		main.day = day
		for per in 4:
			main.period = per
			for pl in places:
				main.go(pl)
				await process_frame
				cnt += 1
				for npc in WorldData.NPCS:
					if npc == "ليان" or main.npc_present(npc, pl):
						main.talk_to(npc)
						await process_frame
						await press_all(4)
						main.go(pl)
						await process_frame
	print("SMOKE visited ", cnt, " place/time combos")
