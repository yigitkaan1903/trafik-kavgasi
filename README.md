# Trafik Kavgası

Beylikdüzü'nde yaşayan, okulu Davutpaşa'da olan bir YTÜ öğrencisisin. Punch Club tarzı bir günlük hayat: zamanın, enerjin ve tokluğun kısıtlı. Gymde antrenman yaparak güçlen, çarşıda çalışarak para kazan, haftada en az 3 gün derse git ki pazartesi harçlık gelsin, yemek yemeyi unutma. Okula metrobüsle gidiyorsun: durakta insan yığını, kaynakçılar, koltuk kavgaları ve yolda sataşmalar seni bekliyor. Güçlendikçe kavgalar kolaylaşır; yendiğin rakipler senden korkmaya başlar (Nam). Çarşıdaki butikten kıyafet, hırdavatçıdan kavga için silah (muşta, beyzbol sopası, bıçak) alabilir, evdeki gardıroptan giyip çantana koyabilirsin. Para biriktirip araba alınca haritadaki otoparktan arabayla okula gidip gelebilirsin: metrobüsten hızlı (~35 dk) ama benzin parası var ve trafikte kavga çıkabilir.

**Zorluk** (yeni oyunda seçilir): antrenman yapmadığın statların gece ne kadar azalacağını belirler. Rahat: hiç, Gerçekçi: 1 puan, Punch Club: 3 puan.
Godot 4.7, GDScript, 480×270 pixel art, Stardew / RPG Maker gibi 3/4 üstten bakış (16 piksellik karolar, dört yöne yürüyen karakterler).

## Açmak
Godot → **İçe Aktar** → bu klasördeki `project.godot` → **F5** ile oyna.

## Tuşlar
| Trafik | Dövüş |
|---|---|
| Sol / Sağ (A/D): şerit | WASD (oklar): yürü; yukarı-aşağı ile rakiple aynı hizaya gel |
| Mekanlar, durak, metrobüs: WASD/oklar dört yöne yürü, E konuş / bin / otur | |
| Koltuk kapma: WASD yürü, E otur | |
| Metrobüs: E otur / laf at | |
| T: telefon (her yerde), G garaj, Esc menü | |
| Yukarı / Aşağı (W/S): gaz / fren | J: yumruk, K: tekme |
| H: korna | L: blok (basılı tut) |
| G: garaj, Esc: menü | Boşluk: geri kaç, U: direksiyon kilidi (satın alınca) |

**F11** (ya da Alt+Enter): tam ekran / pencere. Oyun tam ekran açılır, tercih hatırlanır.

