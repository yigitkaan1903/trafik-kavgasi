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

def _bus(p, bus, cx):
    """Hatta bekleyen metrobüs; gece camları yanar, önde farlar."""
    small = shrink(bus, 0.4)
    blit_art(p, small, cx, 56)
    fx = cx + len(small[0]) // 2
    glow(fx + 3, 52, 8, 90, (255, 248, 225))


KAMPUS = {   # data/places.gd MAPS["kampus"]["spots"] ile aynı
    "giris": (400, 210), "eef": (250, 78), "mak": (390, 140), "fen": (318, 104),
    "yemekhane": (56, 82), "kampus_kafe": (190, 210), "otopark": (300, 203),
}
# YTÜ kampüs haritası renkleri (canlı yeşil, koyu asfalt, açık gri ızgaralı dış zemin)
C_OUT, C_OUT_LINE = H("e7e4dd"), H("d8d4ca")
C_GRASS = [H("6db044"), H("7cbf4f"), H("8fcc5e")]
C_FOREST = H("2f6b37")
C_TREE = [H("2b6630"), H("3d8b3a"), H("69b54f")]
C_ASPH, C_ASPH_EDGE = H("3f434a"), H("e9e9e6")
C_PATH = H("ecdcae")
C_ROOF, C_ROOF_L, C_ROOF_D = H("c4553b"), H("dc7553"), H("943b28")
C_CREAM, C_CREAM_D, C_WIN = H("f0e2c0"), H("d2be96"), H("5b6f86")


def band_top(x):
    """Sağ üstten çapraz geçen metrobüs hattının üst kenarı."""
    return 22 + (x - 290) * 0.5


def campus_edge(x):
    return max(26, int(band_top(x)) + 26)


