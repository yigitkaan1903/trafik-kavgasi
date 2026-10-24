extends CenterContainer
## Ortak seçim penceresi: solda portre, sağda başlık, metin satırları ve butonlar.
## Trafikteki karşılaşmalar ve metrobüs olayları bunu kullanır.

signal chosen(id: String)

var portrait: Texture2D
var title := ""
var _lines: Array = []     # [metin, boyut, renk]
var _choices: Array = []   # {"text", "id", "disabled", "note"}


func add_line(text: String, size: int = 10, color: Color = Color.WHITE) -> void:
	_lines.append([text, size, color])


func add_choice(text: String, id: String, disabled: bool = false, note: String = "") -> void:
	_choices.append({"text": text, "id": id, "disabled": disabled, "note": note})


## Rakip karşılaşmalarında ortak butonlar: kavga, gözdağı (rakip senden korkuyorsa önce o).
func add_rival_choices(rival_id: String, fight_text: String) -> void:
	var r := GameState.rival(rival_id)
	if GameState.is_scared(rival_id):
		add_choice("Gözdağı ver: \"Bir dahakine dikkat et.\"  (+%d TL)" % GameState.intimidate_reward(rival_id), "intimidate")
		add_choice("Yine de dövüş  (kazanırsan +%d TL)" % GameState.fight_reward(rival_id), "fight")
	else:
		add_choice("%s  (kazanırsan +%d TL)" % [fight_text, GameState.fight_reward(rival_id)], "fight")


## Rakip korkuyorsa araya küçük bir anlatım satırı ekler.
func add_scared_note(rival_id: String) -> void:
	if GameState.is_scared(rival_id):
		add_line("(Seni tanıdı. Sesi titriyor, geri adım atıyor.)", 9, Color("7dd3fc"))


## Rakibin portresi, adı ve nam durumu.
func set_rival(rival_id: String) -> void:
	var r := GameState.rival(rival_id)
	portrait = GameState.fighter_texture(r["look"], "idle")
	title = r["name"]
	var fear := GameState.fear_level(rival_id)
	if fear >= GameState.INTIMIDATE_FEAR:
		title += "   [Nam %d: senden korkuyor]" % fear
	elif fear > 0:
		title += "   [Nam %d: seni tanıyor]" % fear


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	if portrait:
		var pic := TextureRect.new()
		pic.texture = portrait
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(64, 96)
		pic.flip_h = true
		row.add_child(pic)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size.x = 260
	row.add_child(box)
	if title != "":
		box.add_child(GameState.make_label(title, 12, Color("e6b428")))
	for l in _lines:
		var label := GameState.make_label(l[0], l[1], l[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	box.add_child(Control.new())   # boşluk

	var first: Button = null
	for c in _choices:
		var b := Button.new()
		b.text = c["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = c["disabled"]
		var id: String = c["id"]
		b.pressed.connect(func(): chosen.emit(id))
		box.add_child(b)
		if c["note"] != "":
			var note := GameState.make_label(c["note"], 8, Color("c8d2e0"))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 260
			box.add_child(note)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
