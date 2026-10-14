extends Node2D

# Prototype: 2D side-view free movement with touch controls and room-to-room transitions.
var player := Vector2(350, 590)
var move_dir := 0.0
var speed := 250.0
var room := "الصالة"
var interact_text := "اقترب من غرض ثم اضغط تفاعل"
var hotspots := []
var status_label: Label
var message_label: Label

func _ready() -> void:
	_build_ui()
	_set_room("الصالة")
	queue_redraw()

func _process(delta: float) -> void:
	player.x = clampf(player.x + move_dir * speed * delta, 40.0, 680.0)
	_update_nearby()
	queue_redraw()

func _draw() -> void:
	# Warm, side-view room illustration built from shapes so the scene runs without external art.
	draw_rect(Rect2(0, 0, 720, 470), Color("#e8d3bb"))
	draw_rect(Rect2(0, 470, 720, 250), Color("#795b49"))
	for x in range(0, 720, 60):
		draw_line(Vector2(x, 470), Vector2(x + 18, 720), Color("#5e4539"), 2.0)
	# window
	draw_rect(Rect2(42, 95, 150, 150), Color("#9bced8"), true)
	draw_rect(Rect2(42, 95, 150, 150), Color("#fff2df"), false, 7.0)
	draw_line(Vector2(117, 98), Vector2(117, 242), Color("#fff2df"), 5.0)
	draw_line(Vector2(45, 170), Vector2(190, 170), Color("#fff2df"), 5.0)
	# wall art
	draw_rect(Rect2(285, 105, 90, 105), Color("#f4e8d8"))
	draw_rect(Rect2(296, 116, 68, 83), Color("#a9b98a"))
	# sofa
	draw_rect(Rect2(215, 375, 280, 92), Color("#a9796c"))
	draw_rect(Rect2(195, 342, 60, 90), Color("#c49484"))
	draw_rect(Rect2(455, 342, 60, 90), Color("#c49484"))
	draw_rect(Rect2(260, 390, 68, 35), Color("#e8c6b4"))
	draw_rect(Rect2(365, 390, 68, 35), Color("#e8c6b4"))
	# interaction props vary by room
	match room:
		"المطبخ":
			draw_rect(Rect2(80, 380, 180, 85), Color("#b9a18a"))
			draw_rect(Rect2(90, 355, 160, 28), Color("#e9e0d5"))
			draw_rect(Rect2(500, 365, 100, 100), Color("#d4d0c6"))
			draw_rect(Rect2(515, 390, 70, 22), Color("#89979a"))
		"غرفة النوم":
			draw_rect(Rect2(170, 360, 360, 105), Color("#b7a4c8"))
			draw_rect(Rect2(190, 335, 105, 45), Color("#f2e9f7"))
			draw_rect(Rect2(310, 375, 195, 80), Color("#d8c3e3"))
		"الحمام":
			draw_rect(Rect2(470, 330, 155, 140), Color("#d7e6e8"))
			draw_rect(Rect2(490, 350, 115, 85), Color("#f5f7f5"))
			draw_rect(Rect2(80, 350, 110, 120), Color("#a7c5ca"))
		"غرفة الغسيل":
			draw_rect(Rect2(110, 355, 130, 115), Color("#e6e6df"))
			draw_circle(Vector2(175, 412), 35, Color("#8eabb5"))
			draw_rect(Rect2(340, 360, 145, 110), Color("#c4b49f"))
		"غرفة الاسترخاء":
			draw_rect(Rect2(160, 360, 400, 100), Color("#9d817c"))
			draw_circle(Vector2(560, 315), 22, Color("#f2cf91"))
	# door on right, room label
	draw_rect(Rect2(640, 270, 60, 200), Color("#8b6045"))
	draw_circle(Vector2(688, 370), 4, Color("#f0d58b"))
	# player avatar: simple modest, non-detailed placeholder silhouette
	draw_circle(Vector2(player.x, player.y - 78), 22, Color("#e8b99a"))
	draw_arc(Vector2(player.x, player.y - 82), 23, PI, TAU, 24, Color("#5a3b2c"), 8.0)
	draw_rect(Rect2(player.x - 20, player.y - 57, 40, 58), Color("#d98e9e"))
	draw_rect(Rect2(player.x - 18, player.y, 14, 38), Color("#343b4b"))
	draw_rect(Rect2(player.x + 4, player.y, 14, 38), Color("#343b4b"))
	draw_line(Vector2(player.x - 18, player.y - 42), Vector2(player.x - 35, player.y - 12), Color("#e8b99a"), 9.0)
	draw_line(Vector2(player.x + 18, player.y - 42), Vector2(player.x + 35, player.y - 12), Color("#e8b99a"), 9.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "حكاية بيتنا — استكشاف حر"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#38251e"))
	layer.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(12, 42)
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#38251e"))
	layer.add_child(status_label)
	message_label = Label.new()
	message_label.position = Vector2(12, 82)
	message_label.size = Vector2(500, 45)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color("#38251e"))
	layer.add_child(message_label)
	var left := _button(layer, "◀", Vector2(22, 620), Vector2(90, 70))
	left.button_down.connect(func(): move_dir = -1.0)
	left.button_up.connect(func(): move_dir = 0.0)
	var right := _button(layer, "▶", Vector2(122, 620), Vector2(90, 70))
	right.button_down.connect(func(): move_dir = 1.0)
	right.button_up.connect(func(): move_dir = 0.0)
	var interact := _button(layer, "تفاعل", Vector2(520, 610), Vector2(175, 70))
	interact.pressed.connect(_interact)
	var back := _button(layer, "رجوع للقائمة", Vector2(500, 8), Vector2(195, 42))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	var door := _button(layer, "الباب التالي ↪", Vector2(500, 55), Vector2(195, 42))
	door.pressed.connect(_next_room)

