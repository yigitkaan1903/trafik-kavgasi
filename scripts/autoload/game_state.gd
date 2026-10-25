extends Node
## Oyunun kalıcı durumu: zaman, ihtiyaçlar, statlar, para, arabalar, nam, kayıt.
## Her sahneden `GameState` diye erişilir. Denge sayıları data/places.gd içinde.

const Cars = preload("res://data/cars.gd")
const Rivals = preload("res://data/rivals.gd")
const MetroEvents = preload("res://data/metro_events.gd")
const Places = preload("res://data/places.gd")
const Shop = preload("res://data/shop.gd")
const Messages = preload("res://data/messages.gd")
const Skills = preload("res://data/skills.gd")

const SAVE_VERSION := 2
const SAVE_PATH := "user://save.json"
const GOD_MONEY := 999999      # God Mode (test zorluğu): sınırsız para. Test bitince kaldırılacak.
const SETTINGS_PATH := "user://settings.cfg"
const FONT_PATH := "res://assets/fonts/Rubik.ttf"              # gövde metinleri: okunaklı
const TITLE_FONT_PATH := "res://assets/fonts/PixelifySans.ttf"  # büyük başlıklar: pixel havası
const TITLE_SIZE := 16                                          # bu boyuttan büyük yazılar pixel fontla
const START_MONEY := 60      # cepteki ilk harçlık
const REPAIR_COST := 25      # kaporta puanı başına tamir
const TOW_COST := 100        # araba hurda olunca çekici

const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_PLACE := "res://scenes/places/place.tscn"
const SCENE_ACTIVITY := "res://scenes/activities/activity.tscn"
const SCENE_WAITER := "res://scenes/activities/waiter.tscn"
const SCENE_METRO := "res://scenes/metro/metrobus.tscn"
const SCENE_STATION := "res://scenes/metro/station.tscn"
const SCENE_SEATS := "res://scenes/metro/seat_rush.tscn"
const SCENE_TRAFFIC := "res://scenes/traffic/traffic.tscn"
const SCENE_GARAGE := "res://scenes/garage/garage.tscn"
const SCENE_FIGHT := "res://scenes/fight/fight.tscn"
const SCENE_MENU := "res://scenes/menu/main_menu.tscn"

## Nam: aynı rakibi her yenişinde korku seviyesi 1 artar (en fazla MAX_FEAR).
## Her seviye rakibin canını, gücünü, saldırganlığını ve refleksini biraz düşürür.
const MAX_FEAR := 5
const FEAR_HP := 0.08
const FEAR_POWER := 0.05
const FEAR_AGGRO := 0.08
const FEAR_BLOCK := 0.06
const INTIMIDATE_FEAR := 3   # bu seviyeden sonra "gözdağı ver" seçeneği açılır
const SIMIT_HP := 15          # simit yiyince sonraki kavgada ek can
const SIMIT_PRICE := 5

const UPGRADES := {
	"engine": {"name": "Motor", "max": 3, "base": 150, "desc": "+%10 hız"},
	"armor": {"name": "Kaporta", "max": 3, "base": 120, "desc": "+1 dayanıklılık"},
	"horn": {"name": "Korna", "max": 2, "base": 100, "desc": "Rakip dövüş başında sersemler"},
}

# ---- günlük hayat
var day := 1                  # 1 = ilk pazartesi
var minute := 420.0           # gün içi dakika (07:00)
var energy := 100.0
var food := 70.0              # tokluk
var stats := {}               # "str", "agi", "sta"
var trained_today := {}       # bugün hangi kas kaç kez çalışıldı
var difficulty := "normal"
var place := "ev"             # haritada nerede olduğun
var map_id := "mahalle"        # hangi haritadasın: mahalle ya da kampus
var done_today := {}           # günde bir kez yapılabilenler: anahtar -> gün
var fridge := 0               # evdeki hazır yemek (öğün)
var protein_days := 0
var gym_until := 0            # aylık üyeliğin bittiği gün
var gym_day_pass := 0         # günlük giriş alınan gün
var week_attended := 0
var last_lecture_day := 0
var good_weeks := 0           # art arda devamı tutturulan hafta
var technique := false        # Direksiyon Kilidi
var messages: Array = []      # telefondaki mesajlar: [gönderen, metin], yeniden eskiye
var unread := 0               # okunmamış mesaj sayısı (telefondaki bildirim)
var outfit := "esofman"       # üzerindeki kıyafet (data/shop.gd OUTFITS)
var hair := "sidepart"          # berberde seçilen saç (data/shop.gd HAIRCUTS)
var outfits_owned: Array = ["esofman"]
var weapons_owned: Array = []
var weapon := ""              # çantadaki silah ("" yok)
var skills_owned: Array = []  # açılan yetenekler (data/skills.gd)
var skill_points := 0         # harcanmamış yetenek puanı (seviye atlayınca)
var level := 1
var xp := 0                   # bu seviyedeki XP
var metro_seat := -1          # metrobüste oturduğun koltuk (sahne değişince aynı yer)
var place_spawn := ""         # mekan açılınca nerede başlanır (ör. butikten çıkınca çarşıda kapının önü)
var pending_notice := ""      # haritaya dönünce gösterilecek uyarı (ör. bayıldın)

# ---- para, arabalar, kavgalar
var money := START_MONEY:      # God Mode'da (test) para hiç azalmaz
	set(v):
		money = maxi(v, GOD_MONEY) if difficulty == "god" else v
var cars: Array = []          # her biri {"id", "engine", "armor", "horn", "damage"}
var active_car := -1          # -1: araba yok, metrobüsle gidiyoruz
var nam := {}                 # rakip id -> kaç kez yendin
var wins := 0
var losses := 0
var traffic_wins := 0
var distance_m := 0.0
var metro_station := 0
var metro_dir := 1
var intro_seen := false
var metro_on_board := false   # metrobüse bindik mi (yoksa durakta mıyız)
var metro_seated := false
var simit_buff := false
var drive_dest := ""          # arabayla gidilen harita ("kampus" / "mahalle"); "" ise serbest sürüş
var drive_left := 0.0         # varışa kalan metre
var blast_best := 0           # telefondaki Block Blast rekoru

