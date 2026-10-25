"""Konuşma portreleri: her karakter için 48x48 büst (yüz, saç, omuzlar), konuşma kutusunda 2x gösterilir.

Çalıştırma (proje klasöründen):  python tools/make_portraits.py
Çıktı: assets/portraits/portrait_<görünüş>.png  (oyuncu kıyafetleri ve figüranlar dahil; ayrıca portrait_player_hurt)
Görünüş bilgisi make_topdown.all_looks() ile aynı: renkler make_sprites.LOOKS, saç/kıyafet make_topdown.STYLE.
"""
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sprites as ms  # noqa: E402
import make_topdown as td  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "portraits")
S = 48
CX = 24
WHITE = (246, 244, 238)
EYE_WHITE = (240, 238, 232)
LASH = (40, 26, 26)
IRISES = [(92, 58, 34), (70, 44, 28), (52, 36, 26), (96, 112, 60), (70, 110, 150)]
FACE_HW = {9: 5, 10: 7, 11: 8, 12: 9, 13: 10, 26: 10, 27: 9, 28: 9, 29: 8, 30: 7, 31: 6, 32: 4, 33: 2}
FEMININE = ("long", "ponytail", "bun", "hijab")


def sh(c, k):
    return ms.shade(c, k)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def face_hw(y):
    if y < 9 or y > 33:
        return -1
    if y in FACE_HW:
        return FACE_HW[y]
    return 10


class P(ms.Canvas):
    def r(self, x0, y0, x1, y1, c):
        self.rect(x0, y0, x1, y1, c)

    def p(self, x, y, c):
        self.set(x, y, c)

    def disc(self, cx, cy, rx, ry, c):
        for y in range(-ry, ry + 1):
            for x in range(-rx, rx + 1):
                if (x / max(rx, 0.5)) ** 2 + (y / max(ry, 0.5)) ** 2 <= 1.05:
                    self.set(cx + x, cy + y, c)


# ---------------------------------------------------------------- Parçalar

def torso(c, L):
    top = L.get("top", "tee")
    shirt = L["shirt"]
    for y in range(36, S):
        hw = min(22, 12 + (y - 36) * 2)
        c.r(CX - hw, y, CX + hw - 1, y, shirt)
        c.r(CX + hw - 5, y, CX + hw - 1, y, sh(shirt, 0.8))          # sağ omuz gölgede
        c.p(CX - hw, y, sh(shirt, 1.15))
    c.r(CX - 12, 36, CX + 11, 36, sh(shirt, 1.12))
    if top in ("jacket", "coat", "suit"):
        inner = (236, 236, 232) if top == "suit" else L.get("inner", (220, 220, 214))
        for y in range(37, S):
            w = 2 + (y - 37) // 2
            c.r(CX - w, y, CX + w - 1, y, inner)
            c.p(CX - w - 1, y, sh(shirt, 0.65)); c.p(CX + w, y, sh(shirt, 0.65))   # yaka
        if top == "coat":
            for y in range(40, S, 3):
                c.p(CX - 7, y, sh(shirt, 0.7))
    elif top == "vest":
        vest = L.get("vest", (230, 120, 40))
        for y in range(38, S):
            hw = min(22, 12 + (y - 36) * 2)
            c.r(CX - hw + 3, y, CX - 3, y, vest); c.r(CX + 2, y, CX + hw - 4, y, sh(vest, 0.85))
    elif top == "dress":
        for y in range(36, 40):
            w = 6 - (y - 36)
            c.r(CX - w, y, CX + w - 1, y, L["skin"])
    else:   # tişört ve kapüşonlu: yuvarlak yaka
        for y in range(36, 39):
            w = 4 - (y - 36)
            c.r(CX - w, y, CX + w - 1, y, sh(L["skin"], 0.85))
        c.r(CX - 5, 36, CX + 4, 36, sh(shirt, 0.75))
    if top == "hoodie" and not L.get("hood"):   # inik kapüşon, ipler
        c.r(CX - 11, 35, CX - 6, 38, sh(shirt, 0.72)); c.r(CX + 5, 35, CX + 10, 38, sh(shirt, 0.72))
        c.r(CX - 3, 39, CX - 3, 44, WHITE); c.r(CX + 2, 39, CX + 2, 43, WHITE)
    if L.get("stripe"):
        st = L["stripe"]
        c.r(CX - 22, 43, CX - 6, 44, st); c.r(CX + 5, 43, CX + 21, 44, sh(st, 0.85))
    if L.get("tie"):
        t = L["tie"]
        c.r(CX - 1, 37, CX, 38, sh(t, 0.8)); c.r(CX - 1, 39, CX, S - 1, t); c.p(CX - 1, 40, sh(t, 1.2))
    if L.get("chain"):
        for (x, y) in ((CX - 5, 37), (CX - 4, 38), (CX - 3, 39), (CX - 2, 40), (CX - 1, 40), (CX, 40), (CX + 1, 40),
                       (CX + 2, 39), (CX + 3, 38), (CX + 4, 37)):
            c.p(x, y, L["chain"])


