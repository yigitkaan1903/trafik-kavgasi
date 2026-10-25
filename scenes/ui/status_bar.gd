extends Control
## Üst şerit (Punch Club tarzı, UIDraw ile çizilir): takvim + saat, enerji ve tokluk, para, üç stat rozeti.
## Değerler akarak değişir. Antrenmanda stat "tutulur" (hold), uçan baloncuklar geldikçe
## (feed) rozet parlar ve ilerleme çubuğu dolar.

const Places = preload("res://data/places.gd")
const HEIGHT := 22.0
const STAT_KEYS := ["str", "agi", "sta"]
const STAT_COLORS := {"str": Color("ef4444"), "agi": Color("22c55e"), "sta": Color("3b82f6")}
const BADGE_X := 260.0
const BADGE_W := 73.0

var _shown := {}
var _held := {}
var _pulse := {}
var _energy := 0.0
var _food := 0.0
var _money := 0.0
var _money_pop := 0
var _money_pop_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(480, HEIGHT)
	for k in STAT_KEYS:
		_shown[k] = GameState.stats[k]
		_pulse[k] = 0.0
	_energy = GameState.energy
	_food = GameState.food
	_money = GameState.money


## Statı mevcut gösterilen değerde dondurur; artış baloncuklarla gelecek.
func hold(k: String) -> void:
	_held[k] = true


## Bir baloncuk rozete ulaştı: gösterilen değeri biraz artır, rozeti parlat.
func feed(k: String, amount: float) -> void:
	_shown[k] = minf(GameState.stats[k], _shown[k] + amount)
	_pulse[k] = 0.25


func release(k: String) -> void:
	_held.erase(k)


## Baloncukların uçacağı nokta (ekran koordinatı).
func stat_anchor(k: String) -> Vector2:
	return global_position + Vector2(BADGE_X + STAT_KEYS.find(k) * BADGE_W + 16, HEIGHT / 2.0)


func _process(delta: float) -> void:
	for k in STAT_KEYS:
		_pulse[k] = maxf(0.0, _pulse[k] - delta)
		if not _held.has(k):
			var target: float = GameState.stats[k]
			_shown[k] = move_toward(_shown[k], target, maxf(3.0, absf(target - _shown[k]) * 3.0) * delta)
	_energy = move_toward(_energy, GameState.energy, maxf(30.0, absf(GameState.energy - _energy) * 3.0) * delta)
	_food = move_toward(_food, GameState.food, maxf(30.0, absf(GameState.food - _food) * 3.0) * delta)
	if absf(GameState.money - _money) >= 1.0 and _money_pop_t <= 0.0:
		_money_pop = GameState.money - int(round(_money))
		_money_pop_t = 1.6
		if _money_pop > 0:
			Audio.sfx("coin", 0.5)
	_money = move_toward(_money, GameState.money, maxf(40.0, absf(GameState.money - _money) * 4.0) * delta)
	_money_pop_t = maxf(0.0, _money_pop_t - delta)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var gs := GameState
	# zemin: koyu, üst yarıda hafif parlama, altta altın çizgi ve gölge
	draw_rect(Rect2(0, 0, 480, HEIGHT), Color("14121e"))
	draw_rect(Rect2(0, 0, 480, HEIGHT / 2.0), Color(1, 1, 1, 0.035))
	draw_rect(Rect2(0, HEIGHT - 1, 480, 1), UIDraw.GOLD)
	draw_rect(Rect2(0, HEIGHT, 480, 2), Color(0, 0, 0, 0.3))

	# takvim yaprağı ve saat
	UIDraw.icon(self, "calendar", Vector2(5, 3))
	draw_string(font, Vector2(5, 15.5), str(gs.day), HORIZONTAL_ALIGNMENT_CENTER, 14, 7, Color("1b1024"))
	var late: bool = gs.minute >= 23 * 60 or gs.minute < Places.START_MINUTE
	draw_string(font, Vector2(23, 15.5), gs.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff6a4a") if late else Color.WHITE)
	_divider(70)

	# enerji ve tokluk: parçalı çubuklar
	UIDraw.icon(self, "energy", Vector2(73, 0))
	UIDraw.meter(self, Rect2(86, 3, 52, 5), _energy / 100.0, Color("facc15") if _energy > 25.0 else Color("ef4444"), 10)
	draw_string(font, Vector2(142, 8.5), "%d" % int(_energy), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.75))
	UIDraw.icon(self, "food", Vector2(73, 11))
	UIDraw.meter(self, Rect2(86, 13, 52, 5), _food / 100.0, Color("4ade80") if _food > 25.0 else Color("ef4444"), 10)
	draw_string(font, Vector2(142, 18.5), "%d" % int(_food), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.75))
	_divider(160)

	# para (değişince küçük +/- yazısı belirir)
	UIDraw.icon(self, "money", Vector2(164, 5))
	draw_string(font, Vector2(180, 15), _money_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIDraw.GOLD)
	if _money_pop_t > 0.0:
		var a := clampf(_money_pop_t / 0.4, 0.0, 1.0)
		var up := (1.6 - _money_pop_t) * 4.0
		draw_string(font, Vector2(214, 10 - up), ("+%d" if _money_pop > 0 else "%d") % _money_pop, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color(0.3, 0.9, 0.5, a) if _money_pop > 0 else Color(1, 0.4, 0.3, a))
	# seviye rozeti ve XP çubuğu
	var mw := font.get_string_size(_money_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var lx := minf(184.0 + mw, BADGE_X - 34.0)
	UIDraw.box(self, Rect2(lx, 4, 26, 12), Color("1e3a5f"), Color("7dd3fc", 0.6), 4)
	draw_string(font, Vector2(lx, 13), "Sv %d" % gs.level, HORIZONTAL_ALIGNMENT_CENTER, 26, 7, Color.WHITE)
	UIDraw.meter(self, Rect2(lx + 1, 18, 24, 2), float(gs.xp) / gs.xp_needed(), Color("7dd3fc"))
	_divider(BADGE_X - 5)

	# stat kartları: renkli simge, değer, ad ve bir sonraki puana ilerleme
	for i in STAT_KEYS.size():
		var k: String = STAT_KEYS[i]
		var x := BADGE_X + i * BADGE_W
		var col: Color = STAT_COLORS[k]
		var glow: float = _pulse[k] / 0.25
		var r := Rect2(x, 2, BADGE_W - 4, 18)
		UIDraw.box(self, r, Color("201c30").lerp(col.darkened(0.35), glow * 0.7), Color(col, 0.35 + glow * 0.5), 3)
		UIDraw.icon(self, k, Vector2(x + 3, 5))
		draw_string(font, Vector2(x + 19, 12.5), str(int(_shown[k])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(font, Vector2(x + 36, 10), Places.STAT_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UIDraw.TEXT_DIM)
		UIDraw.meter(self, Rect2(x + 36, 13, BADGE_W - 44, 3), fmod(_shown[k], 1.0), col.lightened(0.25))


func _divider(x: float) -> void:
	draw_rect(Rect2(x, 4, 1, HEIGHT - 8), Color(1, 1, 1, 0.1))


## God Mode'da (test) para sınırsız: sayı yerine sonsuz işareti.
func _money_text() -> String:
	return "∞ TL" if GameState.difficulty == "god" else "%d TL" % int(round(_money))
