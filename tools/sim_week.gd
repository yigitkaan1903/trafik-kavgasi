extends SceneTree
## Denge testi: tipik bir öğrencinin 14 gününü her zorlukta simüle eder.
## Çalıştırma (proje klasöründen): godot --headless -s tools/sim_week.gd

const Places = preload("res://data/places.gd")

var gs


func _init() -> void:
	for diff in ["kolay", "normal", "zor"]:
		gs = load("res://scripts/autoload/game_state.gd").new()
		gs._no_save = true
		gs.new_game(diff)
		print("\n=== %s ===" % Places.DIFFICULTIES[diff]["name"])
		print("gün  saat   enerji tokluk  para   güç  çev  day  devam")
		var rotation := ["str", "sta", "agi"]
		for d in 14:
			var weekday: bool = gs.is_weekday()
			_act("market", "simit")
			if not gs.has_gym_access():
				_act("gym", "gym_month" if gs.money >= 300 else "gym_day")
			for k in (2 if weekday else 3):
				_act("gym", {"str": "lift", "agi": "bag", "sta": "run"}[rotation[(d * 3 + k) % 3]])
			if weekday:
				_metro_trip()
				_campus("lecture")
				_campus("cafeteria")
				_metro_trip()
			_act("carsi", "waiter")
			_act("market", "tost")
			print("%3d  %s  %5.0f  %5.0f  %5d  %4.1f %4.1f %4.1f  %d" % [gs.day, gs.clock_text(), gs.energy, gs.food,
					gs.money, gs.stats["str"], gs.stats["agi"], gs.stats["sta"], gs.week_attended])
			_act("ev", "sleep")
		print("Selim'e karşı: can %.0f (Selim 115), güç x%.2f (Selim x1.10)" % [gs.player_max_hp(), gs.player_power()])
	quit()


## Metrobüs: ~15 dk bekleme, 16 durak, yarı ihtimalle bir kavga.
func _metro_trip() -> void:
	gs.spend_time(15 + 16 * Places.METRO_MINUTES_PER_STOP)
	if randf() < 0.5:
		gs.energy = maxf(0.0, gs.energy - Places.FIGHT_ENERGY)
		gs.money += 40
		gs.spend_time(Places.FIGHT_MINUTES)


func _campus(id: String) -> void:
	var a: Dictionary = Places.CAMPUS_ACTIONS[id]
	gs.spend_time(Places.MAPS["kampus"]["walk"])
	if gs.action_block_reason(a) == "":
		gs.do_action(a)


func _act(place: String, id: String) -> void:
	if gs.place != place:
		gs.walk_to(place)
	for a in Places.PLACES[place]["actions"]:
		if a["id"] == id:
			var why: String = gs.action_block_reason(a)
			if why == "" and not gs.action_hidden(a):
				if a.has("per_order"):   # garsonluk: ortalama 9 sipariş + bahşiş
					a = a.duplicate()
					a["money"] = a["per_order"] * 9 + 25
				gs.do_action(a)
			return
