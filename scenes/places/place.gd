extends Node2D
## Mekan (Ev, Market, Gym, Çarşı, Kampüs Kafe, Galeri), 3/4 üstten bakış: içinde dört yöne yürünür.
## Yetkiliyle konuşunca ya da bir eşyaya/alete gidince küçük bir diyalog kutusunda seçenekler çıkar.
## Gym aletlerinde karakter animasyonla çalışır, stat baloncukları üstteki rozete uçar.
## Mekanın verisi data/places.gd, çizimi tools/make_rooms.py (aynı id).

const Places = preload("res://data/places.gd")
const Cars = preload("res://data/cars.gd")
const Person = preload("res://scenes/metro/person.gd")
const StatusBar = preload("res://scenes/ui/status_bar.gd")
const Phone = preload("res://scenes/ui/phone.gd")
const DialogBox = preload("res://scenes/ui/dialog_box.gd")
const Shop = preload("res://data/shop.gd")
const PAGE_SIZE := 5          # uzun listelerde (mağaza, gardırop) bir sayfadaki seçenek

const WALK_SPEED := 70.0
const REACH := 16.0
const TRAIN_SECONDS := 2.4
const STAT_BUBBLES := 6
const DIRS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
## Işıklar: [dış mekan mı, yarıçap, gündüz de yansın mı]. Lamba yerleri oda verisinde.
const LIGHTS := {
	"ev": [false, 110.0, false],
	"market": [false, 120.0, true],
	"gym": [false, 100.0, true],
	"carsi": [true, 90.0, false],
	"galeri": [false, 100.0, true],
	"kampus_kafe": [false, 90.0, true],
	"butik": [false, 100.0, true],
	"hirdavat": [false, 100.0, true],
}
## Spotun tıklama alanı hangi eşyanın görseli (işaret adı -> [eşya, kaçıncısı]); yoksa duruş noktasından hesaplanır.
const SPOT_PROPS := {
	"desk": ["desk_laptop", 0], "bed": ["bed", 0], "wardrobe": ["wardrobe", 0], "fridge": ["fridge", 0], "water": ["water_cooler", 0],
	"lift_0": ["squat_rack", 0], "lift_1": ["squat_rack", 1], "run_0": ["tm_console", 0], "run_1": ["tm_console", 1],
	"run_2": ["tm_console", 2], "bag_0": ["bag", 0], "bag_1": ["bag", 1],
}
const COACH_LINES := ["Bir tane daha!", "Nefesini kontrol et!", "Yavaş, kontrollü!", "Aferin, devam!", "Bırakmak yok!"]

## Üstteki rozete uçan küçük stat baloncuğu.
class StatBubble extends Node2D:
	var color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6, Color("1b1024"))
		draw_circle(Vector2.ZERO, 5, color)
		draw_rect(Rect2(-3, -0.5, 6, 1.5), Color.WHITE)
		draw_rect(Rect2(-0.75, -3, 1.5, 6), Color.WHITE)


var _id := "ev"
var _data: Dictionary
var _room: Room
var _spots: Array = []        # data'daki spotların kopyası; "pos" (duruş noktası), npc'lerde "node", aletlerde "user_node"
var _player
var _ui: CanvasLayer
var _bar
var _phone
var _hint: HintBar
var _dialog_open := false
var _busy := false            # eylem/antrenman sürüyor
var _walk_goal := Vector2(-1, -1)   # tıklanan yere yürüme
var _walk_then := -1          # vardığında etkileşilecek spot
var _hover := -1
var _anim := ""               # oyuncunun antrenman animasyonu
var _anim_t := 0.0
var _anim_spot := -1
var _clock_overlay: Control
var _clock_text := ""
var _clock_t := 0.0
var _time := 0.0
var _floor_fx: Node2D         # zemine çizilen hareketli parçalar (koşu bandı, rafta duran halter)
var _top: Node2D              # en üstte: fareyle gelinen şeyin çerçevesi ve adı


