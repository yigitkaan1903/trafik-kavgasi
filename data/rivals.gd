## Rakipler. Nerede çıktıkları, dövüş güçleri ve replikleri.
##   venue:  "traffic" (trafikte arabayla gelir) ya da "metro" (metrobüste çıkar)
##   tier:   trafikte kaç galibiyetten sonra çıkmaya başlar (0: hemen, 1: 2 galibiyet, 2: 5 galibiyet)
##   weight: ne sıklıkla çıkar (büyük = sık)
##   hp, power (hasar çarpanı), speed (hareket ve karar hızı)
##   aggro:  saldırma isteği (0-1), block: blok/kaçma refleksi (0-1)
##   bet:    arabasına iddiaya girilebilir mi
##   lines:  "carpma" (sürtünce), "korna" (korna çalınca), "laf" (metrobüste),
##           "win" (seni dövünce), "lose" (dayak yiyince), "scared" (namını duyunca), "thanks" (yer verince)
##
## Nam: bir rakibi her yenişinde o rakip senden biraz daha korkar (bkz. GameState.fear_level).

const TIER_WINS := [0, 2, 5]

const RIVALS := {
	# ------------------------------------------------------------ Metrobüs
	"teyze": {
		"name": "Pazar Çantalı Teyze", "venue": "metro", "look": "teyze", "weight": 3,
		"hp": 50, "power": 0.8, "speed": 0.8, "aggro": 0.45, "block": 0.1, "reward": 25, "bet": false,
		"lines": {
			"laf": ["Gençler hiç saygı bilmiyor! Kalk bakayım oradan!", "Benim dizlerim ağrıyor, senin neyin ağrıyor?!"],
			"thanks": ["Sağ ol evladım, Allah razı olsun."],
			"scared": ["Aaa, sen o videodaki çocuksun! Tamam evladım, kavga istemem...", "Sen o meşhur kavgacısın! Ben bir şey demedim evladım."],
			"win": ["Çantada üç kilo patates vardı, haberin olsun."],
			"lose": ["Oğluma söyleyeceğim... Polis o..."],
		},
	},
	"kulaklik": {
		"name": "Kulaklıklı Emre", "venue": "metro", "look": "kulaklik", "weight": 3,
		"hp": 55, "power": 0.85, "speed": 1.15, "aggro": 0.4, "block": 0.25, "reward": 30, "bet": false,
		"lines": {
			"laf": ["Ne? Duymuyorum, müzik açık.", "Kanka story atıyorum, bi sus."],
			"thanks": ["Eyv kanka, iyisin."],
			"scared": ["Abi sen o meşhur kavgacısın! Tamam kanka, sorun yok.", "Pardon abi, seni tanımadım. Takipçim olur musun?"],
			"win": ["Bunu story'ye atıyorum."],
			"lose": ["Şarjım da bitti zaten..."],
		},
	},
	"plaza": {
		"name": "Plaza Kerem", "venue": "metro", "look": "plaza", "weight": 2,
		"hp": 70, "power": 0.95, "speed": 1.0, "aggro": 0.45, "block": 0.35, "reward": 45, "bet": false,
		"lines": {
			"laf": ["Benim 9'da toplantım var, anlıyor musun? TOPLANTIM!", "Bu konuyu asap'ten offline'a alalım."],
			"thanks": ["Teşekkürler, toplantıya yetişmem lazımdı."],
			"scared": ["Tamam, bu konuyu escalate etmeyelim.", "Sizinle çalışmak bir onurdur, gerçekten."],
			"win": ["Bunu performans değerlendirmene yazıyorum."],
			"lose": ["Bugün home office yapacaktım zaten..."],
		},
	},
	"abi": {
		"name": "Eşofmanlı Abi", "venue": "metro", "look": "abi", "weight": 2,
		"hp": 85, "power": 1.05, "speed": 0.9, "aggro": 0.55, "block": 0.3, "reward": 60, "bet": false,
		"lines": {
			"laf": ["Ne bakıyon kardeşim? Ne bakıyon?!", "Ben bu hatta 20 senedir biniyom!"],
			"thanks": ["Eyvallah kardeşim, sağ ol."],
			"scared": ["Tamam aslanım, sakin. Ben bir şey demedim.", "Abi sen misin? Hiç tanıyamadım, kusura bakma."],
			"win": ["Okulu bırak, gel benle çalış."],
			"lose": ["Eşofmanım yırtıldı ya..."],
		},
	},
	"hipster": {
		"name": "Hipster Barış", "venue": "metro", "look": "hipster", "weight": 2,
		"hp": 60, "power": 0.85, "speed": 1.05, "aggro": 0.35, "block": 0.3, "reward": 35, "bet": false,
		"lines": {
			"laf": ["Kardeşim kahvemi döktün, bu single origin'di!", "Ben bu metrobüse sen binmeden önce biniyordum."],
			"thanks": ["Çok naziksin dostum, iyi enerji."],
			"scared": ["Tamam dostum, negatif enerjiye gerek yok.", "Sakin... Kahvemi bile bıraktım bak."],
			"win": ["Bunu plaklarıma anlatacağım."],
			"lose": ["Sakalım... sakalım bozuldu..."],
		},
	},
	"elif": {
		"name": "Tıpçı Elif", "venue": "metro", "look": "elif", "weight": 2,
		"hp": 65, "power": 1.0, "speed": 1.2, "aggro": 0.5, "block": 0.35, "reward": 40, "bet": false,
		"lines": {
			"laf": ["36 saattir nöbetteyim, bana bulaşma!", "Anatomi sınavım var, sinirlerim tepemde!"],
			"thanks": ["Çok sağ ol, nöbetten çıktım, ayakta duracak halim yok."],
			"scared": ["Tamam tamam, zaten uykusuzum, uğraşamam.", "Sen o meşhur kavgacısın! Pas geçiyorum."],
			"win": ["Kırık yok, merak etme. Kontrol ettim."],
			"lose": ["Acile... kendim gideyim..."],
		},
	},
	"eren": {
		"name": "Ayyaş Eren", "venue": "metro", "look": "eren", "weight": 2,
		"hp": 80, "power": 1.0, "speed": 0.75, "aggro": 0.6, "block": 0.08, "reward": 40, "bet": false,
		"lines": {
			"laf": ["Kankaa... sen benim en yakın arkadaşımsın... ama ayağıma bastın.", "Bu metrobüs niye dönüyo ya... sen mi döndürüyon?!"],
			"thanks": ["Sen... sen benim kardeşimsin be..."],
			"scared": ["Abi sen o videodaki adamsın... Gel sarılalım kanka.", "Tamam tamam... ben zaten iniyodum... hangi duraktayız?"],
			"win": ["Hık! Ben bile ayakta duramıyorum, sen nasıl düştün?"],
			"lose": ["Yarın hiçbir şey hatırlamıycam... iyi ki..."],
		},
	},
	"kaan": {
		"name": "Kaan Hardal", "venue": "metro", "look": "kaan", "weight": 2,
		"hp": 75, "power": 1.0, "speed": 1.15, "aggro": 0.5, "block": 0.3, "reward": 45, "bet": false,
		"lines": {
			"laf": ["Hardal gibi yakarım kardeşim, uzak dur!", "Ne bakıyon? Sarı mont mu görmedin?"],
			"thanks": ["Eyvallah hocam, borcum olsun."],
			"scared": ["Tamam abi, hardalı ketçapla karıştırmayalım.", "Seni Ebu Hazretleri anlatmıştı... Geç."],
			"win": ["Acı mı? Hardal o, alışırsın."],
			"lose": ["Hardalım... döküldü..."],
		},
	},
	"ebu": {
		"name": "Ebu Hazretleri", "venue": "metro", "look": "ebu", "weight": 1,
		"hp": 100, "power": 1.15, "speed": 0.8, "aggro": 0.35, "block": 0.55, "reward": 70, "bet": false,
		"lines": {
			"laf": ["Evlat, sabır acıdır... ama benim sabrım taştı.", "Bu vagonda edep kalmamış, sana öğretelim."],
			"thanks": ["Allah razı olsun, hayırlı yolculuklar."],
			"scared": ["Hikmet senden yana evlat. Geç, yolun açık olsun.", "Senin namın kervanlarda anlatılıyor. Buyur."],
			"win": ["Nasihat kâr etmeyince... böyle oluyor işte."],
			"lose": ["Bu da bir imtihandı... geçemedim..."],
		},
	},
	"hakan": {
		"name": "Güvenlikçi Hakan", "venue": "metro", "look": "hakan", "weight": 1,
		"hp": 95, "power": 1.1, "speed": 0.95, "aggro": 0.45, "block": 0.4, "reward": 55, "bet": false,
		"lines": {
			"laf": ["Kartını basmadan mı bindin sen? Gel bakalım.", "Burada olay çıkaran sen misin?"],
			"thanks": ["Sağ ol, görevdeyiz yorgunuz."],
			"scared": ["Tamam, ben bir şey görmedim. Telsizim de bozuk zaten.", "Mesaim bitti, karışmıyorum."],
			"win": ["Tutanak tutuyorum, kıpırdama."],
			"lose": ["Merkez... merkez... destek gönderin..."],
		},
	},
	# ------------------------------------------------------------ Trafik
	"necati": {
		"name": "Tofaşlı Necati Amca", "venue": "traffic", "car": "tofas", "look": "necati", "tier": 0, "weight": 3,
		"hp": 55, "power": 0.7, "speed": 0.8, "aggro": 0.3, "block": 0.15, "reward": 40, "bet": false,
		"lines": {
			"carpma": ["Evladım, bizim zamanımızda böyle şoförlük mü vardı?!", "Bu Tofaş'ı 30 senedir çizdirmedim, sen çizdin!"],
			"korna": ["Bana mı korna çalıyorsun? Ben senin dedenle askerdim!", "Sabır evladım, sabır! Ama artık sabrım kalmadı."],
			"scared": ["Tamam evladım, tamam. Sen geç."],
			"win": ["Bastonu almadım bile."],
			"lose": ["Belim... Belim tuttu..."],
		},
	},
	"remzi": {
		"name": "Taksici Remzi", "venue": "traffic", "car": "taksi", "look": "remzi", "tier": 0, "weight": 3,
		"hp": 70, "power": 0.9, "speed": 1.0, "aggro": 0.4, "block": 0.25, "reward": 90, "bet": false,
		"lines": {
			"carpma": ["Ehliyeti çikolata kutusundan mı çıkardın?!", "Taksimetre açık kardeşim, bu da hesaba yazılır!"],
			"korna": ["Ne korna çalıyon lan?! Duraktakileri çağırırım!", "Sabah sabah sinirimi bozma!"],
			"scared": ["Durakta senden bahsediyorlar... Tamam abi, sen haklısın."],
			"win": ["Taksimetre: 1 tane dayak. Üstü kalsın."],
			"lose": ["Durağa söyleyeceğim... Hepsi gelecek..."],
		},
	},
	"cemil": {
		"name": "Dolmuşçu Cemil", "venue": "traffic", "car": "dolmus", "look": "cemil", "tier": 1, "weight": 2,
		"hp": 95, "power": 1.1, "speed": 0.9, "aggro": 0.5, "block": 0.3, "reward": 150, "bet": false,
		"lines": {
			"carpma": ["İnecek var mı?! Sen ineceksin, arabadan!", "Bu hat benim hattım kardeşim!"],
			"korna": ["Arkada boş yer var, gel otur da konuşalım!", "Bir kişilik yer kaldı, o da senin mezarın!"],
			"scared": ["Senin adın hatta efsane abi. Tamam, sen geç.", "Sen bedava bin abi, sen bedava..."],
			"win": ["Arkaya doğru ilerleyelim lütfen."],
			"lose": ["Müsait bir yerde... inebilir miyim..."],
		},
	},
	"selim": {
		"name": "BMW'li Selim Abi", "venue": "traffic", "car": "bmw", "look": "selim", "tier": 0, "weight": 1,
		"hp": 115, "power": 1.1, "speed": 1.25, "aggro": 0.55, "block": 0.45, "reward": 220, "bet": true,
		"lines": {
			"carpma": ["Bu araba senin bütün sülaleden pahalı!", "Çizdiysen yandın, çizdiysen YANDIN!"],
			"korna": ["Sinyal mi? O ne ya?", "Bana korna çalan daha doğmadı kardeşim."],
			"scared": ["Yine mi sen?! Tamam abi, gözlüğümü çıkardım bak."],
			"win": ["Gözlüğümü bile çıkarmadım."],
			"lose": ["Babama söyleyeceğim!"],
		},
	},
	"hayri": {
		"name": "Kamyoncu Hayri", "venue": "traffic", "car": "kamyon", "look": "hayri", "tier": 2, "weight": 1,
		"hp": 160, "power": 1.5, "speed": 0.85, "aggro": 0.6, "block": 0.35, "reward": 450, "bet": true,
		"lines": {
			"carpma": ["Yük de taşırım, seni de taşırım!", "81 ili gezdim, senin gibisini görmedim!"],
			"korna": ["Kamyonun arkasında ne yazıyor biliyon mu? 'SABRET'.", "Bu korna benim kornamın yanında düdük kalır!"],
			"scared": ["Tamam abi, sen haklısın. Kamyonun arkasına adını yazdıracağım."],
			"win": ["Bir dahaki sefere arkamda yazanı oku."],
			"lose": ["Annem... beni... bekler..."],
		},
	},
	"furth": {
		"name": "Furth Man", "venue": "traffic", "car": "passat", "look": "furth", "tier": 1, "weight": 2,
		"hp": 110, "power": 1.2, "speed": 1.2, "aggro": 0.55, "block": 0.45, "reward": 180, "bet": false,
		"lines": {
			"carpma": ["Do you know who I am? I am FURTH MAN!", "Furth Man'in arabasına kimse dokunmaz!"],
			"korna": ["Furth Man'e korna çalınmaz, Furth Man korna çalar!", "Bu korna sesi... meydan okuma mı bu?"],
			"scared": ["Even Furth Man knows when to retreat. Geç dostum."],
			"win": ["Furth Man never loses. Never."],
			"lose": ["Furth Man... will... return..."],
		},
	},
	"mert": {
		"name": "Kuryeci Mert", "venue": "traffic", "car": "doblo", "look": "mert", "tier": 0, "weight": 2,
		"hp": 65, "power": 0.9, "speed": 1.3, "aggro": 0.5, "block": 0.2, "reward": 60, "bet": false,
		"lines": {
			"carpma": ["Kardeşim 12 dakikada teslim etmem lazım, çekil!", "Siparişin soğudu, senin yüzünden!"],
			"korna": ["Korna çalma bana, puanım düşüyor!", "Müşteri beni yıldızlıyor, sen beni kornalıyorsun!"],
			"scared": ["Tamam abi, ben başka yoldan giderim."],
			"win": ["Teslim edildi. Bir yıldız ver bari."],
			"lose": ["Sipariş... iptal..."],
		},
	},
}
