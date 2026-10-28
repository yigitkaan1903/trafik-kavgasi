extends Control
## Üst gösterge "adası" (Punch Club tarzı, UIDraw ile çizilir): ekranın üstünde ortada duran kompakt panel.
## Takvim + saat, enerji / tokluk / can çubukları, para + seviye, üç stat rozeti.
## Değerler akarak değişir. Antrenmanda stat "tutulur" (hold), uçan baloncuklar geldikçe
## (feed) rozet parlar ve ilerleme çubuğu dolar.

const Places = preload("res://data/places.gd")
const HEIGHT := 22.0              # adanın üstte kapladığı yükseklik (altındaki başlıklar 25'ten başlar)
const STAT_KEYS := ["str", "agi", "sta"]
const STAT_COLORS := {"str": Color("ef4444"), "agi": Color("22c55e"), "sta": Color("3b82f6")}
const ISLAND := Rect2(92, 2, 296, 20)
const STAT_X := 163.0             # ada içinde stat rozetlerinin başladığı yer
const STAT_W := 44.0

var _shown := {}
var _held := {}
var _pulse := {}
var _energy := 0.0
var _food := 0.0
var _health := 0.0
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
	_health = GameState.health
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
	return global_position + ISLAND.position + Vector2(STAT_X + STAT_KEYS.find(k) * STAT_W + 8, ISLAND.size.y / 2.0)


func _process(delta: float) -> void:
	for k in STAT_KEYS:
		_pulse[k] = maxf(0.0, _pulse[k] - delta)
		if not _held.has(k):
			var target: float = GameState.stats[k]
			_shown[k] = move_toward(_shown[k], target, maxf(3.0, absf(target - _shown[k]) * 3.0) * delta)
	_energy = move_toward(_energy, GameState.energy, maxf(30.0, absf(GameState.energy - _energy) * 3.0) * delta)
	_food = move_toward(_food, GameState.food, maxf(30.0, absf(GameState.food - _food) * 3.0) * delta)
	_health = move_toward(_health, GameState.health, maxf(30.0, absf(GameState.health - _health) * 3.0) * delta)
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
	draw_set_transform(ISLAND.position)
	var w := ISLAND.size.x
	var h := ISLAND.size.y
	# ada: gölge, koyu gövde, altın kenar, üst yarıda hafif parlama
	UIDraw.box(self, Rect2(1, 2, w, h), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 5)
	UIDraw.box(self, Rect2(0, 0, w, h), Color("181524", 0.96), Color(UIDraw.GOLD, 0.55), 5)
	draw_rect(Rect2(3, 1, w - 6, h / 2.0 - 1), Color(1, 1, 1, 0.03))

	# takvim yaprağı ve saat
	UIDraw.icon(self, "calendar", Vector2(4, 2))
	draw_string(font, Vector2(4, 14.5), str(gs.day), HORIZONTAL_ALIGNMENT_CENTER, 14, 7, Color("1b1024"))
	var late: bool = gs.minute >= 23 * 60 or gs.minute < Places.START_MINUTE
	draw_string(font, Vector2(21, 14), gs.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ff6a4a") if late else Color.WHITE)
	_divider(53)

	# enerji, tokluk, can: ince çubuklar, solda küçük simge (düşükse kırmızı)
	var bars := [["energy", _energy, Color("facc15")], ["food", _food, Color("4ade80")], ["health", _health, Color("f87171")]]
	for i in bars.size():
		var y := 2.5 + i * 5.5
		var v: float = bars[i][1]
		draw_texture_rect_region(UIDraw.ICON_SHEET, Rect2(57, y - 0.5, 5, 5), Rect2(Vector2(UIDraw.ICONS[bars[i][0]][0] * 16, 0), Vector2(12, 12)))
		UIDraw.meter(self, Rect2(64, y + 0.5, 38, 3), v / 100.0, bars[i][2] if v > 25.0 else Color("ef4444"), 8)
	_divider(106)

	# para (değişince küçük +/- yazısı belirir), altında seviye ve XP çubuğu
	draw_texture_rect_region(UIDraw.ICON_SHEET, Rect2(110, 2, 8, 8), Rect2(Vector2(UIDraw.ICONS["money"][0] * 16, 0), Vector2(12, 12)))
	draw_string(font, Vector2(120, 9.5), _money_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIDraw.GOLD)
	if _money_pop_t > 0.0:
		var a := clampf(_money_pop_t / 0.4, 0.0, 1.0)
		var up := (1.6 - _money_pop_t) * 4.0
		draw_string(font, Vector2(124, 30 - up), ("+%d" if _money_pop > 0 else "%d") % _money_pop, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color(0.3, 0.9, 0.5, a) if _money_pop > 0 else Color(1, 0.4, 0.3, a))
	draw_string(font, Vector2(110, 17.5), "Sv %d" % gs.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("7dd3fc"))
	UIDraw.meter(self, Rect2(130, 14, 28, 2), float(gs.xp) / gs.xp_needed(), Color("7dd3fc"))
	_divider(STAT_X - 3)

	# stat rozetleri: renkli simge, değer, bir sonraki puana ilerleme
	for i in STAT_KEYS.size():
		var k: String = STAT_KEYS[i]
		var x := STAT_X + i * STAT_W
		var col: Color = STAT_COLORS[k]
		var glow: float = _pulse[k] / 0.25
		UIDraw.box(self, Rect2(x, 2, STAT_W - 3, 16), Color("201c30").lerp(col.darkened(0.35), glow * 0.7), Color(col, 0.35 + glow * 0.5), 3)
		UIDraw.icon(self, k, Vector2(x + 2, 4))
		draw_string(font, Vector2(x + 16, 11), str(int(_shown[k])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		UIDraw.meter(self, Rect2(x + 16, 14, STAT_W - 22, 2), fmod(_shown[k], 1.0), col.lightened(0.25))
	draw_set_transform(Vector2.ZERO)


func _divider(x: float) -> void:
	draw_rect(Rect2(x, 4, 1, ISLAND.size.y - 8), Color(1, 1, 1, 0.1))


## God Mode'da (test) para sınırsız: sayı yerine sonsuz işareti.
func _money_text() -> String:
	return "∞ TL" if GameState.difficulty == "god" else "%d TL" % int(round(_money))
