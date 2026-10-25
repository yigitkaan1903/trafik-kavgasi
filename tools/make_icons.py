"""Arayüz simgeleri (piksel art): enerji, tokluk, para, takvim ve üç stat.

Çalıştırma (proje klasöründen):  python tools/make_icons.py
Çıktı: assets/sprites/ui_icons.png. Her simge 16x16'lık bir hücrenin sol üstünde; sıra ve boyutlar
scenes/ui/ui_draw.gd ICONS ile aynı olmalı.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import write_png  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ui_icons.png")
CELL = 16


def H(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


K = H("1b1024")   # kontur

ICONS = [
    ("energy", {"k": K, "Y": H("fef08a"), "y": H("facc15"), "o": H("b45309")}, [
        "......kkkkk.",
        ".....kYYyyk.",
        "....kYyyyk..",
        "...kYyyyk...",
        "..kYyyyykkk.",
        ".kYyyyyyyyk.",
        ".kkkkkyyyyk.",
        "....kyyyok..",
        "...kyyyok...",
        "...kyyok....",
        "..kyok......",
        "..kkk.......",
    ]),
    ("food", {"k": K, "B": H("f4a64a"), "b": H("c97a2a"), "W": H("fff3d6"), "G": H("4ade80"), "g": H("16a34a"),
              "Y": H("facc15"), "M": H("7c3f1d"), "m": H("5a2a12")}, [   # hamburger
        "...kkkkkk...",
        ".kkBBBBBBkk.",
        "kBBWBBBBWBBk",
        "kBBBBBWBBBBk",
        "kbbbbbbbbbbk",
        "kGgGGgGGgGGk",
        "kYYYYYYYYYYk",
        "kMYMMMMMMYMk",
        "kmmmmmmmmmmk",
        "kBBBBBBBBBBk",
        "kbbbbbbbbbbk",
        ".kkkkkkkkkk.",
    ]),
    ("money", {"k": K, "o": H("8e611a"), "Y": H("f6d86a"), "W": H("fff7cc"), "d": H("8e611a")}, [
        "...kkkkkk...",
        "..kooooook..",
        ".koWYYYYYok.",
        "koWYdYYYYYok",
        "koYYdddYYYok",
        "koYddddYYYok",
        "koYYdYYYdYok",
        "koYYdYYYdYok",
        "koYYddddYYok",
        ".koYYYYYYok.",
        "..kooooook..",
        "...kkkkkk...",
    ]),
    ("str", {"k": K, "s": H("9ca3af"), "R": H("fca5a5"), "W": H("ffffff"), "r": H("ef4444"), "d": H("991b1b")}, [
        "...kkkkkk...",
        "..kssssssk..",
        ".kskkkkkksk.",
        ".ksk....ksk.",
        ".ksk....ksk.",
        "..kkkkkkkk..",
        ".kRRrrrrrrk.",
        "kRWRrrrrrrdk",
        "kRRrrrrrrrdk",
        "kRrrrrrrrddk",
        ".krrrrrrddk.",
        "..kkkkkkkk..",
    ]),
    ("agi", {"k": K, "G": H("4ade80"), "g": H("16a34a"), "W": H("ffffff"), "w": H("e2e8f0"), "l": H("86efac")}, [
        "............",
        "....kkkk....",
        "...kGGGGk...",
        "...kGWgGk...",
        "...kGGGGkk..",
        "l.kGGGGGGGk.",
        ".kGGGGGGGGGk",
        "lkWGGGGGGGgk",
        ".kkkkkkkkkkk",
        "..kwwwwwwwk.",
        "...kkkkkkk..",
        "............",
    ]),
    ("sta", {"k": K, "B": H("60a5fa"), "W": H("dbeafe"), "b": H("1d4ed8"), "h": H("ffffff")}, [
        ".kkkkkkkkkk.",
        "kBBBBBBBBbbk",
        "kBWWBBBBBbbk",
        "kBBhhBhhBbbk",
        "kBBhhhhhBbbk",
        "kBBBhhhBBbbk",
        ".kBBBhBBBbk.",
        ".kBBBBBBbbk.",
        "..kBBBBBbk..",
        "...kBBBbk...",
        "....kBbk....",
        ".....kk.....",
    ]),
    ("calendar", {"k": K, "S": H("cbd5e1"), "R": H("ef4444"), "r": H("b91c1c"), "W": H("f8fafc"), "g": H("cbd5e1")}, [
        "...k......k...",
        ".kkSkkkkkkSkk.",
        "kRRSRRRRRRSRRk",
        "kRRRRRRRRRRRRk",
        "krrrrrrrrrrrrk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kWWWWWWWWWWWgk",
        "kggggggggggggk",
        ".kkkkkkkkkkkk.",
    ]),
]


def main():
    w = CELL * len(ICONS)
    px = [[(0, 0, 0, 0)] * w for _ in range(CELL)]
    for i, (name, pal, rows) in enumerate(ICONS):
        width = len(rows[0])
        for y, row in enumerate(rows):
            assert len(row) == width, (name, y, row)
            for x, ch in enumerate(row):
                if ch != ".":
                    px[y][i * CELL + x] = pal[ch]
    write_png(OUT, px)
    print("Simgeler:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