func _ready() -> void:
	_id = GameState.open_place
	_data = Places.PLACES[_id]
	GameState.place = _data.get("parent", _id)   # dükkanların içi: haritada çarşı

	_room = Room.new().build(_id)
	add_child(_room)
	_floor_fx = Node2D.new()
	_floor_fx.draw.connect(_draw_floor_fx)
	_room.floor_layer.add_child(_floor_fx)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	_room.top_layer.add_child(_top)

	for s in _data["spots"]:
		var spot: Dictionary = s.duplicate()
		spot["pos"] = _room.mark(spot["at"])
		if spot["kind"] == "npc":
			var p = _person(spot["look"], _room.mark(spot["stand"]))
			if spot.get("sit", false):
				p.sit(spot.get("face", "down"))
			else:
				p.face_dir(spot.get("face", "down"))
				_room.add_blocker(p)   # içinden geçilmesin
			spot["node"] = p
		elif spot["kind"] == "machine" and spot.has("user"):
			var u = _person(spot["user"], spot["pos"])
			_room.add_blocker(u)
			spot["user_node"] = u
		_spots.append(spot)
	for e in _data.get("extras", []):
		var p = _person(e[0], _room.mark(e[1]))
		if e[3]:
			p.sit(e[2])
		else:
			p.face_dir(e[2])
			_room.add_blocker(p)

	var fill := _add_crowd()

	var spawn := GameState.place_spawn if _room.has_mark(GameState.place_spawn) else "spawn"
	GameState.place_spawn = ""
	_player = _person(GameState.player_look(), _room.mark(spawn))
	_player.face_dir("up")
	_player.marker = _id == "gym" or _id == "carsi"
	_room.follow(_player)
	if _id == "ev" and not Lighting.is_dark():
		_dust()
	var light: Array = LIGHTS[_id]
	Lighting.apply(self, light[0], _room.lamps(), light[1], light[2])

	_ui = CanvasLayer.new()
	add_child(_ui)
	_bar = StatusBar.new()
	_ui.add_child(_bar)
	var crowd := ""
	if fill >= 0.0:
		crowd = "  ·  " + ("sakin" if fill < 0.4 else "orta kalabalık" if fill < 0.7 else "tıklım tıklım")
	var title := GameState.make_label(_data["name"] + crowd, 11, Color("e6b428"))
	title.position = Vector2(4, 25)
	UIDraw.pill(title)
	_ui.add_child(title)
	_hint = HintBar.new()   # alt bilgi şeridi
	_hint.default_text = "WASD: yürü · E: konuş / kullan · T: telefon · Esc: çık"
	_ui.add_child(_hint)
	_clock_overlay = Control.new()
	_clock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_overlay.draw.connect(_draw_clock)
	_ui.add_child(_clock_overlay)
	_phone = Phone.new()
	_ui.add_child(_phone)
	_test_shortcuts()


## Mekanın müşterileri (oda verisinde crowd_seats / crowd_stand varsa): her girişte doluluk rastgele.
## Doluluk oranını döndürür (-1: kalabalık yok).
func _add_crowd() -> float:
	var seats: Array = _room.points("crowd_seats")
	var stands: Array = _room.points("crowd_stand")
	if seats.is_empty() and stands.is_empty():
		return -1.0
	var fill := _crowd_level()
	var taken: Array = []
	for s in _spots:
		if s.has("node"):
			taken.append(s["node"].position)
	for e in _data.get("extras", []):
		taken.append(_room.mark(e[1]))
	for it in seats:
		var at := Vector2(it[0], it[1])
		if taken.any(func(t): return t.distance_to(at) < 6.0) or randf() > fill:
			continue
		var p = _person(GameState.MetroEvents.random_look(), at)
		p.sit(it[2])
	for at in stands:
		if randf() < fill * 0.7:
			var p = _person(GameState.MetroEvents.random_look(), at)
			p.face_dir(["up", "left", "right"].pick_random())
			_room.add_blocker(p)
	return fill


## Doluluk: saate göre (sabah sakin, öğle tıklım tıklım, akşam azalır), hafta sonu kampüs boş; biraz da şans.
func _crowd_level() -> float:
	var h := GameState.minute / 60.0
	var base := 0.12
	if h >= 8.0 and h < 11.0:
		base = 0.35
	elif h >= 11.0 and h < 14.0:
		base = 0.8
	elif h >= 14.0 and h < 17.0:
		base = 0.55
	elif h >= 17.0 and h < 20.0:
		base = 0.35
	elif h >= 20.0 and h < 23.0:
		base = 0.2
	if GameState.weekday() >= 5 and _id == "kampus_kafe":
		base *= 0.4
	return clampf(base + randf_range(-0.12, 0.12), 0.05, 0.95)


func _person(look: String, at: Vector2):
	var p := Person.new()
	p.look = look
	p.position = at
	_room.add_actor(p)
	return p


## Test kısayolları: -- --do=gym_day,lift (eylemleri sırayla yapar), --talk=1 (o spotla konuşur)
func _test_shortcuts() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--talk="):
			await get_tree().create_timer(0.3).timeout
			_interact(int(arg.trim_prefix("--talk=")))
		if arg.begins_with("--do="):
			for id in arg.trim_prefix("--do=").split(","):
				await get_tree().create_timer(0.3).timeout
				var a := _action(id)
				if a.has("train"):
					var m := _free_machine(id)
					if m >= 0:
						await _train(m)
				elif not a.is_empty():
					await _perform(a)


