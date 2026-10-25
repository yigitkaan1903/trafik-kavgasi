extends Node2D
## Metrobüs (3/4 üstten bakış, mekan: tools/make_rooms.py "metrobus": körüklü, 2+2 koltuklu): duraktan durağa gidilir,
## bazı duraklarda bir olay (çoğu zaman kavga) çıkabilir. Vagonda dört yöne yürünür: boşalan koltuğa
## oturulur, ayaktaki yolculara laf atılır. Camlardan ve kenarlardan akan yol görünür.
## Sağ alttaki telefonla yolda oyun oynanır.

const MetroEvents = preload("res://data/metro_events.gd")
const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Person = preload("res://scenes/metro/person.gd")
const Phone = preload("res://scenes/ui/phone.gd")
const StatusBar = preload("res://scenes/ui/status_bar.gd")
const Places = preload("res://data/places.gd")

# İki durak arası hareket: hızlan, seyret, yavaşlayarak durağa yanaş. Peron sağdan kayarak gelir ve
# metrobüs durduğunda kapıların hizasında olur (kalan yol = peronun uzaklığı).
const TOP_SPEED := 480.0     # dışarının akış hızı (piksel/sn)
const ACCEL_T := 0.9         # kalkışta hızlanma
const BRAKE_T := 1.8         # durağa yanaşırken yavaşlama
const STOP_GAP := 1150.0     # iki durak arası yol (peron boyu + boşluk)
const CRUISE_T := STOP_GAP / TOP_SPEED - ACCEL_T / 2.0 - BRAKE_T / 2.0
const RIDE_TIME := ACCEL_T + CRUISE_T + BRAKE_T
const PLATFORM_X := -40.0    # durunca peronun sol ucu
const PLATFORM_LEN := 880.0
const EVENT_CHANCE := 0.28   # sakin dönem bittiyse durakta olay çıkma ihtimali
const QUIET_MIN := 3          # bir olaydan sonra en az bu kadar durak sakin geçer
const QUIET_MAX := 6
const LEAVE_CHANCE := 0.4    # durakta oturan birinin inme ihtimali
const WALK_SPEED := 70.0
const PLAYER_SEAT := 21      # kayıtlı koltuk yoksa oyuncunun oturduğu koltuk
const WHEELCHAIR_SPOT := Vector2(396, 104)   # tekerlekli sandalye alanı (orta kapının karşısı)
const AISLE_Y := 134.0       # koridorun ortası
const PROVOKE := ["Ne bakıyorsun?", "Biraz ilerler misin?", "Ayağıma bastın!", "Çantan sırtıma giriyor!"]

var _room: Room
var _outside: Node2D
var _riding := false
var _t := 0.0
var _scroll := 0.0
var _speed := 0.0
var _seat_fill := 0.75       # koltukların doluluğu ve ayakta yolcu sayısı saate göre (_crowd_for_time)
var _standing_target := 6
var _wheelchair: Array = []  # [kişi, sandalye görseli] ya da boş
var _door_open := 0.0        # kapı kanatları: 0 kapalı, 1 açık
var _departing := false
var _doors_fx: Node2D
var _city: Array = []        # camlardan görünen binalar: Rect2(x, yükseklik, genişlik, renk tonu)
var _seat_pos: Array = []    # koltukların yeri (oturanın ayakları)
var _doors: Array = []
var _seats: Array = []       # her koltukta oturan (null: boş, _player: sen)
var _standing: Array = []    # ayaktaki yolcular
var _grabbers: Array = []    # boş koltuğa yürüyenler: [kişi, koltuk]
var _player
var _phone
var _popup_open := false
var _quiet := 0               # kaç durak daha olaysız geçecek
var _ui: CanvasLayer
var _hud: Control
var _line_map: Control
var _money_label: Label
var _goal_label: Label
var _hint: HintBar


