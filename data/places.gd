## Günlük hayat: mekanlar, eylemler, zorluklar ve denge sayıları. Ayar yapmak için tek dosya.
##
## Eylem alanları:
##   time:   kaç dakika sürer        energy / food: enerji ve tokluk değişimi (eksi = azalır)
##   money:  para değişimi            train: hangi stat çalışılır ("str", "agi", "sta")
##   gain:   ek stat kazancı ({"str": 0.4})
##   scene:  eylem ayrı bir sahnede oynanır (waiter: garsonluk, lecture: amfi, cafeteria: yemekhane)
##   effect: özel etki (sleep, nap, fridge_add, fridge_eat, gym_day, gym_month, protein, technique,
##           lecture, metro_school, metro_home, garage)
##   needs:  koşullar: min_energy, gym (giriş/üyelik), fridge, open ([açılış, kapanış] dakika),
##           weekday (hafta içi), once_per_day (aynı gün bir kez), min_str, good_weeks, no_technique

const START_MINUTE := 7 * 60
const WALK_MINUTES := 15           # mahalle içinde bir yerden bir yere yürüme
const FAINT_FROM := 2 * 60         # gece bu saatten sonra ayakta kalırsan bayılırsın
const WAKE_AFTER_FAINT := 10 * 60
const FOOD_PER_HOUR := 5.0         # uyanıkken saatte tokluk kaybı
const FOOD_PER_HOUR_SLEEP := 2.0
const STARVE_ENERGY_PER_HOUR := 6.0  # tokluk sıfırken saatte enerji kaybı
const METRO_MINUTES_PER_STOP := 4.0
const STANDING_ENERGY_PER_STOP := 0.6   # metrobüste ayakta gitmek yorar (16 durakta ~10)
const SEATED_ENERGY_PER_STOP := 0.25    # oturarak gidersen biraz dinlenirsin
const STATION_MINUTES_PER_SECOND := 1.0  # durakta beklerken oyun saati hızı
const FIGHT_MINUTES := 20
# Arabayla okula/eve: metrobüsten (bekleme + 16 durak ~1,5 sa) hızlı ama benzin parası var.
const DRIVE_METERS := 1600.0       # trafik sahnesinde gidilecek yol
const DRIVE_MINUTES := 35.0        # bu yolun oyun içi süresi
const FUEL_COST := 30              # her yolculukta benzin
const FIGHT_ENERGY := 15
const FIGHT_REWARD_MULT := 0.6     # kavgadan kazanılan para (rivals.gd reward x bu)

# Seviye: XP dolunca seviye atlanır, her seviye 1 yetenek puanı verir.
# Tipik bir gün (2-3 antrenman + ders + bazen kavga) ~70-90 XP: ilk seviyeler günde bir, sonra yavaşlar.
const XP_FIGHT_WIN := 30           # + rakibin zorluğuna göre (trafik tier x 10, canı yüksekse fazlası)
const XP_FIGHT_LOSS := 8
const XP_TRAIN := 12
const XP_LECTURE := 25
const XP_BASE := 80                # 1'den 2'ye; her seviye 40 fazlası
const XP_STEP := 40

# Antrenman: kazanç = TRAIN_BASE * enerji verimi * tokluk verimi * protein * TRAIN_SOFT / (TRAIN_SOFT + stat)
const TRAIN_BASE := 3.6          # antrenman başına temel kazanç
const TRAIN_SOFT := 25.0
const PROTEIN_BONUS := 1.25
## Aynı gün aynı kası tekrar çalıştırınca verim düşer (Punch Club gibi). Listeyi aşınca o gün çalışılamaz.
const TRAIN_FATIGUE := [1.0, 0.7, 0.45, 0.25]
const PROTEIN_DAYS := 7
const STAT_START := 5.0
const STAT_MAX := 100.0