func _action(id: String) -> Dictionary:
	for a in _data["actions"]:
		if a["id"] == id:
			return a
	return {}


func _free_machine(action_id: String) -> int:
	for i in _spots.size():
		if _spots[i]["kind"] == "machine" and _spots[i]["action"] == action_id and not _spots[i].has("user"):
			return i
	return -1


## Bir eşyanın ekrandaki görsel sınırı.
func _prop_rect(key: String, idx: int) -> Rect2:
	var list: Array = _room.props.get(key, [])
	if idx >= list.size():
		return Rect2()
	var sp: Sprite2D = list[idx]
	return Rect2(sp.position + sp.offset + Vector2(1, 1), sp.texture.get_size() - Vector2(2, 2))


## Fareyle seçilebilen alan: kişinin ya da eşyanın kendi görseli.
func _spot_rect(i: int) -> Rect2:
	var s: Dictionary = _spots[i]
	var pos: Vector2 = s["pos"]
	var body := Rect2(pos - Vector2(8, 30), Vector2(16, 32))
	if s.has("prop"):
		return _prop_rect(s["prop"], 0)
	match s["kind"]:
		"npc":
			var n: Node2D = s["node"]
			return Rect2(n.position + Vector2(-8, n.head_y() - 1), Vector2(16, -n.head_y() + 2))
		"car":
			return _prop_rect("carfront_" + s["car"], 0)
		"machine":
			var pr := _prop_rect(SPOT_PROPS[s["at"]][0], SPOT_PROPS[s["at"]][1])
			return body.merge(pr) if pr.has_area() else body
		"exit":
			return Rect2(pos - Vector2(16, 14), Vector2(32, 16))
	if SPOT_PROPS.has(s["at"]):
		return _prop_rect(SPOT_PROPS[s["at"]][0], SPOT_PROPS[s["at"]][1])
	var c: Vector2 = pos + DIRS[s.get("dir", "up")] * 14.0 + Vector2(0, -12)
	return Rect2(c - Vector2(14, 14), Vector2(28, 28))


func _can_control() -> bool:
	return not _busy and not _dialog_open and not _phone.is_open()


# ---------------------------------------------------------------- Hareket ve etkileşim

func _process(delta: float) -> void:
	_time += delta
	if _can_control():
		var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
		if dir != Vector2.ZERO:
			_walk_goal = Vector2(-1, -1)
			_walk_then = -1
			_room.walk(_player, dir, WALK_SPEED, delta)
		elif _walk_goal.x >= 0.0:
			if _room.walk_to(_player, _walk_goal, WALK_SPEED, delta):
				_walk_goal = Vector2(-1, -1)
				if _walk_then >= 0:
					var i := _walk_then
					_walk_then = -1
					if _player.position.distance_to(_spots[i]["pos"]) < REACH:
						_interact(i)
		else:
			_player.set_moving(false)
		# kapıdan çıkınca haritaya dön
		var exit_pos: Vector2 = _spots[0]["pos"]
		if _player.position.distance_to(exit_pos) < 8.0 and not _spots[0].has("actions"):
			_exit(_spots[0])
	_update_hover()
	_update_hint()
	_animate(delta)
	_clock_overlay.queue_redraw()
	_floor_fx.queue_redraw()
	_top.queue_redraw()


func _update_hover() -> void:
	var before := _hover
	_hover = -1
	if _can_control():
		var m := get_global_mouse_position()
		for i in _spots.size():
			if _spot_rect(i).has_point(m):
				_hover = i
	if (_hover >= 0) != (before >= 0):   # tıklanabilir bir şeyin üstünde el imleci
		GameState.set_hand_cursor(_hover >= 0)


func _exit_tree() -> void:
	GameState.set_hand_cursor(false)


func _nearest_spot() -> int:
	var best := -1
	var best_d := REACH
	for i in _spots.size():
		var d: float = _player.position.distance_to(_spots[i]["pos"])
		if d < best_d:
			best = i
			best_d = d
	return best


func _item_info(s: Dictionary) -> Dictionary:
	return (Shop.OUTFITS if s["shop"] == "outfits" else Shop.WEAPONS)[s["item"]]


func _item_owned(s: Dictionary) -> bool:
	return (GameState.outfits_owned if s["shop"] == "outfits" else GameState.weapons_owned).has(s["item"])


func _spot_name(s: Dictionary) -> String:
	if s["kind"] == "item":
		return _item_info(s)["name"]
	if s["kind"] == "car":
		return Cars.CARS[s["car"]]["name"]
	return s["name"]