func _ready() -> void:
	if not GameState.metro_on_board:
		GameState.go_to.call_deferred(GameState.SCENE_STATION)
		set_physics_process(false)
		return
	var rng := RandomNumberGenerator.new()
	var bx := 0.0
	while bx < 900.0:
		var w := roundf(rng.randf_range(12, 26))
		_city.append(Rect2(bx, roundf(rng.randf_range(8, 26)), w, rng.randf()))
		bx += w + roundf(rng.randf_range(2, 8))
	_outside = Node2D.new()   # vagonun dışı: akan yol (vagon görselinin camları ve kenarları şeffaf)
	_outside.draw.connect(_draw_outside)
	add_child(_outside)
	_room = Room.new().build("metrobus")
	add_child(_room)
	_seat_pos = _room.points("seats")
	_doors = _room.points("doors")
	_crowd_for_time()
	_doors_fx = Node2D.new()   # kayan kapı kanatları
	_doors_fx.draw.connect(_draw_doors)
	_room.floor_layer.add_child(_doors_fx)
	_add_passengers()
	_room.follow(_player, 1.0, 104.0)   # vagon boyunca kayar; üstte hat haritası, altta panel
	Lighting.apply(self, false, _room.lamps(), 80.0, true)
	_calm_down()   # yolculuk başında ve kavgadan dönünce biraz nefes al
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build_hud()
	var bar := StatusBar.new()
	bar.position = Vector2(0, 36)
	_ui.add_child(bar)
	_phone = Phone.new()
	_ui.add_child(_phone)
	_riding = true


func _physics_process(delta: float) -> void:
	if _riding:
		_t = minf(_t + delta, RIDE_TIME)
		_speed = _speed_at(_t)
		_scroll += _speed * delta
		if _t >= RIDE_TIME:
			_speed = 0.0
			_arrive()
	_update_grabbers(delta)
	if not _popup_open and not _phone.is_open():
		_control_player(delta)
		if Input.is_action_just_pressed("back"):
			_leave(GameState.SCENE_MENU)
	_outside.queue_redraw()
	_doors_fx.queue_redraw()
	_line_map.queue_redraw()
	_hud.queue_redraw()
	_update_hud()


## Hareketin hızı ve alınan yol (hızlanma, sabit hız, yavaşlama).
func _speed_at(t: float) -> float:
	if t < ACCEL_T:
		return TOP_SPEED * t / ACCEL_T
	if t < ACCEL_T + CRUISE_T:
		return TOP_SPEED
	return TOP_SPEED * clampf((RIDE_TIME - t) / BRAKE_T, 0.0, 1.0)


func _traveled(t: float) -> float:
	if t < ACCEL_T:
		return TOP_SPEED * t * t / (2.0 * ACCEL_T)
	if t < ACCEL_T + CRUISE_T:
		return TOP_SPEED * ACCEL_T / 2.0 + TOP_SPEED * (t - ACCEL_T)
	var left := RIDE_TIME - t
	return STOP_GAP - TOP_SPEED * left * left / (2.0 * BRAKE_T)


func _next_station() -> int:
	return GameState.metro_station + GameState.metro_dir


# ---------------------------------------------------------------- Vagonda hareket

func _control_player(delta: float) -> void:
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if dir != Vector2.ZERO:
		if _seats.has(_player):
			_stand_player()
			_say(_player, "Kalktım... yerim gitti.")
		_room.walk(_player, dir, WALK_SPEED, delta)
	elif not _seats.has(_player):
		_player.set_moving(false)
	if Input.is_action_just_pressed("interact"):
		_interact()


func _interact() -> void:
	if _seats.has(_player):
		return
	var seat := _free_seat_near(_player.position)
	if seat >= 0:
		_sit_player(seat)
		_say(_player, "Oh be! Oturdum.")
		return
	var p = _nearest_standing()
	if p:
		_provoke(p)


## Yakındaki boş koltuk (cam kenarındakine de yandakinin önünden uzanıp oturabilirsin).
func _free_seat_near(at: Vector2) -> int:
	var best := -1
	for i in _seat_pos.size():
		var d: Vector2 = _seat_pos[i] - at
		if _seats[i] == null and absf(d.x) < 13.0 and absf(d.y) < 40.0:
			if best < 0 or _seat_pos[i].distance_to(at) < _seat_pos[best].distance_to(at):
				best = i
	return best


## Yanındaki, laf atılabilecek (tanıdık yüz) yolcu.
func _nearest_standing():
	var best = null
	for p in _standing:
		if not GameState.Rivals.RIVALS.has(p.look):
			continue   # figüranlarla uğraşılmaz
		var d: float = p.position.distance_to(_player.position)
		if d < 24.0 and (best == null or d < best.position.distance_to(_player.position)):
			best = p
	return best


