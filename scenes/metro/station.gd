extends Node2D
## Beylikdüzü Sondurak (3/4 üstten bakış, mekan: tools/make_rooms.py "durak"): peronda serbestçe gezilir. Kapıların önünde bir insan yığını bekler;
## metrobüs geldikçe öndekiler biner, yığın kapıya doğru akar. Beklersen sıran gelir,
## kalabalığı yararak öne geçersen (kaynak) insanlar bağırır, öfke dolarsa biri seni durdurur.

const MetroEvents = preload("res://data/metro_events.gd")
const Person = preload("res://scenes/metro/person.gd")
const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const StatusBar = preload("res://scenes/ui/status_bar.gd")
const Places = preload("res://data/places.gd")
const Phone = preload("res://scenes/ui/phone.gd")

const WORLD_W := 960.0
const EDGE_Y := 80.0               # peron kenarı
const FLOOR_MIN := 90.0
const FLOOR_MAX := 190.0
const BUS_Y := 8.0                 # metrobüs görselinin üst kenarı
const STOP_X := 250.0              # metrobüsün durduğu yer (sol ucu)
const BUS_LEN := 404.0
const DOOR_OFFSETS := [80.0, 226.0, 320.0]   # bus.png içindeki kapılar
const QUEUE_CENTER := Vector2(450, 90)
const TURNSTILE_X := 880.0
const BOARD_STEP := 0.2            # kapılardan saniyede ~5 kişi biner
const CUT_TOLERANCE := 3           # bu kadar kişiyi geçmek kaynak sayılmaz
const ANGER_LIMIT := 8.0            # öfke bu kadar dolarsa biri seni durdurur
const ANGER_PER_PERSON := 0.3       # geçilen her kişi için öfke (dolması için ~25 kişi)
const ANGER_DECAY := 0.35           # saniyede sönen öfke
const DOOR_RUSH_ANGER := 0.7        # sıran gelmeden kapıya dalınca
const CUT_SHOUT_COOLDOWN := 1.5

var _room: Room
var _people: Node2D
var _bus_layer: Node2D
var _bus_sprite: Sprite2D
var _player
var _simitci
var _night := false
var _queue: Array = []             # sıradaki yolcular, önden arkaya
var _slots: Array = []             # yığın içindeki yerler (kapıya yakından uzağa)
var _paused := false

# metrobüs
var _bus_state := "wait"           # wait, arriving, open, leaving
var _bus_t := 6.0
var _bus_x := 1000.0
var _bus_speed := 0.0
var _bus_type := "bos"
var _next_type := "bos"
var _capacity := 0
var _board_t := 0.0
var _open_t := 0.0
var _boarded_this_bus := 0
var _stuck_shouted := false

# sıra ve kaynak
var _joined := false
var _fair_rank := 0
var _rank := 0
var _anger := 0.0
var _cut_shout_t := 0.0
var _warned := false
var _walking := false             # oyuncu kendisi mi yürüyor (yoksa kalabalıkla mı ilerliyor)

var _shout_t := 2.0
var _spawn_t := 1.0
var _simit_t := 3.0
var _ui: CanvasLayer
var _hud: Control
var _labels := {}
var _hint_bar: HintBar
var _phone
var _overlay: Node2D
var _max_crowd := 40
var _at_school := false         # Davutpaşa'dan eve dönüş: daha küçük kalabalık