# Okul: haftada bu kadar gün derse girersen pazartesi harçlık gelir.
const ATTEND_NEEDED := 3
const HARCLIK := 150
const LECTURE_HOURS := [9 * 60, 17 * 60]

const DAY_NAMES := ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
const DAY_SHORT := ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

## Zorluk: antrenman yapmadığın her stat gün sonunda ne kadar düşer.
const DIFFICULTIES := {
	"kolay": {"name": "Rahat", "decay": 0.0, "floor": STAT_START, "hunger_mult": 1.0,
		"desc": "Kazandığın güç hiç azalmaz. Aç kalmanın cezası hafif. Hikâyenin ve kavgaların tadını çıkar."},
	"normal": {"name": "Gerçekçi", "decay": 1.0, "floor": 10.0, "hunger_mult": 2.0,
		"desc": "O gün çalışmadığın her stat gece 1 puan düşer (10'un altına inmez). Aç yatarsan kayıp iki katı. Düzenli gym şart."},
	"zor": {"name": "Punch Club", "decay": 3.0, "floor": STAT_START, "hunger_mult": 2.0,
		"desc": "Çalışmadığın her stat gece 3 puan düşer. Aç kalırsan iki katı ve enerjin de erir. Her saat hesaplı olmalı."},
	"god": {"name": "God Mode (test)", "decay": 0.0, "floor": STAT_START, "hunger_mult": 1.0,   # test bitince kaldırılacak
		"desc": "Sınırsız para, statlar düşmez. Sadece oyunu test etmek için."},
}

const STAT_NAMES := {"str": "Güç", "agi": "Çeviklik", "sta": "Dayanıklılık"}