## Ayaktaki bir yolcuya laf at: kavga, gözdağı ya da vazgeç.
func _provoke(p) -> void:
	var id: String = p.look
	_player.face_point(p.position)
	p.face_point(_player.position)
	_calm_down()
	var popup := ChoicePopup.new()
	popup.set_rival(id)
	popup.add_line("Sen: \"%s\"" % PROVOKE.pick_random(), 9, Color(1, 1, 1, 0.65))
	popup.add_line("\"%s\"" % GameState.rival_line(id, "laf"))
	popup.add_scared_note(id)
	popup.add_rival_choices(id, "Kavga et!")
	popup.add_choice("Boş ver", "avoid")
	_open(popup, func(choice: String):
		match choice:
			"fight":
				GameState.fight_rival = id
				GameState.fight_venue = "bus"
				GameState.save_game()
				GameState.go_to(GameState.SCENE_FIGHT)
				return false
			"intimidate":
				GameState.intimidate(id)
				_say(p, GameState.rival(id)["lines"].get("scared", ["Tamam, tamam..."]).pick_random())
		return true)


## Oyuncunun koltuğu: koltuk kaparken ya da önceki sahnede oturduğu yer (GameState.metro_seat).
func _my_seat() -> int:
	return GameState.metro_seat if GameState.metro_seat >= 0 and GameState.metro_seat < _seat_pos.size() else PLAYER_SEAT


func _sit_player(i: int) -> void:
	_seats[i] = _player
	_player.position = _seat_pos[i]
	_player.sit("right")
	GameState.metro_seated = true
	GameState.metro_seat = i


func _stand_player() -> void:
	var i: int = _seats.find(_player)
	if i < 0:
		return
	_seats[i] = null
	_player.position = Vector2(_seat_pos[i].x, AISLE_Y)
	_player.set_moving(false)
	GameState.metro_seated = false
	GameState.metro_seat = -1
	_schedule_grab(i, 0.8)


## Oturma durumu olaylar yüzünden değiştiyse oyuncuyu ona göre yerleştirir.
func _refresh_player() -> void:
	var seat: int = _seats.find(_player)
	if GameState.metro_seated and seat < 0:
		# en yakın boş koltuğa (yoksa kendi koltuğuna; oradaki kalkar gider)
		for i in _seat_pos.size():
			if _seats[i] == null and (seat < 0 or _seat_pos[i].distance_to(_player.position) < _seat_pos[seat].distance_to(_player.position)):
				seat = i
		if seat < 0:
			seat = _my_seat()
			_seats[seat].queue_free()
		_sit_player(seat)
	elif not GameState.metro_seated and seat >= 0:
		_stand_player()


## Bir süre sonra en yakın ayaktaki yolcu boş koltuğa yürür (sen daha önce oturmazsan).
func _schedule_grab(i: int, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if _seats[i] != null or _standing.is_empty():
			return
		var best = _standing[0]
		for p in _standing:
			if p.position.distance_to(_seat_pos[i]) < best.position.distance_to(_seat_pos[i]):
				best = p
		if best.position.distance_to(_seat_pos[i]) > 160.0:
			return   # çok uzaktaki biri koşmaz; koltuk boş kalır, belki sen kaparsın
		_standing.erase(best)
		_grabbers.append([best, i]))


func _update_grabbers(delta: float) -> void:
	for g in _grabbers.duplicate():
		var p = g[0]
		var i: int = g[1]
		if _seats[i] != null:
			_grabbers.erase(g)   # biri (belki sen) önce oturdu
			_standing.append(p)
			p.set_moving(false)
			continue
		# önce koridordan koltuğun hizasına, sonra koltuğa
		var aisle := Vector2(_seat_pos[i].x, AISLE_Y)
		var goal: Vector2 = aisle if absf(p.position.x - aisle.x) > 2.0 and absf(p.position.y - _seat_pos[i].y) > 2.0 else _seat_pos[i]
		if p.step_to(goal, 45.0, delta) and goal == _seat_pos[i]:
			_grabbers.erase(g)
			_room.remove_blocker(p)
			_seats[i] = p
			p.sit("right")


func _person(look: String, at: Vector2):
	var p := Person.new()
	p.look = look
	p.position = at
	_room.add_actor(p)
	return p


## Ayakta durulacak boş bir yer (kapı önleri ve koridor).
func _standing_spot() -> Vector2:
	var spots: Array = _room.points("stand")
	for k in 20:
		var p: Vector2 = spots.pick_random() + Vector2(randf_range(-3, 3), randf_range(-2, 2))
		if not _room.blocked(p, Room.FEET, _player) and p.distance_to(_player.position) > 14.0:
			return p
	return spots.pick_random()


