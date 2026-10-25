extends Node2D
## 3/4 üstten bakışta bir insan (yolcu, müşteri, oyuncu...). Konumu ayaklarının olduğu nokta.
## Dört yöne bakar; görünüşü assets/topdown/td_<look>.png sayfasından gelir (tools/make_topdown.py).

const CELL := Vector2(28, 30)
const POSES := ["idle", "walk1", "walk2", "punch", "kick", "block", "hurt", "sit", "lift1", "lift2", "special"]
const ROWS := {"down": 0, "up": 1, "right": 2, "left": 2}
const WALK_CYCLE := ["walk1", "idle", "walk2", "idle"]

var look := "abi"
var target := Vector2.ZERO
var speed := 40.0
var state := "queue"        # queue, walk_in, board, wander, player
var wants_seat := false     # dolu gelen metrobüse binmez, boşu bekler
var jitter := Vector2.ZERO  # kalabalık düzgün sıra gibi görünmesin
var scale_px := 1.0
var facing := "down"        # down, up, left, right
var marker := false:        # oyuncunun başının üstünde kalabalıkta kaybolmasın diye üçgen
	set(v):
		marker = v
		if is_inside_tree():
			_make_marker()

var hat := ""               # oyuncunun şapkası (ayrı katman); oyuncu görünüşlerinde GameState'ten gelir
var _sprite: Sprite2D
var _hat: Sprite2D
var _pose := "idle"
var _moving := false
var _marker_node: Node2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GameState.td_texture(look)
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.offset = -Vector2(CELL.x / 2.0, CELL.y)
	_sprite.scale = Vector2(scale_px, scale_px)
	add_child(_sprite)
	if look.begins_with("player") and hat == "":
		hat = GameState.hat
	set_hat(hat)
	_apply()
	_make_marker()


## Kalabalığın önünde kalsın diye ayrı, en üstte çizilen bir katman.
func _make_marker() -> void:
	if marker and _marker_node == null:
		_marker_node = Node2D.new()
		_marker_node.z_as_relative = false
		_marker_node.z_index = 90
		_marker_node.draw.connect(_draw_marker)
		add_child(_marker_node)


func _process(_delta: float) -> void:
	if _marker_node:
		_marker_node.queue_redraw()


func _draw() -> void:
	if _pose == "ko":
		draw_rect(Rect2(-12 * scale_px, -3 * scale_px, 24 * scale_px, 4 * scale_px), Color(0, 0, 0, 0.25))
		return
	draw_rect(Rect2(-6 * scale_px, -2 * scale_px, 12 * scale_px, 3 * scale_px), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-4 * scale_px, -3 * scale_px, 8 * scale_px, 5 * scale_px), Color(0, 0, 0, 0.18))


func _apply() -> void:
	if _sprite == null:
		return
	if _pose == "ko":
		_sprite.region_rect = Rect2(0, CELL.y * 3, CELL.x, CELL.y)
		_sprite.flip_h = facing == "left"
		_sync_hat()
		return
	var col := POSES.find(_pose)
	_sprite.region_rect = Rect2(CELL.x * maxi(col, 0), CELL.y * ROWS[facing], CELL.x, CELL.y)
	_sprite.flip_h = facing == "left"
	_sync_hat()


## Şapka katmanı gövdeyle aynı kareyi gösterir (sayfa düzeni aynı).
func _sync_hat() -> void:
	if _hat:
		_hat.region_rect = _sprite.region_rect
		_hat.flip_h = _sprite.flip_h


## Şapka tak / çıkar ("" çıkarır).
func set_hat(id: String) -> void:
	hat = id
	if _sprite == null:
		return
	if id == "":
		if _hat:
			_hat.queue_free()
			_hat = null
		return
	if _hat == null:
		_hat = Sprite2D.new()
		_hat.region_enabled = true
		_hat.centered = false
		_hat.offset = _sprite.offset
		_sprite.add_child(_hat)
	_hat.texture = GameState.hat_texture(id)
	_sync_hat()


## Başın tepesi (ayaklara göre). Oturunca biraz aşağı iner. Baloncuklar buna göre konur.
func head_y() -> float:
	if _pose == "ko":
		return -14.0 * scale_px
	return (-29.0 + (3.0 if _pose == "sit" else 0.0)) * scale_px


func _draw_marker() -> void:
	# üçgen hafifçe zıplar
	var y := head_y() - 4.0 - 2.0 * absf(sin(Time.get_ticks_msec() / 250.0))
	var w := 3.0
	_marker_node.draw_colored_polygon(PackedVector2Array([Vector2(-w - 1, y - w - 1), Vector2(w + 1, y - w - 1), Vector2(0, y + 1)]), Color("1b1024"))
	_marker_node.draw_colored_polygon(PackedVector2Array([Vector2(-w, y - w), Vector2(w, y - w), Vector2(0, y)]), Color("e6b428"))


## Hedefe doğru yürür. Vardıysa true döner.
func step_to(goal: Vector2, spd: float, delta: float) -> bool:
	var d := goal - position
	if d.length() < 1.0:
		set_moving(false)
		return true
	var move := d.limit_length(spd * delta)
	position += move
	set_moving(d.length() > 1.5, move.x, move.y)
	return false


## Yürüme animasyonu. Yön verilirse o yöne döner.
func set_moving(moving: bool, dir_x: float = 0.0, dir_y: float = 0.0) -> void:
	_moving = moving
	if dir_x != 0.0 or dir_y != 0.0:
		face(dir_x, dir_y)
	if moving:
		_pose = WALK_CYCLE[int(Time.get_ticks_msec() / 130 + get_instance_id()) % 4]
		_sprite.position.y = 0.0
	else:
		_pose = "idle"
		# ayakta dururken hafif nefes (1 piksel)
		var breath := 1.0 if int(Time.get_ticks_msec() / 700 + get_instance_id() % 7) % 2 == 0 else 0.0
		_sprite.position.y = breath * scale_px
	_apply()


## Bir yöne dön. Sadece x verilirse sağa/sola döner (eski sahnelerle uyumlu).
func face(dir_x: float, dir_y: float = 0.0) -> void:
	if absf(dir_x) >= absf(dir_y) * 0.9 and dir_x != 0.0:
		facing = "right" if dir_x > 0.0 else "left"
	elif dir_y != 0.0:
		facing = "down" if dir_y > 0.0 else "up"
	_apply()


func face_dir(dir: String) -> void:
	facing = dir
	_apply()


func face_point(p: Vector2) -> void:
	face(p.x - position.x, p.y - position.y)


func sit(dir: String = "") -> void:
	if dir != "":
		facing = dir
	_pose = "sit"
	_sprite.position.y = 0.0
	_apply()


func is_sitting() -> bool:
	return _pose == "sit"


func set_pose(pose: String) -> void:
	_pose = pose
	_sprite.position.y = 0.0
	_apply()
	queue_redraw()


## Görünüşü değiştir (ör. gardıroptan yeni kıyafet giyince).
func set_look(new_look: String) -> void:
	look = new_look
	if _sprite:
		_sprite.texture = GameState.td_texture(look)


func tint(c: Color) -> void:
	_sprite.modulate = c
