extends Control
## Seçim menüsü (berber, butik, silahçı): solda liste, bir seçeneğin üstüne gelince önizleme (on_preview),
## altta açıklama ve "Satın al / Giy" düğmesi. Görsel önizleme (image_for) verilirse sağda büyük bir kart çıkar.
## Esc ya da "Kapat" kapatır; closed sinyali gelir (çağıran önizlemeyi geri alır).

signal closed

const PANEL := Rect2(8, 26, 200, 236)
const ACCENT := Color("e6b428")

var title := ""
var subtitle := ""
## Satırlar: {"id", "name", "price", "desc", "action" (düğme yazısı), "disabled", "note"} ya da {"header": "Başlık"}
var items: Array = []
var on_preview: Callable     # func(item: Dictionary)
var on_buy: Callable         # func(item: Dictionary) -> String ("" ise oldu, değilse neden)
var image_for: Callable      # func(item: Dictionary) -> Texture2D (silah gibi görsel önizleme; yoksa kart çıkmaz)
var keep_open := true        # alım sonrası menü açık kalsın mı (butik: evet, berber: hayır)

var _sel: Dictionary = {}
var _list: VBoxContainer
var _desc: Label
var _buy: Button
var _msg: Label
var _img: TextureRect
var _img_name: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.position = PANEL.position
	panel.custom_minimum_size = PANEL.size
	panel.size = PANEL.size
	panel.add_theme_stylebox_override("panel", _card_style())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	box.add_child(GameState.make_label(title, 12, ACCENT))
	if subtitle != "":
		var st := GameState.make_label(subtitle, 7, Color(1, 1, 1, 0.6))
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size.x = PANEL.size.x - 20
		box.add_child(st)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL.size.x - 18, 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.3)
	line.custom_minimum_size.y = 1
	box.add_child(line)
	_desc = GameState.make_label("", 8, Color(1, 1, 1, 0.8))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(PANEL.size.x - 20, 22)
	box.add_child(_desc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_buy = UIDraw.flat_button("Satın al", ACCENT, 9)
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.pressed.connect(_on_buy)
	row.add_child(_buy)
	_buy.autowrap_mode = TextServer.AUTOWRAP_OFF
	_buy.clip_text = true
	var close_b := UIDraw.flat_button("Kapat", Color("ff8a7a"), 9)
	close_b.autowrap_mode = TextServer.AUTOWRAP_OFF
	close_b.pressed.connect(close)
	row.add_child(close_b)
	_msg = GameState.make_label("", 8, Color("ff8a7a"))
	_msg.position = Vector2(PANEL.position.x, PANEL.end.y + 1)
	add_child(_msg)
	if image_for.is_valid():   # sağda görsel önizleme kartı
		var card := PanelContainer.new()
		card.position = Vector2(300, 70)
		card.custom_minimum_size = Vector2(160, 150)
		card.add_theme_stylebox_override("panel", _card_style())
		add_child(card)
		var cb := VBoxContainer.new()
		card.add_child(cb)
		_img = TextureRect.new()
		_img.custom_minimum_size = Vector2(140, 118)
		_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cb.add_child(_img)
		_img_name = GameState.make_label("", 10, ACCENT)
		_img_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cb.add_child(_img_name)
	_rebuild()
	for arg in OS.get_cmdline_user_args():   # test: -- --pick=deri,fotr (sırayla seçip önizler)
		if arg.begins_with("--pick="):
			for id in arg.trim_prefix("--pick=").split(","):
				for it in items:
					if it.get("id", "-") == id:
						_select.call_deferred(it)


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("15121f", 0.95)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.set_content_margin_all(8)
	return sb


## Liste değişince (ör. alımdan sonra) yeniden kur; seçili satır korunur.
func set_items(new_items: Array) -> void:
	items = new_items
	_rebuild()


func _rebuild() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var first: Button = null
	var keep: Button = null
	for it in items:
		if it.has("header"):
			var h := GameState.make_label(it["header"], 8, Color(ACCENT, 0.8))
			_list.add_child(h)
			continue
		var text: String = it["name"]
		if it.get("note", "") != "":
			text += "  ·  " + it["note"]
		elif it.get("price", 0) > 0:
			text += "  ·  %d TL" % it["price"]
		var b := UIDraw.flat_button(text, ACCENT, 8)
		b.custom_minimum_size.x = PANEL.size.x - 30
		var item: Dictionary = it
		b.focus_entered.connect(func(): _select(item))
		b.pressed.connect(func(): _select(item); _buy.grab_focus())
		_list.add_child(b)
		if first == null:
			first = b
		if not _sel.is_empty() and it.get("id") == _sel.get("id"):
			keep = b
	var target: Button = keep if keep else first
	if target:
		target.grab_focus.call_deferred()


func _select(item: Dictionary) -> void:
	_sel = item
	_msg.text = ""
	_desc.text = item.get("desc", "")
	_buy.text = item.get("action", "Satın al")
	_buy.disabled = item.get("disabled", false)
	if on_preview.is_valid():
		on_preview.call(item)
	if _img:
		_img.texture = image_for.call(item)
		_img_name.text = item["name"]


func _on_buy() -> void:
	if _sel.is_empty() or not on_buy.is_valid():
		return
	var why: String = on_buy.call(_sel)
	if why != "":
		_msg.text = why
		return
	if not keep_open:
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()
