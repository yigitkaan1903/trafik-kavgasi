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
# Muşta elle çizilir (PixelLab 4 yerine 6 delik çizdi): dört parmak deliği, altta avuç çubuğu.
# assets/pixellab/map/weapon_musta.png bunun üstüne yazılır; pano ve inceleme portresi de onu kullanır.
MUSTA_PAL = {"k": (58, 36, 16, 255), "Y": (230, 180, 40, 255), "W": (255, 242, 176, 255), "y": (184, 134, 20, 255)}
MUSTA = [".kkkkkk.kkkkkk.kkkkkk.kkkkkk."] + [
    "k" + (row + "k") * 4 for row in ("YWYYYY", "YkkkkY", "Yk..kY", "Yk..kY", "YkkkkY", "YYYYYY")
] + ["k" + "y" * 27 + "k", ".k" + "y" * 25 + "k.", ".." + "k" * 25 + ".."]

# id: dövüşte en uzun kenar (piksel), sap hangi köşede ("bl": sol alt, "c": orta = muşta)
WEAPONS = {"sopa": (22, "bl"), "bicak": (12, "bl"), "musta": (10, "c")}


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


def draw_musta():
    px = [[MUSTA_PAL.get(ch, (0, 0, 0, 0)) for ch in row] for row in MUSTA]
    assert all(len(r) == len(px[0]) for r in px)
    write_png(os.path.join(ROOT, "assets", "pixellab", "map", "weapon_musta.png"), px)


def main():
    draw_musta()
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
