class_name Lighting
extends RefCounted
## Saate göre sahne rengi (CanvasModulate) ve hava kararınca yanan lambalar (PointLight2D).
## İç mekanlarda gün ışığının etkisi yarıya iner (ışıklar açık).

const NIGHT := Color(0.40, 0.44, 0.68)
const KEYS := [
	[0.0, NIGHT], [360.0, NIGHT], [420.0, Color(1.0, 0.84, 0.76)], [540.0, Color.WHITE],
	[1020.0, Color.WHITE], [1140.0, Color(1.0, 0.80, 0.66)], [1230.0, Color(0.62, 0.58, 0.82)],
	[1320.0, NIGHT], [1440.0, NIGHT],
]

static var _tex: Texture2D


static func time_color(outdoor: bool) -> Color:
	var m: float = GameState.minute
	var c: Color = NIGHT
	for i in KEYS.size() - 1:
		if m >= KEYS[i][0] and m <= KEYS[i + 1][0]:
			c = KEYS[i][1].lerp(KEYS[i + 1][1], (m - KEYS[i][0]) / (KEYS[i + 1][0] - KEYS[i][0]))
			break
	return c if outdoor else c.lerp(Color.WHITE, 0.55)


static func is_dark() -> bool:
	return GameState.minute >= 1170.0 or GameState.minute < 400.0


## Gece ışıklarının gücü (0 gündüz, 1 gece): 18:00-20:00 yanar, 05:30-07:00 söner.
static func night_amount() -> float:
	var m: float = GameState.minute
	if m >= 1200.0 or m < 330.0:
		return 1.0
	if m >= 1080.0:
		return (m - 1080.0) / 120.0
	if m < 420.0:
		return 1.0 - (m - 330.0) / 90.0
	return 0.0


## Sahneye zaman rengi ve lambaları ekler. always_on: iç mekan lambaları gündüz de hafif yanar.
static func apply(parent: Node, outdoor: bool, lamps: Array = [], radius: float = 90.0, always_on: bool = false) -> CanvasModulate:
	var cm := CanvasModulate.new()
	cm.color = time_color(outdoor)
	parent.add_child(cm)
	if is_dark() or always_on:
		for pos in lamps:
			var l := PointLight2D.new()
			l.texture = _light_texture()
			l.texture_scale = radius / 64.0
			l.position = pos
			l.color = Color(1.0, 0.86, 0.62)
			l.energy = 0.95 if is_dark() else 0.3
			parent.add_child(l)
	return cm


static func _light_texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.4, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex = t
	return _tex