# Sahneler arası geçici bilgi
var fight_rival := ""
var fight_bet := false
var fight_venue := "traffic"  # "traffic", "bus", "durak"
var fight_seat_stake := ""    # "gain": kazanınca oturursun, "keep": kaybedince kalkarsın
var station_fight := false     # durakta kaynak yüzünden çıkan kavga
var station_return := ""       # kavgadan sonra durakta nereden devam: "front" / "back"
var board_bus_type := "bos"    # bindiğimiz metrobüs: "bos" / "dolu"
var board_ahead := 0           # bizden önce binen kişi sayısı
var open_place := "ev"         # mekan ekranı hangi yeri gösterecek
var activity := {}              # ayrı sahnede oynanan eylem (garsonluk, ders, yemekhane)

var fullscreen := true
var screen_shake := true      # dövüşte ekran sarsıntısı (ayarlardan kapatılabilir)
var ui_theme: Theme
var title_font: Font
var _fade: ColorRect
var _busy := false
var autoplay := false     # test için: oyuncu kendi kendine dövüşür
var _no_save := false     # geliştirici komutlarıyla açılınca kaydı bozma


func _ready() -> void:
	_setup_cursors()
	_setup_input()
	_setup_theme()
	_setup_fade()
	new_game()
	load_game()
	_load_settings()
	_debug_args()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Kayıt

