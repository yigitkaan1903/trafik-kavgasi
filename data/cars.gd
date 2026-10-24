## Araba listesi. Yeni araba eklemek için buraya bir satır ekle ve
## tools/make_sprites.py içindeki CARS listesine aynı id ile çizimini ekle.
##   price: galeride satış fiyatı (satarken yarısını alırsın)
##   shop:  galeride satılıyor mu (false ise sadece iddiayla kazanılır)
##   speed: hız çarpanı, hp: kaporta dayanıklılığı (kaç sürtünmeye dayanır)

const STARTER := "sahin"

const CARS := {
	"sahin": {"name": "Murat 131 Şahin", "price": 200, "shop": true, "speed": 1.0, "hp": 3,
		"desc": "Babadan kalma. Dandik ama bizim."},
	"tofas": {"name": "Tofaş Doğan", "price": 300, "shop": false, "speed": 1.0, "hp": 3,
		"desc": "Necati Amca'nın 30 yıllık emektarı."},
	"doblo": {"name": "Fiat Doblo", "price": 700, "shop": true, "speed": 1.08, "hp": 5,
		"desc": "Esnafın gözdesi. Kasası sağlam."},
	"passat": {"name": "VW Passat", "price": 1600, "shop": true, "speed": 1.22, "hp": 4,
		"desc": "Dizel, hızlı ve tabii ki makam aracı."},
	"bmw": {"name": "BMW 3.20", "price": 3500, "shop": true, "speed": 1.4, "hp": 4,
		"desc": "Sinyal kolu fabrikadan çıkmıyor."},
	"taksi": {"name": "Sarı Taksi", "price": 900, "shop": false, "speed": 1.15, "hp": 4,
		"desc": "Taksimetre hâlâ açık."},
	"dolmus": {"name": "Dolmuş", "price": 1200, "shop": false, "speed": 0.95, "hp": 6,
		"desc": "İnecek var!"},
	"kamyon": {"name": "Kamyon", "price": 4000, "shop": false, "speed": 0.9, "hp": 10,
		"desc": "Kimse önünü kesmeye cesaret edemez."},
}
