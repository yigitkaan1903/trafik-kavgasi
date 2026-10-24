extends Node2D
## Metrobüse bindin, koltuklar dolmaya başladı: boş bir koltuğa herkesten önce otur!
## Senden önce binenler yerlerin bir kısmını çoktan kapmış olur. Teyzeler çantayı fırlatıp yer ayırır.
## Mekan: tools/make_rooms.py "metrobus" (3/4 üstten bakış).

const Person = preload("res://scenes/metro/person.gd")
const MetroEvents = preload("res://data/metro_events.gd")

var _room: Room
var _seat_pos: Array = []
var _door: Vector2
var _player
var _occupied: Array = []     # her koltukta oturan (ya da null)
var _reserved: Array = []     # koltuğa koşan
var _bag: Array = []          # teyze çantası
var _rushers: Array = []
var _to_spawn := 0
var _spawn_t := 0.0
var _done := false
var _ui: CanvasLayer
var _info: Label
var _bags: Node2D
var _outside: Node2D


func _ready() -> void:
	_outside = Node2D.new()
	_outside.draw.connect(_draw_outside)
	add_child(_outside)
	_room = Room.new().build("metrobus")
	add_child(_room)
	_seat_pos = _room.points("seats")
	_door = _room.mark("door_in")
	for i in _seat_pos.size():
		_occupied.append(null)
		_reserved.append(null)
		_bag.append(false)
	_bags = Node2D.new()
	_bags.draw.connect(_draw_bags)
	_room.top_layer.add_child(_bags)
	Lighting.apply(self, false, _room.lamps(), 80.0, true)
	var dolu := GameState.board_bus_type == "dolu"
	# önceki duraklarda binenler koltukların çoğunu kapmış: boş metrobüste bile birkaç yer kalır
	var free := 0 if dolu else clampi(9 - int(GameState.board_ahead / 3), 3, 9)
	var order := range(_seat_pos.size())
	order.shuffle()
	for k in _seat_pos.size() - free:
		var p = _person(_seat_pos[order[k]])
		p.sit("right")
		_occupied[order[k]] = p

	_player = Person.new()
	_player.look = "player"
	_player.marker = true
	_player.position = _door
	_player.face_dir("up")
	_room.add_actor(_player)
	_room.follow(_player, 1.0, 112.0)

	_ui = CanvasLayer.new()
	add_child(_ui)
	var title := GameState.make_label("YARI DOLU: KOLTUK YOK" if dolu else "KOLTUK KAP!", 20, Color("e6b428"))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 4)
	title.size = Vector2(480, 26)
	_ui.add_child(title)
	_info = GameState.make_label("", 9)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.position = Vector2(110, 31)
	_info.size = Vector2(260, 13)
	UIDraw.pill(_info)
	_ui.add_child(_info)

	if dolu:
		for k in 4:
			var p = _person(_room.points("stand").pick_random())
			p.face_dir(["left", "right", "up"].pick_random())
		_info.text = "Sıkış tıkış ayakta gideceksin..."
		_finish(false, 2.2)
		return
	# senden hemen önce binenler zaten koltuklara koşuyor, arkandan da gelenler var
	for i in mini(2, GameState.board_ahead):
		_add_rusher(_door + Vector2(randf_range(-40, 40), -10))
	_to_spawn = randi_range(3, 6)
	_spawn_t = 0.5


func _physics_process(delta: float) -> void:
	_outside.queue_redraw()
	if _done:
		return
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	var spd: float = 70.0 + 0.4 * GameState.stats["agi"]
	_room.walk(_player, dir, spd, delta)
	if Input.is_action_just_pressed("interact"):
		_try_sit()

	_spawn_t -= delta
	if _spawn_t <= 0.0 and _to_spawn > 0:
		_spawn_t = randf_range(0.5, 0.9)
		_to_spawn -= 1
		_add_rusher(_door + Vector2(randf_range(-6, 6), 0))
	for r in _rushers.duplicate():
		_update_rusher(r, delta)

	var free := _free_seats().size()
	_info.text = "WASD: yürü    E: boş koltuğa otur    Boş koltuk: %d" % free
	if free == 0:
		_say(_player, "Hepsi doldu ya...")
		_info.text = "Bütün koltuklar doldu. Ayakta gideceksin..."
		_finish(false, 1.8)
	_bags.queue_redraw()


func _person(at: Vector2):
	var p := Person.new()
	p.look = MetroEvents.random_look()
	p.position = at
	_room.add_actor(p)
	return p


func _add_rusher(at: Vector2) -> void:
	var p = _person(at)
	p.speed = 85.0 if p.look == "teyze" else randf_range(50.0, 72.0)
	_rushers.append(p)
	_retarget(p)


