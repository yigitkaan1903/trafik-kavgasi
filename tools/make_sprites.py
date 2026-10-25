"""Geçici pixel art üretici.

Çalıştırma (proje klasöründen):  python tools/make_sprites.py
Çıktı: assets/sprites/*.png

Gerçek çizimler hazır olunca aynı dosya adlarıyla değiştirmek yeterli.
Dövüşçüler 32x48, sağa bakar (oyun gerekince çevirir). Arabalar yukarı bakar.
"""
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
OUTLINE = (24, 18, 28, 255)
EYE = (20, 16, 20, 255)


# ---------------------------------------------------------------- PNG yazıcı

def write_png(path, canvas):
    h = len(canvas)
    w = len(canvas[0])
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in canvas)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[(0, 0, 0, 0)] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c if len(c) == 4 else (*c, 255)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.set(x, y, c)

    def outline(self, c=OUTLINE):
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx][3] and src[ny][nx] != c:
                        self.px[y][x] = c
                        break

    def volume(self, light=1.1, dark=0.8):
        """Hacim: ışık sol üstten. Sol/üst kenar pikselleri açılır, sağ/alt kenarlar koyulaşır."""
        src = [row[:] for row in self.px]

        def empty(x, y):
            return not (0 <= x < self.w and 0 <= y < self.h) or src[y][x][3] == 0

        for y in range(self.h):
            for x in range(self.w):
                c = src[y][x]
                if c[3] == 0 or c == EYE or sum(c[:3]) < 90:
                    continue
                if empty(x + 1, y) or empty(x, y + 1):
                    self.px[y][x] = (*shade(c, dark), 255)
                elif empty(x - 1, y) or empty(x, y - 1):
                    self.px[y][x] = (*shade(c, light), 255)

    def save(self, name):
        write_png(os.path.join(OUT, name), self.px)


SHADOW_TINT = (46, 32, 84)     # gölgeler soğuk/mor tarafa kayar
LIGHT_TINT = (255, 238, 196)   # ışıklar sıcak tarafa kayar


def _mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, k):
    """k < 1 koyulaştırır (renk gölgeye doğru kayar), k > 1 açar (sıcak ışığa doğru)."""
    if k < 1.0:
        return _mix(tuple(int(v * k) for v in c[:3]), SHADOW_TINT, (1.0 - k) * 0.55)
    return _mix(c[:3], LIGHT_TINT, (k - 1.0) * 1.6)


# ---------------------------------------------------------------- Dövüşçüler

