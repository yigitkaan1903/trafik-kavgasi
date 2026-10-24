extends Control
## Cepteki telefon: sağ altta simge, tıklayınca (ya da T tuşuyla) sağ altta açılır.
## Uygulamalar: ZepBet (zeplin kumarı), Block Blast (blok yerleştirme), Mesajlar.
## Her şey bu tek düğümde elle çizilir; tıklamalar dikdörtgen kontrolüyle yakalanır.

signal toggled(open: bool)

const BODY_POS := Vector2(356, 44)
const BODY_SIZE := Vector2(118, 220)
const ICON_RECT := Rect2(452, 202, 22, 30)
const SCREEN := Rect2(6, 14, 106, 190)
const DARK := Color("1b1024")
const GOLD := Color("e6b428")

# ZepBet: çarpan e^(büyüme * t) ile artar, önceden çekilen bir noktada patlar.
const BETS := [5, 10, 20, 50, 100, 200]
const ZEP_GROWTH := 0.16
const ZEP_GRAPH := Rect2(10, 40, 98, 66)

# Block Blast
const GRID_N := 8
const CELL := 11
const GRID_POS := Vector2(15, 40)
const TRAY_Y := 136.0
const MINI := 6
const SHAPES := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
]
const BLOCK_COLORS := [Color("ef4444"), Color("f59e0b"), Color("22c55e"), Color("3b82f6"), Color("a855f7"), Color("06b6d4")]

## Oyundaki olaylardan gelen mesajlar (GameState.messages) yetmezse bunlarla doldurulur.
const FILLER_MESSAGES := [
	["Diferansiyel Grubu", "Hoca bugün yoklama alıyormuş, koşun!!"],
	["ZepBet", "Sana özel %100 hoş geldin bonusu! (Kumar bağımlılık yapar.)"],
]

var _open := false
var _app := "home"
var _icon: Control
var _body: Control
var _font: Font
var _seen := false

var _zep_state := "bet"    # bet, fly, crashed, cashed
var _bet_i := 1
var _bet := 0
var _zep_t := 0.0
var _zep_m := 1.0
var _crash_at := 1.0
var _crash_t := 0.0
var _history: Array = []
var _zep_msg := ""

var _grid: Array = []      # 0 boş, değilse renk + 1
var _tray: Array = []      # 3 parça: {"cells", "color"} ya da null
var _drag := -1
var _mouse := Vector2.ZERO
var _score := 0
var _over := false
var _flash := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_icon = Control.new()
	_icon.position = ICON_RECT.position
	_icon.size = ICON_RECT.size
	_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_icon.draw.connect(_draw_icon)
	_icon.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle())
	add_child(_icon)
	_body = Control.new()
	_body.position = BODY_POS
	_body.size = BODY_SIZE
	_body.visible = false
	_body.draw.connect(_draw_body)
	_body.gui_input.connect(_body_input)
	add_child(_body)
	_new_blocks()
	# test kısayolu: -- --phone=home|zep|zep-fly|blocks|msg
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phone="):
			var app := a.trim_prefix("--phone=")
			_app = app.get_slice("-", 0)
			if _app == "msg":
				_read_messages()
			toggle()
			if app == "zep-fly":
				_start_zep()
				_crash_at = 20.0
			elif app == "blocks":
				for i in 3:
					var cell := Vector2i(randi() % 5, randi() % 5)
					if _fits(_tray[i]["cells"], cell.x, cell.y):
						_place(i, cell.x, cell.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _open


func toggle() -> void:
	_open = not _open
	_seen = true
	_body.visible = _open
	if not _open and _zep_state == "fly":
		_cash_out()   # telefonu kapatırken uçuştaysa otomatik çeker
	toggled.emit(_open)


func _read_messages() -> void:
	if GameState.unread > 0:
		GameState.unread = 0
		GameState.save_game()


func close() -> void:
	if _open:
		toggle()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _zep_state == "fly":
		_zep_t += delta
		_zep_m = exp(ZEP_GROWTH * _zep_t)
		if _zep_m >= _crash_at:
			_zep_m = _crash_at
			_zep_state = "crashed"
			_crash_t = 0.0
			_history.push_front(_crash_at)
			_zep_msg = "PATLADI! -%d TL" % _bet
	_crash_t += delta
	_icon.queue_redraw()
	if _open:
		_body.queue_redraw()


# ---------------------------------------------------------------- Çizim yardımcıları

func _rect(r: Rect2, c: Color) -> void:
	_body.draw_rect(r, c)


func _text(pos: Vector2, text: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_body.draw_string(_font, pos, text, align, width, size, c)


func _button(r: Rect2, text: String, bg: Color, fg: Color = Color.WHITE, size: int = 8) -> void:
	_rect(r.grow(1), DARK)
	_rect(r, bg)
	_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.25))
	_text(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + size * 0.35), text, size, fg, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_icon() -> void:
	_icon.draw_rect(Rect2(4, 2, 14, 25), DARK)
	_icon.draw_rect(Rect2(5, 3, 12, 23), Color("2a2a33"))
	_icon.draw_rect(Rect2(6, 5, 10, 17), Color("3b82f6") if _open else Color("60a5fa"))
	_icon.draw_rect(Rect2(10, 23, 2, 2), Color("8a8a96"))
	if GameState.unread > 0:   # okunmamış mesaj sayısı
		var pulse := 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() / 400.0))
		_icon.draw_circle(Vector2(17, 4), 4.5, Color("1b1024"))
		_icon.draw_circle(Vector2(17, 4), 3.8, Color("ef4444").lerp(Color("ff8a7a"), pulse * 0.4))
		_icon.draw_string(_font, Vector2(13, 6.5), str(mini(9, GameState.unread)), HORIZONTAL_ALIGNMENT_CENTER, 8, 6, Color.WHITE)
	_icon.draw_string(_font, Vector2(0, 30), "T", HORIZONTAL_ALIGNMENT_CENTER, 22, 6, Color(1, 1, 1, 0.6))


