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
    p = Painter(480, 270)
    p.fill(0, 0, 480, 270, GREEN[3])
    p.speckle(0, 0, 480, 270, [GREEN[2], GREEN[4]], 0.07, 1)
    for (x, y, w, h) in [(20, 30, 40, 30), (420, 30, 50, 40), (10, 220, 60, 40), (180, 220, 50, 30)]:
        p.fill(x, y, w, h, GREEN[2])
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
    p.fill(102, 212, 318, 10, STONE[3]); p.fill(102, 214, 318, 6, RED[2]); p.fill(102, 216, 318, 1, RED[4])
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
        map_building(p, cx, cy, ramp)
    # durak
    x, y = 70, 176
    p.fill(x, y + 12, 64, 4, STONE[1]); p.fill(x + 4, y + 16, 3, 22, STONE[3]); p.fill(x + 57, y + 16, 3, 22, STONE[3])
    p.fill(x + 18, y + 20, 28, 12, RED[3]); p.fill(x + 22, y + 22, 20, 4, SKY[3])
    p.save("bg_map.png")


def parking_lot(p, cx, cy):
    """Haritada otopark: asfalt, beyaz park çizgileri (araban varsa oyun üstüne çizer)."""
    x, y, w, h = cx - 30, cy - 18, 60, 36
    p.darken(x + 2, y + 2, w, h, 0.65)
    p.fill(x, y, w, h, STONE[1]); p.fill(x, y, w, 1, STONE[3])
    for k in range(x + 4, x + w, 14):
        p.fill(k, y + 3, 1, 12, WHITE); p.fill(k, y + h - 15, 1, 12, WHITE)
    p.fill(x + w - 12, y + 2, 9, 9, NAVY[3]); p.fill(x + w - 10, y + 4, 2, 5, WHITE); p.fill(x + w - 8, y + 4, 2, 2, WHITE)


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
    p.fill(54, 222, 32, 14, CREAM[1]); p.fill(58, 226, 24, 10, STONE[2])
    # metrobüs durağı (kapının yanında)
    p.fill(36, 184, 64, 4, STONE[1]); p.fill(40, 188, 3, 22, STONE[3]); p.fill(93, 188, 3, 22, STONE[3])
    p.fill(54, 192, 28, 12, RED[3]); p.fill(58, 194, 20, 4, SKY[3])
    parking_lot(p, 446, 52)
    # tarihi kışla (süs)
    p.fill(420, 176, 54, 34, GOLD[1]); p.fill(418, 172, 58, 5, RED[1])
    for ax in range(424, 470, 10):
        p.fill(ax, 188, 6, 14, BLACK); p.fill(ax + 1, 186, 4, 2, BLACK)
    # ağaçlar
    rng = random.Random(9)
    for _ in range(40):
        x, y = rng.randrange(8, 472), rng.randrange(20, 224)
        if any(abs(x - sx) < 42 and abs(y - sy) < 32 for (sx, sy), _ in CAMPUS_SPOTS.values()) or 132 < y < 148 or (x > 405 and y < 80) \
                or (140 < x < 200 and 88 < y < 122) or (30 < x < 110 and y > 175):
            continue
        p.circle(x, y + 2, 5, GREEN[0]); p.circle(x, y, 5, GREEN[1]); p.circle(x - 1, y - 1, 3, GREEN[2]); p.set(x - 2, y - 2, GREEN[4])
    for name, ((cx, cy), ramp) in CAMPUS_SPOTS.items():
        map_building(p, cx, cy, ramp)
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


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in (city_map, campus_map, ui):
        f()
    print("Arka planlar üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