def neck(c, L):
    skin = L["skin"]
    c.r(CX - 4, 29, CX + 3, 37, sh(skin, 0.9))
    c.r(CX - 4, 33, CX + 3, 34, sh(skin, 0.75))          # çene gölgesi
    c.r(CX + 2, 29, CX + 3, 37, sh(skin, 0.8))


def head(c, L):
    skin = L["skin"]
    for y in range(9, 34):
        hw = face_hw(y)
        c.r(CX - hw, y, CX + hw - 1, y, skin)
        c.r(CX + hw - 3, y, CX + hw - 1, y, sh(skin, 0.88))   # sağ yanak gölgede
        c.p(CX - hw, y, sh(skin, 1.06))
    for ex in (CX - 12, CX + 10):                              # kulaklar
        c.r(ex, 18, ex + 1, 24, sh(skin, 0.92 if ex < CX else 0.82))
        c.p(ex + (1 if ex < CX else 0), 20, sh(skin, 0.7)); c.p(ex + (1 if ex < CX else 0), 21, sh(skin, 0.7))
    blush = mix(skin, (220, 110, 110), 0.25)
    c.r(CX - 8, 25, CX - 6, 25, blush); c.r(CX + 5, 25, CX + 7, 25, blush)


def eyes(c, L, iris, mood, fem):
    hair = L["hair"]
    brow = sh(hair, 0.8) if L.get("hair_style") != "bald" else sh(L["skin"], 0.55)
    for x0 in (CX - 7, CX + 3):
        right = x0 > CX
        if mood == "hurt":
            c.r(x0, 21, x0 + 3, 21, LASH)
            c.r(x0, 17 + (1 if right else 0), x0 + 3, 17 + (1 if right else 0), brow)
            c.p(x0 + (3 if right else 0), 16 + (1 if right else 0), brow)
            continue
        c.r(x0, 17, x0 + 3, 17, brow)                          # kaş
        c.p(x0 + (3 if right else 0), 18, brow) if not right else c.p(x0, 18, brow)
        c.r(x0, 20, x0 + 3, 20, LASH)                          # üst kirpik
        if fem:
            c.p(x0 - 1 if not right else x0 + 4, 20, LASH)
        c.r(x0, 21, x0 + 3, 22, EYE_WHITE)
        ix = x0 + (1 if not right else 1)
        c.r(ix, 21, ix + 1, 22, iris)
        c.p(ix + 1, 21, sh(iris, 0.55))                        # gözbebeği
        c.p(ix, 21, mix(iris, (255, 255, 255), 0.55))          # parlama
        c.r(x0, 23, x0 + 3, 23, sh(L["skin"], 0.9))