func _draw_body() -> void:
	_rect(Rect2(Vector2.ZERO, BODY_SIZE), Color("0e0e12"))
	_rect(Rect2(1, 1, BODY_SIZE.x - 2, BODY_SIZE.y - 2), Color("2a2a33"))
	_rect(Rect2(3, 3, BODY_SIZE.x - 6, BODY_SIZE.y - 6), Color("0e0e12"))
	_rect(Rect2(48, 7, 22, 3), Color("2a2a33"))
	_body.draw_circle(Vector2(59, 211), 4, Color("3a3a44"))
	match _app:
		"home": _draw_home()
		"zep": _draw_zep()
		"blocks": _draw_blocks()
		"msg": _draw_messages()
	# durum çubuğu
	_rect(Rect2(SCREEN.position.x, SCREEN.position.y, SCREEN.size.x, 10), Color(0, 0, 0, 0.35))
	_text(Vector2(9, 22), GameState.clock_text(), 7, Color.WHITE)
	_rect(Rect2(95, 16, 12, 6), Color.WHITE)
	_rect(Rect2(96, 17, 7, 4), Color("22c55e"))
	_rect(Rect2(107, 18, 1, 2), Color.WHITE)


func _title_bar(title: String, color: Color, right: String = "") -> void:
	_rect(Rect2(SCREEN.position.x, 24, SCREEN.size.x, 12), Color(0, 0, 0, 0.4))
	_text(Vector2(9, 33), "<", 9, Color.WHITE)
	_text(Vector2(18, 33), title, 8, color)
	if right != "":
		_text(Vector2(6, 33), right, 7, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 104)


# ---------------------------------------------------------------- Ana ekran ve mesajlar

const HOME_ICONS := {"zep": Rect2(12, 96, 26, 26), "blocks": Rect2(46, 96, 26, 26), "msg": Rect2(80, 96, 26, 26)}


