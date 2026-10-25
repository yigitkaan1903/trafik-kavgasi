extends Control
## Harita: Beylikdüzü mahallesi ya da YTÜ Davutpaşa kampüsü (GameState.map_id).
## Binaya tıklayınca oraya yürürsün ve mekan/ders/yemekhane açılır. İki harita arası metrobüsle.
## Klavyeyle: Sol/Sağ seç, E ya da Enter git.

const Places = preload("res://data/places.gd")
const MapArt = preload("res://data/map_art.gd")
const Person = preload("res://scenes/metro/person.gd")
const StatusBar = preload("res://scenes/ui/status_bar.gd")
const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Phone = preload("res://scenes/ui/phone.gd")

const BUILDING := Vector2(40, 24)    # uzaktan bakış: küçük binalar (tools/make_citymap.py)

var _map: Dictionary
var _spots := {}      # id -> {"name", "desc", "pos", "go"}
var _order: Array = []
var _hover := ""
var _selected := 0
var _player
var _busy := false
var _ui: CanvasLayer
var _info: Label
var _phone
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map = Places.MAPS[GameState.map_id]
	_spots = _map["spots"]
	_order = _spots.keys()
	if not _spots.has(GameState.place):
		GameState.place = _map["start"]
	_selected = _order.find(GameState.place)

	var bg := TextureRect.new()   # harita görseli (tools/make_backgrounds.py)
	bg.texture = load("res://assets/backgrounds/%s.png" % _map["bg"])
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_overlay = Control.new()      # seçili bina çerçevesi ve isimler
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	Lighting.apply(self, true)
	_add_night_lights()

	if _spots.has("otopark") and GameState.has_car():   # araban otoparkta durur
		var car := Sprite2D.new()
		car.texture = GameState.car_texture(GameState.car()["id"])
		car.rotation = PI / 2.0
		car.scale = Vector2(0.5, 0.5)
		car.position = _spots["otopark"]["pos"] + Vector2(-6, 0)
		add_child(car)

	_player = Person.new()
	_player.look = GameState.player_look()
	_player.marker = true
	_player.scale_px = 0.6
	_player.position = _door(GameState.place)
	add_child(_player)

	_ui = CanvasLayer.new()
	add_child(_ui)
	_ui.add_child(StatusBar.new())
	var panel := Control.new()   # alt bilgi kartı
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.draw.connect(func():
		UIDraw.card(panel, Rect2(4, 235, 472, 32))
		UIDraw.box(panel, Rect2(9, 240, 3, 22), UIDraw.GOLD, Color(0, 0, 0, 0), 1))
	_ui.add_child(panel)
	_info = GameState.make_label("", 9)
	_info.position = Vector2(17, 238)
	_info.size = Vector2(430, 28)
	_ui.add_child(_info)
	_phone = Phone.new()
	_ui.add_child(_phone)

	if GameState.pending_notice != "":
		_notice("Bayıldın!", GameState.pending_notice, "")
		GameState.pending_notice = ""
	elif not GameState.intro_seen:
		_intro()
	for a in OS.get_cmdline_user_args():   # test: -- --go=yemekhane (o yere tıklamış gibi)
		if a.begins_with("--go="):
			_go.call_deferred(a.trim_prefix("--go="))


## Gece: yanan pencereler, sokak lambaları, mekan önü ışıkları (tools/make_citymap.py, bg_*_lights.png).
## Ayrı CanvasLayer'da durur ki CanvasModulate'in gece karartması ışıkları da söndürmesin.
func _add_night_lights() -> void:
	var night := Lighting.night_amount()
	var path := "res://assets/backgrounds/%s_lights.png" % _map["bg"]
	if night <= 0.0 or not ResourceLoader.exists(path):
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var lights := TextureRect.new()
	lights.texture = load(path)
	lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lights.material = mat
	lights.modulate.a = night
	layer.add_child(lights)


func _process(_delta: float) -> void:
	_update_info()
	_overlay.queue_redraw()


func _door(id: String) -> Vector2:
	return _spots[id]["pos"] + Vector2(0, BUILDING.y / 2.0 + 4)


## Binanın alanı: altı kapı hizası, üstü çizimin tepesi (PixelLab binaları daha uzun, bkz. data/map_art.gd).
func _rect(id: String) -> Rect2:
	var pos: Vector2 = _spots[id]["pos"]
	var top: float = MapArt.TOPS.get(GameState.map_id, {}).get(id, -BUILDING.y / 2.0)
	return Rect2(pos.x - BUILDING.x / 2.0, pos.y + top, BUILDING.x, BUILDING.y / 2.0 - top)


