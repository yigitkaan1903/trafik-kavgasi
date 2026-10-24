extends Control
## Can barları (geride kalan "hasar izi" ile), isimler ve özel hareket göstergesi.

var player: Fighter
var enemy: Fighter
var _trail := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := GameState.make_label(player.display_name, 10, Color("e6b428"))
	left.position = Vector2(12, 20)
	add_child(left)
	var right := GameState.make_label(enemy.display_name, 10, Color("ff8a6a"))
	right.position = Vector2(278, 20)
	right.size = Vector2(190, 12)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(right)
	var hint := GameState.make_label("WASD yürü (yukarı-aşağı: hizaya gel)   J yumruk   K tekme   L blok   Boşluk kaç" +
			("   U direksiyon kilidi" if GameState.technique else ""), 8, Color(1, 1, 1, 0.6))
	hint.position = Vector2(0, 256)
	hint.size = Vector2(480, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_trail = {player: player.hp, enemy: enemy.hp}


func _process(delta: float) -> void:
	for f in [player, enemy]:
		_trail[f] = maxf(f.hp, move_toward(_trail[f], f.hp, 40.0 * delta))
	queue_redraw()


func _draw() -> void:
	_bar(Rect2(12, 8, 190, 9), player, false)
	_bar(Rect2(278, 8, 190, 9), enemy, true)
	draw_string(get_theme_default_font(), Vector2(226, 17), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6b428"))
	if GameState.technique:
		var ready := player.special_cd <= 0.0
		var r := Rect2(12, 34, 60, 4)
		draw_rect(r, Color(0, 0, 0, 0.6))
		var k := 1.0 - player.special_cd / Fighter.SPECIAL_COOLDOWN
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color("e04040") if ready else Color("804040"))


func _bar(r: Rect2, f: Fighter, mirrored: bool) -> void:
	draw_rect(r.grow(1), Color("e6b428"))
	draw_rect(r, Color("1a1020"))
	var k_trail: float = _trail[f] / f.max_hp
	var k: float = f.hp / f.max_hp
	var col := Color("4ade80") if k > 0.5 else Color("facc15") if k > 0.25 else Color("ef4444")
	for pair in [[k_trail, Color("ffffff")], [k, col]]:
		var w: float = r.size.x * pair[0]
		var x := r.position.x + (r.size.x - w if mirrored else 0.0)
		draw_rect(Rect2(x, r.position.y, w, r.size.y), pair[1])
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(1, 1, 1, 0.15))
