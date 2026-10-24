extends Node2D
## Garsonluk vardiyası (Kafe Yıldız, 3/4 üstten bakış): boş masalara müşteri gelir ve sipariş verir, mutfak
## birkaç saniyede yemeği tezgaha çıkarır. Tezgahtan al (E), doğru masaya götür (E). Hızlı servis = büyük bahşiş.
## Vardiya bitince maaş + bahşiş alınır, oyun içinde 4 saat geçer. Mekan: tools/make_rooms.py "restoran".

const StatusBar = preload("res://scenes/ui/status_bar.gd")
const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Person = preload("res://scenes/metro/person.gd")
const MetroEvents = preload("res://data/metro_events.gd")

const SPEED := 95.0
const SHIFT_SECONDS := 70.0
const PATIENCE := 26.0
const COOK_TIME := [3.0, 5.5]
const EAT_TIME := 6.0
const MAX_ON_PASS := 3
const DISHES := [
	{"name": "Çay", "color": Color("c84438"), "rim": Color("f4f2ec")},
	{"name": "Tost", "color": Color("e6b428"), "rim": Color("8d5e3c")},
	{"name": "Menemen", "color": Color("e8745a"), "rim": Color("40455a")},
	{"name": "Kahve", "color": Color("6b4530"), "rim": Color("f4f2ec")},
]

var _action: Dictionary
var _room: Room
var _player
var _tables: Array = []                             # müşterinin oturduğu yer
var _serve: Array = []                              # garsonun durduğu yer
var _pass_slots: Array = []
var _customers: Array = []                          # {"node", "state": waiting/eating, "dish", "patience", "t"}
var _cooks: Array = []
var _cooking: Array = []                            # {"table", "dish", "t"}
var _on_pass: Array = []                            # {"table", "dish"}
var _carry := {}
var _time_left := SHIFT_SECONDS
var _spawn_t := 1.0
var _tips := 0
var _served := 0
var _missed := 0
var _done := false
var _ui: CanvasLayer
var _hint: HintBar
var _info: Label
var _top: Node2D


func _ready() -> void:
	_action = GameState.activity
	_room = Room.new().build("restoran")
	add_child(_room)
	_tables = _room.points("tables")
	_serve = _room.points("serve")
	_pass_slots = _room.points("pass")
	_customers.resize(_tables.size())
	_customers.fill(null)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	_room.top_layer.add_child(_top)
	for k in 2:
		var c = _person("sivil%d" % (2 + k * 9), _room.mark("cook%d" % k))
		c.face_dir("up")
		c.target = c.position
		_cooks.append(c)
	_player = _person("player", _room.mark("spawn"))
	_player.marker = true
	_player.face_dir("up")
	_room.follow(_player)
	Lighting.apply(self, false, _room.lamps(), 90.0, true)

	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(StatusBar.new())
	var title := GameState.make_label("Kafe Yıldız: garsonluk", 11, Color("e6b428"))
	title.position = Vector2(4, 25)
	UIDraw.pill(title)
	_ui.add_child(title)
	_info = GameState.make_label("", 9, Color.WHITE)
	_info.position = Vector2(150, 25)
	_info.size = Vector2(230, 13)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIDraw.pill(_info, Color("4ade80"))
	_ui.add_child(_info)
	_hint = HintBar.new()   # alt bilgi şeridi
	_hint.default_text = "WASD: yürü · E: al / servis et"
	_ui.add_child(_hint)
	Bubble.say(self, _player, "Vardiya başladı! Tezgahtan al, masaya götür.", 34.0, 3.0)


func _person(look: String, at: Vector2):
	var p := Person.new()
	p.look = look
	p.position = at
	_room.add_actor(p)
	return p


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()
		return
	if OS.get_cmdline_user_args().has("--autoplay"):
		_autopilot(delta)
	else:
		var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		_room.walk(_player, dir, SPEED, delta)
		if Input.is_action_just_pressed("interact"):
			_interact()
	_update_customers(delta)
	_update_kitchen(delta)
	_info.text = "Vardiya: %d sn   ·   Bahşiş: %d TL   ·   Servis: %d" % [ceili(_time_left), _tips, _served]
	_hint.text = _hint_text()
	_top.queue_redraw()


