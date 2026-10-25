extends Control
## Mekanlarda konuşma kutusu (altta): solda replik (harf harf yazılır) ve seçenekler, sağda çerçeveli
## büyük portre ve altında isim plakası. Portre yoksa isim yazı panelinin başında durur.
## Esc ya da kutunun dışına tıklamak kapatır ("close" seçilmiş sayılır).

signal picked(id: String)

const TEXT_W := 300.0
const FRAME := Color("e6b428")
const TYPE_SPEED := 60.0          # saniyede harf

var speaker := ""
var line := ""
var portrait: Texture2D
var _choices: Array = []   # {"text", "id", "disabled"}
var _done := false
var _line_label: Label
var _typing: Tween


func add_choice(text: String, id: String, disabled: bool = false) -> void:
	_choices.append({"text": text, "id": id, "disabled": disabled})


func _frame_style(bg: Color, radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = FRAME
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(9)
	return sb


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_pick("close"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -6
	add_child(row)

	# yazı paneli
	var text_panel := PanelContainer.new()
	text_panel.add_theme_stylebox_override("panel", _frame_style(Color("17131f", 0.97)))
	text_panel.custom_minimum_size = Vector2(TEXT_W, 124 if portrait else 0)
	text_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(text_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	text_panel.add_child(box)
	if not portrait and speaker != "":
		box.add_child(GameState.make_label(speaker, 10, FRAME))
		var sep := ColorRect.new()
		sep.color = Color(FRAME, 0.3)
		sep.custom_minimum_size.y = 1
		box.add_child(sep)
	if line != "":
		_line_label = GameState.make_label(line, 10, Color("f4efe2"))
		_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line_label.custom_minimum_size.x = TEXT_W - 20
		_line_label.visible_ratio = 0.0
		box.add_child(_line_label)
		_typing = create_tween()
		_typing.tween_property(_line_label, "visible_ratio", 1.0, maxf(0.2, line.length() / TYPE_SPEED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.y = 4
	box.add_child(spacer)
	var first: Button = null
	for c in _choices + [{"text": "Görüşürüz", "id": "close", "disabled": false}]:
		var b := UIDraw.flat_button("›  " + c["text"], FRAME, 9)
		b.disabled = c["disabled"]
		b.custom_minimum_size.x = TEXT_W - 20
		var id: String = c["id"]
		b.pressed.connect(func(): _pick(id))
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()

	# portre paneli: iç çerçevede portre, altında isim plakası
	if portrait:
		var side := PanelContainer.new()
		side.add_theme_stylebox_override("panel", _frame_style(Color("231c33", 0.97)))
		side.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(side)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		side.add_child(col)
		var inner := PanelContainer.new()
		var isb := StyleBoxFlat.new()
		isb.bg_color = Color("3a3156")
		isb.border_color = Color("120e1a")
		isb.set_border_width_all(1)
		isb.set_corner_radius_all(3)
		isb.set_content_margin_all(1)
		inner.add_theme_stylebox_override("panel", isb)
		col.add_child(inner)
		var pic := TextureRect.new()
		pic.texture = portrait
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(96, 96)
		inner.add_child(pic)
		var plate := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color("e8c770")
		psb.border_color = Color("8e611a")
		psb.set_border_width_all(1)
		psb.set_corner_radius_all(3)
		psb.content_margin_top = 1
		psb.content_margin_bottom = 1
		plate.add_theme_stylebox_override("panel", psb)
		col.add_child(plate)
		var name_l := GameState.make_label(speaker, 9 if speaker.length() <= 16 else 7, Color("2a1a10"))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.custom_minimum_size.x = 96
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		plate.add_child(name_l)
	# açılış: alttan hafifçe kayarak gelir
	row.modulate.a = 0.0
	row.position.y += 8
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "modulate:a", 1.0, 0.15)
	tw.tween_property(row, "position:y", row.position.y - 8, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_pick("close")
	elif event.is_action_pressed("interact") and _typing and _typing.is_running():   # E: yazıyı hemen tamamla
		get_viewport().set_input_as_handled()
		_typing.kill()
		_line_label.visible_ratio = 1.0


func _pick(id: String) -> void:
	if _done:
		return
	_done = true
	picked.emit(id)
	queue_free()