LOOKS = {
    "player": dict(skin=(232, 184, 140), hair=(40, 28, 22), shirt=(24, 44, 100), stripe=(230, 180, 40),
                   pants=(62, 84, 136), shoes=(236, 236, 236)),
    "remzi": dict(skin=(220, 170, 125), hair=(80, 72, 68), shirt=(150, 110, 70), pants=(52, 52, 58),
                  shoes=(32, 26, 26), mustache=True, hat=(62, 62, 74)),
    "cemil": dict(skin=(200, 150, 110), hair=(28, 22, 22), shirt=(238, 238, 230), pants=(92, 72, 52),
                  shoes=(32, 30, 30), mustache=True, belly=True),
    "selim": dict(skin=(226, 176, 136), hair=(18, 18, 20), shirt=(30, 30, 36), pants=(40, 42, 92),
                  shoes=(124, 72, 40), glasses=(10, 10, 12), chain=(240, 200, 60)),
    "hayri": dict(skin=(190, 130, 95), hair=(92, 82, 76), shirt=(62, 112, 72), stripe=(40, 80, 50),
                  pants=(62, 62, 84), shoes=(62, 42, 30), mustache=True, belly=True, hat=(184, 40, 40)),
    "necati": dict(skin=(232, 192, 162), hair=(214, 214, 214), shirt=(150, 160, 120), pants=(112, 102, 92),
                   shoes=(52, 42, 32), mustache=True, glasses=(140, 140, 150)),
    # metrobüs
    "teyze": dict(skin=(225, 180, 145), hair=(150, 60, 90), scarf=(150, 60, 90), shirt=(86, 108, 170),
                  stripe=(210, 120, 150), pants=(70, 56, 56), shoes=(40, 30, 30), belly=True, dress=True),
    "plaza": dict(skin=(230, 185, 145), hair=(62, 40, 26), shirt=(70, 72, 86), tie=(186, 32, 44),
                  pants=(60, 62, 76), shoes=(20, 20, 22)),
    "kulaklik": dict(skin=(215, 165, 125), hair=(30, 25, 20), shirt=(124, 62, 164), pants=(40, 40, 50),
                     shoes=(240, 240, 240), headphones=(240, 64, 64), hood=True),
    "abi": dict(skin=(205, 150, 110), hair=(20, 18, 18), shirt=(40, 44, 124), stripe=(236, 236, 236),
                pants=(40, 44, 124), shoes=(236, 236, 236), mustache=True, belly=True),
    "hipster": dict(skin=(226, 182, 146), hair=(110, 70, 40), shirt=(120, 140, 90), stripe=(90, 104, 66),
                    pants=(60, 70, 110), shoes=(150, 90, 50), beard=True, glasses=(30, 30, 30), beanie=(200, 120, 50)),
    "elif": dict(skin=(236, 196, 166), hair=(70, 40, 30), shirt=(236, 236, 240), stripe=(120, 180, 220),
                 pants=(50, 60, 90), shoes=(236, 236, 236), long_hair=True),
    # yeni rakipler
    "eren": dict(skin=(222, 170, 140), hair=(70, 50, 36), shirt=(236, 232, 214), pants=(60, 84, 136),
                 shoes=(90, 70, 50), beard=True, belly=True),
    "kaan": dict(skin=(226, 180, 140), hair=(40, 28, 22), shirt=(214, 168, 40), stripe=(150, 110, 20),
                 pants=(40, 40, 48), shoes=(236, 236, 236), hood=True),
    "ebu": dict(skin=(210, 160, 120), hair=(60, 50, 46), shirt=(230, 226, 210), pants=(230, 226, 210),
                shoes=(90, 60, 40), beard=True, beanie=(244, 244, 240), dress=True),
    "hakan": dict(skin=(205, 150, 110), hair=(24, 20, 20), shirt=(30, 40, 70), stripe=(230, 200, 60),
                  pants=(30, 34, 50), shoes=(20, 20, 22), mustache=True, hat=(30, 40, 70)),
    "furth": dict(skin=(230, 186, 150), hair=(20, 18, 20), shirt=(24, 24, 28), pants=(24, 24, 28),
                  shoes=(110, 40, 40), glasses=(10, 10, 12), chain=(240, 200, 60)),
    "mert": dict(skin=(200, 146, 106), hair=(30, 24, 20), shirt=(120, 40, 160), stripe=(250, 210, 40),
                 pants=(40, 40, 50), shoes=(240, 240, 240), hat=(120, 40, 160)),
    # mekan sahipleri (isimleriyle uyumlu kendi görünüşleri)
    "melek": dict(skin=(226, 180, 146), hair=(62, 36, 28), shirt=(168, 52, 66), pants=(70, 52, 62), shoes=(40, 30, 30)),
    "selin": dict(skin=(236, 200, 170), hair=(196, 146, 78), shirt=(232, 120, 168), pants=(40, 40, 60), shoes=(30, 30, 34)),
    "riza": dict(skin=(200, 150, 110), hair=(70, 66, 62), shirt=(40, 44, 124), stripe=(236, 236, 236), pants=(40, 44, 124),
                 shoes=(236, 236, 236), mustache=True),
    "berber": dict(skin=(214, 160, 120), hair=(30, 24, 20), shirt=(240, 240, 236), pants=(50, 50, 56), shoes=(30, 26, 26),
                   mustache=True),
    "cirak": dict(skin=(226, 180, 140), hair=(40, 28, 22), shirt=(240, 240, 236), pants=(60, 84, 136), shoes=(236, 236, 236)),
    # durak figüranları
    "simitci": dict(skin=(214, 160, 120), hair=(40, 30, 26), shirt=(238, 236, 228), stripe=(200, 60, 50),
                    pants=(70, 60, 52), shoes=(40, 30, 26), mustache=True, tray=True),
}