func _ready() -> void:
	GameState.metro_on_board = false
	_at_school = GameState.metro_station != 0
	# gece seyrek: simitçi yok, kalabalık az; sabah ve akşam iş çıkışı en yoğun
	var m: float = GameState.minute
	_night = m >= 21 * 60 + 30 or m < 6 * 60 + 30
	var rush := (m >= 7 * 60 and m < 10 * 60) or (m >= 17 * 60 and m < 20 * 60)
	_max_crowd = 8 if _night else (26 if _at_school else (40 if rush else 28))
	_make_slots()
	_room = Room.new().build("durak")
	add_child(_room)
	_bus_sprite = Sprite2D.new()   # metrobüs: yolun üstünde, peron kenarının gerisinde
	_bus_sprite.texture = load("res://assets/rooms/props/bus.png")
	_bus_sprite.centered = false
	_bus_sprite.visible = false
	_room.floor_layer.add_child(_bus_sprite)
	_bus_layer = Node2D.new()   # açık kapılar, içerideki kafalar
	_bus_layer.draw.connect(_draw_bus)
	_room.floor_layer.add_child(_bus_layer)
	_overlay = Node2D.new()   # tabela ve dijital pano yazıları
	_overlay.draw.connect(_draw_signs)
	_room.top_layer.add_child(_overlay)
	_people = _room.actors

	for i in (4 if _night else (16 if _at_school else (30 if rush else 18))):
		var p = _spawn_person(_slot(i))
		p.position = _slot(i) + p.jitter
	_player = Person.new()
	_player.look = GameState.player_look()
	_player.state = "player"
	_player.marker = true
	_people.add_child(_player)
	_simitci = Person.new()
	_simitci.look = "simitci"
	_simitci.state = "wander"
	_simitci.position = _room.mark("simitci")
	_simitci.target = _simitci.position
	_people.add_child(_simitci)
	_simitci.visible = not _night   # gece simitçi evine gitmiş

	match GameState.station_return:
		"front":
			_player.position = _slot(0) + Vector2(0, -2)
			_join(0)
			_say(_player, "Herkes yol verdi!")
		"back":
			_player.position = _slot(_queue.size() + 2)
			_join(_queue.size())
		_:
			_player.position = _room.mark("spawn")
			_player.face_dir("left")
	GameState.station_return = ""

	_room.follow(_player)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build_hud()
	_ui.add_child(StatusBar.new())
	Lighting.apply(self, true, _room.lamps(), 110.0)
	_phone = Phone.new()
	_ui.add_child(_phone)
	if not GameState.intro_seen:
		_show_intro()


func _physics_process(delta: float) -> void:
	_bus_layer.queue_redraw()
	_overlay.queue_redraw()
	_hud.queue_redraw()
	_update_hud()
	if _paused:
		return
	GameState.spend_time(delta * Places.STATION_MINUTES_PER_SECOND)   # beklerken saat ilerler
	_move_player(delta)
	_update_queue(delta)
	_update_bus(delta)
	_update_rank()
	_update_simitci(delta)
	_ambient(delta)
	_anger = maxf(0.0, _anger - ANGER_DECAY * delta)
	_cut_shout_t -= delta
	if _anger < ANGER_LIMIT * 0.5:
		_warned = false

	if _phone.is_open():
		pass
	elif Input.is_action_just_pressed("interact"):
		_interact()
	elif Input.is_action_just_pressed("back"):
		_exit_station()


# ---------------------------------------------------------------- Kalabalık

## Yığın içindeki yerler: kapıların ortasına (peron kenarına) yakın olan önce.
func _make_slots() -> void:
	for row in 10:
		for x in range(250, 660, 10):
			_slots.append(Vector2(x + (5 if row % 2 else 0), FLOOR_MIN + row * 10))
	_slots.sort_custom(func(a, b): return _key(a) < _key(b))


## "Sıra mesafesi": en yakın kapıya uzaklık. Yana yayılmak, geriye yayılmaktan daha az
## uzaklaştırır; böylece her kapının önünde ayrı bir yığın oluşur.
func _key(p: Vector2) -> float:
	var best := INF
	for o in DOOR_OFFSETS:
		var door := Vector2(STOP_X + o, QUEUE_CENTER.y)
		best = minf(best, Vector2((p.x - door.x) * 0.8, (p.y - door.y) * 1.7).length())
	return best