## Nereyi düzenlemeli?
| Dosya | İçinde ne var |
|---|---|
| `data/places.gd` | **Günlük hayat dengesi**: mekanlar, eylemler, fiyatlar, işler, antrenman kazancı, zorluklar, okul ve harçlık |
| `data/rivals.gd` | Rakipler: can, güç, saldırganlık, ödül, replikler |
| `data/metro_events.gd` | Metrobüs durakları, olayları ve durakta bağırılan laflar |
| `scenes/metro/station.gd` | Durak: kalabalık, sıra/kaynak, metrobüs geliş sıklığı ve kapasitesi |
| `scenes/metro/seat_rush.gd` | Koltuk kapma |
| `scenes/ui/phone.gd` | Telefon: ZepBet (zeplin kumarı), Block Blast, Mesajlar |
| `data/cars.gd` | Arabalar: fiyat, hız, kaporta |
| `scripts/autoload/game_state.gd` | Zaman, enerji, tokluk, statların dövüşe etkisi (`player_max_hp`, `player_power`, `player_agility`), kayıt, Nam etkisi |
| `scenes/map/map.gd`, `scenes/places/place.gd` | Mahalle haritası ve mekan ekranları |
| `scenes/world/room.gd` | 3/4 bakış oda motoru: zemin + y'ye göre sıralanan eşyalar ve insanlar, çarpışma, işaretler, kamera |
| `tools/sim_week.gd` | Denge testi: `godot --headless -s tools/sim_week.gd` 14 günü her zorlukta simüle eder |
| `scenes/fight/fighter.gd` | Saldırı hasarları, menziller, zamanlamalar (`ATTACKS`) |
| `scenes/fight/ai_fighter.gd` | Rakip yapay zekâsı |
| `scenes/traffic/` | Trafik, NPC arabalar, önüne kırma davranışı; otoparktan çıkınca hedefe sürüş (`DRIVE_*`, `FUEL_COST`: data/places.gd) |
| `tools/make_rooms.py` | **Bütün mekanlar** (ev, market, gym, çarşı, kampüs kafe, galeri, amfi, yemekhane, restoran, durak, metrobüs içi, sokak): zemin/duvar görseli, eşyalar, çarpışma kutuları ve karakterlerin durduğu işaretler. `data/rooms_data.gd` dosyasını üretir (elle düzenlenmez) |
| `tools/make_topdown.py` | 3/4 bakış karakter sayfaları: her kişi için 4 yön × pozlar (`assets/topdown/td_*.png`) |
| `tools/make_sprites.py` | Portreler (yandan büyük dövüşçü çizimleri) ve trafik arabaları |
| `tools/make_backgrounds.py` | Haritalar ve arayüz çerçeveleri |
| `tools/make_audio.py` | Müzik (sakin lo-fi, dövüş müziği) ve ses efektleri, saf Python sentezi (`assets/audio`) |
| `scripts/autoload/audio.gd` | Müzik/efekt çalma, sahneye göre müzik seçimi, ses ayarları |
| `data/shop.gd` | Butik kıyafetleri ve hırdavattaki silahlar (fiyat, hasar, menzil) |
| `data/messages.gd` | Telefona her gün gelen mesajlar (anne, arkadaşlar, reklamlar) |
| `scenes/ui/lighting.gd` | Saate göre sahne rengi ve gece yanan lambalar |

Görseller kodla üretilir: `python tools/make_topdown.py`, `python tools/make_rooms.py` (sonra Godot'ta projeyi bir kez açıp içe aktar). Hazır çizimlere geçmek istersen aynı adlarla değiştirmen yeterli: karakter sayfaları 28×30'luk hücreler (satırlar: aşağı, yukarı, sağ, yerde yatma), mekanlar 1x (karakter boyu 30 piksel).

## Test kısayolları
Komut satırından (`--` sonrası oyuna gider, kayıt dosyasına dokunmaz):
```
godot --path . res://scenes/places/place.tscn -- --fresh --place=gym --time=10:00 --money=300 --do=gym_day,lift
godot --path . res://scenes/metro/metrobus.tscn -- --seated --station=14 --time=09:00   (okula varış)
godot --path . res://scenes/fight/fight.tscn -- --rival=selim --bet --stats=30,20,30
godot --path . res://scenes/garage/garage.tscn -- --money=5000 --car=bmw
godot --path . res://scenes/fight/fight.tscn -- --rival=teyze --venue=bus --nam=3
godot --path . res://scenes/fight/fight.tscn -- --autoplay --shot=ekran.png --wait=10
godot --path . res://scenes/metro/station.tscn -- --fresh --autoplay        (sırada bekleyip biner)
godot --path . res://scenes/metro/station.tscn -- --fresh --autoplay --cut  (kaynak yapar)
godot --path . res://scenes/metro/seat_rush.tscn -- --board=bos --ahead=6
godot --path . res://scenes/metro/metrobus.tscn -- --seated --phone=zep-fly   (home|zep|blocks|msg)
godot --path . res://scenes/traffic/traffic.tscn -- --fresh --car=sahin --drive=kampus --drive_left=300
godot --path . res://scenes/activities/waiter.tscn -- --fresh --activity=carsi:waiter --autoplay
godot --path . res://scenes/activities/activity.tscn -- --fresh --activity=lecture --time=10:00 --act
```

## Lisanslar
Fontlar: Rubik (gövde metinleri) ve Pixelify Sans (büyük başlıklar), ikisi de SIL Open Font License (`assets/fonts/`).
