## Çarşıdaki dükkanlar: Butik (kıyafet) ve Spor & Hırdavat (kavga için silah).
## Alınan kıyafetler evdeki gardıroba gelir, oradan giyilir. Silah da gardıroptan çantaya konur.
##
## Kıyafetlerin görünüşü tools/make_topdown.py OUTFITS içinde (aynı id); her biri ayrı karakter sayfası
## (assets/topdown/td_player_<id>.png). "esofman" başlangıç kıyafeti (td_player.png).

const OUTFITS := {
	"esofman": {"name": "YTÜ eşofmanı", "price": 0, "desc": "Başlangıç kıyafetin. Rahat, lacivert, efsane."},
	"kapson": {"name": "Siyah kapüşonlu", "price": 220, "desc": "Gece metrobüsünde kimse yanına oturmaz."},
	"hawaii": {"name": "Hawaii gömleği", "price": 180, "desc": "Yaz geldi, sen de geldin."},
	"forma": {"name": "Futbol forması", "price": 280, "desc": "Maç günü değil ama olsun."},
	"kot": {"name": "Kot ceket", "price": 340, "desc": "90'lar geri döndü."},
	"deri": {"name": "Deri ceket", "price": 480, "desc": "Taksiciler bile saygı duyar."},
	"mont": {"name": "Kışlık mont", "price": 560, "desc": "Davutpaşa'nın ayazına karşı."},
	"takim": {"name": "Takım elbise", "price": 900, "desc": "Plaza Kerem kıskançlıktan çatlar."},
	"pembe": {"name": "Pembe kapüşonlu", "price": 200, "desc": "Özgüven meselesi."},
	"gomlek": {"name": "Ofis gömleği", "price": 260, "desc": "Staj mülakatına hazır."},
	"kazak": {"name": "Bordo örgü kazak", "price": 300, "desc": "Anneannenin elinden çıkmış gibi."},
	"kirmizi": {"name": "Kırmızı eşofman", "price": 320, "desc": "Mahallenin abisi havası."},
	"metal": {"name": "Metalci tişörtü", "price": 240, "desc": "Kulaklıktan Metallica sızar."},
	"yagmurluk": {"name": "Sarı yağmurluk", "price": 380, "desc": "Davutpaşa'da yağmur eksik olmaz."},
	"kamuflaj": {"name": "Kamuflaj mont", "price": 620, "desc": "Metrobüste görünmez olursun (olmazsın)."},
	"smokin": {"name": "Smokin", "price": 1200, "desc": "Mezuniyet balosu ya da trafik kavgası."},
}

## damage: yumruk (ve özel hareket) hasar çarpanı. range: yumruğun ek menzili (piksel).
## startup: yumruğun ek hazırlanma süresi (ağır silah yavaştır).
## Berber: saç modelleri (tools/make_topdown.py PLAYER_HAIRS ile aynı id'ler; "sidepart" başlangıç saçı).
const HAIRCUTS := {
	"sidepart": {"name": "Klasik yan ayrık", "price": 60},
	"short": {"name": "Kısa kesim", "price": 60},
	"buzz": {"name": "Asker tıraşı", "price": 40},
	"curly": {"name": "Kıvırcık perma", "price": 120},
	"long": {"name": "Uzun saç (protez)", "price": 180},
	"bun": {"name": "Topuz", "price": 90},
	"ponytail": {"name": "At kuyruğu", "price": 90},
	"bald": {"name": "Sıfır numara", "price": 40},
}
const HAIRCUT_MINUTES := 30
const BARBER_HOURS := [540, 1260]   # 09:00-21:00

const WEAPONS := {
	"musta": {"name": "Muşta", "price": 260, "damage": 1.3, "range": 0.0, "startup": 0.0,
		"desc": "Yumruklar %30 daha sert."},
	"sopa": {"name": "Beyzbol sopası", "price": 520, "damage": 1.6, "range": 8.0, "startup": 0.05,
		"desc": "Uzun menzil, %60 hasar ama biraz yavaş."},
	"bicak": {"name": "Bıçak", "price": 820, "damage": 1.85, "range": 2.0, "startup": 0.0,
		"desc": "Çok tehlikeli. Kazanırsan bile polis çevirebilir."},
}
const KNIFE_POLICE_CHANCE := 0.3     # bıçakla kazanınca polisin çevirme ihtimali
const KNIFE_POLICE_FINE := 150
