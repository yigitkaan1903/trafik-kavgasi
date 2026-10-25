extends Control
## Ana menü: solda koyu panel üstünde logo ve seçenekler, arkada hareketli gün batımı (iki kat şehir silueti,
## E-5'te akan arabalar ve metrobüs). Devam / Yeni oyun / Ayarlar /
## Nasıl oynanır / Çıkış. Yeni oyunda zorluk seçilir. Ayarlar: müzik, efekt sesi, tam ekran, sarsıntı.

const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Places = preload("res://data/places.gd")
const VERSION := "v0.4"
const CAR_IDS := ["sahin", "taksi", "doblo", "passat", "dolmus", "tofas", "toros", "egea", "golf", "mercedes", "bmw"]
const BUS_TEX := preload("res://assets/pixellab/map/metrobus.png")
const MENU_POS := Vector2(26, 104)
const ITEM_SIZE := Vector2(150, 18)
const ROAD_Y := 184.0
const LANES := [198.0, 238.0]          # üst şerit sola, alt şerit sağa akar (araba alt kenarı)

var _confirm_new := false
var _t := 0.0
var _far: Array = []          # uzak siluet: [Rect2, renk]
var _near: Array = []         # yakın siluet: [Rect2, renk, ışıklı pencereler]
var _stars: Array = []
var _cars: Array = []         # [Sprite2D, hız]
var _bus: Sprite2D
var _menu: VBoxContainer
var _overlay: Control
var _fade: ColorRect
var _hint: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := -10.0
	while x < 500.0:   # uzak siluet: sade, soluk
		var w := rng.randf_range(14, 30)
		_far.append([Rect2(x, ROAD_Y - rng.randf_range(50, 110), w, 120), Color("3b2a55").lerp(Color("4a3466"), rng.randf())])
		x += w + rng.randf_range(-2, 4)
	x = -10.0
	while x < 500.0:   # yakın siluet: koyu, pencereleri yanar
		var w := rng.randf_range(20, 44)
		var h := rng.randf_range(30, 80)
		var lights: Array = []
		for k in int(w * h / 70.0):
			if rng.randf() < 0.4:
				lights.append(Vector2(rng.randi_range(3, int(w) - 5), rng.randi_range(4, int(h) - 6)))
		_near.append([Rect2(x, ROAD_Y - h, w, h), Color("1d1630").lerp(Color("2a1f42"), rng.randf()), lights])
		x += w + rng.randf_range(2, 10)
	for k in 50:
		_stars.append(Vector3(rng.randf_range(0, 480), rng.randf_range(0, 80), rng.randf()))

	_bus = Sprite2D.new()   # metrobüs, kırmızı şeritte arada bir geçer
	_bus.texture = BUS_TEX
	_bus.centered = false
	_bus.position = Vector2(-400, 222 - BUS_TEX.get_height() + 6)
	add_child(_bus)
	for k in 5:
		_spawn_car(rng.randf_range(-60, 480), k % 2)

	var shade := Control.new()   # solda koyu panel (sağa doğru saydamlaşır)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func():
		for i in 60:
			var k := i / 59.0
			shade.draw_rect(Rect2(i * 4, 0, 4, 270), Color(0.05, 0.04, 0.09, 0.88 * (1.0 - k * k)))
		shade.draw_rect(Rect2(26, 82, 46, 2), Color("e8463c"))
		shade.draw_rect(Rect2(74, 82, 18, 2), UIDraw.GOLD))
	add_child(shade)

	var logo1 := _logo("TRAFİK", Vector2(24, 18), Color("e6b428"))
	var logo2 := _logo("KAVGASI", Vector2(24, 46), Color("f4f2ec"))
	logo1.modulate.a = 0.0
	logo2.modulate.a = 0.0
	var sub := GameState.make_label("Beylikdüzü – Davutpaşa hattında bir YTÜ'lünün\nhayatta kalma hikâyesi", 8, Color(1, 1, 1, 0.7))
	sub.position = Vector2(26, 86)
	add_child(sub)

	_menu = VBoxContainer.new()
	_menu.position = MENU_POS + Vector2(0, 14)
	_menu.add_theme_constant_override("separation", 3)
	add_child(_menu)
	var first: Button = null
	if GameState.has_save():
		first = _button(_menu, "Devam et", func(): GameState.go_to(GameState.home_scene()), _save_summary())
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

	_hint = Control.new()   # alt şerit: tuş ipuçları ve sürüm
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(_draw_hint)
	add_child(_hint)

	_fade = ColorRect.new()   # açılışta karanlıktan gelir
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(logo1, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tw.parallel().tween_property(logo2, "modulate:a", 1.0, 0.5).set_delay(0.35)
	for i in _menu.get_child_count():   # seçenekler sırayla soldan kayarak gelir
		var b: Control = _menu.get_child(i)
		b.modulate.a = 0.0
		var t2 := create_tween()
		t2.tween_interval(0.35 + i * 0.06)
		t2.tween_property(b, "modulate:a", 1.0, 0.25)

	if OS.get_cmdline_user_args().has("--choose"):   # test: zorluk seçimini doğrudan aç
		_choose_difficulty()
	if OS.get_cmdline_user_args().has("--settings"):
		_open_settings()


func _process(delta: float) -> void:
	_t += delta
	for c in _cars:
		var sp: Sprite2D = c[0]
		sp.position.x += c[1] * delta
		if (c[1] > 0 and sp.position.x > 500) or (c[1] < 0 and sp.position.x < -80):
			sp.position.x = -70 - randf() * 120 if c[1] > 0 else 500 + randf() * 120
			sp.texture = GameState.car_texture(CAR_IDS.pick_random(), true)
			sp.position.y = (LANES[1] if c[1] > 0 else LANES[0]) - sp.texture.get_height()
	_bus.position.x += 70.0 * delta
	if _bus.position.x > 520:
		_bus.position.x = -BUS_TEX.get_width() - 500
	queue_redraw()


## Kayıttaki gün, saat ve para (Devam et'in altında küçük yazı).
func _save_summary() -> String:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return ""
	var m := int(d.get("minute", 0))
	var money := "∞" if d.get("difficulty", "") == "god" else str(int(d.get("money", 0)))
	return "%d. gün  ·  %02d:%02d  ·  %s TL" % [int(d.get("day", 1)), (m / 60) % 24, m % 60, money]


func _logo(text: String, pos: Vector2, color: Color) -> Label:
	var l := GameState.make_label(text, 30, color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color("120c1e"))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.position = pos
	add_child(l)
	return l


func _spawn_car(x: float, lane: int) -> void:
	var s := Sprite2D.new()
	s.texture = GameState.car_texture(CAR_IDS.pick_random(), true)
	s.centered = false
	var dir := -1.0 if lane == 0 else 1.0
	s.flip_h = dir < 0
	s.position = Vector2(x, LANES[lane] - s.texture.get_height())
	add_child(s)
	_cars.append([s, dir * randf_range(70, 120)])


## Zorluk seçimi: her seçeneğin ne yaptığı altında yazar.
func _choose_difficulty() -> void:
	var popup := ChoicePopup.new()
	popup.portrait = GameState.portrait_texture(GameState.player_look())
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

## Sağda açılan kart; kapatınca menü seçenekleri geri gelir.
func _panel(title: String) -> VBoxContainer:
	_menu.visible = false
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	move_child(_overlay, _hint.get_index())
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(card)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 112)
	box.custom_minimum_size = Vector2(260, 0)
	box.add_theme_constant_override("separation", 5)
	_overlay.add_child(box)
	card.draw.connect(func():
		UIDraw.card(card, Rect2(box.position - Vector2(10, 10), box.size + Vector2(20, 20))))
	box.resized.connect(card.queue_redraw)
	box.add_child(GameState.make_label(title, 12, UIDraw.GOLD))
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
		var l := GameState.make_label(line, 8, Color(1, 1, 1, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 260
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


## Menü seçeneği: düz yazı; üstüne gelince/seçilince altın vurgu, solda çubuk ve ok, hafif sağa kayma.
## note: altında küçük açıklama (ör. kayıt özeti).
func _button(parent: Control, text: String, action: Callable, note: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = ITEM_SIZE + Vector2(0, 8 if note != "" else 0)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	b.add_theme_color_override("font_hover_color", UIDraw.GOLD)
	b.add_theme_color_override("font_focus_color", UIDraw.GOLD)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 10
	if note != "":
		empty.content_margin_bottom = 8
	var hot := StyleBoxFlat.new()
	hot.bg_color = Color(0.9, 0.7, 0.16, 0.14)
	hot.border_color = UIDraw.GOLD
	hot.border_width_left = 2
	hot.content_margin_left = 16
	hot.content_margin_bottom = empty.content_margin_bottom
	hot.set_corner_radius_all(2)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, hot)
	if action.is_valid():
		b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func(): Audio.sfx("click", 0.4))
	if note != "":
		var n := GameState.make_label(note, 7, Color(1, 1, 1, 0.45))
		n.position = Vector2(10, 14)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
		b.focus_entered.connect(func(): n.position.x = 16)
		b.focus_exited.connect(func(): n.position.x = 10)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- Arka plan

func _draw() -> void:
	var sky := [Color("120d2a"), Color("3a1f5c"), Color("8a3a6a"), Color("f0884a"), Color("ffc46a")]
	for i in 92:   # gökyüzü: yumuşak geçiş
		var k := i / 91.0 * (sky.size() - 1)
		var j := mini(int(k), sky.size() - 2)
		draw_rect(Rect2(0, i * 2, 480, 2), sky[j].lerp(sky[j + 1], k - j))
	for st in _stars:
		var a: float = 0.25 + 0.5 * absf(sin(_t * 1.3 + st.z * 10.0))
		draw_rect(Rect2(st.x, st.y, 1, 1), Color(1, 1, 1, a))
	var sun := Vector2(330, 150)
	draw_circle(sun, 52, Color("ffb86a", 0.18))
	draw_circle(sun, 40, Color("ffc87a", 0.35))
	draw_circle(sun, 30, Color("ffe0a0"))
	for k in 4:   # güneşte yatay boşluklar
		draw_rect(Rect2(sun.x - 32, sun.y + 6 + k * 6, 64, 1 + k * 0.5), sky[3].lerp(sky[4], 0.4))
	var drift := fposmod(_t * 4.0, 480.0)
	for b in _far:
		var r: Rect2 = b[0]
		draw_rect(Rect2(fposmod(r.position.x - drift + 20, 520) - 20, r.position.y, r.size.x, r.size.y), b[1])
	for b in _near:
		var r: Rect2 = b[0]
		draw_rect(r, b[1])
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(b[1]).lightened(0.2))
		for w in b[2]:
			if int(_t * 0.4 + w.x * 7 + w.y) % 11 != 0:
				draw_rect(Rect2(r.position + w, Vector2(2, 2)), Color("ffd27a", 0.8))
	# E-5: kaldırım, iki şerit, ortada kırmızı metrobüs yolu
	draw_rect(Rect2(0, ROAD_Y, 480, 86), Color("2b2a35"))
	draw_rect(Rect2(0, ROAD_Y, 480, 3), Color("a8a6b4"))
	draw_rect(Rect2(0, 206, 480, 18), Color("7a2a32"))
	draw_rect(Rect2(0, 205, 480, 1), Color("d8d6e0")); draw_rect(Rect2(0, 224, 480, 1), Color("d8d6e0"))
	var shift := fposmod(_t * 90.0, 32.0)
	for lx in range(-32, 520, 32):
		draw_rect(Rect2(lx - shift, 244, 14, 1), Color(1, 1, 1, 0.4))
	draw_rect(Rect2(0, 250, 480, 20), Color("1b1a24"))
	for lx in range(10, 480, 60):   # direk lambaları
		draw_rect(Rect2(lx, ROAD_Y - 22, 1, 22), Color("4a4858"))
		draw_rect(Rect2(lx, ROAD_Y - 23, 5, 1), Color("4a4858"))
		draw_circle(Vector2(lx + 4, ROAD_Y - 21), 5, Color("ffd27a", 0.12))
		draw_rect(Rect2(lx + 3, ROAD_Y - 22, 2, 1), Color("ffe6a8"))