func new_game(diff: String = "normal") -> void:
	difficulty = diff
	day = 1
	minute = Places.START_MINUTE
	energy = 100.0
	food = 70.0
	stats = {"str": Places.STAT_START, "agi": Places.STAT_START, "sta": Places.STAT_START}
	trained_today = {}
	place = "ev"
	map_id = "mahalle"
	done_today = {}
	fridge = 1
	protein_days = 0
	gym_until = 0
	gym_day_pass = 0
	week_attended = 0
	last_lecture_day = 0
	good_weeks = 0
	technique = false
	messages = []
	unread = 0
	outfit = "esofman"
	hair = "sidepart"
	outfits_owned = ["esofman"]
	weapons_owned = []
	weapon = ""
	skills_owned = []
	skill_points = 0
	level = 1
	xp = 0
	metro_seat = -1
	pending_notice = ""
	add_message("Annem", "Okulun ilk haftası! Haftada en az %d gün derse git, harçlığın pazartesi yatsın." % Places.ATTEND_NEEDED)
	money = START_MONEY
	cars = []
	active_car = -1
	nam = {}
	wins = 0
	losses = 0
	traffic_wins = 0
	distance_m = 0.0
	metro_station = 0
	metro_dir = 1
	intro_seen = false
	metro_on_board = false
	metro_seated = false
	simit_buff = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if _no_save:
		return
	var data := {
		"version": SAVE_VERSION,
		"day": day, "minute": minute, "energy": energy, "food": food, "stats": stats,
		"trained_today": trained_today, "difficulty": difficulty, "place": place, "fridge": fridge,
		"map_id": map_id, "done_today": done_today,
		"protein_days": protein_days, "gym_until": gym_until, "gym_day_pass": gym_day_pass,
		"week_attended": week_attended, "last_lecture_day": last_lecture_day, "good_weeks": good_weeks,
		"technique": technique, "messages": messages,
		"money": money, "cars": cars, "active_car": active_car, "nam": nam,
		"wins": wins, "losses": losses, "traffic_wins": traffic_wins, "distance_m": distance_m,
		"metro_station": metro_station, "metro_dir": metro_dir, "intro_seen": intro_seen,
		"metro_on_board": metro_on_board, "metro_seated": metro_seated, "simit_buff": simit_buff,
		"blast_best": blast_best, "drive_dest": drive_dest, "drive_left": drive_left, "unread": unread,
		"outfit": outfit, "hair": hair, "outfits_owned": outfits_owned, "weapons_owned": weapons_owned, "weapon": weapon,
		"skills_owned": skills_owned, "skill_points": skill_points, "level": level, "xp": xp,
		"metro_seat": metro_seat,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(data) != TYPE_DICTIONARY:
		return false
	money = int(data.get("money", START_MONEY))
	cars = []
	for c in data.get("cars", []):
		if Cars.CARS.has(c.get("id", "")):
			var car := _new_car(c["id"])
			for k in ["engine", "armor", "horn", "damage"]:
				car[k] = int(c.get(k, 0))
			cars.append(car)
	active_car = clampi(int(data.get("active_car", 0)), -1, cars.size() - 1)
	if active_car < 0 and not cars.is_empty():
		active_car = 0
	nam = {}
	for k in data.get("nam", {}):
		nam[k] = int(data["nam"][k])
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	traffic_wins = int(data.get("traffic_wins", wins))
	distance_m = float(data.get("distance_m", 0.0))
	intro_seen = bool(data.get("intro_seen", true))
	simit_buff = bool(data.get("simit_buff", false))
	blast_best = int(data.get("blast_best", 0))

	if int(data.get("version", 1)) < 2:
		# Eski kayıt: parayla alınan skiller statlara çevrilir, gün baştan başlar.
		var old: Dictionary = data.get("skills", {})
		stats = {
			"str": Places.STAT_START + 7.0 * int(old.get("power", 0)),
			"agi": Places.STAT_START + 7.0 * int(old.get("reflex", 0)),
			"sta": Places.STAT_START + 7.0 * int(old.get("stamina", 0)),
		}
		technique = int(old.get("special", 0)) > 0
		add_message("Oyun", "Kaydın yeni günlük hayat sistemine taşındı. Skillerin statlara çevrildi.")
		return true

	day = int(data.get("day", 1))
	minute = float(data.get("minute", Places.START_MINUTE))
	energy = float(data.get("energy", 100.0))
	food = float(data.get("food", 70.0))
	for k in stats:
		stats[k] = float(data.get("stats", {}).get(k, Places.STAT_START))
	trained_today = {}
	var tt = data.get("trained_today", {})
	if tt is Array:
		for k in tt:
			trained_today[k] = 1
	else:
		for k in tt:
			trained_today[k] = int(tt[k])
	difficulty = data.get("difficulty", "normal") if Places.DIFFICULTIES.has(data.get("difficulty", "")) else "normal"
	place = data.get("place", "ev")
	map_id = data.get("map_id", "mahalle") if Places.MAPS.has(data.get("map_id", "")) else "mahalle"
	if not Places.MAPS[map_id]["spots"].has(place):
		place = Places.MAPS[map_id]["start"]
	done_today = {}
	for k in data.get("done_today", {}):
		done_today[k] = int(data["done_today"][k])
	fridge = int(data.get("fridge", 0))
	protein_days = int(data.get("protein_days", 0))
	gym_until = int(data.get("gym_until", 0))
	gym_day_pass = int(data.get("gym_day_pass", 0))
	week_attended = int(data.get("week_attended", 0))
	last_lecture_day = int(data.get("last_lecture_day", 0))
	good_weeks = int(data.get("good_weeks", 0))
	technique = bool(data.get("technique", false))
	messages = data.get("messages", [])
	metro_station = clampi(int(data.get("metro_station", 0)), 0, MetroEvents.STATIONS.size() - 1)
	metro_dir = 1 if int(data.get("metro_dir", 1)) >= 0 else -1
	metro_on_board = bool(data.get("metro_on_board", false))
	metro_seated = bool(data.get("metro_seated", false))
	drive_dest = data.get("drive_dest", "") if Places.MAPS.has(data.get("drive_dest", "")) else ""
	drive_left = float(data.get("drive_left", 0.0))
	unread = int(data.get("unread", 0))
	outfits_owned = data.get("outfits_owned", ["esofman"]).filter(func(o): return Shop.OUTFITS.has(o))
	if not outfits_owned.has("esofman"):
		outfits_owned.push_front("esofman")
	outfit = data.get("outfit", "esofman") if outfits_owned.has(data.get("outfit", "")) else "esofman"
	hair = data.get("hair", "sidepart") if Shop.HAIRCUTS.has(data.get("hair", "")) else "sidepart"
	weapons_owned = data.get("weapons_owned", []).filter(func(w): return Shop.WEAPONS.has(w))
	weapon = data.get("weapon", "") if weapons_owned.has(data.get("weapon", "")) else ""
	skills_owned = data.get("skills_owned", []).filter(func(k): return Skills.SKILLS.has(k))
	skill_points = int(data.get("skill_points", 0))
	level = maxi(1, int(data.get("level", 1)))
	xp = int(data.get("xp", 0))
	metro_seat = int(data.get("metro_seat", -1))
	return true


func _new_car(id: String) -> Dictionary:
	return {"id": id, "engine": 0, "armor": 0, "horn": 0, "damage": 0}


# ---------------------------------------------------------------- Tam ekran (ayar dosyasında saklanır)

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()


## Ayarlar (tam ekran, müzik ve efekt sesi, ekran sarsıntısı) ayrı dosyada saklanır.
func save_settings() -> void:
	if _no_save:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "screen_shake", screen_shake)
	if _audio():
		cfg.set_value("audio", "music", _audio().music_volume)
		cfg.set_value("audio", "sfx", _audio().sfx_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", true)
		screen_shake = cfg.get_value("display", "screen_shake", true)
		if _audio():
			_audio().music_volume = cfg.get_value("audio", "music", 0.6)
			_audio().sfx_volume = cfg.get_value("audio", "sfx", 0.8)
	set_fullscreen(fullscreen)


# ---------------------------------------------------------------- Zaman ve ihtiyaçlar

func weekday() -> int:
	return (day - 1) % 7


func is_weekday() -> bool:
	return weekday() < 5


func clock_text() -> String:
	var m := int(minute)
	return "%02d:%02d" % [m / 60, m % 60]


func day_text() -> String:
	return "%d. gün, %s" % [day, Places.DAY_NAMES[weekday()]]


func diff() -> Dictionary:
	return Places.DIFFICULTIES[difficulty]


## Zamanı ilerletir. Tokluk azalır, gece yarısını geçince yeni gün başlar (kas kaybı,
## haftalık devam kontrolü). Gece çok geç saatte ayaktaysan bayılırsın.
func spend_time(mins: float, sleeping: bool = false) -> void:
	var left := mins
	while left > 0.001:
		var step := minf(left, 30.0)
		var hours := step / 60.0
		food = maxf(0.0, food - hours * (Places.FOOD_PER_HOUR_SLEEP if sleeping else Places.FOOD_PER_HOUR))
		if food <= 0.0 and not sleeping:
			energy = maxf(0.0, energy - hours * Places.STARVE_ENERGY_PER_HOUR * (1.5 if difficulty == "zor" else 1.0))
		minute += step
		left -= step
		if minute >= 1440.0:
			minute -= 1440.0
			_new_day()
	if not sleeping and minute >= Places.FAINT_FROM and minute < Places.START_MINUTE:
		_faint()


func _new_day() -> void:
	day += 1
	var d := diff()
	if d["decay"] > 0.0:
		for k in stats:
			if trained_today.has(k):
				continue
			var loss: float = d["decay"] * (d["hunger_mult"] if food < 10.0 else 1.0)
			var floor_value := minf(d["floor"], stats[k])   # kayıp statı tabanın altına indirmez
			stats[k] = maxf(floor_value, stats[k] - loss)
	trained_today = {}
	if protein_days > 0:
		protein_days -= 1
	if randf() < 0.85:
		_daily_messages()
	if weekday() == 0:
		_week_check()


## Pazartesi: geçen hafta yeterince derse gittiysen harçlık gelir.
func _week_check() -> void:
	if week_attended >= Places.ATTEND_NEEDED:
		money += Places.HARCLIK
		good_weeks += 1
		add_message("Annem", "Bu hafta derslere gitmişsin, aferin! %d TL harçlık yatırdım." % Places.HARCLIK)
	else:
		good_weeks = 0
		add_message("Annem", "Okuldan aradılar, devamsızlığın varmış (%d/%d gün)! Bu hafta harçlık yok." % [
				week_attended, Places.ATTEND_NEEDED])
	week_attended = 0


func _faint() -> void:
	pending_notice = "Gece çok geç oldu, ayakta duramadın ve bayıldın. Gözünü evde açtın, kafan zonkluyor."
	place = "ev"
	map_id = "mahalle"
	drive_dest = ""   # yoldaysan da yarım kalır
	metro_on_board = false
	metro_seated = false
	spend_time(Places.WAKE_AFTER_FAINT - minute, true)
	energy = 40.0
	save_game()
	go_to.call_deferred(SCENE_MAP)


func add_message(sender: String, text: String) -> void:
	messages.push_front([sender, text])
	if messages.size() > 20:
		messages.resize(20)
	unread += 1
	if is_inside_tree() and get_tree().current_scene != null and _audio():
		_audio().sfx("notify", 0.7, 0.0)


## Ses yöneticisi (autoload "Audio"); test betiklerinde yoktur.
func _audio() -> Node:
	return get_node_or_null("/root/Audio") if is_inside_tree() else null


## Her yeni gün annen, arkadaşların, okul ya da reklamlardan bir iki mesaj gelir.
func _daily_messages() -> void:
	var pool: Array = Messages.DAILY.duplicate()
	pool.shuffle()
	var count := 1 + (1 if randf() < 0.45 else 0)
	for m in pool.slice(0, count):
		add_message(m[0], m[1].replace("{money}", str(money)))


func has_gym_access() -> bool:
	return gym_until >= day or gym_day_pass == day


## Bugün bu kas kaçıncı kez çalışılıyor (0'dan başlar).
func train_count(stat_key: String) -> int:
	return trained_today.get(stat_key, 0)


## Antrenman kazancı: enerji ve tokluk verimi, protein, aynı gün tekrar yorgunluğu ve azalan getiri.
func train_gain(stat_key: String) -> float:
	var n := train_count(stat_key)
	if n >= Places.TRAIN_FATIGUE.size():
		return 0.0
	var eff: float = (0.5 + 0.5 * energy / 100.0) * Places.TRAIN_FATIGUE[n]
	eff *= 1.0 if food >= 25.0 else 0.6
	if protein_days > 0:
		eff *= Places.PROTEIN_BONUS
	return Places.TRAIN_BASE * eff * Places.TRAIN_SOFT / (Places.TRAIN_SOFT + stats[stat_key])


## Eylem şu an yapılabilir mi? Boş metin: evet. Değilse sebebi.
func action_block_reason(a: Dictionary) -> String:
	var needs: Dictionary = a.get("needs", {})
	if a.has("train") and train_count(a["train"]) >= Places.TRAIN_FATIGUE.size():
		return "Bu kas bugün yoruldu, yarın gel"
	# önce kalıcı koşullar, sonra saate ve o anki duruma bağlı olanlar
	if needs.has("min_str") and stats["str"] < needs["min_str"]:
		return "Güç %d gerekir" % needs["min_str"]
	if needs.has("good_weeks") and good_weeks < needs["good_weeks"]:
		return "%d hafta düzenli devam gerekir" % needs["good_weeks"]
	if money + a.get("money", 0) < 0:
		return "Paran yetmiyor"
	if needs.get("fridge", false) and fridge <= 0:
		return "Dolap boş"
	if needs.get("weekday", false) and not is_weekday():
		return "Hafta sonu ders yok"
	if needs.has("once_per_day") and done_today.get(needs["once_per_day"], 0) == day:
		return "Bugün zaten derse girdin" if needs["once_per_day"] == "lecture" else "Bugün yeterince yaptın"
	if needs.has("open") and not is_open(needs["open"]):
		return "Şu an kapalı (%02d:00-%02d:00)" % [needs["open"][0] / 60, needs["open"][1] / 60 % 24]
	if needs.get("gym", false) and not has_gym_access():
		return "Önce giriş ya da üyelik al"
	if needs.has("min_energy") and energy < needs["min_energy"]:
		return "Çok yorgunsun"
	return ""


## Açık mı? Kapanış 1440'tan büyükse gece yarısını geçer (ör. [420, 1500] = 07:00-01:00).
func is_open(hours: Array) -> bool:
	if hours[1] > 1440:
		return minute >= hours[0] or minute < hours[1] - 1440
	return minute >= hours[0] and minute < hours[1]


## Bu durumda listede hiç gösterilmeyecek eylemler (ör. zaten üyeysen üyelik).
func action_hidden(a: Dictionary) -> bool:
	var needs: Dictionary = a.get("needs", {})
	return (needs.get("no_gym", false) and has_gym_access()) \
			or (needs.get("no_month", false) and gym_until >= day) \
			or (needs.get("no_technique", false) and technique)


## Eylemi uygular, ekranda gösterilecek sonuç satırlarını döndürür.
func do_action(a: Dictionary) -> Array:
	var lines: Array = []
	var train: String = a.get("train", "")
	if train != "":
		var gain := train_gain(train)
		stats[train] = minf(Places.STAT_MAX, stats[train] + gain)
		trained_today[train] = train_count(train) + 1
		lines.append("+%.1f %s" % [gain, Places.STAT_NAMES[train]])
		lines.append(add_xp(Places.XP_TRAIN))
		if trained_today[train] >= 2 and trained_today[train] < Places.TRAIN_FATIGUE.size():
			lines.append("(kas yoruluyor)")
	for k in a.get("gain", {}):
		stats[k] = minf(Places.STAT_MAX, stats[k] + a["gain"][k])
		lines.append("+%.1f %s" % [a["gain"][k], Places.STAT_NAMES[k]])
	money += a.get("money", 0)
	energy = clampf(energy + a.get("energy", 0), 0.0, 100.0)
	food = clampf(food + a.get("food", 0), 0.0, 100.0)
	match a.get("effect", ""):
		"sleep":
			var until := Places.START_MINUTE + (1440.0 if minute >= Places.START_MINUTE else 0.0)
			var restore := 100.0 if food >= 20.0 else 75.0
			spend_time(until - minute, true)
			energy = restore
			lines.append("Günaydın! Enerji doldu." if restore >= 100.0 else "Aç yattın, tam dinlenemedin.")
		"nap":
			spend_time(a["time"], true)
		"fridge_add":
			fridge += 3
			lines.append("Evde %d öğün yemek var." % fridge)
		"fridge_eat":
			fridge -= 1
		"gym_day":
			gym_day_pass = day
			lines.append("Bugün salon senin.")
		"gym_month":
			gym_until = day + 29
			lines.append("Üyelik %d. güne kadar geçerli." % gym_until)
		"protein":
			protein_days = Places.PROTEIN_DAYS
			lines.append("%d gün antrenman bonusu!" % Places.PROTEIN_DAYS)
		"technique":
			technique = true
			lines.append("Direksiyon Kilidi öğrenildi! Dövüşte U tuşu.")
		"lecture":
			week_attended += 1
			last_lecture_day = day
			lines.append("Devam: bu hafta %d/%d gün" % [week_attended, Places.ATTEND_NEEDED])
			lines.append(add_xp(Places.XP_LECTURE))
	if a.get("needs", {}).has("once_per_day"):
		done_today[a["needs"]["once_per_day"]] = day
	if a.get("money", 0) > 0:
		lines.append("+%d TL" % a["money"])
	if not a.get("effect", "") in ["sleep", "nap"] and a.get("time", 0) > 0:
		spend_time(a["time"])
	save_game()
	return lines


## Haritada başka bir yere yürü (mahallede 15, kampüste 8 dakika).
func walk_to(target: String) -> void:
	if target != place:
		spend_time(Places.MAPS[map_id]["walk"])
	place = target
	save_game()


## Bir haritaya geç (metrobüsle varınca): giriş noktasından başlarsın.
func enter_map(id: String, spot: String = "") -> void:
	map_id = id
	place = spot if spot != "" else Places.MAPS[id]["start"]
	save_game()
	go_to(SCENE_MAP)


# ---------------------------------------------------------------- Araba ve oyuncu değerleri

func has_car() -> bool:
	return active_car >= 0 and active_car < cars.size()


func car() -> Dictionary:
	return cars[active_car]


func car_info(id: String = "") -> Dictionary:
	return Cars.CARS[id if id != "" else car()["id"]]


func car_max_hp(c: Dictionary = {}) -> int:
	if c.is_empty():
		c = car()
	return Cars.CARS[c["id"]]["hp"] + c["armor"]


func car_speed() -> float:
	return car_info()["speed"] * (1.0 + 0.1 * car()["engine"])


func cheapest_car() -> Dictionary:
	var best := {}
	for id in Cars.CARS:
		var info: Dictionary = Cars.CARS[id]
		if info["shop"] and (best.is_empty() or info["price"] < best["price"]):
			best = info
	return best


## Dayanıklılık can verir; yorgunsan kavgaya daha az canla başlarsın (en az %70).
func player_max_hp() -> float:
	var bonus := (10.0 if has_skill("kalin_deri") else 0.0) + (25.0 if has_skill("demir_adam") else 0.0)
	return (70.0 + 3.0 * stats["sta"]) * lerpf(0.7, 1.0, energy / 100.0) + bonus


## Güç hasarı artırır.
func player_power() -> float:
	return 0.8 + 0.02 * stats["str"]


## Çeviklik: hareket hızı, kaçma bekleme süresi, blokta alınan hasar oranı.
func player_agility() -> Dictionary:
	var a: float = stats["agi"]
	return {"speed": 68.0 + 0.6 * a, "dodge_cd": maxf(0.3, 0.8 - 0.008 * a), "block_chip": maxf(0.05, 0.25 - 0.003 * a)}


func upgrade_cost(base: int, level: int) -> int:
	return base * (level + 1)


func repair_cost() -> int:
	return car()["damage"] * REPAIR_COST


func sell_price(id: String) -> int:
	return int(Cars.CARS[id]["price"] / 2)


func try_spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	save_game()
	return true


## Devam ederken nereye gidilir: metrobüsteysen yolculuk, değilse harita.
func home_scene() -> String:
	if drive_dest != "" and has_car():
		return SCENE_TRAFFIC
	return SCENE_METRO if metro_on_board else SCENE_MAP


## Arabayla yolculuk neden olamaz? ("" ise olur)
func drive_block_reason() -> String:
	if not has_car():
		return "Araban yok. Necdet Oto Galeri'den alabilirsin."
	if car()["damage"] >= car_max_hp():
		return "Araban hurda durumda. Galeride tamir ettir."
	if money < Places.FUEL_COST:
		return "Benzin parası yok (%d TL lazım)." % Places.FUEL_COST
	return ""


## Otoparktan yola çık: benzin alınır, trafik sahnesinde hedefe kadar sürülür.
func start_drive(dest: String) -> void:
	money -= Places.FUEL_COST
	drive_dest = dest
	drive_left = Places.DRIVE_METERS
	save_game()
	go_to(SCENE_TRAFFIC)


## Yol aldıkça saat ilerler.
func drive_progress(meters: float) -> void:
	drive_left = maxf(0.0, drive_left - meters)
	spend_time(meters / Places.DRIVE_METERS * Places.DRIVE_MINUTES)


## Hedefe vardın: oranın otoparkında inersin.
func finish_drive() -> void:
	var dest := drive_dest
	drive_dest = ""
	drive_left = 0.0
	enter_map(dest, "otopark")


## Araba yolda gitti (iddia, hurda): kalan yolu yürüyerek ya da dolmuşla tamamlarsın.
func walk_rest_of_drive() -> void:
	spend_time(drive_left / Places.DRIVE_METERS * 70.0 + 10.0)
	finish_drive()


## Metrobüse bindiysek yolculuğa, binmediysek durağa.
func metro_scene() -> String:
	return SCENE_METRO if metro_on_board else SCENE_STATION


## Mekan ekranını aç.
func open_place_scene(id: String) -> void:
	open_place = id
	place = id
	go_to(SCENE_PLACE)


# ---------------------------------------------------------------- Rakipler ve nam

func rival(id: String = "") -> Dictionary:
	return Rivals.RIVALS[id if id != "" else fight_rival]


func fear_level(id: String) -> int:
	return mini(nam.get(id, 0), MAX_FEAR)


## Nam etkisi uygulanmış dövüş değerleri.
func rival_stats(id: String) -> Dictionary:
	var r := rival(id).duplicate()
	var f := fear_level(id)
	r["hp"] = r["hp"] * (1.0 - FEAR_HP * f)
	r["power"] = r["power"] * (1.0 - FEAR_POWER * f)
	r["aggro"] = r["aggro"] * (1.0 - FEAR_AGGRO * f)
	r["block"] = r["block"] * (1.0 - FEAR_BLOCK * f)
	return r


## Rakip namını duyup geri adım atıyor mu? (O zaman gözdağı seçeneği de açıktır.)
func is_scared(id: String) -> bool:
	return can_intimidate(id)


## Karşılaşmada rakibin söyleyeceği söz: korkuyorsa geri adım atar.
func rival_line(id: String, key: String) -> String:
	var lines: Dictionary = rival(id)["lines"]
	if is_scared(id) and lines.has("scared"):
		return lines["scared"].pick_random()
	if not lines.has(key):
		key = "laf" if lines.has("laf") else "korna"   # trafik rakipleri metrobüste de konuşabilsin
	return lines[key].pick_random()


func can_intimidate(id: String) -> bool:
	return fear_level(id) >= INTIMIDATE_FEAR


## Kavgayı kazanınca alınan para: rivals.gd ödülü x FIGHT_REWARD_MULT, galibiyet arttıkça yavaşça artar
## (her galibiyet +%4, en fazla 25 galibiyette 2 katı).
func fight_reward(id: String = "") -> int:
	return int(rival(id)["reward"] * Places.FIGHT_REWARD_MULT * (1.0 + 0.04 * mini(wins, 25)))


func intimidate_reward(id: String) -> int:
	return int(fight_reward(id) / 3) * (2 if has_skill("karizma") else 1)


func intimidate(id: String) -> void:
	money += intimidate_reward(id)
	save_game()


## Trafik: galibiyete göre açılan rakiplerden ağırlıklı rastgele seçim.
func pick_traffic_rival() -> String:
	var pool: Array = []
	for id in Rivals.RIVALS:
		var r: Dictionary = Rivals.RIVALS[id]
		if r["venue"] == "traffic" and traffic_wins >= Rivals.TIER_WINS[r["tier"]]:
			for i in r["weight"]:
				pool.append(id)
	return pool.pick_random()


## Metrobüs: ağırlıklı rastgele olay (oturuyor/ayakta durumuna uygun olanlardan).
func pick_metro_event() -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for e in MetroEvents.EVENTS:
		var need: String = e.get("need", "")
		if (need == "seated" and not metro_seated) or (need == "standing" and metro_seated):
			continue
		pool.append(e)
		total += e["weight"]
	var roll := randf() * total
	for e in pool:
		roll -= e["weight"]
		if roll <= 0.0:
			return e
	return pool.back()


## Dövüş sonucunu uygular, ekranda gösterilecek özeti döndürür.
func apply_fight_result(won: bool) -> Dictionary:
	var r := rival()
	var result := {"won": won, "money": 0, "car_won": "", "car_lost": "", "no_car": false,
			"venue": fight_venue, "fear_up": false}
	if won:
		wins += 1
		if fight_venue == "traffic":
			traffic_wins += 1
		var reward := fight_reward()
		money += reward
		result["money"] = reward
		if weapon == "bicak" and randf() < Shop.KNIFE_POLICE_CHANCE:
			var fine := mini(money, Shop.KNIFE_POLICE_FINE)
			money -= fine
			result["police"] = "Polis çevirdi, bıçağı gördü: -%d TL ceza!" % fine
		var before := fear_level(fight_rival)
		nam[fight_rival] = nam.get(fight_rival, 0) + 1
		result["fear_up"] = fear_level(fight_rival) > before
		if fight_bet:
			cars.append(_new_car(r["car"]))
			result["car_won"] = r["car"]
		if fight_seat_stake == "gain" and not metro_seated:
			metro_seated = true
			result["seat"] = "Koltuk artık senin. Otur, keyfine bak."
	else:
		if fight_seat_stake == "keep" and metro_seated:
			metro_seated = false
			result["seat"] = "Yerini kaptırdın, ayakta gidiyorsun."
		losses += 1
		var penalty := mini(money, int(fight_reward() / 2))
		money -= penalty
		result["money"] = -penalty
		if fight_bet and has_car():
			result["car_lost"] = car()["id"]
			cars.remove_at(active_car)
			active_car = 0 if not cars.is_empty() else -1
			result["no_car"] = cars.is_empty()
	var gain_xp: int = Places.XP_FIGHT_LOSS
	if won:
		gain_xp = Places.XP_FIGHT_WIN + 10 * int(r.get("tier", 0)) + maxi(0, int((r["hp"] - 60) / 10))
	result["xp"] = add_xp(gain_xp)
	if station_fight:
		station_return = "front" if won else "back"
		result["station"] = "Kalabalık yol verdi, en öndesin!" if won else "Seni sıranın en sonuna ittiler..."
	# kavga yorar ve zaman alır
	var tired: int = Places.FIGHT_ENERGY - (5 if has_skill("nefes") else 0)
	energy = maxf(0.0, energy - tired)
	result["tired"] = "-%d enerji, +%d dakika" % [tired, Places.FIGHT_MINUTES]
	fight_rival = ""
	fight_bet = false
	fight_seat_stake = ""
	station_fight = false
	spend_time(Places.FIGHT_MINUTES)
	save_game()
	return result


# ---------------------------------------------------------------- Sahne geçişi

func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.2)
	await tw.finished
	get_tree().change_scene_to_file(path)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.25)
	await tw.finished
	_busy = false


