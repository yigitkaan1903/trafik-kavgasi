extends Sprite2D
## Trafikteki diğer arabalar. Bazıları ("kırıcılar") oyuncunun önüne aniden kırar.

const Cars = preload("res://data/cars.gd")

var rival_id := ""
var decor := false          # süs araba: sürücü yine bir rakip ama arabası iddiaya konamaz
var speed := 60.0
var lane := 0
var cutter := false
var _did_cut := false


func setup(id: String, lane_index: int, x: float) -> void:
	rival_id = id
	lane = lane_index
	texture = GameState.car_texture(GameState.rival(id)["car"])
	if randf() < 0.45:   # trafik çeşitlensin: sürücü aynı, araba süs modellerden biri
		decor = true
		texture = GameState.car_texture(Cars.DECOR.pick_random())
	position = Vector2(x, -40)
	match GameState.rival(id)["car"]:
		"kamyon", "dolmus":
			speed = randf_range(40, 58)
		"bmw":
			speed = randf_range(70, 105)
		_:
			speed = randf_range(48, 82)
	cutter = randf() < (0.45 if id == "selim" else 0.25)


func update_ai(delta: float, traffic: Node) -> void:
	# önündeki arabaya yaklaşınca yavaşla
	for o in traffic.npcs:
		if o != self and o.lane == lane and o.position.y < position.y and position.y - o.position.y < 52:
			speed = minf(speed, o.speed)
	# sinyal vermeden oyuncunun önüne kır
	var gap: float = traffic.player.position.y - position.y
	if cutter and not _did_cut and absi(lane - traffic.lane) == 1 and gap > 55.0 and gap < 115.0 \
			and traffic.lane_free(traffic.lane, position.y, self):
		lane = traffic.lane
		_did_cut = true
		speed = maxf(35.0, speed - 15.0)   # bir de fren yapar
	position.x = move_toward(position.x, traffic.LANES[lane], 55.0 * delta)
	rotation = clampf((traffic.LANES[lane] - position.x) * 0.02, -0.2, 0.2)


func hit_rect() -> Rect2:
	var s := texture.get_size() - Vector2(4, 4)
	return Rect2(position - s / 2.0, s)