## En yakın kapının x'i (yolcular oraya bakar).
func _nearest_door_x(x: float) -> float:
	var best: float = STOP_X + DOOR_OFFSETS[0]
	for o in DOOR_OFFSETS:
		if absf(STOP_X + o - x) < absf(best - x):
			best = STOP_X + o
	return best


func _slot(i: int) -> Vector2:
	return _slots[mini(i, _slots.size() - 1)]


func _spawn_person(at: Vector2):
	var p := Person.new()
	p.look = MetroEvents.random_look()
	p.wants_seat = randf() < 0.45
	p.jitter = Vector2(randf_range(-3, 3), randf_range(-2, 2))
	p.position = at
	_people.add_child(p)
	_queue.append(p)
	return p


func _update_queue(delta: float) -> void:
	for i in _queue.size():
		var p = _queue[i]
		# oyuncu sıraya girdiyse onun yeri boş bırakılır, arkadakiler önüne geçmez
		var slot_i := i if not _joined or i < _fair_rank else i + 1
		var goal: Vector2 = _slot(slot_i) + p.jitter
		var far: bool = p.position.distance_to(goal) > 20.0
		if p.step_to(goal, 50.0 if far else 20.0, delta):
			p.face_dir("up")   # metrobüsün geleceği yere bakarlar
	# arkadan yeni yolcular gelir
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(0.9, 2.0) * (4.0 if _night else 1.0)
		if _queue.size() < _max_crowd:
			_spawn_person(Vector2(TURNSTILE_X + 30, randf_range(142, 162)))
	# binenler kapıya yürüyüp kaybolur
	for p in _people.get_children():
		if p.get_script() == Person and p != _player and p.state == "board" and p.step_to(p.target, 70.0, delta):
			p.queue_free()


func _move_player(delta: float) -> void:
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if GameState.autoplay:
		dir = _autopilot()
	elif _phone.is_open():
		dir = Vector2.ZERO   # telefona bakarken yürümezsin
	# kalabalığın içinde yavaşlarsın
	var near := 0
	for p in _queue:
		if absf(p.position.x - _player.position.x) < 12.0 and absf(p.position.y - _player.position.y) < 8.0:
			near += 1
	var slow := clampf(1.0 - 0.17 * near, 0.3, 1.0)
	_walking = dir != Vector2.ZERO
	if dir == Vector2.ZERO and _joined:
		# tuşa basmıyorsan kalabalıkla birlikte yerine doğru ilerlersin
		if _player.step_to(_slot(_fair_rank), 20.0, delta):
			_player.face_dir("up")
	else:
		_room.walk(_player, dir, 62.0 * slow, delta)
	# itişme: insanlar kenara kayar, sen de biraz geri itilirsin
	for p in _queue:
		var d: Vector2 = p.position - _player.position
		if absf(d.x) < 8.0 and absf(d.y) < 4.0:
			var sx := signf(d.x) if d.x != 0.0 else (1.0 if randf() < 0.5 else -1.0)
			var push := 8.0 - absf(d.x)
			p.position.x += sx * push * 0.6
			_player.position = _room.slide(_player.position, Vector2(-sx * push * 0.4, 0))
	_player.position = Vector2(clampf(_player.position.x, 10, WORLD_W - 10), clampf(_player.position.y, FLOOR_MIN - 2, FLOOR_MAX))


## Test için: sıranın sonuna girip bekler, sırası gelince kapıya yürür ve biner.
## --cut verilirse doğrudan kalabalığı yararak kapıya koşar.
func _autopilot() -> Vector2:
	var goal: Vector2 = _slot(_queue.size() + 1)
	if OS.get_cmdline_user_args().has("--cut") or _my_turn():
		goal = Vector2(STOP_X + DOOR_OFFSETS[1], FLOOR_MIN - 2)
	elif _joined:
		return Vector2.ZERO
	if _near_door():
		_interact()
	var d: Vector2 = goal - _player.position
	return Vector2.ZERO if d.length() < 3.0 else d.normalized()


