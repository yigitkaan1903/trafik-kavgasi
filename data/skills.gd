## Yetenek ağacı ve başarımlar.
## Başarım açtıkça yetenek puanı (SP) kazanılır. Yetenek açmak için: gereken stat + puan + (varsa) önceki yetenek.
##
## Yetenek alanları:
##   branch: hangi dal (str, agi, sta: statlar; life: günlük hayat)
##   stat:   [stat, en az] (life dalında yok)        cost: kaç yetenek puanı
##   needs:  önce açılması gereken yetenek           desc: etkisi (ekranda yazar)
##   Etkiler kodda id ile okunur: GameState.has_skill("sert_yumruk") vb.

const BRANCHES := {
	"str": {"name": "Güç", "color": Color("ef4444")},
	"agi": {"name": "Çeviklik", "color": Color("22c55e")},
	"sta": {"name": "Dayanıklılık", "color": Color("3b82f6")},
	"life": {"name": "Hayat", "color": Color("e6b428")},
}

const SKILLS := {
	# ---------------------------------------------------------------- Güç
	"sert_yumruk": {"branch": "str", "name": "Sert Yumruk", "stat": ["str", 8], "cost": 1,
		"desc": "Yumruk +1 hasar"},
	"agir_tekme": {"branch": "str", "name": "Ağır Tekme", "stat": ["str", 15], "cost": 1, "needs": "sert_yumruk",
		"desc": "Tekme +2 hasar"},
	"kemik_kiran": {"branch": "str", "name": "Kemik Kıran", "stat": ["str", 25], "cost": 2, "needs": "agir_tekme",
		"desc": "Yumruk +2 hasar daha"},
	"son_darbe": {"branch": "str", "name": "Son Darbe", "stat": ["str", 35], "cost": 2, "needs": "kemik_kiran",
		"desc": "Özel hareket +6 hasar"},
	# ---------------------------------------------------------------- Çeviklik
	"hizli_ayak": {"branch": "agi", "name": "Hızlı Ayak", "stat": ["agi", 8], "cost": 1,
		"desc": "Dövüşte %10 daha hızlı"},
	"siyrilma": {"branch": "agi", "name": "Sıyrılma", "stat": ["agi", 15], "cost": 1, "needs": "hizli_ayak",
		"desc": "Kaçma bekleme süresi -%25"},
	"kontra": {"branch": "agi", "name": "Kontra Blok", "stat": ["agi", 25], "cost": 2, "needs": "siyrilma",
		"desc": "Blokta alınan hasar yarıya iner"},
	"golge": {"branch": "agi", "name": "Gölge", "stat": ["agi", 35], "cost": 2, "needs": "kontra",
		"desc": "Gelen vuruşların %12'si ıskalar"},
	# ---------------------------------------------------------------- Dayanıklılık
	"kalin_deri": {"branch": "sta", "name": "Kalın Deri", "stat": ["sta", 8], "cost": 1,
		"desc": "Dövüşte +10 can"},
	"nefes": {"branch": "sta", "name": "Nefes Kontrolü", "stat": ["sta", 15], "cost": 1, "needs": "kalin_deri",
		"desc": "Kavga 5 enerji daha az yorar"},
	"tas_cene": {"branch": "sta", "name": "Taş Çene", "stat": ["sta", 25], "cost": 2, "needs": "nefes",
		"desc": "Darbe sersemletmesi -%35"},
	"demir_adam": {"branch": "sta", "name": "Demir Adam", "stat": ["sta", 35], "cost": 2, "needs": "tas_cene",
		"desc": "Dövüşte +25 can"},
	# ---------------------------------------------------------------- Günlük hayat
	"pazarlikci": {"branch": "life", "name": "Pazarlıkçı", "cost": 1,
		"desc": "Butik ve hırdavatta %15 indirim"},
	"garson_ustasi": {"branch": "life", "name": "Garson Ustası", "cost": 1, "needs": "pazarlikci",
		"desc": "Garsonlukta sipariş başı +2 TL"},
	"metro_kurdu": {"branch": "life", "name": "Metrobüs Kurdu", "cost": 1, "needs": "garson_ustasi",
		"desc": "Koltuk kaparken %20 daha hızlı"},
	"karizma": {"branch": "life", "name": "Karizma", "cost": 2, "needs": "metro_kurdu",
		"desc": "Gözdağı parası 2 katı"},
}

## Başarımlar: koşul GameState.achievement_progress(id) ile ölçülür ([şu an, hedef]). Her biri puan verir.
const ACHIEVEMENTS := {
	"ilk_kan": {"name": "İlk Kan", "desc": "İlk kavganı kazan.", "goal": 1, "sp": 1},
	"kavgaci": {"name": "Kavgacı", "desc": "5 kavga kazan.", "goal": 5, "sp": 1},
	"efsane": {"name": "Hattın Efsanesi", "desc": "15 kavga kazan.", "goal": 15, "sp": 2},
	"nam": {"name": "Namın Yürüsün", "desc": "Bir rakip senden korksun (nam 3).", "goal": 3, "sp": 1},
	"guclu": {"name": "Pazı", "desc": "Güç 15'e ulaş.", "goal": 15, "sp": 1},
	"cevik": {"name": "Yılan", "desc": "Çeviklik 15'e ulaş.", "goal": 15, "sp": 1},
	"dayanikli": {"name": "Beton", "desc": "Dayanıklılık 15'e ulaş.", "goal": 15, "sp": 1},
	"usta": {"name": "Usta", "desc": "Herhangi bir stat 30 olsun.", "goal": 30, "sp": 2},
	"devamli": {"name": "Örnek Öğrenci", "desc": "Bir hafta derslere düzenli git.", "goal": 1, "sp": 1},
	"garson": {"name": "Tepsi Ustası", "desc": "Toplam 25 sipariş servis et.", "goal": 25, "sp": 1},
	"zengin": {"name": "Cebi Dolu", "desc": "Cebinde 1000 TL olsun.", "goal": 1000, "sp": 1},
	"arabali": {"name": "Direksiyon Başında", "desc": "Araba sahibi ol.", "goal": 1, "sp": 1},
	"sik": {"name": "Şıkır Şıkır", "desc": "3 farklı kıyafetin olsun.", "goal": 3, "sp": 1},
	"koltuk": {"name": "Koltuk Avcısı", "desc": "Metrobüste 5 kez koltuk kap.", "goal": 5, "sp": 1},
	"gece_kusu": {"name": "Gece Kuşu", "desc": "Gece 01:00'de hâlâ ayakta ol.", "goal": 1, "sp": 1},
}
