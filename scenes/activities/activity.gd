extends Node2D
## Kampüste ders (basamaklı amfi) ve yemekhane, 3/4 üstten bakış: kapıdan girersin, boş bir yere oturursun
## (yemekhanede önce tezgahtan tepsi alırsın), ekranda saat dönerken zaman akar, bitince kampüs haritasına dönersin.
## Oynanan eylem GameState.activity içinde (data/places.gd CAMPUS_ACTIONS + course/faculty).
## Mekanlar tools/make_rooms.py: "amfi" ve "yemekhane".

const StatusBar = preload("res://scenes/ui/status_bar.gd")
const Person = preload("res://scenes/metro/person.gd")
const MetroEvents = preload("res://data/metro_events.gd")
const Places = preload("res://data/places.gd")

const REACH := 12.0
const WALK_SPEED := 82.0
const LECTURE_LINES := ["Bu konu sınavda çıkar!", "Arkadakiler, sessiz!", "Yoklama kağıdı dolaşıyor...",
		"Bunu bir daha anlatmayacağım.", "Tahtaya kim çıkmak ister?", "Telefonlar cebe!"]

var _mode := "lecture"
var _action: Dictionary
var _room: Room
var _seats: Array = []    # [konum, baktığı yön]
var _player
var _npc
var _students: Array = []
var _occupied := {}       # koltuk -> oturan
var _has_tray := false
var _my_seat := -1
var _state := "walk"      # walk, sitting
var _clock_from := 0.0
var _clock_t := 0.0
var _ui: CanvasLayer
var _hint: HintBar
var _top: Node2D
var _clock: Control


func _ready() -> void:
	_action = GameState.activity
	_mode = _action.get("scene", "lecture")
	_room = Room.new().build("amfi" if _mode == "lecture" else "yemekhane")
	add_child(_room)
	if _mode == "lecture":
		for p in _room.points("seats"):
			_seats.append([p, "up"])
	else:
		for p in _room.points("seats_top"):
			_seats.append([p, "down"])
		for p in _room.points("seats_bottom"):
			_seats.append([p, "up"])
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	_room.top_layer.add_child(_top)

	_npc = _person("necati" if _mode == "lecture" else "sivil27", _room.mark("lecturer" if _mode == "lecture" else "cook"))
	_npc.face_dir("down")
	_room.add_blocker(_npc)
	var order := range(_seats.size())
	order.shuffle()
	var fill := 0.5 if _mode == "lecture" else Places.crowd_level("yemekhane", GameState.minute, GameState.weekday())
	for i in order.slice(0, int(_seats.size() * fill)):
		var s = _person(MetroEvents.random_look(), _seats[i][0])
		s.sit(_seats[i][1])
		_occupied[i] = s
		_students.append(s)

	_player = _person(GameState.player_look(), _room.mark("spawn"))
	_player.marker = true
	_player.face_dir("up")
	_room.follow(_player)

	Lighting.apply(self, false, _room.lamps(), 100.0, true)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(StatusBar.new())
	var name := "%s: %s" % [_action.get("faculty", "Amfi"), _action.get("course", "")] if _mode == "lecture" else "Merkez Yemekhane"
	var title := GameState.make_label(name, 11, Color("e6b428"))
	title.position = Vector2(4, 25)
	UIDraw.pill(title)
	_ui.add_child(title)
	_hint = HintBar.new()   # alt bilgi şeridi
	_hint.default_text = "WASD: yürü · E: otur · Esc: çık"
	_ui.add_child(_hint)
	_clock = Control.new()
	_clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.draw.connect(_draw_clock)
	_ui.add_child(_clock)
	Bubble.say(self, _npc, "Geç kaldın! Bir yere otur." if _mode == "lecture" else "Tepsini al gel!", 34.0, 2.5)
	# test kısayolu: -- --act  (kendi kendine tepsi alır, oturur)
	if OS.get_cmdline_user_args().has("--act"):
		await get_tree().create_timer(0.4).timeout
		if _mode == "cafeteria":
			_player.position = _room.mark("tray")
			_interact()
		var free := _free_seats()
		_player.position = _seats[free[free.size() - 1]][0]
		_interact()


func _person(look: String, at: Vector2):
	var p := Person.new()
	p.look = look
	p.position = at
	_room.add_actor(p)
	return p


func _process(delta: float) -> void:
	if _state == "walk":
		var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		_room.walk(_player, dir, WALK_SPEED, delta)
		if Input.is_action_just_pressed("interact"):
			_interact()
		elif Input.is_action_just_pressed("back") and not (_mode == "cafeteria" and _has_tray):
			GameState.go_to(GameState.SCENE_MAP)   # vazgeçtin, kampüse dön
			_state = "leaving"
		elif _player.position.distance_to(_room.mark("exit")) < 8.0 and not (_mode == "cafeteria" and _has_tray):
			GameState.go_to(GameState.SCENE_MAP)
			_state = "leaving"
	_hint.text = _hint_text()
	_top.queue_redraw()
	_clock.queue_redraw()


func _free_seats() -> Array:
	return range(_seats.size()).filter(func(i): return not _occupied.has(i))


