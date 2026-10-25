"""Harita ve arayüz görselleri: Beylikdüzü ve kampüs haritaları, 9 parçalı panel/buton çerçeveleri.

Çalıştırma (proje klasöründen):  python tools/make_backgrounds.py
Çıktı: assets/backgrounds/*.png
Mekanların kendisi (3/4 üstten bakış odalar) tools/make_rooms.py ile üretilir; Painter ve palet buradan gelir.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import Canvas, write_png  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "backgrounds")
CLEAR = (0, 0, 0, 0)


def H(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# ---------------------------------------------------------------- Palet (koyudan açığa renk dizileri)
WOOD = [H("2e1d16"), H("4a2f22"), H("6b4530"), H("8d5e3c"), H("b07d50"), H("d0a070")]
CREAM = [H("6e6454"), H("9a8d74"), H("c4b494"), H("ddd0b2"), H("ece2ca"), H("f7f0de")]
STONE = [H("1f2129"), H("2c2f3b"), H("40455a"), H("5c6378"), H("80889c"), H("a8afbf"), H("d2d7e0")]
NAVY = [H("10132a"), H("1b2140"), H("27315e"), H("35457e"), H("4d63a6")]
SKY = [H("4f8fd0"), H("6fa8de"), H("93c2ea"), H("bcdaf2"), H("deedf8")]
DUSK = [H("2b1e4a"), H("5a2e5e"), H("9a4a5a"), H("d8704c"), H("f0a24c"), H("f8d070")]
GREEN = [H("1a3326"), H("2a5236"), H("3f7444"), H("62984f"), H("92bd68")]
RED = [H("3e1520"), H("6e1f2c"), H("9e2c34"), H("c84438"), H("e8745a")]
GOLD = [H("5e3e14"), H("8e611a"), H("c08f26"), H("e6b428"), H("f6d86a")]
TEAL = [H("15323a"), H("1f4e52"), H("33746e"), H("57a08e"), H("9ccfb4")]
WHITE = H("f4f2ec")
BLACK = H("121018")

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


class Painter(Canvas):
    """Canvas + pixel art yardımcıları. Koordinatlar dahil (x0..x1, y0..y1)."""

    def fill(self, x, y, w, h, c):
        if w > 0 and h > 0:
            self.rect(x, y, x + w - 1, y + h - 1, c)

    def clear(self, x, y, w, h):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < self.w and 0 <= yy < self.h:
                    self.px[yy][xx] = CLEAR

    def grad_v(self, x, y, w, h, ramp):
        """Dikey geçiş, renk dizisi boyunca, Bayer dithering ile."""
        n = len(ramp) - 1
        for yy in range(h):
            t = yy / max(1, h - 1) * n
            i = min(int(t), n - 1)
            f = t - i
            for xx in range(w):
                c = ramp[i + 1] if f > (BAYER[(y + yy) % 4][(x + xx) % 4] + 0.5) / 16 else ramp[i]
                self.set(x + xx, y + yy, c)

    def darken(self, x, y, w, h, k=0.75, dither=False):
        """Var olan pikselleri koyulaştırır (gölge). dither=True: yarı yoğunluk."""
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if not (0 <= xx < self.w and 0 <= yy < self.h):
                    continue
                if dither and (xx + yy) % 2:
                    continue
                c = self.px[yy][xx]
                if c[3]:
                    self.px[yy][xx] = (int(c[0] * k), int(c[1] * k), int(c[2] * k * 1.05) if c[2] * k * 1.05 < 255 else 255, 255)

    def speckle(self, x, y, w, h, colors, density, seed):
        rng = random.Random(seed)
        for _ in range(int(w * h * density)):
            self.set(x + rng.randrange(w), y + rng.randrange(h), rng.choice(colors))

    def circle(self, cx, cy, r, c):
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r + r * 0.6:
                    self.set(cx + xx, cy + yy, c)

    def planks(self, x, y, w, h, ramp, board_h=5, seed=1):
        rng = random.Random(seed)
        for row, by in enumerate(range(y, y + h, board_h)):
            base = ramp[2 + (row % 2)]
            self.fill(x, by, w, board_h, base)
            self.fill(x, by, w, 1, ramp[4] if row % 2 else ramp[3])
            self.fill(x, by + board_h - 1, w, 1, ramp[1])
            off = rng.randrange(30)
            for sx in range(x + off, x + w, 34 + rng.randrange(14)):
                self.fill(sx, by, 1, board_h, ramp[1])
            for _ in range(w // 40):
                self.set(x + rng.randrange(w), by + 2, ramp[1])

    def bricks(self, x, y, w, h, ramp, bw=8, bh=4, seed=2):
        rng = random.Random(seed)
        self.fill(x, y, w, h, ramp[0])
        for row, by in enumerate(range(y, y + h, bh)):
            off = (bw // 2) if row % 2 else 0
            for bx in range(x - off, x + w, bw):
                c = ramp[rng.choice([1, 2, 2, 3])]
                self.fill(max(bx, x), by, min(bw - 1, x + w - max(bx, x)) - (0 if bx >= x else 0), bh - 1, c)
                self.set(max(bx, x), by, ramp[min(len(ramp) - 1, 3)])

    def tiles(self, x, y, w, h, a, b, line, size=8):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                tx, ty = (xx - x) // size, (yy - y) // size
                c = a if (tx + ty) % 2 else b
                if (xx - x) % size == 0 or (yy - y) % size == 0:
                    c = line
                self.set(xx, yy, c)

    def window(self, x, y, w, h, frame, glass, mullion=True, transparent=False):
        self.fill(x - 2, y - 2, w + 4, h + 4, frame[0])
        self.fill(x - 1, y - 1, w + 2, h + 2, frame[1])
        if transparent:
            self.clear(x, y, w, h)
        else:
            self.grad_v(x, y, w, h, glass)
            for i in range(0, w + h, 12):   # cam yansıması
                for k in range(3):
                    xx, yy = x + i - k, y
                    for d in range(h):
                        px, py = xx - d // 2, yy + d
                        if x <= px < min(x + w, self.w) and py < min(y + h, self.h) and (d + k) % 5 < 3:
                            c = self.px[py][px]
                            self.px[py][px] = (min(255, c[0] + 18), min(255, c[1] + 18), min(255, c[2] + 18), 255)
        if mullion:
            self.fill(x + w // 2, y, 1, h, frame[1])

    def door(self, x, y, w, h, ramp, knob=GOLD[3]):
        self.fill(x - 1, y - 1, w + 2, h + 1, ramp[0])
        self.fill(x, y, w, h, ramp[2])
        self.fill(x, y, 1, h, ramp[3])
        self.fill(x + 2, y + 3, w - 4, h // 2 - 5, ramp[3])
        self.fill(x + 2, y + h // 2 + 1, w - 4, h // 2 - 5, ramp[3])
        self.fill(x + 3, y + 4, w - 6, h // 2 - 7, ramp[2])
        self.fill(x + 3, y + h // 2 + 2, w - 6, h // 2 - 7, ramp[2])
        self.set(x + w - 3, y + h // 2, knob)
        self.set(x + w - 3, y + h // 2 + 1, GOLD[1])

    def floor_shadow(self, x, y, w):
        self.darken(x, y, w, 2, 0.7)
        self.darken(x - 1, y + 2, w + 2, 1, 0.82, dither=True)

    def save(self, name):
        write_png(os.path.join(OUT, name), self.px)


def city_silhouette(p, x, y0, w, ground, ramp, seed, lit=None):
    rng = random.Random(seed)
    bx = x
    while bx < x + w:
        bw = rng.randint(8, 18)
        top = y0 + rng.randint(0, (ground - y0) // 2)
        p.fill(bx, top, bw, ground - top, ramp[rng.randrange(len(ramp))])
        if lit:
            for wy in range(top + 2, ground - 2, 4):
                for wx in range(bx + 2, bx + bw - 2, 3):
                    if rng.random() < 0.3:
                        p.set(wx, wy, lit)
        bx += bw + rng.randint(0, 3)


# ---------------------------------------------------------------- Harita (tam çözünürlük, 480x270)

MAP_SPOTS = {   # data/places.gd ile aynı konumlar
    "ev": ((78, 92), RED), "market": ((196, 74), GREEN), "gym": ((330, 84), NAVY),
    "galeri": ((400, 186), STONE[2:]), "carsi": ((212, 180), GOLD),
}


def city_map():
    CURRENT_MAP[0] = "mahalle"
    p = Painter(480, 270)
    p.fill(0, 0, 480, 270, GREEN[3])
    p.speckle(0, 0, 480, 270, [GREEN[2], GREEN[4]], 0.07, 1)
    for (x, y, w, h) in [(20, 30, 40, 30), (420, 30, 50, 40), (10, 220, 60, 40), (180, 220, 50, 30)]:
        small_park(p, x, y, w, h)
    # yollar ve kaldırımlar
    def road_h(y):
        p.fill(0, y - 2, 480, 20, STONE[5]); p.fill(0, y, 480, 16, STONE[2])
        for x in range(0, 480, 24):
            p.fill(x, y + 7, 12, 2, CREAM[5])
    def road_v(x):
        p.fill(x - 2, 0, 20, 270, STONE[5]); p.fill(x, 0, 16, 270, STONE[2])
        for y in range(0, 270, 24):
            p.fill(x + 7, y, 2, 12, CREAM[5])
    road_h(132); road_v(140); road_v(278)
    for (x, y) in [(140, 132), (278, 132)]:
        p.fill(x, y, 16, 16, STONE[2])
        for k in range(0, 16, 3):
            p.fill(x - 6, y + k, 4, 2, WHITE); p.fill(x + 18, y + k, 4, 2, WHITE)
    # metrobüs hattı
    p.fill(102, 226, 318, 10, STONE[3]); p.fill(102, 228, 318, 6, RED[2]); p.fill(102, 230, 318, 1, RED[4])
    parking_lot(p, 332, 186)
    # ağaçlar
    rng = random.Random(5)
    for _ in range(26):
        x, y = rng.randrange(8, 472), rng.randrange(20, 262)
        if any(abs(x - sx) < 44 and abs(y - sy) < 34 for (sx, sy), _ in MAP_SPOTS.values()) or 128 < y < 152 \
                or 136 < x < 160 or 274 < x < 298 or 205 < y < 226 or (294 < x < 370 and 160 < y < 212):
            continue
        p.circle(x, y + 2, 5, GREEN[0]); p.circle(x, y, 5, GREEN[1]); p.circle(x - 1, y - 1, 3, GREEN[2]); p.set(x - 2, y - 2, GREEN[4])
    for name, ((cx, cy), ramp) in MAP_SPOTS.items():
        draw_place(p, name, cx, cy, ramp)
    # durak
    if not pixellab_place(p, "durak", 102, 196, "durak"):
        bus_shelter(p, 70, 180)
    pixellab_place(p, "metrobus", 222, 214)      # hatta bekleyen metrobüs
    p.save("bg_map.png")


def parking_lot(p, cx, cy):
    """Haritada otopark: asfalt, beyaz park çizgileri (araban varsa oyun üstüne çizer)."""
    x, y, w, h = cx - 30, cy - 18, 60, 36
    p.darken(x + 2, y + 2, w, h, 0.65)
    p.fill(x, y, w, h, STONE[1]); p.fill(x, y, w, 1, STONE[3])
    for k in range(x + 4, x + w, 14):
        p.fill(k, y + 3, 1, 12, WHITE); p.fill(k, y + h - 15, 1, 12, WHITE)
    p.fill(x + w - 12, y + 2, 9, 9, NAVY[3]); p.fill(x + w - 10, y + 4, 2, 5, WHITE); p.fill(x + w - 8, y + 4, 2, 2, WHITE)


# ---------------------------------------------------------------- Harita binaları (3/4 açı, mekana özel)
# Her bina hover alanına (merkez cx, cy; 64x40) sığar: üstte çatı yüzeyi, altta cephe, sağ altta gölge.

def _shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def _ground_shadow(p, x, y, w, h):
    for k in range(5):   # sağa-aşağı düşen yumuşak gölge
        p.darken(x + 3 + k, y + h + k // 2, w, 1, 0.82, dither=k > 2)
        p.darken(x + w + k // 2, y + 4 + k, 1, h - 4, 0.82, dither=k > 2)


def _windows(p, x, y, cols, rows, ww, wh, gx, gy, frame, glass, sill=None, lit=0.0, seed=1):
    import random as _r
    rng = _r.Random(seed)
    for r in range(rows):
        for c in range(cols):
            wx, wy = x + c * (ww + gx), y + r * (wh + gy)
            p.fill(wx - 1, wy - 1, ww + 2, wh + 2, frame)
            p.fill(wx, wy, ww, wh, glass)
            p.fill(wx, wy, ww, 1, _shade(glass, 1.25))
            if ww >= 4:
                p.fill(wx + ww // 2, wy, 1, wh, frame)
            if lit and rng.random() < lit:
                p.fill(wx, wy + 1, ww, wh - 1, GOLD[4])
            if sill:
                p.fill(wx - 1, wy + wh + 1, ww + 2, 1, sill)


def _pitched_roof(p, x, y, w, d, tile):
    """Kiremit çatı (üstten): mahyaya doğru açılan sıralar, ortada mahya, kenarda saçak."""
    p.fill(x - 2, y, w + 4, d, _shade(tile, 0.85))
    for r in range(d):
        col = tile if (r // 2) % 2 else _shade(tile, 1.12)
        p.fill(x - 2, y + r, w + 4, 1, col)
        for k in range(x - 2 + (r // 2 % 2) * 3, x + w + 2, 6):
            p.set(k, y + r, _shade(tile, 0.75))
    p.fill(x - 2, y + d // 2, w + 4, 1, _shade(tile, 0.6))      # mahya
    p.fill(x - 3, y + d, w + 6, 2, _shade(tile, 0.55))          # saçak gölgesi


def _flat_roof(p, x, y, w, d, base, units=2, seed=3):
    import random as _r
    rng = _r.Random(seed)
    p.fill(x, y, w, d, base)
    p.speckle(x + 1, y + 1, w - 2, d - 2, [_shade(base, 0.9), _shade(base, 1.08)], 0.12, seed)
    p.fill(x, y, w, 1, _shade(base, 1.3)); p.fill(x, y, 1, d, _shade(base, 1.2))      # korkuluk duvarı
    p.fill(x + w - 1, y, 1, d, _shade(base, 0.75)); p.fill(x, y + d - 1, w, 1, _shade(base, 0.7))
    for k in range(units):   # klima / havalandırma kutuları
        ux, uy = x + 4 + rng.randrange(max(1, w - 14)), y + 2 + rng.randrange(max(1, d - 7))
        p.fill(ux, uy, 8, 5, STONE[5]); p.fill(ux, uy, 8, 1, STONE[6]); p.fill(ux + 1, uy + 2, 6, 1, STONE[3])
        p.darken(ux + 8, uy + 1, 1, 5, 0.7)


def bus_shelter(p, x, y):
    """Metrobüs durağı sığınağı (3/4): kırmızı-beyaz çatı, cam arka panel, bank, durak tabelası."""
    _ground_shadow(p, x, y + 6, 64, 24)
    p.fill(x, y, 64, 8, H("c8102e")); p.fill(x, y, 64, 2, H("e83a50")); p.fill(x, y + 7, 64, 1, H("8e0a20"))
    for k in range(x + 4, x + 60, 12):
        p.fill(k, y + 3, 6, 2, WHITE)
    p.fill(x + 2, y + 8, 60, 16, H("a8c4dc")); p.fill(x + 2, y + 8, 60, 1, WHITE)          # cam panel
    for k in range(x + 2, x + 62, 15):
        p.fill(k, y + 8, 2, 22, STONE[1])
    p.fill(x + 6, y + 12, 18, 9, H("e6b428")); p.fill(x + 8, y + 14, 14, 2, H("1b2a52")); p.fill(x + 8, y + 17, 10, 1, H("1b2a52"))  # reklam
    p.fill(x + 30, y + 20, 26, 3, WOOD[3]); p.fill(x + 30, y + 23, 26, 1, WOOD[1])          # bank
    p.fill(x + 32, y + 24, 2, 5, STONE[2]); p.fill(x + 52, y + 24, 2, 5, STONE[2])
    p.fill(x + 61, y - 8, 2, 38, STONE[2])                                                     # tabela direği
    p.circle(x + 62, y - 9, 4, H("c8102e")); p.fill(x + 61, y - 11, 3, 4, WHITE)


def small_park(p, x, y, w, h):
    """Küçük park: koyu çim, kıvrımlı yol, çiçek tarhı, bank."""
    p.fill(x, y, w, h, GREEN[2])
    p.speckle(x, y, w, h, [GREEN[1], GREEN[3]], 0.1, x + y)
    p.fill(x, y + h // 2 - 1, w, 3, CREAM[3]); p.fill(x + w // 2 - 1, y, 3, h, CREAM[3])
    p.fill(x, y + h // 2 - 1, w, 1, CREAM[4])
    p.circle(x + w // 2, y + h // 2, 5, CREAM[3]); p.circle(x + w // 2, y + h // 2, 3, SKY[2])   # süs havuzu
    for (fx, fy) in ((x + 4, y + 4), (x + w - 9, y + h - 8)):
        for k in range(6):
            p.set(fx + k, fy + (k % 2), [RED[4], GOLD[4], WHITE][k % 3])
            p.set(fx + k, fy + 2, GREEN[1])
    p.fill(x + 4, y + h - 6, 10, 2, WOOD[3]); p.fill(x + 5, y + h - 4, 1, 2, STONE[2]); p.fill(x + 12, y + h - 4, 1, 2, STONE[2])


def campus_gate(p, cx, y):
    """Kampüs kapısı: iki taş ayak, üstte kemer ve tabela."""
    p.fill(cx - 22, y - 10, 8, 18, CREAM[1]); p.fill(cx + 14, y - 10, 8, 18, CREAM[1])
    p.fill(cx - 22, y - 10, 8, 2, CREAM[4]); p.fill(cx + 14, y - 10, 8, 2, CREAM[4])
    p.fill(cx - 22, y - 14, 44, 5, H("1b2a52")); p.fill(cx - 22, y - 14, 44, 1, H("4d63a6"))
    p.fill(cx - 12, y - 13, 24, 2, GOLD[3])
    p.fill(cx - 14, y - 9, 28, 1, STONE[2])
    p.darken(cx - 14, y + 8, 40, 3, 0.8, dither=True)


def kisla(p, x, y):
    """Tarihi Davutpaşa Kışlası: kiremit çatı, kum taşı cephe, kemerli pencereler, saat kuleli kapı."""
    w = 58
    _ground_shadow(p, x, y + 10, w, 34)
    _pitched_roof(p, x, y, w, 10, H("a8442e"))
    p.fill(x, y + 12, w, 32, H("d8b888")); p.fill(x, y + 12, w, 1, H("ecd2a4")); p.fill(x, y + 12, 1, 32, H("ecd2a4"))
    p.fill(x, y + 27, w, 1, H("b89868"))
    for ax in list(range(x + 3, x + 22, 6)) + list(range(x + 38, x + w - 3, 6)):    # kemerli pencereler
        for row in (y + 15, y + 30):
            p.fill(ax, row + 2, 4, 7, H("3a2a22")); p.fill(ax + 1, row + 1, 2, 1, H("3a2a22"))
            p.fill(ax, row + 9, 4, 1, H("ecd2a4"))
    tx = x + w // 2 - 7                                                               # saat kulesi ve kapı
    p.fill(tx, y - 8, 14, 52, H("c8a878")); p.fill(tx, y - 8, 14, 2, H("ecd2a4"))
    p.fill(tx - 1, y - 11, 16, 4, H("a8442e")); p.fill(tx + 6, y - 14, 2, 3, GOLD[3])
    p.circle(tx + 7, y + 2, 4, WHITE); p.fill(tx + 7, y - 1, 1, 3, BLACK); p.fill(tx + 7, y + 2, 3, 1, BLACK)
    p.fill(tx + 3, y + 30, 8, 14, H("3a2a22")); p.fill(tx + 4, y + 29, 6, 1, H("3a2a22"))


MAP_TOPS = {}          # harita -> {spot: binanın tepesinin spot merkezine göre y'si} (etiketler için)
CURRENT_MAP = ["mahalle"]
PIXELLAB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pixellab", "map")


def pixellab_place(p, name, cx, cy, spot=""):
    """assets/pixellab/map/<ad>.png varsa onu bas: boş kenarlar kırpılır, alt kenar binanın kapı hizasına
    (cy + 20), ortası cx'e oturur; yere gölge düşer. Yoksa False (kodla çizilen bina kullanılır)."""
    path = os.path.join(PIXELLAB_DIR, name + ".png")
    if not os.path.exists(path):
        return False
    import pngio
    px = pngio.read_png(path)
    ys = [y for y, row in enumerate(px) if any(c[3] > 40 for c in row)]
    xs = [x for x in range(len(px[0])) if any(px[y][x][3] > 40 for y in range(len(px)))]
    if not ys:
        return False
    w, h = xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1
    ox, oy = cx - w // 2, cy + 22 - h
    if spot:
        MAP_TOPS.setdefault(CURRENT_MAP[0], {})[spot] = oy - cy
    _ground_shadow(p, ox + 2, oy + h - 14, w - 4, 12)
    for y in range(h):
        for x in range(w):
            c = px[ys[0] + y][xs[0] + x]
            if c[3] > 40:
                p.set(ox + x, oy + y, c[:3])
    return True