## Yoğunluk saate göre: sabah ve akşam iş saatlerinde tıklım tıklım, gece seyrek.
func _crowd_for_time() -> void:
	var m: float = GameState.minute
	if m >= 21 * 60 + 30 or m < 6 * 60 + 30:
		_seat_fill = 0.35
		_standing_target = 1
	elif (m >= 7 * 60 and m < 10 * 60) or (m >= 17 * 60 and m < 20 * 60):
		_seat_fill = 0.95
		_standing_target = 11
	else:
		_seat_fill = 0.7
		_standing_target = 5


## Tekerlekli sandalyeli yolcu: orta kapının karşısındaki alanda durur.
func _add_wheelchair() -> void:
	if not _wheelchair.is_empty():
		return
	var p = _person(MetroEvents.random_look(), WHEELCHAIR_SPOT)
	p.sit("right")
	var chair := Sprite2D.new()
	chair.texture = load("res://assets/rooms/props/wheelchair.png")
	chair.centered = false
	chair.position = WHEELCHAIR_SPOT + Vector2(-13, 1)
	chair.offset = Vector2(0, -19)
	_room.add_actor(chair)
	_room.add_blocker(p)
	_wheelchair = [p, chair]


func _remove_wheelchair() -> void:
	if _wheelchair.is_empty():
		return
	var p = _wheelchair[0]
	_room.remove_blocker(p)
	for n in _wheelchair:
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.5)
		tw.tween_callback(n.queue_free)
	_wheelchair = []


func _add_passengers() -> void:
	_seats.resize(_seat_pos.size())
	_seats.fill(null)
	_player = _person(GameState.player_look(), Vector2(_room.mark("door_in").x - 40, AISLE_Y))
	_player.marker = true
	_player.face_dir("down")
	for i in _seat_pos.size():
		if (GameState.metro_seated and i == _my_seat()) or randf() > _seat_fill:
			continue
		var s = _person(MetroEvents.random_look(), _seat_pos[i])
		s.sit("right")
		_seats[i] = s
	for k in _standing_target:
		_add_standing(_standing_spot())
	if randf() < 0.35 or OS.get_cmdline_user_args().has("--wheelchair"):
		_add_wheelchair()
	var driver = _person("sivil35", _room.mark("driver"))
	driver.sit("right")
	if GameState.metro_seated:
		_sit_player(_my_seat())


func _add_standing(at: Vector2):
	var p = _person(MetroEvents.random_look(), at)
	p.face_dir(["left", "right", "up", "down", "right"].pick_random())
	_room.add_blocker(p, true)
	_standing.append(p)
	return p


func _say(who: Node2D, text: String) -> void:
	Bubble.say(self, who, text, 34.0, 2.2)


# ---------------------------------------------------------------- Duraklar ve olaylar