func _update_hint() -> void:
	var text := ""
	if _can_control():
		var i := _nearest_spot()
		if i >= 0:
			var s: Dictionary = _spots[i]
			var verb: String = {"npc": "konuş", "exit": "çık", "machine": "çalış", "car": "incele", "object": "bak",
					"door": "gir", "item": "incele"}[s["kind"]]
			text = "E: %s (%s)" % [verb.capitalize(), _spot_name(s)]
		else:
			text = ""   # boşken kontroller görünür
	_hint.text = text


func _unhandled_input(event: InputEvent) -> void:
	if not _can_control():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			_go_interact(_hover)
		else:
			_walk_goal = get_global_mouse_position()
			_walk_then = -1
	elif event.is_action_pressed("interact"):
		var i := _nearest_spot()
		if i >= 0:
			_interact(i)
	elif event.is_action_pressed("back"):
		_interact(0)   # ilk spot her zaman çıkış


func _go_interact(i: int) -> void:
	if _player.position.distance_to(_spots[i]["pos"]) < 4.0:
		_interact(i)
	else:
		_walk_goal = _spots[i]["pos"]
		_walk_then = i


func _interact(i: int) -> void:
	var s: Dictionary = _spots[i]
	_player.set_moving(false)
	match s["kind"]:
		"npc":
			_player.face_point(s["node"].position)
		"car":
			_player.face_dir("up")
		"object":
			_player.face_dir(s.get("dir", "up"))
	match s["kind"]:
		"exit":
			if s.has("actions"):
				_open_dialog(s, i)
			else:
				_exit(s)
		"machine":
			if s.has("user"):
				_say(_player, "Dolu, boş bir alet bulayım.")
				return
			var why: String = GameState.action_block_reason(_action(s["action"]))
			if why != "":
				var coach = _coach()
				_say(coach if coach else _player, why)
				return
			_train(i)
		"car":
			_car_dialog(s)
		"door":
			_busy = true
			GameState.save_game()
			GameState.open_place_scene(s["to"])
		"item":
			_player.face_dir("up")
			_item_dialog(s)
		_:
			if s.has("shop"):
				_open_shop(s, 0)
			elif s.get("wardrobe", false):
				_open_wardrobe(s, 0)
			else:
				_open_dialog(s, i)


func _coach():
	for s in _spots:
		if s["kind"] == "npc" and s["name"] == "Hoca Rıza":
			return s["node"]
	return null


func _say(who: Node2D, text: String, seconds: float = 2.4) -> void:
	Bubble.say(self, who, text, 34.0, seconds)


## Çıkış: dükkanlardan çarşıya (kapının önünde), diğerlerinden haritaya.
func _exit(s: Dictionary) -> void:
	if not s.has("to"):
		_leave()
		return
	if _busy:
		return
	_busy = true
	GameState.place_spawn = s.get("spawn", "")
	GameState.save_game()
	GameState.open_place_scene(s["to"])


func _leave() -> void:
	if _busy:
		return
	_busy = true
	GameState.save_game()
	GameState.go_to(GameState.SCENE_MAP)


# ---------------------------------------------------------------- Diyaloglar

## Kısa seçenek yazısı: "Kaşarlı tost  (20 dk, +30 tokluk, -30 TL)" ya da "... (Paran yetmiyor)".
func _choice_text(a: Dictionary, why: String) -> String:
	if why != "":
		return "%s  (%s)" % [a["name"], why]
	var parts: Array = []
	var t: int = a.get("time", 0)
	if t > 0:
		parts.append("%d sa" % (t / 60) if t % 60 == 0 else ("%d dk" % t if t < 60 else "%d sa %d dk" % [t / 60, t % 60]))
	for key in [["energy", "enerji"], ["food", "tokluk"]]:
		var v: int = a.get(key[0], 0)
		if v != 0:
			parts.append("%+d %s" % [v, key[1]])
	var m: int = a.get("money", 0)
	if m != 0:
		parts.append("%+d TL" % m)
	if parts.is_empty() and a.has("desc"):
		parts.append(a["desc"])
	return a["name"] + ("  (%s)" % ", ".join(parts) if not parts.is_empty() else "")


func _open_dialog(s: Dictionary, _i: int) -> void:
	var d := DialogBox.new()
	d.speaker = _spot_name(s)
	d.line = s.get("lines", [""]).pick_random()
	if s.has("look"):
		d.portrait = GameState.portrait_texture(s["look"])
	for id in s.get("actions", []):
		var a := _action(id)
		if a.is_empty() or GameState.action_hidden(a):
			continue
		var why: String = GameState.action_block_reason(a)
		d.add_choice(_choice_text(a, why), id, why != "")
	if _id == "galeri" and s["kind"] == "npc":
		d.add_choice("Arabamı yönet (yükselt, tamir, sat)", "garage", GameState.cars.is_empty())
		if GameState.has_car():
			d.add_choice("Trafiğe çık", "traffic", GameState.car()["damage"] >= GameState.car_max_hp())
	_show_dialog(d, _on_pick.bind(s))


