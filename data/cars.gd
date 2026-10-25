## Araba listesi. Yeni araba eklemek için buraya bir satır ekle ve
## tools/make_sprites.py içindeki CARS listesine aynı id ile çizimini ekle.
##   price: galeride satış fiyatı (satarken yarısını alırsın)
##   shop:  galeride satılıyor mu (false ise sadece iddiayla kazanılır)
##   speed: hız çarpanı, hp: kaporta dayanıklılığı (kaç sürtünmeye dayanır)

const STARTER := "sahin"

## Trafikte sadece süs olan arabalar (tools/make_sprites.py DECOR_CARS): galeride satılmaz, iddiaya girilmez.
## Rakip böyle bir arabayla gelirse kavga olur ama "arabalar ortaya" seçeneği çıkmaz.
const DECOR := ["civ_0", "civ_1", "civ_2", "civ_3", "civ_4", "civ_5", "civ_6", "civ_7", "civ_8", "civ_9"]

const CARS := {
	"sahin": {"name": "Murat 131 Şahin", "price": 200, "shop": true, "speed": 1.0, "hp": 3,
		"desc": "Babadan kalma. Dandik ama bizim."},
	"tofas": {"name": "Tofaş Doğan", "price": 300, "shop": false, "speed": 1.0, "hp": 3,
		"desc": "Necati Amca'nın 30 yıllık emektarı."},
	"toros": {"name": "Renault Toros", "price": 450, "shop": true, "speed": 1.04, "hp": 3,
		"desc": "Babalarımızın gençliği. Kokusu bile nostalji."},
	"doblo": {"name": "Fiat Doblo", "price": 700, "shop": true, "speed": 1.08, "hp": 5,
		"desc": "Esnafın gözdesi. Kasası sağlam."},
	"egea": {"name": "Fiat Egea", "price": 1100, "shop": true, "speed": 1.15, "hp": 4,
		"desc": "Kiralık araç filosunun kraliçesi."},
	"passat": {"name": "VW Passat", "price": 1600, "shop": true, "speed": 1.22, "hp": 4,
		"desc": "Dizel, hızlı ve tabii ki makam aracı."},
	"golf": {"name": "VW Golf GTI", "price": 2400, "shop": true, "speed": 1.32, "hp": 4,
		"desc": "Arkasındaki GTI yazısı her şeyi anlatıyor."},
	"bmw": {"name": "BMW 3.20", "price": 3500, "shop": true, "speed": 1.4, "hp": 4,
		"desc": "Sinyal kolu fabrikadan çıkmıyor."},
	"mercedes": {"name": "Mercedes C180", "price": 5000, "shop": true, "speed": 1.45, "hp": 5,
		"desc": "Arka koltukta oturan patron havası."},
	"taksi": {"name": "Sarı Taksi", "price": 900, "shop": false, "speed": 1.15, "hp": 4,
		"desc": "Taksimetre hâlâ açık."},
	"dolmus": {"name": "Dolmuş", "price": 1200, "shop": false, "speed": 0.95, "hp": 6,
		"desc": "İnecek var!"},
	"kamyon": {"name": "Kamyon", "price": 4000, "shop": false, "speed": 0.9, "hp": 10,
		"desc": "Kimse önünü kesmeye cesaret edemez."},
}