func _table_near() -> int:
	for i in _tables.size():
		if _player.position.distance_to(_serve[i]) < 20.0 or _player.position.distance_to(_tables[i] + Vector2(0, 14)) < 22.0:
			return i
	return -1


func _at_pass() -> bool:
	return _player.position.distance_to(_room.mark("pickup")) < 34.0


func _hint_text() -> String:
	if _carry.is_empty():
		if _at_pass() and not _on_pass.is_empty():
			return "E: %s al (masa %d)" % [DISHES[_on_pass[0]["dish"]]["name"], _on_pass[0]["table"] + 1]
		return "Yemek çıkınca mutfak tezgahından al (sol üst)" if _on_pass.is_empty() else "Tezgahta yemek var! (sol üst)"
	var t := _table_near()
	if t >= 0:
		return "E: Masa %d'ye servis et" % (t + 1)
	return "%s elinde: masa %d'ye götür" % [DISHES[_carry["dish"]]["name"], _carry["table"] + 1]


func _interact() -> void:
	if _carry.is_empty():
		if _at_pass() and not _on_pass.is_empty():
			_carry = _on_pass.pop_front()
			_player.face_dir("up")
		return
	var t := _table_near()
	if t < 0:
		return
	_player.face_point(_tables[t])
	var c = _customers[t]
	if t != _carry["table"] or c == null or c["state"] != "waiting":
		if c != null:
			Bubble.say(self, c["node"], "Ben bunu istemedim!", 34.0, 1.6)
		return
	var tip := 2 + int(10.0 * c["patience"] / PATIENCE)   # hızlı servis: en fazla 12 TL
	_tips += tip
	_served += 1
	c["state"] = "eating"
	c["t"] = EAT_TIME
	_carry = {}
	Bubble.say(self, c["node"], ["Eline sağlık!", "Çok hızlısın!", "Teşekkürler!"].pick_random() + "  +%d TL" % tip, 34.0, 1.8)