## Haritadaki yerler. Mekanın kendisi (zemin, eşyalar, işaretler) tools/make_rooms.py ile çizilir; aynı id.
##   spots: mekanda etkileşilecek şeyler. at: oyuncunun duracağı işaret (rooms_data.gd marks). kind:
##       exit     çıkış kapısı (haritaya döner; "actions" varsa onları sunar)
##       npc      konuşulacak kişi (look: görünüş, stand: durduğu işaret, face: baktığı yön, sit: oturuyor mu,
##                lines: söyledikleri, actions: sunduğu eylemler)
##       object   eşya (dir: oyuncu ona bakarken hangi yöne döner, actions: eylemler)
##       machine  gym aleti (action: antrenman, anim: lift/run/bag, index: kaçıncı alet, user: başka sporcu)
##       car      galeride satılık araba (car: id, index: kaçıncı yer)
##   extras: sadece süs olan insanlar [görünüş, işaret, yön, oturuyor mu]
##   actions: eylemlerin tanımı (spotlar id ile çağırır)
const PLACES := {
	"ev": {
		"name": "Ev", "desc": "Küçük, rutubetli ama senin.",
		"pos": Vector2(64, 108), "color": Color("b8654a"),
		"spots": [
			{"kind": "exit", "name": "Kapı", "at": "exit"},
			{"kind": "object", "name": "Çalışma masası", "at": "desk", "dir": "up",
				"lines": ["Ödevler bekliyor... Sonra bakarız.", "Laptopun fanı uçak gibi ses çıkarıyor."]},
			{"kind": "object", "name": "Yatak", "at": "bed", "dir": "left", "actions": ["sleep", "nap"],
				"lines": ["Yay sesleri gıcırdıyor ama yatak yatak.", "Biraz uzansan mı?"]},
			{"kind": "object", "name": "Gardırop", "at": "wardrobe", "dir": "up", "wardrobe": true,
				"lines": ["Kıyafetlerin ve çantan burada.", "Bugün ne giysem?"]},
			{"kind": "object", "name": "Buzdolabı", "at": "fridge", "dir": "up", "actions": ["eat_home"],
				"lines": ["Bir yarım limon, bir de makarna.", "Buzdolabının ışığı bile yanmıyor."]},
		],
		"actions": [
			{"id": "sleep", "name": "Uyu", "desc": "Sabaha kadar", "effect": "sleep"},
			{"id": "nap", "name": "Kestir", "time": 120, "energy": 25, "effect": "nap"},
			{"id": "eat_home", "name": "Makarna ısıt, ye", "time": 30, "food": 45, "effect": "fridge_eat", "needs": {"fridge": true}},
		],
	},
	"market": {
		"name": "Market", "desc": "Köşedeki market. 07:00-01:00 açık.",
		"pos": Vector2(186, 114), "color": Color("3f8f5a"),
		"spots": [
			{"kind": "exit", "name": "Kapı", "at": "exit"},
			{"kind": "npc", "name": "Kasiyer Hüseyin Abi", "look": "sivil0", "stand": "cashier", "at": "talk_cashier",
				"actions": ["simit", "tost", "pasta", "energy_drink", "protein"],
				"lines": ["Hoş geldin evladım, ne lazım?", "Öğrenciye veresiye yok ama gülümseme bedava.", "Taze simit geldi, sıcak sıcak!"]},
		],
		"actions": [
			{"id": "simit", "name": "Simit", "time": 10, "food": 12, "money": -5, "needs": {"open": [420, 1500]}},
			{"id": "tost", "name": "Kaşarlı tost", "time": 20, "food": 30, "money": -30, "needs": {"open": [420, 1500]}},
			{"id": "pasta", "name": "Makarna paketi (eve 3 öğün)", "time": 10, "money": -35,
				"effect": "fridge_add", "needs": {"open": [420, 1500]}},
			{"id": "energy_drink", "name": "Enerji içeceği", "time": 5, "energy": 25, "food": -3, "money": -40,
				"needs": {"open": [420, 1500]}},
			{"id": "protein", "name": "Protein tozu (7 gün +%25 antrenman)",
				"time": 10, "money": -300, "effect": "protein", "needs": {"open": [420, 1500]}},
		],
	},
	"gym": {
		"name": "Rıza'nın Salonu", "desc": "Mahallenin spor salonu. 06:00-24:00 açık.",
		"pos": Vector2(372, 104), "color": Color("4a5fb0"),
		"spots": [
			{"kind": "exit", "name": "Kapı", "at": "exit"},
			{"kind": "npc", "name": "Hoca Rıza", "look": "riza", "stand": "riza", "at": "talk_riza",
				"actions": ["gym_day", "gym_month", "technique"],
				"lines": ["Ooo hoş geldin! Isındın mı?", "Ter dökmeden kas olmaz evlat.", "Üyelik al, her gün gel. Düzen her şeydir."]},
			{"kind": "machine", "name": "Halter sehpası", "action": "lift", "anim": "lift", "at": "lift_0", "index": 0},
			{"kind": "machine", "name": "Halter sehpası", "action": "lift", "anim": "lift", "at": "lift_1", "index": 1, "user": "hipster"},
			{"kind": "machine", "name": "Koşu bandı", "action": "run", "anim": "run", "at": "run_0", "index": 0},
			{"kind": "machine", "name": "Koşu bandı", "action": "run", "anim": "run", "at": "run_1", "index": 1, "user": "elif"},
			{"kind": "machine", "name": "Koşu bandı", "action": "run", "anim": "run", "at": "run_2", "index": 2},
			{"kind": "machine", "name": "Kum torbası", "action": "bag", "anim": "bag", "at": "bag_0", "index": 0, "user": "abi"},
			{"kind": "machine", "name": "Kum torbası", "action": "bag", "anim": "bag", "at": "bag_1", "index": 1},
			{"kind": "object", "name": "Su sebili", "at": "water", "dir": "up",
				"lines": ["Buz gibi su. Bedava, tek güzel şey."]},
		],
		"actions": [
			{"id": "gym_day", "name": "Günlük giriş", "money": -20,
				"effect": "gym_day", "needs": {"open": [360, 1440], "no_gym": true}},
			{"id": "gym_month", "name": "Aylık üyelik (30 gün)", "money": -250,
				"effect": "gym_month", "needs": {"open": [360, 1440], "no_month": true}},
			{"id": "lift", "name": "Ağırlık çalış", "time": 60, "energy": -12, "food": -6,
				"train": "str", "needs": {"open": [360, 1440], "gym": true, "min_energy": 12}},
			{"id": "bag", "name": "Kum torbası + ip", "time": 60, "energy": -12, "food": -6, "train": "agi",
				"needs": {"open": [360, 1440], "gym": true, "min_energy": 12}},
			{"id": "run", "name": "Koşu bandı", "time": 60, "energy": -12, "food": -7,
				"train": "sta", "needs": {"open": [360, 1440], "gym": true, "min_energy": 12}},
			{"id": "technique", "name": "Direksiyon Kilidi öğren (Güç 30)",
				"time": 120, "energy": -20, "money": -800, "effect": "technique",
				"needs": {"open": [360, 1440], "min_str": 30, "no_technique": true, "min_energy": 20}},
		],
	},
	"carsi": {
		"name": "Çarşı", "desc": "Kafe, kargo deposu, dershane, butik, Av & Savunma. İş ve alışveriş burada.",
		"pos": Vector2(212, 176), "color": Color("b8902a"),
		"spots": [
			{"kind": "exit", "name": "Mahalleye dön", "at": "exit"},
			{"kind": "door", "name": "Kafe Yıldız", "at": "door_kafe", "to": "kafe_yildiz"},
			{"kind": "door", "name": "Kargo deposu", "at": "door_kargo", "to": "kargo"},
			{"kind": "door", "name": "Dershane", "at": "door_dershane", "to": "dershane"},
			{"kind": "door", "name": "Butik Moda", "at": "door_butik", "to": "butik"},
			{"kind": "door", "name": "Av & Savunma", "at": "door_hirdavat", "to": "hirdavat"},
			{"kind": "object", "name": "Messi büstü", "at": "bust", "dir": "up", "prop": "messi_bust",
				"portrait": "res://assets/sprites/messi_portrait.png",
				"lines": ["Çarşı esnafı toplanıp yaptırmış. Altında \"Gelmişlerin en iyisi\" yazıyor.",
					"Büstün burnu parlamış: herkes uğur için dokunuyor.", "Biri ayağına top bırakmış."]},
		],
		"actions": [],
	},
	"kafe_yildiz": {
		"name": "Kafe Yıldız", "desc": "Çarşının sıcak kafesi. Kahve iç, garsonluk yap.", "parent": "carsi",
		"spots": [
			{"kind": "exit", "name": "Çarşıya çık", "at": "exit", "to": "carsi", "spawn": "from_kafe"},
			{"kind": "npc", "name": "Kafe sahibi Melek Hanım", "look": "melek", "stand": "melek", "at": "talk_melek",
				"actions": ["coffee", "tea", "waiter"],
				"lines": ["Hoş geldin! Kahve mi, iş mi?", "Garson lazım, akşamlar çok yoğun.", "Tepsiyi düşürürsen maaştan keserim, ona göre!"]},
		],
		"actions": [
			{"id": "coffee", "name": "Türk kahvesi", "time": 15, "energy": 18, "food": -1, "money": -35, "needs": {"open": [480, 1440]}},
			{"id": "tea", "name": "Çay + poğaça", "time": 20, "energy": 8, "food": 18, "money": -25, "needs": {"open": [480, 1440]}},
			{"id": "waiter", "name": "Garsonluk vardiyası (4 sa, sipariş başı 4 TL + bahşiş)", "time": 240, "energy": -25,
				"food": -10, "per_order": 4, "scene": "waiter", "needs": {"open": [480, 1440], "min_energy": 25}},
		],
	},
	"kargo": {
		"name": "Kargo Deposu", "desc": "Raflar, koliler, bant. Güçlüysen iş var.", "parent": "carsi",
		"spots": [
			{"kind": "exit", "name": "Çarşıya çık", "at": "exit", "to": "carsi", "spawn": "from_kargo"},
			{"kind": "npc", "name": "Kargo şefi Bayram", "look": "hayri", "stand": "bayram", "at": "talk_bayram", "actions": ["cargo"],
				"lines": ["Koliler ağır, bilek lazım!", "Güçsüzsen hiç başlama, bel fıtığı olursun.", "Bant durmaz, sen de durma!"]},
		],
		"actions": [
			{"id": "cargo", "name": "Koli taşı (4 sa, +güç)", "time": 240, "energy": -40, "food": -16, "money": 180, "gain": {"str": 0.6},
				"needs": {"open": [420, 1380], "min_energy": 40, "min_str": 15}},
		],
	},
	"dershane": {
		"name": "Dershane", "desc": "YKS'ye hazırlık. Düzenli öğrenciye özel ders işi var.", "parent": "carsi",
		"spots": [
			{"kind": "exit", "name": "Çarşıya çık", "at": "exit", "to": "carsi", "spawn": "from_dershane"},
			{"kind": "npc", "name": "Dershane müdürü", "look": "plaza", "stand": "mudur", "at": "talk_mudur", "actions": ["tutor"],
				"lines": ["Matematik bilen düzgün bir öğrenci arıyoruz.", "Önce kendi derslerine düzenli git, sonra konuşalım.",
					"Velilerimiz çok titiz, ona göre."]},
		],
		"actions": [
			{"id": "tutor", "name": "Özel ders ver (2 sa)",
				"time": 120, "energy": -10, "food": -5, "money": 150,
				"needs": {"open": [600, 1380], "min_energy": 10, "good_weeks": 2}},
		],
	},
	"butik": {
		"name": "Butik Moda", "desc": "Çarşıdaki giyim mağazası.", "parent": "carsi",
		"spots": [
			{"kind": "exit", "name": "Çarşıya çık", "at": "exit", "to": "carsi", "spawn": "from_butik"},
			{"kind": "npc", "name": "Butikçi Selin", "look": "selin", "stand": "selin", "at": "talk_selin", "shop": "outfits",
				"lines": ["Yeni sezon geldi canım, bak bak!", "Bu ceket tam sana göre, yemin ederim.", "Şapkalar da geldi, deneyelim mi?"]},
		],
		"actions": [],
	},
	"hirdavat": {
		"name": "Av & Savunma", "desc": "Kemal'in silah dükkanı. Cam vitrinde sopa, muşta, bıçak, levye, pala, balta.", "parent": "carsi",
		"spots": [
			{"kind": "exit", "name": "Çarşıya çık", "at": "exit", "to": "carsi", "spawn": "from_hirdavat"},
			{"kind": "npc", "name": "Silahçı Kemal", "look": "sivil31", "stand": "kemal", "at": "talk_kemal", "shop": "weapons",
				"lines": ["Kendini korumak lazım evlat, devir kötü.", "Sopa beyzbol için, ona göre.", "Polise benden aldığını söyleme."]},
		],
		"actions": [],
	},
	"kampus_kafe": {
		"name": "Kampüs Kafe", "desc": "Ders arası herkes burada.",
		"extras": [["sivil3", "friends2", "up", true]],
		"spots": [
			{"kind": "exit", "name": "Kampüse dön", "at": "exit"},
			{"kind": "npc", "name": "Barista Deniz", "look": "kulaklik", "stand": "barista", "at": "talk_barista", "actions": ["coffee", "tea"],
				"lines": ["Bugün ne içiyoruz?", "Filtre kahve taze, yeni demledim.", "Vize haftası, herkes zombi gibi."]},
			{"kind": "npc", "name": "Sınıf arkadaşların", "look": "hipster", "stand": "friends", "sit": true, "at": "talk_friends", "actions": ["chat"],
				"lines": ["Gel otur, hocayı çekiştiriyoruz!", "Ödevi yaptın mı? Biz de yapmadık.", "Hafta sonu halı saha var, geliyor musun?"]},
			{"kind": "npc", "name": "Tıpçı Elif", "look": "elif", "stand": "elif", "sit": true, "at": "talk_elif", "actions": ["chat"],
				"lines": ["Nöbetten çıktım, bir kahve şart.", "Otursana biraz, kafam çok dolu."]},
			{"kind": "object", "name": "Pencere kenarı", "at": "window", "dir": "up",
				"lines": ["Kampüsün çimleri yemyeşil. Biraz nefes alsan?"]},
		],
		"actions": [
			{"id": "coffee", "name": "Filtre kahve", "time": 10, "energy": 20, "food": -2, "money": -30, "needs": {"open": [420, 1440]}},
			{"id": "tea", "name": "Çay + poğaça", "time": 20, "energy": 8, "food": 18, "money": -20, "needs": {"open": [420, 1440]}},
			{"id": "chat", "name": "Sohbet et (1 sa)", "time": 60, "energy": 10, "food": -3,
				"needs": {"open": [420, 1440]}, "replies": ["İyi ki geldin, kafam dağıldı.", "Yine gel, muhabbet güzeldi!", "Hadi bir çay daha?"]},
		],
	},
	"berber": {
		"name": "Berber Sabri", "desc": "Saç tıraşı, yeni saç modeli. 09:00-21:00 açık.",
		"pos": Vector2(88, 180), "color": Color("c84438"),
		"spots": [
			{"kind": "exit", "name": "Kapı", "at": "exit"},
			{"kind": "npc", "name": "Berber Sabri", "look": "berber", "stand": "sabri", "at": "talk_sabri", "barber": true,
				"lines": ["Buyur kardeşim, otur bakalım. Nasıl keselim?", "Ense kısa, yanlar biraz alınsın mı?",
					"Bu saçla kavgaya gidilmez, gel düzeltelim.", "Sakal da var mı? Şaka şaka, sadece saç."]},
		],
		"actions": [],
	},
	"galeri": {
		"name": "Necdet Oto Galeri", "desc": "İkinci el, az kullanılmış, sahibinden temiz.",
		"pos": Vector2(424, 178), "color": Color("6b7080"),
		"spots": [
			{"kind": "exit", "name": "Kapı", "at": "exit"},
			{"kind": "npc", "name": "Galerici Necdet", "look": "sivil17", "stand": "necdet", "at": "talk_necdet", "actions": [],
				"lines": ["Abi bu araçlar kızlık arabası, hepsi orijinal!", "Bak sana özel fiyat yaparım, kimseye söyleme.", "Boyası yok, değişeni yok, tramer yok. Yemin ederim."]},
			{"kind": "car", "car": "sahin", "at": "car_0", "index": 0},
			{"kind": "car", "car": "toros", "at": "car_1", "index": 1},
			{"kind": "car", "car": "doblo", "at": "car_2", "index": 2},
			{"kind": "car", "car": "egea", "at": "car_3", "index": 3},
			{"kind": "car", "car": "passat", "at": "car_4", "index": 4},
			{"kind": "car", "car": "golf", "at": "car_5", "index": 5},
			{"kind": "car", "car": "bmw", "at": "car_6", "index": 6},
			{"kind": "car", "car": "mercedes", "at": "car_7", "index": 7},
		],
		"actions": [],
	},
}

