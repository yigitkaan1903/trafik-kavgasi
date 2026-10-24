extends Control
## Ana menü: hareketli gün batımı sahnesi (şehir silueti, akan yol, geçen arabalar), Devam / Yeni oyun /
## Ayarlar / Nasıl oynanır / Çıkış. Yeni oyunda zorluk seçilir. Ayarlar: müzik, efekt sesi, tam ekran, sarsıntı.

const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Places = preload("res://data/places.gd")
const VERSION := "v0.2"
const CAR_IDS := ["sahin", "taksi", "doblo", "passat", "dolmus", "tofas"]

var _confirm_new := false
var _t := 0.0
var _skyline: Array = []      # [Rect2, renk, ışıklı pencereler]
var _stars: Array = []
var _cars: Array = []         # [Sprite2D, hız]
var _title: Label
var _menu: VBoxContainer
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := -10.0
	while x < 500.0:   # iki kat şehir silueti
		var w := rng.randf_range(18, 40)
		var h := rng.randf_range(30, 90)
		var lights: Array = []
		for k in int(w * h / 90.0):
			if rng.randf() < 0.45:
				lights.append(Vector2(rng.randi_range(3, int(w) - 5), rng.randi_range(4, int(h) - 6)))
		_skyline.append([Rect2(x, 190 - h, w, h), Color("2a2140").lerp(Color("3a2a52"), rng.randf()), lights])
		x += w + rng.randf_range(0, 6)
	for k in 40:
		_stars.append(Vector3(rng.randf_range(0, 480), rng.randf_range(0, 90), rng.randf()))

	_sprite(GameState.fighter_texture("player", "idle"), Vector2(118, 116), false)
	_sprite(GameState.fighter_texture("selim", "idle"), Vector2(298, 116), true)
	for k in 3:
		_spawn_car(rng.randf_range(-80, 480))

	_title = GameState.make_label("TRAFİK KAVGASI", 32, Color("e6b428"))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color("1b1024"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 14)
	_title.size = Vector2(480, 40)
	add_child(_title)
	var sub := GameState.make_label("Beylikdüzü - Davutpaşa hattında bir YTÜ'lünün hayatta kalma hikâyesi", 9, Color(1, 1, 1, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 54)
	sub.size = Vector2(480, 14)
	add_child(sub)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(175, 86)
	_menu.custom_minimum_size = Vector2(130, 0)
	_menu.add_theme_constant_override("separation", 4)
	add_child(_menu)
	var first: Button = null
	if GameState.has_save():
		first = _button(_menu, "Devam et", func(): GameState.go_to(GameState.home_scene()))
	var new_btn := _button(_menu, "Yeni oyun", Callable())
	new_btn.pressed.connect(func():
		if GameState.has_save() and not _confirm_new:
			_confirm_new = true
			new_btn.text = "Emin misin? Kayıt silinir"
			return
		_choose_difficulty())
	_button(_menu, "Ayarlar", _open_settings)
	_button(_menu, "Nasıl oynanır?", _open_help)
	_button(_menu, "Çıkış", func(): get_tree().quit())
	(first if first else new_btn).grab_focus.call_deferred()

	var foot := GameState.make_label("%s   ·   F11: tam ekran   ·   YTÜ Oyunlar" % VERSION, 8, Color(1, 1, 1, 0.45))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, 256)
	foot.size = Vector2(480, 12)
	add_child(foot)
	if OS.get_cmdline_user_args().has("--choose"):   # test: zorluk seçimini doğrudan aç
		_choose_difficulty()
	if OS.get_cmdline_user_args().has("--settings"):
		_open_settings()


func _process(delta: float) -> void:
	_t += delta
	_title.position.y = 14 + roundf(sin(_t * 1.6) * 2.0)
	for c in _cars:
		var sp: Sprite2D = c[0]
		sp.position.x += c[1] * delta
		if (c[1] > 0 and sp.position.x > 500) or (c[1] < 0 and sp.position.x < -120):
			sp.position.x = -110 if c[1] > 0 else 500
			sp.texture = GameState.car_texture(CAR_IDS.pick_random(), true)
	queue_redraw()


func _spawn_car(x: float) -> void:
	var s := Sprite2D.new()
	s.texture = GameState.car_texture(CAR_IDS.pick_random(), true)
	s.centered = false
	s.scale = Vector2(2, 2)
	var dir := 1.0 if _cars.size() % 2 == 0 else -1.0
	s.flip_h = dir < 0
	s.position = Vector2(x, 196 if dir > 0 else 222)
	add_child(s)
	move_child(s, 0)
	_cars.append([s, dir * randf_range(60, 110)])


## Zorluk seçimi: her seçeneğin ne yaptığı altında yazar.
func _choose_difficulty() -> void:
	var popup := ChoicePopup.new()
	popup.portrait = GameState.fighter_texture("player", "idle")
	popup.title = "Zorluk seç"
	popup.add_line("Gymde kazandığın güç, antrenman yapmadığın günlerde ne kadar azalsın? Zorluk bunu belirler.", 9, Color(1, 1, 1, 0.75))
	for id in Places.DIFFICULTIES:
		var d: Dictionary = Places.DIFFICULTIES[id]
		popup.add_choice(d["name"] + ("  (önerilen)" if id == "normal" else ""), id, false, d["desc"])
	add_child(popup)
	popup.chosen.connect(func(id: String):
		GameState.new_game(id)
		GameState.save_game()
		GameState.go_to(GameState.SCENE_MAP))