def draw_head(c, L, dx=0, dy=0, eyes="normal"):
    x0, y0 = 11 + dx, 3 + dy
    c.rect(x0, y0 + 1, x0 + 7, y0 + 8, L["skin"])           # yüz
    c.rect(x0 + 8, y0 + 5, x0 + 8, y0 + 6, L["skin"])       # burun
    if L.get("hood"):
        c.rect(x0 - 1, y0 + 2, x0 + 1, y0 + 9, shade(L["shirt"], 0.85))
    if L.get("long_hair"):
        c.rect(x0 - 1, y0, x0 + 2, y0 + 12, L["hair"])     # sırta inen saç
    if L.get("bald"):
        c.rect(x0, y0 + 3, x0 + 1, y0 + 5, L["hair"])       # sadece yanlarda saç
        c.rect(x0 + 1, y0, x0 + 6, y0 + 1, shade(L["skin"], 1.05))
    else:
        c.rect(x0, y0, x0 + 7, y0 + 2, L["hair"])           # saç
        c.rect(x0, y0 + 3, x0 + 1, y0 + 5, L["hair"])       # favori
    c.rect(x0 + 2, y0 + 5, x0 + 2, y0 + 6, shade(L["skin"], 0.8))  # kulak
    if eyes == "x":
        c.set(x0 + 5, y0 + 4, EYE); c.set(x0 + 6, y0 + 5, EYE)
        c.set(x0 + 6, y0 + 4, EYE); c.set(x0 + 5, y0 + 5, EYE)
        c.rect(x0 + 5, y0 + 7, x0 + 6, y0 + 7, (120, 30, 30))
    else:
        c.rect(x0 + 5, y0 + 4, x0 + 5, y0 + 5, EYE)
        c.rect(x0 + 4, y0 + 3, x0 + 6, y0 + 3, shade(L["hair"], 0.9))  # kaş
    if L.get("glasses"):
        g = L["glasses"]
        if g[0] < 40:   # güneş gözlüğü
            c.rect(x0 + 3, y0 + 4, x0 + 7, y0 + 5, g)
        else:
            c.rect(x0 + 3, y0 + 4, x0 + 7, y0 + 4, g)
            c.set(x0 + 4, y0 + 5, g); c.set(x0 + 6, y0 + 5, g)
    if L.get("beard"):
        c.rect(x0 + 3, y0 + 7, x0 + 8, y0 + 9, L["hair"])
        c.rect(x0 + 2, y0 + 6, x0 + 2, y0 + 8, L["hair"])
        c.rect(x0 + 6, y0 + 8, x0 + 6, y0 + 8, (150, 60, 60))   # ağız
    if L.get("mustache"):
        c.rect(x0 + 4, y0 + 7, x0 + 8, y0 + 7, L["hair"])
    if L.get("beanie"):
        c.rect(x0 - 1, y0 - 2, x0 + 7, y0 + 1, L["beanie"])
        c.rect(x0 - 1, y0 + 1, x0 + 7, y0 + 1, shade(L["beanie"], 0.75))
    if L.get("scarf"):
        sc = L["scarf"]
        c.rect(x0 - 1, y0 - 1, x0 + 7, y0 + 1, sc)
        c.rect(x0 - 1, y0, x0 + 2, y0 + 9, sc)
        c.rect(x0 + 3, y0 + 9, x0 + 6, y0 + 9, shade(sc, 0.8))
    if L.get("headphones"):
        c.rect(x0 + 1, y0 - 1, x0 + 5, y0 - 1, (30, 30, 34))
        c.rect(x0 + 1, y0 + 3, x0 + 3, y0 + 7, L["headphones"])
    if L.get("tray"):
        c.rect(x0 - 4, y0 - 2, x0 + 11, y0 - 1, (150, 100, 52))
        for sx in range(x0 - 3, x0 + 10, 4):
            c.rect(sx, y0 - 4, sx + 2, y0 - 3, (214, 160, 80))
    if L.get("hat"):
        c.rect(x0 - 1, y0 - 1, x0 + 7, y0 + 1, L["hat"])
        c.rect(x0 + 6, y0 + 2, x0 + 10, y0 + 2, shade(L["hat"], 0.75))  # siper


