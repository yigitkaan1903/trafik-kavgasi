"""Punch Club tarzı uzaktan şehir haritaları: Beylikdüzü (bg_map.png) ve YTÜ Davutpaşa (bg_campus.png).

Çalıştırma (proje klasöründen):  python tools/make_citymap.py   (make_backgrounds.py de çağırır)
Şehir sönük gri-yeşil küçük bloklarla doludur; mekanlar renkli PixelLab çizimlerinin küçültülmüşüdür
(assets/pixellab/map/<ad>.png). Etiket yükseklikleri data/map_art.gd'ye yazılır.
Mekan konumları data/places.gd MAPS[...]["spots"] ile aynı olmalı.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_backgrounds import Painter, H  # noqa: E402
from make_sprites import write_png  # noqa: E402
import pngio  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PIXELLAB_DIR = os.path.join(ROOT, "assets", "pixellab", "map")
W, HGT = 480, 270
TOP, BOTTOM = 22, 234          # durum çubuğu ve alt bilgi kartı arası görünen alan
ART_SCALE = 0.42               # 96 px PixelLab binası ~40 px olur
BASE = 12                      # binanın alt kenarı spot merkezinin bu kadar altında (map.gd _door ile uyumlu)

# ---------------------------------------------------------------- Palet (sönük şehir, renkli mekanlar)
GROUND = H("56615d")
GROUND_D = H("4c5652")
ROAD = H("98a09b")
ROAD_EDGE = H("7a827e")
ROAD_LINE = H("c4cac5")
LANE = H("8a8d8a")
GRASS = [H("3c5442"), H("4a6650"), H("58775a"), H("6b8a66")]
TREE = [H("2c4232"), H("3a5640"), H("4c6c4e")]
WATER = [H("1f434c"), H("27535c"), H("33646c"), H("4b7c80")]
SAND = [H("847b62"), H("9a9174"), H("b0a684")]
ROOFS = [H("7f8986"), H("6f7b7d"), H("8a8679"), H("74806f"), H("87857e"), H("68716f")]
WALLS = [H("4d5756"), H("465153"), H("58544a"), H("4b5549"), H("56534d"), H("434b49")]
OUTLINE = H("2f3735")
WIN = H("3a4341")
METRO_RED = H("9e3a3a")


def _shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


# ---------------------------------------------------------------- Gece ışıkları
# Haritayla aynı boyutta ayrı katman (bg_*_lights.png): oyunda gece toplamalı (add) karışımla basılır.
LIGHTS = [None]
LIGHT_RNG = random.Random(42)
WARM = (255, 206, 120)


def light(x, y, c=WARM, a=255):
    L = LIGHTS[0]
    if L is not None and 0 <= x < W and 0 <= y < HGT and L[y][x][3] < a:
        L[y][x] = (c[0], c[1], c[2], a)


def glow(cx, cy, r, a=70, c=WARM):
    for yy in range(-r, r + 1):
        for xx in range(-r, r + 1):
            d = (xx * xx + yy * yy) ** 0.5
            if d <= r:
                light(cx + xx, cy + yy, c, int(a * (1 - d / r) ** 1.5))


def lamp(x, y):
    """Sokak lambası: küçük sarı hale, ortada parlak nokta."""
    glow(x, y, 8, 95)
    light(x, y, (255, 240, 200))


def start_lights():
    LIGHTS[0] = [[(0, 0, 0, 0)] * W for _ in range(HGT)]


def save_lights(name):
    write_png(os.path.join(ROOT, "assets", "backgrounds", name), LIGHTS[0])
    LIGHTS[0] = None


# ---------------------------------------------------------------- Zemin parçaları

def road(p, x, y, w, h, line=True):
    """Cadde: açık gri asfalt, koyu kenar, ortada kesik çizgi."""
    p.fill(x, y, w, h, ROAD)
    if w >= h:
        p.fill(x, y, w, 1, ROAD_EDGE); p.fill(x, y + h - 1, w, 1, ROAD_EDGE)
        if line and h >= 6:
            for k in range(x, x + w, 10):
                p.fill(k, y + h // 2, 5, 1, ROAD_LINE)
        for k in range(x + 8, x + w, 28):
            lamp(k, y)
            lamp(k + 14, y + h - 1)
    else:
        p.fill(x, y, 1, h, ROAD_EDGE); p.fill(x + w - 1, y, 1, h, ROAD_EDGE)
        if line and w >= 6:
            for k in range(y, y + h, 10):
                p.fill(x + w // 2, k, 1, 5, ROAD_LINE)
        for k in range(y + 8, y + h, 28):
            lamp(x, k)
            lamp(x + w - 1, k + 14)


def lane(p, x, y, w, h):
    """Ara sokak: ince, çizgisiz."""
    p.fill(x, y, w, h, LANE)


def highway(p, y, x0=0, x1=W):
    """E-5 (D-100): iki yönlü yol, ortada kırmızı metrobüs yolu ve bariyerler."""
    w = x1 - x0
    p.fill(x0, y, w, 26, ROAD)
    p.fill(x0, y, w, 1, ROAD_EDGE); p.fill(x0, y + 25, w, 1, ROAD_EDGE)
    for k in range(x0, x1, 12):
        p.fill(k, y + 4, 6, 1, ROAD_LINE); p.fill(k + 6, y + 21, 6, 1, ROAD_LINE)
    p.fill(x0, y + 8, w, 1, H("d6d9d4")); p.fill(x0, y + 17, w, 1, H("d6d9d4"))   # bariyer
    p.fill(x0, y + 9, w, 8, METRO_RED); p.fill(x0, y + 9, w, 1, _shade(METRO_RED, 1.2))
    for k in range(x0, x1, 16):
        p.fill(k, y + 13, 8, 1, _shade(METRO_RED, 0.8))
    for k in range(x0 + 6, x1, 24):    # bariyer üstü direk lambaları
        glow(k, y + 8, 7, 50, (255, 226, 170)); light(k, y + 8, (255, 245, 215))
        glow(k + 12, y + 17, 7, 50, (255, 226, 170)); light(k + 12, y + 17, (255, 245, 215))


def grass(p, x, y, w, h, seed, trees=0.012):
    p.fill(x, y, w, h, GRASS[1])
    p.speckle(x, y, w, h, [GRASS[0], GRASS[2]], 0.12, seed)
    rng = random.Random(seed)
    for _ in range(int(w * h * trees)):
        tree(p, x + 2 + rng.randrange(max(1, w - 4)), y + 2 + rng.randrange(max(1, h - 4)))


def tree(p, x, y):
    p.set(x + 1, y + 2, TREE[0]); p.set(x + 2, y + 2, TREE[0]); p.set(x + 2, y + 1, TREE[0])
    p.fill(x - 1, y - 1, 3, 3, TREE[1]); p.set(x, y - 2, TREE[1]); p.set(x - 2, y, TREE[1])
    p.set(x - 1, y - 1, TREE[2]); p.set(x, y - 1, TREE[2])


def big_tree(p, x, y):
    """Kampüs ağacı: yere gölge, yuvarlak taç, sol üstte ışık."""
    p.darken(x - 1, y + 2, 6, 2, 0.7)
    p.circle(x, y, 3, TREE[0]); p.circle(x - 1, y - 1, 2, TREE[2])
    p.set(x - 2, y - 2, GRASS[3]); p.set(x - 1, y - 3, GRASS[3])


def water(p, x, y, w, h, seed):
    p.fill(x, y, w, h, WATER[1])
    rng = random.Random(seed)
    for _ in range(int(w * h * 0.01)):
        wx, wy = x + rng.randrange(w), y + rng.randrange(h)
        p.fill(wx, wy, 3 + rng.randrange(4), 1, WATER[2])


def lake(p, cx, cy, rx, ry, seed):
    rng = random.Random(seed)
    for yy in range(-ry - 1, ry + 2):
        for xx in range(-rx - 1, rx + 2):
            d = (xx / rx) ** 2 + (yy / ry) ** 2
            if d <= 1.0:
                p.set(cx + xx, cy + yy, WATER[1] if rng.random() > 0.04 else WATER[2])
            elif d <= 1.25:
                p.set(cx + xx, cy + yy, SAND[0])


def coast(p, y, seed):
    """Marmara kıyısı: dalgalı kumsal, altta deniz."""
    rng = random.Random(seed)
    edge = y
    for x in range(W):
        edge += rng.choice((-1, 0, 0, 1))
        edge = max(y - 3, min(y + 3, edge))
        p.fill(x, edge, 1, 4, SAND[1]); p.set(x, edge, SAND[2])
        p.fill(x, edge + 4, 1, HGT - edge - 4, WATER[1])
        p.set(x, edge + 4, WATER[3])
    for _ in range(140):
        wx, wy = rng.randrange(W), y + 8 + rng.randrange(HGT - y - 8)
        p.fill(wx, wy, 3 + rng.randrange(5), 1, WATER[2])


def tiny_building(p, x, y, w, d, h, rng):
    """Uzaktan küçük bina (3/4): üstte çatı, altta pencere noktalı cephe, sağ-alt gölge."""
    i = rng.randrange(len(ROOFS))
    roof, wall = ROOFS[i], WALLS[i]
    p.darken(x + 1, y + d + h, w, 1, 0.7)
    p.darken(x + w, y + 1, 1, d + h, 0.7)
    p.fill(x, y, w, d, roof)
    p.fill(x, y, w, 1, _shade(roof, 1.15))
    if rng.random() < 0.5 and w > 5 and d > 3:      # çatıda klima / su deposu
        p.set(x + 1 + rng.randrange(w - 2), y + 1 + rng.randrange(d - 2), _shade(roof, 0.75))
    p.fill(x, y + d, w, h, wall)
    p.fill(x, y + d, w, 1, _shade(wall, 0.8))
    for wy in range(y + d + 1, y + d + h - 1, 2):
        for wx in range(x + 1, x + w - 1, 2):
            if rng.random() < 0.7:
                p.set(wx, wy, WIN)
                if LIGHT_RNG.random() < 0.32:
                    light(wx, wy, WARM if LIGHT_RNG.random() < 0.85 else (150, 190, 255))
    p.fill(x - 0, y, 1, d + h, _shade(roof, 0.92))


def fill_block(p, x, y, w, h, seed):
    """Şehir bloğu: sıra sıra küçük binalar, aralarda boşluk/avlu."""
    rng = random.Random(seed)
    p.fill(x, y, w, h, GROUND_D)
    by = y + 1
    while by < y + h - 6:
        d = rng.randint(3, 6)
        bh = rng.randint(2, 5)
        if by + d + bh > y + h - 1:
            break
        bx = x + 1
        while bx < x + w - 4:
            bw = rng.randint(5, 13)
            if bx + bw > x + w - 1:
                bw = x + w - 1 - bx
                if bw < 4:
                    break
            if rng.random() < 0.88:
                tiny_building(p, bx, by, bw, d, bh, rng)
            elif rng.random() < 0.5:
                tree(p, bx + bw // 2, by + d)
            bx += bw + rng.randint(1, 2)
        by += d + bh + rng.randint(1, 2)


def parking(p, cx, cy):
    x, y, w, h = cx - 18, cy - 10, 36, 22
    p.fill(x, y, w, h, H("4a5250")); p.fill(x, y, w, 1, ROAD_EDGE)
    for k in range(x + 3, x + w, 6):
        p.fill(k, y + 2, 1, 6, ROAD_LINE); p.fill(k, y + h - 8, 1, 6, ROAD_LINE)
    p.fill(x + w - 7, y + 2, 5, 5, H("2d4e8c")); p.fill(x + w - 6, y + 3, 1, 3, (255, 255, 255)); p.set(x + w - 5, y + 3, (255, 255, 255))


def plot(p, cx, cy, w=46, h=30):
    """Mekanın arsası: açık kaldırım taşı zemin."""
    p.fill(cx - w // 2, cy + BASE - h + 4, w, h, H("6c7470"))
    p.fill(cx - w // 2, cy + BASE - h + 4, w, 1, H("7d8581"))


# ---------------------------------------------------------------- PixelLab çizimini küçültüp basma

def load_art(name):
    path = os.path.join(PIXELLAB_DIR, name + ".png")
    if not os.path.exists(path):
        return None
    px = pngio.read_png(path)
    ys = [y for y, row in enumerate(px) if any(c[3] > 40 for c in row)]
    xs = [x for x in range(len(px[0])) if any(px[y][x][3] > 40 for y in range(len(px)))]
    return [row[xs[0]:xs[-1] + 1] for row in px[ys[0]:ys[-1] + 1]]


def shrink(px, s):
    """Pixel art küçültme: her hedef piksel kaynak bloğundaki en sık rengi alır (renkler bulanmaz)."""
    sh, sw = len(px), len(px[0])
    th, tw = max(1, round(sh * s)), max(1, round(sw * s))
    out = []
    for ty in range(th):
        y0, y1 = int(ty / s), max(int(ty / s) + 1, int((ty + 1) / s))
        row = []
        for tx in range(tw):
            x0, x1 = int(tx / s), max(int(tx / s) + 1, int((tx + 1) / s))
            count, opaque = {}, 0
            for yy in range(y0, min(y1, sh)):
                for xx in range(x0, min(x1, sw)):
                    c = px[yy][xx]
                    if c[3] > 40:
                        opaque += 1
                        k = (c[0] // 8, c[1] // 8, c[2] // 8)
                        count[k] = count.get(k, (0, c))
                        count[k] = (count[k][0] + 1, c)
            total = (min(y1, sh) - y0) * (min(x1, sw) - x0)
            if opaque * 2 >= total and count:
                row.append(max(count.values(), key=lambda v: v[0])[1][:3] + (255,))
            else:
                row.append((0, 0, 0, 0))
        out.append(row)
    return out


def blit_art(p, px, cx, bottom, outline=True, lit=True):
    """Çizimi alt-orta hizalı basar, dışına ince koyu kontur ve yere gölge."""
    h, w = len(px), len(px[0])
    ox, oy = cx - w // 2, bottom - h
    for k in range(3):
        p.darken(ox + 3 + k, bottom - 2 + k, w - 3, 1, 0.75, dither=k == 2)
    if outline:
        for y in range(-1, h + 1):
            for x in range(-1, w + 1):
                inside = 0 <= y < h and 0 <= x < w and px[y][x][3]
                if inside:
                    continue
                near = any(0 <= y + dy < h and 0 <= x + dx < w and px[y + dy][x + dx][3]
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    p.set(ox + x, oy + y, OUTLINE)
    for y in range(h):
        for x in range(w):
            if px[y][x][3]:
                p.set(ox + x, oy + y, px[y][x][:3])
                r, g, b = px[y][x][:3]
                glass = b > r + 30 and b >= g and r + g + b < 520    # mavi camlar (duvarlar değil)
                if lit and glass and y > h // 4 and LIGHT_RNG.random() < 0.75:
                    light(ox + x, oy + y, (255, 196, 110), 190)
    if lit:
        glow(cx, bottom - 1, max(10, w // 3), 80)
    return oy


TOPS = {}


def place(p, map_id, spot, art, cx, cy, scale=ART_SCALE):
    """Mekan çizimi: alt kenarı cy + BASE. Etiket için tepe yüksekliği kaydedilir."""
    px = load_art(art)
    if px is None:
        p.fill(cx - 14, cy - 10, 28, 22, ROOFS[0])
        top = cy - 10
    else:
        top = blit_art(p, shrink(px, scale), cx, cy + BASE)
    if spot:
        TOPS.setdefault(map_id, {})[spot] = top - cy


# ---------------------------------------------------------------- Beylikdüzü

MAHALLE = {   # data/places.gd MAPS["mahalle"]["spots"] ile aynı
    "ev": (64, 108), "market": (186, 114), "gym": (372, 104), "carsi": (212, 176),
    "galeri": (424, 178), "otopark": (338, 180), "durak": (250, 74),
}


def city_map():
    start_lights()
    p = Painter(W, HGT)
    p.fill(0, 0, W, HGT, GROUND)
    # cadde ızgarası: E-5, iki ana cadde, bir yatay cadde, sahil yolu
    vx = [(132, 8), (296, 8)]
    hy = (134, 8)
    coast_y = 212
    # bloklar (ara sokaklarla bölünmüş)
    xs = [(0, 132), (140, 296), (304, W)]
    ys = [(64, 134), (142, 204)]
    seed = 1
    for (x0, x1) in xs:
        for (y0, y1) in ys:
            # ara sokaklar ~40 px'de bir
            sx = x0
            while sx < x1:
                ex = min(x1, sx + random.Random(seed).randint(34, 48))
                if x1 - ex < 20:
                    ex = x1
                fill_block(p, sx + 2, y0 + 2, ex - sx - 4, y1 - y0 - 4, seed)
                if ex < x1:
                    lane(p, ex - 2, y0, 2, y1 - y0)
                sx = ex
                seed += 1
    fill_block(p, 0, TOP, W, 14, 99)                 # E-5'in kuzeyi
    # parklar
    grass(p, 4, 146, 54, 30, 11, 0.03)
    grass(p, 248, 70, 42, 24, 12, 0.03)
    grass(p, 430, 66, 46, 28, 13, 0.03)
    for (vxx, vw) in vx:
        road(p, vxx, 62, vw, coast_y - 62)
    road(p, 0, hy[0], W, hy[1])
    road(p, 0, 204, W, 7, line=False)                # sahil yolu
    highway(p, 36)
    coast(p, coast_y, 3)
    # mekan arsaları ve çizimleri
    for name in ("ev", "market", "gym", "carsi", "galeri"):
        cx, cy = MAHALLE[name]
        plot(p, cx, cy)
    plot(p, *MAHALLE["otopark"], w=40, h=26)
    parking(p, *MAHALLE["otopark"])
    for name in ("ev", "market", "gym", "carsi", "galeri"):
        place(p, "mahalle", name, name, *MAHALLE[name])
    # durak (E-5 kenarında) ve hatta bekleyen metrobüs
    place(p, "mahalle", "durak", "durak", *MAHALLE["durak"], scale=0.36)
    bus = load_art("metrobus")
    if bus:
        _bus(p, bus, 330)
    p.save("bg_map.png")
    save_lights("bg_map_lights.png")


# ---------------------------------------------------------------- YTÜ Davutpaşa

KAMPUS = {   # data/places.gd MAPS["kampus"]["spots"] ile aynı
    "giris": (60, 74), "eef": (110, 124), "mak": (246, 112), "fen": (392, 126),
    "yemekhane": (330, 190), "kampus_kafe": (196, 190), "otopark": (446, 92),
}


def _bus(p, bus, cx):
    """Hatta bekleyen metrobüs; gece camları yanar, önde farlar."""
    small = shrink(bus, 0.4)
    blit_art(p, small, cx, 56)
    fx = cx + len(small[0]) // 2
    glow(fx + 3, 52, 8, 90, (255, 248, 225))


def campus_map():
    start_lights()
    p = Painter(W, HGT)
    p.fill(0, 0, W, HGT, GROUND)
    fill_block(p, 0, TOP, W, 14, 77)
    highway(p, 36)
    # kampüs: duvarla çevrili yeşil alan
    grass(p, 0, 66, W, HGT - 66, 21, 0.0)
    p.fill(0, 64, W, 2, H("8a7f6a")); p.fill(0, 64, W, 1, H("a89c84"))      # kampüs duvarı
    # yürüyüş yolları
    walk = H("a49c86")
    p.fill(0, 152, W, 6, walk); p.fill(0, 152, W, 1, H("b8b09a"))
    for name in ("eef", "mak", "fen", "yemekhane", "kampus_kafe"):
        cx, cy = KAMPUS[name]
        y0, y1 = sorted((cy + BASE, 155))
        p.fill(cx - 2, y0, 4, y1 - y0, walk)
    p.fill(58, 66, 4, 88, walk)                       # girişten ana yola
    p.fill(440, 104, 4, 50, walk)
    lake(p, 120, 200, 34, 14, 5)                      # gölet
    # ağaçlar (bina ve yollardan uzak)
    rng = random.Random(9)
    for _ in range(260):
        x, y = rng.randrange(4, W - 4), rng.randrange(70, 230)
        if 148 < y < 162 or any(abs(x - sx) < 28 and -36 < y - sy < 20 for sx, sy in KAMPUS.values()) \
                or ((x - 120) / 40) ** 2 + ((y - 200) / 19) ** 2 < 1 or (54 < x < 66) or (430 < x < 470 and y < 162):
            continue
        big_tree(p, x, y)
    parking(p, *KAMPUS["otopark"])
    place(p, "kampus", "giris", "durak", *KAMPUS["giris"], scale=0.36)
    for name in ("eef", "mak", "fen", "yemekhane", "kampus_kafe"):
        place(p, "kampus", name, name, *KAMPUS[name])
    place(p, "kampus", "", "kisla", 430, 206)        # tarihi kışla (süs)
    bus = load_art("metrobus")
    if bus:
        _bus(p, bus, 300)
    for x in range(20, W, 40):                         # yol lambaları
        lamp(x, 151)
    for y in range(76, 150, 24):
        lamp(57, y)
    p.save("bg_campus.png")
    save_lights("bg_campus_lights.png")


def write_map_art():
    """Etiket yükseklikleri: data/map_art.gd (elle düzenlenmez)."""
    lines = ["## tools/make_citymap.py üretir. Haritada binanın tepesi (spot merkezine göre y); isim etiketi buraya konur.", "",
             "const TOPS := {"]
    for m, tops in TOPS.items():
        lines.append('\t"%s": {%s},' % (m, ", ".join('"%s": %d' % (k, v) for k, v in tops.items())))
    lines.append("}")
    with open(os.path.join(ROOT, "data", "map_art.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    city_map()
    campus_map()
    write_map_art()


if __name__ == "__main__":
    main()
