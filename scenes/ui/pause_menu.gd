extends CanvasLayer
## Duraklatma menüsü (oyun içinde Esc): Devam et / Ayarlar / Ana menüye dön. Açıkken oyun durur.
## Kullanım: PauseMenu.open(self) — zaten açıksa ikinci kez açılmaz.

const CARD := Rect2(140, 60, 200, 150)

var _box: VBoxContainer
var _card: Control


static func open(scene: Node) -> void:
	for ch in scene.get_children():
		if ch.has_meta("pause_menu"):
			return
	var m = load("res://scenes/ui/pause_menu.gd").new()
	m.set_meta("pause_menu", true)
	scene.add_child(m)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(func(): UIDraw.card(_card, Rect2(_box.position - Vector2(12, 12), _box.size + Vector2(24, 24))))
	add_child(_card)
	_box = VBoxContainer.new()
	_box.position = CARD.position
	_box.custom_minimum_size.x = CARD.size.x
	_box.add_theme_constant_override("separation", 4)
	_box.resized.connect(_card.queue_redraw)
	add_child(_box)
	_main_page()


func _clear() -> VBoxContainer:
	for ch in _box.get_children():
		ch.queue_free()
	return _box


func _title(text: String) -> void:
	var l := GameState.make_label(text, 12, UIDraw.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _button(text: String, action: Callable, accent: Color = UIDraw.GOLD) -> Button:
	var b := UIDraw.flat_button(text, accent, 10)
	b.pressed.connect(action)
	_box.add_child(b)
	return b


func _main_page() -> void:
	_clear()
	_title("Oyun durdu")
	var first := _button("Devam et", close)
	_button("Ayarlar", _settings_page)
	_button("Ana menüye dön", func():
		get_tree().paused = false
		GameState.save_game()
		GameState.go_to(GameState.SCENE_MENU), Color("ff8a7a"))
	first.grab_focus.call_deferred()


func _settings_page() -> void:
	_clear()
	_title("Ayarlar")
	_slider("Müzik", Audio.music_volume, func(v: float): Audio.music_volume = v)
	_slider("Efekt", Audio.sfx_volume, func(v: float):
		Audio.sfx_volume = v
		Audio.sfx("coin", 0.8, 0.0))
	_check("Tam ekran (F11)", GameState.fullscreen, func(on: bool): GameState.set_fullscreen(on))
	_check("Dövüşte ekran sarsıntısı", GameState.screen_shake, func(on: bool): GameState.screen_shake = on)
	var back := _button("Geri", func():
		GameState.save_settings()
		_main_page())
	back.grab_focus.call_deferred()


func _slider(text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)
	var l := GameState.make_label(text, 9)
	l.custom_minimum_size.x = 44
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(110, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := GameState.make_label("%d%%" % int(value * 100), 9, Color(1, 1, 1, 0.7))
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		on_change.call(v))
	row.add_child(s)
	row.add_child(pct)


func _check(text: String, on: bool, on_toggle: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 9)
	c.toggled.connect(on_toggle)
	_box.add_child(c)


func close() -> void:
	GameState.save_settings()
	get_tree().paused = false
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()