func _on_pick(id: String, s: Dictionary) -> void:
	match id:
		"close":
			pass
		"garage":
			_busy = true
			GameState.go_to(GameState.SCENE_GARAGE)
		"traffic":
			_busy = true
			GameState.save_game()
			GameState.go_to(GameState.SCENE_TRAFFIC)
		_:
			await _perform(_action(id), s.get("node"))


## Sayfalı seçim kutusu: choices = [[yazı, id, kapalı mı]], fazlası "Diğerleri" ile sonraki sayfada.
func _paged_dialog(speaker: String, line: String, choices: Array, page: int, on_pick: Callable, reopen: Callable,
		portrait: Texture2D = null) -> void:
	var d := DialogBox.new()
	d.speaker = speaker
	d.line = line
	d.portrait = portrait
	var pages := maxi(1, ceili(choices.size() / float(PAGE_SIZE)))
	page = clampi(page, 0, pages - 1)
	for c in choices.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE):
		d.add_choice(c[0], c[1], c[2])
	if pages > 1:
		d.add_choice("Diğerleri ›  (%d/%d)" % [page + 1, pages], "page")
	_show_dialog(d, func(id: String):
		if id == "page":
			reopen.call((page + 1) % pages)
		elif id != "close":
			on_pick.call(id))


## Askıdaki kıyafet ya da panodaki silah: incele, satın al, hemen giy / çantaya koy.
func _item_dialog(s: Dictionary) -> void:
	var it := _item_info(s)
	var id: String = s["item"]
	var outfits: bool = s["shop"] == "outfits"
	var price := GameState.shop_price(it["price"])
	var d := DialogBox.new()
	d.speaker = "%s  ·  %d TL" % [it["name"], price] + ("  (Pazarlıkçı indirimi)" if price < it["price"] else "")
	d.line = it["desc"] if outfits else "%s  Yumruk hasarı x%.2f%s." % [it["desc"], it["damage"],
			", menzil +%d" % it["range"] if it["range"] > 0 else ""]
	if _item_owned(s):
		if outfits:
			d.add_choice("Hemen giy" if GameState.outfit != id else "Zaten üzerinde", "wear", GameState.outfit == id)
		else:
			d.add_choice("Çantaya koy" if GameState.weapon != id else "Zaten çantanda", "arm", GameState.weapon == id)
	else:
		var poor: bool = GameState.money < price
		d.add_choice("Satın al  (%d TL)" % price if not poor else "Paran yetmiyor  (%d TL)" % price, "buy", poor)
		if outfits:
			d.add_choice("Satın al ve hemen giy", "buy_wear", poor)
	_show_dialog(d, _on_item_pick.bind(s))


func _on_item_pick(choice: String, s: Dictionary) -> void:
	var it := _item_info(s)
	var id: String = s["item"]
	var outfits: bool = s["shop"] == "outfits"
	match choice:
		"buy", "buy_wear":
			var ok := GameState.buy_outfit(id) if outfits else GameState.buy_weapon(id)
			if ok:
				Audio.sfx("buy")
				_say(_player, "%s benim oldu!" % it["name"], 2.0)
				if choice == "buy_wear":
					_wear(id)
		"wear":
			_wear(id)
		"arm":
			GameState.weapon = id
			GameState.save_game()
			_say(_player, "%s çantada." % it["name"])


func _wear(id: String) -> void:
	GameState.outfit = id
	GameState.save_game()
	_player.set_look(GameState.player_look())
	_say(_player, "Yakıştı mı? Bence yakıştı.")


## Butik (kıyafet) ya da hırdavat (silah): alınanlar gardıroba gelir.
func _open_shop(s: Dictionary, page: int) -> void:
	var items: Dictionary = Shop.OUTFITS if s["shop"] == "outfits" else Shop.WEAPONS
	var owned: Array = GameState.outfits_owned if s["shop"] == "outfits" else GameState.weapons_owned
	var choices: Array = []
	for id in items:
		var it: Dictionary = items[id]
		if it["price"] <= 0:
			continue
		var price := GameState.shop_price(it["price"])
		var text := "%s  (%d TL)  %s" % [it["name"], price, it["desc"]]
		if owned.has(id):
			text = "%s  (sende var)" % it["name"]
		elif GameState.money < price:
			text = "%s  (%d TL, paran yetmiyor)" % [it["name"], price]
		choices.append([text, id, owned.has(id) or GameState.money < price])
	_paged_dialog(_spot_name(s), s.get("lines", [""]).pick_random(), choices, page, func(id: String):
		var ok := GameState.buy_outfit(id) if s["shop"] == "outfits" else GameState.buy_weapon(id)
		if ok:
			Audio.sfx("buy")
			_say(s["node"], "Güle güle giy! Gardırobuna koydum." if s["shop"] == "outfits" else "Çantana koydum. Dikkatli ol evlat.")
			_say(_player, "+ %s" % items[id]["name"], 2.0), func(pg: int): _open_shop(s, pg),
			GameState.portrait_texture(s["look"]) if s.has("look") else null)