# ---------------------------------------------------------------- Sıra ve kaynak

func _join(rank: int) -> void:
	_joined = true
	_fair_rank = rank


func _update_rank() -> void:
	var pk := _key(_player.position)
	_rank = 0
	for p in _queue:
		if _key(p.position) < pk:
			_rank += 1
	var last_key := _key(_slot(_queue.size()))
	if not _joined:
		if pk <= last_key + 10.0 and _player.position.x < TURNSTILE_X - 20:
			_join(_rank)
		return
	if pk > last_key + 45.0:
		_joined = false   # yığından uzaklaştın, yerini kaybettin
		return
	if not _walking:
		_rank = _fair_rank   # kalabalıkla birlikte ilerliyorsun, yerin belli
		return
	if _rank < _fair_rank - CUT_TOLERANCE:
		var passed := _fair_rank - _rank
		_fair_rank = _rank   # öne geçtiğin yer artık senin
		if _my_turn():
			return           # sıran gelmiş, kapıya yürümek kaynak sayılmaz
		_anger += passed * ANGER_PER_PERSON
		if _rank >= _queue.size():
			return
		var who = _queue[_rank]
		if _anger >= ANGER_LIMIT:
			_confront()
		elif _anger >= ANGER_LIMIT - 1.5 and not _warned:
			_warned = true
			_say(who, "Son uyarı! Bir kişi daha geçersen görürsün!")
		elif _cut_shout_t <= 0.0:
			# az öfkede kibarca uyarırlar, öfke arttıkça sertleşir
			_cut_shout_t = CUT_SHOUT_COOLDOWN
			_say(who, (MetroEvents.SHOUT_CUT if _anger >= ANGER_LIMIT * 0.5 else MetroEvents.SHOUT_CUT_MILD).pick_random())


## Biri öfkelenip seni durdurur: kavga ya da en arkaya dönüş.
func _confront() -> void:
	_paused = true
	_player.set_moving(false, 0.0)
	# senden korkmayan biri seni durdurur; herkes korkuyorsa kimse sesini çıkaramaz
	var brave: Array = ["abi", "abi", "plaza", "teyze", "kulaklik"].filter(func(r): return not GameState.is_scared(r))
	if brave.is_empty():
		_anger = 0.0
		_paused = false
		_say(_player, "Kimse sesini çıkaramadı. Namın yürüyor!")
		return
	var id: String = brave.pick_random()
	var popup := ChoicePopup.new()
	popup.set_rival(id)
	popup.add_line("KAYNAK YAKALANDI!", 10, Color("ff9a7a"))
	popup.add_line("\"%s Herkes burada yarım saattir bekliyor!\"" % MetroEvents.SHOUT_CUT.pick_random())
	popup.add_line("Etraftakiler: \"Doğru söylüyor!\"", 9, Color(1, 1, 1, 0.65))
	_phone.close()
	popup.add_rival_choices(id, "Ne var?! (kavga)")
	popup.add_choice("Tamam tamam... (en arkaya geç)", "back")
	_ui.add_child(popup)
	popup.chosen.connect(func(choice: String):
		popup.queue_free()
		match choice:
			"fight":
				GameState.fight_rival = id
				GameState.fight_venue = "durak"
				GameState.station_fight = true
				GameState.save_game()
				GameState.go_to(GameState.SCENE_FIGHT)
				return
			"intimidate":
				GameState.intimidate(id)
				_say(_player, "+%d TL. Kimse sesini çıkaramadı." % GameState.intimidate_reward(id))
			"back":
				_player.position = _slot(_queue.size() + 3)
				_join(_queue.size())
		_anger = 0.0
		_paused = false)


# ---------------------------------------------------------------- Metrobüs

