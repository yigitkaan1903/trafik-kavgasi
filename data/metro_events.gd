## Metrobüs: duraklar, yolculuk olayları ve durakta bağırılan laflar.
##   bg:      dövüş arka planı: "bus" (metrobüs içi) ya da "durak" (peron)
##   rivals:  bu olayda karşına çıkabilecek rakipler (rivals.gd'deki id'ler)
##   text:    {r} yerine rakibin adı yazılır
##   fight / avoid: buton yazıları
##   need:    "standing" (sadece ayaktayken) ya da "seated" (sadece otururken)
##   seat:    "gain" (kazanırsan oturursun) ya da "keep" (kaybedersen yerini kaybedersin)
##   avoid_effect: "stand" (bu seçenekte yerinden kalkarsın)
##   money:   rakipsiz olaylarda kazanılan/kaybedilen para
##   weight:  ne sıklıkla çıkar (ondalık olabilir: 0.2 = nadir)

const STATIONS := [
	"Beylikdüzü Sondurak", "Cumhuriyet Mah.", "Beykent", "Güzelyurt", "Haramidere", "Avcılar",
	"Şükrübey", "Küçükçekmece", "Florya", "Sefaköy", "Yenibosna", "Şirinevler", "Bahçelievler",
	"İncirli", "Zeytinburnu", "Merter", "Davutpaşa-YTÜ",
]
const SCHOOL := "Davutpaşa-YTÜ"

const EVENTS := [
	{"title": "Boş koltuk!", "bg": "bus", "weight": 3, "need": "standing", "seat": "gain",
		"rivals": ["plaza", "teyze", "kulaklik", "elif", "kaan", "eren", "buse", "husnu"],
		"text": "Bir koltuk boşaldı. {r} de aynı koltuğa yöneldi...",
		"fight": "Koltuğu kap!", "avoid": "Ayakta git"},
	{"title": "Yer ver!", "bg": "bus", "weight": 3, "need": "seated", "seat": "keep",
		"rivals": ["teyze", "abi", "elif", "ebu", "husnu", "rifat"],
		"text": "{r} tam önünde dikiliyor ve sana bakıyor. Bütün vagon da sana bakıyor.",
		"fight": "Bu yer benim!", "avoid": "Yer ver (ayakta gidersin)", "avoid_effect": "stand"},
	{"title": "Omuz attı!", "bg": "bus", "weight": 2, "need": "standing", "rivals": ["abi", "kulaklik", "plaza", "hipster", "eren", "kaan", "kokan"],
		"text": "{r} geçerken sana sert bir omuz attı.",
		"fight": "Dur bakalım!", "avoid": "Özür dile (sen!)"},
	{"title": "Hoparlörden arabesk", "bg": "bus", "weight": 2, "rivals": ["kulaklik", "abi", "hipster", "eren", "kokan", "buse"],
		"text": "{r} telefonundan hoparlörle arabesk açtı. Bütün vagon dinliyor.",
		"fight": "Kapat şunu!", "avoid": "Kulaklık tak"},
	{"title": "Çanta koltukta", "bg": "bus", "weight": 2, "need": "standing", "seat": "gain",
		"rivals": ["teyze", "plaza"],
		"text": "{r} çantasını yan koltuğa koymuş, kaldırmıyor.",
		"fight": "Çantayı kaldır!", "avoid": "Boş ver"},
	{"title": "Kapının önü", "bg": "durak", "weight": 2, "rivals": ["abi", "teyze", "plaza", "kulaklik", "hipster", "elif", "hakan", "ebu", "rifat", "buse"],
		"text": "{r} kapının tam önünde dikiliyor. İnmeyecek ama çekilmiyor da!",
		"fight": "İtip geç!", "avoid": "Boş ver"},
	# rakipsiz olaylar
	{"title": "Yerde para!", "bg": "", "weight": 0.2, "money": 10,
		"text": "Koltuğun altında buruşuk bir 10 TL buldun. Kimse görmedi."},
	{"title": "Sıkışma", "bg": "", "weight": 1, "need": "standing", "money": 0,
		"text": "Metrobüs o kadar dolu ki ayakların yere değmiyor. Kavga etmeye yer bile yok."},
	{"title": "Kart kontrolü", "bg": "bus", "weight": 1, "rivals": ["hakan"],
		"text": "{r} vagonda kart kontrolü yapıyor. Sana takıldı: \"Bu kart öğrenci kartı mı, emin misin?\"",
		"fight": "Kartım geçerli!", "avoid": "Kartı göster, uğraşma"},
	{"title": "Vaaz", "bg": "bus", "weight": 1, "rivals": ["ebu"],
		"text": "{r} vagonun ortasında yüksek sesle nasihat veriyor. Sana dönüp \"Sen de dinle evlat!\" dedi.",
		"fight": "Biraz sessiz ol!", "avoid": "Başını salla, dinle"},
	{"title": "Sızmış yolcu", "bg": "bus", "weight": 1, "need": "seated", "seat": "keep", "rivals": ["eren"],
		"text": "{r} yanına çöktü, başını omzuna koydu ve horlamaya başladı.",
		"fight": "Kalk üstümden!", "avoid": "Kalk, ayakta git", "avoid_effect": "stand"},
	{"title": "Uyuyakaldın", "bg": "", "weight": 1, "need": "seated", "money": 0,
		"text": "Koltuğun sıcaklığı seni aldı götürdü. Yanındakinin omzunda uyandın. Kimse bir şey demedi."},
]