func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


# ---------------------------------------------------------------- Tuşlar ve görünüm

func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"horn": [KEY_H], "garage": [KEY_G],
		"punch": [KEY_J], "kick": [KEY_K], "block": [KEY_L], "dodge": [KEY_SPACE], "special": [KEY_U],
		"back": [KEY_ESCAPE], "fullscreen": [KEY_F11], "interact": [KEY_E], "phone": [KEY_T], "skills": [KEY_Y],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var alt_enter := InputEventKey.new()
	alt_enter.physical_keycode = KEY_ENTER
	alt_enter.alt_pressed = true
	InputMap.action_add_event("fullscreen", alt_enter)


func _setup_theme() -> void:
	# Yazılar ekranın gerçek çözünürlüğünde çizilir (stretch mode: canvas_items), pürüzsüz ve okunaklı olsun.
	var font := FontVariation.new()
	font.base_font = load(FONT_PATH)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	title_font = load(TITLE_FONT_PATH)
	# Tema CanvasLayer'lardan alt düğümlere geçmediği için doğrudan varsayılan temayı düzenliyoruz.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 10
	ui_theme = ThemeDB.get_default_theme()
	ui_theme.default_font = font
	ui_theme.default_font_size = 10

	var navy := Color("1b2a52")
	var gold := Color("e6b428")
	# pixel çerçeveli paneller ve butonlar (tools/make_backgrounds.py -> assets/backgrounds/ui_*.png)
	ui_theme.set_stylebox("normal", "Button", _pixel_box("ui_button", 5))
	ui_theme.set_stylebox("hover", "Button", _pixel_box("ui_button_hover", 5))
	ui_theme.set_stylebox("pressed", "Button", _pixel_box("ui_button_pressed", 5))
	ui_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), gold))
	ui_theme.set_stylebox("disabled", "Button", _pixel_box("ui_button_disabled", 5))
	ui_theme.set_color("font_color", "Button", Color.WHITE)
	ui_theme.set_color("font_hover_color", "Button", gold.lightened(0.3))
	ui_theme.set_color("font_pressed_color", "Button", Color("1b1b24"))
	ui_theme.set_color("font_disabled_color", "Button", Color("77778a"))
	ui_theme.set_stylebox("panel", "Panel", _pixel_box("ui_panel", 4))
	ui_theme.set_stylebox("panel", "PanelContainer", _pixel_box("ui_panel", 7))
	ui_theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	ui_theme.set_constant("shadow_offset_x", "Label", 1)
	ui_theme.set_constant("shadow_offset_y", "Label", 1)
	for type in ["Label", "Button", "RichTextLabel"]:
		ui_theme.set_font_size("font_size", type, 10)
		ui_theme.set_font("font", type, font)
	ui_theme.set_font("normal_font", "RichTextLabel", font)
	ui_theme.set_font_size("normal_font_size", "RichTextLabel", 10)


