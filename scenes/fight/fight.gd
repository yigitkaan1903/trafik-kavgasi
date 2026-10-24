extends Node2D
## Dövüş sahnesi (3/4 üstten bakış, kamera 2x yakın): mekan, iki dövüşçü, seyirciler, vuruş efektleri,
## K.O. ve sonuç ekranı. Mekanlar tools/make_rooms.py: sokak, metrobus, durak.

const PlayerFighter = preload("res://scenes/fight/player_fighter.gd")
const AIFighter = preload("res://scenes/fight/ai_fighter.gd")
const FightHud = preload("res://scenes/fight/fight_hud.gd")

const Person = preload("res://scenes/metro/person.gd")
const ZOOM := 2.0
## Mekan ve dövüş alanı (dövüşçülerin ayaklarının gezebileceği dikdörtgen)
const VENUES := {
	"traffic": ["sokak", Rect2(30, 78, 420, 66)],
	"bus": ["metrobus", Rect2(330, 118, 300, 31)],
	"durak": ["durak", Rect2(260, 96, 440, 84)],
}
const HIT_WORDS := {
	"punch": ["PAT!", "ÇAT!", "BAM!", "PÜF!"],
	"kick": ["GÜM!", "TAK!", "HAAA!"],
	"special": ["KÜT!!", "DANG!!"],
}

var rival: Dictionary
var venue := "traffic"
var rival_id := ""
var player: Fighter
var enemy: Fighter
var _room: Room
var _focus: Node2D           # kamera iki dövüşçünün ortasına bakar
var _arena: Rect2
var _ui: CanvasLayer
var _shake := 0.0
var _over := false


func _ready() -> void:
	if GameState.fight_rival == "":
		GameState.fight_rival = "remzi"   # sahne tek başına açılırsa
	rival_id = GameState.fight_rival
	rival = GameState.rival_stats(rival_id)
	venue = GameState.fight_venue
	_add_background()
	var mid_y := _arena.get_center().y

	if venue == "traffic":
		if GameState.has_car():
			_add_parked_car(GameState.car()["id"], Vector2(_arena.position.x + 70, _arena.position.y - 6), false)
		if rival.has("car"):
			_add_parked_car(rival["car"], Vector2(_arena.end.x - 70, _arena.position.y - 6), true)
	_add_crowd()

	# statlar: Güç hasar, Dayanıklılık can (yorgunsan daha az), Çeviklik hız/kaçış/blok
	var agi := GameState.player_agility()
	player = PlayerFighter.new()
	player.look = GameState.player_look()
	player.display_name = "Sen"
	player.max_hp = GameState.player_max_hp() + (GameState.SIMIT_HP if GameState.simit_buff else 0)
	player.power = GameState.player_power()
	player.block_chip = agi["block_chip"]
	player.dodge_cooldown = agi["dodge_cd"]
	player.move_speed = agi["speed"] * 0.5
	player.arena = _arena
	player.weapon = GameState.weapon_info()
	# yetenek ağacı (data/skills.gd)
	var gs := GameState
	player.dmg_bonus = {"punch": (1.0 if gs.has_skill("sert_yumruk") else 0.0) + (2.0 if gs.has_skill("kemik_kiran") else 0.0),
			"kick": 2.0 if gs.has_skill("agir_tekme") else 0.0, "special": 6.0 if gs.has_skill("son_darbe") else 0.0}
	if gs.has_skill("hizli_ayak"):
		player.move_speed *= 1.1
	if gs.has_skill("siyrilma"):
		player.dodge_cooldown *= 0.75
	if gs.has_skill("kontra"):
		player.block_chip *= 0.5
	player.evade_chance = 0.12 if gs.has_skill("golge") else 0.0
	player.stun_mult = 0.65 if gs.has_skill("tas_cene") else 1.0
	player.weapon_id = GameState.weapon
	player.position = Vector2(_arena.get_center().x - 45, mid_y)

	enemy = AIFighter.new()
	enemy.look = rival["look"]
	enemy.display_name = rival["name"]
	enemy.max_hp = rival["hp"]
	enemy.power = rival["power"]
	enemy.move_speed = 32.0 * rival["speed"]
	enemy.arena = _arena
	enemy.aggro = rival["aggro"]
	enemy.reflex = rival["block"]
	enemy.think_speed = rival["speed"]
	enemy.position = Vector2(_arena.get_center().x + 45, mid_y)

	player.opponent = enemy
	enemy.opponent = player
	for f in [player, enemy]:
		_room.add_actor(f)
		f.got_hit.connect(_on_hit)
		f.dodged.connect(_on_dodged)
		f.knocked_out.connect(_on_ko)

	_focus = Node2D.new()
	add_child(_focus)
	_update_focus()
	_room.follow(_focus, ZOOM)

	_ui = CanvasLayer.new()
	add_child(_ui)
	var hud := FightHud.new()
	hud.player = player
	hud.enemy = enemy
	_ui.add_child(hud)
	_intro()


