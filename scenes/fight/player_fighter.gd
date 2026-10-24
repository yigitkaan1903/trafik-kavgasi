extends Fighter
## Klavyeyle kontrol edilen dövüşçü. Saldırı tuşlarını kısa süre hafızada tutar
## (input buffer) ki önceki hareket biterken basılan tuş kaybolmasın.

const BUFFER_TIME := 0.15

var controls_enabled := false
var _buffered := ""
var _buffer_t := 0.0


func _think(delta: float) -> void:
	if not controls_enabled:
		input_dir = 0.0
		input_dir_y = 0.0
		want_block = false
		return
	if GameState.autoplay:
		_autopilot()
		return
	input_dir = Input.get_axis("move_left", "move_right")
	input_dir_y = Input.get_axis("move_up", "move_down")
	want_block = Input.is_action_pressed("block")

	for action in ["punch", "kick", "special", "dodge"]:
		if Input.is_action_just_pressed(action):
			if action == "special" and not GameState.technique:
				continue
			_buffered = action
			_buffer_t = BUFFER_TIME
	if _buffered != "":
		var done := start_dodge() if _buffered == "dodge" else start_attack(_buffered)
		_buffer_t -= delta
		if done or _buffer_t <= 0.0:
			_buffered = ""


func _autopilot() -> void:
	var dist := absf(opponent.position.x - position.x)
	var dy := opponent.position.y - position.y
	input_dir = signf(opponent.position.x - position.x) if dist > 15.0 else 0.0
	input_dir_y = signf(dy) if absf(dy) > 3.0 else 0.0
	want_block = false
	if dist <= 18.0 and in_line(opponent) and randf() < 0.08:
		start_attack(["punch", "kick"].pick_random())