def draw_torso(c, L, dx=0):
    x0 = 10 + dx
    c.rect(x0 + 2, 12, x0 + 5, 12, shade(L["skin"], 0.85))  # boyun
    c.rect(x0, 13, x0 + 8, 26, L["shirt"])
    c.rect(x0, 13, x0, 26, shade(L["shirt"], 0.8))
    if L.get("stripe"):
        c.rect(x0, 19, x0 + 8, 20, L["stripe"])
    if L.get("belly"):
        c.rect(x0 + 9, 19, x0 + 9, 26, L["shirt"])
    if L.get("tie"):
        c.rect(x0 + 5, 13, x0 + 8, 13, (240, 240, 240))
        c.rect(x0 + 7, 14, x0 + 8, 21, L["tie"])
    if L.get("dress"):
        c.rect(x0 - 1, 27, x0 + 10, 37, L["shirt"])
        c.rect(x0 - 1, 33, x0 + 10, 33, L.get("stripe", L["shirt"]))
        return
    if L.get("chain"):
        c.rect(x0 + 3, 13, x0 + 6, 13, L["chain"]); c.set(x0 + 6, 14, L["chain"])
    c.rect(x0, 27, x0 + 8 + (1 if L.get("belly") else 0), 27, shade(L["pants"], 0.6))  # kemer


def draw_leg(c, L, x, y_top=28, y_bot=44, lift=0):
    y_bot -= lift
    c.rect(x, y_top, x + 2, y_bot, L["pants"])
    c.rect(x, y_top, x, y_bot, shade(L["pants"], 0.8))
    c.rect(x, y_bot + 1, x + 3, y_bot + 3, L["shoes"])


def guard_arm(c, L, dx=0):
    c.rect(18 + dx, 14, 20 + dx, 17, L["shirt"])
    c.rect(20 + dx, 11, 21 + dx, 16, L["skin"])
    c.rect(20 + dx, 9, 23 + dx, 11, L["skin"])


def back_arm(c, L, dx=0):
    c.rect(8 + dx, 14, 9 + dx, 23, L["shirt"])
    c.rect(8 + dx, 24, 9 + dx, 25, L["skin"])