def thick_line(p, pts, w, c):
    """Kalın çoklu çizgi (kare fırçayla)."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x, y = round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)
            p.fill(x - w // 2, y - w // 2, w, w, c)


def campus_road(p, pts):
    thick_line(p, pts, 9, C_ASPH_EDGE)
    thick_line(p, pts, 7, C_ASPH)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):   # lambalar
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(0, n, 26):
            lamp(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n) - 5)


def bright_tree(p, x, y):
    p.darken(x - 2, y + 2, 7, 2, 0.75)
    p.circle(x, y, 3, C_TREE[0]); p.circle(x - 1, y - 1, 2, C_TREE[1])
    p.set(x - 2, y - 2, C_TREE[2]); p.set(x - 1, y - 3, C_TREE[2]); p.set(x - 3, y - 1, C_TREE[2])


def ellipse(p, cx, cy, rx, ry, c):
    for yy in range(-ry, ry + 1):
        for xx in range(-rx, rx + 1):
            if (xx / rx) ** 2 + (yy / ry) ** 2 <= 1.0:
                p.set(cx + xx, cy + yy, c)


def curve_path(p, pts, w=2):
    """Parktaki kıvrımlı yürüyüş yolu: noktalar arasından yumuşak (Catmull-Rom) geçer."""
    ext = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(24):
            t = k / 24
            pt = [0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                         + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)]
            p.fill(round(pt[0]), round(pt[1]), w, w, C_PATH)


def tasbina(p, cx, cy):
    """Taşbina (tarihi Davutpaşa Kışlası, rektörlük): kiremit çatılı kare bina, ortada avlu, önde cephe ve kule."""
    w, d, wing, fh = 104, 46, 12, 9
    x0, y0 = cx - w // 2, cy - d // 2 - 4
    p.darken(x0 + 3, y0 + d + fh, w, 3, 0.7)
    p.darken(x0 + w, y0 + 3, 3, d + fh, 0.7)
    # çatı halkası
    p.fill(x0, y0, w, d, C_ROOF)
    p.fill(x0, y0, w, 1, C_ROOF_L)
    for (rx, ry, rw, rh, vertical) in ((x0, y0, w, wing, False), (x0, y0 + d - wing, w, wing, False),
                                       (x0, y0, wing, d, True), (x0 + w - wing, y0, wing, d, True)):
        if vertical:
            p.fill(rx + rw // 2, ry + 1, 1, rh - 2, C_ROOF_L)
        else:
            p.fill(rx + 1, ry + rh // 2, rw - 2, 1, C_ROOF_L)
    # avlu: çim, çapraz yollar, içerideki kuzey kanadın cephesi
    ax, ay, aw, ah = x0 + wing, y0 + wing, w - 2 * wing, d - 2 * wing
    p.fill(ax, ay, aw, ah, C_GRASS[1])
    p.fill(ax, ay, aw, 5, C_CREAM)
    for wx in range(ax + 2, ax + aw - 2, 4):
        p.fill(wx, ay + 1, 2, 3, C_WIN)
        light(wx, ay + 2) if LIGHT_RNG.random() < 0.5 else None
    for k in range(0, max(aw, ah)):
        for (px_, py_) in ((ax + k, ay + 5 + k * (ah - 5) // max(aw, 1)), (ax + aw - 1 - k, ay + 5 + k * (ah - 5) // max(aw, 1))):
            if ax <= px_ < ax + aw and ay + 5 <= py_ < ay + ah:
                p.set(px_, py_, C_PATH)
    p.fill(ax, ay + 5 + (ah - 5) // 2, aw, 1, C_PATH)
    p.fill(ax + aw // 2, ay + 5, 1, ah - 5, C_PATH)
    p.fill(x0 + wing - 1, y0 + d - wing - 1, w - 2 * wing + 2, 1, C_ROOF_D)
    # ön cephe: pencere sıraları, ortada kemerli giriş
    fy = y0 + d
    p.fill(x0, fy, w, fh, C_CREAM)
    p.fill(x0, fy, w, 1, C_ROOF_D)
    p.fill(x0, fy + fh - 1, w, 1, C_CREAM_D)
    for wx in range(x0 + 3, x0 + w - 3, 5):
        if abs(wx - cx) < 5:
            continue
        for wy in (fy + 2, fy + 5):
            p.fill(wx, wy, 2, 2, C_WIN)
            if LIGHT_RNG.random() < 0.45:
                light(wx, wy, a=220); light(wx + 1, wy, a=220)
    p.fill(cx - 3, fy + 2, 6, fh - 2, H("4a3a2e")); p.fill(cx - 2, fy + 1, 4, 1, H("4a3a2e"))
    glow(cx, fy + fh, 10, 70)
    # köşe köşkleri ve saat kulesi
    for kx in (x0 - 2, x0 + w - 12):
        p.fill(kx, y0 - 3, 14, 6, C_ROOF_D); p.fill(kx, y0 - 3, 14, 1, C_ROOF_L)
    tx = x0 + w - 30
    p.fill(tx, y0 - 14, 8, 14, C_CREAM); p.fill(tx, y0 - 14, 8, 1, C_CREAM_D)
    p.fill(tx - 1, y0 - 17, 10, 3, C_ROOF); p.fill(tx + 3, y0 - 19, 2, 2, C_ROOF_D)
    p.set(tx + 3, y0 - 10, C_WIN); p.set(tx + 4, y0 - 10, C_WIN)


def stadium(p, cx, cy):
    """YTÜ Stadyumu: kırmızı koşu pisti, çizgili çim saha."""
    p.darken(cx - 30, cy + 15, 62, 3, 0.75)
    ellipse(p, cx, cy, 31, 17, C_ASPH_EDGE)
    ellipse(p, cx, cy, 30, 16, H("c65a3e"))
    for k in (3, 6):
        for a in range(0, 360, 3):
            import math
            x = round(cx + (30 - k) * math.cos(math.radians(a)))
            y = round(cy + (16 - k * 0.55) * math.sin(math.radians(a)))
            p.set(x, y, H("e88a6a"))
    ellipse(p, cx, cy, 21, 10, H("5fae46"))
    for x in range(cx - 18, cx + 19, 6):
        p.fill(x, cy - 8, 3, 17, H("6cbb52"))
    p.fill(cx - 15, cy - 6, 30, 1, WHITE_L); p.fill(cx - 15, cy + 6, 30, 1, WHITE_L)
    p.fill(cx - 15, cy - 6, 1, 13, WHITE_L); p.fill(cx + 14, cy - 6, 1, 13, WHITE_L)
    p.fill(cx, cy - 6, 1, 13, WHITE_L)
    for a in range(0, 360, 20):   # projektörler
        pass
    glow(cx - 28, cy - 14, 12, 60, (255, 250, 230)); glow(cx + 28, cy - 14, 12, 60, (255, 250, 230))


WHITE_L = H("f4f2ec")


def metro_band(p):
    """Sağ üstteki çapraz hat: gri platform, kırmızı metrobüs yolu, istasyon ve M tabelası."""
    for x in range(250, W):
        t = int(band_top(x))
        for y in range(max(TOP, t), t + 24):
            k = y - t
            if k < 2 or k > 21:
                c = H("bfc0c4")
            elif 8 <= k <= 15:
                c = H("b03a3a") if k not in (8, 15) else H("f2f2f2")
            else:
                c = H("d6d7da")
            p.set(x, y, c)
        if x % 24 == 0:
            p.set(x, int(band_top(x)) + 11, H("f2f2f2")); p.set(x + 1, int(band_top(x)) + 11, H("f2f2f2"))
        if x % 22 == 0:
            glow(x, int(band_top(x)) + 4, 6, 55)
    # Davutpaşa-YTÜ istasyonu: çatılı peron
    for x in range(392, 436):
        t = int(band_top(x))
        p.fill(x, t - 4, 1, 4, H("8a8f99"))
        p.set(x, t - 5, H("e6e7ea"))
        light(x, t - 2, a=120)
    # M tabelası (kırmızı iğne)
    mx, my = 380, int(band_top(380)) - 10
    p.circle(mx, my, 5, H("1b2a52")); p.circle(mx, my, 4, H("c8102e"))
    for (dx, dy) in ((-2, 2), (-2, 1), (-2, 0), (-2, -1), (-1, -1), (0, 0), (1, -1), (2, -1), (2, 0), (2, 1), (2, 2)):
        p.set(mx + dx, my + dy, (255, 255, 255))
    p.fill(mx, my + 5, 1, 4, H("1b2a52"))


def campus_map():
    start_lights()
    p = Painter(W, HGT)
    # dış zemin: açık gri izometrik ızgara
    p.fill(0, 0, W, HGT, C_OUT)
    for y in range(HGT):
        for x in range(W):
            if (x + 2 * y) % 24 == 0 or (x - 2 * y) % 24 == 0:
                p.set(x, y, C_OUT_LINE)
    # kampüs alanı: canlı yeşil, kenarı koyu orman
    rng = random.Random(21)
    for x in range(W):
        e = campus_edge(x)
        for y in range(e, HGT):
            p.set(x, y, C_GRASS[1] if rng.random() > 0.12 else C_GRASS[rng.choice((0, 2))])
        for y in range(e, e + 3):
            p.set(x, y, C_FOREST)
    metro_band(p)
    # yollar: dış halka, içte bir dikey ve bir yatay yol, A kapısından çıkış
    ring = [(12, 40), (258, 40), (452, 137), (452, 228), (12, 228), (12, 40)]
    campus_road(p, ring)
    campus_road(p, [(100, 40), (100, 228)])
    campus_road(p, [(100, 178), (452, 178)])
    campus_road(p, [(452, 160), (W + 4, 160)])
    for gx in (460, 470):                              # A kapısı
        p.fill(gx, 151, 4, 9, H("c9ccd2")); p.fill(gx, 151, 4, 1, (255, 255, 255))
    p.fill(458, 149, 18, 3, H("1b2a52")); p.fill(462, 150, 10, 1, GOLD_L)
    # park: gölet ve kıvrımlı yollar (Taşbina ile fakülteler arası)
    curve_path(p, [(205, 128), (226, 150), (248, 132), (276, 128), (292, 150), (270, 168), (236, 166), (226, 150)])
    curve_path(p, [(160, 140), (190, 158), (226, 150)])
    ellipse(p, 262, 146, 14, 7, H("d9eef6")); ellipse(p, 262, 146, 12, 5, H("6fbde3"))
    p.fill(256, 144, 5, 1, H("a8dcf2"))
    stadium(p, 56, 152)
    # ağaçlar: kenar ormanı sık, içeride serpiştirilmiş (bina, yol, park dışında)
    blocked = [(56, 82, 26, 26), (165, 108, 60, 36), (250, 78, 24, 26), (318, 104, 24, 26), (390, 140, 24, 26),
               (190, 210, 22, 24), (300, 203, 22, 14), (400, 210, 18, 14), (56, 152, 34, 20), (262, 148, 34, 24)]
    trees = random.Random(33)
    spots = [(trees.randrange(2, W - 2), trees.randrange(TOP + 4, 232)) for _ in range(1600)]
    for (cx, cy) in [(195, 58), (70, 205), (36, 112), (140, 200), (250, 205), (352, 215), (430, 168), (340, 150),
                     (130, 160), (420, 200), (300, 140), (225, 100)]:   # orman kümeleri
        spots += [(cx + trees.randint(-14, 14), cy + trees.randint(-9, 9)) for _ in range(26)]
    for x, y in spots:
        if not (2 <= x < W - 2 and TOP + 4 <= y < 232):
            continue
        if y < campus_edge(x) + 3:
            continue
        if any(abs(x - bx) < bw and abs(y - by) < bh for bx, by, bw, bh in blocked):
            continue
        if p.px[y][x][:3] in (C_ASPH, C_ASPH_EDGE, C_PATH) or p.px[y + 3][x][:3] in (C_ASPH, C_ASPH_EDGE) \
                or p.px[y - 3][x][:3] in (C_ASPH, C_ASPH_EDGE):
            continue
        edge = x < 10 or y > 224 or x > 456 or y < campus_edge(x) + 14 or (y < 38)
        if edge or trees.random() < 0.3 or (x, y) in spots[1600:]:
            bright_tree(p, x, y)
    tasbina(p, 165, 108)
    parking(p, *KAMPUS["otopark"])
    place(p, "kampus", "giris", "durak", *KAMPUS["giris"], scale=0.36)
    for name in ("eef", "mak", "fen", "yemekhane", "kampus_kafe"):
        place(p, "kampus", name, name, *KAMPUS[name])
    p.save("bg_campus.png")
    save_lights("bg_campus_lights.png")


GOLD_L = H("e6b428")


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
