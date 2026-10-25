extends Node
## Müzik ve ses efektleri. Her sahneden `Audio` diye erişilir.
## Müzik sahneye göre kendiliğinden seçilir (dövüşte gergin, başka her yerde sakin) ve yumuşak geçişle değişir.
## Butonlara basınca tık sesi otomatik çalar. Sesler tools/make_audio.py ile üretilir (assets/audio).

const MUSIC := {"chill": "res://assets/audio/music_chill.wav", "fight": "res://assets/audio/music_fight.wav"}
const FADE := 0.8
const MUSIC_GAIN := {"chill": 1.0, "fight": 0.5}   # dövüş müziği daha kısık
const SFX_GAIN := 0.18       # efektler müziğin altında kalsın (ayardaki %100 = bu kadar)

var music_volume := 0.6:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_volume()
var sfx_volume := 0.8

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _scene_path := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for i in 8:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx_pool.append(s)
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if path != _scene_path:
		_scene_path = path
		play_music("fight" if path.ends_with("fight.tscn") else "chill")


## Müziği değiştir (aynıysa dokunma). Eski parça kısılırken yenisi açılır.
func play_music(name: String) -> void:
	if name == _current or not MUSIC.has(name):
		return
	_current = name
	var stream: AudioStreamWAV = _load(MUSIC[name])
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var old := _players[_active]
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = -80.0
	p.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", _music_db(), FADE)
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.chain().tween_callback(old.stop)


## Kısa ses efekti. pitch_var: her çalışta küçük perde farkı (tekrar eden sesler mekanik durmasın).
func sfx(name: String, volume: float = 1.0, pitch_var: float = 0.06) -> void:
	if sfx_volume <= 0.001:
		return
	var stream = _load("res://assets/audio/sfx_%s.wav" % name)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(maxf(0.0001, sfx_volume * volume * SFX_GAIN))
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func _load(path: String):
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _music_db() -> float:
	return linear_to_db(maxf(0.0001, music_volume * 0.8 * MUSIC_GAIN.get(_current, 1.0)))


func _apply_volume() -> void:
	if _players.size() == 2 and _players[_active].playing:
		_players[_active].volume_db = _music_db()


## Oyundaki bütün butonlara tık sesi.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func(): sfx("click", 0.6, 0.02))
