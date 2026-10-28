class_name Room
extends Node2D
## 3/4 üstten bakış oda: zemin görseli, y'ye göre sıralanan eşyalar ve karakterler, çarpışma, işaretler, kamera.
## Odalar tools/make_rooms.py ile üretilir: assets/rooms/<oda>.png, assets/rooms/props/*.png, data/rooms_data.gd.
##
## Kullanım:
##   var room := Room.new()
##   room.build("gym")            # sahneye eklemeden önce ya da sonra
##   add_child(room)
##   room.add_actor(person)       # y'ye göre sıralanır
##   room.follow(person)          # kamera takip eder, oda küçükse ortalar

const RoomsData = preload("res://data/rooms_data.gd")
const TOP_UI := 22.0      # üstteki durum çubuğu (ekran pikseli)
const BOTTOM_UI := 18.0   # alttaki bilgi şeridi (HintBar)
const FEET := Vector2(5, 3) # ayak kutusunun yarı boyu (çarpışma)

var id := ""
var size := Vector2.ZERO
var data: Dictionary
var floor_layer: Node2D   # zeminin hemen üstü: yere çizilen hareketli şeyler (koşu bandı, tabaklar...)
var actors: Node2D        # eşyalar ve insanlar, y'ye göre sıralı
var top_layer: Node2D     # her şeyin üstü (etiketler, seçim çerçevesi)
var cam: Camera2D
var cam_zoom := 1.0
var cam_free := false     # true: kamera oda sınırına takılmadan hedefi izler (önizleme yakınlaştırması)
var cam_fixed_y := -1.0   # >= 0 ise kamera dikeyde sabit (metrobüs: üstte hat haritası var)
var blockers: Array = []  # yolu kesen insanlar (ayak kutuları), itilebilenler "pushable" meta'sı taşır
var solids: Array[Rect2] = []
var props := {}           # eşya adı -> [Sprite2D]
var _follow: Node2D
var _texts: Node2D