## Kampüs eylemleri: fakültelerde ders, yemekhane. Ayrı sahnelerde oynanır (scenes/activities).
const CAMPUS_ACTIONS := {
	"lecture": {"id": "lecture", "name": "Derse gir (2 sa)",
		"time": 120, "energy": -10, "food": -6, "effect": "lecture", "scene": "lecture",
		"needs": {"weekday": true, "open": [540, 1020], "once_per_day": "lecture", "min_energy": 10}},
	"cafeteria": {"id": "cafeteria", "name": "Yemekhane", "time": 30, "food": 50, "money": -15, "scene": "cafeteria",
		"needs": {"open": [660, 1200]}},
}

## Haritalar. go: tıklanınca ne olur
##   place     mekan ekranı (PLACES içindeki aynı id)
##   metro     Beylikdüzü durağı, okula metrobüs        metro_home  kampüsten eve metrobüs
##   lecture   fakültede ders (course: dersin adı)      cafeteria   yemekhane
const MAPS := {
	"mahalle": {
		"name": "BEYLİKDÜZÜ", "bg": "bg_map", "walk": 15, "start": "ev",
		"line": [Vector2(330, 52), "E-5 · metrobüs → Davutpaşa"],
		"spots": {
			"ev": {"name": "Ev", "desc": "Küçük, rutubetli ama senin.", "pos": Vector2(150, 145), "go": "place"},
			"market": {"name": "Market", "desc": "Köşedeki market. 07:00-01:00 açık.", "pos": Vector2(230, 155), "go": "place"},
			"gym": {"name": "Rıza'nın Salonu", "desc": "Mahallenin spor salonu. 06:00-24:00 açık.", "pos": Vector2(340, 160), "go": "place"},
			"galeri": {"name": "Necdet Oto Galeri", "desc": "Araba al, sat, yükselt.", "pos": Vector2(400, 210), "go": "place"},
			"berber": {"name": "Berber Sabri", "desc": "Saç tıraşı, yeni saç modeli. 09:00-21:00 açık.", "pos": Vector2(100, 180), "go": "place"},
			"carsi": {"name": "Çarşı", "desc": "İş (kafe, kargo, dershane) ve alışveriş (butik, Av & Savunma).", "pos": Vector2(220, 200), "go": "place"},
			"durak": {"name": "Metrobüs Durağı", "desc": "Okula (YTÜ Davutpaşa) metrobüsle gidilir.", "pos": Vector2(340, 100), "go": "metro"},
			"otopark": {"name": "Otopark", "desc": "Arabanla okula git: ~35 dk, 30 TL benzin. Trafikte kavga çıkabilir.", "pos": Vector2(320, 210), "go": "drive"},
		},
	},
	"kampus": {
		"name": "YTÜ DAVUTPAŞA", "bg": "bg_campus", "walk": 8, "start": "giris",
		"line": [Vector2(140, 34), "Hafta içi 09:00-17:00 ders  ·  haftada en az 3 gün"],
		"spots": {
			"giris": {"name": "Kampüs girişi (metrobüs)", "desc": "Eve dönmek için metrobüse bin.", "pos": Vector2(400, 210), "go": "metro_home"},
			"eef": {"name": "Elektrik-Elektronik Fak.", "desc": "Devre Analizi dersi.", "pos": Vector2(250, 78), "go": "lecture", "course": "Devre Analizi"},
			"mak": {"name": "Makine Fakültesi", "desc": "Termodinamik dersi.", "pos": Vector2(390, 140), "go": "lecture", "course": "Termodinamik"},
			"fen": {"name": "Fen-Edebiyat Fakültesi", "desc": "Diferansiyel Denklemler dersi.", "pos": Vector2(318, 104), "go": "lecture", "course": "Diferansiyel Denklemler"},
			"yemekhane": {"name": "Merkez Yemekhane", "desc": "11:00-20:00. Ucuz ve doyurucu.", "pos": Vector2(56, 82), "go": "cafeteria"},
			"kampus_kafe": {"name": "Kampüs Kafe", "desc": "Kahve, çay, sohbet. Enerji toplamanın yolu.", "pos": Vector2(190, 210), "go": "place"},
			"otopark": {"name": "Otopark", "desc": "Arabanla eve dön: ~35 dk, 30 TL benzin.", "pos": Vector2(300, 203), "go": "drive"},
		},
	},
}