func _doors() -> Array:
	var out: Array = []
	for o in DOOR_OFFSETS:
		out.append(_bus_x + o)
	return out


func _update_bus(delta: float) -> void:
	match _bus_state:
		"wait":
			_bus_t -= delta
			if _bus_t <= 0.0:
				_bus_state = "arriving"
				_bus_type = _next_type
				_bus_x = WORLD_W + 60.0
				_capacity = randi_range(16, 24) if _bus_type == "bos" else randi_range(5, 9)
				_shout_front(MetroEvents.SHOUT_EMPTY_COMING if _bus_type == "bos" else MetroEvents.SHOUT_FULL_COMING)
		"arriving":
			_bus_x = move_toward(_bus_x, STOP_X, maxf(25.0, (_bus_x - STOP_X) * 2.0) * delta)
			if absf(_bus_x - STOP_X) < 0.5:
				_bus_state = "open"
				_open_t = 0.0
				_board_t = 0.5
				_boarded_this_bus = 0
				_stuck_shouted = false
		"open":
			_open_t += delta
			_board_t -= delta
			if _board_t <= 0.0 and _capacity > 0:
				_board_t = BOARD_STEP
				_board_next()
			if _capacity <= 0 or _open_t > 8.0:
				_bus_state = "leaving"
				_bus_speed = 0.0
				_shout_front(MetroEvents.SHOUT_DOORS_CLOSE)
		"leaving":
			_bus_speed += 140.0 * delta
			_bus_x -= _bus_speed * delta
			if _bus_x < -BUS_LEN - 40.0:
				_bus_state = "wait"
				_bus_t = randf_range(10.0, 15.0)
				_next_type = "bos" if randf() < 0.6 else "dolu"


## Öndekilerden binmek isteyen ilk kişi kapıya yürür. Dolu metrobüse oturmak isteyenler binmez.
func _board_next() -> void:
	var refused := false
	for i in mini(8, _queue.size()):
		var p = _queue[i]
		if _bus_type == "dolu" and p.wants_seat:
			refused = true
			continue
		_queue.remove_at(i)
		var best: float = _doors()[0]
		for d in _doors():
			if absf(d - p.position.x) < absf(best - p.position.x):
				best = d
		p.state = "board"
		p.target = Vector2(best, EDGE_Y + 2)
		_capacity -= 1
		_boarded_this_bus += 1
		if _joined and i < _fair_rank:
			_fair_rank -= 1
		return
	if _my_turn() and not _stuck_shouted and _open_t > 2.5 and not _queue.is_empty():
		_stuck_shouted = true
		_say(_queue[mini(6, _queue.size() - 1)], "Niye binmiyorsun öndeki?!")
	elif refused and not _stuck_shouted and _open_t > 1.5 and _queue.size() > 10:
		_stuck_shouted = true
		_say(_queue[mini(12, _queue.size() - 1)], MetroEvents.SHOUT_FRONT_STUCK.pick_random())


## Bu metrobüste sana yer kaldı mı (önündekiler binince sen de sığıyor musun)?
func _my_turn() -> bool:
	return _bus_state == "open" and _joined and _fair_rank < _capacity


func _near_door() -> bool:
	if _bus_state != "open":
		return false
	for d in _doors():
		if absf(_player.position.x - d) < 16.0 and _player.position.y < FLOOR_MIN + 10.0:
			return true
	return false


func _interact() -> void:
	if _near_door():
		if _capacity <= 0:
			_say(_player, "Doldu, kapı kapanıyor...")
			return
		if _joined and not _my_turn():
			# sıran gelmeden kapıya dalamazsın: arkadakiler bağırır, öfke artar
			_anger += DOOR_RUSH_ANGER
			if not _queue.is_empty():
				_say(_queue[randi() % mini(5, _queue.size())], "Sıranı bekle! Önünde %d kişi var!" % _fair_rank)
			if _anger >= ANGER_LIMIT:
				_confront()
			return
		_board()
	elif not _night and _player.position.distance_to(_simitci.position) < 20.0:
		_buy_simit()


