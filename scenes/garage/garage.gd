extends Control
## Oto Galeri: araba yükseltme ve tamir, araba alım-satım. (Güçlenmek artık gymde.)

const Cars = preload("res://data/cars.gd")

const TABS := ["Arabam", "Galeri"]

var _tab := 0
var _money_label: Label
var _showcase: VBoxContainer
var _tab_bar: HBoxContainer
var _content: VBoxContainer
var _message: Label
var _drive_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := GameState.make_label("OTO GALERİ", 14, Color("e6b428"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_money_label = GameState.make_label("", 14, Color("e6b428"))
	top.add_child(_money_label)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)
	var show_panel := PanelContainer.new()
	show_panel.custom_minimum_size.x = 150
	main.add_child(show_panel)
	_showcase = VBoxContainer.new()
	show_panel.add_child(_showcase)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	_tab_bar = HBoxContainer.new()
	right.add_child(_tab_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 3)
	scroll.add_child(_content)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)
	_message = GameState.make_label("", 10, Color("ff9a7a"))
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_message)
	var metro := Button.new()
	metro.text = "Galeriye dön"
	metro.pressed.connect(_on_metro)
	bottom.add_child(metro)
	_drive_button = Button.new()
	_drive_button.text = "Trafiğe çık!"
	_drive_button.pressed.connect(_on_drive)
	bottom.add_child(_drive_button)
	if not GameState.has_car():
		_tab = 1
	(_drive_button if GameState.has_car() else metro).grab_focus.call_deferred()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_on_metro()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c1a24"))
	for x in range(0, int(size.x), 24):
		draw_rect(Rect2(x, 0, 1, size.y), Color("24212e"))


func _on_drive() -> void:
	if GameState.car()["damage"] >= GameState.car_max_hp():
		_message.text = "Araban hurda! Önce tamir ettir."
		return
	GameState.save_game()
	GameState.go_to(GameState.SCENE_TRAFFIC)


func _on_metro() -> void:
	GameState.save_game()
	GameState.open_place_scene("galeri")


# ---------------------------------------------------------------- Ekranı yeniden kur

func _refresh() -> void:
	_money_label.text = "%d TL" % GameState.money
	_drive_button.disabled = not GameState.has_car()
	_fill_showcase()
	for c in _tab_bar.get_children():
		c.queue_free()
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.button_pressed = i == _tab
		b.pressed.connect(func():
			_tab = i
			_message.text = ""
			_refresh())
		_tab_bar.add_child(b)
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		0: _fill_my_car()
		1: _fill_shop()


func _fill_showcase() -> void:
	for c in _showcase.get_children():
		c.queue_free()
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(112, 44)
	_showcase.add_child(pic)
	if GameState.has_car():
		var car := GameState.car()
		var info := GameState.car_info()
		pic.texture = GameState.car_texture(car["id"], true)
		_showcase.add_child(GameState.make_label(info["name"], 11, Color("e6b428")))
		var desc := GameState.make_label(info["desc"], 8, Color(1, 1, 1, 0.6))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 136
		_showcase.add_child(desc)
		var hp := GameState.car_max_hp()
		_showcase.add_child(GameState.make_label("Hız: x%.2f" % GameState.car_speed(), 9))
		_showcase.add_child(GameState.make_label("Kaporta: %d / %d   Korna: %d" % [hp - car["damage"], hp, car["horn"]], 9,
				Color("ff6a4a") if car["damage"] > 0 else Color.WHITE))
	else:
		pic.texture = GameState.fighter_texture("player", "idle")
		_showcase.add_child(GameState.make_label("Araban yok", 11, Color("e6b428")))
		var desc := GameState.make_label("Öğrenci kartıyla metrobüs. İlk araba: %s, %d TL." % [
				GameState.cheapest_car()["name"], GameState.cheapest_car()["price"]], 8, Color(1, 1, 1, 0.6))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 136
		_showcase.add_child(desc)
	_showcase.add_child(GameState.make_label("Sen", 11, Color("e6b428")))
	_showcase.add_child(GameState.make_label("Güç %d   Çev %d   Day %d" % [int(GameState.stats["str"]), int(GameState.stats["agi"]), int(GameState.stats["sta"])], 9))
	_showcase.add_child(GameState.make_label("Galibiyet: %d   Yenilgi: %d" % [GameState.wins, GameState.losses], 9))
	var scared := 0
	for id in GameState.nam:
		if GameState.fear_level(id) > 0:
			scared += 1
	_showcase.add_child(GameState.make_label("Nam: %d rakip senden çekiniyor" % scared, 9, Color("7dd3fc")))