def draw_place(p, name, cx, cy, ramp):
    if pixellab_place(p, name, cx, cy, name):
        return
    x0, y0 = cx - 32, cy - 22
    if name == "ev":   # 4 katlı apartman: kiremit çatı, balkonlar
        x, w = x0 + 4, 56
        _ground_shadow(p, x, y0 + 12, w, 30)
        _pitched_roof(p, x, y0, w, 12, H("b8553a"))
        p.fill(x + w - 12, y0 + 1, 5, 6, H("8a4a3a")); p.fill(x + w - 12, y0, 5, 1, H("6a3a2e"))      # baca
        p.fill(x, y0 + 14, w, 28, H("e8dcc4")); p.fill(x, y0 + 14, 1, 28, H("f6eedc")); p.fill(x + w - 1, y0 + 14, 1, 28, H("c8b89c"))
        for fl in range(3):
            fy = y0 + 16 + fl * 8
            _windows(p, x + 5, fy, 4, 1, 5, 4, 8, 0, H("8a7a62"), SKY[2], seed=fl)
            p.fill(x + 3, fy + 5, 22, 1, STONE[2]); p.fill(x + 31, fy + 5, 22, 1, STONE[2])   # balkon korkuluğu
            for k in range(x + 3, x + 25, 3):
                p.set(k, fy + 4, STONE[3])
        p.fill(cx - 5, y0 + 34, 10, 8, WOOD[1]); p.fill(cx - 4, y0 + 35, 8, 7, WOOD[2]); p.fill(cx - 7, y0 + 33, 14, 1, STONE[3])
        p.fill(x + 2, y0 + 40, 4, 2, GREEN[1]); p.fill(x + w - 6, y0 + 40, 4, 2, GREEN[1])
    elif name == "market":   # tek katlı market: düz çatı, yeşil tente, vitrin
        x, w = x0 + 2, 60
        _ground_shadow(p, x, y0 + 18, w, 22)
        _flat_roof(p, x, y0 + 2, w, 18, STONE[4], 2, 5)
        p.fill(x, y0 + 20, w, 22, H("f0ece2"))
        p.fill(x, y0 + 20, w, 5, GREEN[1]); p.fill(x + 2, y0 + 21, w - 4, 3, GREEN[3])           # tabela bandı
        for k in range(x + 6, x + w - 6, 6):
            p.fill(k, y0 + 22, 3, 1, WHITE)
        for k, sx in enumerate(range(x, x + w, 6)):                                               # tente
            p.fill(sx, y0 + 25, 6, 4, GREEN[2] if k % 2 else WHITE)
        p.fill(x, y0 + 29, w, 1, GREEN[0])
        p.fill(x + 4, y0 + 31, 34, 10, H("2b3a55"))
        for k in range(6):
            p.fill(x + 6 + k * 5, y0 + 34, 3, 6, [RED[3], GOLD[3], GREEN[3], NAVY[4], H("e8745a"), TEAL[3]][k])
        p.fill(x + 44, y0 + 31, 10, 11, H("8fb4cc")); p.fill(x + 48, y0 + 31, 1, 11, STONE[3])
        p.fill(x + 40, y0 + 39, 3, 3, WOOD[2])
    elif name == "gym":   # spor salonu: kemerli metal çatı, cam şerit
        x, w = x0, 64
        _ground_shadow(p, x, y0 + 16, w, 26)
        for r in range(16):   # kemerli çatı: ortası açık, kenarlar koyu
            k = 0.75 + 0.35 * (1 - abs(r - 7.5) / 7.5)
            p.fill(x, y0 + r, w, 1, _shade(H("6e7a92"), k))
        for k in range(x + 2, x + w, 4):
            p.fill(k, y0, 1, 16, _shade(H("6e7a92"), 0.7))
        p.fill(x, y0 + 16, w, 26, NAVY[2]); p.fill(x, y0 + 16, w, 1, NAVY[4])
        p.fill(x + 2, y0 + 19, w - 4, 9, H("9ab0c8"))                                              # cam şerit
        for k in range(x + 2, x + w - 2, 8):
            p.fill(k, y0 + 19, 1, 9, NAVY[1])
        p.fill(x + 14, y0 + 30, 36, 5, GOLD[3]); p.fill(x + 14, y0 + 30, 36, 1, GOLD[4])          # tabela
        p.fill(cx - 6, y0 + 35, 12, 7, H("8fb4cc")); p.fill(cx, y0 + 35, 1, 7, STONE[3])
    elif name == "galeri":   # oto galeri: cam vitrin, içinde arabalar, flamalar
        x, w = x0 + 1, 62
        _ground_shadow(p, x, y0 + 14, w, 28)
        _flat_roof(p, x, y0 + 2, w, 12, STONE[3], 1, 7)
        for k, fx in enumerate(range(x + 2, x + w, 7)):   # flamalar
            p.fill(fx, y0 + 1, 3, 3, [RED[3], GOLD[3], NAVY[4]][k % 3])
        p.fill(x, y0 + 14, w, 28, STONE[2])
        p.fill(x + 2, y0 + 16, w - 4, 4, GOLD[3])
        p.fill(x + 2, y0 + 21, w - 4, 19, H("bcd4e4")); p.fill(x + 2, y0 + 21, w - 4, 1, WHITE)
        for k in range(x + 16, x + w - 2, 15):
            p.fill(k, y0 + 21, 1, 19, STONE[1])
        for k, col in enumerate((H("e2d4a8"), H("2a3e70"), BLACK)):    # vitrindeki arabalar (yandan)
            ax = x + 5 + k * 19
            p.fill(ax, y0 + 33, 14, 4, col); p.fill(ax + 3, y0 + 30, 8, 3, col); p.fill(ax + 4, y0 + 31, 6, 2, SKY[2])
            p.fill(ax + 2, y0 + 37, 3, 2, BLACK); p.fill(ax + 10, y0 + 37, 3, 2, BLACK)
    elif name == "carsi":   # çarşı: renkli tenteli üç dükkan
        _ground_shadow(p, x0, y0 + 14, 64, 28)
        cols = [(H("e2cfa8"), RED[3]), (H("9aa0aa"), NAVY[3]), (H("ecd2da"), H("a04878"))]
        for k, (wall_c, awn) in enumerate(cols):
            x = x0 + k * 21
            _flat_roof(p, x, y0 + 4, 21, 10, _shade(wall_c, 0.7), 1, 11 + k)
            p.fill(x, y0 + 14, 21, 28, wall_c); p.fill(x, y0 + 14, 1, 28, _shade(wall_c, 1.1))
            p.fill(x + 3, y0 + 16, 15, 4, _shade(awn, 0.6))                                         # tabela
            for j, sx in enumerate(range(x, x + 21, 3)):                                            # tente
                p.fill(sx, y0 + 21, 3, 4, awn if j % 2 else WHITE)
            p.fill(x + 3, y0 + 27, 10, 9, H("ffe0a0") if k == 0 else H("cfe7f5"))
            p.fill(x + 14, y0 + 28, 5, 14, WOOD[2] if k != 1 else STONE[3])
        p.fill(x0, y0 + 41, 64, 1, STONE[2])
    else:   # kampüs binaları
        wall, roof = (ramp[2] if len(ramp) > 2 else ramp[0]), (ramp[1] if len(ramp) > 1 else ramp[0])
        if name == "kampus_kafe":   # kafe: ahşap cephe, büyük camlar, terasta şemsiyeler
            x, w = x0 + 4, 50
            _ground_shadow(p, x, y0 + 12, w, 24)
            _pitched_roof(p, x, y0 + 2, w, 10, H("6b4530"))
            p.fill(x, y0 + 14, w, 22, H("b07d50")); p.fill(x, y0 + 14, w, 1, H("d0a070"))
            for k in range(x, x + w, 4):
                p.fill(k, y0 + 14, 1, 22, H("8d5e3c"))
            _windows(p, x + 3, y0 + 18, 3, 1, 10, 10, 4, 0, WOOD[1], H("ffe0a0"))
            p.fill(x + 41, y0 + 18, 6, 18, WOOD[0])
            for k, ux in enumerate((x0 + 4, x0 + 22, x0 + 40)):   # teras şemsiyeleri
                c = [RED[3], GREEN[3], GOLD[3]][k]
                p.circle(ux + 6, y0 + 39, 5, c); p.circle(ux + 6, y0 + 38, 3, _shade(c, 1.2))
        elif name == "yemekhane":   # tuğla yemekhane, büyük pencereler, bacalar
            x, w = x0, 64
            _ground_shadow(p, x, y0 + 14, w, 28)
            _flat_roof(p, x, y0 + 2, w, 12, STONE[3], 3, 13)
            p.fill(x + 50, y0, 4, 5, STONE[2]); p.fill(x + 8, y0, 4, 5, STONE[2])
            p.bricks(x, y0 + 14, w, 28, [RED[0], RED[1], RED[2], RED[3]], 6, 3, seed=4)
            _windows(p, x + 4, y0 + 18, 5, 1, 8, 9, 4, 0, H("f4f2ec"), SKY[2])
            p.fill(cx - 7, y0 + 32, 14, 10, H("8fb4cc")); p.fill(cx, y0 + 32, 1, 10, STONE[3]); p.fill(cx - 9, y0 + 30, 18, 2, STONE[5])
        else:   # fakülteler: 3 katlı blok, pencere ızgarası, sütunlu giriş
            x, w = x0, 64
            _ground_shadow(p, x, y0 + 12, w, 30)
            _flat_roof(p, x, y0 + 1, w, 11, _shade(roof, 1.05), 2, len(name))
            p.fill(x, y0 + 12, w, 30, wall); p.fill(x, y0 + 12, 1, 30, _shade(wall, 1.2)); p.fill(x + w - 1, y0 + 12, 1, 30, _shade(wall, 0.75))
            for fl in range(3):
                p.fill(x, y0 + 21 + fl * 7, w, 1, _shade(wall, 0.85))                                # kat çizgileri
            _windows(p, x + 3, y0 + 14, 9, 3, 4, 4, 3, 3, _shade(wall, 0.6), SKY[3], seed=len(name))
            p.fill(cx - 10, y0 + 33, 20, 2, STONE[6]); p.fill(cx - 10, y0 + 35, 20, 7, _shade(wall, 0.7))    # giriş saçağı
            for k in range(cx - 9, cx + 10, 6):
                p.fill(k, y0 + 35, 2, 7, STONE[6])
            p.fill(cx - 3, y0 + 36, 6, 6, H("8fb4cc"))


