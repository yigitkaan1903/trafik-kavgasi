extends Control
## Mekanlarda konuşma kutusu: altta ortada küçük bir panel. Konuşanın adı, repliği ve
## kısa seçenekler. Esc ya da kutunun dışına tıklamak kapatır ("close" seçilmiş sayılır).

signal picked(id: String)

const WIDTH := 300.0

var speaker := ""
var line := ""
var _choices: Array = []   # {"text", "id", "disabled"}
var _done := false


func add_choice(text: String, id: String, disabled: bool = false) -> void:
	_choices.append({"text": text, "id": id, "disabled": disabled})


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_pick("close"))
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -6
	panel.custom_minimum_size.x = WIDTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(GameState.make_label(speaker, 10, Color("e6b428")))
	if line != "":
		var l := GameState.make_label("\"%s\"" % line, 9, Color(1, 1, 1, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH - 12
		box.add_child(l)
	var first: Button = null
	for c in _choices + [{"text": "Görüşürüz", "id": "close", "disabled": false}]:
		var b := Button.new()
		b.text = "›  " + c["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = c["disabled"]
		b.add_theme_font_size_override("font_size", 9)
		var id: String = c["id"]
		b.pressed.connect(func(): _pick(id))
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_pick("close")


func _pick(id: String) -> void:
	if _done:
		return
	_done = true
	picked.emit(id)
	queue_free()