func _arrive() -> void:
	_riding = false
	_t = 0.0
	_scroll = roundf(_scroll)
	GameState.metro_station = _next_station()
	GameState.spend_time(Places.METRO_MINUTES_PER_STOP)
	if GameState.metro_seated:
		GameState.energy = minf(100.0, GameState.energy + Places.SEATED_ENERGY_PER_STOP)
	else:
		GameState.energy = maxf(0.0, GameState.energy - Places.STANDING_ENERGY_PER_STOP)
	var name: String = MetroEvents.STATIONS[GameState.metro_station]
	_center_text(name)
	Audio.sfx("ding", 0.6, 0.0)
	GameState.save_game()
	var tw := create_tween()   # kapılar açılır
	Audio.sfx("door", 0.8)
	tw.tween_property(self, "_door_open", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	await tw.finished
	_station_shuffle()
	await get_tree().create_timer(1.0).timeout
	if _popup_open:
		return   # zaten bir pencere açık (ör. laf attın); kapanınca yolculuk sürer
	if GameState.metro_station == MetroEvents.STATIONS.size() - 1 or GameState.metro_station == 0:
		_arrive_destination()
	elif _quiet > 0:
		_quiet -= 1
		_depart()
	elif randf() < EVENT_CHANCE:
		_calm_down()
		_event(GameState.pick_metro_event())
	else:
		_depart()


## Kapılar kapanır, metrobüs yavaşça kalkar.
func _depart() -> void:
	if _departing or _riding:
		return
	_departing = true
	var tw := create_tween()
	Audio.sfx("door", 0.6)
	tw.tween_property(self, "_door_open", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tw.finished
	_departing = false
	_t = 0.0
	_riding = true


## Bir olay (ya da senin çıkardığın kavga) oldu: birkaç durak kimse sataşmaz.
func _calm_down() -> void:
	_quiet = randi_range(QUIET_MIN, QUIET_MAX)


## Hattın ucuna vardın: okulda in ya da Beylikdüzü'nde inip mahalleye dön.
func _arrive_destination() -> void:
	GameState.metro_on_board = false
	GameState.metro_seated = false
	GameState.metro_seat = -1
	set_physics_process(false)
	if GameState.metro_station == 0:
		GameState.enter_map("mahalle", "durak")
	else:
		GameState.enter_map("kampus", "giris")   # kampüs girişinde inersin


func _nearest_door(at: Vector2) -> Vector2:
	var best: Vector2 = _doors[0]
	for d in _doors:
		if d.distance_to(at) < best.distance_to(at):
			best = d
	return best


## Durakta biri iner (koltuğu boşalır), bazen yeni biri biner.
func _station_shuffle() -> void:
	if randf() < LEAVE_CHANCE:
		var taken: Array = []
		for i in _seat_pos.size():
			if _seats[i] != null and _seats[i] != _player:
				taken.append(i)
		if not taken.is_empty():
			var i: int = taken.pick_random()
			var leaver = _seats[i]
			_seats[i] = null
			_say(leaver, "İnecek var!")
			var door := _nearest_door(leaver.position)
			var aisle := Vector2(_seat_pos[i].x, AISLE_Y)
			var tw := create_tween()
			tw.tween_interval(0.3)
			tw.tween_method(func(t: float):
				leaver.position = _seat_pos[i].lerp(aisle, t)
				leaver.set_moving(true, 0.0, aisle.y - _seat_pos[i].y), 0.0, 1.0, 0.25)
			tw.tween_method(func(t: float):
				leaver.position = aisle.lerp(door, t)
				leaver.set_moving(true, door.x - aisle.x, door.y - aisle.y), 0.0, 1.0, clampf(aisle.distance_to(door) / 70.0, 0.3, 2.0))
			tw.tween_property(leaver, "modulate:a", 0.0, 0.25)
			tw.tween_callback(leaver.queue_free)
			_schedule_grab(i, 1.6)   # sen kapmazsan biri kapar
	if _wheelchair.is_empty() and randf() < 0.12:
		_add_wheelchair()
	elif not _wheelchair.is_empty() and randf() < 0.2:
		_say(_wheelchair[0], "İnecek var, rampayı açar mısınız?")
		_remove_wheelchair()
	_crowd_for_time()
	if _standing.size() < _standing_target:
		var door: Vector2 = _doors.pick_random()
		var spot := _standing_spot()
		var p = _add_standing(door)
		var tw := create_tween()
		tw.tween_method(func(t: float):
			p.position = door.lerp(spot, t)
			p.set_moving(t < 1.0, spot.x - door.x, spot.y - door.y), 0.0, 1.0, 0.8)


func _event(e: Dictionary) -> void:
	if not e.has("rivals"):
		var popup := _neutral_popup(e["title"])
		popup.add_line(e["text"])
		var m: int = e.get("money", 0)
		if m < 0 and GameState.money < -m:
			popup.add_line("...ama paran yetmedi.", 9, Color(1, 1, 1, 0.6))
			m = 0
		if m != 0:
			GameState.money += m
			popup.add_line("%+d TL" % m, 11, Color("4ade80") if m > 0 else Color("ff6a4a"))
			GameState.save_game()
		popup.add_choice("Devam", "ok")
		_open(popup)
		return

	var id: String = e["rivals"].pick_random()
	var popup := ChoicePopup.new()
	popup.set_rival(id)
	popup.add_line(e["title"].to_upper(), 10, Color("ff9a7a"))
	popup.add_line(e["text"].replace("{r}", GameState.rival(id)["name"]))
	popup.add_line("\"%s\"" % GameState.rival_line(id, "laf"), 10, Color(1, 1, 1, 0.8))
	popup.add_scared_note(id)
	popup.add_rival_choices(id, e["fight"])
	popup.add_choice(e["avoid"], "avoid")
	_open(popup, func(choice: String):
		match choice:
			"fight":
				GameState.fight_rival = id
				GameState.fight_venue = e["bg"]
				GameState.fight_seat_stake = e.get("seat", "")
				GameState.save_game()
				GameState.go_to(GameState.SCENE_FIGHT)
				return false
			"intimidate":
				GameState.intimidate(id)
				if e.get("seat", "") == "gain":
					GameState.metro_seated = true
				_center_text("+%d TL  (gözdağı)" % GameState.intimidate_reward(id))
			"avoid":
				if e.get("avoid_effect", "") == "stand":
					GameState.metro_seated = false
					_give_seat_to(id)
		_refresh_player()
		return true)


## Yerini verdin: kalkarsın ve yer isteyen kişi koltuğa oturur.
func _give_seat_to(rival_id: String) -> void:
	var seat: int = _seats.find(_player)
	if seat < 0:
		return
	_stand_player()
	var p = _person(GameState.rival(rival_id)["look"], _seat_pos[seat])   # yer isteyen oturur
	p.sit("right")
	_seats[seat] = p
	_say(p, GameState.rival(rival_id)["lines"].get("thanks", ["Sağ ol, çok iyisin."]).pick_random())


func _neutral_popup(title: String) -> ChoicePopup:
	var popup := ChoicePopup.new()
	popup.portrait = GameState.portrait_texture(GameState.player_look())
	popup.title = title
	return popup


## Pencereyi açar. on_choice false dönerse yolculuk devam etmez (ör. dövüşe gidiliyor).
func _open(popup: ChoicePopup, on_choice: Callable = Callable()) -> void:
	_phone.close()
	_popup_open = true
	_player.set_moving(false)
	var was_riding := _riding
	_riding = false
	_speed = 0.0
	_ui.add_child(popup)
	popup.chosen.connect(func(choice: String):
		var resume := true
		if on_choice.is_valid():
			resume = on_choice.call(choice)
		popup.queue_free()
		_popup_open = false
		if resume:
			if was_riding:
				_riding = true
			elif _t == 0.0:
				_depart())


func _leave(path: String) -> void:
	_riding = false
	set_physics_process(false)
	GameState.save_game()
	GameState.go_to(path)


func _center_text(text: String) -> void:
	var l := GameState.make_label(text, 20, Color("e6b428"))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 120)
	l.size = Vector2(480, 30)
	_ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_trip_card)
	_ui.add_child(_hud)
	_line_map = Control.new()
	_line_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_map.draw.connect(_draw_line_map)
	_hud.add_child(_line_map)
	_goal_label = GameState.make_label("", 8)
	_goal_label.position = Vector2(26, 224)
	_hud.add_child(_goal_label)
	_money_label = GameState.make_label("", 7, UIDraw.TEXT_DIM)
	_money_label.position = Vector2(26, 235)
	_hud.add_child(_money_label)
	_hint = HintBar.new()
	_hint.default_text = "WASD: yürü · E: otur / laf at · T: telefon · Esc: menü"
	_ui.add_child(_hint)


