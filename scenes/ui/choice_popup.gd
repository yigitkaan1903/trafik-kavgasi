extends CenterContainer
## Ortak seçim penceresi: solda portre (ya da uyarı simgesi), sağda başlık, metin satırları ve seçenekler.
## Trafikteki karşılaşmalar ve metrobüs olayları bunu kullanır.

signal chosen(id: String)

var portrait: Texture2D
var icon := ""             # portre yerine simge: "warn" (ünlem) ya da "clock" (kapalı / saat dışı)
var accent := Color("e6b428")   # başlık, üst şerit ve seçili seçenek rengi
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
	portrait = GameState.portrait_texture(r["look"])
	title = r["name"]
	var fear := GameState.fear_level(rival_id)
	if fear >= GameState.INTIMIDATE_FEAR:
		title += "   [Nam %d: senden korkuyor]" % fear
	elif fear > 0:
		title += "   [Nam %d: seni tanıyor]" % fear


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color("15121f", 0.97)
	card.border_color = Color(accent, 0.55)
	card.set_border_width_all(1)
	card.border_width_top = 3
	card.set_corner_radius_all(6)
	card.shadow_color = Color(0, 0, 0, 0.5)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 3)
	card.set_content_margin_all(10)
	card.content_margin_top = 12
	panel.add_theme_stylebox_override("panel", card)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	if portrait or icon != "":
		var frame := PanelContainer.new()   # portre / simge çerçevesi
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color(accent.darkened(0.75), 0.9)
		fs.border_color = Color(accent, 0.35)
		fs.set_border_width_all(1)
		fs.set_corner_radius_all(4)
		fs.set_content_margin_all(2)
		frame.add_theme_stylebox_override("panel", fs)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
		if icon != "":
			var ic := Control.new()
			ic.custom_minimum_size = Vector2(52, 52)
			ic.draw.connect(func(): _draw_icon(ic))
			frame.add_child(ic)
		else:
			var pic := TextureRect.new()
			pic.texture = portrait
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var bust := portrait.get_width() == portrait.get_height()   # konuşma portresi (kare) ya da tam boy sprite
			pic.custom_minimum_size = Vector2(96, 96) if bust else Vector2(60, 90)
			pic.flip_h = not bust
			frame.add_child(pic)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size.x = 250
	row.add_child(box)
	if title != "":
		box.add_child(GameState.make_label(title, 12, accent))
		var line := ColorRect.new()   # başlık altı ayraç
		line.color = Color(accent, 0.3)
		line.custom_minimum_size = Vector2(0, 1)
		box.add_child(line)
	for l in _lines:
		var label := GameState.make_label(l[0], l[1], l[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 3
	box.add_child(gap)

	var first: Button = null
	for c in _choices:
		var b := UIDraw.flat_button(c["text"], accent)
		b.disabled = c["disabled"]
		var id: String = c["id"]
		b.pressed.connect(func(): chosen.emit(id))
		box.add_child(b)
		if c["note"] != "":
			var note := GameState.make_label(c["note"], 8, Color(1, 1, 1, 0.55))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 250
			box.add_child(note)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()
	# açılış: arka plan kararır, kart hafif büyüyerek belirir
	modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	_pop.call_deferred(panel)


func _pop(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22)


## Uyarı simgesi: vurgu renginde daire, içinde ünlem (ya da saat: "clock").
func _draw_icon(c: Control) -> void:
	var m := c.size / 2.0
	c.draw_circle(m, 21, Color(accent, 0.18))
	c.draw_circle(m, 16, accent)
	if icon == "clock":
		c.draw_circle(m, 12, Color("15121f"))
		c.draw_line(m, m + Vector2(0, -8), accent, 2.0)
		c.draw_line(m, m + Vector2(6, 2), accent, 2.0)
		c.draw_circle(m, 2, accent)
	else:
		c.draw_rect(Rect2(m.x - 2, m.y - 10, 4, 13), Color("15121f"))
		c.draw_rect(Rect2(m.x - 2, m.y + 6, 4, 4), Color("15121f"))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.05, 0.6))