func _button(parent: Node, text_value: String, pos: Vector2, size_value: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = size_value
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b

func _set_room(new_room: String) -> void:
	room = new_room
	player = Vector2(350, 590)
	hotspots = _hotspots_for_room()
	status_label.text = "المكان: %s  |  تحرّك بالأسهم واضغط تفاعل قرب الأغراض" % room
	_update_nearby()
	queue_redraw()

func _hotspots_for_room() -> Array:
	match room:
		"الصالة": return [{"x":350.0,"name":"الأريكة","text":"جلست على الأريكة قليلًا واستعدت بعض الطاقة."},{"x":560.0,"name":"التلفزيون","text":"شغّلت التلفزيون؛ يمكن تطوير هذا النشاط لاحقًا إلى مشهد وحوار."}]
		"المطبخ": return [{"x":160.0,"name":"سطح المطبخ","text":"حضّرت وجبة بسيطة. تحسّن المزاج قليلًا."},{"x":550.0,"name":"الثلاجة","text":"فتحت الثلاجة وتفقدت احتياجات البيت."}]
		"غرفة النوم": return [{"x":330.0,"name":"السرير","text":"استرحت على السرير. حان وقت حفظ التقدم."},{"x":560.0,"name":"الخزانة","text":"الخزانة جاهزة لاختيار الملابس من قائمة الملابس."}]
		"الحمام": return [{"x":550.0,"name":"الدش","text":"بدأت روتين عناية شخصية بخصوصية. المشهد تمثيلي وغير صريح."},{"x":140.0,"name":"المغسلة","text":"استخدمت المغسلة وأكملت روتين العناية."}]
		"غرفة الغسيل": return [{"x":175.0,"name":"الغسالة","text":"بدأت دورة غسيل تجريبية."},{"x":400.0,"name":"سلة الملابس","text":"جمعت الملابس المتراكمة استعدادًا للغسيل."}]
		"غرفة الاسترخاء": return [{"x":330.0,"name":"سرير المساج","text":"جهّزت جلسة استرخاء بملابس مناسبة، ويمكن اختيار نوع الجلسة من قائمة الأنشطة."},{"x":560.0,"name":"الشموع","text":"أضفت إضاءة هادئة إلى غرفة الاسترخاء."}]
		_: return [{"x":350.0,"name":"الأريكة","text":"استرحت قليلًا في الغرفة."}]

func _update_nearby() -> void:
	var closest: Dictionary = {}
	var dist := 99999.0
	for item in hotspots:
		var d: float = absf(player.x - float(item.x))
		if d < dist:
			dist = d
			closest = item
	if not closest.is_empty() and dist < 95.0:
		interact_text = "قريب من: " + str(closest.name) + " — اضغط تفاعل"
	else:
		interact_text = "اقترب من الأغراض ثم اضغط تفاعل"
	message_label.text = interact_text

func _interact() -> void:
	var closest: Dictionary = {}
	var dist := 99999.0
	for item in hotspots:
		var d: float = absf(player.x - float(item.x))
		if d < dist:
			dist = d
			closest = item
	if closest.is_empty() or dist >= 95.0:
		message_label.text = "اقترب أكثر من الأريكة أو الغرض الظاهر في الغرفة أولًا."
		return
	message_label.text = str(closest.text)
	if str(closest.name) == "السرير":
		player.x = 350.0

func _next_room() -> void:
	var order := ["الصالة", "المطبخ", "غرفة النوم", "الحمام", "غرفة الغسيل", "غرفة الاسترخاء"]
	var idx: int = order.find(room)
	_set_room(str(order[(idx + 1) % order.size()]))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			move_dir = -1.0
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			move_dir = 1.0
	elif event.keycode == KEY_E or event.keycode == KEY_SPACE:
			_interact()
	elif event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://main.tscn")
	elif event is InputEventKey and not event.pressed and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT or event.keycode == KEY_A or event.keycode == KEY_D):
		move_dir = 0.0