func _seat_near() -> int:
	var best := -1
	for i in _free_seats():
		var d: float = _seats[i][0].distance_to(_player.position)
		if d < REACH and (best < 0 or d < _seats[best][0].distance_to(_player.position)):
			best = i
	return best


func _at_counter() -> bool:
	return _player.position.distance_to(_room.mark("tray")) < 26.0


func _hint_text() -> String:
	if _state != "walk":
		return ""
	if _mode == "cafeteria" and not _has_tray:
		return "E: Tepsi al" if _at_counter() else "Önce tezgahtan tepsini al (yukarı soldaki tezgah)"
	if _seat_near() >= 0:
		return "E: Otur"
	return "Sıralarda boş bir yere geç" if _mode == "lecture" else "Boş bir yere otur"


func _interact() -> void:
	if _mode == "cafeteria" and not _has_tray:
		if _at_counter():
			_has_tray = true
			_player.face_dir("up")
			Bubble.say(self, _npc, ["Afiyet olsun!", "Bugün kuru fasulye var.", "Pilavı bol koydum."].pick_random(), 34.0, 2.0)
		return
	var i := _seat_near()
	if i >= 0:
		_sit(i)


## Yerine geç, otur; saat dönsün, süre dolunca eylemi uygula ve kampüse dön.
func _sit(i: int) -> void:
	_state = "sitting"
	_occupied[i] = _player
	_my_seat = i
	_player.position = _seats[i][0]
	_player.sit(_seats[i][1])
	_clock_from = GameState.minute
	var seconds := 5.0 if _mode == "lecture" else 3.0
	var tw := create_tween()
	tw.tween_property(self, "_clock_t", 1.0, seconds)
	if _mode == "lecture":
		for k in 3:
			await get_tree().create_timer(seconds / 4.0).timeout
			if k % 2 == 0:
				Bubble.say(self, _npc, LECTURE_LINES.pick_random(), 34.0, 1.5)
			elif not _students.is_empty():
				Bubble.say(self, _students.pick_random(), "Zzz...", 34.0, 1.4)
	await tw.finished
	var lines: Array = GameState.do_action(_action)
	Bubble.say(self, _player, "  ".join(lines) if not lines.is_empty() else "Oh, doydum!", 34.0, 1.8)
	await get_tree().create_timer(1.6).timeout
	GameState.go_to(GameState.SCENE_MAP)


## Tepsi: elde ya da masada.
func _draw_top() -> void:
	if not _has_tray:
		return
	var tray: Vector2
	if _state == "walk":
		tray = _player.position + Vector2(-9, -16)
	else:
		var seat: Array = _seats[_my_seat]
		tray = seat[0] + (Vector2(-9, 0) if seat[1] == "down" else Vector2(-9, -30))
	_top.draw_rect(Rect2(tray.x - 1, tray.y - 1, 20, 7), Color("1b1024"))
	_top.draw_rect(Rect2(tray.x, tray.y, 18, 5), Color("8d5e3c"))
	_top.draw_rect(Rect2(tray.x + 2, tray.y + 1, 6, 3), Color("f4f2ec"))
	_top.draw_rect(Rect2(tray.x + 3, tray.y + 1, 4, 2), Color("c84438"))
	_top.draw_rect(Rect2(tray.x + 10, tray.y + 1, 6, 3), Color("e6b428"))


## Otururken ortada dönen büyük saat: başlangıç saatinden bitişe akar.
func _draw_clock() -> void:
	if _state != "sitting":
		return
	var minutes: float = _action.get("time", 60)
	var now := _clock_from + minutes * _clock_t
	var c := Vector2(240, 80)
	_clock.draw_rect(Rect2(c.x - 110, c.y - 42, 220, 84), Color(0, 0, 0, 0.55))
	_clock.draw_circle(c + Vector2(0, -8), 24, Color("1b1024"))
	_clock.draw_circle(c + Vector2(0, -8), 22, Color("f4f2ec"))
	for h in 12:
		var a := TAU * h / 12.0
		_clock.draw_rect(Rect2(c + Vector2(0, -8) + Vector2.from_angle(a) * 18 - Vector2(1, 1), Vector2(2, 2)), Color("1b1024"))
	var center := c + Vector2(0, -8)
	_clock.draw_line(center, center + Vector2.from_angle(TAU * fmod(now, 60.0) / 60.0 - PI / 2) * 17, Color("c84438"), 2)
	_clock.draw_line(center, center + Vector2.from_angle(TAU * fmod(now / 60.0, 12.0) / 12.0 - PI / 2) * 11, Color("1b1024"), 3)
	var start := "%02d:%02d" % [int(_clock_from) / 60 % 24, int(_clock_from) % 60]
	var cur := "%02d:%02d" % [int(now) / 60 % 24, int(now) % 60]
	var label: String = _action.get("course", "Ders") if _mode == "lecture" else "Yemek yiyorsun"
	_clock.draw_string(ThemeDB.fallback_font, Vector2(c.x - 110, c.y + 26), "%s  %s → %s" % [label, start, cur], HORIZONTAL_ALIGNMENT_CENTER, 220, 9, Color.WHITE)