def fighter(L, pose):
    c = Canvas(32, 48)
    if pose == "ko":
        c.rect(3, 37, 10, 45, L["skin"]); c.rect(3, 37, 5, 45, L["hair"])
        c.set(8, 41, EYE); c.set(9, 42, EYE); c.set(9, 41, EYE); c.set(8, 42, EYE)
        c.rect(11, 38, 23, 45, L["shirt"])
        c.rect(24, 39, 30, 44, L["pants"]); c.rect(31, 38, 31, 45, L["shoes"])
        c.rect(12, 46, 20, 47, L["skin"])
        c.volume(); c.outline(); return c

    if pose == "sit":
        # üst gövde ayakta gibi çizilir, 10 piksel aşağı kaydırılır, sonra bacaklar eklenir
        back_arm(c, L); draw_torso(c, L); draw_head(c, L)
        c.rect(17, 14, 19, 22, L["shirt"]); c.rect(18, 23, 21, 24, L["skin"])
        c.px = [[(0, 0, 0, 0)] * c.w for _ in range(10)] + c.px[:-10]
        leg = L["shirt"] if L.get("dress") else L["pants"]
        c.rect(10, 38, 21, 40, leg); c.rect(10, 40, 21, 40, shade(leg, 0.8))
        c.rect(19, 41, 21, 44, L["pants"])
        c.rect(19, 45, 23, 47, L["shoes"])
        c.volume(); c.outline(); return c
    if pose in ("lift1", "lift2"):
        # halter: bar göğüste (lift1) ve başın üstünde (lift2); yandan bakışta iki uçta plakalar
        draw_leg(c, L, 10); draw_leg(c, L, 15)
        draw_torso(c, L); draw_head(c, L)
        bar_y = 18 if pose == "lift1" else 3
        if pose == "lift1":
            c.rect(16, 14, 18, 17, L["shirt"]); c.rect(17, 17, 19, 19, L["skin"])
            c.rect(9, 14, 10, 17, L["shirt"]); c.rect(9, 17, 11, 19, L["skin"])
        else:
            c.rect(10, 4, 11, 13, L["skin"]); c.rect(17, 4, 18, 13, L["skin"])
            c.rect(10, 12, 11, 15, L["shirt"]); c.rect(17, 12, 18, 15, L["shirt"])
        c.rect(2, bar_y, 29, bar_y + 1, (150, 150, 160))
        c.rect(1, bar_y - 3, 3, bar_y + 4, (40, 40, 48)); c.rect(28, bar_y - 3, 30, bar_y + 4, (40, 40, 48))
        c.volume(); c.outline()
        return c
    if pose in ("idle", "walk1", "walk2", "walk3", "walk4"):
        # (arka bacak x, ön bacak x, arka kalkış, ön kalkış, kol salınımı)
        back_x, front_x, back_lift, front_lift, swing = {
            "idle": (10, 15, 0, 0, 0), "walk1": (9, 17, 0, 0, -1), "walk2": (12, 14, 2, 0, 0),
            "walk3": (10, 16, 0, 0, 1), "walk4": (13, 13, 0, 2, 0)}[pose]
        draw_leg(c, L, back_x, lift=back_lift); draw_leg(c, L, front_x, lift=front_lift)
        back_arm(c, L, swing); draw_torso(c, L); draw_head(c, L); guard_arm(c, L)
    elif pose in ("punch", "special"):
        draw_leg(c, L, 9); draw_leg(c, L, 16)
        back_arm(c, L, 1); draw_torso(c, L, 1); draw_head(c, L, 1)
        c.rect(19, 14, 22, 16, L["shirt"])
        if pose == "punch":
            c.rect(23, 14, 27, 16, L["skin"]); c.rect(28, 13, 31, 17, L["skin"])
        else:  # direksiyon kilidi
            c.rect(23, 14, 24, 16, L["skin"])
            c.rect(24, 11, 31, 12, (210, 40, 40)); c.rect(25, 13, 26, 14, (210, 40, 40))
            c.rect(29, 7, 31, 10, (240, 200, 40))
    elif pose == "kick":
        draw_leg(c, L, 9)
        back_arm(c, L, -2); draw_torso(c, L, -2); draw_head(c, L, -2); guard_arm(c, L, -2)
        c.rect(15, 26, 27, 29, L["pants"]); c.rect(15, 29, 27, 29, shade(L["pants"], 0.8))
        c.rect(28, 25, 31, 30, L["shoes"])
    elif pose == "block":
        draw_leg(c, L, 9); draw_leg(c, L, 14)
        back_arm(c, L, -1); draw_torso(c, L, -1); draw_head(c, L, -1)
        c.rect(17, 14, 19, 18, L["shirt"])
        c.rect(19, 5, 22, 17, L["skin"]); c.rect(19, 5, 19, 17, shade(L["skin"], 0.8))
    elif pose == "hurt":
        draw_leg(c, L, 10); draw_leg(c, L, 15)
        c.rect(5, 14, 6, 21, L["shirt"]); c.rect(4, 11, 5, 13, L["skin"])
        draw_torso(c, L, -2); draw_head(c, L, -4, 1, eyes="x")
        c.rect(16, 14, 17, 22, L["shirt"]); c.rect(17, 23, 18, 24, L["skin"])
    c.volume(); c.outline()
    return c


# ---------------------------------------------------------------- Arabalar

CARS = {
    # id: (genişlik, uzunluk, gövde rengi, ekstra)
    "sahin": (16, 30, (226, 212, 168), None),
    "tofas": (16, 30, (150, 70, 52), None),
    "toros": (16, 30, (236, 232, 222), None),
    "doblo": (18, 32, (236, 236, 240), "van"),
    "egea": (17, 32, (196, 40, 44), None),
    "golf": (17, 30, (176, 180, 188), "hatch"),
    "mercedes": (18, 35, (200, 204, 212), None),
    "passat": (18, 34, (40, 62, 112), None),
    "bmw": (18, 34, (28, 28, 34), "sport"),
    "taksi": (16, 32, (246, 200, 40), "taxi"),
    "dolmus": (20, 42, (230, 210, 70), "van"),
    "kamyon": (24, 54, (200, 46, 40), "truck"),
}


GLASS, GLASS_HI = (66, 98, 132), (168, 208, 232)
TIRE, RIM = (22, 22, 26), (150, 152, 162)
HEAD, TAIL = (255, 246, 196), (228, 44, 44)