func _intro() -> void:
	if GameState.fight_bet:
		var bet := GameState.make_label("İDDİA: ARABALAR ORTADA!", 10, Color("ff6a4a"))
		bet.position = Vector2(0, 40)
		bet.size = Vector2(480, 12)
		bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.add_child(bet)
	if GameState.simit_buff:
		GameState.simit_buff = false
		_popup("SİMİT GÜCÜ! +%d can" % GameState.SIMIT_HP, player.position + Vector2(0, -40), Color("ffd84a"), 10)
	if GameState.weapon != "":
		var w := GameState.weapon_info()
		var wl := GameState.make_label("Elinde: %s  (%s)" % [w["name"], w["desc"]], 9, Color("f6d86a"))
		wl.position = Vector2(0, 64)
		wl.size = Vector2(480, 12)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.add_child(wl)
	var fear := GameState.fear_level(GameState.fight_rival)
	if fear > 0:
		var nam := GameState.make_label("Namın yürüyor! Rakip çekiniyor (Nam %d): daha az can, daha az saldırı" % fear, 9, Color("7dd3fc"))
		nam.position = Vector2(0, 52)
		nam.size = Vector2(480, 12)
		nam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.add_child(nam)
	await _center_text("Sen  vs  " + rival["name"], 16, Color.WHITE, 1.0)
	await _center_text("KAVGA!", 32, Color("e6b428"), 0.5)
	player.controls_enabled = true
	enemy.active = true
	var horn: int = GameState.car()["horn"] if venue == "traffic" and GameState.has_car() else 0
	if horn > 0:
		enemy.stun(0.5 * horn)
		_popup("DIIIIT!", enemy.position + Vector2(0, -40), Color("7dd3fc"), 14)


func _physics_process(_delta: float) -> void:
	# dövüşçüler iç içe geçmesin (aynı hizadaysalar)
	var d := enemy.position.x - player.position.x
	var close := absf(d) < 12.0 and absf(enemy.position.y - player.position.y) < Fighter.DEPTH
	if close and player.state != Fighter.S.KO and enemy.state != Fighter.S.KO:
		var push := (12.0 - absf(d)) / 2.0 * (signf(d) if d != 0.0 else 1.0)
		player.position.x = clampf(player.position.x - push, _arena.position.x, _arena.end.x)
		enemy.position.x = clampf(enemy.position.x + push, _arena.position.x, _arena.end.x)


func _process(delta: float) -> void:
	_update_focus()
	if _room.cam:
		_room.cam.offset = Vector2(roundf(randf_range(-1, 1) * _shake), roundf(randf_range(-1, 1) * _shake)) / ZOOM
	_shake = move_toward(_shake, 0.0, 25.0 * delta) if GameState.screen_shake else 0.0


func _update_focus() -> void:
	_focus.position = ((player.position + enemy.position) / 2.0).round()


# ---------------------------------------------------------------- Olaylar

func _on_hit(target: Fighter, attack: String, _damage: float, blocked: bool) -> void:
	var attacker := target.opponent
	var pos := Vector2((attacker.position.x + target.position.x) / 2.0, target.position.y - 22)
	if blocked:
		Audio.sfx("block")
		_popup("BLOK", pos, Color("cbd5e1"), 10)
		_hitstop(0.03)
		_shake = 1.0
		return
	var big := attack == "special"
	Audio.sfx("kick" if attack != "punch" else "punch")
	_popup(HIT_WORDS[attack].pick_random(), pos, Color("ff5a3c") if big else Color("ffd84a"), 22 if big else 14)
	_sparks(pos, 12 if big else 6)
	_hitstop({"punch": 0.05, "kick": 0.08, "special": 0.15}[attack])
	_shake = {"punch": 2.0, "kick": 3.0, "special": 7.0}[attack]