## Evdeki gardırop: kıyafet giy, çantaya silah koy ya da çıkar.
func _open_wardrobe(s: Dictionary, page: int) -> void:
	var choices: Array = []
	for id in GameState.outfits_owned:
		var on: bool = id == GameState.outfit
		choices.append(["%s%s" % [Shop.OUTFITS[id]["name"], "  (üzerinde)" if on else ""], "wear:" + id, on])
	for id in GameState.weapons_owned:
		var on: bool = id == GameState.weapon
		choices.append(["Çanta: %s%s" % [Shop.WEAPONS[id]["name"], "  (çantada)" if on else ""], "arm:" + id, on])
	if GameState.weapon != "":
		choices.append(["Silahı çantadan çıkar", "arm:", false])
	var line: String = "Butikten aldıkların burada. Çarşıdaki butik ve hırdavatçıya uğra." if choices.size() <= 1 else s.get("lines", [""]).pick_random()
	_paged_dialog("Gardırop", line, choices, page, func(id: String):
		if id.begins_with("wear:"):
			GameState.outfit = id.trim_prefix("wear:")
			_player.set_look(GameState.player_look())
			_say(_player, "Yakıştı mı? Bence yakıştı.")
		else:
			GameState.weapon = id.trim_prefix("arm:")
			_say(_player, "Çanta boş." if GameState.weapon == "" else "%s çantada. Kavgada işime yarar." % Shop.WEAPONS[GameState.weapon]["name"])
		GameState.save_game(), func(pg: int): _open_wardrobe(s, pg),
			GameState.portrait_texture(GameState.player_look()))


func _car_dialog(s: Dictionary) -> void:
	var id: String = s["car"]
	var info: Dictionary = Cars.CARS[id]
	var owned := GameState.cars.any(func(c): return c["id"] == id)
	var d := DialogBox.new()
	d.speaker = info["name"] + ("  (sende var)" if owned else "")
	d.line = "%s  Hız x%.2f, kaporta %d." % [info["desc"], info["speed"], info["hp"]]
	var price: int = info["price"]
	d.add_choice("Satın al  (%d TL)" % price if GameState.money >= price else "Satın al  (Paran yetmiyor: %d TL)" % price,
			"buy", GameState.money < price)
	_show_dialog(d, func(choice: String):
		if choice != "buy" or not GameState.try_spend(price):
			return
		GameState.cars.append(GameState._new_car(id))
		GameState.active_car = GameState.cars.size() - 1
		GameState.save_game()
		var dealer = _spots[1].get("node")
		_say(dealer if dealer else _player, "Hayırlı olsun abi! Anahtarlar sende."))


func _show_dialog(d, on_pick: Callable) -> void:
	_dialog_open = true
	_ui.add_child(d)
	d.picked.connect(func(id: String):
		_dialog_open = false
		on_pick.call(id))


# ---------------------------------------------------------------- Eylemler

## Gym dışı eylem: saat animasyonu, sonra sonuç baloncuğu.
func _perform(a: Dictionary, speaker = null) -> void:
	if a.has("scene"):
		# garsonluk, ders ve yemekhane kendi sahnelerinde oynanır
		_busy = true
		GameState.activity = a
		GameState.save_game()
		GameState.go_to(GameState.SCENE_WAITER if a["scene"] == "waiter" else GameState.SCENE_ACTIVITY)
		return
	_busy = true
	var minutes: float = a.get("time", 0)
	if a.get("effect", "") == "sleep":
		minutes = 9 * 60
	if a.get("effect", "") in ["sleep", "nap"]:
		_player.position = _room.mark("bed") + Vector2(-34, -6)   # yorganın altında
		_player.visible = false
		_say(_player, "Zzz...", 1.2)
	if minutes > 0:
		_clock_text = "%s..." % a["name"]
		_clock_t = 0.0
		var tw := create_tween()
		tw.tween_property(self, "_clock_t", 1.0, clampf(minutes / 120.0, 0.4, 1.2))
		await tw.finished
		_clock_text = ""
	var day_before: int = GameState.day
	var lines: Array = GameState.do_action(a)
	if GameState.day != day_before and a.get("effect", "") != "sleep":
		lines.append("Gece yarısı geçti!")
	if a.get("effect", "") in ["sleep", "nap"]:
		_player.position = _room.mark("bed")
		_player.visible = true
		_player.face_dir("down")
	_room.redraw_texts()
	if not lines.is_empty():
		_say(_player, "  ".join(lines), 2.6)
	elif speaker:
		_say(speaker, a.get("replies", ["Afiyet olsun!", "Buyur.", "Kolay gelsin!"]).pick_random(), 1.6)
	_busy = false