func _board() -> void:
	_paused = true
	GameState.board_bus_type = _bus_type
	GameState.board_ahead = _boarded_this_bus
	GameState.metro_on_board = true
	GameState.metro_seated = false
	GameState.metro_seat = -1
	GameState.metro_dir = -1 if _at_school else 1
	GameState.save_game()
	GameState.go_to(GameState.SCENE_SEATS)


# ---------------------------------------------------------------- Simitçi ve laf atmalar

func _update_simitci(delta: float) -> void:
	if _night:
		return
	if _simitci.step_to(_simitci.target, 22.0, delta):
		if randf() < 0.01:
			_simitci.target = Vector2(randf_range(120, 840), randf_range(150, FLOOR_MAX - 4))
	_simit_t -= delta
	if _simit_t <= 0.0:
		_simit_t = randf_range(14.0, 22.0)
		_say(_simitci, MetroEvents.SHOUT_SIMIT.pick_random())


func _buy_simit() -> void:
	if GameState.simit_buff:
		_say(_simitci, "Bir tane yedin ya, doymadın mı?")
	elif GameState.try_spend(GameState.SIMIT_PRICE):
		GameState.simit_buff = true
		GameState.food = minf(100.0, GameState.food + 12.0)
		GameState.save_game()
		_say(_simitci, "Afiyet olsun! Sonraki kavgada +%d can." % GameState.SIMIT_HP, 3.0)
	else:
		_say(_simitci, "5 TL bile yok mu be evladım?")


func _ambient(delta: float) -> void:
	_shout_t -= delta
	if _shout_t > 0.0 or _queue.is_empty():
		return
	_shout_t = randf_range(6.0, 11.0)   # seyrek: ekran baloncuktan geçilmesin
	if _bubble_count() > 0:
		return
	var lines: Array = MetroEvents.SHOUT_BOARDING if _bus_state == "open" else MetroEvents.SHOUT_WAITING
	var visible: Array = _queue.filter(func(p): return absf(p.position.x - _room.cam.position.x) < 220.0)
	if not visible.is_empty():
		_say(visible.pick_random(), lines.pick_random())


## Şu an ekranda kaç baloncuk var.
func _bubble_count() -> int:
	var layer := get_node_or_null("BubbleLayer")
	return layer.get_child_count() if layer else 0


func _shout_front(lines: Array) -> void:
	if not _queue.is_empty():
		_say(_queue[randi() % mini(4, _queue.size())], lines.pick_random())


func _say(who: Node2D, text: String, seconds: float = 2.5) -> void:
	Bubble.say(self, who, text, 54.0, seconds)


func _show_intro() -> void:
	_paused = true
	var popup := ChoicePopup.new()
	popup.portrait = GameState.fighter_texture("player", "idle")
	popup.title = "Hoş geldin, Yıldızlı!"
	popup.add_line("Sabahın köründe Beylikdüzü Sondurak'tasın. Okul Davutpaşa'da, araban yok, cebinde %d TL var." % GameState.money)
	popup.add_line("Kapıların önünde koca bir insan yığını var. Sıranı bekleyebilir ya da kalabalığı yarıp kaynak yapabilirsin... ama insanlar kızar.", 9, Color(1, 1, 1, 0.75))
	popup.add_line("Tabela sonraki metrobüsün boş mu dolu mu geleceğini gösterir. Boşa binersen oturma şansın olur.", 9, Color("7dd3fc"))
	popup.add_choice("Hadi bakalım!", "ok")
	_ui.add_child(popup)
	popup.chosen.connect(func(_c: String):
		popup.queue_free()
		GameState.intro_seen = true
		GameState.save_game()
		_paused = false)