func _on_dodged(target: Fighter) -> void:
	Audio.sfx("whoosh")
	_popup("ISKA!", target.position + Vector2(0, -36), Color("7dd3fc"), 10)


func _on_ko(target: Fighter) -> void:
	if _over:
		return
	_over = true
	player.controls_enabled = false
	enemy.active = false
	var won := target == enemy
	_shake = 8.0
	Audio.sfx("ko", 1.0, 0.0)
	Engine.time_scale = 0.3
	_center_text("K.O.!", 40, Color("ff5a3c"), 0.9)
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.5).timeout
	_show_result(GameState.apply_fight_result(won))


func _show_result(res: Dictionary) -> void:
	var won: bool = res["won"]
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	box.add_child(GameState.make_label("KAZANDIN!" if won else "DAYAK YEDİN...", 20,
			Color("e6b428") if won else Color("ff6a4a")))
	var quote: String = rival["lines"]["lose" if won else "win"].pick_random()
	var q := GameState.make_label("%s: \"%s\"" % [rival["name"], quote], 10, Color(1, 1, 1, 0.75))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size.x = 260
	box.add_child(q)
	if res["money"] > 0:
		var why := "" if venue == "traffic" else "  (%s)" % GameState.MetroEvents.WIN_REASONS.pick_random()
		box.add_child(GameState.make_label("+%d TL%s" % [res["money"], why], 12, Color("4ade80")))
	elif res["money"] < 0:
		box.add_child(GameState.make_label("%d TL (hastane parası)" % res["money"], 12, Color("ff6a4a")))
	if res["fear_up"]:
		var level := GameState.fear_level(rival_id)
		var text := "Namın yürüyor! %s artık seni tanıyor." % rival["name"]
		if level >= GameState.INTIMIDATE_FEAR:
			text = "%s artık senden korkuyor! Bir dahakine gözdağı verebilirsin." % rival["name"]
		box.add_child(GameState.make_label(text, 10, Color("7dd3fc")))
	if res["car_won"] != "":
		box.add_child(GameState.make_label("Yeni araba: %s! Garaja çekildi." % GameState.car_info(res["car_won"])["name"], 11, Color("e6b428")))
	if res["car_lost"] != "":
		box.add_child(GameState.make_label("Araban gitti: %s..." % GameState.car_info(res["car_lost"])["name"], 11, Color("ff6a4a")))
	for key in ["xp", "seat", "station", "police"]:
		if res.has(key):
			box.add_child(GameState.make_label(res[key], 10, Color("7dd3fc")))
	if res["no_car"]:
		box.add_child(GameState.make_label("Artık araban yok. Metrobüs seni bekliyor...", 10, Color(1, 1, 1, 0.75)))
	box.add_child(GameState.make_label("Kavga yordu: %s" % res["tired"], 9, Color(1, 1, 1, 0.55)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var back_to_traffic := venue == "traffic" and GameState.has_car()
	var walk_on := venue == "traffic" and not GameState.has_car() and GameState.drive_dest != ""
	var cont := Button.new()
	if walk_on:   # araban gitti: kalan yolu dolmuşla
		cont.text = "Dolmuşla devam et"
		cont.pressed.connect(GameState.walk_rest_of_drive)
	else:
		cont.text = "Yola devam" if back_to_traffic and GameState.drive_dest != "" else ("Trafiğe dön" if back_to_traffic else ("Metrobüse dön" if GameState.metro_on_board else "Durağa dön"))
		cont.pressed.connect(GameState.go_to.bind(GameState.SCENE_TRAFFIC if back_to_traffic else GameState.metro_scene()))
	buttons.add_child(cont)
	if venue == "traffic" and GameState.drive_dest == "":
		var to_garage := Button.new()
		to_garage.text = "Garaja git"
		to_garage.pressed.connect(GameState.go_to.bind(GameState.SCENE_GARAGE))
		buttons.add_child(to_garage)
	cont.grab_focus()


# ---------------------------------------------------------------- Efektler

func _hitstop(seconds: float) -> void:
	player.frozen = true
	enemy.frozen = true
	await get_tree().create_timer(seconds, true, false, true).timeout
	player.frozen = false
	enemy.frozen = false


func _center_text(text: String, size: int, color: Color, seconds: float) -> void:
	var l := GameState.make_label(text, size, color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 95)
	l.size = Vector2(480, 50)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.6, 1.6)
	_ui.add_child(l)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.15)
	await tw.finished
	l.queue_free()


