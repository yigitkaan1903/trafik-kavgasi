extends Node2D
## Yukarıdan bakışlı trafik. Sürtünme ya da korna kavgayı başlatır.
## Otoparktan çıkınca (GameState.drive_dest) hedefe kadar sürülür: yol aldıkça saat ilerler, varınca oranın
## otoparkında inersin. Galeriden "Trafiğe çık" ile girince serbest sürüş.

const NpcCar = preload("res://scenes/traffic/npc_car.gd")
const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")

const PLAYER_REPLIES := {
	"carpma": ["Abi sen ani fren yaptın!", "Sinyal versene kardeşim!", "Ayna süs için mi orada?"],
	"korna": ["Yeşil yandı abi, uyuma!", "Yolu babanın malı mı sandın?", "Şerit diye bir şey var!"],
	"scared": ["Bir dahakine dikkat et.", "Bugün şanslı günündesin.", "Yolumdan çekil, yeter."],
}

const LANES := [206.0, 240.0, 274.0]
const ROAD_L := 189.0
const ROAD_R := 291.0
const PLAYER_Y := 215.0
const PX_TO_M := 0.25
const MIN_SPEED := 40.0
const SCENERY_H := 540.0

var player: Sprite2D
var npcs: Array = []
var lane := 1
var speed := 0.0
var _cruise := 0.0
var _max_speed := 0.0
var _paused := false
var _scroll := 0.0
var _spawn_t := 0.5
var _recent: Array = []       # son çıkan rakipler ve araba görselleri (art arda tekrar olmasın)
var _honk_cd := 0.0
var _invuln := 0.0
var _shake := 0.0
var _scenery: Array = []
var _ui: CanvasLayer
var _hud: Control
var _hud_labels := {}
var _arrived := false


func _ready() -> void:
	if not GameState.has_car():
		GameState.go_to.call_deferred(GameState.SCENE_METRO)
		set_physics_process(false)
		return
	var k := GameState.car_speed()
	_cruise = 95.0 * k
	_max_speed = 150.0 * k
	speed = _cruise
	_make_scenery()

	player = Sprite2D.new()
	player.texture = GameState.car_texture(GameState.car()["id"])
	player.position = Vector2(LANES[lane], PLAYER_Y)
	player.z_index = 2
	add_child(player)

	_ui = CanvasLayer.new()
	add_child(_ui)
	_build_hud()
	if GameState.car()["damage"] >= GameState.car_max_hp():
		_message("Araban hurda durumda!", "Önce tamir ettirmen lazım.", "Garaja git", GameState.go_to.bind(GameState.SCENE_GARAGE))


func _physics_process(delta: float) -> void:
	position = Vector2(roundf(randf_range(-1, 1) * _shake), roundf(randf_range(-1, 1) * _shake))
	_shake = move_toward(_shake, 0.0, 20.0 * delta)
	if _paused:
		return
	_honk_cd -= delta
	_invuln -= delta

	var target := _cruise
	if Input.is_action_pressed("move_up"):
		target = _max_speed
	elif Input.is_action_pressed("move_down"):
		target = MIN_SPEED
	speed = move_toward(speed, target, (110.0 if target > speed else 200.0) * delta)
	if Input.is_action_just_pressed("move_left"):
		lane = maxi(0, lane - 1)
	if Input.is_action_just_pressed("move_right"):
		lane = mini(2, lane + 1)
	player.position.x = move_toward(player.position.x, LANES[lane], 170.0 * delta)
	player.rotation = clampf((LANES[lane] - player.position.x) * 0.015, -0.25, 0.25)
	player.modulate.a = 0.5 if _invuln > 0.0 and int(_invuln * 10) % 2 == 0 else 1.0

	_scroll += speed * delta
	GameState.distance_m += speed * delta * PX_TO_M
	if GameState.drive_dest != "":
		GameState.drive_progress(speed * delta * PX_TO_M)
		if GameState.drive_left <= 0.0:
			_arrive()
			return

	for n in npcs.duplicate():
		n.position.y += (speed - n.speed) * delta
		n.update_ai(delta, self)
		if n.position.y > 330.0 or n.position.y < -120.0:
			_remove_npc(n)
	_spawn(delta)
	_check_crash()

	if Input.is_action_just_pressed("horn"):
		_honk()
	if Input.is_action_just_pressed("garage") and GameState.drive_dest == "":
		_leave(GameState.SCENE_GARAGE)
	elif Input.is_action_just_pressed("back"):
		_leave(GameState.SCENE_MENU)
	queue_redraw()
	_hud.queue_redraw()
	_update_hud()