func _gui_input(event: InputEvent) -> void:
	if _busy or _phone.is_open():
		return
	if event is InputEventMouseMotion:
		_hover = ""
		for id in _spots:
			if _rect(id).grow(4).has_point(event.position):
				_hover = id
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover != "":
		_go(_hover)


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _phone.is_open():
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		_selected = (_selected + 1) % _order.size()
		_hover = _order[_selected]
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		_selected = (_selected - 1 + _order.size()) % _order.size()
		_hover = _order[_selected]
	elif (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")) and _hover != "":
		_go(_hover)
	elif event.is_action_pressed("back"):
		GameState.save_game()
		GameState.go_to(GameState.SCENE_MENU)


## Seçilen yere yürü ve aç.
func _go(id: String) -> void:
	var spot: Dictionary = _spots[id]
	# derse/yemekhaneye girmeden önce koşulları kontrol et (kapalı, hafta sonu, yorgun...)
	if spot["go"] in ["lecture", "cafeteria"]:
		var why: String = GameState.action_block_reason(Places.CAMPUS_ACTIONS[spot["go"]])
		if why != "":
			var timed := why.begins_with("Şu an kapalı") or why.begins_with("Hafta sonu")
			_notice(spot["name"], why + ".", "clock" if timed else "warn")
			return
	if spot["go"] == "drive":
		var why := GameState.drive_block_reason()
		if why != "":
			_notice(spot["name"], why, "warn")
			return
	_busy = true
	var dest := _door(id)
	if id != GameState.place:
		var tw := create_tween()
		tw.tween_method(func(t: float):
			_player.position = _player.position.lerp(dest, t)
			_player.set_moving(true, dest.x - _player.position.x), 0.0, 1.0, 0.6)
		await tw.finished
		_player.set_moving(false, 0.0)
	GameState.walk_to(id)
	match spot["go"]:
		"metro":   # Beylikdüzü durağından okula
			GameState.metro_station = 0
			GameState.metro_dir = 1
			GameState.metro_on_board = false
			GameState.go_to(GameState.SCENE_STATION)
		"metro_home":   # kampüsten eve
			GameState.metro_station = GameState.MetroEvents.STATIONS.size() - 1
			GameState.metro_dir = -1
			GameState.metro_on_board = false
			GameState.go_to(GameState.SCENE_STATION)
		"lecture", "cafeteria":
			var a: Dictionary = Places.CAMPUS_ACTIONS[spot["go"]].duplicate()
			a["course"] = spot.get("course", "")
			a["faculty"] = spot["name"]
			GameState.activity = a
			GameState.save_game()
			GameState.go_to(GameState.SCENE_ACTIVITY)
		"drive":   # arabayla öbür haritaya
			GameState.start_drive("kampus" if GameState.map_id == "mahalle" else "mahalle")
		_:
			GameState.open_place_scene(id)


func _update_info() -> void:
	var gs := GameState
	var lines: Array = []
	if _hover != "":
		lines.append("%s: %s" % [_spots[_hover]["name"], _spots[_hover]["desc"]])
	else:
		lines.append("Bir yere tıkla (ya da ok tuşları + E). Burada yürümek %d dakika." % _map["walk"])
	var week := "Bu hafta ders: %d/%d gün" % [gs.week_attended, Places.ATTEND_NEEDED]
	var extra := []
	if gs.energy < 20.0:
		extra.append("Çok yorgunsun, eve gidip uyu!")
	if gs.food < 20.0:
		extra.append("Karnın aç!")
	if gs.minute >= 23 * 60:
		extra.append("Gece oldu, 02:00'den önce yat!")
	lines.append("%s   ·   Zorluk: %s   ·   Evde %d öğün%s" % [week, gs.diff()["name"], gs.fridge,
			("   ·   " + " ".join(extra)) if not extra.is_empty() else ""])
	_info.text = "\n".join(lines)


func _intro() -> void:
	var popup := ChoicePopup.new()
	popup.portrait = GameState.portrait_texture(GameState.player_look())
	popup.title = "Hoş geldin, Yıldızlı!"
	popup.add_line("Beylikdüzü'nde küçük bir öğrenci evinde yaşıyorsun. Okul Davutpaşa'da, araban yok, cebinde %d TL var." % GameState.money)
	popup.add_line("Günün kısıtlı: gymde antrenman yap, çarşıda çalış, haftada en az %d gün derse git, yemek yemeyi unutma. Gece 02:00'yi geçirirsen bayılırsın." % Places.ATTEND_NEEDED, 9, Color(1, 1, 1, 0.75))
	popup.add_line("Güçlendikçe metrobüs kavgaları kolaylaşır. Zorluk: %s. %s" % [GameState.diff()["name"], GameState.diff()["desc"]], 9, Color("7dd3fc"))
	popup.add_choice("Hadi bakalım!", "ok")
	_open_popup(popup, func(_c):
		GameState.intro_seen = true
		GameState.save_game())


## Uyarı kartı. icon: "clock" (kapalı, saat dışı), "warn" (ünlem) ya da "" (oyuncunun portresi, ör. bayılınca).
func _notice(title: String, text: String, icon: String = "clock") -> void:
	var popup := ChoicePopup.new()
	popup.icon = icon
	popup.accent = Color("f59e0b")
	if icon == "":
		popup.portrait = GameState.portrait_texture("player", "hurt")
	popup.title = title
	popup.add_line(text, 10, Color(1, 1, 1, 0.85))
	popup.add_choice("Tamam", "ok")
	_open_popup(popup, func(_c): pass)


func _open_popup(popup, on_done: Callable) -> void:
	_busy = true
	_ui.add_child(popup)
	popup.chosen.connect(func(c: String):
		popup.queue_free()
		on_done.call(c)
		_busy = false)


# ---------------------------------------------------------------- Çizim
# Yollar, binalar ve ağaçlar bg_map.png içinde; burada sadece isimler ve seçim çerçevesi.

func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	for id in _spots:
		var r := _rect(id)
		var hot: bool = id == _hover
		if hot:
			_overlay.draw_rect(r.grow(3), Color("e6b428"), false, 2.0)
		var name: String = _spots[id]["name"]
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var lp := Vector2(clampf(r.get_center().x - w / 2.0, 4.0, 476.0 - w), r.position.y - 3)
		if lp.y < 32.0:   # durum çubuğuna değecekse etiket binanın altına
			lp.y = r.end.y + 10.0
		_overlay.draw_rect(Rect2(lp.x - 2, lp.y - 8, w + 4, 10), Color(0, 0, 0, 0.55))
		_overlay.draw_string(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e6b428") if hot else Color.WHITE)
	_overlay.draw_string(font, _map["line"][0], _map["line"][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.75))
	_overlay.draw_string(font, Vector2(6, 34), _map["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))