# ---------------------------------------------------------------- Ayarlar ve yardım

## Ortada açılan panel; kapatınca menü butonları geri gelir.
func _panel(title: String) -> VBoxContainer:
	_menu.visible = false
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(110, 70)
	panel.custom_minimum_size = Vector2(260, 0)
	_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	box.add_child(GameState.make_label(title, 12, Color("e6b428")))
	return box


func _close_panel() -> void:
	GameState.save_settings()
	_overlay.queue_free()
	_menu.visible = true
	(_menu.get_child(0) as Button).grab_focus()


func _open_settings() -> void:
	var box := _panel("Ayarlar")
	_slider(box, "Müzik sesi", Audio.music_volume, func(v: float): Audio.music_volume = v)
	_slider(box, "Efekt sesi", Audio.sfx_volume, func(v: float):
		Audio.sfx_volume = v
		Audio.sfx("coin", 0.8, 0.0))
	_check(box, "Tam ekran (F11)", GameState.fullscreen, func(on: bool): GameState.set_fullscreen(on))
	_check(box, "Dövüşte ekran sarsıntısı", GameState.screen_shake, func(on: bool): GameState.screen_shake = on)
	var back := _button(box, "Kaydet ve dön", _close_panel)
	back.grab_focus.call_deferred()


func _open_help() -> void:
	var box := _panel("Nasıl oynanır?")
	for line in [
		"WASD / oklar: yürü    E: konuş, kullan, otur, bin    T: telefon    Esc: geri",
		"Gün kısıtlı: gymde antrenman yap, çarşıda çalış, haftada 3 gün derse git, yemek ye.",
		"Metrobüste sıranı bekle ya da kaynak yap; koltuk kap, laf atanla kavga et.",
		"Dövüş: J yumruk, K tekme, L blok, Boşluk kaç. W/S ile rakiple aynı hizaya gel.",
		"Butikten kıyafet, hırdavattan silah al; evdeki gardıroptan giy ve çantana koy.",
		"Gece 02:00'den önce yat, yoksa bayılırsın!"]:
		var l := GameState.make_label(line, 9, Color(1, 1, 1, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 250
		box.add_child(l)
	_button(box, "Tamam", _close_panel).grab_focus.call_deferred()


func _slider(parent: Control, text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := GameState.make_label(text, 9)
	l.custom_minimum_size.x = 90
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(120, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := GameState.make_label("%d%%" % int(value * 100), 9, Color(1, 1, 1, 0.7))
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		on_change.call(v))
	row.add_child(s)
	row.add_child(pct)


func _check(parent: Control, text: String, on: bool, on_toggle: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 9)
	c.toggled.connect(on_toggle)
	parent.add_child(c)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if action.is_valid():
		b.pressed.connect(action)
	parent.add_child(b)
	return b


func _sprite(tex: Texture2D, pos: Vector2, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(2, 2)
	s.flip_h = flip
	s.position = pos
	add_child(s)


# ---------------------------------------------------------------- Arka plan

func _draw() -> void:
	var top := Color("1b1436")
	var mid := Color("6a2f5a")
	var bottom := Color("f08a4b")
	for i in 19:   # gökyüzü: lacivertten mora, turuncuya
		var k := i / 18.0
		draw_rect(Rect2(0, i * 10, 480, 10), top.lerp(mid, k * 2.0) if k < 0.5 else mid.lerp(bottom, (k - 0.5) * 2.0))
	for st in _stars:
		var a: float = 0.3 + 0.5 * absf(sin(_t * 1.5 + st.z * 10.0))
		draw_rect(Rect2(st.x, st.y, 1, 1), Color(1, 1, 1, a))
	draw_circle(Vector2(240, 176), 42, Color("ffb86a", 0.35))
	draw_circle(Vector2(240, 178), 34, Color("ffd27a"))
	for b in _skyline:
		var r: Rect2 = b[0]
		draw_rect(r, b[1])
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(b[1]).lightened(0.15))
		for w in b[2]:
			var on: bool = int(_t * 0.3 + w.x * 7 + w.y) % 9 != 0
			if on:
				draw_rect(Rect2(r.position + w, Vector2(2, 2)), Color("ffd27a", 0.85))
	draw_rect(Rect2(0, 190, 480, 80), Color("2e2e38"))
	draw_rect(Rect2(0, 190, 480, 3), Color("b4b4c0"))
	draw_rect(Rect2(0, 250, 480, 20), Color("3a3a44"))
	var shift := fposmod(_t * 80.0, 40.0)
	for lx in range(-40, 520, 40):
		draw_rect(Rect2(lx - shift, 228, 20, 2), Color("e8e8e8", 0.6))