## Gym: alete yürü, çalış; baloncuklar üstteki stat rozetine uçup çubuğu doldurur.
func _train(i: int) -> void:
	var s: Dictionary = _spots[i]
	var a := _action(s["action"])
	var k: String = a["train"]
	_busy = true
	var stand: Vector2 = s["pos"]
	var from: Vector2 = _player.position
	var walk := create_tween()
	walk.tween_method(func(t: float):
		_player.position = from.lerp(stand, t)
		_player.set_moving(true, stand.x - from.x, stand.y - from.y), 0.0, 1.0, clampf(from.distance_to(stand) / 90.0, 0.1, 1.2))
	await walk.finished
	_player.set_moving(false)

	var before: float = GameState.stats[k]
	_bar.hold(k)
	var lines: Array = GameState.do_action(a)   # kazanç ve zaman hemen işlenir, gösterim baloncuklarla gelir
	var gain: float = GameState.stats[k] - before
	_anim = s["anim"]
	_anim_t = 0.0
	_anim_spot = i
	var sweat := _sweat()   # ter damlaları
	_clock_text = "%s..." % a["name"]
	_clock_t = 0.0
	create_tween().tween_property(self, "_clock_t", 1.0, TRAIN_SECONDS)
	var coach = _coach()
	if coach and randf() < 0.7:
		_say(coach, COACH_LINES.pick_random(), 1.6)
	for n in STAT_BUBBLES:
		await get_tree().create_timer(TRAIN_SECONDS / (STAT_BUBBLES + 1)).timeout
		_spawn_stat_bubble(k, gain / STAT_BUBBLES)
	await get_tree().create_timer(0.7).timeout
	_bar.release(k)
	sweat.emitting = false
	get_tree().create_timer(1.0).timeout.connect(sweat.queue_free)
	_anim = ""
	_anim_spot = -1
	_clock_text = ""
	_player.set_pose("idle")
	_player.face_dir("down")
	_say(_player, "  ".join(lines))
	_busy = false


## Antrenmanda başından sıçrayan ter damlaları.
func _sweat() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = _player.position + Vector2(0, _player.head_y() + 4)
	p.amount = 10
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, 160)
	p.color = Color("9ccfeb")
	p.z_index = 20
	_room.top_layer.add_child(p)
	p.emitting = true
	return p


## Gündüz evde pencereden giren ışıkta uçuşan toz.
func _dust() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(184, 96)
	p.amount = 14
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 40)
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector2.ZERO
	p.color = Color(1, 0.95, 0.8, 0.5)
	_room.top_layer.add_child(p)


## Başın üstünden çıkıp kavis çizerek üstteki stat rozetine uçar; varınca rozeti doldurur.
func _spawn_stat_bubble(k: String, amount: float) -> void:
	var b := StatBubble.new()
	b.color = StatusBar.STAT_COLORS[k]
	var world: Vector2 = _player.position + Vector2(randf_range(-6, 6), _player.head_y())
	var start: Vector2 = _room.to_screen(world)
	var target: Vector2 = _bar.stat_anchor(k)
	var mid := start.lerp(target, 0.5) + Vector2(randf_range(-30, 30), -30)
	b.position = start
	_ui.add_child(b)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		b.position = (1 - t) * (1 - t) * start + 2 * (1 - t) * t * mid + t * t * target
		b.scale = Vector2.ONE * lerpf(1.2, 0.7, t), 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_bar.feed(k, amount)
		b.queue_free())


## Oyuncunun ve salondaki diğer sporcuların animasyonları.
func _animate(delta: float) -> void:
	_anim_t += delta
	if _anim != "":
		_pose(_player, _anim, _anim_t)
	for s in _spots:
		if s.has("user_node"):
			_pose(s["user_node"], s["anim"], _time + s["index"] * 0.37)
	# kum torbaları: vuran varsa sallanır
	if _room.props.has("bag"):
		for s in _spots:
			if s.get("anim", "") == "bag":
				var hit: bool = s.has("user") or _anim_spot == _spots.find(s)
				var bag: Sprite2D = _room.props["bag"][s["index"]]
				bag.offset.x = roundf(sin(_time * 12.0 + s["index"]) * 1.5) if hit else 0.0