func _free_seats() -> Array:
	var out: Array = []
	for i in _seat_pos.size():
		if _occupied[i] == null and not _bag[i]:
			out.append(i)
	return out


## En yakın boş ve kimsenin koşmadığı koltuğu seçer. Yoksa ayakta kalır.
func _retarget(p) -> void:
	var best := -1
	for i in _free_seats():
		if _reserved[i] == null and (best < 0 or _seat_pos[i].distance_to(p.position) < _seat_pos[best].distance_to(p.position)):
			best = i
	p.set_meta("seat", best)
	if best >= 0:
		_reserved[best] = p


func _update_rusher(p, delta: float) -> void:
	var seat: int = p.get_meta("seat", -1)
	if seat < 0 or _occupied[seat] != null:
		if seat >= 0 and _reserved[seat] == p:
			_reserved[seat] = null
		_retarget(p)
		seat = p.get_meta("seat", -1)
		if seat < 0:
			_rushers.erase(p)   # yer kalmadı, ayakta bekler
			p.set_moving(false)
			return
	var target: Vector2 = _seat_pos[seat]
	# teyze yaklaşınca çantasını fırlatıp yeri ayırır
	if p.look == "teyze" and not _bag[seat] and target.distance_to(p.position) < 90.0 and not p.has_meta("threw"):
		p.set_meta("threw", true)
		_bag[seat] = true
		_say(p, "Çantamı koydum, burası dolu!")
	# koridordan koltuğun hizasına gelip sonra oturur
	var aisle := Vector2(target.x, 134.0)
	if absf(p.position.x - target.x) > 2.0 and absf(p.position.y - target.y) > 2.0:
		p.step_to(aisle, p.speed, delta)
		return
	if p.step_to(target, p.speed, delta):
		_bag[seat] = false
		_occupied[seat] = p
		_reserved[seat] = null
		p.sit("right")
		_rushers.erase(p)


func _try_sit() -> void:
	var order := range(_seat_pos.size())
	order.sort_custom(func(a, b): return _seat_pos[a].distance_to(_player.position) < _seat_pos[b].distance_to(_player.position))
	for i in order:
		var d: Vector2 = _seat_pos[i] - _player.position
		if absf(d.x) > 13.0 or absf(d.y) > 40.0:
			continue
		if _bag[i]:
			_say(_player, "Teyzenin çantası var...")
			return
		if _occupied[i] != null:
			continue
		var other = _reserved[i]
		if other != null:
			_reserved[i] = null
			_say(other, "Ben oturacaktım!")
		_occupied[i] = _player
		_player.position = _seat_pos[i]
		_player.sit("right")
		_say(_player, "Oh be! Oturdum.")
		_info.text = "Oturdun! Artık yolculuğun tadını çıkar."
		_finish(true, 1.6)
		return


func _finish(seated: bool, wait: float) -> void:
	_done = true
	GameState.metro_seated = seated
	GameState.metro_on_board = true
	GameState.save_game()
	await get_tree().create_timer(wait).timeout
	GameState.go_to(GameState.SCENE_METRO)


func _say(who: Node2D, text: String) -> void:
	Bubble.say(self, who, text, 34.0, 2.0)


## Kapıların açıldığı taraf: durak peronu.
func _draw_outside() -> void:
	_outside.draw_rect(Rect2(-40, -60, 900, 340), Color("3a3c44"))
	_outside.draw_rect(Rect2(-40, 0, 900, 10), Color("a8afbf"))
	_outside.draw_rect(Rect2(0, 46, 800, 32), Color("1b2440") if Lighting.is_dark() else Color("cfe7f5"))
	for x in range(10, 800, 70):   # karşı peronun direkleri
		_outside.draw_rect(Rect2(x, 52, 6, 26), Color("80889c"))
	_outside.draw_rect(Rect2(0, 70, 800, 8), Color("9a9aa6"))
	_outside.draw_rect(Rect2(0, 70, 800, 2), Color("e6b428"))
	_outside.draw_rect(Rect2(-40, 186, 900, 80), Color("a8a49c"))
	_outside.draw_rect(Rect2(-40, 186, 900, 5), Color("e6b428"))


## Çanta: teyzenin ayırdığı koltuklar.
func _draw_bags() -> void:
	for i in _seat_pos.size():
		if _bag[i]:
			var p: Vector2 = _seat_pos[i] + Vector2(-4, -14)
			_bags.draw_rect(Rect2(p.x - 1, p.y - 1, 12, 10), Color("1b1024"))
			_bags.draw_rect(Rect2(p.x, p.y, 10, 8), Color("9e2c34"))
			_bags.draw_rect(Rect2(p.x, p.y, 10, 2), Color("c84438"))
			_bags.draw_rect(Rect2(p.x + 3, p.y - 3, 4, 3), Color("3e1520"))