## 12x12'lik pixel çerçeve görselinden 9 parçalı stil: köşeler sabit, ortası esner.
func _pixel_box(file: String, margin: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/backgrounds/%s.png" % file)
	s.set_texture_margin_all(4)
	s.set_content_margin_all(margin)
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 1
	return s


func _box(bg: Color, border: Color, margin: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 1
	return s


## Ortak yardımcı: verilen renk ve boyutta Label oluşturur.
func make_label(text: String, size: int = 10, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if size >= TITLE_SIZE:
		l.add_theme_font_override("font", title_font)
	l.add_theme_color_override("font_color", color)
	return l


## Oyuncunun görünüşü (üzerindeki kıyafete göre karakter sayfası).
func player_look() -> String:
	var base := "player" if outfit == "esofman" else "player_" + outfit
	return base if hair == "sidepart" else base + "__" + hair


## Berberde tıraş: para, zaman ve yeni saç. Olmazsa neden ("" ise oldu).
func get_haircut(id: String) -> String:
	if not is_open(Shop.BARBER_HOURS):
		return "Kapalı (09:00-21:00)"
	if id == hair:
		return "Zaten bu saçın var"
	if not try_spend(Shop.HAIRCUTS[id]["price"]):
		return "Paran yetmiyor"
	hair = id
	spend_time(Shop.HAIRCUT_MINUTES)
	save_game()
	return ""


## Mağaza fiyatı (Pazarlıkçı yeteneğiyle %15 indirimli).
func shop_price(base: int) -> int:
	return int(round(base * (0.85 if has_skill("pazarlikci") else 1.0)))


func buy_outfit(id: String) -> bool:
	if outfits_owned.has(id) or not try_spend(shop_price(Shop.OUTFITS[id]["price"])):
		return false
	outfits_owned.append(id)
	save_game()
	return true


func buy_weapon(id: String) -> bool:
	if weapons_owned.has(id) or not try_spend(shop_price(Shop.WEAPONS[id]["price"])):
		return false
	weapons_owned.append(id)
	if weapon == "":
		weapon = id
	save_game()
	return true


# ---------------------------------------------------------------- Yetenekler ve başarımlar

func has_skill(id: String) -> bool:
	return skills_owned.has(id)


## Yetenek neden açılamaz? ("" ise açılabilir)
func skill_block_reason(id: String) -> String:
	var sk: Dictionary = Skills.SKILLS[id]
	if has_skill(id):
		return "Açık"
	if sk.has("needs") and not has_skill(sk["needs"]):
		return "Önce: " + Skills.SKILLS[sk["needs"]]["name"]
	if sk.has("stat") and stats[sk["stat"][0]] < sk["stat"][1]:
		return "%s %d gerekir" % [Places.STAT_NAMES[sk["stat"][0]], sk["stat"][1]]
	if skill_points < sk["cost"]:
		return "%d puan gerekir" % sk["cost"]
	return ""


func buy_skill(id: String) -> bool:
	if skill_block_reason(id) != "":
		return false
	skill_points -= Skills.SKILLS[id]["cost"]
	skills_owned.append(id)
	save_game()
	return true


## Bir sonraki seviye için gereken XP.
func xp_needed() -> int:
	return Places.XP_BASE + Places.XP_STEP * (level - 1)


## XP ekler; dolarsa seviye atlar (her seviye 1 yetenek puanı). Ekranda gösterilecek satırı döndürür.
func add_xp(amount: int) -> String:
	xp += amount
	var line := "+%d XP" % amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		line += "  SEVİYE %d!" % level
		add_message("Seviye", "Seviye %d oldun! +1 yetenek puanı. Telefon > Yetenek (ya da Y) ile harca." % level)
		toast("SEVİYE %d!   +1 yetenek puanı" % level)
	return line


var _toast_layer: CanvasLayer


## Ekranın üstünde kısa süre görünen altın renkli bildirim.
func toast(text: String) -> void:
	if not is_inside_tree():
		return
	if _toast_layer == null:
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 90
		add_child(_toast_layer)
	var l := make_label(text, 10, Color("1b1024"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e6b428")
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_layer.add_child(l)
	l.reset_size()
	l.position = Vector2(roundf(240 - l.size.x / 2.0), -20 - 22 * (_toast_layer.get_child_count() - 1))
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 48, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
	var au := _audio()
	if au:
		au.sfx("buy", 0.8, 0.0)


func weapon_info() -> Dictionary:
	return Shop.WEAPONS.get(weapon, {})


func fighter_texture(look: String, pose: String) -> Texture2D:
	return load("res://assets/sprites/fighter_%s_%s.png" % [look, pose])


## Oyuna özel fare imleçleri (tools/make_cursors.py): ok ve tıklanabilir şeylerin üstünde el.
func _setup_cursors() -> void:
	Input.set_custom_mouse_cursor(load("res://assets/sprites/cursor_arrow.png"), Input.CURSOR_ARROW, Vector2(0, 0))
	Input.set_custom_mouse_cursor(load("res://assets/sprites/cursor_hand.png"), Input.CURSOR_POINTING_HAND, Vector2(5, 1))


## Sahnede tıklanabilir bir şeyin üstündeyken el imleci (Control olmayan sahneler için: mekan, metrobüs...).
func set_hand_cursor(on: bool) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)


## Konuşma portresi (tools/make_portraits.py, 48x48 büst). Yoksa dövüş sprite'ı. mood: "" ya da "hurt" (sadece oyuncu).
func portrait_texture(look: String, mood: String = "") -> Texture2D:
	var path := "res://assets/portraits/portrait_%s%s.png" % [look, "_" + mood if mood != "" else ""]
	if ResourceLoader.exists(path):
		return load(path)
	return fighter_texture(look, "hurt" if mood == "hurt" else "idle")


## 3/4 üstten bakış karakter sayfası (tools/make_topdown.py): 4 yön x pozlar.
func td_texture(look: String) -> Texture2D:
	return load("res://assets/topdown/td_%s.png" % look)


## 3/4 bakışta yandan araba (tools/make_rooms.py), sağa bakar.
func car_3q_texture(id: String) -> Texture2D:
	return load("res://assets/rooms/props/car_%s.png" % id)


func car_texture(id: String, side: bool = false) -> Texture2D:
	return load("res://assets/sprites/car_%s%s.png" % ["side_" if side else "", id])


# ---------------------------------------------------------------- Geliştirici kısayolları
# Komut satırı: godot --path . res://scenes/fight/fight.tscn -- --rival=selim --bet --shot=out.png
# --shot verilirse birkaç saniye sonra ekran görüntüsü alınıp oyun kapanır.
# Bu komutlarla açılınca kayıt ve ayar dosyalarına yazılmaz, oyun pencerede açılır.
# Günlük hayat: --diff=zor --day=3 --time=14:30 --stats=20,10,15 --energy=50 --food=30 --place=gym

func _debug_args() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.is_empty():
		return
	_no_save = true
	set_fullscreen(false)
	if args.has("fresh"):
		new_game(args.get("diff", "normal"))
		intro_seen = not args.has("intro")
	autoplay = args.has("autoplay")
	if args.has("money"):
		money = int(args["money"])
	if args.has("day"):
		day = int(args["day"])
	if args.has("time"):
		var hm: PackedStringArray = args["time"].split(":")
		minute = int(hm[0]) * 60 + (int(hm[1]) if hm.size() > 1 else 0)
	if args.has("stats"):
		var v: PackedStringArray = args["stats"].split(",")
		stats = {"str": float(v[0]), "agi": float(v[1]), "sta": float(v[2])}
	if args.has("energy"):
		energy = float(args["energy"])
	if args.has("food"):
		food = float(args["food"])
	if args.has("place"):
		open_place = args["place"]
		place = args["place"]
	if args.has("activity"):   # --activity=lecture (kampüs) ya da --activity=carsi:waiter
		var pa: PackedStringArray = args["activity"].split(":")
		if pa.size() == 1:
			activity = Places.CAMPUS_ACTIONS[pa[0]].duplicate()
			activity["course"] = args.get("course", "Diferansiyel Denklemler")
		else:
			for a in Places.PLACES[pa[0]]["actions"]:
				if a["id"] == pa[1]:
					activity = a
	if args.has("map"):
		map_id = args["map"]
		place = Places.MAPS[map_id]["start"]
	if args.has("car"):
		cars.append(_new_car(args["car"]))
		active_car = cars.size() - 1
	if args.has("nam"):
		for id in Rivals.RIVALS:
			nam[id] = int(args["nam"])
	if args.has("board"):
		board_bus_type = args["board"]
		board_ahead = int(args.get("ahead", "4"))
	if args.has("station"):
		metro_station = int(args["station"])
		metro_dir = int(args.get("dir", "1"))
	if args.has("seated"):
		metro_on_board = true
		metro_seated = true
	if args.has("level"):   # --level=4
		level = int(args["level"])
	if args.has("sp"):   # --sp=5  yetenek puanı
		skill_points = int(args["sp"])
	if args.has("weapon"):   # --weapon=sopa  (alıp çantaya koyar)
		weapons_owned.append(args["weapon"])
		weapon = args["weapon"]
	if args.has("outfit"):   # --outfit=deri
		outfits_owned.append(args["outfit"])
		outfit = args["outfit"]
	if args.has("drive"):   # --drive=kampus [--drive_left=200]: arabayla yolculuğun ortası
		drive_dest = args["drive"]
		drive_left = float(args.get("drive_left", str(Places.DRIVE_METERS)))
	if args.has("rival"):
		fight_rival = args["rival"]
		fight_bet = args.has("bet")
		fight_venue = args.get("venue", "traffic")
	if args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(args["scene"])
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("wait", "2.5"))).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		get_tree().quit()