func _draw_hint() -> void:
	var y := 256.0
	_hint.draw_rect(Rect2(0, 252, 480, 18), Color(0.04, 0.03, 0.08, 0.85))
	_hint.draw_rect(Rect2(0, 252, 480, 1), Color(UIDraw.GOLD, 0.5))
	var x := 12.0
	x += UIDraw.keycap(_hint, Vector2(x, y), "↑↓") + 4
	_hint.draw_string(ThemeDB.fallback_font, Vector2(x, y + 8.5), "seç", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIDraw.TEXT_DIM)
	x += 26
	x += UIDraw.keycap(_hint, Vector2(x, y), "Enter") + 4
	_hint.draw_string(ThemeDB.fallback_font, Vector2(x, y + 8.5), "onayla", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIDraw.TEXT_DIM)
	x += 40
	x += UIDraw.keycap(_hint, Vector2(x, y), "F11") + 4
	_hint.draw_string(ThemeDB.fallback_font, Vector2(x, y + 8.5), "tam ekran", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIDraw.TEXT_DIM)
	_hint.draw_string(ThemeDB.fallback_font, Vector2(0, y + 8.5), VERSION + "   ", HORIZONTAL_ALIGNMENT_RIGHT, 476, 8, Color(1, 1, 1, 0.4))