## Kavga kazanınca paranın nereden geldiği (komik açıklama)
const WIN_REASONS := [
	"kavga videon viral oldu",
	"yolcular alkışlayıp bahşiş attı",
	"rakibin cebinden bozukluk düştü",
	"bir youtuber röportaj yaptı",
]

# ---------------------------------------------------------------- Durak (Beylikdüzü) lafları

const SHOUT_WAITING := [
	"Kaynak yapmayın!", "İtmeyin arkadan!", "Bu metrobüs ne zaman gelecek ya?",
	"Her sabah aynı çile...", "Turnike yine bozuk!", "Kardeşim ayağıma bastın!",
	"Sıra burası mı, orası mı?", "Bekliyoruz işte, sabır!",
]
const SHOUT_EMPTY_COMING := ["Boş geliyor, boş!!", "Hazır olun, boş geldi!", "Oturarak gideceğiz inşallah!"]
const SHOUT_FULL_COMING := ["Dolu geliyor, bekleyin...", "Ayakta mı gideceğiz yine?", "Bunu salın, arkası boş!"]
const SHOUT_BOARDING := ["İlerleyin içeri!", "Arkaya doğru ilerleyelim!", "Kapıyı tutun!", "İtmeyin, herkes binecek!"]
const SHOUT_FRONT_STUCK := ["Niye binmiyorsunuz öndekiler?!", "Binin ya da çekilin!", "Önden bir hareket!"]
const SHOUT_CUT_MILD := ["Pardon, sıra var.", "Sıra arkadan ama...", "Hmm, kaynak mı bu?", "Herkes bekliyor ama..."]
const SHOUT_CUT := ["Kaynak yapma kardeşim!", "Sıraya gir!", "Hop hop, nereye?!", "Biz burada boşuna mı bekliyoruz?!", "Ayıp ayıp!"]
const SHOUT_DOORS_CLOSE := ["Doldu doldu, bir sonrakine!", "Kapı kapanıyor!", "Bırakın kapıyı!"]
## Kalabalığı dolduran figüranlar (make_sprites.py'deki civilians()). Bunlara laf atılmaz.
## Figüranlar: sivil0..sivil39 (tools/make_topdown.py civilians: farklı ten, saç, başörtüsü, kıyafet, boy)
const CIVILIAN_COUNT := 40
## Kalabalıktaki tanıdık yüzler (laf atılabilir, kavga edilebilir)
const NAMED := ["teyze", "plaza", "kulaklik", "abi", "hipster", "elif", "necati", "cemil", "remzi", "eren", "kaan", "ebu", "hakan"]


## Kalabalık için rastgele bir yüz: çoğu figüran, bazıları tanıdık.
static func random_look() -> String:
	return NAMED.pick_random() if randf() < 0.25 else "sivil%d" % (randi() % CIVILIAN_COUNT)


const SHOUT_SIMIT := ["Simiiit! Taze simit!", "Sıcak simit var!", "Simit, poğaça!"]