func _draw_home() -> void:
	for i in 19:
		_rect(Rect2(SCREEN.position.x, SCREEN.position.y + i * 10, SCREEN.size.x, 10), Color("1b2a52").lerp(Color("4c1d95"), i / 18.0))
	_text(Vector2(6, 62), GameState.clock_text(), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 106)
	_text(Vector2(6, 76), GameState.day_text(), 7, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 106)
	# ZepBet
	var r: Rect2 = HOME_ICONS["zep"]
	_rect(r, Color("7f1d1d"))
	_rect(Rect2(r.position.x + 5, r.position.y + 9, 16, 7), Color("cbd5e1"))
	_rect(Rect2(r.position.x + 3, r.position.y + 11, 2, 3), Color("cbd5e1"))
	_rect(Rect2(r.position.x + 10, r.position.y + 16, 5, 3), Color("475569"))
	# Block Blast
	r = HOME_ICONS["blocks"]
	_rect(r, Color("1e293b"))
	for k in 4:
		_rect(Rect2(r.position.x + 4 + (k % 2) * 10, r.position.y + 4 + (k / 2) * 10, 8, 8), BLOCK_COLORS[k])
	# Mesajlar
	r = HOME_ICONS["msg"]
	_rect(r, Color("15803d"))
	_rect(Rect2(r.position.x + 5, r.position.y + 7, 16, 10), Color.WHITE)
	_rect(Rect2(r.position.x + 7, r.position.y + 17, 3, 3), Color.WHITE)
	if GameState.unread > 0:
		_body.draw_circle(Vector2(r.end.x - 2, r.position.y + 2), 4, Color("ef4444"))
		_text(Vector2(r.end.x - 6, r.position.y + 5), str(mini(9, GameState.unread)), 6, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8)
	for key in HOME_ICONS:
		var ir: Rect2 = HOME_ICONS[key]
		var label: String = {"zep": "ZepBet", "blocks": "Block Blast", "msg": "Mesajlar"}[key]
		_text(Vector2(ir.position.x - 6, ir.end.y + 9), label, 6, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x + 12)


