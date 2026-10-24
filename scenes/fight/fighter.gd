class_name Fighter
extends Node2D
## Oyuncu ve rakip için ortak dövüşçü (3/4 üstten bakış, beat'em-up gibi): sağa-sola ve derinliğine
## (yukarı-aşağı) yürünür, vuruş için aynı hizada olmak gerekir. Durumlar, saldırılar, hasar, animasyon.
## Alt sınıflar her karede `_think()` içinde input_dir / input_dir_y / want_block ayarlar ve
## start_attack() / start_dodge() çağırır. Görünüş: assets/topdown/td_<look>.png (yan satır).

signal got_hit(target: Fighter, attack_name: String, damage: float, blocked: bool)
signal dodged(target: Fighter)
signal knocked_out(target: Fighter)

enum S { IDLE, WALK, ATTACK, BLOCK, HURT, DODGE, STUN, KO }

const CELL := Vector2(28, 30)
const POSES := ["idle", "walk1", "walk2", "punch", "kick", "block", "hurt", "sit", "lift1", "lift2", "special"]
const DEPTH := 6.0             # vuruşun tutması için derinlik farkı en fazla bu kadar
const ATTACKS := {
	"punch": {"pose": "punch", "startup": 0.07, "active": 0.08, "recovery": 0.14,
		"damage": 6.0, "range": 18.0, "knock": 30.0, "stun": 0.22},
	"kick": {"pose": "kick", "startup": 0.14, "active": 0.1, "recovery": 0.26,
		"damage": 10.0, "range": 22.0, "knock": 55.0, "stun": 0.3},
	"special": {"pose": "special", "startup": 0.22, "active": 0.12, "recovery": 0.35,
		"damage": 22.0, "range": 24.0, "knock": 110.0, "stun": 0.55},
}
const SPECIAL_COOLDOWN := 6.0
const DODGE_TIME := 0.25

var look := "player"
var display_name := ""
var max_hp := 100.0
var hp := 100.0
var power := 1.0
var move_speed := 35.0
var block_chip := 0.2          # bloklanan vuruşta alınan hasar oranı
var dodge_cooldown := 0.7
var arena := Rect2(20, 80, 440, 70)

var opponent: Fighter
var facing := 1
var state := S.IDLE
var frozen := false            # vuruş anında kısa donma (hitstop) için

var input_dir := 0.0
var input_dir_y := 0.0
var want_block := false

var attack_name := ""
var _t := 0.0
var _stun_time := 0.0
var _attack_hit := false
var _vel_x := 0.0
var _invuln := 0.0
var _dodge_cd := 0.0
var special_cd := 0.0
var _flash := 0.0

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GameState.td_texture(look)
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.offset = -Vector2(CELL.x / 2.0, CELL.y)
	add_child(_sprite)
	hp = max_hp


func _draw() -> void:
	# gölge
	draw_rect(Rect2(-8, -2, 16, 3), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-5, -3, 10, 5), Color(0, 0, 0, 0.2))


## Başın tepesi (vuruş yazıları ve baloncuklar için).
func head_y() -> float:
	return -14.0 if state == S.KO else -29.0


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_flash = maxf(0.0, _flash - delta)

	if state != S.KO and opponent:
		_think(delta)
		if can_act() and opponent.position.x != position.x:
			facing = 1 if opponent.position.x > position.x else -1

	_t += delta
	match state:
		S.IDLE, S.WALK:
			if want_block:
				state = S.BLOCK
			elif input_dir != 0.0 or input_dir_y != 0.0:
				state = S.WALK
				var backwards := input_dir != 0.0 and signf(input_dir) != facing
				position.x += input_dir * move_speed * (0.75 if backwards else 1.0) * delta
				position.y += input_dir_y * move_speed * 0.65 * delta
			else:
				state = S.IDLE
		S.BLOCK:
			if not want_block:
				state = S.IDLE
		S.ATTACK:
			var a: Dictionary = ATTACKS[attack_name]
			if not _attack_hit and _t >= a["startup"] and _t < a["startup"] + a["active"]:
				_try_hit(a)
			if _t >= a["startup"] + a["active"] + a["recovery"]:
				state = S.IDLE
		S.HURT, S.STUN:
			if _t >= _stun_time:
				state = S.IDLE
		S.DODGE:
			if _t >= DODGE_TIME:
				state = S.IDLE

	position.x += _vel_x * delta
	_vel_x = move_toward(_vel_x, 0.0, 450.0 * delta)
	position.x = clampf(position.x, arena.position.x, arena.end.x)
	position.y = clampf(position.y, arena.position.y, arena.end.y)
	_update_pose()