func _pose(p, anim: String, t: float) -> void:
	match anim:
		"lift":
			p.face_dir("down")
			p.set_pose("lift2" if int(t / 0.5) % 2 == 1 else "lift1")
		"run":
			p.face_dir("right")
			p.set_pose("walk1" if int(t / 0.11) % 2 == 0 else "walk2")
		"bag":
			p.face_dir("right")
			p.set_pose("punch" if int(t / 0.27) % 2 == 0 else "idle")


## Eylem sürerken üstte dönen bir saat.
func _draw_clock() -> void:
	if _clock_text == "":
		return
	var c := Vector2(240, 66)
	_clock_overlay.draw_rect(Rect2(c.x - 70, c.y - 24, 140, 46), Color(0, 0, 0, 0.6))
	_clock_overlay.draw_circle(c + Vector2(0, -6), 12, Color.WHITE)
	_clock_overlay.draw_circle(c + Vector2(0, -6), 10, Color("1b2a52"))
	var ang := _clock_t * TAU * 3.0
	_clock_overlay.draw_line(c + Vector2(0, -6), c + Vector2(0, -6) + Vector2.from_angle(ang - PI / 2) * 8, Color("e6b428"), 2)
	_clock_overlay.draw_line(c + Vector2(0, -6), c + Vector2(0, -6) + Vector2.from_angle(ang / 12.0 - PI / 2) * 5, Color.WHITE, 2)
	_clock_overlay.draw_string(ThemeDB.fallback_font, Vector2(c.x - 70, c.y + 16), _clock_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 9, Color.WHITE)


# ---------------------------------------------------------------- Çizim
# Mekanlar tools/make_rooms.py ile çizilir. Burada sadece hareketli parçalar ve etiketler.

## Zemin üstü: koşu bantları akar, boştaki halter barı sehpada durur.
func _draw_floor_fx() -> void:
	if _id != "gym":
		return
	var belts: Array = _room.points("belts")
	var bars: Array = _room.points("bars")
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		var active: bool = i == _anim_spot or s.has("user")
		match s.get("anim", ""):
			"run":
				var b: Array = belts[s["index"]]
				var shift := int(fposmod(_time * 50.0, 6.0)) if active else 0
				for bx in range(0, int(b[2]), 6):
					_floor_fx.draw_rect(Rect2(b[0] + fposmod(bx - shift, b[2]), b[1] + 1, 1, b[3] - 2), Color("2c2f3b"))
			"lift":
				if not active:
					var p: Vector2 = bars[s["index"]]
					_floor_fx.draw_rect(Rect2(p.x - 26, p.y, 52, 2), Color("a8afbf"))
					_floor_fx.draw_rect(Rect2(p.x - 26, p.y - 4, 4, 10), Color("121018"))
					_floor_fx.draw_rect(Rect2(p.x + 22, p.y - 4, 4, 10), Color("121018"))


## En üst: fareyle üstüne gelinen ya da yanındaki şeyin adı; dükkanlarda fiyatlar, evde dolap.
func _draw_top() -> void:
	var font := ThemeDB.fallback_font
	for s in _spots:   # dükkanlarda askı ve panoların üstünde fiyat
		if s["kind"] == "item":
			var r := _prop_rect(s["prop"], 0)
			var owned := _item_owned(s)
			var tag := "SENDE" if owned else "%d TL" % GameState.shop_price(_item_info(s)["price"])
			var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 6.0
			var tp := Vector2(roundf(r.get_center().x - tw / 2.0), r.position.y - 9)
			UIDraw.box(_top, Rect2(tp, Vector2(tw, 9)), Color("16a34a") if owned else Color("e6b428"), Color(0, 0, 0, 0), 3)
			_top.draw_string(font, tp + Vector2(3, 7), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE if owned else Color("1b1024"))
	if _id == "ev":
		var f := _room.mark("fridge") + Vector2(-10, -30)
		_top.draw_string(font, f, "%d öğün" % GameState.fridge, HORIZONTAL_ALIGNMENT_CENTER, 24, 6, Color("6e6454"))
	var focus := _hover if _hover >= 0 else (_nearest_spot() if _can_control() else -1)
	if focus < 0:
		return
	var r := _spot_rect(focus)
	var name := _spot_name(_spots[focus])
	var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(roundf(r.get_center().x - w / 2.0), r.position.y - 4)
	_top.draw_rect(Rect2(p.x - 3, p.y - 9, w + 6, 11), Color(0, 0, 0, 0.65))
	_top.draw_string(font, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e6b428"))