func lane_free(l: int, y: float, except: Node) -> bool:
	for n in npcs:
		if n != except and n.lane == l and absf(n.position.y - y) < 46.0:
			return false
	return true


func _spawn(delta: float) -> void:
	_spawn_t -= delta * speed / _cruise
	if _spawn_t > 0.0:
		return
	_spawn_t = randf_range(0.6, 1.4)
	var l := randi() % 3
	if not lane_free(l, -40.0, null):
		return
	var n := NpcCar.new()
	var rid := GameState.pick_traffic_rival()
	for k in 4:   # aynı rakip / aynı araba art arda gelmesin
		if rid not in _recent:
			break
		rid = GameState.pick_traffic_rival()
	n.setup(rid, l, LANES[l], _recent)
	_recent.push_front(rid)
	_recent.push_front(n.texture.resource_path)
	_recent.resize(mini(_recent.size(), 6))
	n.z_index = 1
	add_child(n)
	npcs.append(n)


func _remove_npc(n: Node) -> void:
	npcs.erase(n)
	n.queue_free()


func _player_rect() -> Rect2:
	var s := player.texture.get_size() - Vector2(4, 4)
	return Rect2(player.position - s / 2.0, s)


func _check_crash() -> void:
	if _invuln > 0.0:
		return
	var pr := _player_rect()
	for n in npcs:
		if pr.intersects(n.hit_rect()):
			_invuln = 1.2
			_shake = 4.0
			speed *= 0.4
			GameState.car()["damage"] += 1
			_float_text("ÇARP!", player.position + Vector2(0, -28), Color("ff6a4a"))
			if GameState.car()["damage"] >= GameState.car_max_hp():
				_wreck()
			else:
				_encounter(n, "carpma")
			return


func _honk() -> void:
	if _honk_cd > 0.0:
		return
	_honk_cd = 0.5
	Audio.sfx("horn", 0.8)
	_float_text("DIIIT!", player.position + Vector2(0, -28), Color("7dd3fc"))
	var best: Node = null
	for n in npcs:
		var gap: float = player.position.y - n.position.y
		if absf(n.position.x - player.position.x) < 16.0 and gap > 0.0 and gap < 120.0:
			if best == null or n.position.y > best.position.y:
				best = n
	if best:
		_encounter(best, "korna")


func _encounter(n: Node, reason: String) -> void:
	_paused = true
	var id: String = n.rival_id
	var r := GameState.rival(id)
	var popup := ChoicePopup.new()
	popup.set_rival(id)
	popup.add_line("\"%s\"" % GameState.rival_line(id, reason))
	popup.add_scared_note(id)
	var reply_key := "scared" if GameState.is_scared(id) else reason
	popup.add_line("Sen: \"%s\"" % PLAYER_REPLIES[reply_key].pick_random(), 9, Color(1, 1, 1, 0.65))
	popup.add_rival_choices(id, "Kavga et!")
	if r["bet"] and not n.decor:   # süs arabaya iddiaya girilmez
		popup.add_choice("İddiaya gir: arabalar ortaya!", "bet", false, "Kazanırsan: %s   Kaybedersen: %s" % [
				GameState.car_info(r["car"])["name"], GameState.car_info()["name"]])
	var cost := int(r["reward"] / 2)
	if GameState.money >= cost:
		popup.add_choice("Özür dile, yoluna bak  (-%d TL)" % cost, "apologize")
	else:
		popup.add_choice("Özür dile  (paran yetmiyor!)", "apologize", true)
	_ui.add_child(popup)
	popup.chosen.connect(func(choice: String):
		match choice:
			"apologize", "intimidate":
				if choice == "apologize":
					GameState.try_spend(cost)
				else:
					GameState.intimidate(id)
					_float_text("+%d TL" % GameState.intimidate_reward(id), n.position + Vector2(0, -24), Color("4ade80"))
				_remove_npc(n)
				popup.queue_free()
				_invuln = 1.5
				_paused = false
			_:
				GameState.fight_rival = id
				GameState.fight_bet = choice == "bet"
				GameState.fight_venue = "traffic"
				GameState.save_game()
				GameState.go_to(GameState.SCENE_FIGHT)
	)