func _row(title: String, desc: String, button_text: String, enabled: bool, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	texts.add_child(GameState.make_label(title, 10))
	if desc != "":
		texts.add_child(GameState.make_label(desc, 8, Color(1, 1, 1, 0.55)))
	if button_text != "":
		var b := Button.new()
		b.text = button_text
		b.custom_minimum_size.x = 92
		b.disabled = not enabled
		b.pressed.connect(func():
			action.call()
			GameState.save_game()
			_refresh())
		row.add_child(b)


func _header(text: String) -> void:
	_content.add_child(GameState.make_label(text, 10, Color("e6b428")))


## Fiyat butonu: yeterli para varsa harcar, yoksa uyarı verir.
func _buy(cost: int, what: Callable) -> Callable:
	return func():
		if GameState.try_spend(cost):
			what.call()
			_message.text = ""
		else:
			_message.text = "Paran yetmiyor! Biraz daha kavga lazım."


# ---------------------------------------------------------------- Sekmeler

func _fill_my_car() -> void:
	if not GameState.has_car():
		_header("Henüz araban yok")
		_content.add_child(GameState.make_label("Metrobüs kavgalarıyla para biriktir, sonra Galeri'den ilk arabanı al.", 9, Color(1, 1, 1, 0.7)))
		return
	var car := GameState.car()
	_header("Yükseltmeler")
	for key in GameState.UPGRADES:
		var u: Dictionary = GameState.UPGRADES[key]
		var lvl: int = car[key]
		var maxed: bool = lvl >= u["max"]
		var cost := GameState.upgrade_cost(u["base"], lvl)
		_row("%s  (%d/%d)" % [u["name"], lvl, u["max"]], u["desc"],
				"MAX" if maxed else "%d TL" % cost, not maxed,
				_buy(cost, func(): car[key] += 1))
	if car["damage"] > 0:
		var cost := GameState.repair_cost()
		_row("Tamir", "%d kaporta hasarı" % car["damage"], "%d TL" % cost, true,
				_buy(cost, func(): car["damage"] = 0))

	_header("Arabalarım")
	for i in GameState.cars.size():
		var c: Dictionary = GameState.cars[i]
		var info := GameState.car_info(c["id"])
		var active := i == GameState.active_car
		var desc := "Motor %d  Kaporta %d  Korna %d" % [c["engine"], c["armor"], c["horn"]]
		if active:
			_row(info["name"] + "  (aktif)", desc, "", false, Callable())
			continue
		_row(info["name"], desc, "Seç", true, func(): GameState.active_car = i)
		var price := GameState.sell_price(c["id"])
		_row("", "", "Sat +%d TL" % price, true, func():
			GameState.money += price
			GameState.cars.remove_at(i)
			if GameState.active_car > i:
				GameState.active_car -= 1)


func _fill_shop() -> void:
	_header("Galeri (ikinci el, az kullanılmış)")
	for id in Cars.CARS:
		var info: Dictionary = Cars.CARS[id]
		if not info["shop"]:
			continue
		var price: int = info["price"]
		_row(info["name"], "Hız x%.2f  Kaporta %d - %s" % [info["speed"], info["hp"], info["desc"]],
				"%d TL" % price, true, _buy(price, func():
					GameState.cars.append(GameState._new_car(id))
					GameState.active_car = GameState.cars.size() - 1))
	_content.add_child(GameState.make_label("Bazı arabalar satılmaz, sadece iddiayla kazanılır...", 8, Color(1, 1, 1, 0.5)))
