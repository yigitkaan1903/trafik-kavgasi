extends Control
## Ana menü. Yeni oyunda zorluk seçilir.

const ChoicePopup = preload("res://scenes/ui/choice_popup.gd")
const Places = preload("res://data/places.gd")

var _confirm_new := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite(GameState.car_texture("sahin", true), Vector2(40, 150), false)
	_sprite(GameState.car_texture("bmw", true), Vector2(344, 150), true)
	_sprite(GameState.fighter_texture("player", "idle"), Vector2(130, 116), false)
	_sprite(GameState.fighter_texture("selim", "idle"), Vector2(286, 116), true)

	var title := GameState.make_label("TRAFİK KAVGASI", 32, Color("e6b428"))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color("1b1024"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(480, 40)
	add_child(title)
	var sub := GameState.make_label("Yol kimin? Kavgayı kazanan söyler.", 10, Color(1, 1, 1, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 58)
	sub.size = Vector2(480, 14)
	add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(180, 100)
	box.custom_minimum_size = Vector2(120, 0)
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var first: Button = null
	if GameState.has_save():
		first = _button(box, "Devam et", func(): GameState.go_to(GameState.home_scene()))
	var new_btn := _button(box, "Yeni oyun", Callable())
	new_btn.pressed.connect(func():
		if GameState.has_save() and not _confirm_new:
			_confirm_new = true
			new_btn.text = "Emin misin? Kayıt silinir"
			return
		_choose_difficulty())
	_button(box, "Çıkış", func(): get_tree().quit())
	(first if first else new_btn).grab_focus.call_deferred()

	var foot := GameState.make_label("F11: tam ekran / pencere    ·    YTÜ Oyunlar", 8, Color(1, 1, 1, 0.45))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(0, 254)
	foot.size = Vector2(480, 12)
	add_child(foot)
	if OS.get_cmdline_user_args().has("--choose"):   # test: zorluk seçimini doğrudan aç
		_choose_difficulty()


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


func _draw() -> void:
	var top := Color("2b1e4a")
	var bottom := Color("f08a4b")
	for i in 19:
		draw_rect(Rect2(0, i * 10, 480, 10), top.lerp(bottom, i / 18.0))
	draw_circle(Vector2(240, 190), 40, Color("ffd27a"))
	draw_rect(Rect2(0, 190, 480, 80), Color("3a3a44"))
	draw_rect(Rect2(0, 190, 480, 3), Color("b4b4c0"))
	for lx in range(8, 480, 40):
		draw_rect(Rect2(lx, 236, 20, 2), Color("e8e8e8", 0.6))