def car_top(w, h, body, extra):
    """Üstten araba (trafik, otopark; önü yukarı): yuvarlak köşeli gövde, kenara doğru koyulaşan boya,
    eğimli ön/arka cam, tavan parlaması, yan aynalar, farlar ve stoplar."""
    c = Canvas(w + 4, h)
    ox = 2
    dark, mid, light, lighter = shade(body, 0.66), shade(body, 0.85), shade(body, 1.12), shade(body, 1.28)
    for wy in (int(h * 0.15), int(h * 0.70)):   # tekerlekler gövdeden azıcık taşar
        c.rect(ox - 1, wy, ox - 1, wy + 5, TIRE); c.rect(ox + w, wy, ox + w, wy + 5, TIRE)
    if extra == "truck":
        cab = 14
        c.rect(ox, 1, ox + w - 1, cab, body); c.rect(ox + 1, 0, ox + w - 2, 0, body)
        c.rect(ox, 1, ox, cab, dark); c.rect(ox + w - 1, 1, ox + w - 1, cab, dark)
        c.rect(ox + 2, 4, ox + w - 3, 7, GLASS); c.rect(ox + 3, 4, ox + 6, 4, GLASS_HI)
        c.rect(ox + 2, 9, ox + w - 3, cab - 1, light)
        c.rect(ox, cab + 2, ox + w - 1, h - 1, (156, 164, 178))
        for y in range(cab + 4, h - 2, 4):
            c.rect(ox + 1, y, ox + w - 2, y, (122, 130, 146))
        c.rect(ox + 1, 0, ox + 3, 0, HEAD); c.rect(ox + w - 4, 0, ox + w - 2, 0, HEAD)
        c.rect(ox, h - 1, ox + 1, h - 1, TAIL); c.rect(ox + w - 2, h - 1, ox + w - 1, h - 1, TAIL)
        c.volume(); c.outline()
        return c
    # gövde: köşeler yuvarlatılmış, yanlara doğru koyulaşır
    c.rect(ox + 2, 0, ox + w - 3, h - 1, body)
    c.rect(ox + 1, 1, ox + w - 2, h - 2, body)
    c.rect(ox, 3, ox + w - 1, h - 4, body)
    c.rect(ox, 3, ox, h - 4, dark); c.rect(ox + w - 1, 3, ox + w - 1, h - 4, dark)
    c.rect(ox + 1, 2, ox + 1, h - 3, mid); c.rect(ox + w - 2, 2, ox + w - 2, h - 3, mid)
    van = extra == "van"
    ws = int(h * (0.16 if van else 0.27))
    we = ws + max(3, int(h * 0.1))
    if van:
        rs, re = h - 6, h - 4
    elif extra == "hatch":
        rs, re = int(h * 0.74), int(h * 0.86)
    else:
        rs, re = int(h * 0.68), int(h * 0.77)
    if not van:   # kaput çizgisi
        c.rect(ox + w // 2, 2, ox + w // 2, ws - 2, light)
        c.rect(ox + 3, 1, ox + w - 4, 1, light)
    for i, y in enumerate(range(ws, we + 1)):   # ön cam (üstte dar)
        inset = 3 if i == 0 else 2
        c.rect(ox + inset, y, ox + w - 1 - inset, y, GLASS)
    c.rect(ox + 3, ws + 1, ox + 5, ws + 1, GLASS_HI); c.rect(ox + 3, ws + 2, ox + 4, ws + 2, GLASS_HI)
    c.rect(ox + 3, we + 1, ox + w - 4, rs - 1, light)                    # tavan
    c.rect(ox + 4, we + 2, ox + 4, rs - 2, lighter)
    c.rect(ox + 2, we + 1, ox + 2, rs - 1, GLASS); c.rect(ox + w - 3, we + 1, ox + w - 3, rs - 1, GLASS)   # yan camlar
    pillar = (we + rs) // 2
    c.set(ox + 2, pillar, mid); c.set(ox + w - 3, pillar, mid)
    for y in range(rs, re + 1):   # arka cam (altta dar)
        inset = 3 if y == re else 2
        c.rect(ox + inset, y, ox + w - 1 - inset, y, GLASS)
    c.set(ox - 1, ws + 1, body); c.set(ox + w, ws + 1, body)            # yan aynalar
    if van:
        for y in range(we + 3, rs - 1, 5):
            c.rect(ox + 1, y, ox + 1, y + 2, GLASS); c.rect(ox + w - 2, y, ox + w - 2, y + 2, GLASS)
    if extra == "taxi":
        c.rect(ox + w // 2 - 3, pillar - 1, ox + w // 2 + 2, pillar + 1, (30, 30, 30))
        c.rect(ox + w // 2 - 2, pillar, ox + w // 2 + 1, pillar, (250, 240, 200))
    if extra in ("sport", "hatch"):   # yarış şeridi
        c.rect(ox + w // 2 - 1, 1, ox + w // 2, ws - 1, shade(body, 0.45))
        c.rect(ox + w // 2 - 1, re + 1, ox + w // 2, h - 2, shade(body, 0.45))
    c.rect(ox + 1, 0, ox + 3, 0, HEAD); c.rect(ox + w - 4, 0, ox + w - 2, 0, HEAD)
    c.rect(ox + 1, h - 1, ox + 3, h - 1, TAIL); c.rect(ox + w - 4, h - 1, ox + w - 2, h - 1, TAIL)
    c.volume(); c.outline()
    return c


def _wheel(c, cx, cy, r=5):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            d = x * x + y * y
            if d <= r * r + r * 0.5:
                c.set(cx + x, cy + y, TIRE if d > (r - 2) ** 2 else RIM if d > 1 else (90, 92, 100))
    c.set(cx - 1, cy - 2, (210, 212, 220))


def car_side(body, extra):
    """Yandan araba (garaj, menü; sağa bakar): omuz çizgisi, eğimli camlar, kapı çizgileri, jant."""
    w, h = (64, 30) if extra == "truck" else (54, 24) if extra == "van" else (50, 22)
    c = Canvas(w, h)
    dark, mid, light = shade(body, 0.66), shade(body, 0.85), shade(body, 1.18)
    base = h - 5
    if extra == "truck":
        c.rect(1, 2, 42, base, (156, 164, 178)); c.rect(1, 2, 42, 2, (190, 196, 206)); c.rect(1, base - 1, 42, base, (120, 130, 146))
        c.rect(44, 8, 62, base, body); c.rect(44, 8, 62, 8, light)
        c.rect(50, 10, 60, 16, GLASS); c.rect(51, 11, 53, 11, GLASS_HI); c.rect(44, base - 2, 62, base, dark)
        c.rect(61, base - 6, 62, base - 5, HEAD)
        for wx in (10, 32, 54):
            _wheel(c, wx, base, 4)
        c.volume(); c.outline()
        return c
    van = extra == "van"
    belt = base - 8                                   # cam altı (omuz) çizgisi
    c.rect(1, belt, w - 2, base, body)
    c.rect(0, belt + 2, w - 1, base - 1, body)
    c.rect(1, belt, w - 2, belt, light)               # omuz parlaması
    c.rect(1, base - 1, w - 2, base, dark)            # etek
    c.rect(2, belt + 3, w - 3, belt + 3, mid)
    # kabin: ön cam daha yatık
    if van:
        top, roof_l, roof_r, slope_f, slope_b = 2, 3, w - 12, 6, 1
    elif extra == "sport":
        top, roof_l, roof_r, slope_f, slope_b = 6, 17, w - 17, 7, 6
    elif extra == "hatch":
        top, roof_l, roof_r, slope_f, slope_b = 4, 8, w - 18, 7, 2
    else:
        top, roof_l, roof_r, slope_f, slope_b = 4, 12, w - 16, 7, 5
    rows = belt - top
    for i in range(rows):
        k = i / max(1, rows - 1)
        xl = int(roof_l - slope_b * k)
        xr = int(roof_r + slope_f * k)
        c.rect(xl, top + i, xr, top + i, body)
        if i > 0:
            c.rect(xl + 2, top + i, xr - 2, top + i, GLASS)
    c.rect(roof_l, top, roof_r, top, light)            # tavan çizgisi
    mid_x = (roof_l + roof_r) // 2 + 2
    c.rect(mid_x, top + 1, mid_x + 1, belt - 1, dark)  # orta direk
    c.rect(roof_l + 2, top + 1, roof_l + 5, top + 1, GLASS_HI)
    c.rect(mid_x, belt + 1, mid_x, base - 2, dark)     # kapı çizgisi
    c.rect(mid_x - 6, belt + 2, mid_x - 4, belt + 2, light); c.rect(mid_x + 4, belt + 2, mid_x + 6, belt + 2, light)
    c.rect(w - 3, belt + 1, w - 2, belt + 2, HEAD); c.rect(1, belt + 1, 2, belt + 2, TAIL)
    c.rect(w - 4, base - 1, w - 1, base, (60, 62, 70)); c.rect(0, base - 1, 3, base, (60, 62, 70))   # tamponlar
    if extra == "taxi":
        tx = (roof_l + roof_r) // 2
        c.rect(tx - 3, top - 2, tx + 3, top - 1, (30, 30, 30)); c.rect(tx - 2, top - 2, tx + 2, top - 2, (250, 240, 200))
    for wx in (9, w - 12):
        for y in range(-6, 1):   # çamurluk boşluğu
            for x in range(-6, 7):
                if x * x + y * y <= 36:
                    c.set(wx + x, base + y, (0, 0, 0, 0))
        _wheel(c, wx, base)
    c.volume(); c.outline()
    return c


def civilians(count=16, seed=42):
    """Kalabalık için rastgele yolcular: farklı ten, saç, yüz detayı ve kıyafet."""
    import random
    rng = random.Random(seed)
    skins = [(236, 196, 166), (226, 182, 146), (214, 160, 120), (196, 140, 100), (170, 116, 82), (130, 86, 60)]
    hairs = [(24, 20, 20), (60, 40, 28), (110, 70, 40), (170, 120, 60), (200, 200, 200), (130, 40, 30)]
    clothes = [(200, 60, 60), (60, 120, 200), (60, 160, 90), (230, 200, 60), (150, 80, 170), (240, 240, 236),
               (40, 40, 48), (230, 130, 50), (90, 200, 200), (180, 180, 190), (120, 90, 60), (220, 110, 160)]
    pants = [(40, 44, 70), (60, 84, 136), (50, 50, 56), (110, 100, 80), (90, 60, 40), (150, 150, 160)]
    shoes = [(30, 26, 26), (236, 236, 236), (120, 70, 40), (60, 60, 70)]
    out = {}
    for i in range(count):
        shirt = rng.choice(clothes)
        look = dict(skin=rng.choice(skins), hair=rng.choice(hairs), shirt=shirt, pants=rng.choice(pants),
                    shoes=rng.choice(shoes))
        style = rng.choice(["short", "short", "long", "bald", "beard", "cap", "beanie"])
        if style == "long":
            look["long_hair"] = True
        elif style == "bald":
            look["bald"] = True
            look["mustache"] = rng.random() < 0.5
        elif style == "beard":
            look["beard"] = True
        elif style == "cap":
            look["hat"] = rng.choice(clothes)
        elif style == "beanie":
            look["beanie"] = rng.choice(clothes)
        if rng.random() < 0.25:
            look["glasses"] = rng.choice([(20, 20, 24), (140, 140, 150)])
        if rng.random() < 0.3:
            look["stripe"] = rng.choice(clothes)
        if rng.random() < 0.15 and not look.get("long_hair"):
            look["headphones"] = rng.choice(clothes)
        if rng.random() < 0.2:
            look["belly"] = True
        out["sivil%d" % i] = look
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    LOOKS.update(civilians())
    for who, look in LOOKS.items():
        poses = ["idle", "walk1", "walk2", "walk3", "walk4", "punch", "kick", "block", "hurt", "ko", "special", "sit",
                 "lift1", "lift2"]   # lift: gym animasyonu (salondaki diğer sporcular da kullanır)
        for pose in poses:
            fighter(look, pose).save(f"fighter_{who}_{pose}.png")
    for cid, (w, h, body, extra) in CARS.items():
        car_top(w, h, body, extra).save(f"car_{cid}.png")
        car_side(body, extra).save(f"car_side_{cid}.png")
    print("Sprite'lar üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