## Duraktan çık: Beylikdüzü'ndeysen mahalleye, Davutpaşa'daysan kampüse.
func _exit_station() -> void:
	_paused = true
	GameState.save_game()
	GameState.enter_map("kampus" if _at_school else "mahalle", "giris" if _at_school else "durak")


func _leave(path: String) -> void:
	_paused = true
	GameState.save_game()
	GameState.go_to(path)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	_ui.add_child(_hud)
	# alt kartlar: solda durak ve sıra/öfke, sağda metrobüs; en altta bilgi şeridi
	for spec in [["money", Vector2(11, 219), 10, UIDraw.GOLD], ["rank", Vector2(11, 233), 8, Color.WHITE],
			["bus", Vector2(302, 219), 9, Color.WHITE], ["bus2", Vector2(302, 233), 8, UIDraw.TEXT_DIM]]:
		var l := GameState.make_label("", spec[2], spec[3])
		l.position = spec[1]
		_hud.add_child(l)
		_labels[spec[0]] = l
	_hint_bar = HintBar.new()
	_hint_bar.default_text = "WASD: yürü · E: bin / simit al · T: telefon · Esc: duraktan çık"
	_ui.add_child(_hint_bar)


func _bus_type_name() -> String:
	return "BOŞ" if (_bus_type if _bus_state != "wait" else _next_type) == "bos" else "YARI DOLU"