## Alt sınıflar doldurur.
func _think(_delta: float) -> void:
	pass


func can_act() -> bool:
	return state == S.IDLE or state == S.WALK or state == S.BLOCK


func start_attack(name: String) -> bool:
	if not can_act():
		return false
	if name == "special":
		if special_cd > 0.0:
			return false
		special_cd = SPECIAL_COOLDOWN
	state = S.ATTACK
	attack_name = name
	_t = 0.0
	_attack_hit = false
	return true


func start_dodge() -> bool:
	if not can_act() or _dodge_cd > 0.0:
		return false
	state = S.DODGE
	_t = 0.0
	_invuln = DODGE_TIME + 0.05
	_dodge_cd = dodge_cooldown
	_vel_x = -facing * 130.0
	return true


func stun(seconds: float) -> void:
	state = S.STUN
	_t = 0.0
	_stun_time = seconds


func is_attacking() -> bool:
	return state == S.ATTACK


## Aynı hizada mı (derinlik farkı az mı)?
func in_line(other: Fighter) -> bool:
	return absf(other.position.y - position.y) <= DEPTH


func _try_hit(a: Dictionary) -> void:
	var dx := (opponent.position.x - position.x) * facing
	if dx > 0.0 and dx <= a["range"] and in_line(opponent):
		_attack_hit = true
		opponent.receive_hit(self, attack_name)


func receive_hit(attacker: Fighter, name: String) -> void:
	if state == S.KO:
		return
	if _invuln > 0.0:
		dodged.emit(self)
		return
	var a: Dictionary = ATTACKS[name]
	var dmg: float = a["damage"] * attacker.power
	var blocked := state == S.BLOCK and facing == -attacker.facing and name != "special"
	if blocked:
		dmg *= block_chip
		_vel_x = attacker.facing * a["knock"] * 0.6
	else:
		state = S.HURT
		_t = 0.0
		_stun_time = a["stun"]
		_vel_x = attacker.facing * a["knock"]
		_flash = 0.1
	hp = maxf(0.0, hp - dmg)
	got_hit.emit(self, name, dmg, blocked)
	if hp <= 0.0:
		state = S.KO
		_vel_x = attacker.facing * 120.0
		knocked_out.emit(self)


func _update_pose() -> void:
	var pose := "idle"
	match state:
		S.WALK:
			pose = ["walk1", "idle", "walk2", "idle"][int(Time.get_ticks_msec() / 110) % 4]
		S.ATTACK:
			pose = ATTACKS[attack_name]["pose"]
		S.BLOCK:
			pose = "block"
		S.HURT, S.STUN:
			pose = "hurt"
		S.DODGE:
			pose = "walk2"
	if state == S.KO:
		_sprite.region_rect = Rect2(0, CELL.y * 3, CELL.x, CELL.y)
	else:
		_sprite.region_rect = Rect2(CELL.x * POSES.find(pose), CELL.y * 2, CELL.x, CELL.y)
	_sprite.flip_h = facing < 0
	if _flash > 0.0:
		_sprite.modulate = Color(1.0, 0.45, 0.45)
	elif state == S.DODGE:
		_sprite.modulate = Color(1, 1, 1, 0.55)
	elif state == S.STUN:
		_sprite.modulate = Color(0.8, 0.8, 1.0)
	else:
		_sprite.modulate = Color.WHITE
	# yumrukta hafif ileri hamle, idle'da nefes alma
	var lean := 0.0
	if state == S.ATTACK and _t < ATTACKS[attack_name]["startup"]:
		lean = -1.0
	_sprite.position = Vector2(lean * facing, 1 if state == S.IDLE and int(Time.get_ticks_msec() / 400) % 2 == 0 else 0)