def nose_mouth(c, L, mood, fem):
    skin = L["skin"]
    c.r(CX, 22, CX, 25, sh(skin, 0.86))
    c.p(CX - 1, 24, sh(skin, 1.08))
    c.r(CX - 2, 26, CX + 1, 26, sh(skin, 0.82))
    c.p(CX - 2, 26, sh(skin, 0.7)); c.p(CX + 1, 26, sh(skin, 0.7))
    lip = mix(skin, (200, 80, 90), 0.55 if fem else 0.3)
    if mood == "hurt":
        c.r(CX - 3, 30, CX + 2, 30, sh(lip, 0.7)); c.p(CX - 3, 29, sh(lip, 0.7)); c.p(CX + 2, 29, sh(lip, 0.7))
        bruise = mix(skin, (110, 70, 140), 0.45)
        c.r(CX + 3, 23, CX + 6, 24, bruise); c.p(CX + 4, 25, bruise)
        c.r(CX - 9, 11, CX - 6, 12, (236, 210, 170)); c.p(CX - 8, 11, (200, 170, 130))   # yara bandı
        return
    c.r(CX - 3, 29, CX + 2, 29, sh(lip, 0.75))
    c.p(CX - 4, 28, sh(lip, 0.8)); c.p(CX + 3, 28, sh(lip, 0.8))                         # hafif gülümseme
    c.r(CX - 2, 30, CX + 1, 30, lip)


def hair_dome(c, L, top_y=5, extra=1, fringe=True, part=None):
    hair = L["hair"]
    for y in range(top_y, 15):
        hw = face_hw(y) + extra if y >= 9 else {5: 6, 6: 8, 7: 10, 8: 11, 4: 4, 3: 2}.get(y, 11)
        if hw <= 0:
            continue
        c.r(CX - hw, y, CX + hw - 1, y, hair)
    for y in range(13, 22):                                    # favoriler
        c.r(CX - 11, y, CX - 9, y, hair); c.r(CX + 8, y, CX + 10, y, sh(hair, 0.8))
    if fringe:
        for x in range(CX - 9, CX + 9):
            if (x * 7) % 5 < 3:
                c.p(x, 15, hair)
            if (x * 3) % 7 == 0:
                c.p(x, 16, hair)
    if part is not None:
        c.r(part, 6, part, 11, sh(hair, 0.6))
        c.r(part + 1, 13, CX + 8, 15, hair)
    c.r(CX - 7, 7, CX - 3, 7, sh(hair, 1.3)); c.r(CX - 8, 8, CX - 6, 8, sh(hair, 1.3))   # parlama
    c.r(CX + 6, 9, CX + 9, 13, sh(hair, 0.78))


def hairstyle(c, L):
    st = L.get("hair_style", "short")
    hair = L["hair"]
    if st == "bald":
        c.r(CX - 11, 15, CX - 9, 22, hair); c.r(CX + 8, 15, CX + 10, 22, sh(hair, 0.8))
        c.r(CX - 6, 10, CX - 3, 10, sh(L["skin"], 1.15))
    elif st == "buzz":
        for y in range(7, 15):
            hw = face_hw(y) if y >= 9 else {7: 8, 8: 9}[y]
            for x in range(CX - hw, CX + hw):
                c.p(x, y, hair if (x + y) % 3 else mix(hair, L["skin"], 0.4))
        c.r(CX - 10, 15, CX - 9, 20, hair); c.r(CX + 8, 15, CX + 9, 20, hair)
    elif st == "curly":
        hair_dome(c, L, 4, 2, fringe=False)
        for (x, y) in ((CX - 10, 6), (CX - 6, 3), (CX - 1, 2), (CX + 4, 3), (CX + 9, 6), (CX - 12, 11), (CX + 11, 11),
                       (CX - 8, 14), (CX - 2, 14), (CX + 4, 14)):
            c.disc(x, y, 3, 2, hair)
            c.p(x - 1, y - 1, sh(hair, 1.3))
    elif st == "sidepart":
        hair_dome(c, L, 5, 1, fringe=False, part=CX - 5)
    elif st in ("long", "ponytail", "bun"):
        hair_dome(c, L, 5, 1, fringe=st == "long")
        if st == "long":
            for y in range(12, 42):
                w = 4 if y < 34 else 4 - (y - 34) // 3
                c.r(CX - 13, y, CX - 13 + w, y, hair); c.r(CX + 12 - w, y, CX + 12, y, sh(hair, 0.82))
        elif st == "ponytail":
            c.r(CX + 10, 12, CX + 13, 30, sh(hair, 0.85)); c.r(CX + 10, 12, CX + 13, 13, L.get("stripe") or (200, 60, 80))
        else:
            c.disc(CX, 4, 5, 3, hair); c.p(CX - 2, 3, sh(hair, 1.3))
    else:   # short
        hair_dome(c, L, 5, 1)