func _update_hud() -> void:
	var hint := ""
	if not _popup_open and not _phone.is_open():
		if _seats.has(_player):
			hint = "Oturuyorsun · yürürsen kalkarsın"
		elif _free_seat_near(_player.position) >= 0:
			hint = "E: Otur"
		elif _nearest_standing() != null:
			hint = "E: Laf at (%s)" % GameState.rival(_nearest_standing().look)["name"]
	_hint.text = hint
	var dest := "Okula (Davutpaşa)" if GameState.metro_dir > 0 else "Eve (Beylikdüzü)"
	var left := absi((MetroEvents.STATIONS.size() - 1 if GameState.metro_dir > 0 else 0) - GameState.metro_station)
	_goal_label.text = "%s · %d durak · ~%d dk" % [dest, left, int(left * Places.METRO_MINUTES_PER_STOP)]
	_money_label.text = ("Oturuyorsun, dinleniyorsun (+%.1f enerji / durak)" % Places.SEATED_ENERGY_PER_STOP) if GameState.metro_seated \
			else ("Ayaktasın, yoruluyorsun (-%.1f enerji / durak)" % Places.STANDING_ENERGY_PER_STOP)


## Alt soldaki yolculuk kartı: oturma durumu simgesi, hedef ve kalan durak.
func _draw_trip_card() -> void:
	var r := Rect2(4, 220, 236, 28)
	var seated := GameState.metro_seated
	var col := Color("4ade80") if seated else Color("f59e0b")
	UIDraw.card(_hud, r, col)
	UIDraw.box(_hud, Rect2(9, 225, 13, 18), Color(col, 0.25), Color(col, 0.7), 3)
	if seated:   # koltuk simgesi
		_hud.draw_rect(Rect2(12, 228, 3, 11), col); _hud.draw_rect(Rect2(12, 235, 8, 3), col); _hud.draw_rect(Rect2(18, 238, 2, 3), col)
	else:        # ayakta: tutunma kolu
		_hud.draw_rect(Rect2(15, 227, 2, 4), col); _hud.draw_circle(Vector2(16, 233), 2.5, col); _hud.draw_rect(Rect2(14, 236, 4, 6), col)


