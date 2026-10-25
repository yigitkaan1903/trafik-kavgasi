"""3/4 üstten bakış mekanları (Stardew / RPG Maker tarzı).

Çalıştırma (proje klasöründen):  python tools/make_rooms.py
Çıktı:
  assets/rooms/<oda>.png         zemin, duvarlar ve yere yapışık her şey (1x, 16 piksellik karolar)
  assets/rooms/props/<eşya>.png  önünden/arkasından geçilebilen eşyalar (oyunda y'ye göre sıralanır)
  data/rooms_data.gd             eşyaların yeri, çarpışma kutuları, işaretler (elle düzenlenmez)

Koordinatlar piksel. Eşya kaydı: [görsel, sol, üst, taban_y]; taban_y karakterlerle sıralama içindir
(karakterin ayakları tabandan aşağıdaysa karakter önde çizilir).
İşaretler (marks): karakterlerin duracağı noktalar (ayak konumu). Listeler (lists): koltuklar, masalar...
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import shade, write_png  # noqa: E402
from make_backgrounds import (Painter, H, WOOD, CREAM, STONE, NAVY, SKY, GREEN, RED, GOLD, TEAL,  # noqa: E402
                              WHITE, BLACK)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "rooms")
PROP_OUT = os.path.join(OUT, "props")
DATA = os.path.join(ROOT, "data", "rooms_data.gd")

EDGE = H("221c2a")         # odanın dış duvar kesiti (üstten görünen koyu duvar)
EDGE_HI = H("3a3046")
SHADOW = 0.62

PROPS = {}
CANVASES = {}   # önizleme için: oda id -> zemin


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def outlined(c):
    """1 piksel boşluk ekleyip koyu dış çizgi çizer."""
    out = Painter(c.w + 2, c.h + 2)
    for y in range(c.h):
        for x in range(c.w):
            if c.px[y][x][3]:
                out.px[y + 1][x + 1] = c.px[y][x]
    out.outline()
    return out


# ---------------------------------------------------------------- Oda

class Room:
    def __init__(self, rid, w, h, wall_h=56):
        self.id, self.W, self.H, self.wall_h = rid, w, h, wall_h
        self.c = Painter(w, h)
        self.props, self.solids, self.marks, self.lists, self.rects, self.texts = [], [], {}, {}, {}, []

    def prop(self, key, fn, x, y, foot=None, shadow=True, base=None):
        """Eşyayı (x, y) sol üst köşesine koyar. foot: tabandan yukarı doğru bu kadar piksel katıdır.
        base: sıralama için taban (verilmezse görselin alt kenarı)."""
        if key not in PROPS:
            PROPS[key] = outlined(fn())
        img = PROPS[key]
        w, h = img.w - 2, img.h - 2
        sort_y = y + h if base is None else base
        base = y + h
        self.props.append([key, x - 1, y - 1, sort_y])
        if foot:
            self.solids.append([x, base - foot, w, foot])
        if shadow:
            self.c.darken(x + 1, base - 2, w - 2, 3, SHADOW + 0.1, dither=False)
            self.c.darken(x, base + 1, w, 1, 0.8, dither=True)
        return base

    def solid(self, x, y, w, h):
        self.solids.append([x, y, w, h])

    def mark(self, name, x, y):
        self.marks[name] = [x, y]

    def add(self, list_name, item):
        self.lists.setdefault(list_name, []).append(item)

    def rect(self, list_name, x, y, w, h):
        self.rects.setdefault(list_name, []).append([x, y, w, h])

    def text(self, x, y, w, s, size=8, color="f4f2ec"):
        self.texts.append([x, y, w, s, size, color])

    # -- ortak parçalar
    def back_wall(self, face, top=None, base=None, h=None):
        h = h or self.wall_h
        wall(self.c, 0, 0, self.W, h, face, top, base)
        self.solid(0, 0, self.W, h + 4)

    def borders(self, door=None, bottom=True):
        """Sol, sağ ve alt duvar kesitleri. door: (x, genişlik) alt duvardaki kapı boşluğu."""
        c = self.c
        c.fill(0, 0, 5, self.H, EDGE); c.fill(4, self.wall_h, 1, self.H - self.wall_h, EDGE_HI)
        c.fill(self.W - 5, 0, 5, self.H, EDGE); c.fill(self.W - 5, self.wall_h, 1, self.H - self.wall_h, EDGE_HI)
        self.solid(0, 0, 6, self.H)
        self.solid(self.W - 6, 0, 6, self.H)
        if bottom:
            c.fill(0, self.H - 6, self.W, 6, EDGE)
            c.fill(0, self.H - 6, self.W, 1, EDGE_HI)
            if door:
                dx, dw = door
                c.fill(dx, self.H - 6, dw, 6, STONE[3])
                c.fill(dx, self.H - 6, dw, 1, STONE[5])
                for k in range(dx + 2, dx + dw - 2, 3):
                    c.set(k, self.H - 3, STONE[2])
                self.solid(0, self.H - 4, dx, 4)
                self.solid(dx + dw, self.H - 4, self.W - dx - dw, 4)
            else:
                self.solid(0, self.H - 6, self.W, 6)

    def window(self, x, y, w, h, outside="city", frame=WOOD):
        c = self.c
        c.fill(x - 3, y - 3, w + 6, h + 6, frame[1])
        c.fill(x - 2, y - 2, w + 4, h + 4, frame[3])
        c.fill(x - 2, y - 2, w + 4, 1, frame[4])
        c.grad_v(x, y, w, h, [SKY[4], SKY[3], SKY[2]])
        rng = random.Random(x * 7 + y)
        if outside == "city":
            bx = x
            while bx < x + w:
                bw = rng.randint(6, 12)
                top = y + h // 3 + rng.randint(0, h // 3)
                c.fill(bx, top, min(bw, x + w - bx), y + h - top, STONE[rng.choice([4, 5])])
                for wy in range(top + 2, y + h - 1, 4):
                    for wx in range(bx + 1, min(bx + bw - 1, x + w - 1), 3):
                        c.set(wx, wy, STONE[6])
                bx += bw + 1
        elif outside == "green":
            c.fill(x, y + h * 2 // 3, w, h - h * 2 // 3, GREEN[3])
            for k in range(x - 4, x + w, 9):
                cx = k + rng.randint(0, 4)
                cy = y + h // 2 + rng.randint(-2, 3)
                for (r, col) in ((7, GREEN[1]), (6, GREEN[2]), (3, GREEN[3])):
                    for yy in range(-r, r + 1):
                        for xx in range(-r, r + 1):
                            if xx * xx + yy * yy <= r * r and x <= cx + xx < x + w and y <= cy + yy < y + h:
                                c.set(cx + xx, cy + yy, col)
        # cam yansıması
        for i in range(0, w + h, 14):
            for d in range(h):
                px = x + i - d // 2
                if x <= px < min(x + w, c.w) and y + d < c.h and (d % 5) < 3:
                    col = c.px[y + d][px]
                    c.px[y + d][px] = (min(255, col[0] + 22), min(255, col[1] + 22), min(255, col[2] + 22), 255)
        c.fill(x + w // 2, y, 1, h, frame[3])
        c.fill(x - 4, y + h + 2, w + 8, 3, frame[4])
        c.fill(x - 4, y + h + 4, w + 8, 1, frame[1])
        self.rect("windows", x, y, w, h)

    def finish(self):
        write_png(os.path.join(OUT, f"{self.id}.png"), self.c.px)
        CANVASES[self.id] = self.c
        return {"size": [self.W, self.H], "props": self.props, "solids": self.solids, "marks": self.marks,
                "lists": self.lists, "rects": self.rects, "texts": self.texts}


def wall(c, x, y, w, h, face, top=None, base=None):
    top = top or shade(face, 0.5)
    c.fill(x, y, w, h, face)
    for k in range(6):   # tavana yakın kısım biraz koyu (ortam gölgesi)
        c.darken(x, y + 6 + k, w, 1, 0.82 + k * 0.03, dither=k % 2 == 1)
    c.fill(x, y, w, 6, top)
    c.fill(x, y + 5, w, 1, shade(top, 0.7))
    b = base or shade(face, 0.62)
    c.fill(x, y + h - 5, w, 5, b)
    c.fill(x, y + h - 5, w, 1, shade(b, 1.25))
    c.fill(x, y + h, w, 2, shade(b, 0.55))   # duvarın dibine düşen gölge


def concrete(c, x, y, w, h, base, seed, grid=32):
    c.fill(x, y, w, h, base)
    c.speckle(x, y, w, h, [shade(base, 0.9), shade(base, 1.06)], 0.08, seed)
    for gx in range(x, x + w, grid):
        c.fill(gx, y, 1, h, shade(base, 0.82))
    for gy in range(y, y + h, grid):
        c.fill(x, gy, w, 1, shade(base, 0.82))


def checker(c, x, y, w, h, a, b, size=16):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            tx, ty = (xx - x) // size, (yy - y) // size
            col = a if (tx + ty) % 2 else b
            if (xx - x) % size == 0 or (yy - y) % size == 0:
                col = shade(col, 0.88)
            elif (xx - x) % size == 1 or (yy - y) % size == 1:
                col = shade(col, 1.06)
            c.set(xx, yy, col)


def planks(c, x, y, w, h, ramp, seed, board=6):
    rng = random.Random(seed)
    for row, by in enumerate(range(y, y + h, board)):
        bh = min(board, y + h - by)
        base = ramp[2] if row % 2 else ramp[3]
        c.fill(x, by, w, bh, base)
        c.fill(x, by, w, 1, shade(base, 1.12))
        c.fill(x, by + bh - 1, w, 1, ramp[1])
        sx = x + rng.randrange(40)
        while sx < x + w:
            c.fill(sx, by, 1, bh - 1, ramp[1])
            c.set(sx + 1, by + 1, shade(base, 1.12))
            sx += 34 + rng.randrange(28)
        for _ in range(w // 14):
            c.set(x + rng.randrange(w), by + 1 + rng.randrange(max(1, bh - 2)), shade(base, rng.choice([0.88, 1.08])))


def rug(c, x, y, w, h, ramp, accent, motif=True):
    c.fill(x, y, w, h, ramp[1])
    c.fill(x + 2, y + 2, w - 4, h - 4, ramp[2])
    c.fill(x + 4, y + 4, w - 8, h - 8, ramp[3])
    for k in range(x + 6, x + w - 6, 6):
        c.set(k, y + 6, accent); c.set(k + 3, y + h - 7, accent)
    cx, cy = x + w // 2, y + h // 2
    for d in range(min(w, h) // 4 if motif else 0):   # ortada artı deseni
        c.set(cx - d, cy, accent); c.set(cx + d, cy, accent); c.set(cx, cy - d // 2, accent); c.set(cx, cy + d // 2, accent)
    for k in range(x, x + w, 2):   # saçaklar
        c.set(k, y - 1, ramp[4]); c.set(k, y + h, ramp[4])


# ---------------------------------------------------------------- Eşyalar (her biri bir Painter döndürür)

def block(w, d, fh, top, front):
    c = Painter(w, d + fh)
    c.fill(0, 0, w, d, top)
    c.fill(0, 0, w, 1, shade(top, 1.15))
    c.fill(0, d - 1, w, 1, shade(top, 1.08))
    c.fill(0, d, w, fh, front)
    c.fill(0, d, w, 1, shade(front, 0.8))
    c.fill(0, d + fh - 1, w, 1, shade(front, 0.68))
    return c


def table(w, d, ramp=WOOD, legs=6):
    c = Painter(w, d + 4 + legs)
    c.fill(0, 0, w, d, ramp[4])
    for k in range(3, d, 5):
        c.fill(1, k, w - 2, 1, mix(ramp[4], ramp[3], 0.5))
    c.fill(0, 0, w, 1, ramp[5])
    c.fill(0, d, w, 4, ramp[2])
    c.fill(0, d + 3, w, 1, ramp[1])
    c.fill(1, d + 4, 2, legs, ramp[1]); c.fill(w - 3, d + 4, 2, legs, ramp[1])
    return c


def chair_top(color=WOOD):
    """Masanın üst tarafındaki sandalye: arkalığı oturanın arkasında kalır."""
    c = Painter(14, 22)
    c.fill(1, 0, 12, 12, color[3]); c.fill(1, 0, 12, 1, color[4])
    c.fill(3, 2, 8, 7, color[2])
    c.fill(0, 12, 14, 5, color[4]); c.fill(0, 16, 14, 1, color[2])
    c.fill(1, 17, 2, 5, color[1]); c.fill(11, 17, 2, 5, color[1])
    return c


def chair_away(color=WOOD):
    """Arkası bize dönük sandalye (oturan yukarı bakar)."""
    c = Painter(14, 18)
    c.fill(0, 0, 14, 4, color[4])
    c.fill(1, 4, 12, 9, color[3]); c.fill(1, 4, 12, 1, color[4]); c.fill(3, 6, 8, 5, color[2])
    c.fill(1, 13, 2, 5, color[1]); c.fill(11, 13, 2, 5, color[1])
    return c


def plant(big=False):
    w, hgt = (18, 34) if big else (14, 24)
    c = Painter(w, hgt)
    pot_h = 9 if big else 7
    c.fill(2, hgt - pot_h, w - 4, pot_h, H("b0603e")); c.fill(2, hgt - pot_h, w - 4, 2, H("d0805a"))
    c.fill(3, hgt - 1, w - 6, 1, H("7a3a26"))
    rng = random.Random(w)
    for _ in range(14 if big else 9):
        cx, cy = rng.randint(3, w - 4), rng.randint(2, hgt - pot_h - 2)
        r = rng.randint(2, 4)
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r:
                    c.set(cx + xx, cy + yy, GREEN[2] if yy > 0 else GREEN[3])
        c.set(cx - 1, cy - 1, GREEN[4])
    return c


def bed():
    c = Painter(44, 62)
    c.fill(0, 0, 44, 6, WOOD[2]); c.fill(0, 6, 44, 10, WOOD[1]); c.fill(0, 0, 44, 1, WOOD[3])   # başlık
    c.fill(2, 14, 40, 40, H("e8e2d4"))                                       # çarşaf
    c.fill(6, 16, 32, 10, WHITE); c.fill(6, 25, 32, 1, H("c8c0b0"))          # yastık
    c.fill(2, 28, 40, 26, H("4d63a6")); c.fill(2, 28, 40, 2, H("6d83c6"))    # yorgan
    for y in range(32, 54, 6):
        for x in range(4, 42, 6):
            c.set(x, y, H("8da3e0")); c.set(x + 3, y + 3, H("35457e"))
    c.fill(2, 54, 40, 6, H("35457e")); c.fill(0, 14, 2, 46, WOOD[2]); c.fill(42, 14, 2, 46, WOOD[2])
    c.fill(0, 60, 44, 2, WOOD[1])
    return c


def desk_laptop():
    c = Painter(50, 38)
    t = table(50, 14)
    for y in range(t.h):
        for x in range(t.w):
            if t.px[y][x][3]:
                c.px[y + 14][x] = t.px[y][x]
    c.fill(18, 6, 16, 10, STONE[1]); c.fill(19, 7, 14, 8, H("3a74c0")); c.fill(20, 8, 5, 1, H("9ad0ff"))  # ekran
    c.fill(16, 16, 20, 6, STONE[4]); c.fill(16, 16, 20, 1, STONE[5])                                     # klavye
    c.fill(3, 4, 2, 12, STONE[2]); c.fill(1, 2, 7, 4, GOLD[3]); c.fill(1, 2, 7, 1, GOLD[4])                # lamba
    c.fill(38, 12, 8, 6, RED[2]); c.fill(38, 12, 8, 2, RED[3])                                           # kitaplar
    c.fill(39, 9, 7, 3, TEAL[2])
    c.fill(9, 17, 4, 3, WHITE)                                                                           # kupa
    return c


def wardrobe():
    c = block(26, 6, 46, WOOD[3], WOOD[2])
    c.fill(12, 8, 1, 42, WOOD[1])
    c.fill(10, 26, 1, 4, GOLD[3]); c.fill(15, 26, 1, 4, GOLD[3])
    c.fill(2, 10, 8, 14, WOOD[3]); c.fill(16, 10, 8, 14, WOOD[3])
    return c


def fridge(w=24, color=H("e4e8ee")):
    c = block(w, 8, 40, shade(color, 1.05), color)
    c.fill(1, 22, w - 2, 1, STONE[4])
    c.fill(w - 5, 12, 2, 7, STONE[3]); c.fill(w - 5, 25, 2, 9, STONE[3])
    c.fill(4, 12, 4, 4, RED[3]); c.fill(9, 14, 3, 3, GOLD[3]); c.fill(5, 28, 5, 3, TEAL[3])
    return c


def kitchen_counter(w=50):
    c = block(w, 14, 16, STONE[5], WOOD[2])
    c.fill(4, 2, 16, 10, STONE[3]); c.fill(5, 3, 14, 8, H("8fb4cc")); c.fill(11, 1, 2, 3, STONE[2])   # lavabo
    c.fill(w - 22, 2, 18, 10, STONE[0])
    for cx in (w - 17, w - 9):
        c.circle(cx, 7, 3, RED[1]); c.circle(cx, 7, 1, RED[3])
    for k in range(0, w, w // 3 + 1):
        c.fill(k + 2, 16, w // 3 - 3, 12, WOOD[3]); c.fill(k + w // 6, 20, 2, 1, GOLD[3])
    return c


def drying_rack():
    c = Painter(34, 28)
    c.fill(0, 8, 34, 1, STONE[5]); c.fill(0, 14, 34, 1, STONE[5])
    c.fill(1, 8, 1, 20, STONE[4]); c.fill(32, 8, 1, 20, STONE[4])
    for i, col in enumerate([RED[3], WHITE, NAVY[3], GOLD[3], TEAL[3]]):
        x = 3 + i * 6
        c.fill(x, 8 if i % 2 else 14, 5, 10 + (i % 3) * 2, col)
        c.fill(x, 8 if i % 2 else 14, 5, 1, shade(col, 1.2))
    return c


def books_stack():
    c = Painter(14, 12)
    for i, col in enumerate([RED[2], NAVY[3], GOLD[2], GREEN[2]]):
        c.fill(1 + (i % 2), 9 - i * 3, 12, 3, col); c.fill(1 + (i % 2), 9 - i * 3, 12, 1, shade(col, 1.25))
    return c


def backpack():
    c = Painter(12, 14)
    c.fill(1, 2, 10, 12, RED[2]); c.fill(1, 2, 10, 2, RED[3]); c.fill(3, 8, 6, 4, RED[1]); c.fill(4, 0, 4, 2, RED[1])
    return c


def gondola(w=112):
    c = block(w, 10, 24, STONE[5], STONE[4])
    rng = random.Random(w)
    for row in range(3):
        y = 11 + row * 7
        c.fill(1, y + 5, w - 2, 1, STONE[2])
        x = 2
        while x < w - 4:
            bw = rng.randint(3, 6)
            col = rng.choice([RED[3], GOLD[3], GREEN[3], NAVY[4], WHITE, H("e8745a"), TEAL[3], H("b06ad0")])
            bh = rng.randint(3, 5)
            c.fill(x, y + 5 - bh, bw, bh, col)
            c.fill(x, y + 5 - bh, bw, 1, shade(col, 1.25))
            x += bw + 1
    for x in range(2, w - 2, 5):   # üstteki ürünler
        c.fill(x, 2, 3, 6, [RED[3], GOLD[3], GREEN[3], NAVY[4]][x % 4]); c.fill(x, 2, 3, 1, WHITE)
    return c


def market_counter():
    c = block(96, 18, 14, H("d8d2c4"), RED[2])
    c.fill(0, 18, 96, 2, RED[3])
    c.fill(66, 0, 22, 12, STONE[1]); c.fill(68, 2, 18, 5, H("3a5a40")); c.fill(69, 3, 6, 1, H("9adf9a"))   # yazar kasa
    c.fill(68, 8, 18, 3, STONE[3])
    for i in range(5):   # şekerler
        c.fill(6 + i * 7, 3, 5, 6, [RED[3], GOLD[3], GREEN[3], TEAL[3], H("e8745a")][i]); c.fill(6 + i * 7, 3, 5, 1, WHITE)
    c.fill(42, 5, 14, 8, WOOD[3])
    return c


def bread_rack():
    c = Painter(30, 30)
    c.fill(0, 6, 30, 3, WOOD[3]); c.fill(0, 18, 30, 3, WOOD[3])
    c.fill(1, 6, 2, 24, WOOD[1]); c.fill(27, 6, 2, 24, WOOD[1])
    for x in range(3, 26, 7):
        for y in (2, 14):
            c.circle(x + 3, y + 2, 3, H("c48a3c")); c.circle(x + 3, y + 2, 1, (0, 0, 0, 0)); c.set(x + 1, y, H("e8b860"))
    return c


def fruit_crates():
    c = block(40, 14, 10, WOOD[3], WOOD[2])
    for i, col in enumerate([H("e84438"), H("f0a020"), H("8cc84a")]):
        for k in range(5):
            c.circle(3 + i * 13 + (k % 3) * 4, 3 + (k // 3) * 5, 2, col)
            c.set(3 + i * 13 + (k % 3) * 4 - 1, 2 + (k // 3) * 5, shade(col, 1.3))
    c.fill(13, 0, 1, 14, WOOD[1]); c.fill(26, 0, 1, 14, WOOD[1])
    return c


def drinks_fridge():
    c = block(64, 8, 40, STONE[5], STONE[4])
    for k in range(3):
        x = 2 + k * 21
        c.fill(x, 10, 19, 34, H("2a3a52"))
        for row in range(4):
            for b in range(4):
                col = [RED[3], GREEN[3], GOLD[3], H("e8745a")][(b + row + k) % 4]
                c.fill(x + 2 + b * 4, 12 + row * 8, 2, 6, col); c.set(x + 2 + b * 4, 12 + row * 8, WHITE)
        c.fill(x, 10, 2, 34, H("6a8aa8"))
    return c


def reception_desk(w=72):
    c = block(w, 16, 16, H("ccc6b8"), NAVY[2])
    c.fill(0, 16, w, 3, GOLD[3])
    c.fill(w - 26, 0, 18, 10, STONE[1]); c.fill(w - 25, 1, 16, 6, H("3a74c0"))      # bilgisayar
    for i in range(3):   # protein kavanozları
        c.fill(6 + i * 8, 2, 6, 9, [WHITE, BLACK, RED[3]][i]); c.fill(6 + i * 8, 2, 6, 2, GOLD[3])
    return c


def squat_rack():
    c = Painter(50, 46)
    for x in (1, 45):
        c.fill(x, 0, 4, 44, STONE[1]); c.fill(x, 0, 1, 44, STONE[3])
        for y in range(6, 40, 5):
            c.set(x + 2, y, STONE[4])
        c.fill(x - 1, 20, 6, 2, RED[3])                 # j-kancalar
    c.fill(1, 0, 48, 3, STONE[1]); c.fill(1, 0, 48, 1, STONE[3])
    c.fill(0, 42, 50, 4, STONE[2])
    return c


def treadmill_console():
    c = Painter(12, 30)
    c.fill(1, 4, 2, 26, STONE[2]); c.fill(9, 4, 2, 26, STONE[2])
    c.fill(0, 0, 12, 10, STONE[1]); c.fill(1, 1, 10, 5, H("2b3a55")); c.fill(2, 2, 4, 1, H("62c0ff"))
    c.fill(0, 9, 12, 2, STONE[3])
    return c


def punching_bag():
    c = Painter(16, 52)
    c.fill(4, 0, 8, 2, STONE[2])
    c.fill(7, 2, 2, 18, STONE[4])
    c.fill(1, 20, 14, 30, RED[2]); c.fill(1, 20, 3, 30, RED[3]); c.fill(12, 20, 3, 30, RED[1])
    c.fill(1, 20, 14, 3, RED[0]); c.fill(1, 47, 14, 3, RED[0]); c.fill(1, 33, 14, 2, RED[0])
    return c


def water_cooler():
    c = Painter(14, 32)
    c.fill(3, 0, 8, 12, H("8fc8f0")); c.fill(3, 0, 8, 2, H("cfeaff")); c.fill(4, 3, 2, 7, H("cfeaff"))
    c.fill(1, 12, 12, 20, WHITE); c.fill(1, 12, 12, 1, H("d8dce4")); c.fill(5, 16, 4, 3, STONE[2])
    return c


def dumbbell_rack():
    c = block(64, 10, 12, STONE[2], STONE[1])
    for i in range(7):
        x = 3 + i * 9
        c.fill(x, 2, 7, 3, STONE[0]); c.fill(x + 2, 3, 3, 1, STONE[4]); c.fill(x, 6, 7, 3, STONE[0])
    return c


def gym_bench():
    c = Painter(50, 18)
    c.fill(0, 0, 50, 8, BLACK); c.fill(0, 0, 50, 2, STONE[2]); c.fill(1, 8, 48, 3, STONE[1])
    c.fill(4, 11, 3, 7, STONE[3]); c.fill(43, 11, 3, 7, STONE[3])
    return c


def lamp_post():
    c = Painter(14, 70)
    c.fill(5, 8, 3, 60, STONE[1]); c.fill(5, 8, 1, 60, STONE[3])
    c.fill(2, 66, 9, 4, STONE[2])
    c.fill(0, 0, 14, 8, STONE[1]); c.fill(2, 6, 10, 3, H("fff2b0"))
    return c


def street_tree():
    c = Painter(42, 66)
    c.fill(18, 36, 6, 26, WOOD[1]); c.fill(18, 36, 2, 26, WOOD[2])
    c.fill(10, 58, 22, 8, STONE[3]); c.fill(10, 58, 22, 2, STONE[5])
    rng = random.Random(3)
    for _ in range(22):
        cx, cy, r = rng.randint(8, 34), rng.randint(6, 36), rng.randint(5, 8)
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r:
                    c.set(cx + xx, cy + yy, GREEN[1] if yy > r // 2 else (GREEN[2] if yy > -r // 3 else GREEN[3]))
    for _ in range(18):
        c.set(rng.randint(6, 36), rng.randint(2, 30), GREEN[4])
    return c


def cafe_table_out():
    c = Painter(30, 24)
    c.circle(15, 6, 8, WHITE); c.circle(15, 6, 7, H("e8e4dc")); c.fill(14, 13, 2, 9, STONE[2]); c.fill(9, 21, 12, 3, STONE[2])
    c.fill(12, 3, 4, 3, H("c84438")); c.fill(18, 5, 3, 2, WOOD[3])
    return c


def boxes():
    c = Painter(44, 40)
    for (x, y, w, h) in [(0, 18, 20, 22), (20, 20, 22, 20), (8, 0, 20, 20)]:
        b = block(w, 6, h - 6, H("d8a868"), H("b08048"))
        for yy in range(b.h):
            for xx in range(b.w):
                if b.px[yy][xx][3]:
                    c.px[y + yy][x + xx] = b.px[yy][xx]
        c.fill(x + w // 2 - 1, y, 2, 6, H("e8d8a0"))
        c.fill(x + 3, y + 10, 8, 3, WHITE)
    return c


def park_bench():
    c = Painter(46, 22)
    for k in range(3):
        c.fill(0, k * 4, 46, 3, WOOD[3]); c.fill(0, k * 4, 46, 1, WOOD[4])
    c.fill(0, 12, 46, 3, WOOD[2])
    c.fill(2, 15, 3, 7, STONE[1]); c.fill(41, 15, 3, 7, STONE[1])
    return c


def trash_bin():
    c = Painter(12, 18)
    c.fill(0, 0, 12, 4, STONE[2]); c.fill(1, 4, 10, 14, GREEN[1]); c.fill(1, 4, 2, 14, GREEN[2]); c.fill(1, 0, 10, 1, STONE[4])
    return c


def espresso_counter():
    c = block(104, 18, 16, H("e8e0d0"), WOOD[1])
    for k in range(4):
        c.fill(4 + k * 26, 20, 22, 11, WOOD[2]); c.fill(4 + k * 26, 20, 22, 1, WOOD[3])
    c.fill(6, 0, 22, 12, STONE[4]); c.fill(6, 0, 22, 2, STONE[5]); c.fill(9, 5, 4, 5, STONE[1]); c.fill(19, 5, 4, 5, STONE[1])
    c.fill(36, 1, 30, 12, H("cfe7f5")); c.fill(36, 1, 30, 1, WHITE)              # pasta vitrini
    for i in range(4):
        c.fill(38 + i * 7, 8, 5, 3, [H("c48a3c"), H("f0d8a0"), H("6b4530"), H("e8745a")][i])
    for i in range(4):
        c.fill(74 + i * 6, 4, 4, 5, WHITE); c.fill(74 + i * 6, 4, 4, 1, H("c8c0b0"))  # bardaklar
    return c


def sofa():
    c = Painter(52, 26)
    c.fill(0, 0, 52, 12, TEAL[1]); c.fill(2, 2, 48, 8, TEAL[2]); c.fill(0, 10, 52, 10, TEAL[2]); c.fill(2, 11, 48, 3, TEAL[3])
    c.fill(0, 6, 6, 18, TEAL[1]); c.fill(46, 6, 6, 18, TEAL[1]); c.fill(0, 20, 52, 4, TEAL[0])
    return c


def car_3q(body, kind=None):
    """Sağa bakan araba, 3/4 açıdan (tavan, yan yüz, tekerlekler)."""
    c = Painter(76, 40)
    dark, light, lighter = shade(body, 0.68), shade(body, 1.15), shade(body, 1.3)
    glass, glass_hi = (58, 86, 116), (150, 190, 215)
    cl, cr = {"van": (8, 60), "sport": (22, 50)}.get(kind, (16, 54))
    roof_top = 4 if kind == "van" else (10 if kind == "sport" else 6)
    # alt gövde
    c.fill(2, 18, 72, 13, body); c.fill(1, 20, 74, 9, body)
    c.fill(3, 14, 70, 5, light); c.fill(3, 14, 70, 1, lighter)        # kaput ve bagaj üstü
    c.fill(1, 28, 74, 3, dark)
    c.fill(4, 22, 68, 1, shade(body, 1.08))
    # kabin
    c.fill(cl + 4, roof_top - 4, cr - cl - 8, 4, lighter)                # tavan
    c.fill(cl, roof_top, cr - cl, 14 - roof_top + 1, body)
    mid = (cl + cr) // 2
    c.fill(cl + 3, roof_top + 1, mid - cl - 4, 13 - roof_top - 1, glass)
    c.fill(mid + 1, roof_top + 1, cr - mid - 4, 13 - roof_top - 1, glass)
    c.fill(cl + 4, roof_top + 1, 4, 1, glass_hi); c.fill(mid + 2, roof_top + 1, 4, 1, glass_hi)
    for i in range(10 - roof_top // 2):                                   # ön ve arka cam eğimi
        c.fill(cr + i // 2, roof_top + i, 2, 1, glass)
        c.fill(cl - 1 - i // 2, roof_top + i, 2, 1, glass)
    c.fill(mid, roof_top, 1, 28 - roof_top, dark)
    c.fill(mid - 6, 20, 3, 1, STONE[5]); c.fill(mid + 4, 20, 3, 1, STONE[5])
    # farlar
    c.fill(71, 19, 4, 3, (255, 240, 170)); c.fill(1, 19, 3, 3, (220, 50, 50))
    # tekerlekler
    for wx in (16, 58):
        c.circle(wx, 31, 6, (24, 24, 28)); c.circle(wx, 31, 3, (120, 120, 130)); c.set(wx - 1, 30, (180, 180, 190))
    if kind == "taxi":
        c.fill(mid - 6, roof_top - 7, 12, 4, (30, 30, 30)); c.fill(mid - 5, roof_top - 6, 10, 2, (250, 240, 200))
    if kind == "sport":
        c.fill(2, 12, 8, 2, BLACK)
    return c


CAR_COLORS = {
    "sahin": ((226, 212, 168), None), "tofas": ((150, 70, 52), None), "doblo": ((236, 236, 240), "van"),
    "passat": ((40, 62, 112), None), "bmw": ((28, 28, 34), "sport"), "taksi": ((246, 200, 40), "taxi"),
    "dolmus": ((230, 210, 70), "van"), "kamyon": ((200, 46, 40), "van"),
    "toros": ((236, 232, 222), None), "egea": ((196, 40, 44), None), "golf": ((176, 180, 188), "sport"),
    "mercedes": ((200, 204, 212), None),
}


def bus_3q():
    """Durağa giren metrobüs, 3/4 açıdan: tavan + yan yüz (kapılar yan yüzde). Önü solda."""
    w = 404
    c = Painter(w, 66)
    roof, side = H("e8eaee"), H("f4f4f6")
    c.fill(4, 0, w - 8, 18, roof); c.fill(4, 0, w - 8, 1, WHITE)
    for x in (40, 150, 260, 340):   # klima kutuları
        c.fill(x, 3, 30, 10, STONE[5]); c.fill(x, 3, 30, 1, WHITE)
        for k in range(x + 3, x + 28, 4):
            c.fill(k, 5, 2, 6, STONE[4])
    c.fill(0, 18, w, 44, side)
    c.fill(0, 18, w, 2, shade(side, 0.85))
    c.fill(0, 22, w, 18, H("2b3a55"))                  # cam şeridi
    for x in range(30, w, 34):
        c.fill(x, 22, 3, 18, H("d8dce4"))
    c.fill(2, 22, 18, 18, H("3a5070")); c.fill(4, 24, 8, 2, H("9ab8d8"))   # ön cam
    c.fill(0, 46, w, 5, H("c8102e")); c.fill(0, 51, w, 2, H("8e0a20"))
    c.fill(196, 18, 14, 44, H("2a2a33"))                # körük
    for y in range(20, 60, 3):
        c.fill(196, y, 14, 1, H("44444f"))
    for o in (80, 200 + 2, 320):                        # kapılar (kapalı)
        o = o if o != 202 else 226
        c.fill(o - 12, 22, 24, 38, H("aab2c0")); c.fill(o - 1, 22, 2, 38, H("5c6270"))
        c.fill(o - 10, 24, 8, 14, H("3a5070")); c.fill(o + 2, 24, 8, 14, H("3a5070"))
    c.fill(4, 20, 30, 1, BLACK)
    for wx in (36, 150, 262, 370):
        c.circle(wx, 60, 6, (24, 24, 28)); c.circle(wx, 60, 2, STONE[4])
    c.fill(6, 54, 6, 3, (255, 240, 170))
    return c


def metro_seat(aisle=False):
    """Sağa (gidiş yönüne) bakan metrobüs koltuğu: arkalık solda, mavi kumaş, kırmızı desen.
    Koridor tarafındakinin arkalığında sarı tutunma kolu var."""
    c = Painter(16, 18)
    fab, fab_d, fab_l = H("2f4a8e"), H("22356a"), H("4a68b0")
    c.fill(0, 0, 4, 14, fab_d); c.fill(1, 1, 2, 12, fab); c.fill(1, 1, 2, 1, fab_l)
    for y in range(3, 13, 3):
        c.set(2, y, RED[3])
    c.fill(2, 8, 13, 6, fab); c.fill(2, 8, 13, 1, fab_l); c.fill(14, 9, 1, 5, fab_d)
    for x in range(4, 14, 3):
        c.set(x, 10, RED[3]); c.set(x + 1, 12, H("6a84c8"))
    c.fill(2, 14, 13, 1, STONE[1])
    c.fill(4, 15, 2, 3, STONE[2]); c.fill(12, 15, 2, 3, STONE[2])
    if aisle:
        c.fill(0, 0, 4, 2, GOLD[3]); c.fill(0, 0, 4, 1, GOLD[4])
    return c


def metro_pole():
    c = Painter(3, 58)
    c.fill(0, 0, 3, 56, GOLD[3]); c.fill(0, 0, 1, 56, GOLD[4]); c.fill(2, 0, 1, 56, GOLD[1])
    c.fill(0, 55, 3, 3, STONE[2])
    return c


def validator():
    """Kart okutma makinesi (İstanbulkart) kısa direğin üstünde."""
    c = Painter(10, 30)
    c.fill(4, 10, 2, 20, STONE[3])
    c.fill(0, 0, 10, 11, GOLD[2]); c.fill(1, 1, 8, 5, H("1b2a22")); c.fill(2, 2, 3, 1, H("62e080"))
    c.fill(2, 7, 6, 3, STONE[1]); c.fill(0, 0, 10, 1, GOLD[4])
    return c


def driver_seat():
    c = Painter(18, 22)
    c.fill(0, 0, 5, 16, BLACK); c.fill(1, 1, 3, 14, STONE[1])
    c.fill(3, 9, 14, 7, STONE[1]); c.fill(3, 9, 14, 1, STONE[3])
    c.fill(7, 16, 4, 6, STONE[2])
    return c


def dashboard():
    c = Painter(16, 70)
    c.fill(0, 0, 16, 70, STONE[1]); c.fill(0, 0, 16, 2, STONE[3])
    c.fill(3, 24, 8, 8, BLACK); c.circle(6, 40, 5, BLACK); c.circle(6, 40, 3, STONE[2])   # direksiyon
    c.fill(4, 8, 8, 4, H("2b5a3a")); c.fill(5, 9, 3, 1, H("7ae09a"))
    return c


def wheelchair():
    """Sağa bakan tekerlekli sandalye (yandan): büyük arka tekerlek, küçük ön tekerlek, itme kolu."""
    c = Painter(22, 24)
    c.fill(2, 0, 2, 12, STONE[2]); c.fill(0, 0, 4, 2, BLACK)              # itme kolu ve arkalık
    c.fill(3, 10, 13, 3, H("2f4a8e")); c.fill(3, 10, 13, 1, H("4a68b0"))   # oturak
    c.fill(15, 12, 2, 8, STONE[3]); c.fill(15, 19, 5, 2, STONE[3])          # ayaklık
    c.circle(8, 16, 7, H("24242c")); c.circle(8, 16, 5, STONE[4]); c.circle(8, 16, 4, (0, 0, 0, 0))
    for (x, y) in ((8, 12), (8, 20), (4, 16), (12, 16)):
        c.set(x, y, STONE[5])
    c.circle(8, 16, 1, STONE[2])
    c.circle(19, 21, 2, H("24242c"))
    return c


def clothes_rack(o, oid=""):
    """Askılık: krom çubuk; askıda üst (tişört, kapüşonlu, ceket, takım, palto...), mandallı askıda pantolon.
    Kıyafetin kesimi ve detayları (yaka, cep, düğme, fermuar, desen) make_topdown.OUTFITS bilgisinden çizilir."""
    c = Painter(32, 48)
    chrome, chrome_d = STONE[5], STONE[3]
    c.fill(0, 1, 32, 2, chrome); c.fill(0, 1, 32, 1, WHITE)
    c.fill(0, 1, 2, 45, chrome_d); c.fill(30, 1, 2, 45, chrome_d)
    c.fill(0, 45, 8, 2, chrome_d); c.fill(24, 45, 8, 2, chrome_d)
    shirt, pants = o["shirt"], o.get("pants", (40, 44, 70))
    top = o.get("top", "tee")
    long_sl = o.get("sleeves", "long" if top in ("hoodie", "jacket", "suit", "coat") else "short") == "long"
    dk, lt = shade(shirt, 0.72), shade(shirt, 1.15)
    hem = 30 if top == "coat" else 24
    # askı
    c.fill(15, 0, 2, 4, STONE[2]); c.fill(8, 4, 16, 1, WOOD[3])
    if top == "hoodie":   # kapüşon (ensede toplanmış)
        c.fill(11, 3, 10, 5, dk); c.fill(13, 4, 6, 3, shade(shirt, 0.5))
    # gövde ve omuzlar
    c.fill(9, 5, 14, 2, shirt); c.fill(8, 6, 16, hem - 5, shirt)
    c.fill(8, 6, 1, hem - 5, lt); c.fill(23, 6, 1, hem - 5, dk)
    # kollar
    if long_sl:
        c.fill(4, 6, 4, hem - 8 if top != "coat" else 18, shirt); c.fill(24, 6, 4, hem - 8 if top != "coat" else 18, shirt)
        cuff = (hem - 3) if top != "coat" else 23
        c.fill(4, cuff, 4, 2, dk); c.fill(24, cuff, 4, 2, dk)
        c.fill(4, 6, 1, cuff - 6, lt)
    else:
        c.fill(5, 6, 3, 6, shirt); c.fill(24, 6, 3, 6, shirt)
        c.fill(5, 11, 3, 1, dk); c.fill(24, 11, 3, 1, dk)
    for x in (12, 19):    # kumaş kıvrımları
        c.fill(x, 9, 1, hem - 12, shade(shirt, 0.9))
    c.fill(8, hem - 1, 16, 1, dk)                                      # etek ucu
    inner = o.get("inner", (230, 230, 230))
    if top == "tee":
        c.fill(13, 5, 6, 2, shade(shirt, 0.5)); c.fill(12, 5, 1, 1, dk); c.fill(19, 5, 1, 1, dk)   # yuvarlak yaka
        if oid == "hawaii":   # çiçek deseni
            for (x, y) in ((10, 9), (16, 12), (20, 8), (11, 16), (18, 19), (14, 21), (21, 15)):
                c.set(x, y, o.get("stripe", WHITE)); c.set(x + 1, y, WHITE); c.set(x, y + 1, o.get("stripe", WHITE))
        elif oid == "forma":  # dikey şerit ve sırt numarası
            c.fill(15, 6, 2, hem - 7, o.get("stripe", WHITE)); c.fill(11, 12, 2, 5, WHITE); c.fill(19, 12, 2, 5, WHITE)
        elif oid == "metal":  # göğüste kafatası baskısı
            c.fill(13, 10, 6, 5, (220, 220, 225)); c.set(14, 12, shirt); c.set(17, 12, shirt); c.fill(14, 15, 4, 2, (220, 220, 225))
        elif oid == "gomlek":  # gömlek yakası ve düğmeler
            c.fill(12, 5, 3, 3, WHITE); c.fill(17, 5, 3, 3, WHITE); c.fill(15, 7, 2, hem - 8, shade(shirt, 0.92))
            for y in range(9, hem - 2, 4):
                c.set(15, y, STONE[3])
        elif oid == "kazak":   # örgü dokusu, lastikli yaka ve etek
            c.fill(12, 5, 8, 2, dk)
            for y in range(9, hem - 2, 3):
                for x in range(9, 23, 2):
                    c.set(x + (y // 3) % 2, y, shade(shirt, 1.08))
            c.fill(8, hem - 3, 16, 2, dk)
        elif o.get("stripe"):
            c.fill(8, 13, 16, 2, o["stripe"])
    elif top == "hoodie":
        c.fill(14, 7, 1, 5, WHITE); c.fill(17, 7, 1, 5, WHITE)        # bağcıklar
        c.fill(11, 16, 10, 5, shade(shirt, 0.88)); c.fill(11, 16, 10, 1, dk)   # kanguru cebi
        c.fill(8, hem - 3, 16, 2, dk)                                  # lastikli etek
        if o.get("stripe"):
            c.fill(4, 10, 4, 1, o["stripe"]); c.fill(24, 10, 4, 1, o["stripe"])
            c.fill(8, 11, 1, hem - 12, o["stripe"]); c.fill(23, 11, 1, hem - 12, o["stripe"])
    elif top in ("jacket", "suit", "coat"):
        c.fill(14, 6, 4, hem - 7, inner)                               # içteki gömlek/tişört
        for k in range(5):                                              # yaka ve klapalar
            c.set(13 - (k // 2), 6 + k, lt); c.set(18 + (k // 2), 6 + k, lt)
        c.fill(12, 5, 2, 2, lt); c.fill(18, 5, 2, 2, lt)
        if top == "suit":
            c.fill(14, 6, 4, 6, WHITE); c.fill(15, 7, 2, 7, o.get("tie", (180, 30, 40))); c.set(15, 6, o.get("tie", (180, 30, 40)))
            c.set(13, 16, STONE[1]); c.set(13, 19, STONE[1])
        elif top == "coat":
            for y in range(10, hem - 2, 4):
                c.set(12, y, dk); c.set(19, y, dk)
            c.fill(8, 19, 16, 2, dk)                                    # kemer
            c.fill(14, 19, 4, 2, GOLD[2])
        else:
            c.fill(13, 6, 1, hem - 7, STONE[4] if oid == "kot" else dk)   # fermuar / düğme hattı
        c.fill(9, 16, 3, 1, dk); c.fill(20, 16, 3, 1, dk)              # cep kapakları
        if oid == "kot":
            for y in range(8, hem - 1, 4):
                c.set(9, y, GOLD[3]); c.set(22, y, GOLD[3])             # turuncu dikiş
    if o.get("chain"):
        for k in range(5):
            c.set(13 + k, 8 + abs(k - 2), o["chain"])
    if o.get("beanie"):   # askının üstünde bere
        c.fill(11, 0, 10, 3, o["beanie"]); c.fill(11, 2, 10, 1, shade(o["beanie"], 0.75))
    # pantolon (mandallı askı)
    py = hem + 2
    c.fill(9, py - 1, 14, 1, STONE[2]); c.set(10, py, STONE[1]); c.set(21, py, STONE[1])
    plen = 45 - py
    c.fill(10, py, 12, 3, pants); c.fill(10, py + 1, 12, 1, shade(pants, 0.7))         # bel ve kemer
    c.fill(10, py + 3, 5, plen - 3, pants); c.fill(17, py + 3, 5, plen - 3, pants)
    c.fill(15, py + 3, 2, 2, pants)
    c.fill(12, py + 3, 1, plen - 3, shade(pants, 0.85)); c.fill(19, py + 3, 1, plen - 3, shade(pants, 0.85))   # ütü çizgisi
    c.fill(10, 44, 5, 1, shade(pants, 0.7)); c.fill(17, 44, 5, 1, shade(pants, 0.7))
    c.volume(1.06, 0.88)
    return c


def pixellab_art(name, max_w=None, max_h=None):
    """assets/pixellab/map/<ad>.png: boş kenarları kırpılmış, gerekirse sığacak kadar küçültülmüş Painter."""
    from make_citymap import load_art, shrink
    px = load_art(name)
    k = min(1.0, (max_w or 999) / len(px[0]), (max_h or 999) / len(px))
    if k < 1.0:
        px = shrink(px, k)
    c = Painter(len(px[0]), len(px))
    for y, row in enumerate(px):
        for x, col in enumerate(row):
            if col[3]:
                c.set(x, y, col[:3])
    return c


def weapon_display(wid):
    """Duvardaki delikli pano üstünde silah (PixelLab çizimi)."""
    c = Painter(36, 38)
    c.fill(0, 0, 36, 30, H("8a6a44")); c.fill(1, 1, 34, 28, H("b08a5a"))
    for y in range(4, 28, 5):
        for x in range(4, 34, 5):
            c.set(x, y, H("6a5034"))
    c.fill(16, 30, 4, 6, STONE[2]); c.fill(10, 36, 16, 2, STONE[2])
    art = pixellab_art("weapon_" + wid, 30, 24)
    ox, oy = (36 - art.w) // 2, (30 - art.h) // 2
    for y in range(art.h):
        for x in range(art.w):
            if art.px[y][x][3]:
                c.set(ox + x, oy + y, art.px[y][x][:3])
    return c


def tool_shelf():
    c = block(96, 10, 24, STONE[4], STONE[3])
    rng = random.Random(4)
    for row in range(3):
        y = 11 + row * 7
        c.fill(1, y + 5, 94, 1, STONE[1])
        x = 2
        while x < 92:
            kind = rng.choice(["box", "can", "tool"])
            col = rng.choice([RED[3], GOLD[3], NAVY[4], GREEN[3], STONE[5], H("e8745a")])
            if kind == "box":
                c.fill(x, y, 7, 5, col); c.fill(x, y, 7, 1, shade(col, 1.25)); x += 8
            elif kind == "can":
                c.fill(x, y + 1, 4, 4, col); c.fill(x, y + 1, 4, 1, WHITE); x += 5
            else:
                c.fill(x, y + 3, 6, 1, STONE[1]); c.fill(x + 5, y + 1, 2, 4, col); x += 8
    return c


def pillar():
    c = Painter(12, 72)
    c.fill(0, 0, 12, 70, STONE[4]); c.fill(0, 0, 3, 70, STONE[5]); c.fill(9, 0, 3, 70, STONE[3])
    c.fill(0, 30, 12, 10, H("c8102e")); c.fill(0, 30, 12, 1, H("e83a50"))
    c.fill(0, 68, 12, 4, STONE[2])
    return c


def info_board():
    c = Painter(48, 60)
    c.fill(22, 20, 4, 40, STONE[2]); c.fill(22, 20, 1, 40, STONE[4])
    c.fill(0, 0, 48, 22, STONE[0]); c.fill(2, 2, 44, 18, H("14100c")); c.fill(0, 0, 48, 1, STONE[3])
    return c


def station_sign():
    c = Painter(130, 46)
    c.fill(6, 18, 3, 28, STONE[2]); c.fill(121, 18, 3, 28, STONE[2])
    c.fill(0, 0, 130, 20, NAVY[2]); c.fill(0, 0, 130, 2, NAVY[4]); c.fill(0, 18, 130, 2, GOLD[3])
    return c


def turnstile():
    c = Painter(10, 26)
    c.fill(0, 0, 10, 20, STONE[3]); c.fill(0, 0, 10, 3, STONE[5]); c.fill(2, 5, 6, 3, H("62c060"))
    c.fill(1, 20, 8, 6, STONE[2])
    return c


def lectern():
    c = block(26, 8, 22, WOOD[3], WOOD[2])
    c.fill(4, 10, 18, 10, WOOD[3]); c.fill(9, 13, 8, 4, GOLD[3])
    c.fill(16, 0, 8, 5, WHITE)
    return c


def lecture_desk(w):
    c = block(w, 8, 9, H("c8a070"), H("8d5e3c"))
    for x in range(10, w - 10, 28):
        c.fill(x, 2, 8, 4, WHITE); c.fill(x + 1, 3, 6, 1, STONE[4])
    return c


def serving_counter(w=176):
    c = block(w, 24, 16, STONE[5], STONE[3])
    c.fill(0, 0, w, 3, STONE[6])
    foods = [H("8a4a26"), H("f4f0e0"), H("e8742a"), H("6aa84a"), H("d8a040")]
    for i, x in enumerate(range(6, w - 24, 30)):
        c.fill(x, 6, 26, 14, STONE[2]); c.fill(x + 1, 7, 24, 12, foods[i % len(foods)])
        for k in range(4):
            c.set(x + 3 + k * 6, 9 + (k % 2) * 4, shade(foods[i % len(foods)], 1.25))
    c.fill(0, 24, w, 2, STONE[4])
    for x in range(4, w, 16):
        c.fill(x, 30, 10, 6, STONE[2])
    return c


def tray_stack():
    c = Painter(18, 22)
    for k in range(5):
        c.fill(0, 14 - k * 2, 18, 2, H("8d5e3c") if k % 2 else H("a8744a"))
    c.fill(2, 16, 14, 6, STONE[3])
    return c


def stove():
    c = block(64, 12, 24, STONE[1], STONE[4])
    for cx in (10, 26, 42, 56):
        c.circle(cx, 6, 4, BLACK); c.circle(cx, 6, 2, RED[2])
    c.fill(4, 16, 56, 14, STONE[2]); c.fill(6, 18, 52, 10, H("2a2020")); c.fill(6, 18, 52, 1, STONE[5])
    c.fill(18, 0, 10, 6, STONE[5]); c.fill(18, 0, 10, 1, WHITE)          # tencere
    return c


def pass_counter(w=168):
    c = block(w, 16, 14, STONE[6], STONE[3])
    c.fill(0, 16, w, 2, STONE[4])
    c.fill(0, 0, w, 1, WHITE)
    return c


# ---------------------------------------------------------------- Odalar

def room_ev():
    r = Room("ev", 288, 192)
    c = r.c
    r.back_wall(H("b8ad8f"))
    for x in range(0, r.W, 12):
        c.fill(x, 12, 1, 38, H("a99f82"))
    for (cx, cy, rad) in [(270, 18, 10), (278, 26, 7)]:     # rutubet
        for yy in range(-rad, rad + 1):
            for xx in range(-rad, rad + 1):
                if xx * xx + yy * yy <= rad * rad and (xx + yy) % 2 == 0:
                    c.darken(cx + xx, cy + yy, 1, 1, 0.84)
    r.window(156, 12, 44, 28)
    c.fill(162, 41, 10, 6, H("b0603e")); c.circle(167, 37, 4, GREEN[2])     # pencere önü saksı
    c.fill(26, 14, 24, 30, NAVY[2]); c.circle(38, 30, 6, GOLD[3]); c.fill(30, 18, 16, 3, GOLD[3])  # konser afişi
    c.fill(98, 18, 18, 14, WHITE); c.fill(98, 18, 18, 3, RED[3])             # takvim
    for k in range(4):
        c.fill(100 + k * 4, 24, 2, 2, STONE[3])
    planks(c, 0, 56, r.W, 136, WOOD, 7)
    rug(c, 104, 112, 76, 44, RED, GOLD[3])
    c.fill(26, 172, 30, 12, H("6a5a3a")); c.fill(28, 174, 26, 8, H("8a7a52"))   # paspas
    r.borders(door=(26, 30))
    r.prop("bed", bed, 8, 46, foot=46)
    r.prop("desk_laptop", desk_laptop, 64, 30, foot=12)
    r.prop("chair_away", chair_away, 82, 64, shadow=True)
    r.prop("wardrobe", wardrobe, 122, 16, foot=10)
    r.prop("kitchen_counter", kitchen_counter, 206, 34, foot=14)
    r.prop("fridge", fridge, 258, 18, foot=10)
    r.prop("drying_rack", drying_rack, 212, 118, foot=4)
    r.prop("books", books_stack, 60, 100)
    r.prop("backpack", backpack, 120, 70)
    r.prop("plant", plant, 236, 150, foot=4)
    r.mark("spawn", 41, 170); r.mark("exit", 41, 188)
    r.mark("desk", 92, 92); r.mark("bed", 64, 96); r.mark("fridge", 268, 82); r.mark("stove", 228, 82)
    r.mark("wardrobe", 135, 78)
    r.add("lamps", [144, 96])
    return r.finish()


def freezer_chest():
    """Dondurma sandığı: beyaz gövde, cam kapaklar, içinde renkli külahlar."""
    c = Painter(52, 30)
    c.fill(0, 8, 52, 22, H("eef2f6")); c.fill(0, 8, 52, 1, WHITE); c.fill(0, 26, 52, 4, H("b8c0cc"))
    c.fill(2, 0, 48, 10, H("9cc8e4")); c.fill(2, 0, 48, 1, H("d8f0fa"))
    c.fill(26, 0, 1, 10, H("7aa8c8"))
    rng = random.Random(3)
    for k in range(12):
        x, y = 4 + (k % 6) * 8, 2 + (k // 6) * 4
        c.fill(x, y, 5, 3, rng.choice([H("f4a6c0"), H("fde68a"), H("a5d8ff"), H("c4a07a"), RED[3]]))
    c.fill(6, 14, 40, 8, RED[2]); c.fill(6, 14, 40, 1, RED[4])
    for x in range(10, 44, 9):
        c.fill(x, 16, 5, 4, WHITE)
    return c


def veg_stand():
    """Meyve-sebze tezgahı: eğimli kasalar, fiyat kartları."""
    c = Painter(64, 34)
    c.fill(0, 14, 64, 20, WOOD[2]); c.fill(0, 14, 64, 1, WOOD[4]); c.fill(0, 30, 64, 4, WOOD[1])
    fruits = [(RED[3], RED[4]), (H("f59e0b"), H("fcd34d")), (GREEN[3], GREEN[4]), (H("8b5cf6"), H("c4b5fd"))]
    for k, (col, hi) in enumerate(fruits):
        x = 2 + k * 15
        c.fill(x, 4, 14, 12, WOOD[3]); c.fill(x, 4, 14, 1, WOOD[5])
        for yy in range(5, 13, 3):
            for xx in range(x + 1, x + 13, 3):
                c.fill(xx, yy, 3, 3, col); c.set(xx, yy, hi)
        c.fill(x + 3, 18, 8, 6, WHITE); c.fill(x + 4, 20, 6, 1, RED[2])   # fiyat kartı
    return c


def basket_stack():
    """Kapı yanında kırmızı alışveriş sepetleri."""
    c = Painter(18, 18)
    for k in range(3):
        y = 10 - k * 3
        c.fill(1, y, 16, 7, RED[2]); c.fill(1, y, 16, 1, RED[4])
        for x in range(3, 16, 3):
            c.fill(x, y + 2, 1, 4, RED[1])
    c.fill(4, 1, 1, 6, STONE[2]); c.fill(13, 1, 1, 6, STONE[2]); c.fill(4, 1, 10, 1, STONE[2])
    return c


def room_market():
    """Mahalle marketi: duvar boyu raflar (fiyat etiketli), iki gondol, içecek dolabı, dondurma sandığı,
    meyve-sebze tezgahı, simit rafı, kasa ve arkasında sigara rafı, kapı yanında sepetler."""
    r = Room("market", 384, 224)
    c = r.c
    r.back_wall(H("d6e6d8"))
    c.tiles(0, 40, r.W, 16, H("f2f4f0"), H("e2e8e4"), H("c4ccc8"), size=8)   # alt duvar fayansı
    for sy in (8, 24):   # duvar rafları
        c.fill(8, sy + 12, 188, 3, WOOD[2]); c.fill(8, sy + 12, 188, 1, WOOD[4])
        rng = random.Random(sy)
        x = 10
        while x < 192:
            bw = rng.randint(3, 6)
            col = rng.choice([RED[3], GOLD[3], GREEN[3], NAVY[4], WHITE, H("e8745a"), TEAL[3], H("b06ad0")])
            bh = rng.randint(5, 9)
            c.fill(x, sy + 12 - bh, bw, bh, col); c.fill(x, sy + 12 - bh, bw, 1, shade(col, 1.25))
            x += bw + 1
        for px in range(14, 192, 22):   # fiyat etiketleri
            c.fill(px, sy + 15, 7, 3, GOLD[4]); c.fill(px + 1, sy + 16, 5, 1, RED[2])
    c.fill(272, 6, 104, 18, RED[2]); c.fill(272, 6, 104, 2, RED[3]); c.fill(272, 22, 104, 2, RED[0])
    r.text(272, 19, 104, "MAHALLE MARKET", 8, "f4f2ec")
    c.fill(272, 28, 30, 12, GOLD[3]); c.fill(272, 28, 30, 1, GOLD[4])                    # indirim afişi
    r.text(272, 37, 30, "% İNDİRİM", 5, "9e2c34")
    c.fill(306, 28, 70, 26, WOOD[1]); c.fill(308, 30, 66, 22, WOOD[0])                   # sigara rafı
    rng = random.Random(77)
    for row in range(3):
        for k in range(10):
            col = rng.choice([WHITE, RED[3], GOLD[3], NAVY[4], H("b8c0cc")])
            c.fill(310 + k * 6, 31 + row * 7, 5, 5, col); c.fill(310 + k * 6, 31 + row * 7, 5, 1, shade(col, 1.2))
    checker(c, 0, 56, r.W, r.H - 56, H("ecebe4"), H("c9cfd2"))
    for x in range(0, r.W, 24):   # zemin parlaması
        for d in range(0, r.H - 56, 4):
            if (d // 4) % 5 == 0:
                c.set(x + 4 + d // 8, 56 + d, H("f8f8f2"))
    r.borders(door=(194, 30))
    r.prop("drinks_fridge", drinks_fridge, 202, 10, foot=8)
    r.prop("gondola", gondola, 22, 82, foot=10)
    r.prop("gondola", gondola, 22, 142, foot=10)
    r.prop("veg_stand", veg_stand, 152, 92, foot=12)
    r.prop("freezer_chest", freezer_chest, 152, 150, foot=14)
    r.prop("market_counter", market_counter, 270, 108, foot=18)
    r.prop("bread_rack", bread_rack, 236, 60, foot=6)
    r.prop("basket_stack", basket_stack, 236, 192, foot=8)
    c.fill(60, 70, 36, 9, NAVY[3]); c.fill(60, 70, 36, 1, NAVY[4])                     # tavandan sarkan reyon tabelası
    r.text(60, 77, 36, "GIDA", 6, "f4f2ec")
    c.fill(77, 62, 1, 8, STONE[3])
    r.mark("spawn", 209, r.H - 22); r.mark("exit", 209, r.H - 4)
    r.mark("cashier", 334, 118); r.mark("talk_cashier", 322, 156)
    r.add("lamps", [110, 110]); r.add("lamps", [290, 110]); r.add("lamps", [180, 180])
    return r.finish()


def room_gym():
    """Kareye yakın salon: üst sırada resepsiyon, halter platformu, dambıl rafı, kum torbaları; alt sırada koşu bantları."""
    r = Room("gym", 416, 272, wall_h=64)
    c = r.c
    r.back_wall(H("3a4058"), base=H("20232f"))
    c.fill(110, 18, 284, 40, H("9aa8bc"))                     # aynalar
    c.grad_v(112, 20, 280, 36, [H("c8d4e4"), H("a8b8cc"), H("8a9ab0")])
    for x in range(112, 392, 56):
        c.fill(x, 18, 2, 40, STONE[2])
        for d in range(30):
            if (d % 6) < 3:
                c.set(x + 10 + d // 2, 22 + d, H("e8eef6"))
    c.fill(148, 6, 208, 12, GOLD[3]); c.fill(148, 6, 208, 1, GOLD[4]); c.fill(148, 17, 208, 1, GOLD[1])
    r.text(148, 15, 208, "RIZA'NIN SALONU  ·  1987'DEN BERİ", 8, "1b1024")
    c.fill(20, 16, 26, 36, RED[2]); c.fill(24, 20, 18, 16, H("e8b88c")); c.fill(22, 38, 22, 10, BLACK)   # afiş
    c.fill(0, 64, r.W, r.H - 64, H("2a2c34"))
    c.speckle(0, 64, r.W, r.H - 64, [H("33363f"), H("24262d")], 0.12, 9)
    for x in range(0, r.W, 32):
        c.fill(x, 64, 1, r.H - 64, H("1f2128"))
    for y in range(64, r.H, 32):
        c.fill(0, y, r.W, 1, H("1f2128"))
    planks(c, 108, 70, 152, 64, WOOD, 3)                       # halter platformu
    c.fill(108, 70, 152, 1, GOLD[3]); c.fill(108, 133, 152, 1, GOLD[1])
    c.fill(96, 160, 196, 52, H("23252c")); c.fill(96, 160, 196, 1, H("3a3d48"))   # kardiyo köşesi paspası
    tm_y = 178
    for k, x in enumerate((110, 168, 226)):                    # koşu bandı tabanları
        c.fill(x, tm_y, 46, 18, STONE[1]); c.fill(x + 2, tm_y + 2, 42, 14, H("17171c")); c.fill(x, tm_y, 46, 1, STONE[3])
        r.add("belts", [x + 2, tm_y + 2, 42, 14])
    r.borders(door=(20, 32))
    r.prop("reception", reception_desk, 22, 88, foot=16)
    for i, x in enumerate((118, 188)):
        r.prop("squat_rack", squat_rack, x, 64, shadow=False)
        r.solid(x, 104, 6, 6); r.solid(x + 44, 104, 6, 6)
        r.mark("lift_%d" % i, x + 25, 112)
        r.add("bars", [x + 25, 86])
    r.prop("dumbbells", dumbbell_rack, 278, 58, foot=10)
    for i, x in enumerate((110, 168, 226)):
        r.prop("tm_console", treadmill_console, x + 36, tm_y - 16, shadow=False)
        r.solid(x, tm_y, 46, 6)
        r.mark("run_%d" % i, x + 18, tm_y + 12)
    for i, x in enumerate((322, 358)):   # torbalar üst sırada, dambıl rafıyla su sebili arasında
        r.prop("bag", punching_bag, x, 72)
        r.solid(x + 2, 118, 12, 6)
        r.mark("bag_%d" % i, x - 8, 126)
        r.add("bag_pos", [x + 8, 72])
    r.prop("water_cooler", water_cooler, 388, 40, foot=6)
    r.prop("gym_bench", gym_bench, 320, 196, foot=8)
    r.prop("plant_big", lambda: plant(True), 80, 40, foot=4)
    r.mark("spawn", 36, r.H - 22); r.mark("exit", 36, r.H - 4)
    r.mark("riza", 58, 100); r.mark("talk_riza", 60, 140); r.mark("water", 392, 88)
    for (x, y) in ((80, 110), (200, 110), (320, 110), (140, 210), (330, 220)):
        r.add("lamps", [x, y])
    return r.finish()


def shop_window(c, x, y, w, h, light, dark, inside):
    """Dükkan vitrini: koyu çerçeve, içeride sıcak ışık geçişi, içerik (inside), camda çapraz yansıma, denizlik."""
    c.fill(x - 3, y - 3, w + 6, h + 6, H("2c2636")); c.fill(x - 2, y - 2, w + 4, h + 4, H("4a4258"))
    c.grad_v(x, y, w, h, [light, dark])
    inside(x, y, w, h)
    for i in range(0, w + h, 22):   # cam yansıması
        for k in range(4):
            for d in range(h):
                px_, py_ = x + i - k - d // 2, y + d
                if x <= px_ < x + w and (d + k) % 6 < 3:
                    col = c.px[py_][px_]
                    c.px[py_][px_] = (min(255, col[0] + 22), min(255, col[1] + 22), min(255, col[2] + 26), 255)
    c.fill(x - 4, y + h + 2, w + 8, 3, H("6a6458")); c.fill(x - 4, y + h + 2, w + 8, 1, H("9a948a"))


def a_frame_sign():
    """Kafenin kaldırımdaki menü tahtası."""
    c = Painter(16, 22)
    c.fill(1, 0, 14, 18, WOOD[2]); c.fill(2, 1, 12, 15, H("24302a"))
    for k in range(4):
        c.fill(4, 4 + k * 3, 6 + (k * 3) % 4, 1, WHITE)
    c.fill(4, 2, 8, 1, GOLD[4])
    c.fill(1, 18, 2, 4, WOOD[1]); c.fill(13, 18, 2, 4, WOOD[1])
    return c


def planter():
    """Kaldırım saksısı: beton kutu, çiçekler."""
    c = Painter(30, 18)
    c.fill(0, 6, 30, 12, STONE[4]); c.fill(0, 6, 30, 1, STONE[5]); c.fill(0, 16, 30, 2, STONE[2])
    rng = random.Random(8)
    for _ in range(26):
        x, y = rng.randint(1, 28), rng.randint(0, 7)
        c.set(x, y, GREEN[rng.choice((1, 2, 3))])
    for _ in range(9):
        c.set(rng.randint(2, 27), rng.randint(0, 5), rng.choice([RED[4], GOLD[4], WHITE, H("f4a6c0")]))
    return c


# 3x5 piksel harfler (plaket yazıları); M 5 geniş, İ'nin noktası üstte
GLYPHS = {"M": ["1...1", "11.11", "1.1.1", "1...1", "1...1"], "E": ["111", "1..", "11.", "1..", "111"],
          "S": ["111", "1..", "111", "..1", "111"], "İ": ["1", "1", "1", "1", "1"]}


def pixel_text(c, text, cx, y, col):
    """Ortalanmış küçük piksel yazı (y: harflerin üstü; İ'nin noktası bir üstte)."""
    w = sum(len(GLYPHS[ch][0]) for ch in text) + len(text) - 1
    x = cx - w // 2
    for ch in text:
        g = GLYPHS[ch]
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == "1":
                    c.set(x + gx, y + gy, col)
        if ch == "İ":
            c.set(x, y - 2, col)
        x += len(g[0]) + 1


def messi_art():
    """PixelLab büstü (Arjantin forması), kaidedeki altın plakete "MESSİ" yazılır."""
    c = pixellab_art("messi_bust")
    gold = [(x, y) for y in range(c.h) for x in range(c.w)
            if c.px[y][x][3] and c.px[y][x][0] > 170 and c.px[y][x][1] > 120 and c.px[y][x][2] < 110 and y > c.h // 2]
    xs, ys = [p[0] for p in gold], [p[1] for p in gold]
    cx, cy = (min(xs) + max(xs) + 1) // 2, (min(ys) + max(ys) + 1) // 2
    c.fill(cx - 13, cy - 5, 26, 11, H("6a4a14"))                                  # yazıya yetecek büyüklükte plaket
    c.fill(cx - 12, cy - 4, 24, 9, H("e8b830")); c.fill(cx - 12, cy - 4, 24, 1, H("f8dc70"))
    pixel_text(c, "MESSİ", cx, cy - 1, H("4a2a10"))
    return c


def messi_bust():
    """Çarşı meydanındaki Messi büstü, altında küçük çiçeklik."""
    art = messi_art()
    c = Painter(art.w + 8, art.h + 6)
    c.fill(0, art.h - 2, art.w + 8, 8, H("8a8478")); c.fill(0, art.h - 2, art.w + 8, 1, H("b8b2a4"))
    for x in range(2, art.w + 6, 3):
        c.set(x, art.h + 1, GREEN[2]); c.set(x + 1, art.h + 2, [RED[4], GOLD[4], WHITE][x % 3])
    for y in range(art.h):
        for x in range(art.w):
            if art.px[y][x][3]:
                c.set(x + 4, y, art.px[y][x][:3])
    # konuşma kutusu portresi: yazılı büstün kendisi (64x64 içinde ortalı)
    port = Painter(64, 64)
    ox, oy = (64 - art.w) // 2, (64 - art.h) // 2
    for y in range(art.h):
        for x in range(art.w):
            if art.px[y][x][3]:
                port.set(ox + x, oy + y, art.px[y][x][:3])
    write_png(os.path.join(ROOT, "assets", "sprites", "messi_portrait.png"), port.px)
    return c


def room_carsi():
    """Çarşı: beş dükkan (üstlerinde ikinci kat), kaldırım (ağaç, saksı, bank, Messi büstü), önünde yol."""
    D = 24                                        # ikinci kat payı: her şey bu kadar aşağıda
    r = Room("carsi", 1024, 248, wall_h=96 + D)
    c = r.c
    c.fill(0, 0, r.W, 96 + D, H("3a3346"))
    shops = [(16, 208, H("e2cfa8"), "KAFE YILDIZ", GREEN[1], (RED[3], WHITE)),
             (224, 416, H("9aa0aa"), "KARGO DEPOSU", NAVY[2], None),
             (432, 624, H("b8c8e0"), "DERSHANE", RED[1], (NAVY[3], H("dbe4f0"))),
             (640, 816, H("ecd2da"), "BUTİK MODA", H("6e2850"), (H("6e2850"), H("f0c8d8"))),
             (832, 1008, H("cbb88e"), "SPOR & HIRDAVAT", H("3a3a44"), (GREEN[1], GREEN[3]))]
    rng = random.Random(21)
    for (x0, x1, face, name, sign, awning) in shops:
        w = x1 - x0
        # ikinci kat: sıva, pencereler (perde, saksı, klima), çatı kenarı
        upper = shade(face, 0.92)
        c.fill(x0, 0, w, 6 + D, upper)
        c.fill(x0, 0, w, 3, shade(face, 0.55))
        for wx in range(x0 + 14, x1 - 24, 38):
            c.fill(wx - 1, 6, 22, 18, shade(face, 0.6))
            c.fill(wx, 7, 20, 16, H("4a5a74") if rng.random() < 0.6 else H("f0d890"))
            c.fill(wx, 7, 20, 1, H("8aa0c0"))
            c.fill(wx + 10, 7, 1, 16, shade(face, 0.6))
            c.fill(wx + 1, 8, 4, 10, rng.choice([RED[3], H("e0d8c8"), GREEN[3], NAVY[4]]))   # perde
            c.fill(wx - 2, 24, 24, 2, shade(face, 1.15))                                       # denizlik
            if rng.random() < 0.5:
                c.fill(wx + 2, 22, 16, 2, WOOD[2]); c.set(wx + 4, 21, RED[4]); c.set(wx + 9, 21, GOLD[4]); c.set(wx + 14, 21, RED[4])
            elif rng.random() < 0.6:
                c.fill(wx + 22, 12, 10, 8, STONE[5]); c.fill(wx + 22, 12, 10, 1, WHITE); c.fill(wx + 24, 15, 6, 1, STONE[3])
        if rng.random() < 0.7:   # çatıda çanak anten
            c.circle(x1 - 16, 2, 3, STONE[5]); c.set(x1 - 16, 2, STONE[3])
        # dükkan cephesi
        c.fill(x0, 6 + D, w, 90, face)
        c.bricks(x0, 30 + D, w, 66, [shade(face, 0.7), shade(face, 0.9), face, shade(face, 1.08)], seed=x0)
        c.fill(x0, 6 + D, w, 2, shade(face, 0.6))
        c.fill(x0 + 30, 10 + D, w - 60, 16, sign); c.fill(x0 + 30, 10 + D, w - 60, 1, shade(sign, 1.4))
        c.fill(x0 + 30, 25 + D, w - 60, 1, shade(sign, 0.6))
        r.text(x0 + 30, 22 + D, w - 60, name, 9, "f6d86a")
        r.rect("signs", x0 + 30, 10 + D, w - 60, 16)
        c.fill(x0, 92 + D, w, 4, shade(face, 0.55))
        if awning:
            for k, x in enumerate(range(x0 + 4, x1 - 4, 8)):
                c.fill(x, 30 + D, 8, 9, awning[k % 2])
                c.set(x + 3, 39 + D, awning[k % 2]); c.set(x + 4, 39 + D, awning[k % 2])
            c.fill(x0 + 4, 30 + D, w - 8, 1, shade(awning[0], 1.3))
            c.darken(x0 + 4, 40 + D, w - 8, 3, 0.8)
    for x in (212, 420, 628, 820, 1012):   # dükkan araları: kolon ve yağmur borusu
        c.fill(x - 4, 0, 8, 96 + D, H("2c2636")); c.fill(x - 4, 0, 2, 96 + D, H("3e3650"))
        c.fill(x + 1, 4, 2, 92 + D, STONE[3]); c.fill(x, 4, 4, 2, STONE[4])
    # vitrinler: çerçeve, sıcak iç ışık, içerik, cam yansıması, denizlik (bkz. shop_window)
    def kafe_inside(x, y, w, h):
        for lx in (x + 14, x + 44, x + 74):                                   # sarkan lambalar
            c.fill(lx, y, 1, 8, STONE[1]); c.fill(lx - 3, y + 8, 7, 3, GOLD[3]); c.fill(lx - 2, y + 11, 5, 1, H("fff2b0"))
        c.fill(x, y + h - 12, w, 12, WOOD[2]); c.fill(x, y + h - 12, w, 1, WOOD[4])   # pasta tezgahı
        for k in range(5):
            c.fill(x + 6 + k * 16, y + h - 17, 10, 5, [H("c48a3c"), H("f0d8a0"), H("6b4530"), H("e8745a"), H("f4a6c0")][k])
            c.fill(x + 6 + k * 16, y + h - 17, 10, 1, WHITE)
        for (px_, col) in ((x + 22, H("3a5a8a")), (x + 58, H("8a3a5a"))):  # masalarda oturanlar
            c.circle(px_, y + 17, 3, H("d8a880")); c.fill(px_ - 4, y + 20, 8, 7, col)
            c.fill(px_ + 6, y + 22, 10, 2, WOOD[3])
    shop_window(c, 30, 46 + D, 90, 40, H("ffe6b0"), H("f2c070"), kafe_inside)
    c.fill(144, 46 + D, 30, 50, H("8fb4cc")); c.fill(146, 48 + D, 26, 46, H("cfe7f5")); c.fill(158, 48 + D, 1, 46, STONE[3])
    c.fill(150, 68 + D, 6, 3, GOLD[3]); r.text(146, 58 + D, 26, "AÇIK", 5, "2e7d32")
    # kargo: yarı açık kepenk, içeride koliler
    c.fill(250, 34 + D, 140, 62, H("2a2620"))
    for (bx, by) in ((262, 74), (290, 70), (320, 76), (350, 72)):
        c.fill(bx, by + D, 22, 22, H("c8984e")); c.fill(bx, by + D, 22, 2, H("e0b46a")); c.fill(bx + 9, by + D, 4, 22, H("e8d8a0"))
    c.fill(250, 34 + D, 140, 34, STONE[4])
    for y in range(36, 68, 4):
        c.fill(250, y + D, 140, 1, STONE[3])
    c.fill(250, 66 + D, 140, 2, STONE[2])

    def poster_inside(x, y, w, h, posters):
        for (px_, py_, pw, ph, col, txt) in posters:
            c.fill(x + px_ - 1, y + py_ - 1, pw + 2, ph + 2, STONE[1]); c.fill(x + px_, y + py_, pw, ph, col)
            c.fill(x + px_, y + py_, pw, 2, shade(col, 1.25))
            r.text(x + px_, y + py_ + ph - 3, pw, txt, 5, "1b1024")
    shop_window(c, 450, 44 + D, 50, 34, H("eef4fa"), H("d8e4f0"),
                lambda x, y, w, h: poster_inside(x, y, w, h, [(4, 4, 18, 22, GOLD[3], "YKS"), (26, 4, 20, 16, RED[3], "%100")]))
    shop_window(c, 550, 44 + D, 60, 34, H("eef4fa"), H("d8e4f0"),
                lambda x, y, w, h: poster_inside(x, y, w, h, [(4, 4, 24, 18, GREEN[3], "KAYIT"), (32, 6, 22, 22, NAVY[4], "LGS")]))
    c.fill(510, 44 + D, 30, 52, H("8fb4cc")); c.fill(512, 46 + D, 26, 48, H("cfe7f5"))

    def butik_inside(x, y, w, h):
        for k in range(4):                                                  # spot ışığı konileri
            sx = x + 14 + k * 26
            for d in range(h - 6):
                for xx in range(sx - d // 4, sx - d // 4 + d // 2 + 2):
                    col = c.px[y + d][xx]
                    c.px[y + d][xx] = (min(255, col[0] + 10), min(255, col[1] + 9), min(255, col[2] + 6), 255)
            c.fill(sx - 1, y, 3, 2, STONE[2])
        outfits = ((H("c84060"), RED[1]), (H("3a6ab8"), NAVY[2]), (H("e6b428"), H("6a4a1a")), (H("2a2a30"), BLACK))
        for k, (col, low) in enumerate(outfits):
            mx = x + 10 + k * 26
            c.circle(mx + 4, y + 9, 3, H("e8d8c8"))
            c.fill(mx, y + 13, 9, 14, col); c.fill(mx, y + 13, 9, 1, shade(col, 1.3)); c.fill(mx - 1, y + 14, 1, 8, col); c.fill(mx + 9, y + 14, 1, 8, col)
            c.fill(mx + 1, y + 27, 7, 10, low)
            c.fill(mx + 4, y + 37, 1, 5, STONE[2]); c.fill(mx + 1, y + 41, 7, 2, STONE[2])
            c.fill(mx + 10, y + 20, 5, 4, WHITE); c.set(mx + 12, y + 21, RED[2])   # fiyat etiketi
    shop_window(c, 652, 44 + D, 110, 46, H("fff4f8"), H("f6dde8"), butik_inside)
    c.fill(774, 44 + D, 30, 52, H("8fb4cc")); c.fill(776, 46 + D, 26, 48, H("cfe7f5")); c.fill(788, 46 + D, 1, 48, STONE[3])

    def hirdavat_inside(x, y, w, h):
        c.fill(x, y, w, h - 10, H("b08a5a"))                                 # delikli pano
        for yy in range(y + 3, y + h - 12, 4):
            for xx in range(x + 3, x + w - 2, 4):
                c.set(xx, yy, H("8a6a44"))
        for k in range(4):                                                   # sopalar
            c.fill(x + 6 + k * 4, y + 4, 2, 24, WOOD[2 + k % 2]); c.fill(x + 6 + k * 4, y + 24, 2, 4, BLACK)
        c.fill(x + 26, y + 6, 14, 4, STONE[2]); c.fill(x + 32, y + 10, 2, 14, WOOD[2])    # çekiç
        c.fill(x + 46, y + 8, 10, 10, RED[2]); c.fill(x + 60, y + 8, 10, 10, RED[2])       # boks eldivenleri
        c.fill(x + 46, y + 8, 10, 2, RED[4]); c.fill(x + 60, y + 8, 10, 2, RED[4])
        c.fill(x + 76, y + 6, 16, 3, GOLD[3]); r.text(x + 74, y + 26, 22, "%20", 5, "9e2c34")
        c.fill(x, y + h - 10, w, 10, STONE[3]); c.fill(x, y + h - 10, w, 1, STONE[5])      # alt raf: toplar
        for k in range(6):
            c.circle(x + 8 + k * 15, y + h - 6, 4, [WHITE, H("f59e0b"), WHITE, H("3b82f6"), WHITE, H("f59e0b")][k])
            c.set(x + 7 + k * 15, y + h - 7, BLACK)
    shop_window(c, 842, 44 + D, 100, 42, H("f0ead8"), H("e0d4b8"), hirdavat_inside)
    c.fill(954, 44 + D, 32, 52, H("2a2620")); c.fill(956, 46 + D, 28, 50, H("4a4030"))
    r.rect("windows", 30, 46 + D, 90, 40); r.rect("windows", 450, 44 + D, 50, 34); r.rect("windows", 550, 44 + D, 60, 34)
    r.rect("windows", 652, 44 + D, 110, 46); r.rect("windows", 842, 44 + D, 100, 42)
    # kaldırım (iki tonlu taş), bordür, yol (yaya geçidi)
    for y in range(96 + D, 176 + D, 8):
        off = 8 if (y // 8) % 2 else 0
        c.fill(0, y, r.W, 8, H("b8b2a8"))
        c.fill(0, y, r.W, 1, H("9a948a"))
        for x in range(-off, r.W, 16):
            c.fill(x, y, 1, 8, H("9a948a"))
            c.set(x + 3, y + 3, H("c8c2b8"))
            if (x // 16 + y // 8) % 7 == 0:
                c.fill(x + 1, y + 1, 15, 7, H("aaa49a"))
    c.fill(0, 96 + D, r.W, 3, H("6a6458"))
    c.fill(560, 120 + D, 120, 50, H("c8c2b4"))                      # büstün meydancığı
    for x in range(560, 680, 10):
        for y in range(120 + D, 170 + D, 10):
            c.fill(x, y, 10, 1, H("b0aa9c")); c.fill(x, y, 1, 10, H("b0aa9c"))
    c.fill(0, 176 + D, r.W, 6, STONE[5]); c.fill(0, 176 + D, r.W, 1, WHITE); c.fill(0, 181 + D, r.W, 1, STONE[2])
    c.fill(0, 182 + D, r.W, 42, H("3a3c44"))
    c.speckle(0, 182 + D, r.W, 42, [H("44464e"), H("33353c")], 0.15, 4)
    for x in range(0, r.W, 40):
        if not 584 <= x <= 664:
            c.fill(x, 202 + D, 22, 2, H("e8e4d0"))
    for x in range(586, 664, 8):                                     # yaya geçidi
        c.fill(x, 184 + D, 5, 38, H("e8e4d0"))
    r.solid(0, 0, r.W, 100 + D)
    r.solid(0, 176 + D, r.W, 48)
    r.solid(r.W - 4, 0, 4, r.H)
    r.prop("lamp_post", lamp_post, 214, 104 + D, foot=4)
    r.prop("lamp_post", lamp_post, 420, 104 + D, foot=4)
    r.prop("lamp_post", lamp_post, 822, 104 + D, foot=4)
    r.prop("cafe_table", cafe_table_out, 40, 112 + D, foot=6)
    r.prop("cafe_table", cafe_table_out, 92, 134 + D, foot=6)
    r.prop("a_frame", a_frame_sign, 126, 128 + D, foot=4)
    r.prop("boxes", boxes, 384, 92 + D, foot=14)
    r.prop("street_tree", street_tree, 236, 96 + D, foot=8)
    r.prop("street_tree", street_tree, 724, 96 + D, foot=8)
    r.prop("messi_bust", messi_bust, 596, 102 + D, foot=12)
    r.prop("park_bench", park_bench, 452, 138 + D, foot=8)
    r.prop("park_bench", park_bench, 690, 140 + D, foot=8)
    r.prop("planter", planter, 870, 150 + D, foot=6)
    r.prop("trash_bin", trash_bin, 990, 150 + D, foot=4)
    r.prop("trash_bin", trash_bin, 196, 150 + D, foot=4)
    r.mark("bust", 620, 160 + D)
    r.mark("spawn", 22, 140 + D); r.mark("exit", 4, 140 + D)
    r.mark("melek", 160, 110 + D); r.mark("talk_melek", 160, 136 + D)
    r.mark("bayram", 320, 110 + D); r.mark("talk_bayram", 320, 136 + D)
    r.mark("mudur", 526, 110 + D); r.mark("talk_mudur", 526, 136 + D)
    r.mark("door_butik", 789, 104 + D); r.mark("from_butik", 789, 122 + D)
    r.mark("door_hirdavat", 970, 104 + D); r.mark("from_hirdavat", 970, 122 + D)
    r.add("lamps", [221, 108 + D]); r.add("lamps", [427, 108 + D]); r.add("lamps", [829, 108 + D])
    return r.finish()


def room_kampus_kafe():
    """Büyük kampüs kafesi: 18 masa (3 sıra x 6, her biri 4 kişilik), uzun tezgah.
    crowd_seats / crowd_stand: oyun her girişte bunları saate göre doldurur (bkz. place.gd _crowd_level)."""
    r = Room("kampus_kafe", 640, 272, wall_h=64)
    c = r.c
    r.back_wall(H("a85a40"), base=WOOD[1])
    c.bricks(0, 12, r.W, 46, [H("6e2f22"), H("8e4a34"), H("a85a40"), H("b86a4c")], bw=10, bh=5, seed=5)
    for x in (150, 254, 358, 462, 566):
        r.window(x, 12, 64, 38, outside="green")
    c.fill(22, 12, 76, 32, GREEN[0]); c.fill(22, 12, 76, 2, WOOD[3]); c.fill(22, 42, 76, 2, WOOD[3])
    for k in range(4):
        c.fill(28, 22 + k * 5, 30 + (k * 7) % 20, 1, WHITE); c.fill(76, 22 + k * 5, 14, 1, GOLD[4])
    r.text(22, 20, 76, "MENÜ", 8, "f6d86a")
    planks(c, 0, 64, r.W, r.H - 64, [WOOD[0], WOOD[1], H("7a5038"), H("9a6a48"), WOOD[4], WOOD[5]], 11)
    rug(c, 146, 84, 470, 176, TEAL, GOLD[4], motif=False)
    r.borders(door=(20, 30))
    r.prop("espresso_counter", espresso_counter, 14, 68, foot=18)
    for row, ty in enumerate((92, 148, 204)):   # 4 kişilik masalar: ikisi üstte, ikisi altta
        for col, tx in enumerate((160, 236, 312, 388, 464, 540)):
            for sx in (2, 20):
                r.prop("chair_top", chair_top, tx + sx, ty - 14, shadow=False)
            r.prop("table_sq", lambda: table(40, 18), tx - 2, ty, foot=18)
            r.add("tables", [tx, ty])
            for sx in (9, 27):
                r.add("crowd_seats", [tx + sx, ty + 10, "down"])
                r.add("crowd_seats", [tx + sx, ty + 38, "up"])
    r.prop("plant_big", lambda: plant(True), 124, 50, foot=4)
    r.prop("plant_big", lambda: plant(True), 612, 52, foot=4)
    r.prop("plant", plant, 612, 236, foot=4)
    r.prop("plant", plant, 100, 236, foot=4)
    r.mark("barista", 60, 82); r.mark("talk_barista", 60, 126)
    r.mark("friends", 169, 102); r.mark("friends2", 169, 130); r.mark("talk_friends", 220, 120)
    r.mark("elif", 549, 102); r.mark("talk_elif", 600, 120)
    r.mark("window", 418, 72)
    for (x, y) in ((92, 130), (104, 140), (34, 132), (140, 150), (300, 72), (500, 74), (620, 150), (140, 230)):
        r.add("crowd_stand", [x, y])
    r.mark("spawn", 35, r.H - 22); r.mark("exit", 35, r.H - 4)
    for (x, y) in ((120, 120), (240, 120), (360, 120), (480, 120), (590, 120), (240, 220), (480, 220)):
        r.add("lamps", [x, y])
    return r.finish()


def room_butik():
    """Butik Moda: iki sıra askılık (her birinde bir kıyafet), ayna, deneme kabini, kasa."""
    import make_topdown as td
    looks = td.all_looks()
    outfits = [k for k in td.OUTFITS]
    r = Room("butik", 456, 216, wall_h=64)
    c = r.c
    r.back_wall(H("ecd2da"), base=H("8a4a64"))
    for x in range(0, r.W, 14):
        c.fill(x, 10, 1, 46, H("e0c0cc"))
    c.fill(150, 12, 120, 14, H("6e2850")); c.fill(150, 12, 120, 1, H("a04878"))
    r.text(150, 23, 120, "BUTİK MODA", 9, "f6d0e0")
    c.fill(24, 14, 40, 44, STONE[4]); c.grad_v(26, 16, 36, 40, [H("dfe8f2"), H("c8d4e4"), H("aab8cc")])   # ayna
    for d in range(20):
        if d % 5 < 3:
            c.set(34 + d // 2, 18 + d, WHITE)
    c.fill(392, 10, 52, 50, H("6e2850")); c.fill(394, 12, 48, 46, H("8a3a66"))                         # kabin perdesi
    for x in range(396, 442, 6):
        c.fill(x, 12, 2, 46, H("a04878"))
    checker(c, 0, 64, r.W, 152, H("f2ece6"), H("e2d8d2"), size=16)
    rug(c, 300, 150, 96, 40, RED, GOLD[4])
    r.borders(door=(20, 30))
    r.prop("butik_counter", lambda: reception_desk(64), 334, 84, foot=16)
    r.prop("plant_big", lambda: plant(True), 290, 46, foot=4)
    rows = [(24, 74), (24, 136)]
    k = 0
    for (x0, y0) in rows:
        for col in range(8):
            if k >= len(outfits):
                break
            oid = outfits[k]
            x = x0 + col * 36
            r.prop("rack_" + oid, lambda o=looks["player_" + oid], i=oid: clothes_rack(o, i), x, y0, foot=6)
            r.mark("item_" + oid, x + 16, y0 + 56)
            k += 1
    r.mark("selin", 366, 98); r.mark("talk_selin", 366, 136)
    r.mark("spawn", 35, 194); r.mark("exit", 35, 212)
    for x in (100, 220, 340):
        r.add("lamps", [x, 120])
    return r.finish()


def room_hirdavat():
    """Spor & Hırdavat: duvarda silah panoları, alet rafları, eldiven ve top kutuları, kasa."""
    r = Room("hirdavat", 384, 200, wall_h=56)
    c = r.c
    r.back_wall(H("8a96a8"), base=H("3a4250"))
    c.fill(200, 8, 170, 40, H("b08a5a"))                       # duvar boyu alet panosu
    for y in range(12, 46, 5):
        for x in range(204, 368, 5):
            c.set(x, y, H("6a5034"))
    rng = random.Random(9)
    for k in range(12):
        x, y = 208 + k * 13, 14 + (k % 3) * 10
        c.fill(x, y, 2, 10, WOOD[2]); c.fill(x - 2, y, 6, 3, rng.choice([STONE[2], RED[2], GOLD[2]]))
    c.fill(110, 12, 80, 14, H("3a3a44")); c.fill(110, 12, 80, 1, H("6a6a74"))
    r.text(110, 23, 80, "SPOR & HIRDAVAT", 7, "f6d86a")
    concrete(c, 0, 56, r.W, 144, H("b8b4aa"), 3, grid=32)
    r.borders(door=(20, 30))
    for k, wid in enumerate(("musta", "sopa", "bicak")):
        x = 12 + k * 42
        r.prop("wdisp_" + wid, lambda w=wid: weapon_display(w), x, 48, foot=4)
        r.mark("item_" + wid, x + 18, 98)
    r.prop("tool_shelf", tool_shelf, 120, 110, foot=10)
    r.prop("boxes", boxes, 40, 128, foot=14)
    r.prop("hirdavat_counter", lambda: reception_desk(64), 290, 98, foot=16)
    r.mark("kemal", 322, 112); r.mark("talk_kemal", 322, 150)
    r.mark("spawn", 35, 178); r.mark("exit", 35, 196)
    for x in (100, 260):
        r.add("lamps", [x, 120])
    return r.finish()


GALERI_CARS = ["sahin", "toros", "doblo", "egea", "passat", "golf", "bmw", "mercedes"]   # data/places.gd galeri ile aynı sıra


def car_front(cid):
    """Galeride bize bakan araba: assets/pixellab/cars/car_<id>.png (boş kenarlar kırpılır)."""
    import pngio
    px = pngio.read_png(os.path.join(ROOT, "assets", "pixellab", "cars", "car_%s.png" % cid))
    ys = [y for y, row in enumerate(px) if any(c[3] > 40 for c in row)]
    xs = [x for x in range(len(px[0])) if any(px[y][x][3] > 40 for y in range(len(px)))]
    c = Painter(xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1)
    for y in range(c.h):
        for x in range(c.w):
            p = px[ys[0] + y][xs[0] + x]
            if p[3] > 40:
                c.set(x, y, p[:3])
    return c


def room_galeri():
    r = Room("galeri", 704, 208, wall_h=72)
    c = r.c
    r.back_wall(STONE[2], base=STONE[1])
    for x in range(124, r.W - 100, 112):
        r.window(x, 20, 100, 42, outside="city", frame=[STONE[0], STONE[1], STONE[2], STONE[3], STONE[4]])
    c.fill(24, 18, 70, 46, NAVY[2]); c.fill(28, 22, 62, 38, NAVY[3])
    c.fill(220, 4, 300, 12, GOLD[3]); c.fill(220, 4, 300, 1, GOLD[4])
    r.text(220, 14, 300, "NECDET OTO  ·  KİMSEDE YOK BU FİYATLAR", 8, "1b1024")
    checker(c, 0, 72, r.W, 136, H("d8dce4"), H("c4c8d2"), size=32)
    for x in range(0, r.W, 32):   # parlak zemin yansıması
        for d in range(0, 136, 3):
            if (d // 3) % 4 == 0:
                c.set(x + 6 + d // 6, 72 + d, H("eef0f6"))
    r.borders(door=(20, 32))
    r.prop("desk_dealer", lambda: reception_desk(60), 22, 96, foot=16)
    r.prop("plant_big", lambda: plant(True), 96, 60, foot=4)
    for i, cid in enumerate(GALERI_CARS):   # arabalar bize bakar; fiyat arabaya tıklayınca görünür
        cx = 150 + i * 70
        img = car_front(cid)
        x, y = cx - img.w // 2, 136 - img.h
        c.darken(x + 2, 132, img.w - 4, 6, 0.8)          # zemindeki gölge
        r.prop("carfront_" + cid, lambda cid=cid: car_front(cid), x, y, foot=10)
        r.mark("car_%d" % i, cx, 156)
    r.mark("necdet", 52, 108); r.mark("talk_necdet", 54, 146)
    r.mark("spawn", 36, 186); r.mark("exit", 36, 204)
    for x in range(140, r.W - 20, 110):
        r.add("lamps", [x, 120])
    return r.finish()


def barber_chair():
    """Berber koltuğu (arkadan): krom ayak, kırmızı deri oturak ve sırt, kolçaklar, ayak dayama."""
    c = Painter(26, 30)
    c.fill(9, 26, 8, 3, STONE[4]); c.fill(5, 28, 16, 2, STONE[3])                 # ayak
    c.fill(12, 18, 2, 9, STONE[5])
    c.fill(3, 4, 20, 14, H("9e2c34")); c.fill(3, 4, 20, 1, H("c84438")); c.fill(4, 5, 2, 12, H("b83a40"))   # sırt
    c.fill(9, 0, 8, 5, H("7a222a")); c.fill(9, 0, 8, 1, H("9e2c34"))             # başlık
    c.fill(0, 12, 3, 8, STONE[5]); c.fill(23, 12, 3, 8, STONE[5])                # kolçaklar
    c.fill(2, 18, 22, 3, H("7a222a"))
    return c


def barber_pole():
    """Döner berber direği: kırmızı-beyaz-mavi şerit, krom uçlar."""
    c = Painter(10, 30)
    c.fill(1, 0, 8, 3, STONE[5]); c.fill(1, 27, 8, 3, STONE[5])
    c.fill(2, 3, 6, 24, WHITE)
    for y in range(3, 27):
        for x in range(2, 8):
            k = (x + y) % 8
            if k < 2:
                c.set(x, y, RED[3])
            elif k < 4:
                c.set(x, y, NAVY[4])
    c.fill(2, 3, 1, 24, H("dcdad4"))
    return c


def room_berber():
    """Berber Sabri: aynalar önünde üç koltuk (müşteriler saate göre oturur), bekleme kanepesi, direk, afişler."""
    r = Room("berber", 336, 224, wall_h=64)
    c = r.c
    r.back_wall(H("e8dcc4"), base=WOOD[1])
    c.fill(0, 40, r.W, 16, WOOD[2]); c.fill(0, 40, r.W, 1, WOOD[4])                       # ahşap lambri
    for x in range(0, r.W, 12):
        c.fill(x, 41, 1, 15, WOOD[1])
    for k, x in enumerate((66, 146, 226)):                                                 # aynalar ve şişe rafı
        c.fill(x - 2, 8, 52, 32, WOOD[1]); c.fill(x, 10, 48, 28, H("b8d0e0"))
        c.grad_v(x, 10, 48, 28, [H("d8e8f2"), H("b8d0e0"), H("98b4c8")])
        for d in range(20):
            if d % 5 < 3:
                c.set(x + 6 + d // 2, 12 + d, WHITE)
        c.fill(x - 2, 40, 52, 3, STONE[4]); c.fill(x - 2, 40, 52, 1, STONE[5])
        rng = random.Random(x)
        for bx in range(x, x + 46, 7):
            col = rng.choice([TEAL[3], GOLD[3], RED[3], NAVY[4], GREEN[3]])
            c.fill(bx, 34, 4, 6, col); c.fill(bx + 1, 32, 2, 2, STONE[2])
    c.fill(10, 10, 40, 26, WHITE); c.fill(10, 10, 40, 1, STONE[3])                       # saç modeli afişi
    for k in range(3):
        c.circle(17 + k * 12, 20, 4, H("e8c8a8")); c.fill(13 + k * 12, 15, 9, 3 + k, [BLACK, WOOD[1], GOLD[2]][k])
    r.text(10, 33, 40, "MODELLER", 5, "9e2c34")
    c.fill(286, 10, 42, 14, H("9e2c34")); c.fill(286, 10, 42, 1, H("c84438"))
    r.text(286, 20, 42, "BERBER SABRİ", 5, "f6d86a")
    checker(c, 0, 64, r.W, r.H - 64, H("ece8e0"), H("2a2a30"), size=16)
    rng = random.Random(4)
    for (cx, cy) in ((90, 100), (170, 100), (250, 100)):                                  # yerde saç kırpıntıları
        for _ in range(26):
            c.set(cx + rng.randint(-14, 14), cy + rng.randint(-6, 8), rng.choice([BLACK, WOOD[1], H("3a2a22")]))
    r.borders(door=(150, 34))
    r.prop("barber_pole", barber_pole, 128, 26, foot=4)
    for k, x in enumerate((77, 157, 237)):
        r.prop("barber_chair", barber_chair, x, 72, foot=6)
        r.add("crowd_seats", [x + 13, 92, "up"])
    r.prop("sofa", sofa, 264, 150, foot=8)
    r.prop("plant", plant, 316, 150, foot=4)
    r.prop("plant_big", lambda: plant(True), 6, 56, foot=4)
    for x in (274, 290, 306):
        r.add("crowd_seats", [x, 168, "down"])
    for (x, y) in ((44, 150), (60, 170)):
        r.add("crowd_stand", [x, y])
    r.mark("sabri", 196, 98); r.mark("talk_sabri", 196, 130)
    r.mark("cirak", 276, 98)
    r.mark("spawn", 166, r.H - 22); r.mark("exit", 166, r.H - 4)
    for (x, y) in ((90, 110), (170, 110), (250, 110), (290, 180)):
        r.add("lamps", [x, y])
    return r.finish()


def room_amfi():
    r = Room("amfi", 480, 272, wall_h=48)
    c = r.c
    r.back_wall(H("c8c4bc"))
    c.fill(116, 8, 248, 34, WOOD[1]); c.fill(118, 10, 244, 30, H("2a4a3a"))
    rng = random.Random(8)
    for row in range(4):
        x = 124
        while x < 350:
            ln = rng.randint(4, 14)
            c.fill(x, 15 + row * 6, ln, 1, H("d8e8d8")); x += ln + rng.randint(3, 8)
    c.fill(116, 40, 248, 3, WOOD[3]); c.fill(150, 40, 10, 2, WHITE)
    planks(c, 0, 48, r.W, 56, WOOD, 2)
    tiers = [H("4a3a5a"), H("423350"), H("3a2c46"), H("33263e")]
    for k in range(4):
        y0 = 104 + k * 40
        c.fill(0, y0, r.W, 40, tiers[k])
        c.speckle(0, y0, r.W, 40, [shade(tiers[k], 1.1)], 0.05, k)
        c.fill(0, y0, r.W, 2, shade(tiers[k], 1.4)); c.fill(0, y0 + 2, r.W, 1, shade(tiers[k], 0.7))
        c.fill(64, y0 + 24, 352, 6, H("27202e")); c.fill(64, y0 + 24, 352, 1, H("4a3e58"))   # oturma bankı
        for ax in (24, 420):   # yan koridor basamakları
            c.fill(ax, y0, 36, 40, H("6a6270")); c.fill(ax, y0, 36, 2, H("9a92a0"))
            c.fill(ax, y0 + 20, 36, 1, H("8a8290"))
    r.borders(door=(424, 32))
    r.prop("lectern", lectern, 228, 56, foot=8)
    for k in range(4):
        y0 = 104 + k * 40
        r.prop("lecture_desk", lambda: lecture_desk(352), 64, y0, foot=8)
        for x in (96, 152, 208, 272, 328, 384):
            r.add("seats", [x, y0 + 30])
    r.mark("lecturer", 204, 84)
    r.mark("spawn", 440, 252); r.mark("exit", 440, 268)
    return r.finish()


def room_yemekhane():
    r = Room("yemekhane", 512, 288)   # üç sıra uzun masa
    c = r.c
    r.back_wall(H("e8e4d8"))
    c.tiles(0, 30, r.W, 20, H("f4f2ec"), H("e4e8ee"), H("c8ccd4"), size=6)
    c.fill(32, 10, 150, 24, BLACK); c.fill(34, 12, 146, 20, H("1b2a22"))
    r.text(34, 25, 146, "BUGÜN: KURU FASULYE · PİLAV", 7, "f6d86a")
    for x in (300, 364, 428):
        r.window(x, 10, 52, 26, outside="green")
    concrete(c, 0, 56, r.W, r.H - 56, H("d4cfc4"), 6, grid=24)
    c.speckle(0, 56, r.W, r.H - 56, [H("b8b2a4"), H("8a8478"), H("e8e2d4")], 0.06, 12)
    r.borders(door=(24, 32))
    r.prop("serving_counter", serving_counter, 12, 62, foot=24)
    r.prop("tray_stack", tray_stack, 196, 82, foot=6)
    for (tx, ty) in ((232, 92), (376, 92), (232, 156), (376, 156), (232, 220), (376, 220)):
        for sx in (14, 50, 86):
            r.prop("chair_top", chair_top, tx + sx - 1, ty - 14, shadow=False)
        r.prop("long_table", lambda: table(112, 16, [STONE[1], STONE[2], STONE[3], STONE[4], STONE[5], STONE[6]]), tx, ty, foot=10)
        c.fill(tx + 4, ty + 34, 104, 5, WOOD[2]); c.fill(tx + 4, ty + 34, 104, 1, WOOD[4])   # alt banklar
        for sx in (20, 56, 92):
            r.add("seats_top", [tx + sx, ty + 10])
            r.add("seats_bottom", [tx + sx, ty + 40])
    r.mark("cook", 96, 76); r.mark("tray", 120, 118)
    r.mark("spawn", 40, r.H - 20); r.mark("exit", 40, r.H - 4)
    for (x, y) in ((120, 120), (290, 120), (430, 120), (290, 220), (430, 220)):
        r.add("lamps", [x, y])
    return r.finish()


def room_restoran():
    r = Room("restoran", 576, 224)
    c = r.c
    r.back_wall(H("d8c0a0"), base=WOOD[1])
    c.tiles(0, 8, 184, 44, WHITE, H("dde6ea"), H("b8c4cc"), size=8)
    for x in (236, 330, 424, 518):
        r.window(x, 12, 44, 28)
    c.fill(196, 14, 26, 20, GOLD[2]); c.fill(198, 16, 22, 16, H("6a8a5a"))   # tablo
    checker(c, 0, 56, 184, 52, H("c8ccd2"), H("aeb4bc"), size=12)
    planks(c, 184, 56, r.W - 184, 168, WOOD, 21)
    planks(c, 0, 108, 184, 116, WOOD, 22)
    c.fill(184, 56, 2, 52, STONE[2])
    r.borders(door=(140, 30))
    r.prop("stove", stove, 14, 30, foot=12)
    r.prop("fridge", fridge, 92, 18, foot=8)
    r.prop("kitchen_counter", lambda: kitchen_counter(56), 120, 34, foot=14)
    r.prop("pass_counter", pass_counter, 8, 92, foot=16)
    r.solid(176, 56, 10, 52)
    for k in range(3):
        r.add("pass", [28 + k * 36, 98])
    tables = [(240, 100), (352, 100), (464, 100), (240, 162), (352, 162), (464, 162)]
    for (tx, ty) in tables:
        r.prop("chair_top", chair_top, tx + 9, ty - 14, shadow=False)
        r.prop("table_r", lambda: table(32, 18), tx, ty, foot=10)
        r.add("tables", [tx + 16, ty + 10])      # müşterinin oturduğu yer (masanın üst tarafı)
        r.add("serve", [tx + 16, ty + 40])       # garsonun durduğu yer
    r.prop("plant_big", lambda: plant(True), 546, 60, foot=4)
    r.prop("plant", plant, 196, 196, foot=4)
    r.mark("pickup", 64, 136)
    r.mark("cook0", 40, 86); r.mark("cook1", 120, 86)
    r.mark("spawn", 110, 170)
    for x in (260, 372, 484):
        r.add("lamps", [x, 120])
    r.add("lamps", [90, 70])
    return r.finish()


def room_durak():
    r = Room("durak", 960, 216, wall_h=0)
    c = r.c
    c.fill(0, 0, r.W, 10, STONE[5])
    for x in range(0, r.W, 24):
        c.fill(x, 0, 12, 10, STONE[4])
    c.fill(0, 9, r.W, 1, STONE[2])
    c.fill(0, 10, r.W, 62, H("3a3c44"))
    c.speckle(0, 10, r.W, 62, [H("44464e"), H("30323a")], 0.12, 2)
    c.fill(0, 12, r.W, 1, WHITE)
    for x in range(0, r.W, 60):
        c.fill(x, 40, 30, 1, H("e8e4d0"))
    c.fill(0, 72, r.W, 3, WHITE)
    c.fill(0, 75, r.W, 6, GOLD[3])
    for x in range(0, r.W, 3):
        c.set(x, 77, GOLD[2]); c.set(x + 1, 79, GOLD[2])
    concrete(c, 0, 81, r.W, 121, H("a8a49c"), 5, grid=32)
    c.fill(0, 81, r.W, 2, shade(H("a8a49c"), 0.7))
    c.fill(0, 200, r.W, 16, STONE[1])                       # arka korkuluk ve reklam camları
    for x in range(0, r.W, 80):
        c.fill(x + 4, 202, 72, 12, H("2b3a55")); c.fill(x + 6, 204, 30, 8, [RED[3], GOLD[3], TEAL[3], GREEN[3]][(x // 80) % 4])
    c.fill(0, 200, r.W, 2, STONE[3])
    c.fill(892, 81, 68, 119, H("8a867e"))                    # turnike arkası
    for y in range(81, 200, 6):
        c.fill(892, y, 68, 1, H("7a766e"))
    r.solid(0, 0, r.W, 84)
    r.solid(0, 196, r.W, 20)
    for y in (86, 110, 168):
        r.prop("turnstile", turnstile, 880, y, foot=6)
    for x in range(40, 880, 160):
        r.prop("pillar", pillar, x, 126, foot=6)
    r.prop("info_board", info_board, 616, 138, foot=4)
    r.prop("station_sign", station_sign, 290, 152, foot=4)
    r.prop("park_bench", park_bench, 120, 176, foot=8)
    r.prop("park_bench", park_bench, 740, 176, foot=8)
    r.mark("board_text", 618, 150); r.mark("sign_text", 292, 166)
    r.mark("spawn", 860, 150); r.mark("simitci", 760, 168)
    for x in range(80, 960, 160):
        r.add("lamps", [x, 110])
    return r.finish()


METRO_DOORS = (130, 400, 670)
METRO_JOINT = 300                     # körük (iki vagonun birleştiği yer)


def room_metrobus():
    """Körüklü metrobüs: koridorun iki yanında 2+2 koltuk sıraları (hepsi gidiş yönüne bakar),
    kapı önlerinde ayakta durma alanları, sarı tutunma direkleri, kart okuyucular, önde şoför kabini."""
    r = Room("metrobus", 800, 224, wall_h=0)
    c = r.c
    W = r.W
    # dışarısı (0-40 ve 184-224) şeffaf: oyun akan yolu çizer
    c.fill(0, 40, W, 8, H("5c6270")); c.fill(0, 40, W, 1, STONE[5])          # tavan kenarı
    c.fill(0, 48, W, 32, H("dcdfe6"))
    for x in range(10, W - 60, 74):
        if abs(x + 32 - METRO_JOINT) < 40:
            continue
        c.clear(x, 50, 64, 22)                                                 # geniş camlar
        c.fill(x - 1, 49, 66, 1, STONE[3]); c.fill(x - 1, 72, 66, 2, STONE[3])
        c.fill(x + 31, 50, 2, 22, STONE[4])                                    # cam ortası (sürgülü üst cam)
        r.rect("windows", x, 50, 64, 22)
    c.clear(W - 50, 50, 40, 26)                                               # ön cam
    c.fill(0, 74, W, 6, H("b4bac6")); c.fill(0, 79, W, 2, H("5c6270"))
    # zemin: kaymaz gri kaplama, kapı önlerinde sarı çizgi
    c.fill(0, 81, W, 95, H("6a6e78"))
    for y in range(84, 176, 4):
        c.fill(0, y, W, 1, H("60646e"))
    c.speckle(0, 81, W, 95, [H("767a84"), H("5a5e68")], 0.04, 1)
    c.fill(0, 117, W, 1, H("7c808a")); c.fill(0, 151, W, 1, H("5a5e68"))      # koridor kenarları
    # körük: kauçuk körük ve döner tabla
    c.fill(METRO_JOINT - 12, 40, 24, 144, H("2a2a33"))
    for y in range(42, 182, 3):
        c.fill(METRO_JOINT - 12, y, 24, 1, H("3a3a44"))
    for yy in range(-30, 31):
        for xx in range(-11, 12):
            if (xx / 11.5) ** 2 + (yy / 30.0) ** 2 <= 1:
                c.set(METRO_JOINT + xx, 133 + yy, H("4a4450") if (xx + yy) % 4 else H("56505c"))
    # yakın taraf duvarı ve kapılar
    c.fill(0, 176, W, 8, H("f4f4f6")); c.fill(0, 176, W, 1, WHITE); c.fill(0, 182, W, 2, H("c8102e"))
    for dx in METRO_DOORS:
        c.fill(dx - 18, 168, 36, 16, H("4a4e58")); c.fill(dx - 18, 168, 36, 2, GOLD[3])
        c.fill(dx - 18, 182, 36, 2, GOLD[2]); c.fill(dx - 1, 172, 2, 12, STONE[2])
        r.add("doors", [dx, 170])
        c.fill(dx - 30, 160, 60, 1, GOLD[3])                                   # "kapıdan uzak dur" çizgisi
    # tekerlekli sandalye alanı (orta kapının karşısı)
    c.fill(384, 86, 32, 22, H("2f5aa0")); c.fill(386, 88, 28, 18, H("3a6ab8"))
    c.circle(398, 98, 4, WHITE); c.circle(398, 98, 2, H("3a6ab8")); c.fill(400, 91, 2, 4, WHITE)
    # şoför kabini
    c.fill(W - 58, 81, 4, 95, STONE[2]); c.fill(W - 58, 81, 1, 95, STONE[4])
    c.fill(W - 54, 81, 48, 95, H("5a5e68"))
    c.fill(0, 40, 6, 144, EDGE); c.fill(W - 6, 40, 6, 144, EDGE)
    r.solid(0, 0, W, 90)
    r.solid(0, 176, W, 48)
    r.solid(0, 0, 8, r.H)
    r.solid(W - 58, 0, 58, r.H)
    # koltuklar: 2+2, gidiş yönüne bakar; kapı önleri ve körük boş
    seat_rows = [(100, False), (114, True), (158, True), (172, False)]
    for sx in range(26, W - 70, 26):
        if abs(sx - METRO_JOINT) < 22:
            continue
        for (sy, aisle) in seat_rows:
            near = sy > 130
            if near and any(abs(sx - d) < 36 for d in METRO_DOORS):
                continue
            if not near and abs(sx - 400) < 30:
                continue
            key = "metro_seat_a" if aisle else "metro_seat"
            r.prop(key, lambda a=aisle: metro_seat(a), sx - 9, sy - 15, shadow=False, base=sy - 1)
            r.solid(sx - 9, sy - 6, 15, 7)
            r.add("seats", [sx, sy])
    # ayakta durma yerleri, direkler, kart okuyucular
    for d in METRO_DOORS:
        for (px, py) in ((d - 22, 132), (d + 22, 142)):
            r.prop("metro_pole", metro_pole, px - 1, py - 57, foot=2)
            r.add("poles", [px, py])
        r.prop("validator", validator, d + 26, 136, foot=3)
        for x in range(d - 26, d + 27, 13):
            for y in (124, 138, 152, 164):
                r.add("stand", [x, y])
    for x in range(40, W - 70, 46):
        r.add("stand", [x, 134])
    r.prop("metro_pole", metro_pole, METRO_JOINT - 20, 74, foot=2)
    r.prop("metro_pole", metro_pole, METRO_JOINT + 18, 86, foot=2)
    r.prop("driver_seat", driver_seat, W - 42, 116, shadow=False, base=136)
    r.prop("dashboard", dashboard, W - 22, 92, shadow=False)
    r.mark("driver", W - 34, 137)
    for x in range(70, W - 60, 120):
        r.add("lamps", [x, 128])
    r.mark("door_in", 400, 164)
    return r.finish()


def room_sokak():
    r = Room("sokak", 480, 176, wall_h=0)
    c = r.c
    c.fill(0, 0, r.W, 22, H("8a6a5a"))
    c.bricks(0, 0, r.W, 22, [H("5a3a2e"), H("7a5040"), H("8a6a5a"), H("9a7a6a")], seed=6)
    for x in range(20, r.W, 90):
        c.fill(x, 4, 50, 18, H("2b3a55")); c.fill(x + 2, 6, 46, 2, H("6a8aa8"))
    for y in range(22, 56, 8):
        c.fill(0, y, r.W, 8, H("b8b2a8")); c.fill(0, y, r.W, 1, H("9a948a"))
        for x in range(8 if (y // 8) % 2 else 0, r.W, 16):
            c.fill(x, y, 1, 8, H("9a948a"))
    c.fill(0, 56, r.W, 5, STONE[5]); c.fill(0, 60, r.W, 1, STONE[2])
    c.fill(0, 61, r.W, 94, H("3a3c44"))
    c.speckle(0, 61, r.W, 94, [H("44464e"), H("30323a")], 0.15, 8)
    for x in range(0, r.W, 40):
        c.fill(x, 107, 22, 2, H("e8e4d0"))
    c.fill(0, 155, r.W, 5, STONE[5]); c.fill(0, 155, r.W, 1, WHITE)
    for y in range(160, 176, 8):
        c.fill(0, y, r.W, 8, H("b8b2a8")); c.fill(0, y, r.W, 1, H("9a948a"))
    r.prop("lamp_post", lamp_post, 120, -10, foot=0, shadow=False)
    r.prop("street_tree", street_tree, 330, -6, shadow=False)
    r.rect("arena", 24, 76, 432, 72)
    return r.finish()


def gd(v):
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, gd(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd(x) for x in v) + "]"
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return repr(v)


def main():
    os.makedirs(PROP_OUT, exist_ok=True)
    rooms = {}
    for fn in (room_ev, room_market, room_gym, room_carsi, room_butik, room_hirdavat, room_kampus_kafe, room_galeri, room_berber, room_amfi,
               room_yemekhane, room_restoran, room_durak, room_metrobus, room_sokak):
        data = fn()
        rooms[fn.__name__[5:]] = data
    PROPS["bus"] = outlined(bus_3q())
    PROPS["wheelchair"] = outlined(wheelchair())
    for cid, b in CAR_COLORS.items():
        if "car_" + cid not in PROPS:
            PROPS["car_" + cid] = outlined(car_3q(*b))
    for key, img in PROPS.items():
        write_png(os.path.join(PROP_OUT, key + ".png"), img.px)
    with open(DATA, "w", encoding="utf-8") as f:
        f.write("## tools/make_rooms.py üretir, elle düzenleme. Mekanların eşyaları, çarpışma kutuları ve işaretleri.\n\n")
        f.write("const ROOMS := {\n")
        for rid, d in rooms.items():
            f.write('\t"%s": %s,\n' % (rid, gd(d)))
        f.write("}\n")
    print("Mekanlar üretildi:", len(rooms), "oda,", len(PROPS), "eşya")


if __name__ == "__main__":
    main()
