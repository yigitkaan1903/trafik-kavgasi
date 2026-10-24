class_name UIDraw
extends RefCounted
## Arayüz çizim yardımcıları: köşeleri yuvarlatılmış kutular, tuş kapakları, hap (pill) etiketler.
## Göstergeler (üst şerit, alt bilgi şeridi, kartlar) aynı görünsün diye hepsi buradan çizilir.

const BG := Color(0.065, 0.058, 0.105, 0.94)
const BG_SOFT := Color(0.09, 0.08, 0.14, 0.88)
const GOLD := Color("e6b428")
const TEXT_DIM := Color(1, 1, 1, 0.62)

static var _cache := {}


static func style(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 3, border_w: int = 1) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [bg.to_html(), border.to_html(), radius, border_w]
	if not _cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(border_w if border.a > 0.0 else 0)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 0.6
		_cache[key] = sb
	return _cache[key]


## Yuvarlak köşeli kutu.
static func box(ci: CanvasItem, r: Rect2, bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 3) -> void:
	style(bg, border, radius).draw(ci.get_canvas_item(), r)


## Kart: koyu yarı saydam zemin, ince altın kenar, üstte hafif parlama.
static func card(ci: CanvasItem, r: Rect2, accent: Color = GOLD) -> void:
	box(ci, r, BG, Color(accent, 0.55), 4)
	ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 1, r.size.x - 8, 1), Color(1, 1, 1, 0.07))


## İnce yatay ilerleme çubuğu (yuvarlak uçlu). k: 0..1
static func meter(ci: CanvasItem, r: Rect2, k: float, color: Color, segments: int = 0) -> void:
	box(ci, r.grow(1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 2)
	var w := r.size.x * clampf(k, 0.0, 1.0)
	if w >= 1.0:
		box(ci, Rect2(r.position, Vector2(maxf(w, 2.0), r.size.y)), color, Color(0, 0, 0, 0), 2)
		ci.draw_rect(Rect2(r.position.x + 1, r.position.y, maxf(w - 2.0, 0.0), 1), Color(1, 1, 1, 0.28))
	if segments > 1:
		for i in range(1, segments):
			var x := r.position.x + r.size.x * i / segments
			ci.draw_rect(Rect2(x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.35))


## Tuş kapağı ("E", "WASD", "Esc"). Genişliğini döndürür.
static func keycap(ci: CanvasItem, pos: Vector2, key: String, font_size: int = 7) -> float:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 7.0
	var r := Rect2(pos, Vector2(w, 11))
	box(ci, Rect2(r.position + Vector2(0, 1), r.size), Color("8a8698"), Color(0, 0, 0, 0), 2)
	box(ci, r, Color("eeeaf6"), Color(0, 0, 0, 0), 2)
	ci.draw_string(font, pos + Vector2(3.5, 8.5), key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1b1024"))
	return w


## Label'a hap görünümü (yuvarlak koyu zemin) verir: başlıklar ve bilgi satırları için.
static func pill(label: Label, accent: Color = GOLD) -> Label:
	var sb := style(BG_SOFT, Color(accent, 0.45), 6).duplicate()
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	label.add_theme_stylebox_override("normal", sb)
	return label