def map_building(p, cx, cy, ramp):
    if True:
        x, y, w, h = cx - 32, cy - 20, 64, 40
        p.darken(x + 3, y + 3, w, h, 0.6)
        wall = ramp[2] if len(ramp) > 2 else ramp[0]
        p.fill(x, y + 10, w, h - 10, wall)
        p.fill(x, y + 10, 1, h - 10, ramp[3] if len(ramp) > 3 else ramp[-1])
        p.fill(x - 2, y, w + 4, 11, ramp[1]); p.fill(x - 2, y, w + 4, 2, ramp[3] if len(ramp) > 3 else ramp[-1])
        for wx in range(x + 6, x + w - 8, 12):
            p.fill(wx, y + 15, 7, 7, SKY[3]); p.fill(wx, y + 15, 7, 1, WHITE); p.fill(wx + 3, y + 15, 1, 7, ramp[1])
        p.fill(cx - 5, y + h - 12, 10, 12, BLACK); p.fill(cx - 4, y + h - 11, 8, 11, WOOD[1])


CAMPUS_SPOTS = {   # data/places.gd MAPS["kampus"] ile aynı konumlar
    "eef": ((108, 84), NAVY), "mak": ((254, 66), [H("4a2a20"), H("6b3a2a"), H("7e4632"), H("94563c")]),
    "fen": ((396, 104), TEAL), "yemekhane": ((330, 186), RED), "kampus_kafe": ((196, 176), GOLD),
}


