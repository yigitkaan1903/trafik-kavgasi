extends Control
## Yetenek ağacı (tam ekran panel). Telefondan "Yetenek" ya da Y tuşuyla açılır.
## Dört dal: Güç, Çeviklik, Dayanıklılık (stat ister) ve Hayat. Yetenek açmak için gereken stat + yetenek
## puanı + önceki yetenek. Puanlar seviye atlayınca gelir (XP: kavga, antrenman, ders).

signal closed

const Skills = preload("res://data/skills.gd")
const Places = preload("res://data/places.gd")
const PANEL := Rect2(8, 24, 464, 240)
const COL_W := 110.0
const NODE_H := 40.0

var _hover := ""
var _rects := {}            # tıklanabilir alanlar: id -> Rect2 ("close" ve yetenek id'leri)
var _msg := ""
var _msg_col := Color.WHITE
var _msg_t := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	queue_redraw()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") or event.is_action_pressed("skills"):
		get_viewport().set_input_as_handled()
		close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = ""
		for id in _rects:
			if _rects[id].has_point(event.position):
				_hover = id
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover != "" else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in _rects:
			if _rects[id].has_point(event.position):
				_click(id)
				return


func _click(id: String) -> void:
	match id:
		"close":
			close()
		_:
			if not Skills.SKILLS.has(id):
				return
			var why := GameState.skill_block_reason(id)
			if why == "":
				GameState.buy_skill(id)
				Audio.sfx("buy")
				_say("%s açıldı! %s" % [Skills.SKILLS[id]["name"], Skills.SKILLS[id]["desc"]], Color("4ade80"))
			elif why != "Açık":
				_say(why, Color("ff8a7a"))


func _say(text: String, col: Color) -> void:
	_msg = text
	_msg_col = col
	_msg_t = 2.5


# ---------------------------------------------------------------- Çizim

func _text(pos: Vector2, s: String, size: int, col: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, align, width, size, col)


func _draw() -> void:
	_rects.clear()
	draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.55))
	UIDraw.card(self, PANEL)
	_text(PANEL.position + Vector2(10, 15), "YETENEK AĞACI", 12, UIDraw.GOLD)
	# yetenek puanı
	var sp := "Yetenek puanı: %d" % GameState.skill_points
	UIDraw.box(self, Rect2(PANEL.position.x + 118, PANEL.position.y + 4, 88, 14),
			Color(UIDraw.GOLD, 0.25 + 0.15 * absf(sin(_t * 2.0))) if GameState.skill_points > 0 else Color(1, 1, 1, 0.08),
			Color(UIDraw.GOLD, 0.7), 6)
	_text(PANEL.position + Vector2(118, 14.5), sp, 8, Color.WHITE, 88, HORIZONTAL_ALIGNMENT_CENTER)
	# seviye ve XP
	var lr := Rect2(PANEL.position.x + 214, PANEL.position.y + 4, 210, 14)
	UIDraw.box(self, lr, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.15), 6)
	_text(lr.position + Vector2(7, 10.5), "Seviye %d" % GameState.level, 8, Color.WHITE)
	UIDraw.meter(self, Rect2(lr.position.x + 58, lr.position.y + 5, 100, 4), float(GameState.xp) / GameState.xp_needed(), Color("7dd3fc"))
	_text(lr.position + Vector2(162, 10.5), "%d/%d XP" % [GameState.xp, GameState.xp_needed()], 7, UIDraw.TEXT_DIM, 44, HORIZONTAL_ALIGNMENT_RIGHT)
	var cr := Rect2(PANEL.end.x - 20, PANEL.position.y + 4, 14, 14)
	_rects["close"] = cr
	UIDraw.box(self, cr, Color("c84438") if _hover == "close" else Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 3)
	_text(cr.position + Vector2(0, 10.5), "X", 8, Color.WHITE, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_skills()
	var foot := _msg if _msg_t > 0.0 else "Kavga kazan, spor yap, derse gir: XP dolunca seviye atlarsın (+1 puan).  ·  Y / Esc: kapat"
	_text(Vector2(PANEL.position.x, PANEL.end.y - 6), foot, 8, _msg_col if _msg_t > 0.0 else UIDraw.TEXT_DIM, PANEL.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)


func _draw_skills() -> void:
	var col := 0
	for b in Skills.BRANCHES:
		var br: Dictionary = Skills.BRANCHES[b]
		var x := PANEL.position.x + 10 + col * (COL_W + 4)
		var y := PANEL.position.y + 26
		var head: String = br["name"] if b == "life" else "%s  %d" % [br["name"], int(GameState.stats[b])]
		UIDraw.box(self, Rect2(x, y, COL_W, 13), Color(br["color"], 0.3), Color(br["color"], 0.8), 4)
		_text(Vector2(x, y + 9.5), head, 8, Color.WHITE, COL_W, HORIZONTAL_ALIGNMENT_CENTER)
		y += 18
		var prev := Vector2.ZERO
		for id in Skills.SKILLS:
			var sk: Dictionary = Skills.SKILLS[id]
			if sk["branch"] != b:
				continue
			var r := Rect2(x, y, COL_W, NODE_H)
			if prev != Vector2.ZERO:   # dal çizgisi
				draw_rect(Rect2(x + COL_W / 2.0 - 1, prev.y, 2, r.position.y - prev.y), Color(br["color"], 0.6))
			_draw_node(id, sk, r, br["color"])
			prev = Vector2(x, r.end.y)
			y += NODE_H + 6
		col += 1


func _draw_node(id: String, sk: Dictionary, r: Rect2, color: Color) -> void:
	_rects[id] = r
	var owned := GameState.has_skill(id)
	var why := GameState.skill_block_reason(id)
	var ready := why == ""
	var bg := Color(color.darkened(0.45), 0.95) if owned else (Color("221d33") if ready else Color("17141f"))
	var border := color if owned else (UIDraw.GOLD.lerp(Color.WHITE, 0.4 * absf(sin(_t * 3.0))) if ready else Color(1, 1, 1, 0.15))
	if _hover == id and not owned:
		bg = bg.lightened(0.08)
	UIDraw.box(self, r, bg, border, 4)
	var name_col := Color.WHITE if owned or ready else Color(1, 1, 1, 0.55)
	_text(r.position + Vector2(5, 10), sk["name"], 8, name_col, r.size.x - 10)
	if owned:
		_check(r.position + Vector2(r.size.x - 12, 6))
	_text(r.position + Vector2(5, 21), sk["desc"], 6, Color(1, 1, 1, 0.8 if owned or ready else 0.45), r.size.x - 8)
	var req: Array = []
	if sk.has("needs") and not GameState.has_skill(sk["needs"]):
		req.append("Önce " + Skills.SKILLS[sk["needs"]]["name"])
	if sk.has("stat"):
		req.append("%s %d" % [Places.STAT_NAMES[sk["stat"][0]], sk["stat"][1]])
	req.append("%d puan" % sk["cost"])
	var req_text := "Açık" if owned else " · ".join(req)
	var req_col := Color("4ade80") if owned else (UIDraw.GOLD if ready else Color("ff8a7a", 0.8))
	_text(r.position + Vector2(5, 33), req_text, 6, req_col, r.size.x - 10)


## Küçük onay işareti.
func _check(p: Vector2) -> void:
	draw_line(p + Vector2(0, 3), p + Vector2(3, 6), Color("4ade80"), 2.0)
	draw_line(p + Vector2(3, 6), p + Vector2(8, 0), Color("4ade80"), 2.0)
