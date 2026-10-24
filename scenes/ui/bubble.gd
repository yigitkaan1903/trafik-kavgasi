class_name Bubble
extends Node2D
## Bir karakterin üstünde beliren konuşma baloncuğu. Hedefi takip eder, süresi bitince kaybolur.

const FONT_SIZE := 8

var text := ""
var target: Node2D
var offset := Vector2(0, -54)
var life := 2.5
var color := Color.WHITE


## Kısayol: hedefin üstünde baloncuk çıkarır. Hedefte zaten baloncuk varsa onu değiştirir.
## Hedef baş yüksekliğini biliyorsa (Person.head_y) baloncuk tam başın üstüne konur.
static func say(parent: Node, who: Node2D, line: String, height: float = 54.0, seconds: float = 2.5) -> Bubble:
	# baloncuklar kamerayı takip eden ayrı bir katmanda: gece sahne kararınca onlar kararmaz
	var layer: CanvasLayer = parent.get_node_or_null("BubbleLayer")
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "BubbleLayer"
		layer.layer = 2
		layer.follow_viewport_enabled = true
		parent.add_child(layer)
	parent = layer
	for c in parent.get_children():
		if c is Bubble and c.target == who:
			c.queue_free()
	var b := Bubble.new()
	b.text = line
	b.target = who
	b.offset = Vector2(0, (who.head_y() - 3.0) if who.has_method("head_y") else -height)
	b.life = seconds
	parent.add_child(b)
	b._follow()
	return b


func _ready() -> void:
	z_as_relative = false
	z_index = 100


func _process(delta: float) -> void:
	_follow()
	life -= delta
	modulate.a = clampf(life / 0.3, 0.0, 1.0)
	if life <= 0.0:
		queue_free()


func _follow() -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("head_y"):
		offset.y = target.head_y() - 3.0   # oturup kalkınca da başın üstünde kalsın
	var pos := target.global_position + offset
	# ekran kenarında kesilmesin: ekran koordinatında içeri kaydır (kameralı sahnelerde de)
	var half := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0 + 6.0
	var xf := get_viewport().get_canvas_transform() if get_viewport() else Transform2D.IDENTITY
	var screen := xf * pos
	visible = screen.x > -10.0 and screen.x < 490.0   # konuşan ekran dışındaysa baloncuk görünmez
	screen.x = clampf(screen.x, half, 480.0 - half)
	screen.y = maxf(screen.y, 16.0)
	global_position = (xf.affine_inverse() * screen).round()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
	var r := Rect2(roundf(-w / 2.0), -13, roundf(w), 12)
	draw_rect(r.grow(1), Color("1b1024"))
	draw_rect(r, color)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -1), Vector2(3, -1), Vector2(0, 4)]), Color("1b1024"))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(0, 2)]), color)
	draw_string(font, Vector2(r.position.x + 4, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("1b1024"))