# ---------------------------------------------------------------- Çizim

## Vagonun dışı: asfalt ve şeritler hızla akar, durağa yaklaşırken peron sağdan kayarak gelir.
func _draw_outside() -> void:
	var night := Lighting.is_dark()
	var asphalt := Color("23242c") if night else Color("3a3c44")
	_outside.draw_rect(Rect2(-40, -60, 900, 340), asphalt)
	var shift := fposmod(_scroll, 60.0)
	for x in range(-60, 880, 60):
		var lx := roundf(x - shift)
		_outside.draw_rect(Rect2(lx, 24, 30, 2), Color("e8e4d0"))      # karşı şerit çizgisi
		_outside.draw_rect(Rect2(lx + 10, 206, 30, 2), Color("e8e4d0"))
	# ortadaki beton bariyer (üstte)
	var bshift := fposmod(_scroll, 24.0)
	_outside.draw_rect(Rect2(-40, 0, 900, 10), Color("a8afbf"))
	for x in range(-24, 860, 24):
		_outside.draw_rect(Rect2(roundf(x - bshift), 0, 12, 10), Color("80889c"))
	# camlardan görünen şehir: gökyüzü ve akan binalar (karşı taraf)
	_outside.draw_rect(Rect2(0, 46, 800, 32), Color("1b2440") if night else Color("93c2ea"))
	for b in _city:
		var x := roundf(fposmod(b.position.x - _scroll * 0.5, 900.0) - 60.0)
		var col := Color("2a2f4a") if night else Color("6d7f99").lerp(Color("8a9ab0"), b.size.y)
		_outside.draw_rect(Rect2(x, 78 - b.position.y, b.size.x, b.position.y), col)
		if night:
			for wy in range(int(80 - b.position.y), 76, 5):
				_outside.draw_rect(Rect2(x + 3, wy, 2, 2), Color("ffd27a"))
	# peronlar: geride kalan (kalkışta) ve yaklaşan (yanaşırken)
	if _riding or _t > 0.0:   # yolda (ya da yolda bir pencere açıkken)
		var gone := _traveled(_t)
		_draw_platform(PLATFORM_X - gone, GameState.metro_station)
		_draw_platform(PLATFORM_X + STOP_GAP - gone, _next_station())
	else:
		_draw_platform(PLATFORM_X, GameState.metro_station)


## Durak peronu: beton, sarı kenar çizgisi, direkler, durak tabelaları, bekleyenlerin gölgeleri.
func _draw_platform(x0: float, station: int) -> void:
	x0 = roundf(x0)
	if x0 > 860.0 or x0 + PLATFORM_LEN < -40.0 or station < 0 or station >= MetroEvents.STATIONS.size():
		return
	_outside.draw_rect(Rect2(x0, 186, PLATFORM_LEN, 70), Color("a8a49c"))
	_outside.draw_rect(Rect2(x0, 186, PLATFORM_LEN, 5), Color("e6b428"))
	for k in range(4, int(PLATFORM_LEN), 6):
		_outside.draw_rect(Rect2(x0 + k, 188, 2, 1), Color("c08f26"))
	for k in range(0, int(PLATFORM_LEN), 32):
		_outside.draw_rect(Rect2(x0 + k, 191, 1, 40), Color("8a867e"))
	_outside.draw_rect(Rect2(x0, 186, 4, 70), Color("6a665e"))
	_outside.draw_rect(Rect2(x0 + PLATFORM_LEN - 4, 186, 4, 70), Color("6a665e"))
	var font := ThemeDB.fallback_font
	var name: String = MetroEvents.STATIONS[station]
	for k in [140.0, 520.0]:
		_outside.draw_rect(Rect2(x0 + k, 214, 120, 14), Color("1b2a52"))
		_outside.draw_rect(Rect2(x0 + k, 226, 120, 2), Color("e6b428"))
		_outside.draw_string(font, Vector2(x0 + k, 224), name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 7, Color.WHITE)
	for k in range(60, int(PLATFORM_LEN), 160):
		_outside.draw_rect(Rect2(x0 + k, 196, 6, 40), Color("80889c"))
		_outside.draw_rect(Rect2(x0 + k, 196, 2, 40), Color("a8afbf"))
	var rng := RandomNumberGenerator.new()   # bekleyen yolcular (kafalar, üstten)
	rng.seed = station * 31
	for k in 14:
		var px := x0 + rng.randf_range(20, PLATFORM_LEN - 20)
		var py := rng.randf_range(196, 210)
		_outside.draw_circle(Vector2(px, py + 2), 4, Color(0, 0, 0, 0.18))
		_outside.draw_circle(Vector2(px, py), 3.5, [Color("2a201c"), Color("6b4530"), Color("c8c8cc"), Color("8a3a5a")][k % 4])