## Boş masalara müşteri gelir; bekleyenin sabrı azalır, yiyen bir süre sonra kalkar.
func _update_customers(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(2.5, 5.5)
		var empty := range(_tables.size()).filter(func(i): return _customers[i] == null)
		if not empty.is_empty():
			var i: int = empty.pick_random()
			var p = _person(MetroEvents.random_look(), _tables[i])
			p.sit("down")
			p.modulate.a = 0.0
			create_tween().tween_property(p, "modulate:a", 1.0, 0.4)
			var dish := randi() % DISHES.size()
			_customers[i] = {"node": p, "state": "waiting", "dish": dish, "patience": PATIENCE, "t": 0.0}
			_cooking.append({"table": i, "dish": dish, "t": randf_range(COOK_TIME[0], COOK_TIME[1])})
	for i in _tables.size():
		var c = _customers[i]
		if c == null:
			continue
		if c["state"] == "waiting":
			c["patience"] -= delta
			if c["patience"] <= 0.0:
				_missed += 1
				Bubble.say(self, c["node"], "Bu ne biçim servis!", 34.0, 1.6)
				_leave(i)
		else:
			c["t"] -= delta
			if c["t"] <= 0.0:
				_leave(i)


func _leave(i: int) -> void:
	var node = _customers[i]["node"]
	_customers[i] = null
	_on_pass = _on_pass.filter(func(d): return d["table"] != i)
	_cooking = _cooking.filter(func(d): return d["table"] != i)
	if not _carry.is_empty() and _carry["table"] == i:
		_carry = {}
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(node, "modulate:a", 0.0, 0.4)
	tw.tween_callback(node.queue_free)


## Mutfak: aşçılar ocakla tezgah arasında koşturur, yemekler pişince tezgaha çıkar.
func _update_kitchen(delta: float) -> void:
	for d in _cooking.duplicate():
		d["t"] -= delta
		if d["t"] <= 0.0 and _on_pass.size() < MAX_ON_PASS:
			_cooking.erase(d)
			_on_pass.append({"table": d["table"], "dish": d["dish"]})
	for c in _cooks:
		if c.step_to(c.target, 30.0, delta):
			c.face_dir("up" if randf() < 0.7 else "down")
			if randf() < 0.01:
				c.target = Vector2(randf_range(24, 160), _room.mark("cook0").y)


## Test için: tezgahtaki ilk yemeği alıp masasına götürür.
func _autopilot(delta: float) -> void:
	var goal := Vector2(-1, -1)
	if _carry.is_empty():
		if not _on_pass.is_empty():
			goal = _room.mark("pickup")
	else:
		goal = _serve[_carry["table"]]
	if goal.x < 0.0:
		_player.set_moving(false)
		return
	if _player.position.distance_to(goal) < 4.0 or _room.walk_to(_player, goal, SPEED, delta):
		_interact()


func _finish() -> void:
	_done = true
	var pay: int = _action.get("money", 70)
	var a := _action.duplicate()
	a["money"] = pay + _tips
	GameState.do_action(a)
	var popup := ChoicePopup.new()
	popup.portrait = GameState.fighter_texture("sivil9", "idle")
	popup.title = "Vardiya bitti!"
	popup.add_line("Melek Hanım: \"%s\"" % ("Harikaydın, yarın yine gel!" if _missed == 0 and _served >= 6 else
			"Fena değil, ama müşteri bekletme!" if _missed < 3 else "Bu böyle olmaz, daha hızlı olmalısın!"))
	popup.add_line("Servis: %d   ·   Kızıp giden: %d" % [_served, _missed], 9, Color(1, 1, 1, 0.7))
	popup.add_line("Maaş %d TL + bahşiş %d TL = %d TL" % [pay, _tips, pay + _tips], 11, Color("4ade80"))
	popup.add_choice("Çarşıya dön", "ok")
	_ui.add_child(popup)
	popup.chosen.connect(func(_c): GameState.open_place_scene("carsi"))


## Tabaklar: tezgahta, elde ve müşterilerin üstünde sipariş + sabır çubuğu; masa numaraları.
func _draw_top() -> void:
	var font := ThemeDB.fallback_font
	for k in _on_pass.size():
		_plate(_pass_slots[k] + Vector2(-8, 0), _on_pass[k]["dish"], _on_pass[k]["table"])
	if not _carry.is_empty():
		_plate(_player.position + Vector2(-8, -20), _carry["dish"], _carry["table"])
	for i in _tables.size():
		_top.draw_string(font, _serve[i] + Vector2(-6, -12), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 12, 7, Color("f6d86a"))
		var c = _customers[i]
		if c == null:
			continue
		if c["state"] == "eating":
			_plate(_tables[i] + Vector2(-8, 2), c["dish"], -1)
			continue
		var head: Vector2 = _tables[i] + Vector2(0, c["node"].head_y() - 16)
		_top.draw_rect(Rect2(head.x - 14, head.y - 4, 28, 18), Color("1b1024"))
		_top.draw_rect(Rect2(head.x - 13, head.y - 3, 26, 16), Color("f4f2ec"))
		_plate(head + Vector2(-11, -1), c["dish"], -1)
		var k: float = c["patience"] / PATIENCE
		_top.draw_rect(Rect2(head.x - 11, head.y + 9, 22, 2), Color("2c2f3b"))
		_top.draw_rect(Rect2(head.x - 11, head.y + 9, 22 * k, 2), Color("62984f") if k > 0.5 else (Color("e6b428") if k > 0.25 else Color("c84438")))
		_top.draw_string(font, Vector2(head.x + 5, head.y + 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("1b1024"))


func _plate(p: Vector2, dish: int, table: int) -> void:
	var d: Dictionary = DISHES[dish]
	_top.draw_rect(Rect2(p.x - 1, p.y + 3, 16, 3), Color("1b1024"))
	_top.draw_rect(Rect2(p.x, p.y + 3, 14, 2), d["rim"])
	_top.draw_rect(Rect2(p.x + 3, p.y, 8, 4), d["color"])
	_top.draw_rect(Rect2(p.x + 3, p.y, 8, 1), d["color"].lightened(0.3))
	if table >= 0:
		_top.draw_string(ThemeDB.fallback_font, Vector2(p.x + 1, p.y - 2), "M%d" % (table + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("f6d86a"))