def hijab(c, L, back):
    sc = L.get("scarf", L["hair"])
    if back:   # yüzün arkasında kalan örtü
        for y in range(4, 40):
            hw = 13 if 8 <= y <= 30 else {4: 7, 5: 9, 6: 11, 7: 12}.get(y, 12 - (y - 30) // 2)
            c.r(CX - hw, y, CX + hw - 1, y, sc)
            c.r(CX + hw - 4, y, CX + hw - 1, y, sh(sc, 0.8))
        return
    for y in range(8, 18):   # alnı örten kısım
        hw = face_hw(y) + 1 if y >= 9 else 8
        c.r(CX - hw, y, CX + hw - 1, y, sc)
    c.r(CX - 9, 16, CX + 8, 16, sh(sc, 0.8))
    for y in range(16, 33):   # yüzün iki yanı
        hw = face_hw(y)
        c.r(CX - hw - 1, y, CX - hw + 1, y, sc); c.r(CX + hw - 2, y, CX + hw, y, sh(sc, 0.85))
    for y in range(33, 39):   # çenenin altında bağlanır
        c.r(CX - 8 + (y - 33) // 2, y, CX + 7 - (y - 33) // 2, y, sc)
    c.r(CX - 2, 35, CX + 1, 38, sh(sc, 0.75))


def hood_back(c, L):
    col = sh(L["shirt"], 0.75)
    for y in range(3, 40):
        hw = 14 if 7 <= y <= 30 else {3: 6, 4: 9, 5: 11, 6: 13}.get(y, 14 - (y - 30) // 3)
        c.r(CX - hw, y, CX + hw - 1, y, col)
    for y in range(5, 32):
        hw = 12 if 8 <= y <= 28 else 9
        c.r(CX - hw, y, CX + hw - 1, y, sh(col, 0.6))


def headwear(c, L):
    if L.get("hat"):
        hat = L["hat"]
        for y in range(4, 13):
            hw = face_hw(y) + 1 if y >= 9 else {4: 5, 5: 8, 6: 9, 7: 10, 8: 11}[y]
            c.r(CX - hw, y, CX + hw - 1, y, hat)
        c.r(CX - 6, 6, CX - 3, 6, sh(hat, 1.3))
        c.r(CX - 12, 12, CX + 11, 13, sh(hat, 0.85)); c.r(CX - 12, 14, CX + 11, 14, sh(hat, 0.55))   # siper
        c.p(CX, 4, sh(hat, 0.7))
    elif L.get("beanie"):
        b = L["beanie"]
        for y in range(3, 15):
            hw = face_hw(y) + 2 if y >= 9 else {3: 5, 4: 8, 5: 10, 6: 11, 7: 11, 8: 12}[y]
            c.r(CX - hw, y, CX + hw - 1, y, b)
        for x in range(CX - 11, CX + 11, 2):
            c.r(x, 11, x, 14, sh(b, 0.8))
        c.r(CX - 12, 11, CX + 11, 11, sh(b, 1.15))
        c.r(CX - 5, 5, CX - 2, 5, sh(b, 1.3))
    if L.get("headphones"):
        hp = L["headphones"]
        for x in range(CX - 12, CX + 12):
            dy = int(((x - CX + 0.5) / 12.5) ** 2 * 6)
            c.p(x, 3 + dy, sh(hp, 0.8)); c.p(x, 4 + dy, hp)
        for ex in (CX - 15, CX + 10):
            c.r(ex, 16, ex + 4, 25, hp); c.r(ex + 1, 17, ex + 3, 18, sh(hp, 1.3)); c.r(ex, 24, ex + 4, 25, sh(hp, 0.7))


def facial_hair(c, L):
    hair = L["hair"]
    if L.get("beard"):
        for y in range(22, 35):
            hw = face_hw(y) if y <= 33 else 1
            for x in range(CX - hw, CX + hw):
                inner = abs(x - CX + 0.5) < 6 and y < 27
                if not inner:
                    c.p(x, y, hair if (x + y) % 5 else sh(hair, 1.2))
        c.r(CX - 3, 29, CX + 2, 30, mix(L["skin"], (180, 80, 80), 0.3))   # ağız beyazda kalır
        c.r(CX - 5, 27, CX + 4, 28, hair)
    elif L.get("mustache"):
        c.r(CX - 5, 27, CX + 4, 28, hair); c.p(CX - 5, 29, hair); c.p(CX + 4, 29, hair)
        c.r(CX - 3, 27, CX + 2, 27, sh(hair, 1.2))


def glasses(c, L):
    g = L.get("glasses")
    if not g:
        return
    dark = sum(g) < 120
    for x0 in (CX - 8, CX + 2):
        if dark:   # güneş gözlüğü
            c.r(x0, 19, x0 + 5, 23, g); c.r(x0 + 1, 20, x0 + 2, 20, (120, 130, 150))
        else:
            c.r(x0, 19, x0 + 5, 19, g); c.r(x0, 23, x0 + 5, 23, g); c.r(x0, 19, x0, 23, g); c.r(x0 + 5, 19, x0 + 5, 23, g)
    c.r(CX - 2, 20, CX + 1, 20, g)
    c.r(CX - 11, 20, CX - 9, 20, g); c.r(CX + 8, 20, CX + 10, 20, g)


def portrait(L, seed, mood="normal", fem=None):
    c = P(S, S)
    st = L.get("hair_style", "short")
    if fem is None:   # oyuncu uzun saç seçse de rimel/ruj almaz
        fem = st in FEMININE or L.get("top") == "dress" or "skirt" in L
    iris = IRISES[seed % len(IRISES)] if seed % 4 else IRISES[0]
    if L.get("hood"):
        hood_back(c, L)
    if st == "hijab":
        hijab(c, L, back=True)
    elif st == "long":
        hair_back = L["hair"]
        for y in range(10, 40):
            c.r(CX - 13, y, CX + 12, y, sh(hair_back, 0.7))
    torso(c, L)
    neck(c, L)
    head(c, L)
    eyes(c, L, iris, mood, fem)
    nose_mouth(c, L, mood, fem)
    facial_hair(c, L)
    if st == "hijab":
        hijab(c, L, back=False)
    elif not (L.get("hat") or L.get("beanie")) or st in ("long", "ponytail"):
        hairstyle(c, L)
    else:
        c.r(CX - 11, 13, CX - 9, 21, L["hair"]); c.r(CX + 8, 13, CX + 10, 21, sh(L["hair"], 0.8))
    headwear(c, L)
    glasses(c, L)
    c.outline()
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    looks = td.all_looks()
    for who, L in looks.items():
        seed = zlib.crc32(who.encode())
        ms.write_png(os.path.join(OUT, "portrait_%s.png" % who), portrait(L, seed, fem=False if who.startswith("player") else None).px)
    ms.write_png(os.path.join(OUT, "portrait_player_hurt.png"), portrait(looks["player"], zlib.crc32(b"player"), "hurt").px)
    print("Portreler üretildi:", len(looks) + 1, os.path.normpath(OUT))


if __name__ == "__main__":
    main()