## Kayan kapı kanatları (yakın taraftaki duvarda).
func _draw_doors() -> void:
	var slide := 16.0 * _door_open
	for d in _doors:
		var x: float = d.x
		for side in [-1.0, 1.0]:
			var inner: float = x + side * slide
			var r := Rect2(minf(inner, inner + side * 17.0), 168, 17, 16)
			_doors_fx.draw_rect(r, Color("c8ccd4"))
			_doors_fx.draw_rect(Rect2(r.position.x + 3, 170, 11, 7), Color("3a5070"))
			_doors_fx.draw_rect(Rect2(r.position.x, 168, 17, 1), Color("e8ecf2"))
			_doors_fx.draw_rect(Rect2(inner - (1.0 if side < 0 else 0.0), 168, 1, 16), Color("5c6270"))
		if _door_open > 0.5:   # açık kapıdan peron görünür, ışık yanar
			_doors_fx.draw_rect(Rect2(x - 2, 166, 4, 2), Color("4ade80"))


## Üst şerit: hat numarası, hat çizgisi (geçilen duraklar dolu), duraklar, hareket eden metrobüs, hedef bilgisi.
func _draw_line_map() -> void:
	var font := ThemeDB.fallback_font
	_line_map.draw_rect(Rect2(0, 0, 480, 36), Color("101a36"))
	_line_map.draw_rect(Rect2(0, 0, 480, 18), Color(1, 1, 1, 0.03))
	_line_map.draw_rect(Rect2(0, 35, 480, 1), UIDraw.GOLD)
	UIDraw.box(_line_map, Rect2(5, 5, 28, 13), Color("c8102e"), Color(0, 0, 0, 0), 3)
	_line_map.draw_string(font, Vector2(5, 14.5), "34BZ", HORIZONTAL_ALIGNMENT_CENTER, 28, 7, Color.WHITE)
	var cur := GameState.metro_station
	var dir := GameState.metro_dir
	var k_move := clampf(_traveled(_t) / STOP_GAP, 0.0, 1.0) if _riding else 0.0
	var y := 26.0
	_line_map.draw_rect(Rect2(40, y - 1, 400, 3), Color(1, 1, 1, 0.18))
	_line_map.draw_rect(Rect2(40, y - 1, 200 + 100.0 * k_move, 3), Color(UIDraw.GOLD, 0.85))
	for k in range(-1, 3):   # bir önceki, şimdiki ve sonraki iki durak
		var idx := cur + k * dir
		if idx < 0 or idx >= MetroEvents.STATIONS.size():
			continue
		var x := 240.0 + k * 100.0
		var passed := k < 0 or (k == 0)
		var is_cur := k == 0 and not _riding
		_line_map.draw_circle(Vector2(x, y + 0.5), 5.5 if is_cur else 4.0, Color("101a36"))
		_line_map.draw_circle(Vector2(x, y + 0.5), 4.5 if is_cur else 3.0, UIDraw.GOLD if passed else Color(1, 1, 1, 0.8))
		if is_cur:
			_line_map.draw_circle(Vector2(x, y + 0.5), 2.0, Color.WHITE)
		var name: String = MetroEvents.STATIONS[idx]
		var col := UIDraw.GOLD if k == 0 else (Color(1, 1, 1, 0.45) if k < 0 else Color(1, 1, 1, 0.8))
		if k == 0:
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 12.0
			UIDraw.box(_line_map, Rect2(x - w / 2.0, 5, w, 12), Color(UIDraw.GOLD, 0.15), Color(UIDraw.GOLD, 0.6), 6)
		_line_map.draw_string(font, Vector2(x - 50, 14), name, HORIZONTAL_ALIGNMENT_CENTER, 100, 8, col)
	# hareket eden metrobüs işareti
	var bx := roundf(240.0 + 100.0 * k_move)
	UIDraw.box(_line_map, Rect2(bx - 8, y - 5, 16, 9), Color("f4f4f6"), Color(0, 0, 0, 0), 2)
	_line_map.draw_rect(Rect2(bx - 8, y + 1, 16, 2), Color("c8102e"))
	_line_map.draw_rect(Rect2(bx - 6, y - 3, 12, 3), Color("2b3a55"))