func _draw_messages() -> void:
	_rect(SCREEN, Color("f1f5f9"))
	_title_bar("Mesajlar", Color("22c55e"))
	var y := 40.0
	var list: Array = GameState.messages.slice(0, 4)
	if list.size() < 4:
		list.append(["Banka", "Hesap bakiyeniz: %d TL. İyi günler dileriz." % GameState.money])
		list.append_array(FILLER_MESSAGES)
	for m in list.slice(0, 4):
		var text: String = m[1]
		_rect(Rect2(9, y, 100, 36), Color.WHITE)
		_rect(Rect2(9, y, 2, 36), Color("22c55e"))
		_text(Vector2(14, y + 9), m[0], 7, Color("15803d"))
		_body.draw_multiline_string(_font, Vector2(14, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, 92, 6, 3, Color("334155"))
		y += 40.0


# ---------------------------------------------------------------- ZepBet

func _draw_zep() -> void:
	_rect(SCREEN, Color("1a0f2e"))
	_title_bar("ZepBet", Color("f87171"))
	var g := ZEP_GRAPH
	_rect(g, Color("120a22"))
	for i in 4:
		_rect(Rect2(g.position.x, g.position.y + i * g.size.y / 4.0, g.size.x, 1), Color(1, 1, 1, 0.05))
	if _zep_state != "bet":
		var t_end := _zep_t
		var span := maxf(5.0, t_end)
		var m_span := maxf(1.5, _zep_m - 1.0)
		var prev := Vector2(g.position.x, g.end.y)
		for i in range(1, 25):
			var t := t_end * i / 24.0
			var p := Vector2(g.position.x + g.size.x * t / span, g.end.y - g.size.y * 0.85 * (exp(ZEP_GROWTH * t) - 1.0) / m_span)
			_body.draw_line(prev, p, Color("ef4444") if _zep_state == "crashed" else GOLD, 1.5)
			prev = p
		if _zep_state == "crashed":
			var k := clampf(_crash_t * 3.0, 0.0, 1.0)
			_body.draw_circle(prev, 4 + 8 * k, Color(1.0, 0.45, 0.1, 1.0 - k))
			_body.draw_circle(prev, 2 + 5 * k, Color(1.0, 0.85, 0.3, 1.0 - k))
		else:
			_rect(Rect2(prev.x - 9, prev.y - 5, 15, 7), Color("cbd5e1"))
			_rect(Rect2(prev.x - 11, prev.y - 4, 2, 5), Color("94a3b8"))
			_rect(Rect2(prev.x - 4, prev.y + 2, 5, 3), Color("475569"))
	var col := Color.WHITE
	if _zep_state == "crashed":
		col = Color("ef4444")
	elif _zep_state == "cashed":
		col = Color("4ade80")
	_text(Vector2(g.position.x, g.position.y + 24), "%.2fx" % _zep_m, 16, col, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
	if _zep_msg != "":
		_text(Vector2(g.position.x, g.position.y + 36), _zep_msg, 7, col, HORIZONTAL_ALIGNMENT_CENTER, g.size.x)
	# son patlamalar
	for i in mini(5, _history.size()):
		var h: float = _history[i]
		var r := Rect2(10 + i * 20, 110, 18, 10)
		_rect(r, Color("7f1d1d") if h < 2.0 else Color("14532d"))
		_text(Vector2(r.position.x, r.position.y + 8), "%.1f" % h, 6, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var flying := _zep_state == "fly"
	_button(Rect2(10, 124, 16, 14), "-", Color("334155") if not flying else Color("1e1b2e"))
	_button(Rect2(92, 124, 16, 14), "+", Color("334155") if not flying else Color("1e1b2e"))
	_text(Vector2(26, 134), "Bahis: %d TL" % BETS[_bet_i], 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 66)
	if flying:
		_button(Rect2(10, 142, 98, 18), "ÇEK: %d TL" % int(round(_bet * _zep_m)), Color("16a34a"), Color.WHITE, 9)
	else:
		_button(Rect2(10, 142, 98, 18), "OYNA", GOLD, DARK, 9)
	_text(Vector2(6, 172), "Bakiye: %d TL" % GameState.money, 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 106)
	_text(Vector2(6, 186), "Kumar bağımlılık yapar.", 6, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 106)
	_text(Vector2(6, 195), "Kasa her zaman kazanır.", 6, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 106)


func _zep_click(p: Vector2) -> void:
	var flying := _zep_state == "fly"
	if Rect2(10, 124, 16, 14).has_point(p) and not flying:
		_bet_i = maxi(0, _bet_i - 1)
	elif Rect2(92, 124, 16, 14).has_point(p) and not flying:
		_bet_i = mini(BETS.size() - 1, _bet_i + 1)
	elif Rect2(10, 142, 98, 18).has_point(p):
		if flying:
			_cash_out()
		else:
			_start_zep()


func _start_zep() -> void:
	var bet: int = BETS[_bet_i]
	if not GameState.try_spend(bet):
		_zep_msg = "Bakiye yetersiz!"
		return
	_bet = bet
	# %3 kasa payı: patlama noktası 0.97 / (1 - u)
	var u := randf()
	_crash_at = 1.0 if u < 0.03 else clampf(0.97 / (1.0 - u), 1.01, 50.0)
	_zep_t = 0.0
	_zep_m = 1.0
	_zep_msg = ""
	_zep_state = "fly"


func _cash_out() -> void:
	var win := int(round(_bet * _zep_m))
	GameState.money += win
	GameState.save_game()
	_zep_state = "cashed"
	_history.push_front(_crash_at)
	_zep_msg = "+%d TL  (patlama: %.2fx)" % [win, _crash_at]


# ---------------------------------------------------------------- Block Blast

func _new_blocks() -> void:
	_grid = []
	_grid.resize(GRID_N * GRID_N)
	_grid.fill(0)
	_score = 0
	_over = false
	_refill_tray()


func _refill_tray() -> void:
	_tray = []
	for i in 3:
		_tray.append({"cells": SHAPES.pick_random(), "color": randi() % BLOCK_COLORS.size()})


func _fits(cells: Array, col: int, row: int) -> bool:
	for c in cells:
		var x: int = col + c.x
		var y: int = row + c.y
		if x < 0 or y < 0 or x >= GRID_N or y >= GRID_N or _grid[y * GRID_N + x] != 0:
			return false
	return true


func _fits_anywhere(cells: Array) -> bool:
	for row in GRID_N:
		for col in GRID_N:
			if _fits(cells, col, row):
				return true
	return false


func _place(i: int, col: int, row: int) -> void:
	var piece: Dictionary = _tray[i]
	for c in piece["cells"]:
		_grid[(row + c.y) * GRID_N + col + c.x] = piece["color"] + 1
	_score += piece["cells"].size()
	# dolan satır ve sütunları temizle
	var full: Array = []
	for k in GRID_N:
		var row_full := true
		var col_full := true
		for j in GRID_N:
			if _grid[k * GRID_N + j] == 0:
				row_full = false
			if _grid[j * GRID_N + k] == 0:
				col_full = false
		if row_full:
			for j in GRID_N:
				full.append(k * GRID_N + j)
		if col_full:
			for j in GRID_N:
				full.append(j * GRID_N + k)
	if not full.is_empty():
		var lines := full.size() / GRID_N
		_score += 10 * lines * lines
		_flash = 0.25
		for idx in full:
			_grid[idx] = 0
	_tray[i] = null
	if _tray.all(func(t): return t == null):
		_refill_tray()
	_over = true
	for t in _tray:
		if t != null and _fits_anywhere(t["cells"]):
			_over = false
	if _score > GameState.blast_best:
		GameState.blast_best = _score
		GameState.save_game()


func _piece_size(cells: Array) -> Vector2i:
	var s := Vector2i.ZERO
	for c in cells:
		s = Vector2i(maxi(s.x, c.x + 1), maxi(s.y, c.y + 1))
	return s


func _drag_origin() -> Vector2:
	var s := _piece_size(_tray[_drag]["cells"])
	return _mouse - Vector2(s) * CELL / 2.0 - Vector2(0, 14)


func _drag_cell() -> Vector2i:
	var o := (_drag_origin() - GRID_POS) / CELL
	return Vector2i(roundi(o.x), roundi(o.y))


func _draw_blocks() -> void:
	_rect(SCREEN, Color("111827"))
	_title_bar("Block Blast", Color("60a5fa"), "%d  (en iyi %d)" % [_score, GameState.blast_best])
	_rect(Rect2(GRID_POS - Vector2(2, 2), Vector2(GRID_N * CELL + 3, GRID_N * CELL + 3)), Color("1f2937").lightened(_flash))
	for y in GRID_N:
		for x in GRID_N:
			var r := Rect2(GRID_POS + Vector2(x, y) * CELL, Vector2(CELL - 1, CELL - 1))
			var v: int = _grid[y * GRID_N + x]
			_rect(r, Color("273449") if v == 0 else BLOCK_COLORS[v - 1])
			if v != 0:
				_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(1, 1, 1, 0.3))
	if _drag >= 0:
		var cell := _drag_cell()
		var piece: Dictionary = _tray[_drag]
		if _fits(piece["cells"], cell.x, cell.y):
			for c in piece["cells"]:
				_rect(Rect2(GRID_POS + Vector2(cell.x + c.x, cell.y + c.y) * CELL, Vector2(CELL - 1, CELL - 1)),
						Color(BLOCK_COLORS[piece["color"]], 0.35))
	for i in 3:
		var slot := Rect2(8 + i * 35, TRAY_Y, 32, 50)
		_rect(slot, Color("1a2333"))
		var piece = _tray[i]
		if piece == null or i == _drag:
			continue
		var s := _piece_size(piece["cells"])
		var o := slot.get_center() - Vector2(s) * MINI / 2.0
		for c in piece["cells"]:
			_rect(Rect2(o + Vector2(c) * MINI, Vector2(MINI - 1, MINI - 1)), BLOCK_COLORS[piece["color"]])
	if _drag >= 0:
		var o := _drag_origin()
		var piece: Dictionary = _tray[_drag]
		for c in piece["cells"]:
			_rect(Rect2(o + Vector2(c) * CELL, Vector2(CELL - 1, CELL - 1)), BLOCK_COLORS[piece["color"]])
	if _over:
		_rect(Rect2(14, 70, 90, 54), Color(0, 0, 0, 0.85))
		_text(Vector2(14, 86), "Oyun bitti!", 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 90)
		_text(Vector2(14, 98), "Skor: %d" % _score, 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 90)
		_button(Rect2(30, 104, 58, 14), "Yeniden", Color("3b82f6"))


func _blocks_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		if event.pressed:
			if _over:
				if Rect2(30, 104, 58, 14).has_point(_mouse):
					_new_blocks()
				return
			for i in 3:
				if _tray[i] != null and Rect2(8 + i * 35, TRAY_Y, 32, 50).has_point(_mouse):
					_drag = i
		elif _drag >= 0:
			var cell := _drag_cell()
			if _fits(_tray[_drag]["cells"], cell.x, cell.y):
				_place(_drag, cell.x, cell.y)
			_drag = -1


# ---------------------------------------------------------------- Dokunma

func _body_input(event: InputEvent) -> void:
	_body.accept_event()
	if _app == "blocks":
		_blocks_input(event)
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if Rect2(50, 204, 18, 14).has_point(p) or (_app != "home" and Rect2(6, 24, 16, 12).has_point(p)):
		if _app == "zep" and _zep_state == "fly":
			_cash_out()
		_app = "home"
		_drag = -1
		return
	match _app:
		"home":
			for key in HOME_ICONS:
				if HOME_ICONS[key].has_point(p):
					_app = key
					if key == "msg":
						_read_messages()
		"zep":
			_zep_click(p)
