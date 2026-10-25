"""Silah görselleri (PixelLab çizimlerinden): dövüşte eldeki küçük hali ve tutma / uç noktaları.

Çalıştırma (proje klasöründen):  python tools/make_weapons.py   (make_rooms.py pano çizimini ayrıca yapar)
Girdi: assets/pixellab/map/weapon_<id>.png
Çıktı: assets/sprites/weapon_<id>.png (dövüş boyu), data/weapon_art.gd (tutma ve uç noktaları, piksel)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import write_png  # noqa: E402
from make_citymap import load_art, shrink  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# id: dövüşte en uzun kenar (piksel), sap hangi köşede ("bl": sol alt, "c": orta = muşta)
WEAPONS = {"sopa": (22, "bl"), "bicak": (12, "bl"), "musta": (6, "c"), "levye": (20, "bl"), "pala": (20, "bl"),
           "balta": (22, "bl")}


def ends(px, grip):
    """Sap (tutulan yer) ve uç: sol alttaki ve sağ üstteki dolu pikseller."""
    pts = [(x, y) for y, row in enumerate(px) for x, c in enumerate(row) if c[3]]
    if grip == "c":
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        mid = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
        return mid, (max(xs), mid[1])
    handle = max(pts, key=lambda p: p[1] - p[0])   # sol alt
    tip = max(pts, key=lambda p: p[0] - p[1])      # sağ üst
    return handle, tip


def _line(px, x0, y0, x1, y1, width, col):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x, y = round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)
        for dx in range(width):
            for dy in range(width):
                if 0 <= y + dy < len(px) and 0 <= x + dx < len(px[0]):
                    px[y + dy][x + dx] = col


def _outline(px, col=(30, 22, 26, 255)):
    src = [r[:] for r in px]
    for y in range(len(px)):
        for x in range(len(px[0])):
            if src[y][x][3]:
                continue
            if any(0 <= y + dy < len(px) and 0 <= x + dx < len(px[0]) and src[y + dy][x + dx][3] and src[y + dy][x + dx] != col
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[y][x] = col


def draw_pala():
    """Pala (elle; PixelLab işi takıldı): siyah bantlı sap sol altta, geniş çelik bıçak sağ üste."""
    px = [[(0, 0, 0, 0)] * 44 for _ in range(44)]
    _line(px, 3, 38, 11, 30, 3, (34, 30, 34, 255))                           # sap
    for k in range(4, 11, 2):
        px[38 - (k - 3)][k] = (90, 84, 92, 255)                               # bant çizgileri
    _line(px, 9, 27, 15, 33, 2, (120, 110, 100, 255))                         # kabzalık
    for t in range(0, 26):                                                     # bıçak: sırt koyu, ağız parlak
        x, y = 13 + t, 28 - t
        w = 4 if t < 20 else max(1, 4 - (t - 19))
        for k in range(w):
            col = (150, 156, 168, 255) if k == 0 else (205, 210, 220, 255) if k < w - 1 else (240, 244, 250, 255)
            if 0 <= y + k < 44 and 0 <= x < 44:
                px[y + k][x] = col
    _outline(px)
    write_png(os.path.join(ROOT, "assets", "pixellab", "map", "weapon_pala.png"), px)


def draw_balta():
    """Balta (elle): uzun ahşap sap, sağ üstte çelik balta başı."""
    px = [[(0, 0, 0, 0)] * 44 for _ in range(44)]
    _line(px, 3, 40, 30, 13, 3, (150, 100, 56, 255))                         # sap
    _line(px, 4, 40, 31, 13, 1, (184, 132, 80, 255))
    _line(px, 3, 41, 7, 37, 3, (90, 60, 34, 255))                             # sap ucu
    head = [(26, 6), (34, 4), (40, 10), (38, 18), (32, 20)]                  # balta başı (çokgen)
    for y in range(44):
        for x in range(44):
            inside = True
            for i in range(len(head)):
                (ax, ay), (bx, by) = head[i], head[(i + 1) % len(head)]
                if (bx - ax) * (y - ay) - (by - ay) * (x - ax) < 0:
                    inside = False
                    break
            if inside:
                px[y][x] = (170, 176, 188, 255)
    _line(px, 37, 8, 40, 12, 1, (235, 240, 248, 255))                         # keskin ağız
    _line(px, 39, 12, 38, 17, 1, (235, 240, 248, 255))
    _line(px, 27, 10, 31, 16, 2, (110, 116, 128, 255))                        # sapın geçtiği yer
    _outline(px)
    write_png(os.path.join(ROOT, "assets", "pixellab", "map", "weapon_balta.png"), px)


def draw_musta():
    """Muşta (elle): yan yana dört yuvarlak parmak halkası, altında kavisli avuç çubuğu; altın, üstten ışık."""
    W, Hh = 38, 22
    px = [[(0, 0, 0, 0)] * W for _ in range(Hh)]
    gold = [(126, 86, 18, 255), (186, 136, 30, 255), (230, 182, 52, 255), (250, 222, 120, 255)]
    rings = [(6, 7), (14, 6), (22, 6), (30, 7)]                     # ortadaki iki halka biraz yukarıda (parmak eğrisi)
    for y in range(Hh):
        for x in range(W):
            for (cx, cy) in rings:
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if 2.9 < d <= 5.2:
                    k = 3 if (y - cy) < -2 and (x - cx) < 1 else 2 if y <= cy else 1   # üst-sol parlak, alt koyu
                    px[y][x] = gold[k]
    for x in range(3, 34):                                             # avuç çubuğu: ortası kalın, uçlar yukarı kıvrık
        t = (x - 18) / 15
        top = 13 + round(2 * (1 - t * t)) - 1
        for y in range(top, top + 3 + (1 if abs(t) < 0.5 else 0)):
            px[y][x] = gold[2] if y == top else gold[1] if y < top + 2 else gold[0]
    for (cx, cy) in rings:                                             # halka ile çubuk arası köprü
        for y in range(cy + 5, 14):
            px[y][cx] = gold[1]; px[y][cx + 1] = gold[0]
    _outline(px, (52, 32, 10, 255))
    write_png(os.path.join(ROOT, "assets", "pixellab", "map", "weapon_musta.png"), px)


def main():
    draw_musta()
    draw_pala()
    draw_balta()
    lines = ["## tools/make_weapons.py üretir. Dövüşte eldeki silah: sap (tutulan nokta) ve uç, görsel pikseli olarak.", "",
             "const ART := {"]
    for wid, (size, grip) in WEAPONS.items():
        art = load_art("weapon_" + wid)
        s = size / max(len(art), len(art[0]))
        small = shrink(art, s)
        write_png(os.path.join(ROOT, "assets", "sprites", "weapon_%s.png" % wid), small)
        (hx, hy), (tx, ty) = ends(small, grip)
        lines.append('\t"%s": {"handle": Vector2(%.1f, %.1f), "tip": Vector2(%.1f, %.1f)},' % (wid, hx + 0.5, hy + 0.5, tx + 0.5, ty + 0.5))
    lines.append("}")
    with open(os.path.join(ROOT, "data", "weapon_art.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("Silahlar üretildi:", ", ".join(WEAPONS))


if __name__ == "__main__":
    main()