## Vuruş yazısı: dünya noktasının ekrandaki yerinde, arayüz katmanında (yakın kamerada bulanık olmasın).
func _popup(text: String, pos: Vector2, color: Color, size: int) -> void:
	var l := GameState.make_label(text, size, color)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(100, 24)
	l.position = _room.to_screen(pos) - Vector2(50, 12) + Vector2(randf_range(-6, 6), 0)
	_ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_callback(l.queue_free)


func _sparks(pos: Vector2, count: int) -> void:
	for i in count:
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = [Color("fff3b0"), Color("ffd84a"), Color.WHITE].pick_random()
		p.position = pos + Vector2(0, 8)
		_room.top_layer.add_child(p)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(5, 14)
		var tw := create_tween()
		tw.tween_property(p, "position", p.position + dir, 0.25)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- Mekan

## Trafikte durdurulmuş arabalar (3/4 bakış, yandan).
func _add_parked_car(id: String, at: Vector2, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = GameState.car_3q_texture(id)
	s.centered = false
	s.flip_h = flip
	var size := s.texture.get_size()
	s.position = at
	s.offset = Vector2(-size.x / 2.0, -size.y)
	_room.add_actor(s)


## Etrafta toplanan meraklılar: dövüş alanının kenarlarında, dövüşçülere bakar.
func _add_crowd() -> void:
	var looks := ["teyze", "plaza", "kulaklik", "abi", "necati", "cemil"]
	looks.erase(rival["look"])
	looks.shuffle()
	for k in 6:
		looks.append(GameState.MetroEvents.random_look())
	var spots: Array = []
	match venue:
		"bus":
			for p in _room.points("seats"):
				if randf() < 0.8:
					spots.append([p, "sit"])
			for k in 4:
				spots.append([_room.points("stand").pick_random(), "up"])
		"durak":
			for k in 7:
				spots.append([Vector2(_arena.position.x - 20 + k * 78, _arena.position.y - 6 + (k % 2) * 4), "down"])
			for k in 4:
				spots.append([Vector2(_arena.position.x + 30 + k * 120, _arena.end.y + 12), "up"])
		_:
			for k in 6:
				spots.append([Vector2(60 + k * 72 + randf_range(-6, 6), 46 + randf_range(-4, 4)), "down"])
			for k in 4:
				spots.append([Vector2(90 + k * 100, 168), "up"])
	for i in spots.size():
		var p := Person.new()
		p.look = looks[i % looks.size()]
		p.position = spots[i][0]
		_room.add_actor(p)
		if spots[i][1] == "sit":
			p.sit("right")
		else:
			p.face_dir(spots[i][1])
		p.tint(Color(0.85, 0.85, 0.92))


## Mekan (tools/make_rooms.py): sokak, metrobüs içi ya da durak peronu.
func _add_background() -> void:
	var v: Array = VENUES.get(venue, VENUES["traffic"])
	_arena = v[1]
	if venue == "bus":
		var outside := Node2D.new()   # vagon camlarından ve kenarlarından görünen yol
		outside.draw.connect(func():
			outside.draw_rect(Rect2(-40, -80, 900, 400), Color("3a3c44"))
			outside.draw_rect(Rect2(0, 46, 800, 32), Color("93c2ea"))
			for k in 20:
				outside.draw_rect(Rect2(k * 44 + 6, 68 - (k * 7) % 16, 30, 10 + (k * 7) % 16), Color("6d7f99")))
		add_child(outside)
	_room = Room.new().build(v[0])
	add_child(_room)
	Lighting.apply(self, venue != "bus", _room.lamps(), 90.0, venue == "bus")
	if venue == "durak":
		var sign := Node2D.new()
		sign.draw.connect(func():
			sign.draw_string(ThemeDB.fallback_font, _room.mark("sign_text"), GameState.MetroEvents.STATIONS[GameState.metro_station].to_upper(),
					HORIZONTAL_ALIGNMENT_CENTER, 126, 7, Color.WHITE))
		_room.top_layer.add_child(sign)
