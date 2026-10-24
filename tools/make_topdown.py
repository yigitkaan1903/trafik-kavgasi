"""3/4 üstten bakış karakter sayfaları.

Çalıştırma (proje klasöründen):  python tools/make_topdown.py
Çıktı: assets/topdown/td_<kişi>.png

Her sayfa 28x30'luk hücrelerden oluşur (karakter 16 piksel genişlik, hücrede ortalı, ayaklar en alt satırda):
  satırlar: 0 aşağı (yüz bize dönük), 1 yukarı (sırtı dönük), 2 sağa (sola bakarken oyun aynalar), 3 yerde yatma (ko)
  sütunlar: POSES sırası
Karakterler köşeleri yuvarlatılmış parçalardan çizilir (baş, omuzlar, ayrı kollar, eller, ayakkabılar), gölgelenir ve
renkli dış çizgi alır. Görünüş: make_sprites.py LOOKS (renkler) + aşağıdaki STYLE (saç, kıyafet, boy, aksesuar).
Figüranlar (sivil0..sivil39) civilians() ile üretilir: farklı ten, saç modeli, başörtüsü, kıyafet, boy, yaş.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sprites as ms  # noqa: E402
from make_sprites import Canvas, shade, EYE  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "topdown")
CW, CH = 28, 30
POSES = ["idle", "walk1", "walk2", "punch", "kick", "block", "hurt", "sit", "lift1", "lift2", "special"]
OX = 6          # karakterin hücre içindeki sol kenarı (16 genişlik: 6..21)
CIVILIAN_COUNT = 40
LINE = (34, 24, 40)

# Adlı karakterlerin saç / kıyafet / boy bilgisi (renkler make_sprites.LOOKS içinde)
STYLE = {
    "player": dict(hair_style="sidepart", top="hoodie", height=0, backpack=(40, 44, 60)),
    "remzi": dict(hair_style="short", top="jacket", inner=(200, 190, 170), height=1),
    "cemil": dict(hair_style="bald", top="tee", height=1, sleeves="short"),
    "selim": dict(hair_style="sidepart", top="jacket", inner=(30, 30, 36), height=0),
    "hayri": dict(hair_style="short", top="vest", vest=(230, 120, 40), height=1),
    "necati": dict(hair_style="bald", top="coat", height=2),
    "teyze": dict(hair_style="hijab", top="coat", height=2),
    "plaza": dict(hair_style="sidepart", top="suit", height=0, bag=(70, 50, 40)),
    "kulaklik": dict(hair_style="curly", top="hoodie", height=1),
    "abi": dict(hair_style="buzz", top="tee", height=1, sleeves="long"),
    "hipster": dict(hair_style="bun", top="jacket", inner=(236, 230, 214), height=0),
    "elif": dict(hair_style="ponytail", top="tee", height=2, backpack=(120, 180, 220)),
    "simitci": dict(hair_style="short", top="tee", height=1, sleeves="short"),
    "eren": dict(hair_style="curly", top="tee", height=1, sleeves="short"),
    "kaan": dict(hair_style="sidepart", top="hoodie", height=0),
    "ebu": dict(hair_style="short", top="coat", inner=(230, 226, 210), height=1),
    "hakan": dict(hair_style="short", top="jacket", inner=(220, 220, 215), height=0),
    "furth": dict(hair_style="sidepart", top="jacket", inner=(40, 40, 46), height=0),
    "mert": dict(hair_style="short", top="hoodie", height=1, backpack=(250, 200, 40)),
}

# Oyuncunun kıyafetleri (data/shop.gd OUTFITS ile aynı id): oyuncunun görünüşünün üstüne yazılır.
# None verilen özellik kaldırılır. Her biri ayrı sayfa: td_player_<id>.png ("esofman" = td_player.png).
OUTFITS = {
    "kapson": dict(shirt=(30, 30, 34), top="hoodie", stripe=None, pants=(36, 36, 40), shoes=(44, 44, 48)),
    "hawaii": dict(shirt=(236, 120, 60), stripe=(60, 180, 170), top="tee", sleeves="short", pants=(200, 186, 150),
                   shoes=(150, 90, 50), backpack=None),
    "forma": dict(shirt=(200, 40, 50), stripe=(240, 240, 240), top="tee", sleeves="short", pants=(240, 240, 240),
                  shoes=(30, 30, 34)),
    "kot": dict(shirt=(70, 100, 160), top="jacket", inner=(240, 240, 236), stripe=None, pants=(40, 44, 70)),
    "deri": dict(shirt=(44, 32, 30), top="jacket", inner=(214, 210, 200), stripe=None, pants=(36, 36, 44),
                 shoes=(30, 26, 26), backpack=None),
    "mont": dict(shirt=(70, 96, 64), top="coat", inner=(200, 190, 170), stripe=None, beanie=(180, 40, 40)),
    "takim": dict(shirt=(40, 42, 60), top="suit", pants=(40, 42, 60), tie=(180, 30, 40), stripe=None,
                  shoes=(20, 20, 22), backpack=None),
}


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Cell(Canvas):
    def r(self, x0, y0, x1, y1, c):
        self.rect(OX + x0, y0, OX + x1, y1, c)

    def p(self, x, y, c):
        self.set(OX + x, y, c)

    def rows(self, y0, spans, c):
        for i, (a, b) in enumerate(spans):
            self.r(a, y0 + i, b, y0 + i, c)

    def selout(self):
        """Renkli dış çizgi: komşu rengin koyusu (düz siyah çizgiden daha yumuşak durur)."""
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x][3]:
                    continue
                for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx][3]:
                        n = src[ny][nx]
                        self.px[y][x] = (*mix(shade(n, 0.42), LINE, 0.55), 255)
                        break

    def finish(self):
        self.volume(1.08, 0.84)
        self.selout()
        return self


def look_of(who, L):
    st = dict(STYLE.get(who, {}))
    st.update({k: v for k, v in L.items()})
    if "hair_style" not in st:
        st["hair_style"] = "hijab" if L.get("scarf") else "bald" if L.get("bald") else "long" if L.get("long_hair") else "short"
    if "top" not in st:
        st["top"] = "suit" if L.get("tie") else "hoodie" if L.get("hood") else "dress" if L.get("dress") else "tee"
    st.setdefault("height", 1)
    return st


# ---------------------------------------------------------------- Ön (aşağı) ve arka (yukarı)

HEAD = [(5, 10), (4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11), (5, 10)]
SCARF = [(5, 10), (3, 12), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (3, 12), (3, 12), (2, 13), (2, 13)]
FACE_OVAL = [(5, 10), (4, 11), (4, 11), (4, 11), (4, 11), (4, 11), (5, 10)]


def face_front(c, L, y0, eyes):
    skin, hair = L["skin"], L["hair"]
    if eyes == "x":
        for (x, y) in ((5, 6), (6, 7), (6, 6), (5, 7), (9, 6), (10, 7), (10, 6), (9, 7)):
            c.p(x, y0 + y, EYE)
    else:
        c.r(5, y0 + 6, 5, y0 + 7, EYE); c.r(10, y0 + 6, 10, y0 + 7, EYE)
        c.p(5, y0 + 6, (70, 56, 60)); c.p(10, y0 + 6, (70, 56, 60))
        if L["hair_style"] != "hijab":
            c.r(4, y0 + 5, 6, y0 + 5, shade(hair, 0.85)); c.r(9, y0 + 5, 11, y0 + 5, shade(hair, 0.85))
    c.p(8, y0 + 8, shade(skin, 0.86))
    c.r(7, y0 + 9, 8, y0 + 9, shade(skin, 0.72) if eyes != "x" else (120, 50, 60))
    c.p(4, y0 + 8, mix(skin, (230, 120, 110), 0.25)); c.p(11, y0 + 8, mix(skin, (230, 120, 110), 0.25))
    if L.get("mustache"):
        c.r(5, y0 + 8, 10, y0 + 8, hair)
    if L.get("beard"):
        c.rows(y0 + 8, [(3, 12), (4, 11), (5, 10)], hair)
        c.r(7, y0 + 9, 8, y0 + 9, (150, 70, 70))
    if L.get("glasses"):
        g = L["glasses"]
        c.r(4, y0 + 6, 11, y0 + 6, g)
        if g[0] < 40:   # güneş gözlüğü
            c.r(4, y0 + 6, 6, y0 + 7, g); c.r(9, y0 + 6, 11, y0 + 7, g)
        else:
            c.p(4, y0 + 7, g); c.p(6, y0 + 7, g); c.p(9, y0 + 7, g); c.p(11, y0 + 7, g)


def head_front(c, L, y0, back=False, eyes="normal"):
    skin, hair, hs = L["skin"], L["hair"], L["hair_style"]
    if hs == "hijab":
        sc = L.get("scarf", (150, 60, 90))
        c.rows(y0, SCARF, sc)
        c.r(5, y0 + 1, 9, y0 + 1, shade(sc, 1.15))
        if not back:
            c.rows(y0 + 3, FACE_OVAL, skin)
            face_front(c, L, y0, eyes)
            c.r(4, y0 + 11, 11, y0 + 11, shade(sc, 0.85))   # çene altı kıvrım
        else:
            c.r(6, y0 + 5, 9, y0 + 12, shade(sc, 0.9))
        return
    c.rows(y0, HEAD, hair if back and hs not in ("bald",) else skin)
    if back:
        if hs == "bald":
            c.rows(y0 + 5, [(3, 12), (3, 12), (4, 11)], hair)
            c.r(6, y0 + 1, 8, y0 + 1, shade(skin, 1.12))
        elif hs == "buzz":
            c.rows(y0, HEAD, mix(hair, skin, 0.35))
        c.p(2, y0 + 5, shade(skin, 0.9)); c.p(13, y0 + 5, shade(skin, 0.9))
        c.r(5, y0 + 1, 7, y0 + 1, shade(hair, 1.2))   # parlama
        if hs == "long":
            c.r(3, y0 + 9, 12, y0 + 14, hair); c.r(4, y0 + 15, 11, y0 + 15, hair)
        elif hs == "ponytail":
            c.r(7, y0 + 9, 8, y0 + 15, hair); c.r(6, y0 + 8, 9, y0 + 9, shade(hair, 0.8))
        elif hs == "bun":
            c.r(6, y0 - 2, 9, y0, hair); c.r(6, y0 - 2, 7, y0 - 2, shade(hair, 1.2))
        elif hs == "curly":
            for k in range(3, 13, 2):
                c.p(k, y0 - 1, hair)
            c.p(2, y0 + 3, hair); c.p(13, y0 + 3, hair); c.p(2, y0 + 6, hair); c.p(13, y0 + 6, hair)
    else:
        if hs == "bald":
            c.r(6, y0 + 1, 7, y0 + 1, shade(skin, 1.15))
            c.r(3, y0 + 4, 3, y0 + 6, hair); c.r(12, y0 + 4, 12, y0 + 6, hair)
        elif hs == "buzz":
            c.rows(y0, HEAD[:3], mix(hair, skin, 0.35))
        else:
            c.rows(y0, HEAD[:3], hair)
            c.r(5, y0, 7, y0, shade(hair, 1.2))
            if hs == "sidepart":
                c.r(3, y0 + 3, 8, y0 + 3, hair); c.p(3, y0 + 4, hair); c.r(12, y0 + 3, 12, y0 + 4, hair)
            elif hs == "curly":
                for k in range(3, 13, 2):
                    c.p(k, y0 - 1, hair); c.p(k + 1, y0 + 3, hair)
                c.r(2, y0 + 2, 2, y0 + 6, hair); c.r(13, y0 + 2, 13, y0 + 6, hair)
            else:
                c.r(3, y0 + 3, 4, y0 + 3, hair); c.r(5, y0 + 3, 7, y0 + 3, hair); c.r(11, y0 + 3, 12, y0 + 3, hair)
                c.p(3, y0 + 4, hair); c.p(12, y0 + 4, hair)
            if hs == "long":
                c.r(2, y0 + 2, 3, y0 + 14, hair); c.r(12, y0 + 2, 13, y0 + 14, hair)
                c.r(8, y0 + 3, 11, y0 + 3, hair)
            elif hs == "bun":
                c.r(6, y0 - 2, 9, y0, hair); c.r(6, y0 - 2, 7, y0 - 2, shade(hair, 1.2))
            elif hs == "ponytail":
                c.r(8, y0 + 3, 11, y0 + 3, hair)
        if hs not in ("long",):
            c.p(2, y0 + 5, shade(skin, 0.88)); c.p(2, y0 + 6, shade(skin, 0.88))
            c.p(13, y0 + 5, shade(skin, 0.88)); c.p(13, y0 + 6, shade(skin, 0.88))
        face_front(c, L, y0, eyes)
    if L.get("headphones"):
        c.r(3, y0, 12, y0, (30, 30, 34))
        c.r(2, y0 + 4, 2, y0 + 7, L["headphones"]); c.r(13, y0 + 4, 13, y0 + 7, L["headphones"])
    if L.get("hat"):
        c.rows(y0, [(4, 11), (3, 12), (3, 12)], L["hat"])
        c.r(5, y0, 7, y0, shade(L["hat"], 1.2))
        if not back:
            c.r(3, y0 + 3, 12, y0 + 3, shade(L["hat"], 0.7))
    if L.get("beanie"):
        c.rows(y0 - 1, [(5, 10), (4, 11), (3, 12), (3, 12), (3, 12)], L["beanie"])
        c.r(3, y0 + 3, 12, y0 + 3, shade(L["beanie"], 0.78))
        c.p(7, y0 - 2, shade(L["beanie"], 1.2)); c.p(8, y0 - 2, shade(L["beanie"], 1.2))
    if L.get("tray"):
        c.rect(OX - 4, 0, OX + 19, 1, (150, 100, 52))
        for sx in range(OX - 3, OX + 18, 4):
            c.rect(sx, 0, sx + 2, 0, (214, 160, 80))


TORSO = [(4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11)]
TORSO_BELLY = [(4, 11), (3, 12), (3, 12), (2, 13), (2, 13), (2, 13), (2, 13), (3, 12), (4, 11)]


def torso_front(c, L, t0, back=False):
    """t0: boyun satırı. Gövde t0+1 .. t0+9."""
    shirt, skin, top = L["shirt"], L["skin"], L["top"]
    if L["hair_style"] != "hijab":
        c.r(6, t0, 9, t0, shade(skin, 0.8))
    spans = TORSO_BELLY if L.get("belly") else TORSO
    if top == "coat":
        spans = spans + [(3, 12), (3, 12), (3, 12)]
    c.rows(t0 + 1, spans, shirt)
    c.r(5, t0 + 1, 10, t0 + 1, shade(shirt, 1.12))
    if back:
        if top == "hoodie":
            c.rows(t0, [(4, 11), (4, 11), (5, 10)], shade(shirt, 0.82))
        if top == "vest":
            c.rows(t0 + 1, spans, L.get("vest", (230, 120, 40)))
            c.r(3, t0 + 5, 12, t0 + 5, (220, 220, 210))
        if top == "dress":
            c.rows(t0 + 9, [(3, 12), (3, 12), (2, 13), (2, 13), (2, 13), (2, 13)], L.get("skirt", shirt))
        if L.get("backpack"):
            bp = L["backpack"]
            c.rows(t0 + 2, [(5, 10), (4, 11), (4, 11), (4, 11), (4, 11), (4, 11), (5, 10)], bp)
            c.r(5, t0 + 4, 10, t0 + 4, shade(bp, 0.75)); c.r(6, t0 + 2, 9, t0 + 2, shade(bp, 1.2))
        return
    if top == "tee":
        c.r(7, t0 + 1, 8, t0 + 1, shade(skin, 0.9))
        if L.get("stripe"):
            c.r(3, t0 + 5, 12, t0 + 5, L["stripe"])
    elif top == "hoodie":
        c.rows(t0, [(4, 5), (10, 11)], shade(shirt, 0.82))
        c.r(6, t0 + 1, 9, t0 + 1, shade(shirt, 0.8))
        c.p(6, t0 + 2, (230, 230, 230)); c.p(9, t0 + 2, (230, 230, 230)); c.p(6, t0 + 3, (230, 230, 230)); c.p(9, t0 + 3, (230, 230, 230))
        c.r(5, t0 + 6, 10, t0 + 7, shade(shirt, 0.88))
        if L.get("stripe"):
            c.r(3, t0 + 4, 4, t0 + 4, L["stripe"]); c.r(11, t0 + 4, 12, t0 + 4, L["stripe"])
            c.r(5, t0 + 5, 10, t0 + 5, L["stripe"])
    elif top in ("jacket", "suit", "coat"):
        inner = (236, 236, 236) if top == "suit" else L.get("inner", L.get("stripe", (220, 214, 200)))
        last = t0 + (12 if top == "coat" else 9)
        c.r(6, t0 + 1, 9, t0 + 6 if top == "coat" else last, inner)
        c.p(5, t0 + 1, shade(shirt, 0.7)); c.p(10, t0 + 1, shade(shirt, 0.7))
        c.p(5, t0 + 2, shade(shirt, 0.7)); c.p(10, t0 + 2, shade(shirt, 0.7))
        if top == "suit":
            c.r(7, t0 + 1, 8, t0 + 1, (236, 236, 236))
            c.r(7, t0 + 2, 8, t0 + 6, L.get("tie", (180, 40, 50))); c.p(7, t0 + 7, L.get("tie", (180, 40, 50)))
        if top == "coat":
            for k in (8, 10):
                c.p(9, t0 + k, shade(shirt, 0.65))
    elif top == "vest":
        c.rows(t0 + 1, [(3, 5), (3, 5), (3, 5), (3, 5), (3, 5), (3, 5), (3, 5), (4, 5)], L.get("vest", (230, 120, 40)))
        c.rows(t0 + 1, [(10, 12), (10, 12), (10, 12), (10, 12), (10, 12), (10, 12), (10, 12), (10, 11)], L.get("vest", (230, 120, 40)))
        c.r(3, t0 + 5, 5, t0 + 5, (220, 220, 210)); c.r(10, t0 + 5, 12, t0 + 5, (220, 220, 210))
    elif top == "dress":
        c.r(7, t0 + 1, 8, t0 + 1, shade(skin, 0.9))
        c.rows(t0 + 9, [(3, 12), (3, 12), (2, 13), (2, 13), (2, 13), (2, 13)], L.get("skirt", shirt))
        if L.get("stripe"):
            c.r(2, t0 + 13, 13, t0 + 13, L["stripe"])
    if L.get("chain"):
        c.r(5, t0 + 1, 10, t0 + 1, L["chain"]); c.p(7, t0 + 2, L["chain"]); c.p(8, t0 + 2, L["chain"])
    if L.get("backpack"):
        bp = shade(L["backpack"], 0.8)
        c.r(4, t0 + 1, 4, t0 + 5, bp); c.r(11, t0 + 1, 11, t0 + 5, bp)
    if L.get("bag"):
        c.r(4, t0 + 1, 4, t0 + 2, (60, 44, 34)); c.p(5, t0 + 3, (60, 44, 34)); c.p(6, t0 + 4, (60, 44, 34))
    if top not in ("coat", "dress"):
        c.r(4, t0 + 9, 11, t0 + 9, shade(L["pants"], 0.62))   # kemer


def sleeve_color(L):
    return L.get("sleeve", L["shirt"])


def arm_front(c, L, side, t0, swing=0):
    """side: -1 sol, 1 sağ. swing: elin dikey kayması."""
    skin = L["skin"]
    off = 1 if L.get("belly") else 0
    x = (1 - off) if side < 0 else (13 + off)
    long_sleeve = L.get("sleeves", "long" if L["top"] in ("hoodie", "jacket", "suit", "coat", "vest") else "short") == "long"
    sl = sleeve_color(L)
    end = t0 + 7 + swing
    c.r(x, t0 + 2, x + 1, t0 + 2, sl)
    if long_sleeve:
        c.r(x, t0 + 2, x + 1, end, sl)
        c.r(x, end, x + 1, end, shade(sl, 0.8))
    else:
        c.r(x, t0 + 2, x + 1, t0 + 4, sl)
        c.r(x, t0 + 5, x + 1, end, skin)
    c.r(x, end + 1, x + 1, end + 2, skin)
    c.p(x + (1 if side < 0 else 0), end + 2, shade(skin, 0.85))


def legs_front(c, L, t0, lift_l=0, lift_r=0, back=False):
    pants, shoes = L["pants"], L["shoes"]
    top = t0 + 10
    covered = t0 + (13 if L["top"] == "coat" else 14 if L["top"] == "dress" else 9)
    leg_col = pants
    for (x0, lift) in ((4, lift_l), (9, lift_r)):
        bot = 26 - lift
        c.r(x0, top, x0 + 2, bot, leg_col)
        c.r(x0, top, x0, bot, shade(leg_col, 1.08))
        if bot - top > 3:
            c.p(x0 + 1, (top + bot) // 2, shade(leg_col, 0.9))
        sy = 27 - lift
        if back:
            c.r(x0, sy, x0 + 2, sy + 1, shoes); c.r(x0, sy + 2, x0 + 2, sy + 2, shade(shoes, 0.6))
        else:
            c.r(x0 + (0 if x0 == 4 else 0), sy, x0 + 2, sy, shoes)
            c.r(x0 - 1 if x0 == 4 else x0, sy + 1, x0 + 2 if x0 == 4 else x0 + 3, sy + 1, shoes)
            c.r(x0 - 1 if x0 == 4 else x0, sy + 2, x0 + 2 if x0 == 4 else x0 + 3, sy + 2, shade(shoes, 0.62))
            c.p(x0 + 1, sy, shade(shoes, 1.25))
    if covered < top:
        pass
    c.r(5, top, 10, top, pants)
    c.r(7, top + 1, 8, top + 1, shade(pants, 0.7))


def front(L, pose, back=False):
    c = Cell(CW, CH)
    skin = L["skin"]
    dy = L["height"]
    if pose == "sit":
        d = dy + 3
        t0 = d + 11
        c.r(4, 24, 11, 26, L["pants"]); c.r(4, 24, 11, 24, shade(L["pants"], 1.12))
        for x0 in (4, 9):
            c.r(x0 - (1 if x0 == 4 else 0), 27, x0 + 2 + (0 if x0 == 4 else 1), 28, L["shoes"])
            c.r(x0 - (1 if x0 == 4 else 0), 29, x0 + 2 + (0 if x0 == 4 else 1), 29, shade(L["shoes"], 0.6))
        torso_front(c, L, t0, back)
        if L["top"] == "dress":
            c.r(3, 24, 12, 26, L.get("skirt", L["shirt"]))
        arm_front(c, L, -1, t0, -1); arm_front(c, L, 1, t0, -1)
        head_front(c, L, d, back)
        return c.finish()
    t0 = dy + 11
    if pose in ("lift1", "lift2"):
        legs_front(c, L, t0, back=back)
        torso_front(c, L, t0, back)
        sl = sleeve_color(L)
        if pose == "lift1":
            bar = t0 + 4
            c.r(1, t0 + 2, 2, bar, sl); c.r(13, t0 + 2, 14, bar, sl)
        else:
            bar = dy + 1
            c.r(1, bar, 2, t0 + 2, skin); c.r(13, bar, 14, t0 + 2, skin)
        head_front(c, L, dy, back)
        c.rect(1, bar, 26, bar, (160, 164, 176))
        c.rect(0, bar - 3, 2, bar + 3, (40, 40, 48)); c.rect(25, bar - 3, 27, bar + 3, (40, 40, 48))
        c.r(1, bar - 1, 2, bar + 1, skin); c.r(13, bar - 1, 14, bar + 1, skin)
        return c.finish()
    lift_l = lift_r = 0
    sw_l = sw_r = 0
    if pose == "walk1":
        lift_r, sw_l, sw_r = 2, 1, -1
    elif pose == "walk2":
        lift_l, sw_l, sw_r = 2, -1, 1
    legs_front(c, L, t0, lift_l, lift_r, back)
    if pose == "kick":
        if not back:   # bacak bize doğru: ayakkabının altı görünür
            c.r(9, t0 + 10, 12, t0 + 13, L["pants"]); c.r(8, t0 + 13, 13, t0 + 17, L["shoes"])
            c.r(9, t0 + 14, 12, t0 + 16, shade(L["shoes"], 0.6))
        else:
            c.r(9, t0 + 10, 11, t0 + 12, L["pants"]); c.r(9, t0 + 12, 11, t0 + 14, L["shoes"])
    torso_front(c, L, t0, back)
    sl = sleeve_color(L)
    hurt = pose == "hurt"
    if pose == "special":
        if back:
            c.r(1, dy + 3, 2, t0 + 2, sl); c.r(13, dy + 3, 14, t0 + 2, sl)
            c.r(1, dy + 1, 2, dy + 2, skin); c.r(13, dy + 1, 14, dy + 2, skin)
        else:
            c.r(2, t0 + 2, 4, t0 + 4, sl); c.r(11, t0 + 2, 13, t0 + 4, sl)
            c.r(2, t0 + 5, 6, t0 + 8, skin); c.r(9, t0 + 5, 13, t0 + 8, skin)
    elif pose == "punch":
        arm_front(c, L, -1, t0, 0)
        if back:
            c.r(13, dy + 4, 14, t0 + 2, sl); c.r(12, dy + 1, 15, dy + 3, skin)
        else:
            c.r(12, t0 + 2, 14, t0 + 4, sl); c.r(10, t0 + 4, 14, t0 + 7, skin); c.r(10, t0 + 4, 14, t0 + 4, shade(skin, 1.1))
    elif pose == "block":
        if back:
            c.r(0, dy + 4, 1, t0 + 2, skin); c.r(14, dy + 4, 15, t0 + 2, skin)
        else:
            c.r(1, t0 + 2, 2, t0 + 3, sl); c.r(13, t0 + 2, 14, t0 + 3, sl)
    elif hurt:
        c.r(-1, t0, 0, t0 + 5, sl); c.r(15, t0, 16, t0 + 5, sl)
        c.r(-1, t0 - 2, 0, t0 - 1, skin); c.r(15, t0 - 2, 16, t0 - 1, skin)
    else:
        arm_front(c, L, -1, t0, sw_l); arm_front(c, L, 1, t0, sw_r)
    head_front(c, L, dy + (1 if hurt else 0), back, eyes="x" if hurt else "normal")
    if pose == "block" and not back:
        c.r(3, dy + 7, 12, dy + 11, skin); c.r(3, dy + 7, 12, dy + 7, shade(skin, 1.1))
        c.r(7, dy + 7, 8, dy + 11, shade(skin, 0.85))
    return c.finish()


# ---------------------------------------------------------------- Yan (sağa)

HEAD_SIDE = [(6, 10), (5, 11), (4, 12), (4, 12), (4, 12), (4, 12), (4, 12), (4, 12), (4, 12), (5, 11), (6, 10)]


def head_side(c, L, y0, dx=0, eyes="normal"):
    skin, hair, hs = L["skin"], L["hair"], L["hair_style"]
    sp = [(a + dx, b + dx) for a, b in HEAD_SIDE]
    if hs == "hijab":
        sc = L.get("scarf", (150, 60, 90))
        c.rows(y0, [(5 + dx, 10 + dx), (4 + dx, 11 + dx)] + [(3 + dx, 12 + dx)] * 10 + [(3 + dx, 11 + dx), (3 + dx, 10 + dx)], sc)
        c.rows(y0 + 3, [(9 + dx, 12 + dx)] * 7, skin)
        c.p(13 + dx, y0 + 7, skin)
    else:
        c.rows(y0, sp, skin)
        if hs == "bald":
            c.r(5 + dx, y0 + 4, 7 + dx, y0 + 7, hair); c.r(7 + dx, y0 + 1, 9 + dx, y0 + 1, shade(skin, 1.12))
        elif hs == "buzz":
            c.rows(y0, sp[:3], mix(hair, skin, 0.35)); c.r(4 + dx, y0 + 3, 6 + dx, y0 + 7, mix(hair, skin, 0.35))
        else:
            c.rows(y0, sp[:3], hair)
            c.r(4 + dx, y0 + 3, 7 + dx, y0 + 8, hair); c.r(10 + dx, y0 + 3, 11 + dx, y0 + 3, hair)
            c.r(7 + dx, y0, 9 + dx, y0, shade(hair, 1.2))
            if hs == "long":
                c.r(3 + dx, y0 + 2, 7 + dx, y0 + 15, hair)
            elif hs == "ponytail":
                c.r(2 + dx, y0 + 4, 3 + dx, y0 + 11, hair); c.p(4 + dx, y0 + 4, shade(hair, 0.8))
            elif hs == "bun":
                c.r(4 + dx, y0 - 2, 7 + dx, y0, hair)
            elif hs == "curly":
                for k in range(4, 12, 2):
                    c.p(k + dx, y0 - 1, hair)
                c.p(3 + dx, y0 + 3, hair); c.p(3 + dx, y0 + 6, hair)
        if hs not in ("long",):
            c.r(8 + dx, y0 + 6, 8 + dx, y0 + 7, shade(skin, 0.82))
        c.p(13 + dx, y0 + 7, skin); c.p(13 + dx, y0 + 6, shade(skin, 1.05))
    if eyes == "x":
        for (x, y) in ((10, 5), (11, 6), (11, 5), (10, 6)):
            c.p(x + dx, y0 + y + 1, EYE)
    else:
        c.r(11 + dx, y0 + 6, 11 + dx, y0 + 7, EYE)
        if hs != "hijab":
            c.r(10 + dx, y0 + 5, 12 + dx, y0 + 5, shade(hair, 0.85))
    c.p(12 + dx, y0 + 9, shade(skin, 0.72))
    if L.get("glasses"):
        c.r(10 + dx, y0 + 6, 13 + dx, y0 + 6, L["glasses"]); c.p(9 + dx, y0 + 6, L["glasses"])
    if L.get("mustache"):
        c.r(11 + dx, y0 + 8, 13 + dx, y0 + 8, hair)
    if L.get("beard"):
        c.rows(y0 + 8, [(8 + dx, 12 + dx), (8 + dx, 12 + dx), (9 + dx, 11 + dx)], hair)
    if L.get("headphones"):
        c.r(6 + dx, y0, 10 + dx, y0, (30, 30, 34)); c.r(7 + dx, y0 + 4, 9 + dx, y0 + 7, L["headphones"])
    if L.get("hat"):
        c.rows(y0, [(5 + dx, 11 + dx), (4 + dx, 12 + dx), (4 + dx, 12 + dx)], L["hat"])
        c.r(12 + dx, y0 + 3, 15 + dx, y0 + 3, shade(L["hat"], 0.7))
    if L.get("beanie"):
        c.rows(y0 - 1, [(6 + dx, 10 + dx), (5 + dx, 11 + dx), (4 + dx, 12 + dx), (4 + dx, 12 + dx), (4 + dx, 12 + dx)], L["beanie"])
    if L.get("tray"):
        c.rect(OX - 2, 0, OX + 17, 1, (150, 100, 52))


def torso_side(c, L, t0, dx=0):
    shirt, top = L["shirt"], L["top"]
    if L["hair_style"] != "hijab":
        c.r(7 + dx, t0, 9 + dx, t0, shade(L["skin"], 0.8))
    rows = [(6, 10)] + [(5, 10)] * 7 + [(6, 10)]
    if L.get("belly"):
        rows = [(6, 10), (5, 10), (5, 11), (5, 12), (5, 12), (5, 12), (5, 11), (5, 10), (6, 10)]
    if top == "coat":
        rows = rows + [(5, 10), (5, 10), (5, 11)]
    c.rows(t0 + 1, [(a + dx, b + dx) for a, b in rows], shirt)
    if top == "hoodie":
        c.r(4 + dx, t0, 6 + dx, t0 + 2, shade(shirt, 0.82))
    elif top in ("jacket", "suit"):
        inner = (236, 236, 236) if top == "suit" else L.get("inner", (220, 214, 200))
        c.r(10 + dx, t0 + 1, 10 + dx, t0 + 8, inner)
        if top == "suit":
            c.r(10 + dx, t0 + 2, 10 + dx, t0 + 6, L.get("tie", (180, 40, 50)))
    elif top == "vest":
        c.rows(t0 + 1, [(a + dx, b + dx) for a, b in rows[:8]], L.get("vest", (230, 120, 40)))
        c.r(5 + dx, t0 + 5, 10 + dx, t0 + 5, (220, 220, 210))
    elif top == "dress":
        c.rows(t0 + 9, [(5 + dx, 10 + dx), (4 + dx, 11 + dx), (4 + dx, 11 + dx), (4 + dx, 12 + dx), (4 + dx, 12 + dx), (4 + dx, 12 + dx)], L.get("skirt", shirt))
    elif top == "tee" and L.get("stripe"):
        c.r(5 + dx, t0 + 5, 10 + dx, t0 + 5, L["stripe"])
    if L.get("chain"):
        c.r(9 + dx, t0 + 1, 10 + dx, t0 + 1, L["chain"])
    if top not in ("coat", "dress"):
        c.r(5 + dx, t0 + 9, 10 + dx, t0 + 9, shade(L["pants"], 0.62))
    if L.get("backpack"):
        bp = L["backpack"]
        c.r(2 + dx, t0 + 2, 4 + dx, t0 + 8, bp); c.r(2 + dx, t0 + 2, 4 + dx, t0 + 2, shade(bp, 1.2))
        c.r(5 + dx, t0 + 1, 5 + dx, t0 + 4, shade(bp, 0.7))


def leg_side(c, L, x, top, lift=0, back=False):
    col = shade(L["pants"], 0.82) if back else L["pants"]
    shoes = shade(L["shoes"], 0.85) if back else L["shoes"]
    bot = 26 - lift
    c.r(x, top, x + 2, bot, col)
    c.r(x, 27 - lift, x + 3, 28 - lift, shoes)
    c.r(x, 29 - lift, x + 3, 29 - lift, shade(L["shoes"], 0.6))
    c.p(x + 3, 27 - lift, shade(shoes, 1.2))


def arm_side(c, L, t0, dx=0, swing=0):
    sl = sleeve_color(L)
    long_sleeve = L.get("sleeves", "long" if L["top"] in ("hoodie", "jacket", "suit", "coat", "vest") else "short") == "long"
    x = 7 + dx + swing
    c.r(7 + dx, t0 + 2, 8 + dx, t0 + 3, sl)
    c.r(x, t0 + 4, x + 1, t0 + 7, sl if long_sleeve else L["skin"])
    c.r(x, t0 + 8, x + 1, t0 + 9, L["skin"])


def side(L, pose):
    c = Cell(CW, CH)
    skin, sl = L["skin"], sleeve_color(L)
    dy = L["height"]
    t0 = dy + 11
    if pose == "sit":
        d = dy + 2
        t0 = d + 11
        c.r(6, 22, 12, 24, L["pants"]); c.r(6, 22, 12, 22, shade(L["pants"], 1.12))
        c.r(11, 24, 13, 27, L["pants"])
        c.r(11, 28, 15, 28, L["shoes"]); c.r(11, 29, 15, 29, shade(L["shoes"], 0.6))
        torso_side(c, L, t0)
        if L["top"] == "dress":
            c.r(5, 21, 12, 23, L.get("skirt", L["shirt"]))
        head_side(c, L, d)
        c.r(7, t0 + 2, 8, t0 + 6, sl); c.r(8, t0 + 7, 11, t0 + 8, sl); c.r(11, t0 + 7, 12, t0 + 8, skin)
        return c.finish()
    if pose in ("lift1", "lift2"):
        leg_side(c, L, 7, t0 + 10, back=True); leg_side(c, L, 6, t0 + 10)
        torso_side(c, L, t0); head_side(c, L, dy)
        if pose == "lift1":
            c.r(8, t0 + 2, 9, t0 + 4, sl); c.r(9, t0 + 4, 10, t0 + 5, skin)
            c.rect(OX + 2, t0 + 4, OX + 18, t0 + 4, (160, 164, 176))
            c.rect(OX + 1, t0 + 1, OX + 3, t0 + 7, (40, 40, 48)); c.rect(OX + 17, t0 + 1, OX + 19, t0 + 7, (40, 40, 48))
        else:
            c.r(8, dy + 1, 9, t0 + 1, skin)
            c.rect(OX + 2, dy, OX + 18, dy, (160, 164, 176))
            c.rect(OX + 1, max(0, dy - 1), OX + 3, dy + 2, (40, 40, 48)); c.rect(OX + 17, max(0, dy - 1), OX + 19, dy + 2, (40, 40, 48))
        return c.finish()
    legs = {"idle": ((7, 0), (6, 0)), "walk1": ((4, 0), (9, 0)), "walk2": ((7, 2), (6, 0)),
            "punch": ((4, 0), (8, 0)), "special": ((3, 0), (9, 0)), "block": ((4, 0), (7, 0)),
            "hurt": ((5, 0), (7, 0)), "kick": ((4, 0), None)}[pose]
    leg_side(c, L, legs[0][0], t0 + 10, legs[0][1], back=True)
    if legs[1]:
        leg_side(c, L, legs[1][0], t0 + 10, legs[1][1])
    dx = {"kick": -2, "hurt": -2, "block": -1, "punch": 1, "special": 2}.get(pose, 0)
    c.r(5 + dx, t0 + 2, 6 + dx, t0 + 7, shade(sl, 0.75))   # arka kol
    torso_side(c, L, t0, dx)
    head_side(c, L, dy + (1 if pose == "hurt" else 0), dx - (1 if pose == "hurt" else 0), eyes="x" if pose == "hurt" else "normal")
    if pose == "kick":
        c.r(8, t0 + 9, 19, t0 + 11, L["pants"]); c.r(19, t0 + 7, 21, t0 + 12, L["shoes"])
        c.r(21, t0 + 7, 21, t0 + 12, shade(L["shoes"], 0.6))
    if pose == "special":
        c.r(10, t0 + 1, 17, t0 + 3, sl); c.r(10, t0 + 4, 17, t0 + 6, sl)
        c.r(18, t0, 21, t0 + 7, skin); c.r(18, t0, 21, t0, shade(skin, 1.15))
    elif pose == "punch":
        c.r(10, t0 + 2, 15, t0 + 4, sl); c.r(16, t0 + 1, 19, t0 + 5, skin); c.r(16, t0 + 1, 19, t0 + 1, shade(skin, 1.15))
    elif pose == "block":
        c.r(9, t0 + 2, 10, t0 + 5, sl); c.r(11, dy + 3, 12, t0 + 4, skin)
    elif pose == "hurt":
        c.r(1, t0, 2, t0 + 5, sl)
    else:
        arm_side(c, L, t0, dx, {"walk1": 2, "walk2": -1}.get(pose, 0))
    return c.finish()


def ko(L):
    c = Cell(CW, CH)
    skin, hair = L["skin"], L["hair"]
    # sırtüstü yatan: baş solda
    c.rect(1, 19, 9, 27, L.get("scarf", skin) if L["hair_style"] == "hijab" else skin)
    c.rect(1, 19, 3, 27, L.get("scarf", hair) if L["hair_style"] == "hijab" else hair)
    if L["hair_style"] == "hijab":
        c.rect(4, 21, 8, 25, skin)
    for (x, y) in ((6, 21), (7, 22), (7, 21), (6, 22), (6, 24), (7, 25), (7, 24), (6, 25)):
        c.set(x, y, EYE)
    c.rect(10, 18, 19, 28, L["shirt"]); c.rect(11, 17, 17, 17, L["shirt"]); c.rect(11, 29, 17, 29, L["shirt"])
    c.rect(12, 16, 13, 16, skin); c.rect(12, 30 - 1, 13, 29, skin)
    c.rect(20, 19, 25, 27, L["pants"]); c.rect(20, 23, 25, 23, shade(L["pants"], 0.7))
    c.rect(26, 19, 27, 22, L["shoes"]); c.rect(26, 24, 27, 27, L["shoes"])
    c.volume(1.08, 0.84); c.selout()
    return c


def sheet(L):
    W, Hh = CW * len(POSES), CH * 4
    px = [[(0, 0, 0, 0)] * W for _ in range(Hh)]

    def blit(cell, col, row):
        for y in range(CH):
            for x in range(CW):
                if cell.px[y][x][3]:
                    px[row * CH + y][col * CW + x] = cell.px[y][x]

    for col, pose in enumerate(POSES):
        blit(front(L, pose), col, 0)
        blit(front(L, pose, back=True), col, 1)
        blit(side(L, pose), col, 2)
    blit(ko(L), 0, 3)
    return px


# ---------------------------------------------------------------- Figüranlar

SKINS = [(242, 210, 182), (236, 196, 166), (226, 182, 146), (214, 160, 120), (196, 140, 100), (170, 116, 82),
         (140, 94, 66), (110, 72, 50)]
HAIRS = [(24, 20, 20), (44, 30, 24), (70, 44, 30), (110, 70, 40), (150, 100, 56), (190, 150, 90), (130, 40, 30),
         (200, 200, 204), (160, 160, 166)]
CLOTHES = [(200, 60, 60), (60, 120, 200), (60, 160, 90), (230, 200, 60), (150, 80, 170), (240, 240, 236),
           (40, 40, 48), (230, 130, 50), (90, 200, 200), (180, 180, 190), (120, 90, 60), (220, 110, 160),
           (100, 120, 70), (70, 80, 120), (170, 60, 80), (210, 190, 160), (50, 90, 80), (140, 150, 170)]
PANTS = [(40, 44, 70), (60, 84, 136), (50, 50, 56), (110, 100, 80), (90, 60, 40), (150, 150, 160), (36, 36, 40),
         (80, 100, 70), (170, 150, 120)]
SHOES = [(30, 26, 26), (236, 236, 236), (120, 70, 40), (60, 60, 70), (180, 60, 50), (70, 90, 140)]


def civilians(count=CIVILIAN_COUNT, seed=42):
    """Kalabalık: ilk 16'nın renkleri make_sprites ile aynı (portreler uyuşsun), saç/kıyafet/boy/aksesuar
    burada eklenir; geri kalanlar tamamen yeni üretilir."""
    rng = random.Random(seed)
    base = ms.civilians(16)
    out = {}
    for i in range(count):
        if i < 16:
            L = dict(base["sivil%d" % i])
        else:
            L = dict(skin=rng.choice(SKINS), hair=rng.choice(HAIRS), shirt=rng.choice(CLOTHES), pants=rng.choice(PANTS),
                     shoes=rng.choice(SHOES))
            if rng.random() < 0.25:
                L["glasses"] = rng.choice([(20, 20, 24), (140, 140, 150), (120, 80, 50)])
            if rng.random() < 0.18:
                L["belly"] = True
        woman = rng.random() < 0.5
        if L.get("long_hair"):
            woman = True
        if woman:
            L["hair_style"] = rng.choice(["long", "long", "ponytail", "bun", "hijab", "hijab", "curly", "sidepart"])
            L.pop("beard", None); L.pop("mustache", None); L.pop("bald", None)
            L["top"] = rng.choice(["tee", "dress", "coat", "jacket", "hoodie", "dress"])
            if L["hair_style"] == "hijab":
                L["scarf"] = rng.choice(CLOTHES)
                L["top"] = rng.choice(["coat", "dress", "jacket"])
                L.pop("hat", None); L.pop("beanie", None); L.pop("headphones", None)
            if L["top"] == "dress":
                L["skirt"] = rng.choice(CLOTHES + [(40, 40, 48), (60, 60, 90)])
            L["height"] = rng.choice([1, 2, 2])
        else:
            if L.get("bald"):
                L["hair_style"] = "bald"
            else:
                L["hair_style"] = rng.choice(["short", "short", "sidepart", "buzz", "curly", "bald"])
            L["top"] = rng.choice(["tee", "tee", "hoodie", "jacket", "suit", "coat", "vest"])
            if rng.random() < 0.2 and L["hair_style"] != "bald":
                L["beard"] = True
            elif rng.random() < 0.25:
                L["mustache"] = True
            L["height"] = rng.choice([0, 0, 1, 1, 2])
        if L["top"] in ("jacket", "coat"):
            L["inner"] = rng.choice(CLOTHES)
        if L["top"] == "vest":
            L["vest"] = rng.choice([(230, 120, 40), (210, 220, 60)])
        if L["top"] == "suit":
            L["shirt"] = rng.choice([(40, 40, 48), (60, 62, 76), (70, 72, 86), (90, 80, 70)])
            L["pants"] = L["shirt"]
            L["tie"] = rng.choice(CLOTHES)
        if rng.random() < 0.15 and L["hair_style"] not in ("bald", "hijab"):
            L["hair"] = rng.choice([(200, 200, 204), (160, 160, 166)])   # yaşlı
        if rng.random() < 0.28 and L["top"] not in ("suit",):
            L["backpack"] = rng.choice(CLOTHES)                         # öğrenci
        elif rng.random() < 0.15:
            L["bag"] = True
        L["sleeves"] = rng.choice(["short", "long"]) if L["top"] in ("tee", "dress") else "long"
        out["sivil%d" % i] = L
    return out


def all_looks():
    looks = {who: look_of(who, L) for who, L in ms.LOOKS.items()}
    for oid, over in OUTFITS.items():
        L = dict(looks["player"])
        for k, v in over.items():
            if v is None:
                L.pop(k, None)
            else:
                L[k] = v
        looks["player_" + oid] = L
    for who, L in civilians().items():
        looks[who] = look_of(who, L)
    return looks


def main():
    os.makedirs(OUT, exist_ok=True)
    looks = all_looks()
    for who, L in looks.items():
        ms.write_png(os.path.join(OUT, f"td_{who}.png"), sheet(L))
    print("Üstten bakış karakterleri üretildi:", len(looks), os.path.normpath(OUT))


if __name__ == "__main__":
    main()
