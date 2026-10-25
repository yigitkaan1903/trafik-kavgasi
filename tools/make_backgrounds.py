"""Arayüz görselleri (9 parçalı panel/buton çerçeveleri) ve Painter/palet; haritaları tools/make_citymap.py çizer.

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
    ui()
    import make_citymap   # haritalar (Punch Club tarzı uzaktan şehir)
    make_citymap.main()
    print("Arka planlar üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