func _update_hud() -> void:
	_labels["money"].text = "%s%s" % [MetroEvents.STATIONS[GameState.metro_station], "  + simit" if GameState.simit_buff else ""]
	if _joined:
		_labels["rank"].text = "Önünde ~%d kişi var" % _rank if _rank > 0 else "En öndesin!"
	else:
		_labels["rank"].text = "Sırada değilsin. Kalabalığa katıl!"
	match _bus_state:
		"wait":
			_labels["bus"].text = "Sonraki: %d sn" % ceili(_bus_t)
			_labels["bus2"].text = "Tabelada yazıyor"
		"arriving":
			_labels["bus"].text = "Perona giriyor!"
			_labels["bus2"].text = "Kapılara hazırlan"
		"open":
			_labels["bus"].text = "Kapılar açık"
			_labels["bus2"].text = "Kalan yer: ~%d kişi" % maxi(0, _capacity)
		"leaving":
			_labels["bus"].text = "Metrobüs kalktı"
			_labels["bus2"].text = "Bir sonrakini bekle"
	var hint := ""
	if _near_door() and _joined and not _my_turn():
		hint = "Sıran gelmedi, önünde ~%d kişi var · Bekle ya da kalabalığı yar" % _fair_rank
	elif _near_door():
		hint = "E: Metrobüse bin (%s)" % ("boş, koltuk kapabilirsin" if _bus_type == "bos" else "yarı dolu, ayakta gidersin")
	elif not _night and _player.position.distance_to(_simitci.position) < 20.0 and not GameState.simit_buff:
		hint = "E: Simit al (%d TL, sonraki kavgada +%d can)" % [GameState.SIMIT_PRICE, GameState.SIMIT_HP]
	elif _my_turn():
		hint = "Sıran geldi! Kapıya git, E'ye bas" + (" · ya da bekle, sonraki boş gelir" if _bus_type == "dolu" else "")
	_hint_bar.text = hint


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	# sol kart: durak, sıra, öfke göstergesi
	var left := Rect2(4, 216, 210, 33)
	var k := _anger / ANGER_LIMIT
	var hot := Color("4ade80").lerp(Color("f59e0b"), clampf(k * 2.0, 0.0, 1.0)).lerp(Color("ef4444"), clampf(k * 2.0 - 1.0, 0.0, 1.0))
	UIDraw.card(_hud, left, hot if k > 0.6 else UIDraw.GOLD)
	_hud.draw_string(font, Vector2(140, 226), "KALABALIK ÖFKESİ", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UIDraw.TEXT_DIM)
	var shake := roundf(sin(Time.get_ticks_msec() / 40.0)) if k > 0.75 else 0.0
	UIDraw.meter(_hud, Rect2(140 + shake, 231, 66, 7), k, hot, int(ANGER_LIMIT))
	# sağ kart: metrobüs simgesi, durum, BOŞ / YARI DOLU etiketi
	var right := Rect2(270, 216, 178, 33)   # sağ altta telefon düğmesi var
	UIDraw.card(_hud, right)
	UIDraw.box(_hud, Rect2(277, 223, 20, 12), Color("f4f4f6"), Color(0, 0, 0, 0), 2)
	_hud.draw_rect(Rect2(277, 230, 20, 2), Color("c8102e"))
	_hud.draw_rect(Rect2(279, 225, 16, 4), Color("2b3a55"))
	_hud.draw_circle(Vector2(281, 236), 2, Color("24242c")); _hud.draw_circle(Vector2(293, 236), 2, Color("24242c"))
	var tag := _bus_type_name()
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 10.0
	var tag_col := Color("16a34a") if tag == "BOŞ" else Color("d97706")
	UIDraw.box(_hud, Rect2(442 - tw, 221, tw, 11), tag_col, Color(0, 0, 0, 0), 5)
	_hud.draw_string(font, Vector2(447 - tw, 229.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)


# ---------------------------------------------------------------- Çizim

## Tabelanın ve dijital panonun yazıları (eşya görsellerinin üstüne).
func _draw_signs() -> void:
	var font := ThemeDB.fallback_font
	var sign := _room.mark("sign_text")
	_overlay.draw_string(font, sign, MetroEvents.STATIONS[GameState.metro_station].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 126, 7, Color.WHITE)
	var board_text := "%s %ds" % ["BOŞ" if _next_type == "bos" else "DOLU", maxi(0, ceili(_bus_t))] \
			if _bus_state == "wait" else ("BOŞ" if _bus_type == "bos" else "DOLU")
	var b := _room.mark("board_text")
	_overlay.draw_string(font, b + Vector2(0, -6), "SONRAKİ" if _bus_state == "wait" else "PERONDA", HORIZONTAL_ALIGNMENT_CENTER, 44, 6, Color("ff9a2a"))
	_overlay.draw_string(font, b + Vector2(0, 3), board_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 7, Color("ff9a2a"))


## Metrobüs: görsel (bus.png) yolda kayar; açıkken kapılar kararır, doluysa camlarda kafalar görünür.
func _draw_bus() -> void:
	_bus_sprite.visible = _bus_state != "wait"
	if _bus_state == "wait":
		return
	var x0 := roundf(_bus_x)
	_bus_sprite.position = Vector2(x0 - 1, BUS_Y - 1)
	if _bus_type == "dolu":
		for wx in range(34, int(BUS_LEN) - 10, 17):
			var skip := false
			for d in DOOR_OFFSETS:
				if absf(wx - d) < 16.0:
					skip = true
			if skip or (wx > 190 and wx < 214):
				continue
			_bus_layer.draw_rect(Rect2(x0 + wx, BUS_Y + 32, 7, 8), Color("c89a70"))
			_bus_layer.draw_rect(Rect2(x0 + wx, BUS_Y + 30, 7, 3), Color("3a2a22"))
	if _bus_state == "open":
		for d in DOOR_OFFSETS:
			_bus_layer.draw_rect(Rect2(x0 + d - 12, BUS_Y + 22, 24, 38), Color("1b1b24"))
			_bus_layer.draw_rect(Rect2(x0 + d - 15, BUS_Y + 22, 3, 38), Color("aab2c0"))
			_bus_layer.draw_rect(Rect2(x0 + d + 12, BUS_Y + 22, 3, 38), Color("aab2c0"))
			_bus_layer.draw_rect(Rect2(x0 + d - 12, BUS_Y + 56, 24, 4), Color("e6b428"))