## Hedefe vardın: arabayı park edip in.
func _arrive() -> void:
	if _arrived:
		return
	_arrived = true
	_paused = true
	var dest := "YTÜ Davutpaşa" if GameState.drive_dest == "kampus" else "Beylikdüzü"
	_float_text("%s'ya vardın!" % dest if GameState.drive_dest == "kampus" else "%s'e vardın!" % dest, player.position + Vector2(0, -40), Color("4ade80"))
	await get_tree().create_timer(1.0).timeout
	GameState.finish_drive()


## Kaporta bitti: çekici arabayı galeriye götürür. Yolculuktaysan kalan yolu dolmuşla tamamlarsın
## (yolculuk yarıda kalmaz); serbest sürüşteysen garaja dönersin.
func _wreck() -> void:
	var fee := mini(GameState.money, GameState.TOW_COST)
	GameState.money -= fee
	GameState.save_game()
	if GameState.drive_dest != "":
		_message("Araban hurdaya döndü!", "Çekici arabanı Necdet Oto Galeri'ye çekti: -%d TL. Tamir ettirmeden binemezsin.\nKalan yolu dolmuşla gidiyorsun." % fee,
				"Dolmuşa bin", GameState.walk_rest_of_drive)
	else:
		_message("Araban hurdaya döndü!", "Çekici geldi: -%d TL. Arabayı garaja çektiler." % fee,
				"Garaja git", GameState.go_to.bind(GameState.SCENE_GARAGE))


## Uyarı kartı (oyunu durdurur); tek seçenek, seçince on_ok çağrılır.
func _message(title: String, text: String, button_text: String, on_ok: Callable) -> void:
	_paused = true
	_update_hud()   # durunca HUD güncellenmez: çekici parası hemen görünsün
	var popup := ChoicePopup.new()
	popup.icon = "warn"
	popup.accent = Color("ef4444")
	popup.title = title
	popup.add_line(text, 10, Color(1, 1, 1, 0.85))
	popup.add_choice(button_text, "ok")
	_ui.add_child(popup)
	popup.chosen.connect(func(_c: String): on_ok.call())


func _leave(path: String) -> void:
	_paused = true
	GameState.save_game()
	GameState.go_to(path)


func _float_text(text: String, pos: Vector2, color: Color) -> void:
	var l := GameState.make_label(text, 10, color)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 14)
	l.position = pos - Vector2(40, 7)
	l.z_index = 5
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	_ui.add_child(_hud)
	var left := Panel.new()
	left.position = Vector2(6, 6)
	left.size = Vector2(164, 118)
	left.show_behind_parent = true
	_hud.add_child(left)
	var y := 10.0
	for key in ["money", "car", "armor", "speed", "km", "record"]:
		var l := GameState.make_label("", 14 if key == "money" else 10, Color("e6b428") if key == "money" else Color.WHITE)
		l.position = Vector2(14, y)
		_hud.add_child(l)
		_hud_labels[key] = l
		y += 22.0 if key == "money" else 16.0
	var right := Panel.new()
	right.position = Vector2(310, 6)
	right.size = Vector2(164, 118)
	_hud.add_child(right)
	var help := GameState.make_label(
			"Sol / Sağ: şerit değiştir\nYukarı: gaz   Aşağı: fren\nH: korna çal\n" +
				("Esc: menü\n\nHızlı gidersen erken varırsın\n(saat yol aldıkça ilerler).\nBirine sürtersen kavga çıkar!" if GameState.drive_dest != ""
				else "G: garaj   Esc: menü\nF11: tam ekran\n\nBirine sürt ya da korna çal:\nkavga başlar!"), 9)
	help.position = Vector2(318, 12)
	_hud.add_child(help)


func _update_hud() -> void:
	_hud_labels["money"].text = "%d TL" % GameState.money
	_hud_labels["car"].text = GameState.car_info()["name"]
	_hud_labels["armor"].text = "Kaporta"
	_hud_labels["speed"].text = "Hız: %d km/s" % int(speed * 0.9)
	_hud_labels["km"].text = "Yol: %.1f km" % (GameState.distance_m / 1000.0)
	_hud_labels["record"].text = "Galibiyet: %d   Yenilgi: %d" % [GameState.wins, GameState.losses]
	if GameState.drive_dest != "":
		_hud_labels["km"].text = "%s: %.1f km kaldı" % ["Okula" if GameState.drive_dest == "kampus" else "Eve", GameState.drive_left / 1000.0]


