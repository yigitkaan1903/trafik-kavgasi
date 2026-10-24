extends Fighter
## Basit rakip yapay zekâsı. Davranışı rivals.gd içindeki aggro / block / speed belirler.
## Önce oyuncuyla aynı hizaya (derinliğe) gelir, sonra yaklaşıp vurur.

var aggro := 0.4
var reflex := 0.25
var think_speed := 1.0
var active := false

var _plan := "idle"
var _decide_t := 0.5
var _block_hold := 0.0
var _reacted := false
var _drift := 0.0             # bazen biraz yukarı-aşağı kayar, hep aynı çizgide durmasın


func _think(delta: float) -> void:
	input_dir = 0.0
	input_dir_y = 0.0
	if not active:
		want_block = false
		return
	var dist := absf(opponent.position.x - position.x)
	var toward := signf(opponent.position.x - position.x)
	var dy := opponent.position.y + _drift - position.y

	# Gelen saldırıya tepki: blok ya da kaçış (her saldırıda bir kez zar atılır)
	if opponent.is_attacking():
		if not _reacted and dist < 30.0 and in_line(opponent):
			_reacted = true
			var roll := randf()
			if roll < reflex:
				_block_hold = randf_range(0.3, 0.5)
			elif roll < reflex * 1.4:
				start_dodge()
	else:
		_reacted = false

	if _block_hold > 0.0:
		_block_hold -= delta
		want_block = true
		return
	want_block = false

	_decide_t -= delta * think_speed
	if _decide_t <= 0.0:
		_decide_t = randf_range(0.25, 0.6)
		_drift = randf_range(-10.0, 10.0) if randf() < 0.25 else 0.0
		var roll := randf()
		if dist > 24.0:
			_plan = "approach" if roll < 0.6 + aggro * 0.4 else "idle"
		elif roll < aggro:
			_plan = "attack"
		elif roll < aggro + 0.15:
			_plan = "retreat"
		elif roll < aggro + 0.3:
			_plan = "block"
		else:
			_plan = "idle"

	# hizaya gel (saldırırken tam hizaya, diğer zamanlarda biraz kayarak)
	if absf(dy) > 2.0 and _plan != "block":
		input_dir_y = signf(dy)

	match _plan:
		"approach":
			if dist > 16.0:
				input_dir = toward
			else:
				_plan = "attack" if randf() < aggro else "idle"
		"attack":
			_drift = 0.0
			if dist > 20.0:
				input_dir = toward
			elif in_line(opponent):
				var which := "punch" if dist < 17.0 and randf() < 0.65 else "kick"
				if start_attack(which):
					_plan = "idle"
		"retreat":
			input_dir = -toward
		"block":
			want_block = true