func build(room_id: String) -> Room:
	id = room_id
	data = RoomsData.ROOMS[id]
	size = Vector2(data["size"][0], data["size"][1])
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/rooms/%s.png" % id)
	bg.centered = false
	add_child(bg)
	_texts = Node2D.new()
	_texts.draw.connect(_draw_texts)
	add_child(_texts)
	floor_layer = Node2D.new()
	add_child(floor_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	top_layer = Node2D.new()
	top_layer.z_index = 50
	add_child(top_layer)
	for p in data["props"]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/rooms/props/%s.png" % p[0])
		s.centered = false
		s.position = Vector2(p[1], p[3])
		s.offset = Vector2(0, p[2] - p[3])
		actors.add_child(s)
		if not props.has(p[0]):
			props[p[0]] = []
		props[p[0]].append(s)
	for r in data["solids"]:
		solids.append(Rect2(r[0], r[1], r[2], r[3]))
	return self


func add_actor(node: Node2D) -> void:
	actors.add_child(node)


# ---------------------------------------------------------------- İşaretler

func mark(name: String) -> Vector2:
	var m: Array = data["marks"].get(name, [size.x / 2.0, size.y / 2.0])
	return Vector2(m[0], m[1])


func has_mark(name: String) -> bool:
	return data["marks"].has(name)


## İsimli liste (koltuklar, masalar...). İki sayılı öğeler Vector2'ye çevrilir.
func points(name: String) -> Array:
	var out: Array = []
	for it in data["lists"].get(name, []):
		out.append(Vector2(it[0], it[1]) if it.size() == 2 else it)
	return out


func rects(name: String) -> Array:
	var out: Array = []
	for r in data["rects"].get(name, []):
		out.append(Rect2(r[0], r[1], r[2], r[3]))
	return out


func lamps() -> Array:
	return points("lamps")


# ---------------------------------------------------------------- Çarpışma

## Yolu kesen biri (ayakta duran NPC). pushable: oyuncu itince kenara kayar (kalabalık metrobüs).
func add_blocker(node: Node2D, pushable: bool = false) -> void:
	node.set_meta("pushable", pushable)
	blockers.append(node)


func remove_blocker(node: Node2D) -> void:
	blockers.erase(node)


func _blocker_at(box: Rect2, who: Node2D) -> Node2D:
	for b in blockers:
		if b == who or not is_instance_valid(b) or not b.visible:
			continue
		if Rect2(b.position - FEET, FEET * 2.0).intersects(box):
			return b
	return null


## Ayak kutusu (half: yarı boyut) bir engele, birine ya da oda dışına taşıyor mu?
func blocked(p: Vector2, half: Vector2 = FEET, who: Node2D = null) -> bool:
	var box := Rect2(p - half, half * 2.0)
	if box.position.x < 0.0 or box.position.y < 0.0 or box.end.x > size.x or box.end.y > size.y:
		return true
	for s in solids:
		if s.intersects(box):
			return true
	return who != null and _blocker_at(box, who) != null


func blocked_by_solid(p: Vector2, half: Vector2 = FEET) -> bool:
	return blocked(p, half, null)


## Engellere kayarak hareket: önce x, sonra y denenir. who verilirse diğer insanlara da çarpar.
func slide(from: Vector2, motion: Vector2, half: Vector2 = FEET, who: Node2D = null) -> Vector2:
	var p := from
	var box := Rect2(from - half, half * 2.0)
	for s in solids:   # zaten bir eşyanın içinde kalmışsa (ör. alet başında) sıkışmasın: ondan uzaklaşan adıma izin ver
		if s.intersects(box):
			var c := s.get_center()
			return from + motion if (from + motion).distance_to(c) > from.distance_to(c) else from
	if motion.x != 0.0 and not blocked(p + Vector2(motion.x, 0), half, who):
		p.x += motion.x
	if motion.y != 0.0 and not blocked(p + Vector2(0, motion.y), half, who):
		p.y += motion.y
	return p


## Yürüyen biri için: girdiyle hareket ettirir, animasyonu ayarlar. Gerçekten hareket ettiyse true.
## Önündeki itilebilir biri varsa onu biraz kenara iter (kalabalıkta yol açmak).
func walk(person: Node2D, dir: Vector2, spd: float, delta: float) -> bool:
	if dir == Vector2.ZERO:
		person.set_moving(false)
		return false
	var before := person.position
	var motion := dir.normalized() * spd * delta
	person.position = slide(before, motion, FEET, person)
	var moved := person.position.distance_to(before) > motion.length() * 0.5
	if not moved:
		_push_aside(person, before + motion * 3.0, dir)
	moved = person.position.distance_to(before) > 0.01
	person.set_moving(moved, dir.x, dir.y)
	if not moved:
		person.face(dir.x, dir.y)
	return moved


func _push_aside(pusher: Node2D, at: Vector2, dir: Vector2) -> void:
	var b := _blocker_at(Rect2(at - FEET, FEET * 2.0), pusher)
	if b == null or not b.get_meta("pushable", false):
		return
	# yana doğru (hareket yönüne dik) kay; olmazsa ileri
	var side := Vector2(-dir.y, dir.x).normalized()
	if side.dot(b.position - pusher.position) < 0.0:
		side = -side
	for step in [side, (side + dir.normalized()).normalized(), dir.normalized()]:
		var to: Vector2 = b.position + step * 1.2
		if not blocked(to, FEET, b) and Rect2(to - FEET, FEET * 2.0).intersects(Rect2(pusher.position - FEET, FEET * 2.0)) == false:
			b.position = to
			if b.has_method("face_point") and randf() < 0.05:
				b.face_point(pusher.position)
			return


## Bir noktaya doğru (engellere kayarak) yürür. Vardıysa ya da takıldıysa true.
func walk_to(person: Node2D, goal: Vector2, spd: float, delta: float) -> bool:
	var d := goal - person.position
	if d.length() < 2.0:
		person.set_moving(false)
		return true
	var step := d.limit_length(spd * delta)
	var before: Vector2 = person.position
	person.position = slide(before, step, FEET, person)
	if person.position.distance_to(before) < spd * delta * 0.2:
		# doğrudan gidemiyor: sadece yatay ya da dikey dene
		var alt := Vector2(step.x, 0) if absf(d.x) > absf(d.y) else Vector2(0, step.y)
		person.position = slide(before, alt.normalized() * spd * delta, FEET, person)
		if person.position.distance_to(before) < 0.01:
			person.set_moving(false)
			return true
	person.set_moving(true, d.x, d.y)
	return false


# ---------------------------------------------------------------- Kamera

## Kamera hedefi takip eder; oda ekrandan küçükse ortalanır. Üstteki durum çubuğu payı bırakılır.
func follow(target: Node2D, zoom: float = 1.0, fixed_y: float = -1.0) -> Camera2D:
	_follow = target
	cam_zoom = zoom
	cam_fixed_y = fixed_y
	if cam == null:
		cam = Camera2D.new()
		add_child(cam)
	cam.zoom = Vector2(zoom, zoom)
	cam.make_current()
	update_camera()
	return cam


func update_camera() -> void:
	if cam == null or not is_instance_valid(_follow):
		return
	var view := Vector2(480, 270) / cam_zoom
	var top := TOP_UI / cam_zoom
	var bottom := BOTTOM_UI / cam_zoom
	var c := Vector2.ZERO
	if size.x <= view.x:
		c.x = size.x / 2.0
	else:
		c.x = clampf(_follow.position.x, view.x / 2.0, size.x - view.x / 2.0)
	var band := view.y - top - bottom
	if cam_free:
		cam.position = (_follow.position + Vector2(0, -12)).round()
		return
	if cam_fixed_y >= 0.0:
		c.y = cam_fixed_y
	elif size.y <= band:
		c.y = size.y / 2.0 - (top - bottom) / 2.0
	else:
		c.y = clampf(_follow.position.y - 10.0, view.y / 2.0 - top, size.y - view.y / 2.0 + bottom)
	cam.position = c.round()


func _process(_delta: float) -> void:
	update_camera()


## Dünya noktasının ekrandaki yeri (arayüz katmanına bir şey koymak için).
func to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


# ---------------------------------------------------------------- Çizim

## Duvarlardaki tabela yazıları ve gece pencereleri.
func _draw_texts() -> void:
	var font := ThemeDB.fallback_font
	for t in data["texts"]:
		if t[3] != "":
			_texts.draw_string(font, Vector2(t[0], t[1]), t[3], HORIZONTAL_ALIGNMENT_CENTER, t[2], t[4], Color(t[5]))
	if Lighting.is_dark():
		for r in rects("windows"):
			_texts.draw_rect(r, Color(0.04, 0.05, 0.14, 0.82))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(r.position.x)
			for k in int(r.size.x / 6):
				_texts.draw_rect(Rect2(r.position.x + rng.randi_range(1, int(r.size.x) - 3), r.position.y + rng.randi_range(r.size.y / 2.0, r.size.y - 2), 1, 1), Color("ffd27a"))


func redraw_texts() -> void:
	_texts.queue_redraw()