def campus_map():
    CURRENT_MAP[0] = "kampus"
    p = Painter(480, 270)
    p.fill(0, 0, 480, 270, GREEN[3])
    p.speckle(0, 0, 480, 270, [GREEN[2], GREEN[4]], 0.08, 7)
    # yürüyüş yolları (açık taş)
    def path(x0, y0, x1, y1, wdt=10):
        if x0 == x1:
            p.fill(x0 - wdt // 2, min(y0, y1), wdt, abs(y1 - y0), STONE[5])
        else:
            p.fill(min(x0, x1), y0 - wdt // 2, abs(x1 - x0), wdt, STONE[5])
    path(20, 140, 470, 140, 14)
    for (sx, sy) in [(108, 84), (254, 66), (396, 104), (330, 186), (196, 176)]:
        path(sx, sy + 20, sx, 140)
    path(70, 140, 70, 230)
    p.speckle(0, 0, 480, 270, [STONE[4]], 0.0, 1)
    # süs havuzu
    for yy in range(-14, 15):
        for xx in range(-26, 27):
            if (xx / 26) ** 2 + (yy / 14) ** 2 <= 1:
                p.set(170 + xx, 105 + yy, SKY[1] if (xx + yy) % 5 else SKY[3])
    # kampüs duvarı ve kapı
    p.fill(0, 228, 480, 6, CREAM[2]); p.fill(0, 228, 480, 1, CREAM[4])
    has_art = os.path.exists(os.path.join(PIXELLAB_DIR, "durak.png"))
    if not has_art:
        campus_gate(p, 70, 228)
        bus_shelter(p, 38, 184)
    parking_lot(p, 446, 52)
    # tarihi kışla (süs)
    if not os.path.exists(os.path.join(PIXELLAB_DIR, "kisla.png")):
        kisla(p, 418, 168)
    # ağaçlar
    rng = random.Random(9)
    for _ in range(40):
        x, y = rng.randrange(8, 472), rng.randrange(20, 224)
        if any(abs(x - sx) < 42 and abs(y - sy) < 32 for (sx, sy), _ in CAMPUS_SPOTS.values()) or 132 < y < 148 or (x > 405 and y < 80) or (x > 405 and y > 160) \
                or (140 < x < 200 and 88 < y < 122) or (30 < x < 110 and y > 175):
            continue
        p.circle(x, y + 2, 5, GREEN[0]); p.circle(x, y, 5, GREEN[1]); p.circle(x - 1, y - 1, 3, GREEN[2]); p.set(x - 2, y - 2, GREEN[4])
    for name, ((cx, cy), ramp) in CAMPUS_SPOTS.items():
        draw_place(p, name, cx, cy, ramp)
    if has_art:   # PixelLab çizimleri ağaçların üstüne
        pixellab_place(p, "durak", 70, 196, "giris")
        pixellab_place(p, "kisla", 447, 190)
    p.save("bg_campus.png")


# ---------------------------------------------------------------- Arayüz (9 parçalı paneller ve butonlar, 12x12)

def ui_piece(name, fill, top, border, outer=BLACK):
    """Köşeleri yuvarlatılmış pixel çerçeve: dış koyu çizgi, renkli kenar, üstte ışık, içi dolu."""
    p = Painter(12, 12)
    p.fill(1, 0, 10, 12, outer); p.fill(0, 1, 12, 10, outer)
    p.fill(1, 1, 10, 10, border)
    p.fill(2, 2, 8, 8, fill)
    p.fill(2, 2, 8, 1, top)
    p.fill(2, 9, 8, 1, tuple(int(v * 0.75) for v in fill))
    write_png(os.path.join(OUT, name), p.px)


def ui():
    ui_piece("ui_panel.png", H("12142a"), H("1f2442"), GOLD[1])
    ui_piece("ui_button.png", NAVY[2], NAVY[3], GOLD[1])
    ui_piece("ui_button_hover.png", NAVY[3], NAVY[4], GOLD[3])
    ui_piece("ui_button_pressed.png", GOLD[2], GOLD[3], GOLD[4])
    ui_piece("ui_button_disabled.png", STONE[1], STONE[2], STONE[2])
    ui_piece("ui_bubble.png", WHITE, WHITE, BLACK, BLACK)


def write_map_art():
    """Etiket yükseklikleri: data/map_art.gd (elle düzenlenmez)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "map_art.gd")
    lines = ["## tools/make_backgrounds.py üretir. Haritada binanın tepesi (spot merkezine göre y); isim etiketi buraya konur.", "",
             "const TOPS := {"]
    for m, tops in MAP_TOPS.items():
        lines.append('\t"%s": {%s},' % (m, ", ".join('"%s": %d' % (k, v) for k, v in tops.items())))
    lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in (city_map, campus_map, ui):
        f()
    write_map_art()
    print("Arka planlar üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