func _draw_hud() -> void:
	if GameState.drive_dest != "":   # yolculuk ilerlemesi
		var k := 1.0 - GameState.drive_left / GameState.Places.DRIVE_METERS
		var r := Rect2(184, 8, 112, 6)
		_hud.draw_rect(r.grow(1), Color("e6b428"))
		_hud.draw_rect(r, Color("1a1020"))
		_hud.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color("4ade80"))
		_hud.draw_string(ThemeDB.fallback_font, Vector2(184, 26), "YTÜ Davutpaşa" if GameState.drive_dest == "kampus" else "Ev (Beylikdüzü)",
				HORIZONTAL_ALIGNMENT_CENTER, 112, 8, Color.WHITE)
	var max_hp := GameState.car_max_hp()
	var hp: int = max_hp - GameState.car()["damage"]
	for i in max_hp:
		var r := Rect2(64 + i * 9, 51, 7, 8)
		_hud.draw_rect(r.grow(1), Color("e6b428"))
		_hud.draw_rect(r, Color("4ade80") if i < hp else Color("3a1a1a"))


# ---------------------------------------------------------------- Yol ve çevre

func _make_scenery() -> void:
	var colors := [Color("5a5266"), Color("6b5a52"), Color("4f5a66"), Color("665a4a"), Color("5c6670")]
	for side in [[4.0, 168.0], [312.0, 476.0]]:
		var y := 0.0
		while y < SCENERY_H:
			var h := randf_range(40, 90)
			var x0: float = side[0] + randf_range(0, 20)
			var x1: float = side[1] - randf_range(0, 20)
			var details: Array = []
			for i in randi_range(1, 3):
				details.append(Rect2(randf_range(x0 + 6, x1 - 18), randf_range(6, h - 18), randf_range(8, 14), randf_range(6, 10)))
			_scenery.append({"rect": Rect2(x0, y, x1 - x0, h - 6), "color": colors.pick_random(), "details": details})
			y += h


func _draw() -> void:
	draw_rect(Rect2(-8, -8, 496, 286), Color("2d3138"))
	var off := fposmod(_scroll, SCENERY_H)
	for s in _scenery:
		for wrap in [0.0, -SCENERY_H]:
			var r: Rect2 = s["rect"]
			var y: float = r.position.y + off + wrap
			if y > 280.0 or y + r.size.y < -10.0:
				continue
			draw_rect(Rect2(r.position.x, y, r.size.x, r.size.y), s["color"])
			draw_rect(Rect2(r.position.x, y, r.size.x, 2), Color(s["color"]).lightened(0.15))
			for d in s["details"]:
				draw_rect(Rect2(d.position.x, y + d.position.y, d.size.x, d.size.y), Color(s["color"]).darkened(0.25))
	# kaldırımlar ve ağaçlar
	for sx in [177.0, 291.0]:
		draw_rect(Rect2(sx, -8, 12, 286), Color("8a8a96"))
		for i in range(-1, 24):
			var y := i * 12.0 + fposmod(_scroll, 12.0)
			draw_rect(Rect2(sx, y, 12, 1), Color("767682"))
		for i in range(-1, 8):
			var y := i * 40.0 + fposmod(_scroll, 40.0)
			draw_circle(Vector2(sx + 6, y), 6, Color("3d6b3d"))
			draw_circle(Vector2(sx + 5, y - 1), 3, Color("4f8a4f"))
	# yol
	draw_rect(Rect2(ROAD_L, -8, ROAD_R - ROAD_L, 286), Color("3a3a44"))
	draw_rect(Rect2(ROAD_L + 1, -8, 2, 286), Color("e8e8e8"))
	draw_rect(Rect2(ROAD_R - 3, -8, 2, 286), Color("e8e8e8"))
	for lx in [223.0, 257.0]:
		for i in range(-1, 11):
			draw_rect(Rect2(lx - 1, i * 28.0 + fposmod(_scroll, 28.0), 2, 14), Color("e8e8e8", 0.8))
